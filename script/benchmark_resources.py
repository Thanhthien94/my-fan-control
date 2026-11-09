#!/usr/bin/env python3
"""Sample a macOS app with libproc. Read-only; no profiling privileges or dependencies."""
import argparse
import csv
import ctypes
import datetime
import json
import math
import os
import pathlib
import plistlib
import statistics
import subprocess
import sys
import time


class RUsageInfoV2(ctypes.Structure):
    _fields_ = [("uuid", ctypes.c_uint8 * 16)] + [(name, ctypes.c_uint64) for name in (
        "user_time", "system_time", "pkg_idle_wkups", "interrupt_wkups", "pageins",
        "wired_size", "resident_size", "phys_footprint", "proc_start_abstime", "proc_exit_abstime",
        "child_user_time", "child_system_time", "child_pkg_idle_wkups", "child_interrupt_wkups",
        "child_pageins", "child_elapsed_abstime", "diskio_bytesread", "diskio_byteswritten",
    )]


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def distribution(values):
    values = sorted(values)
    def percentile(p):
        position = (len(values) - 1) * p
        lo, hi = math.floor(position), math.ceil(position)
        return values[lo] + (values[hi] - values[lo]) * (position - lo)
    return {"mean": statistics.mean(values), "p50": percentile(.5), "p95": percentile(.95), "min": values[0], "max": values[-1]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--duration", type=int, default=90)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if sys.platform != "darwin" or not (5 <= args.duration <= 3600) or not (0 <= args.warmup <= 120):
        parser.error("Requires macOS; duration 5–3600s and warmup 0–120s")
    library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    library.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
    library.proc_pid_rusage.restype = ctypes.c_int
    class Timebase(ctypes.Structure):
        _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]
    timebase = Timebase()
    system = ctypes.CDLL("/usr/lib/libSystem.B.dylib")
    if system.mach_timebase_info(ctypes.byref(timebase)) != 0 or not timebase.denom:
        raise RuntimeError("Could not read Mach timebase")
    cpu_seconds_per_tick = timebase.numer / timebase.denom / 1e9
    def read():
        value = RUsageInfoV2()
        if library.proc_pid_rusage(args.pid, 2, ctypes.byref(value)) != 0:
            raise OSError(ctypes.get_errno(), "proc_pid_rusage failed")
        return value
    executable = pathlib.Path(command("/bin/ps", "-p", str(args.pid), "-o", "comm="))
    if executable.name != "MyFanControl" or executable.parent.name != "MacOS":
        parser.error("PID must identify the MyFanControl app executable")
    info = plistlib.loads((executable.parent.parent / "Info.plist").read_bytes())
    args.output_dir.mkdir(parents=True, exist_ok=False)
    metadata = {
        "scenario": args.scenario, "app_version": info.get("MFCReleaseLabel"),
        "app_build": info.get("CFBundleVersion"), "app_revision": info.get("MFCSourceRevision"),
        "chip": command("/usr/sbin/sysctl", "-n", "machdep.cpu.brand_string"),
        "model": command("/usr/sbin/sysctl", "-n", "hw.model"),
        "logical_cpus": int(command("/usr/sbin/sysctl", "-n", "hw.logicalcpu")),
        "memory_gib": int(command("/usr/sbin/sysctl", "-n", "hw.memsize")) / 1024**3,
        "macos": command("/usr/bin/sw_vers", "-productVersion"),
        "macos_build": command("/usr/bin/sw_vers", "-buildVersion"),
        "load_average_start": os.getloadavg(), "warmup_seconds": args.warmup,
        "cpu_basis": "100% equals one fully used logical CPU; RUSAGE_INFO_V2 Mach absolute CPU ticks converted with mach_timebase_info",
        "mach_timebase": {"numer": timebase.numer, "denom": timebase.denom},
        "memory_basis": "Kernel phys_footprint and resident_size, MiB (1024^2 bytes); not total system memory",
    }
    read()
    print(f"Warmup {args.warmup}s, then {args.duration}s: {args.scenario}", flush=True)
    time.sleep(args.warmup)
    start = time.monotonic_ns()
    previous_time, previous = start, read()
    first = previous
    rows = []
    metadata["started_at_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    for index in range(1, args.duration + 1):
        target = start + index * 1_000_000_000
        time.sleep(max(0, (target - time.monotonic_ns()) / 1e9))
        current, instant = read(), time.monotonic_ns()
        if current.proc_start_abstime != first.proc_start_abstime:
            raise RuntimeError("Target process restarted during measurement")
        elapsed = (instant - previous_time) / 1e9
        cpu = ((current.user_time + current.system_time) - (previous.user_time + previous.system_time)) * cpu_seconds_per_tick
        rows.append({"elapsed_s": (instant - start) / 1e9, "interval_s": elapsed,
            "cpu_one_core_pct": cpu / elapsed * 100,
            "footprint_mib": current.phys_footprint / 1024**2,
            "rss_mib": current.resident_size / 1024**2})
        previous, previous_time = current, instant
    duration = (previous_time - start) / 1e9
    metadata.update({"completed": True, "measured_seconds": duration, "sample_count": len(rows),
        "cpu_one_core_percent_mean": ((previous.user_time + previous.system_time) - (first.user_time + first.system_time)) * cpu_seconds_per_tick / duration * 100,
        "cpu_one_second_samples_percent": distribution([r["cpu_one_core_pct"] for r in rows]),
        "phys_footprint_mib": distribution([r["footprint_mib"] for r in rows]),
        "resident_mib": distribution([r["rss_mib"] for r in rows]),
        "package_idle_wakeups_per_s": (previous.pkg_idle_wkups - first.pkg_idle_wkups) / duration,
        "interrupt_wakeups_per_s": (previous.interrupt_wkups - first.interrupt_wkups) / duration,
        "disk_read_kib": (previous.diskio_bytesread - first.diskio_bytesread) / 1024,
        "disk_written_kib": (previous.diskio_byteswritten - first.diskio_byteswritten) / 1024,
        "load_average_end": os.getloadavg()})
    (args.output_dir / "summary.json").write_text(json.dumps(metadata, indent=2) + "\n")
    with (args.output_dir / "samples.csv").open("x", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps({"scenario": args.scenario, "cpu_one_core_percent_mean": metadata["cpu_one_core_percent_mean"],
        "footprint_mib": metadata["phys_footprint_mib"], "rss_mib": metadata["resident_mib"]}, indent=2), flush=True)


if __name__ == "__main__":
    main()
