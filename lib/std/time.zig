const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;
const maxInt = math.maxInt;
const minInt = math.minInt;

const is_windows = builtin.os.tag == .windows;
const is_darwin = builtin.os.tag.isDarwin();

pub const epoch = @import("time/epoch.zig");
pub const utc2018 = @import("time/utc2018.zig");

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    // TODO: opting out of async sleeping?
    if (std.io.is_async) {
        return std.event.Loop.instance.?.sleep(nanoseconds);
    }

    if (is_windows) {
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(os.windows.DWORD, big_ms_from_ns) catch math.maxInt(os.windows.DWORD);
        os.windows.kernel32.Sleep(ms);
        return;
    }

    if (builtin.os.tag == .wasi) {
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

pub fn timestamp() i64 {
    @compileError("timestamp is deprecated. Consider (milliMonotonic() / std.time.ms_per_s) instead.");
}

pub fn milliTimestamp() i64 {
    @compileError("milliTimestamp is deprecated. You probably want milliMonotonic() instead.");
}

pub fn nanoTimestamp() i128 {
    @compileError("nanoTimestamp is deprecated. See `std.os.clock_gettime` for a POSIX timestamp. See timestampNow() or nanoMonotonic().");
}

var global_timer_started = false;
var global_timer: Timer = undefined;

/// Get a monotonic counter, in nanoseconds, relative to the first call to this function.
/// Precision of timing depends on the hardware and operating system.
/// Increments while suspended.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn nanoMonotonic() u64 {
    if (!global_timer_started) {
        global_timer = Timer.start() catch return 0;
        global_timer_started = true;
        return 0;
    }

    return global_timer.read();
}

/// Get a monotonic counter, in milliseconds, relative to the first call to nanoMonotonic().
/// Precision of timing depends on the hardware and operating system.
/// Increments while suspended.
pub fn milliMonotonic() u64 {
    return nanoMonotonic() / ns_per_ms;
}

/// timestampNow() provides a canonical timestamp for use in the Zig std library.
/// 
/// Windows: FILETIME is stable and doesn't have leap seconds. It's now (as of June 2018 update) 
/// defined as Utc2018 and will stay that way. Windows has APIs to convert to UTC that takes 
/// into account leap seconds after 2018 and is kept up-to-date with Windows Update.
/// 
/// POSIX: If CLOCK_TAI appears configured, use that. Then use a compile-time constant (always 37)
/// to convert to Utc2018. However, CLOCK_TAI is often unconfigured (zero or 1 delta from
/// CLOCK_REALTIME). If unconfigured, (or unavailable), make the assumption that there are no
/// more UTC leap seconds after 2018. .wasi and darwin do not currently support CLOCK_TAI.
///                           !!!WARNING!!! 
/// If a leap second is announced (WHY?!), the above assumption MUST be revisited.
/// Non-Windows Zig code deployed into distributed systems that care about accurate 
/// timestamps (and doesn't configure CLOCK_TAI) needs to be updated and re-compiled after 
/// a leap second is declared.
/// Consider letting the International Telecommunications Union know exactly what you think 
/// of leap seconds. As of 2021, they are considering removing them going forward.
///
/// This returns ticks since Zig's Utc2018 Epoch: 1601-01-01T00:00:00 in 2018's UTC assuming no
/// leap seconds. However, Leap seconds are real, so the actual start of the Utc2018 Epoch is
/// represented as "1601-01-01T00:00:27". These timestamps don't jump around on leap seconds.
/// This handles errors by returning zero.
/// These are the same timestamps used by std.fs.File.Stat
/// See `std.os.clock_gettime` for a POSIX timestamp.
/// These ticks represent 2^60 Hz. This is silly large (no computer actually has a clock this
/// fast), but it leaves room for future increases in precision.
/// It's a fixed-point value in (36.60) format.
/// Notice it's unsigned: Values prior to the Gregorian calendar make no sense.
/// 36 bits for seconds allows timestamps between year 1601 and year 3776
/// Shift right by 60 to get seconds with no fractional part.
/// For a more reasonable precision, consider shifting right by 32 and truncating to a u64.
/// This leaves a fixed-point value (36.28 format).
/// 28 bits for fraction gives ~3.7ns precision (2^28 Hz = 268_435_456 Hz)
/// NOTE: This suffers from discontinuities due to NTP initialization or manual time changes.
pub fn timestampNow() u96 {
    // "Precision of timing depends on hardware and OS".
    return TimestampImpl.timestampNow();
}

