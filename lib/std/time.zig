const std = @import("std.zig");
const builtin = std.builtin;
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;
const target = std.Target.current;

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
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn timestamp() u64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get a calendar timestamp, in milliseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn milliTimestamp() u64 {
    return @divFloor(nanoTimestamp(), ns_per_ms);
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// On Windows this has a maximum granularity of 100 nanoseconds.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn nanoTimestamp() u64 {
    return Clock.read(.realtime) catch {
        // "Precision of timing depends on hardware and OS".
        return 0;
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
/// the user an opportunity to check for the existnece of monotonic clocks 
/// without forcing them to check for error on each read.
pub const Timer = struct {
    start_time: u64,

    pub const Error = error{TimerUnsupported};

    /// At some point we may change our minds, but for now we're
    /// sticking with posix standard MONOTONIC.
    /// For more information, see: https://github.com/ziglang/zig/pull/933
    const clock_id = Clock.Id.monotonic;

    /// Initialize the timer structure.
    pub fn start() Error!Timer {
        // We assume that if the system is blocking us from using clock_gettime
        // (i.e. with use of linux seccomp), it should at least block us consistently.
        const start_time = Clock.read(clock_id) catch return error.TimerUnsupported;
        return Timer{ .start_time = start_time };
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: Timer) u64 {
        const current = Clock.read(clock_id) catch 0;
        if (current < self.start_time) return 0;
        return current - self.start_time;
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = Clock.read(clock_id) catch 0;
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        const current = Clock.read(clock_id) catch 0;
        defer if (current > self.start_time) {
            self.start_time = current;
        };

        if (current < self.start_time) return 0;
        return current - self.start_time;
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

    pub const Error = error{
        UnsupportedClock
    } || os.UnexpectedError;

    /// Reads the current value of the clock source represented by the `id`.
    pub fn read(id: Id) Error!u64 {
        return Impl.read(id);
    }

    const Impl = switch (target.os.tag) {
        .windows => WindowsImpl,
        else => PosixImpl,
    };

    const PosixImpl = struct {
        pub fn read(id: Id) Error!u64 {
            const clock_id = toOsClockId(id) orelse return error.UnsupportedClock;
            var ts: os.timespec = undefined;
            try os.clock_gettime(clock_id, &ts);
            return @intCast(u64, ts.tv_sec) * ns_per_s + @intCast(u64, ts.tv_nsec);
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
                    .macos, .tvos, .ios, .watchos => os.CLOCK_MONOTONIC_RAW, // mach_continuous_time
                    .linux => os.CLOCK_BOOTTIME, // actually counts time suspended
                    else => os.CLOCK_MONOTONIC,
                },
                .uptime => switch (target.os.tag) {
                    .openbsd, .freebsd, .kfreebsd, .dragonfly => os.CLOCK_UPTIME,
                    .macos, .tvos, .ios, .watchos => os.CLOCK_UPTIME_RAW, // mach_absolute_time
                    .linux => os.CLOCK_MONOTONIC, // doesn't count time suspended
                    else => null,
                },
                .thread_cputime => os.CLOCK_THREAD_CPUTIME_ID,
                .process_cputime => os.CLOCK_PROCESS_CPUTIME_ID,
            };
        }
    };

    const WindowsImpl = struct {
        pub fn read(id: Id) Error!u64 {
            return switch (id) {
                .realtime => getSystemTime(),
                .monotonic => getInterruptTime(),
                .uptime => getUnbiasedInterruptTime(),
                .thread_cputime => getCpuTime("GetThreadTimes", "GetCurrentThread"),
                .process_cputime => getCpuTime("GetProcessTimes", "GetCurrentProcess"),
            };
        }

        fn getSystemTime() u64 {
            var ft: os.windows.FILETIME = undefined;
            os.windows.kernel32.GetSystemTimePreciseAsFileTime(&ft);
            var system_time = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;

            // Returns 0 if the current time is before the Unix Epoch (Jan 1 1970).
            // This can happen since windows' starting epoch is Jan 01, 1601.
            const utc_epoch = -(epoch.windows * (ns_per_s / 100));
            if (system_time <= utc_epoch) {
                return 0;
            }

            const utc_now = system_time - utc_epoch;
            return utc_now * 100;
        }

        /// Could be replaced with QueryInterruptTimePrecise() (only on Windows 10+)
        fn getInterruptTime() u64 {
            const counter = os.windows.QueryPerformanceCounter();
            const qpc = getDeltaTime(struct{}, counter);
            return getQPCInterruptTime(qpc) * 100;
        }

        /// Could be replaced with kernel32.QueryUnbiasedInterruptTimePrecise() (only on Windows 10+)
        fn getUnbiasedInterruptTime() u64 {
            // Compute the unbiased (without suspend) time by sampling the current interrupt time
            // then subtracting the InterruptTimeBias while accounting for possibly suspending mid-sample.
            //
            // https://stackoverflow.com/questions/24330496/how-do-i-create-monotonic-clock-on-windows-which-doesnt-tick-during-suspend
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const KUSER_SHARED_DATA = 0x7ffe0000;
            const InterruptTimeBias = @intToPtr(*volatile u64, KUSER_SHARED_DATA + 0x3b0);

            while (true) {
                const bias = InterruptTimeBias.*;
                const counter = os.windows.QueryPerformanceCounter();
                if (bias != InterruptTimeBias.*) {
                    continue;
                }

                const qpc = getDeltaTime(struct{}, counter);
                const qpc_bias = getDeltaTime(struct{}, bias);
                return (getQPCInterruptTime(qpc) - qpc_bias) * 100;
            }
        }

        fn getQPCInterruptTime(qpc: u64) u64 {
            // doesn't need to be cached. It just reads from KUSER_SHARED_DATA:
            // See the QpcFrequency offset in:
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const frequency = os.windows.QueryPerformanceFrequency();

            // Interrupt time in units of 100ns 
            const scale = ns_per_s / 100; 

            // Try to do qpc * scale / frequency
            var qpc_scaled: u64 = undefined;
            if (!@mulWithOverflow(u64, qpc, scale, &qpc_scaled)) {
                return qpc_scaled / frequency;
            }

            // Does qpc * scale / frequency without overflowing too early
            const div = qpc / frequency;
            const rem = qpc % frequency;
            return (div * scale) + (rem * scale) / frequency;
        }

        /// Globally caches the first `current` supplied using `UniqueType` as a key.
        /// Future calls with the same `UniqueType` return the saturating difference 
        /// between their given `current` and the first cached `current`.
        ///
        /// ```
        /// cached = globals[UniqueType]
        /// if cached == 0:
        ///     cached = globals[UniqueType] = current
        /// if current < cached:
        ///     return 0
        /// return current - cached
        /// ```
        fn getDeltaTime(comptime UniqueType: type, current: u64) u64 {
            _ = UniqueType;

            const Atomic = std.atomic.Atomic;
            const Static = struct {
                var delta = Atomic(u64).init(0);
                var delta_once = os.windows.INIT_ONCE_STATIC_INIT;

                fn initDeltaOnce(once: *os.windows.INIT_ONCE, param: ?*c_void, ctx: ?*c_void) callconv(.C) void {
                    _ = .{ once, ctx };
                    const current_ptr = @ptrCast(*u64, @alignCast(@alignOf(u64), param));
                    delta.storeUnchecked(current_ptr.*);
                }
            };

            const delta = blk: {
                // Use 64bit atomics when available to set delta if it hasn't been already
                if (@sizeOf(usize) >= @sizeOf(u64)) {
                    const delta = Static.delta.load(.Monotonic);
                    if (delta != 0) break :blk delta;
                    break :blk Static.delta.compareAndSwap(
                        delta,
                        current,
                        .Monotonic,
                        .Monotonic,
                    ) orelse current;
                }

                // 64bit atomics aren't supported. Use INIT_ONCE instead
                var init_with = current; 
                os.windows.InitOnceExecuteOnce(
                    &Static.delta_once,
                    Static.initDeltaOnce,
                    @ptrCast(*c_void, &init_with),
                    null,
                );
                break :blk Static.delta.loadUnchecked();
            };

            if (current < delta) return 0;
            return current - delta;
        }

        /// Calls either GetThreadTimes or GetProcessTimes and returns
        /// the amount of nanoseconds spent in userspace and the the kernel.
        fn getCpuTime(comptime GetTimesFn: []const u8, comptime GetCurrentFn: []const u8) !u64 {
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

            var cpu_time = (@as(u64, kernel_time.dwHighDateTime) << 32) | kernel_time.dwLowDateTime;
            cpu_time += (@as(u64, user_time.dwHighDateTime) << 32) | user_time.dwLowDateTime;
            return cpu_time * 100;
        }
    };
};

test "Clock" {
    comptime var clock_ids: []const Clock.Id = &[_]Clock.Id{};
    inline for (std.meta.fields(Clock.Id)) |field| {
        const clock_id = @field(Clock.Id, field.name);
        clock_ids = clock_ids ++ [_]Clock.Id{ clock_id };
    }

    for (clock_ids) |clock_id| {
        _ = Clock.read(clock_id) catch |err| {
            // Only return errors for clock sources that we use personally.
            // The rest are just tested for their code paths
            switch (clock_id) {
                .realtime, .monotonic => return err,
                else => continue,
            }
        };
    }
}