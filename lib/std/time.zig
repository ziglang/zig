const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;
const is_windows = builtin.os.tag == .windows;

pub const epoch = @import("time/epoch.zig");

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
            .id = w.CLOCK.MONOTONIC,
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

/// Get a calendar timestamp, in seconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn timestamp() i64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get a calendar timestamp, in milliseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn milliTimestamp() i64 {
    return @intCast(i64, @divFloor(nanoTimestamp(), ns_per_ms));
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// On Windows this has a maximum granularity of 100 nanoseconds.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn nanoTimestamp() i128 {
    return Clock.read(.realtime) catch |err| switch (err) {
        // "Precision of timing depends on hardware and OS".
        error.UnsupportedClock, error.Unexpected => 0,
    };
}

test "timestamp" {
    const margin = ns_per_ms * 50;

    const time_0 = milliTimestamp();
    sleep(ns_per_ms);
    const time_1 = milliTimestamp();
    const interval = time_1 - time_0;
    try testing.expect(interval > 0);
    // Tests should not depend on timings: skip test if outside margin.
    if (!(interval < margin)) return error.SkipZigTest;
}

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

/// A high-performance timer that tries to be monotonically increasing.
/// Timer.start() must be called to initialize the struct, which gives 
/// the user an opportunity to check for the existence of such timers 
/// without forcing them to check for an error on each read.
pub const Timer = struct {
    start_time: i128,

    pub const Error = error{TimerUnsupported};

    // This is a clock source which is supported on most platforms and is mostly monotonic.
    const clock_id = Clock.Id.monotonic;

    /// Initialize the timer structure.
    pub fn start() Error!Timer {
        // We assume that if the system is blocking us from using the Clock
        // (i.e. with use of linux seccomp), it should at least block us consistently.
        return Timer{
            .start_time = Clock.read(clock_id) catch return error.TimerUnsupported,
        };
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: Timer) u64 {
        const current = clockNative();
        return self.toDurationNanos(current);
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = clockNative();
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        const current = clockNative();
        defer self.start_time = current;
        return self.toDurationNanos(current);
    }

    /// Returns the current value of the Timer's clock.
    /// Should not error out since the existence of the clock was checked at start().
    fn clockNative() i128 {
        return Clock.read(clock_id) catch unreachable;
    }

    /// Converts a reading from the Timer's clock to nanoseconds since the start_time.
    fn toDurationNanos(self: Timer, current: i128) u64 {
        // Handle cases where the clock goes backwards
        if (current < self.start_time) return 0;

        // Saturating subtraction from the current time to handle overflows.
        const duration = current - self.start_time;
        return std.math.cast(u64, duration) catch std.math.maxInt(u64);
    }
};

test "Timer" {
    const margin = ns_per_ms * 150;

    var timer = try Timer.start();
    sleep(10 * ns_per_ms);
    const time_0 = timer.read();
    try testing.expect(time_0 > 0);
    // Tests should not depend on timings: skip test if outside margin.
    if (!(time_0 < margin)) return error.SkipZigTest;

    const time_1 = timer.lap();
    try testing.expect(time_1 >= time_0);

    timer.reset();
    try testing.expect(timer.read() < time_1);
}

test {
    _ = @import("time/epoch.zig");
}