/// Maximum accepted time is 3776-12-31T23:59:59.999999999... (value 0xFFEF7E9FF_FFFFFFFFFFFFFFF)
/// This value lets CalendarTime just check the year component for validity when parsing, rather
/// than having a CalendarTime stop working partway through the year 3777.
pub const max_st = 0xFFEF7E9FF_FFFFFFFFFFFFFFF;
pub const max_seconds = 0xFFEF7E9FF;

// Fixed-Point multipler to turn nanoseconds into 36.60 StdTime
const ns_scale_st_36_60: u96 = (1 << 60) / ns_per_s;

// Fixed-Point multipler to turn FILETIME units into 36.60 StdTime
const filetime_scale_st_36_60: u96 = (1 << 60) / (ns_per_s / 100);

const TimestampImpl = if (is_windows) WindowsTimestampImpl else PosixTimestampImpl;

const PosixTimestampImpl = struct {
    // The CLOCK_ID to use in os.clock_gettime() to get Utc2018.
    // Must be detected with detectClockId().
    var clock_id: i32 = math.maxInt(i32);

    // The offset (in seconds) to get Utc2018. Must be detected with detectClockId().
    var clock_offset: u8 = 0;

    fn detectClockId() !void {
        while (true) {
            var utc_ts: os.timespec = undefined;
            os.clock_gettime(os.CLOCK.REALTIME, &utc_ts) catch return error.UnsupportedClock;

            if (builtin.os.tag == .wasi) {
                clock_id = os.CLOCK.REALTIME;
                return;
            }

            if (comptime builtin.target.isDarwin()) {
                clock_id = os.CLOCK.REALTIME;
                return;
            }

            var tai_ts: os.timespec = undefined;
            os.clock_gettime(os.CLOCK.TAI, &tai_ts) catch {
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
                return;
            };

            var utc_ts2: os.timespec = undefined;
            try os.clock_gettime(os.CLOCK.REALTIME, &utc_ts2);
            if (utc_ts.tv_sec != utc_ts2.tv_sec) {
                // tv_sec rolled over between utc_ts and utc_ts2, try again.
                // Shouldn't happen a second time
                continue;
            }

            const offset = tai_ts.tv_sec - utc_ts.tv_sec;
            if (offset < 0) {
                // Offset doesn't make any sense: No possible way that Earth spun up that much.
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
            } else if (offset <= 1) {
                // Assume the epoch of CLOCK_TAI is 2018's UTC (assuming no leap seconds).
                clock_id = os.CLOCK.TAI;
                clock_offset = 0;
            } else if (offset > 1000) {
                // CLOCK_TAI seems to be configured, but the offset doesn't make any sense:
                // No possible way that Earth slowed down its spin that much.
                // CLOCK.TAI unsupported, use CLOCK_REALTIME and assume no leap seconds
                clock_id = os.CLOCK.REALTIME;
            } else {
                // CLOCK_TAI is configured, assume it's actually TAI.
                clock_id = os.CLOCK.TAI;

                // Use the constant offset between TAI and Utc2018.
                clock_offset = utc2018.tai_offset;
            }
        }
    }

    /// This implementation tries to use CLOCK_TAI to give consistent Utc2018 time
    /// but has a fallback that just assumes CLOCK_REALTIME is in 2018's UTC.
    fn timestampNow() u96 {
        if (clock_id == math.maxInt(i32)) {
            // Unknown clock_id, run the detection algorithm once
            detectClockId() catch return 0;
        }

        var ts: os.timespec = undefined;
        os.clock_gettime(clock_id, &ts) catch return 0;

        // Convert to Utc2018 seconds
        const seconds = @intCast(u96, ts.tv_sec) + utc2018.epoch.posix - clock_offset;

        // Fixed-point math. Move to the left for 60 bits of fraction.
        const seconds_36_60 = seconds << 60;

        // Convert from 1ns units to seconds.
        // Fractional part remains in the 60 lowest bits.
        const st_36_60 = seconds_36_60 + (@intCast(u96, ts.tv_nsec) * ns_scale_st_36_60);
        return st_36_60;
    }
};

