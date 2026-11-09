#include "CSMC.h"
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <sys/select.h>
#include <errno.h>
#include <signal.h>
#include <time.h>

static volatile sig_atomic_t stop_requested=0;
static void request_stop(int signal_number) { (void)signal_number;stop_requested=1; }
void mfc_install_signal_handlers(void) {
    struct sigaction action={0};action.sa_handler=request_stop;sigemptyset(&action.sa_mask);
    sigaction(SIGTERM,&action,NULL);sigaction(SIGINT,&action,NULL);sigaction(SIGHUP,&action,NULL);
}
int mfc_stop_requested(void) {return stop_requested;}

typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } Version;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } Limits;
typedef struct { uint32_t size, type; uint8_t attributes; } KeyInfo;
typedef struct {
    uint32_t key; Version version; Limits limits; KeyInfo info;
    uint8_t result, status, command; uint32_t data; uint8_t bytes[32];
} Packet;
_Static_assert(sizeof(Packet) == 80, "AppleSMC packet ABI mismatch");
static uint32_t fourcc(const char *key) {
    return ((uint32_t)(uint8_t)key[0]<<24) | ((uint32_t)(uint8_t)key[1]<<16) |
           ((uint32_t)(uint8_t)key[2]<<8) | (uint8_t)key[3];
}
static int call(uint32_t connection, Packet *in, Packet *out) {
    size_t size = sizeof(*out);
    kern_return_t status = IOConnectCallStructMethod(connection, 2, in, sizeof(*in), out, &size);
    if (status != KERN_SUCCESS) return (int)status;
    if (size != sizeof(*out)) return -1;
    return out->result ? -(int)out->result : 0;
}
uint32_t mfc_open(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return 0;
    io_connect_t connection = 0;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    return result == KERN_SUCCESS ? connection : 0;
}
void mfc_close(uint32_t connection) { if (connection) IOServiceClose(connection); }
int mfc_read(uint32_t connection, const char *key, MFCValue *value) {
    if (!key || strlen(key)!=4 || !value) return -1;
    Packet in = {0}, out = {0}; in.key = fourcc(key); in.command = 9;
    int result = call(connection, &in, &out); if (result) return result;
    if (!out.info.size || out.info.size > 32) return -1;
    value->size = out.info.size; value->type = out.info.type;
    memset(&out, 0, sizeof(out)); in.info.size = value->size; in.command = 5;
    result = call(connection, &in, &out);
    if (!result) memcpy(value->bytes, out.bytes, 32);
    return result;
}
int mfc_write(uint32_t connection, const char *key, const MFCValue *value) {
    if (geteuid()!=0 || !key || strlen(key)!=4 || value->size>32 || !value->size) return -1;
    // The only writable namespace is fan target/mode and legacy force mask.
    if (!strcmp(key,"Ftst")) {
        if(value->size!=1 || value->bytes[0]>1) return -1;
    } else if (!(key[0]=='F' && key[1]>='0' && key[1]<='9' &&
          ((key[2]=='T' && key[3]=='g') || ((key[2]=='M'||key[2]=='m') && key[3]=='d'))) && strcmp(key,"FS! ")) return -1;
    Packet in = {0}, out = {0}; in.key=fourcc(key); in.command=6; in.info.size=value->size;
    memcpy(in.bytes,value->bytes,value->size); return call(connection,&in,&out);
}
int mfc_key_at(uint32_t connection, uint32_t index, char *key) {
    Packet in={0},out={0}; in.command=8; in.data=index;
    int result=call(connection,&in,&out); if(result) return result;
    for(int i=0;i<4;i++) key[i]=(char)(out.key>>(24-i*8)); key[4]=0; return 0;
}
static int address(const char *path, struct sockaddr_un *addr) {
    memset(addr,0,sizeof(*addr)); addr->sun_family=AF_UNIX;
    if (strlen(path)>=sizeof(addr->sun_path)) return -1;
    strcpy(addr->sun_path,path); addr->sun_len=sizeof(*addr); return 0;
}
static void options(int fd) {
    int yes=1; setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&yes,sizeof(yes));
    struct timeval t={1,0}; setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&t,sizeof(t));
    setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&t,sizeof(t));
}
int mfc_listen(const char *path, uint32_t uid) {
    if(geteuid()!=0 || uid==0) return -1;
    struct sockaddr_un addr; if(address(path,&addr)) return -1;
    struct stat oldstat,newstat;
    if(lstat(path,&oldstat)==0 && S_ISSOCK(oldstat.st_mode) && oldstat.st_uid==uid) {
        int probe=socket(AF_UNIX,SOCK_STREAM,0);
        int connected=probe<0 ? -1 : connect(probe,(struct sockaddr *)&addr,sizeof(addr));
        int failure=errno;if(probe>=0)close(probe);
        if(connected<0 && failure==ECONNREFUSED && lstat(path,&newstat)==0 && oldstat.st_ino==newstat.st_ino) unlink(path);
    }
    int fd=socket(AF_UNIX,SOCK_STREAM,0); if(fd<0) return -1;
    // Never remove or follow a preexisting path; /var/run is root-owned.
    mode_t old=umask(077);
    int result=bind(fd,(struct sockaddr *)&addr,sizeof(addr)); umask(old);
    if(result) { close(fd); return -1; }
    if(chown(path,uid,(gid_t)-1) || chmod(path,0600) || listen(fd,4)) {
        close(fd); unlink(path); return -1;
    }
    return fd;
}
int mfc_accept(int server, uint32_t uid) {
    int fd=accept(server,NULL,NULL); if(fd<0) return -1;
    uid_t peer; gid_t group;
    if(getpeereid(fd,&peer,&group) || peer!=uid) { close(fd); return -1; }
    options(fd); return fd;
}
int mfc_connect(const char *path) {
    struct sockaddr_un addr; if(address(path,&addr)) return -1;
    int fd=socket(AF_UNIX,SOCK_STREAM,0); if(fd<0) return -1;
    options(fd);
    if(connect(fd,(struct sockaddr *)&addr,sizeof(addr))) {close(fd);return -1;}
    uid_t peer; gid_t group;
    if(getpeereid(fd,&peer,&group) || peer!=0) {close(fd);return -1;}
    return fd;
}
int mfc_wait(int fd, int seconds) {
    fd_set set; FD_ZERO(&set); FD_SET(fd,&set); struct timeval t={seconds,0};
    return select(fd+1,&set,NULL,NULL,&t);
}
static int receive_deadline(int fd, char *buffer, size_t capacity,double timeout) {
    if(fd<0 || fd>=FD_SETSIZE) return -1;
    size_t n=0;struct timespec start,now;clock_gettime(CLOCK_MONOTONIC,&start);
    while(n+1<capacity) {
        clock_gettime(CLOCK_MONOTONIC,&now);
        double elapsed=(double)(now.tv_sec-start.tv_sec)+(double)(now.tv_nsec-start.tv_nsec)/1e9;
        if(elapsed>=timeout) return -1;
        double remaining=timeout-elapsed;
        fd_set ready;FD_ZERO(&ready);FD_SET(fd,&ready);
        struct timeval tv={(int)remaining,(int)((remaining-(int)remaining)*1e6)};
        if(select(fd+1,&ready,NULL,NULL,&tv)<=0) return -1;
        char c; ssize_t count=recv(fd,&c,1,0); if(count!=1) return -1;
        if(c=='\n') {buffer[n]=0;return (int)n;} buffer[n++]=c; }
    return -1;
}
int mfc_receive(int fd,char *buffer,size_t capacity){return receive_deadline(fd,buffer,capacity,1);}
int mfc_receive_reply(int fd,char *buffer,size_t capacity){return receive_deadline(fd,buffer,capacity,45);}
int mfc_peer_pid(int fd) {pid_t pid=0;socklen_t size=sizeof(pid);return getsockopt(fd,SOL_LOCAL,LOCAL_PEERPID,&pid,&size)==0 ? pid : -1;}
int mfc_send(int fd, const char *buffer, size_t length) {
    size_t n=0; while(n<length) {ssize_t result=send(fd,buffer+n,length-n,0);
        if(result<=0) return -1; n+=(size_t)result;} return 0;
}
