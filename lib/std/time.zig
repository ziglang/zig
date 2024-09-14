const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const math = std.math;
const windows = std.os.windows;
const posix = std.posix;

pub const epoch = @import("time/epoch.zig");

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    if (builtin.os.tag == .windows) {
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(windows.DWORD, big_ms_from_ns) orelse math.maxInt(windows.DWORD);
        windows.kernel32.Sleep(ms);
        return;
    }

    if (builtin.os.tag == .wasi) {
        const w = std.os.wasi;
        const userdata: w.userdata_t = 0x0123_45678;
        const clock: w.subscription_clock_t = .{
            .id = .MONOTONIC,
            .timeout = nanoseconds,
            .precision = 0,
            .flags = 0,
        };
        const in: w.subscription_t = .{
            .userdata = userdata,
            .u = .{
                .tag = .CLOCK,
                .u = .{ .clock = clock },
            },
        };

        var event: w.event_t = undefined;
        var nevents: usize = undefined;
        _ = w.poll_oneoff(&in, &event, 1, &nevents);
        return;
    }

    if (builtin.os.tag == .uefi) {
        const boot_services = std.os.uefi.system_table.boot_services.?;
        const us_from_ns = nanoseconds / ns_per_us;
        const us = math.cast(usize, us_from_ns) orelse math.maxInt(usize);
        _ = boot_services.stall(us);
        return;
    }

    const s = nanoseconds / ns_per_s;
    const ns = nanoseconds % ns_per_s;

    // Newer kernel ports don't have old `nanosleep()` and `clock_nanosleep()` has been around
    // since Linux 2.6 and glibc 2.1 anyway.
    if (builtin.os.tag == .linux) {
        const linux = std.os.linux;

        var req: linux.timespec = .{
            .sec = std.math.cast(linux.time_t, s) orelse std.math.maxInt(linux.time_t),
            .nsec = std.math.cast(linux.time_t, ns) orelse std.math.maxInt(linux.time_t),
        };
        var rem: linux.timespec = undefined;

        while (true) {
            switch (linux.E.init(linux.clock_nanosleep(.MONOTONIC, .{ .ABSTIME = false }, &req, &rem))) {
                .SUCCESS => return,
                .INTR => {
                    req = rem;
                    continue;
                },
                .FAULT,
                .INVAL,
                .OPNOTSUPP,
                => unreachable,
                else => return,
            }
        }
    }

    posix.nanosleep(s, ns);
}

test sleep {
    sleep(1);
}

/// Get a calendar timestamp, in seconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `posix.clock_gettime` for a POSIX timestamp.
pub fn timestamp() i64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get a calendar timestamp, in milliseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `posix.clock_gettime` for a POSIX timestamp.
pub fn milliTimestamp() i64 {
    return @as(i64, @intCast(@divFloor(nanoTimestamp(), ns_per_ms)));
}