const WindowsTimestampImpl = struct {

    /// This implementation returns consistent Utc2018 time
    fn timestampNow() u96 {
        // FileTime has a granularity of 100ns and uses the NTFS/Windows epoch.
        // Matches Zig's Utc2018 epoch.
        // Explicitly doesn't have leap seconds (as of June 2018).
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimePreciseAsFileTime(&ft);

        // Fixed-point math. Scales to 60 bits of fraction.
        // Convert from 100ns units to seconds. 10_000_000 100ns units per second.
        // Fractional part remains in the 60 lowest bits.
        const st_36_60 = @as(u96, ft) * filetime_scale_st_36_60;
        return st_36_60;
    }
};

/// This is timestampNow() but with a more reasonable precision.
/// This returns a fixed-point value (36.28 format).
/// 28 bits for fraction gives ~3.7ns precision (2^28 Hz = 268_435_456 Hz)
/// Shift right by 28 to get seconds with no fractional part.
/// NOTE: See timestampNow() for details.
pub fn timestampNow64() !u64 {
    return reducePrecisionStdTime(TimestampImpl.timestampNow());
}

test "milliMonotonic" {
    const margin = ns_per_ms * 50;

    const time_0 = milliMonotonic();
    sleep(ns_per_ms);
    const time_1 = milliMonotonic();
    const interval = time_1 - time_0;
    try testing.expect(interval > 0);
    // Tests should not depend on timings: skip test if outside margin.
    if (!(interval < margin)) return error.SkipZigTest;
}

pub const one_ms_in_std_time = stdTimeFromSeconds(1) / ms_per_s;
pub const one_ns_in_std_time = stdTimeFromSeconds(1) / ns_per_s;

test "timestampNow" {
    const margin = one_ms_in_std_time * 50;

    const time_0 = timestampNow();
    sleep(ns_per_ms);
    const time_1 = timestampNow();
    const interval = time_1 - time_0;
    try testing.expect(interval > 0);
    // Tests should not depend on timings: skip test if outside margin.
    if (!(interval < margin)) return error.SkipZigTest;
}

// TODO: Should 'StdTime' just be 'Timestamp' in the 'time' namespace?
pub fn stdTimeFromSeconds(s: u36) u96 {
    // Zig std time in fixed-point 36.60
    // The 60 bits of fraction are zero in this case
    return @as(u96, s) << 60;
}

pub fn secondsPartOfStdTime(st: u96) u36 {
    // Zig std time in fixed-point 36.60
    // Shift out the 60 bits of fraction
    return @truncate(u36, st >> 60);
}

/// std time is in 36.60 fixed-point format.
/// This truncates out the 36 bits of 'seconds' and returns the fractional part converted to
/// nanoseconds.
pub fn nsPartOfStdTime(st: u96) u30 {
    // Truncate to the fractional part in the lower 60 bits.
    const fraction = @truncate(u60, st + 1);

    // Add 30 bits to work with.
    // Multiply by the number of ns_per_s.
    const ns = @as(u90, fraction) * ns_per_s;

    // Shift out the fractional part.
    return @truncate(u30, ns >> 60);
}

pub fn reducePrecisionStdTime(st: u96) u64 {
    // Zig std time in fixed-point 36.60
    // Shift out 32 bits of fraction
    return @truncate(u64, st >> 32);
}

