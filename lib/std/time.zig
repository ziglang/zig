// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const atomic = std.sync.atomic;
const builtin = std.builtin;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;
const target = std.Target.current;

pub const epoch = @import("time/epoch.zig");

// Divisions of a nanosecond.
pub const ns_per_us = 1000;
pub const ns_per_ms = 1000 * ns_per_us;
pub const ns_per_s = 1000 * ns_per_ms;
pub const ns_per_min = 60 * ns_per_s;
pub const ns_per_hour = 60 * ns_per_min;
pub const ns_per_day = 24 * ns_per_hour;
pub const ns_per_week = 7 * ns_per_day;

// Divisions of a microsecond.
pub const us_per_ms = 1000;
pub const us_per_s = 1000 * us_per_ms;
pub const us_per_min = 60 * us_per_s;
pub const us_per_hour = 60 * us_per_min;
pub const us_per_day = 24 * us_per_hour;
pub const us_per_week = 7 * us_per_day;

// Divisions of a millisecond.
pub const ms_per_s = 1000;
pub const ms_per_min = 60 * ms_per_s;
pub const ms_per_hour = 60 * ms_per_min;
pub const ms_per_day = 24 * ms_per_hour;
pub const ms_per_week = 7 * ms_per_day;

// Divisions of a second.
pub const s_per_min = 60;
pub const s_per_hour = s_per_min * 60;
pub const s_per_day = s_per_hour * 24;
pub const s_per_week = s_per_day * 7;

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    // TODO: opting out of async sleeping?
    if (std.io.is_async) {
        return std.event.Loop.instance.?.sleep(nanoseconds);
    }

    if (target.os.tag == .windows) {
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(os.windows.DWORD, big_ms_from_ns) catch math.maxInt(os.windows.DWORD);
        os.windows.kernel32.Sleep(ms);
        return;
    }

    if (target.os.tag == .wasi) {
        const w = std.os.wasi;
        const userdata: w.userdata_t = 0x0123_45678;
        const clock = w.subscription_clock_t{
            .id = w.CLOCK_MONOTONIC,
            .timeout = nanoseconds,
            .precision = 0,
            .flags = 0,
        };
        const in = w.subscription_t{
            .userdata = userdata,
            .u = w.subscription_u_t{
                .tag = w.EVENTTYPE_CLOCK,
                .u = w.subscription_u_u_t{
                    .clock = clock,
                },
            },
        };

        var event: w.event_t = undefined;
        var nevents: usize = undefined;
        _ = w.poll_oneoff(&in, &event, 1, &nevents);
        return;
    }

    const s = nanoseconds / ns_per_s;
    const ns = nanoseconds % ns_per_s;
    std.os.nanosleep(s, ns);
}