pub const Clock = struct {
    /// Id represents the type of clock source to interact with.
    /// Each clock sources may start, tick, and change in different ways.
    pub const Id = enum {
        /// Returns nanoseconds since Unix Epoch (Jan 1 1970)
        realtime,
        /// Returns nanoseconds since an arbitrary point in time. Increments while suspended
        monotonic,
        /// Returns nanoseconds since an arbitrary point in time. Pauses while suspended.
        uptime,
        /// Returns nanoseconds of cpu time spent by the caller's thread.
        thread_cputime,
        /// Returns nanoseconds of cpu time spent all threads in the caller's process
        process_cputime,
    };

    pub const Error = error{UnsupportedClock} || os.UnexpectedError;

    /// Reads the current value of the clock source represented by the `id`.
    pub fn read(id: Id) Error!i128 {
        return Impl.read(id);
    }

    const Impl = switch (target.os.tag) {
        .windows => WindowsImpl,
        else => PosixImpl,
    };

    const PosixImpl = struct {
        pub fn read(id: Id) Error!i128 {
            const clock_id = toOsClockId(id) orelse return error.UnsupportedClock;
            var ts: os.timespec = undefined;
            try os.clock_gettime(clock_id, &ts);
            return (@as(i128, ts.tv_sec) * ns_per_s) + ts.tv_nsec;
        }

        // https://github.com/polazarus/oclock-testing/blob/master/docs/clock_gettime.md
        //
        // https://linux.die.net/man/2/clock_gettime
        // https://opensource.apple.com/source/Libc/Libc-1439.40.11/gen/clock_gettime.c.auto.html
        // https://man.openbsd.org/clock_gettime.2
        // https://man.netbsd.org/amd64/clock_gettime.2
        // https://github.com/WebAssembly/WASI/blob/main/phases/snapshot/docs.md#-clockid-variant
        // https://man.dragonflybsd.org/?command=clock_gettime&section=2
        // https://www.freebsd.org/cgi/man.cgi?query=clock_gettime
        fn toOsClockId(id: Id) ?i32 {
            return switch (id) {
                .realtime => os.CLOCK_REALTIME,
                .monotonic => switch (target.os.tag) {
                    // Calls mach_continuous_time() internally
                    .macos, .tvos, .ios, .watchos => os.CLOCK_MONOTONIC_RAW,
                    // Unlike CLOCK_MONOTONIC, this actually counts time suspended (true POSIX MONOTONIC)
                    .linux => os.CLOCK_BOOTTIME,
                    else => os.CLOCK_MONOTONIC,
                },
                .uptime => switch (target.os.tag) {
                    .openbsd, .freebsd, .kfreebsd, .dragonfly => os.CLOCK_UPTIME,
                    // Calls mach_absolute_time() internally
                    .macos, .tvos, .ios, .watchos => os.CLOCK_UPTIME_RAW,
                    // CLOCK_MONOTONIC on linux actually doesn't count time suspended (not POSIX compliant).
                    // At some point we may change our minds on CLOCK_MONOTONIC_RAW,
                    // but for now we're sticking with CLOCK_MONOTONIC standard.
                    // For more information, see: https://github.com/ziglang/zig/pull/933
                    .linux => os.CLOCK_MONOTONIC, // doesn't count time suspended
                    // Platforms like wasi and netbsd don't support getting time without suspend
                    else => null,
                },
                .thread_cputime => os.CLOCK_THREAD_CPUTIME_ID,
                .process_cputime => os.CLOCK_PROCESS_CPUTIME_ID,
            };
        }
    };

    const WindowsImpl = struct {
        const is_windows_10 = target.os.isAtLeast(.windows, .win10) orelse false;

        pub fn read(id: Id) Error!i128 {
            return switch (id) {
                .realtime => getSystemTime(),
                .monotonic => getInterruptTime(),
                .uptime => getUnbiasedInterruptTime(),
                .thread_cputime => getCpuTime("GetThreadTimes", "GetCurrentThread"),
                .process_cputime => getCpuTime("GetProcessTimes", "GetCurrentProcess"),
            };
        }

        fn getSystemTime() i128 {
            var ft: os.windows.FILETIME = undefined;
            os.windows.kernel32.GetSystemTimePreciseAsFileTime(&ft);
            const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;

            // FileTime has a granularity of 100ns and uses the NTFS/Windows epoch
            // which is 1601-01-01
            const epoch_adj = epoch.windows * (ns_per_s / 100);
            return @as(i128, @bitCast(i64, ft64) + epoch_adj) * 100;
        }

        fn getInterruptTime() i128 {
            // TODO: Disabled for now as lld-link fails to find the symbol
            //
            // Use the QueryInterruptTimePrecise() function when available.
            // Don't use the non-Precise variant as it's less granular (0.5ms-16ms) than QPC (<=1us)
            // https://docs.microsoft.com/en-us/windows/win32/api/realtimeapiset/nf-realtimeapiset-queryinterrupttimeprecise#remarks
            if (false and is_windows_10) {
                var interrupt_time: os.windows.ULONGLONG = undefined;
                os.windows.kernel32.QueryInterruptTimePrecise(&interrupt_time);
                return interrupt_time * 100;
            }

            const counter = os.windows.QueryPerformanceCounter();
            return getQPCInterruptTime(counter, 0);
        }

        fn getUnbiasedInterruptTime() i128 {
            // TODO: Disabled for now as lld-link fails to find the symbol
            //
            // Use the QueryUnbiasedInterruptTimePrecise() functions when available.
            // Don't use the non-Precise variant as it's less granular (0.5ms-16ms) than QPC (<=1us)
            // https://docs.microsoft.com/en-us/windows/win32/api/realtimeapiset/nf-realtimeapiset-queryinterrupttimeprecise#remarks
            if (false and is_windows_10) {
                var interrupt_time: os.windows.ULONGLONG = undefined;
                os.windows.kernel32.QueryUnbiasedInterruptTimePrecise(&interrupt_time);
                return interrupt_time * 100;
            }

            // Compute the unbiased (without suspend) time by sampling the current interrupt time
            // then subtracting the InterruptTimeBias while accounting for possibly suspending mid-sample.
            // https://stackoverflow.com/questions/24330496/how-do-i-create-monotonic-clock-on-windows-which-doesnt-tick-during-suspend
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const KUSER_SHARED_DATA = 0x7ffe0000;
            const InterruptTimeBias = @intToPtr(*volatile u64, KUSER_SHARED_DATA + 0x3b0);

            while (true) {
                const bias = InterruptTimeBias.*;
                const counter = os.windows.QueryPerformanceCounter();
                if (bias == InterruptTimeBias.*) {
                    return getQPCInterruptTime(counter, bias);
                }
            }
        }

        fn getQPCInterruptTime(qpc: u64, bias: u64) i128 {
            // QueryPerofrmanceFrequency() doesn't need to be cached.
            // It just reads from KUSER_SHARED_DATA.
            // See the QpcFrequency offset in:
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const frequency = os.windows.QueryPerformanceFrequency();

            // Convert QPC in units of 100ns since this is the granularity of InterruptTimeBias.
            const scale = ns_per_s / 100;

            // Performs (qpc * scale) / frequency without overflow.
            var interrupt_time = blk: {
                const overflow_limit = @divFloor(std.math.maxInt(u64), scale);
                if (qpc <= overflow_limit) {
                    break :blk (qpc * scale) / frequency;
                }

                // Computes (qpc * scale) / frequency without overflow
                // as long as both (scale * frequency) and the final result fit into an i64
                // which should be the case for time conversions with QPC.
                const quotient = qpc / frequency;
                const remainder = qpc % frequency;
                break :blk (quotient * scale) + (remainder * scale) / frequency;
            };

            // Finally subtract the bias (zero for .monotonic) and scale back up to nanoseconds
            interrupt_time -= bias;
            return interrupt_time * 100;
        }

        /// Calls either GetThreadTimes or GetProcessTimes and returns
        /// the amount of nanoseconds spent in userspace and the the kernel.
        fn getCpuTime(comptime GetTimesFn: []const u8, comptime GetCurrentFn: []const u8) !i128 {
            var creation_time: os.windows.FILETIME = undefined;
            var exit_time: os.windows.FILETIME = undefined;
            var kernel_time: os.windows.FILETIME = undefined;
            var user_time: os.windows.FILETIME = undefined;

            const result = @field(os.windows.kernel32, GetTimesFn)(
                @field(os.windows.kernel32, GetCurrentFn)(),
                &creation_time,
                &exit_time,
                &kernel_time,
                &user_time,
            );

            if (result == 0) {
                const err = os.windows.kernel32.GetLastError();
                return os.windows.unexpectedError(err);
            }

            var cpu_time: i128 = (@as(u64, kernel_time.dwHighDateTime) << 32) | kernel_time.dwLowDateTime;
            cpu_time += (@as(u64, user_time.dwHighDateTime) << 32) | user_time.dwLowDateTime;
            return cpu_time * 100;
        }
    };
};

test "Clock" {
    inline for (std.meta.fields(Clock.Id)) |field| {
        const clock_id = @field(Clock.Id, field.name);

        // Only return errors for clock sources that we use personally.
        // The rest are just tested for their code paths
        _ = switch (clock_id) {
            .realtime, .monotonic => try Clock.read(clock_id),
            else => Clock.read(clock_id) catch undefined,
        };
    }
}