/// This converts a POSIX timespec into canonical Zig 'std' time in Utc2018, specified 
/// in 36.60 fixed-point.
/// NOTE: POSIX timespec are technically in "Fuzzy UTC", which means they are are offset by a 
///       slightly fuzzy number of leap seconds: 
///       If needed, use convertUtcFuzzyToUtc2018(stdTimeFromPosixTime(ts)) to make 
///       a best-estimate conversion using a compile-time table of past leap seconds.
pub fn stdTimeFromPosixTime(ts: os.timespec) u96 {
    // Clamp max values
    const seconds_posix = if (@bitSizeOf(@TypeOf(ts.tv_sec)) <= 37)
        @as(i37, ts.tv_sec)
    else if (ts.tv_sec > maxInt(u36))
        maxInt(u36)
    else if (ts.tv_sec < minInt(i37))
        minInt(i37)
    else
        @truncate(i37, ts.tv_sec);

    const ns = if (ts.tv_nsec > 999_999_999)
        999_999_999
    else if (ts.tv_nsec < 0)
        0
    else
        @intCast(u96, ts.tv_nsec);

    // Shift the epoch to zig std Utc2018
    var seconds_utc2018 = math.add(i37, seconds_posix, utc2018.epoch.posix) catch maxInt(u36);

    // timestamps prior to 0 aka. "1601-01-01T00:00:27" are not expressible
    if (seconds_utc2018 < 0)
        seconds_utc2018 = 0;

    // Fixed-point math. Move to the left for 60 bits of fraction.
    const seconds_36_60 = @intCast(u96, seconds_utc2018) << 60;

    // Add 0.5 ns (half a tv_nsec unit) to be closer to the real value, this helps when converting
    // the fraction back to 'nanoseconds' to get the expected value after simple truncation rounding
    const ns_36_60 = (ns << 60) + (one_ns_in_std_time / 2);

    // Convert from 1ns units to seconds.
    // Fractional part remains in the 60 lowest bits.
    return seconds_36_60 + (ns_36_60 / ns_per_s);
}

/// This converts a canonical Zig 'std' time in Utc2018 (specified in 36.60 fixed-point) into
/// a POSIX timespec.
/// NOTE: POSIX timespec are technically in "Fuzzy UTC", which means they are are offset by a 
///       slightly fuzzy number of leap seconds: 
///       If needed, use posixTimeFromStdTime(convertUtc2018ToUtcFuzzy(st)) to make 
///       a best-estimate conversion using a compile-time table of past leap seconds.
pub fn posixTimeFromStdTime(st: u96) os.timespec {
    const seconds_2018 = secondsPartOfStdTime(st);

    // convert to posix epoch
    var posix_seconds = @as(i37, seconds_2018) - utc2018.epoch.posix;

    if (@bitSizeOf(isize) < 36) {
        // clamp to valid size
        return .{
            .tv_sec = @intCast(isize, math.clamp(posix_seconds, minInt(isize), maxInt(isize))),
            .tv_nsec = nsPartOfStdTime(st),
        };
    } else {
        return .{
            .tv_sec = posix_seconds,
            .tv_nsec = nsPartOfStdTime(st),
        };
    }
}

fn testRoundTripConversion(s: i38, nsec: u30) !void {
    const ts: os.timespec = .{ .tv_sec = @intCast(isize, s), .tv_nsec = nsec };

    const st = utc2018.convertUtcFuzzyToUtc2018(stdTimeFromPosixTime(ts));
    const ts2 = posixTimeFromStdTime(utc2018.convertUtc2018ToUtcFuzzy(st));
    try testing.expectEqual(ts.tv_sec, ts2.tv_sec);
    try testing.expectEqual(ts.tv_nsec, ts2.tv_nsec);
}

fn testRoundTripConversions(s: i38) !void {
    // zig fmt: off
    try testRoundTripConversion(s,           1);
    try testRoundTripConversion(s,           2);
    try testRoundTripConversion(s,           3);
    try testRoundTripConversion(s,           4);
    try testRoundTripConversion(s,     123_456);
    try testRoundTripConversion(s,     999_999);
    try testRoundTripConversion(s,   1_234_567);
    try testRoundTripConversion(s,  12_345_678);
    try testRoundTripConversion(s, 999_999_998);
    try testRoundTripConversion(s, 999_999_999);
    // zig fmt: on
}

const leap_seconds = utc2018.leap_seconds;