/// Get a calendar timestamp, in microseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `posix.clock_gettime` for a POSIX timestamp.
pub fn microTimestamp() i64 {
    return @as(i64, @intCast(@divFloor(nanoTimestamp(), ns_per_us)));
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// On Windows this has a maximum granularity of 100 nanoseconds.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `posix.clock_gettime` for a POSIX timestamp.
pub fn nanoTimestamp() i128 {
    switch (builtin.os.tag) {
        .windows => {
            // FileTime has a granularity of 100 nanoseconds and uses the NTFS/Windows epoch,
            // which is 1601-01-01.
            const epoch_adj = epoch.windows * (ns_per_s / 100);
            var ft: windows.FILETIME = undefined;
            windows.kernel32.GetSystemTimeAsFileTime(&ft);
            const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
            return @as(i128, @as(i64, @bitCast(ft64)) + epoch_adj) * 100;
        },
        .wasi => {
            var ns: std.os.wasi.timestamp_t = undefined;
            const err = std.os.wasi.clock_time_get(.REALTIME, 1, &ns);
            assert(err == .SUCCESS);
            return ns;
        },
        .uefi => {
            var value: std.os.uefi.Time = undefined;
            const status = std.os.uefi.system_table.runtime_services.getTime(&value, null);
            assert(status == .Success);
            return value.toEpoch();
        },
        else => {
            var ts: posix.timespec = undefined;
            posix.clock_gettime(.REALTIME, &ts) catch |err| switch (err) {
                error.UnsupportedClock, error.Unexpected => return 0, // "Precision of timing depends on hardware and OS".
            };
            return (@as(i128, ts.sec) * ns_per_s) + ts.nsec;
        },
    }
}

test milliTimestamp {
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

/// An Instant represents a timestamp with respect to the currently
/// executing program that ticks during suspend and can be used to
/// record elapsed time unlike `nanoTimestamp`.
///
/// It tries to sample the system's fastest and most precise timer available.
/// It also tries to be monotonic, but this is not a guarantee due to OS/hardware bugs.
/// If you need monotonic readings for elapsed time, consider `Timer` instead.
pub const Instant = struct {
    timestamp: if (is_posix) posix.timespec else u64,

    // true if we should use clock_gettime()
    const is_posix = switch (builtin.os.tag) {
        .windows, .uefi, .wasi => false,
        else => true,
    };

    /// Queries the system for the current moment of time as an Instant.
    /// This is not guaranteed to be monotonic or steadily increasing, but for
    /// most implementations it is.
    /// Returns `error.Unsupported` when a suitable clock is not detected.
    pub fn now() error{Unsupported}!Instant {
        const clock_id = switch (builtin.os.tag) {
            .windows => {
                // QPC on windows doesn't fail on >= XP/2000 and includes time suspended.
                return Instant{ .timestamp = windows.QueryPerformanceCounter() };
            },
            .wasi => {
                var ns: std.os.wasi.timestamp_t = undefined;
                const rc = std.os.wasi.clock_time_get(.MONOTONIC, 1, &ns);
                if (rc != .SUCCESS) return error.Unsupported;
                return .{ .timestamp = ns };
            },
            .uefi => {
                var value: std.os.uefi.Time = undefined;
                const status = std.os.uefi.system_table.runtime_services.getTime(&value, null);
                if (status != .Success) return error.Unsupported;
                return Instant{ .timestamp = value.toEpoch() };
            },
            // On darwin, use UPTIME_RAW instead of MONOTONIC as it ticks while
            // suspended.
            .macos, .ios, .tvos, .watchos, .visionos => posix.CLOCK.UPTIME_RAW,
            // On freebsd derivatives, use MONOTONIC_FAST as currently there's
            // no precision tradeoff.
            .freebsd, .dragonfly => posix.CLOCK.MONOTONIC_FAST,
            // On linux, use BOOTTIME instead of MONOTONIC as it ticks while
            // suspended.
            .linux => posix.CLOCK.BOOTTIME,
            // On other posix systems, MONOTONIC is generally the fastest and
            // ticks while suspended.
            else => posix.CLOCK.MONOTONIC,
        };

        var ts: posix.timespec = undefined;
        posix.clock_gettime(clock_id, &ts) catch return error.Unsupported;
        return .{ .timestamp = ts };
    }

    /// Quickly compares two instances between each other.
    pub fn order(self: Instant, other: Instant) std.math.Order {
        // windows and wasi timestamps are in u64 which is easily comparible
        if (!is_posix) {
            return std.math.order(self.timestamp, other.timestamp);
        }

        var ord = std.math.order(self.timestamp.sec, other.timestamp.sec);
        if (ord == .eq) {
            ord = std.math.order(self.timestamp.nsec, other.timestamp.nsec);
        }
        return ord;
    }

    /// Returns elapsed time in nanoseconds since the `earlier` Instant.
    /// This assumes that the `earlier` Instant represents a moment in time before or equal to `self`.
    /// This also assumes that the time that has passed between both Instants fits inside a u64 (~585 yrs).
    pub fn since(self: Instant, earlier: Instant) u64 {
        if (builtin.os.tag == .windows) {
            // We don't need to cache QPF as it's internally just a memory read to KUSER_SHARED_DATA
            // (a read-only page of info updated and mapped by the kernel to all processes):
            // https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/ntddk/ns-ntddk-kuser_shared_data
            // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
            const qpc = self.timestamp - earlier.timestamp;
            const qpf = windows.QueryPerformanceFrequency();

            // 10Mhz (1 qpc tick every 100ns) is a common enough QPF value that we can optimize on it.
            // https://github.com/microsoft/STL/blob/785143a0c73f030238ef618890fd4d6ae2b3a3a0/stl/inc/chrono#L694-L701
            const common_qpf = 10_000_000;
            if (qpf == common_qpf) {
                return qpc * (ns_per_s / common_qpf);
            }

            // Convert to ns using fixed point.
            const scale = @as(u64, std.time.ns_per_s << 32) / @as(u32, @intCast(qpf));
            const result = (@as(u96, qpc) * scale) >> 32;
            return @as(u64, @truncate(result));
        }

        // WASI timestamps are directly in nanoseconds
        if (builtin.os.tag == .wasi) {
            return self.timestamp - earlier.timestamp;
        }

        // Convert timespec diff to ns
        const seconds = @as(u64, @intCast(self.timestamp.sec - earlier.timestamp.sec));
        const elapsed = (seconds * ns_per_s) + @as(u32, @intCast(self.timestamp.nsec));
        return elapsed - @as(u32, @intCast(earlier.timestamp.nsec));
    }
};

/// A monotonic, high performance timer.
///
/// Timer.start() is used to initialize the timer
/// and gives the caller an opportunity to check for the existence of a supported clock.
/// Once a supported clock is discovered,
/// it is assumed that it will be available for the duration of the Timer's use.
///
/// Monotonicity is ensured by saturating on the most previous sample.
/// This means that while timings reported are monotonic,
/// they're not guaranteed to tick at a steady rate as this is up to the underlying system.
pub const Timer = struct {
    started: Instant,
    previous: Instant,

    pub const Error = error{TimerUnsupported};

    /// Initialize the timer by querying for a supported clock.
    /// Returns `error.TimerUnsupported` when such a clock is unavailable.
    /// This should only fail in hostile environments such as linux seccomp misuse.
    pub fn start() Error!Timer {
        const current = Instant.now() catch return error.TimerUnsupported;
        return Timer{ .started = current, .previous = current };
    }

    /// Reads the timer value since start or the last reset in nanoseconds.
    pub fn read(self: *Timer) u64 {
        const current = self.sample();
        return current.since(self.started);
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        const current = self.sample();
        self.started = current;
    }

    /// Returns the current value of the timer in nanoseconds, then resets it.
    pub fn lap(self: *Timer) u64 {
        const current = self.sample();
        defer self.started = current;
        return current.since(self.started);
    }

    /// Returns an Instant sampled at the callsite that is
    /// guaranteed to be monotonic with respect to the timer's starting point.
    fn sample(self: *Timer) Instant {
        const current = Instant.now() catch unreachable;
        if (current.order(self.previous) == .gt) {
            self.previous = current;
        }
        return self.previous;
    }
};

test Timer {
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
    _ = epoch;
}
