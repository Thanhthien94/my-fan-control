#pragma once
#include <stdint.h>
#include <stddef.h>
typedef struct { uint32_t type; uint32_t size; uint8_t bytes[32]; } MFCValue;
uint32_t mfc_open(void);
void mfc_close(uint32_t connection);
int mfc_read(uint32_t connection, const char *key, MFCValue *value);
int mfc_write(uint32_t connection, const char *key, const MFCValue *value);
int mfc_key_at(uint32_t connection, uint32_t index, char *key);
int mfc_listen(const char *path, uint32_t uid);
int mfc_accept(int server, uint32_t allowed_uid);
int mfc_connect(const char *path);
int mfc_wait(int fd, int seconds);
int mfc_receive(int fd, char *buffer, size_t capacity);
int mfc_receive_reply(int fd, char *buffer, size_t capacity);
int mfc_peer_pid(int fd);
int mfc_send(int fd, const char *buffer, size_t length);
void mfc_install_signal_handlers(void);
int mfc_stop_requested(void);