test "timestamp conversion" {
    try testRoundTripConversions(epoch.windows + 50); // Offset because epoch.windows would go negative
    try testRoundTripConversions(epoch.zos);
    try testRoundTripConversions(epoch.pickos);
    try testRoundTripConversions(-2);
    try testRoundTripConversions(-1);
    try testRoundTripConversions(0);
    try testRoundTripConversions(1);
    try testRoundTripConversions(2);
    try testRoundTripConversions(epoch.amiga);
    try testRoundTripConversions(epoch.gps);

    // Test that roundtrip conversion from Fuzzy UTC, Utc2018, and back are consistent
    var i: u8 = 1; // The 0 item in the table isn't actually a leap second
    while (i < leap_seconds.len) : (i += 1) {
        try testRoundTripConversions(leap_seconds[i].utc_fuzzy - utc2018.epoch.posix - 2);
        try testRoundTripConversions(leap_seconds[i].utc_fuzzy - utc2018.epoch.posix - 1);
        try testRoundTripConversions(leap_seconds[i].utc_fuzzy - utc2018.epoch.posix);
        try testRoundTripConversions(leap_seconds[i].utc_fuzzy - utc2018.epoch.posix + 1);
        try testRoundTripConversions(leap_seconds[i].utc_fuzzy - utc2018.epoch.posix + 2);
    }
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
    start_instant: Instant,
    last_instant: Instant,

    /// Initialize the timer structure.
    pub fn start() error{TimerUnsupported}!Timer {
        // We assume that if the system is blocking us from using the Clock
        // (i.e. with use of linux seccomp), it should at least block us consistently.
        const s = Instant.now() catch return error.TimerUnsupported;
        return Timer{ .start_instant = s, .last_instant = s };
    }

    /// Returns the current duration of the timer in nanoseconds
    pub fn read(self: *Timer) u64 {
        return self.toDuration(self.now());
    }

    /// Resets the timer to 0 (by setting the start_instant to now()).
    pub fn reset(self: *Timer) void {
        self.start_instant = self.now();
    }

    /// Returns the current duration of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        const current_instant = self.now();
        defer self.start_instant = current_instant;
        return self.toDuration(current_instant);
    }

    /// Reads Instant.now() assuming that it cannot fail.
    /// Makes sure the Instant is monotonic.
    pub fn now(self: *Timer) Instant {
        const current = Instant.now() catch unreachable;
        if (self.last_instant.order(current) == .lt) self.last_instant = current;
        return self.last_instant;
    }

    fn toDuration(self: Timer, current: Instant) u64 {
        assert(self.start_instant.order(current) != .gt);
        return @intCast(u64, current.since(self.start_instant) catch unreachable);
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

/// A snapshot of the current high-precision clock value.
/// Mostly monotonic, but is allowed to jump backwards.
/// Can be used to measure elapsed (or wallclock) time. 
pub const Instant = struct {
    native_ticks: NativeTicks,

    const NativeTicks = if (is_darwin or is_windows) u64 else os.timespec;

    /// Get the current Instant snapshot.
    /// Time conversion to nanoseconds happens at since() to keep now() sampling fast.
    pub fn now() error{UnsupportedClock}!Instant {
        var native_ticks: NativeTicks = undefined;

        if (is_windows) {
            native_ticks = os.windows.QueryPerformanceCounter();
        } else if (is_darwin) {
            native_ticks = os.darwin.mach_continuous_time();
        } else switch (builtin.os.tag) {
            // Unlike CLOCK.MONOTONIC, this actually counts time suspended (true POSIX MONOTONIC)
            .linux => os.clock_gettime(os.CLOCK.BOOTTIME, &native_ticks) catch
                return error.UnsupportedClock,

            else => os.clock_gettime(os.CLOCK.MONOTONIC, &native_ticks) catch
                return error.UnsupportedClock,
        }
        return Instant{
            .native_ticks = native_ticks,
        };
    }

    /// Does a fast comparison without computing a duration (like since() below)
    pub fn order(self: Instant, other: Instant) std.math.Order {
        if (is_darwin or is_windows) {
            return std.math.order(self.native_ticks, other.native_ticks);
        }

        var ord = std.math.order(self.native_ticks.tv_sec, other.native_ticks.tv_sec);
        if (ord == .eq)
            ord = std.math.order(self.native_ticks.tv_nsec, other.native_ticks.tv_nsec);
        return ord;
    }

    const zero_tick: NativeTicks = if (is_darwin or is_windows) 0 else .{
        .tv_sec = 0,
        .tv_nsec = 0,
    };
    const instant_zero = Instant{
        .native_ticks = zero_tick,
    };

    // This is used to implement Instant.asStdTime().
    // This represents the std time at a hypothetical Instant{ZeroTick}.
    var base_std_time: u96 = 0;
    var base_std_time_valid = false;

    // The two Instants are averaged to become slightly more accurate.
    // avg_instant.sinceAssumeEarlier(Instant{ZeroTick}) is subtracted from the std timestamp to
    // become base_std_time
    fn getBaseStdTime() void {
        var best_delta_ns = ns_per_day;
        var best_st = 0;
        var best_ns_sinze_zero = 0;
        while (true) {
            // Grab two Instant.now() with a std timestamp in-between.
            const instant_1 = Instant.now();
            const st = timestampNow();
            const instant_2 = Instant.now();

            const instant_1_ns_since_zero = instant_1.sinceAssumeEarlier(instant_zero);
            const instant_2_ns_since_zero = instant_2.sinceAssumeEarlier(instant_zero);

            if (instant_1_ns_since_zero > instant_2_ns_since_zero)
                continue; // Try again, non-monotonic behavior

            const delta_ns = instant_2_ns_since_zero - instant_1_ns_since_zero;
            if (delta_ns < (best_delta_ns / 2)) {
                best_delta_ns = delta_ns;
                best_st = st;
                best_ns_sinze_zero = instant_1_ns_since_zero + (delta_ns / 2);
                continue; // Found a much better delta, try again
            }

            return best_st - (best_ns_sinze_zero * ns_scale_st_36_60);
        }
    }

    /// Returns the Instant converted to zig StdTime in Utc2018.
    /// The first time this is called, this may take up to a few microseconds to establish the 
    /// congruence between Instant's NativeTicks and StdTime via timestampNow().
    pub fn asStdTime(self: Instant) u96 {
        if (!base_std_time_valid) {
            base_std_time = getBaseStdTime();
            // TODO: Add a Zig idiomatic fence to ensure the above occurs first.
            base_std_time_valid = true;
        }

        const st_since_base = self.sinceAssumeEarlier(instant_zero) * ns_scale_st_36_60;
        return base_std_time + st_since_base;
    }

    /// Returns the duration in nanoseconds since the earlier Instant to this Instant.
    /// If this Instant snapshot represents a time before earlier Instant, a negative value is returned.
    /// If too much time occurred between this Instant and earlier Instant, `error.Overflow` is returned.
    /// TODO: Does returning Overflow make sense? It seems like the computer would need to run for centuries
    pub fn since(self: Instant, earlier: Instant) error{Overflow}!i64 {
        return switch (self.order(earlier)) {
            .eq => 0,
            .gt => std.math.cast(i64, self.sinceAssumeEarlier(earlier)),
            .lt => 0 - try std.math.cast(i64, earlier.sinceAssumeEarlier(self)),
        };
    }

    var windows_ns_scale32: u64 = maxInt(u64);

    var darwin_ns_scale32: u64 = maxInt(u64);

    fn getDarwinScale32() u64 {
        var timebase: os.darwin.mach_timebase_info_data = undefined;
        if (os.darwin.mach_timebase_info(&timebase) != 0) unreachable;

        if (timebase.numer == timebase.denom)
            return 0;

        return @as(u64, 1 << 32) * timebase.numer / timebase.denom;
    }

    fn sinceAssumeEarlier(self: Instant, earlier: Instant) u64 {
        if (is_windows) {
            const duration_ticks = self.native_ticks - earlier.native_ticks;

            if (windows_ns_scale32 == maxInt(u64))
                windows_ns_scale32 = (std.time.ns_per_s << 32) / os.windows.QueryPerformanceFrequency();

            // Scales to duration in ns using fixed-point math avoiding overflow.
            return @truncate(u64, (@as(u96, duration_ticks) * windows_ns_scale32) >> 32);
        } else if (is_darwin) {
            const duration_ticks = self.native_ticks - earlier.native_ticks;

            if (darwin_ns_scale32 == maxInt(u64))
                darwin_ns_scale32 = getDarwinScale32();

            if (darwin_ns_scale32 == 0)
                return duration_ticks;

            // Scales to duration in ns using fixed-point math avoiding overflow.
            return @truncate(u64, (@as(u96, duration_ticks) * darwin_ns_scale32) >> 32);
        } else {
            const duration_seconds = @intCast(u64, self.native_ticks.tv_sec - earlier.native_ticks.tv_sec);

            return ((duration_seconds * ns_per_s) + @intCast(u64, self.native_ticks.tv_nsec)) -
                @intCast(u64, earlier.native_ticks.tv_nsec);
        }
    }
};

/// Measures amount of time the callers thread or process spent running on cpu
pub const CpuTime = enum {
    /// Returns nanoseconds of cpu time spent by the caller's thread.
    thread,
    /// Returns nanoseconds of cpu time spent in all threads in the caller's process
    process,
    /// Returns nanoseconds since an arbitrary point in time. Pauses while suspended.
    computer,

    const Error = error{UnsupportedClock};

    // measure thread/process/computer cpu time in nanoseconds
    pub fn read(self: CpuTime) Error!u64 {
        return if (is_windows) switch (self) {
            .thread => readWindowsCpuTime("GetThreadTimes", "GetCurrentThread"),
            .process => readWindowsCpuTime("GetProcessTimes", "GetCurrentProcess"),
            .computer => readWindowsUnbiasedInterruptTime(),
        } else switch (self) {
            .thread => readPosixTime(os.CLOCK.THREAD_CPUTIME_ID),
            .process => readPosixTime(os.CLOCK.PROCESS_CPUTIME_ID),
            .computer => readPosixTime(posix_uptime_clock_id),
        };
    }

    /// Calls either GetThreadTimes or GetProcessTimes and returns
    /// the amount of nanoseconds spent in userspace and the the kernel.
    fn readWindowsCpuTime(comptime GetTimesFn: []const u8, comptime GetCurrentFn: []const u8) Error!u64 {
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

        if (result == 0)
            return error.UnsupportedClock;

        var cpu_time = kernel_time + user_time;
        return cpu_time * 100;
    }

    pub fn readPosixTime(id: i32) Error!u64 {
        var ts: os.timespec = undefined;
        try os.clock_gettime(id, &ts);
        return (@intCast(u64, ts.tv_sec) * ns_per_s) + @intCast(u64, ts.tv_nsec);
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
    const posix_uptime_clock_id = switch (builtin.os.tag) {
        .openbsd, .freebsd, .kfreebsd, .dragonfly => os.CLOCK.UPTIME,
        // Calls mach_absolute_time() internally
        .macos, .tvos, .ios, .watchos => os.CLOCK.UPTIME_RAW,
        // CLOCK.MONOTONIC on linux actually doesn't count time suspended (not POSIX compliant).
        // At some point we may change our minds on CLOCK.MONOTONIC_RAW,
        // but for now we're sticking with CLOCK.MONOTONIC standard.
        // For more information, see: https://github.com/ziglang/zig/pull/933
        .linux => os.CLOCK.MONOTONIC,
        // Platforms like wasi and netbsd don't support getting time without suspend
        else => null,
    };

    var windows_ns_scale32: u64 = maxInt(u64);

    /// TODO: Replace with QueryUnbiasedInterruptTimePrecise() once available
    fn readWindowsUnbiasedInterruptTime() u64 {
        // Compute the unbiased (without suspend) time by sampling the current interrupt time
        // then subtracting the InterruptTimeBias while accounting for possibly suspending mid-sample.
        // https://stackoverflow.com/questions/24330496/how-do-i-create-monotonic-clock-on-windows-which-doesnt-tick-during-suspend
        // https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
        const KUSER_SHARED_DATA = 0x7ffe0000;
        const InterruptTimeBias = @intToPtr(*volatile u64, KUSER_SHARED_DATA + 0x3b0);

        if (windows_ns_scale32 == maxInt(u64))
            windows_ns_scale32 = (std.time.ns_per_s << 32) / os.windows.QueryPerformanceFrequency();

        while (true) {
            const bias = InterruptTimeBias.*;
            const counter = os.windows.QueryPerformanceCounter();
            if (bias == InterruptTimeBias.*) {
                // Scales to duration in ns using fixed-point math avoiding overflow.
                return @truncate(u64, (@as(u96, counter) * windows_ns_scale32) >> 32) - (bias * 100);
            }
        }
    }
};