test "sleep" {
    sleep(1);
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed due to possibly being behind the UTC epoch.
pub fn timestamp() i64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed due to possibly being behind the UTC epoch.
pub fn milliTimestamp() i64 {
    return @intCast(i64, @divFloor(nanoTimestamp(), ns_per_ms));
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed due to possibly being behind the UTC epoch.
pub fn nanoTimestamp() i128 {
    if (target.os.tag == .windows) {
        // FileTime has a granularity of 100 nanoseconds and uses the NTFS/Windows epoch,
        // which is 1601-01-01.
        const epoch_adj = epoch.windows * (ns_per_s / 100);
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimeAsFileTime(&ft);
        const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
        return @as(i128, @bitCast(i64, ft64) + epoch_adj) * 100;
    }

    if (comptime target.isDarwin()) {
        var tv: os.timeval = undefined;
        os.gettimeofday(&tv, null);
        return (@as(i128, tv.tv_sec) * ns_per_s) + (tv.tv_usec * ns_per_us);
    }

    if (target.os.tag == .wasi and !builtin.link_libc) {
        var ns: os.wasi.timestamp_t = undefined;
        return switch (os.wasi.clock_time_get(os.wasi.CLOCK_REALTIME, 1, &ns)) {
            os.wasi.ESUCCESS => ns,
            else => 0,
        };
    }

    if (target.os.tag == .linux or builtin.link_libc) {
        var ts: os.timespec = undefined;
        os.clock_gettime(os.CLOCK_REALTIME, &ts) catch return 0;
        return (@as(i128, ts.tv_sec) * ns_per_s) + ts.tv_nsec;
    }

    // "Precision of timing depends on hardware and OS".
    return 0;
}

test "timestamp" {
    const margin = 50 * ns_per_ms;

    const start = timestamp();
    sleep(1 * ns_per_ms);
    const stop = timestamp();

    const interval = stop - start;
    testing.expect(interval >= 0);
    testing.expect(interval < margin);
}

/// Get a monotonic timestamp, in nanoseconds, using the system's high-performance timer.
/// Precision of timing depends on the hardware and operating system.
/// The return value is guaranteed to never go backwards, but not guaranteed to progress at a steady rate.
///
/// TODO: checkout the statistical-acceleration techniques performed by Google's abseil to decrease overhead.
/// https://github.com/abseil/abseil-cpp/blob/master/absl/time/clock.cc
pub fn now() u64 {
    const current_now = readSystemTimer() orelse blk: {
        break :blk 0; // Precision of timing depends on the hardware and operating system.
    };
    return enforceMonotonic(current_now);
}

/// Forces the provided value of the system timer to be monotonic in relation to previously providede values.
fn enforceMonotonic(current_now: u64) u64 {
    // For some platforms, the time returned isnt always monotonic (never going backwards).
    // If it is, then we just return what the os provided.
    // If not, we have to enforce the monotonic property ourselves.
    if (comptime isSystemTimerMonotonic()) {
        return current_now;
    }

    const Static = struct {
        var last_now: u64 = 0;
        var last_now_mutex = std.sync.Mutex{};
    };
    
    // If 64bit atomics are available, its generally cheaper to use them vs locking below.
    if (comptime supports64bitAtomics()) {
        var last = atomic.load(&Static.last_now, .Relaxed);
        while (true) {
            if (last >= current_now) {
                return last;
            }
            last = atomic.tryCompareAndSwap(
                &Static.last_now,
                last,
                current_now,
                .Relaxed,
                .Relaxed,
            ) orelse return current_now;
        }
    }

    // For platforms that don't support 64bit atomics, fall back to Lock based synchronization.
    // We use a Lock over a Mutex here as the former is unfair and may deal with micro-contention better.
    const held = Static.last_now_mutex.acquire();
    defer held.release();

    const last_now = Static.last_now;
    if (last_now > current_now) {
        return last_now;
    }

    Static.last_now = current_now;
    return current_now;
}

/// Returns true if the platform supports 64-bit atomic operations.
fn supports64bitAtomics() bool {
    // TODO: check if this is actually true.
    return @sizeOf(usize) >= @sizeOf(u64);
}

/// Returns true if the system's high performance timer implementation is actually monotonic.
/// For some platforms, this is not always the case: https://doc.rust-lang.org/src/std/time.rs.html#227
fn isSystemTimerMonotonic() bool {
    // https://github.com/rust-lang/rust/issues/51648
    // https://github.com/rust-lang/rust/issues/56560
    // https://github.com/rust-lang/rust/issues/56612
    if (target.os.tag == .windows) {
        return false;
    }
    
    // https://github.com/rust-lang/rust/issues/49281
    // https://github.com/rust-lang/rust/issues/56940
    if (target.os.tag == .linux and (target.cpu.arch == .aarch64 or .arch == .s390x)) {
        return false;
    }

    // https://github.com/rust-lang/rust/issues/48514
    if (target.os.tag == .openbsd and target.arch == .x86_64) {
        return false;
    }

    return true;
}

/// Tries to sample the systems high performance timer, returning its value in nanoseconds.
/// Precision and progression of timing depends on the hardware and operating system.
/// If `isSystemTimerMonotonic` returns true, the return value must be monotonically increasing.
fn readSystemTimer() ?u64 {
    if (target.os.tag == .windows) {
        const Static = struct {
            var bias: u64 = undefined;
            var frequency_mul: u64 = undefined;
            var frequency_div: ?u64 = undefined;
            var init_once = std.sync.Once(init);

            fn init() void {
                bias = os.windows.QueryPerformanceCounter();
                const frequency = os.windows.QueryPerformanceFrequency();

                const is_frequency_pow_10 = blk: {
                    var input = frequency;
                    while (input > 9 and input % 10 == 0) {
                        input /= 10;
                    }
                    break :blk input == 1;
                };

                if (is_frequency_pow_10) {
                    frequency_div = null;
                    frequency_mul = @divFloor(ns_per_s, frequency);
                } else {
                    frequency_div = ns_per_s;
                    frequency_mul = frequency;
                }
            }

            fn isPowerOf10(input: u64) bool {

            }
        };

        Static.init_once.call();

        var value = os.windows.QueryPerformanceCounter();
        value -%= Static.bias;
        value *= Static.frequency_mul;
        if (Static.frequency_div) |div| {
            value /= div;
        }

        return value;
    }

    if (comptime target.isDarwin()) {
        if (target.os.tag == .ios) {
            // iOS 10+ supports clock_gettime(CLOCK_MONOTONIC) which is 15x faster than sysctl(KERN_BOOTTIME) below.
            if (comptime target.os.version_range.semver.min.major >= 10) {
                var ts: os.timespec = undefined;
                os.clock_gettime(os.CLOCK_MONOTONIC, &ts) catch return null;
                return (@intCast(u64, ts.tv_sec) * ns_per_s) + @intCast(u64, ts.tv_nsec);
            }

            // On iOS, mach_absolute_time() pauses while the device is sleeping.
            // This is quite common for mobile devices so mach_absolute_time() not reliable enough.
            var tv: os.timeval = undefined;
            var tv_size = @sizeOf(@TypeOf(tv));
            const name = &[_]c_int{ os.darwin.CTL_KERN, os.darwin.KERN_BOOTTIME };
            os.sysctl(name, @ptrCast(*c_void, &tv), &tv_size, null, 0) catch return null;
            return (@intCast(u64, tv.tv_sec) * ns_per_s) + (@intCast(u64, ts.tv_usec) * ns_per_us);
        }

        // It appears Apple already does the static caching for us:
        // https://github.com/apple/darwin-xnu/blob/master/libsyscall/wrappers/mach_timebase_info.c
        var info: os.darwin.mach_timebase_info_data_t = undefined;
        if (os.darwin.mach_timebase_info(&info) != os.darwin.KERN_SUCCESS) {
            return null;
        }

        // It also appears that Apple seems unconcerned about overflow and that numer & denom = 1 is common.
        // https://developer.apple.com/library/content/qa/qa1398/_index.html
        var counter = os.darwin.mach_absolute_time();
        if (info.numer != 1) {
            counter *= info.numer;
        }
        if (info.denom != 1) {
            counter /= info.denom;
        }
        return counter;
    }

    if (target.os.tag == .wasi and !builtin.link_libc) {
        var ns: os.wasi.timestamp_t = undefined;
        return switch (os.wasi.clock_time_get(os.wasi.CLOCK_MONOTONIC, 1, &ns)) {
            os.wasi.ESUCCESS => ns,
            else => null,
        };
    }

    if (target.os.tag == .linux or builtin.link_libc) {
        var ts: os.timespec = undefined;
        os.clock_gettime(os.CLOCK_MONOTONIC, &ts) catch return null;
        return (@intCast(u64, ts.tv_sec) * ns_per_s) + @intCast(u64, ts.tv_nsec);
    }

    return null;
}

test "now" {
    const margin = 150 * ns_per_ms;

    const time_0 = now();
    sleep(10 * ns_per_ms);
    const time_1 = now();

    const interval = time_1 - time_0;
    testing.expect(interval >= 0);
    testing.expect(interval < margin);

    const time_2 = now();
    testing.expect(time_2 >= time_1);
    testing.expect(time_2 >= time_0);
}

/// A monotonic, high-precision timer.
/// Timer.start() must be called to initialize the struct,
/// which gives the user an opportunity to check for the existence of a monotonic clock.
pub const Timer = struct {
    start_time: u64,

    pub const Error = error{TimerUnsupported};

    /// Initialize the timer structure,
    /// failing if either the OS or the environment restricts monotonic timing in some fashion.
    pub fn start() Error!Timer {
        var start_time = readSystemTimer() orelse return Error.TimerUnsupported;
        start_time = enforceMonotonic(start_time);
        return Timer{ .start_time = start_time };
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: Timer) u64 {
        return now() -% self.start_time;
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = now();
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        const lap_now = now();
        const lap_time = lap_now -% self.start_time;
        self.start_time = lap_now;
        return lap_time;
    }
};

test "Timer" {
    const margin = 150 * ns_per_ms;

    var timer = try Timer.start();
    sleep(10 * ns_per_ms);
    const time_0 = timer.read();

    testing.expect(time_0 >= 0);
    testing.expect(time_0 < margin);

    const time_1 = timer.lap();
    testing.expect(time_1 >= time_0);

    timer.reset();
    const time_2 = timer.read();
    testing.expect(time_2 < time_1);
}