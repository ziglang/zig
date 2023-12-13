const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;

pub const epoch = @import("time/epoch.zig");

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    // TODO: opting out of async sleeping?
    if (std.io.is_async) {
        return std.event.Loop.instance.?.sleep(nanoseconds);
    }

    if (builtin.os.tag == .windows) {
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(os.windows.DWORD, big_ms_from_ns) orelse math.maxInt(os.windows.DWORD);
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

    if (builtin.os.tag == .uefi) {
        const boot_services = os.uefi.system_table.boot_services.?;
        const us_from_ns = nanoseconds / ns_per_us;
        const us = math.cast(usize, us_from_ns) orelse math.maxInt(usize);
        _ = boot_services.stall(us);
        return;
    }

    const s = nanoseconds / ns_per_s;
    const ns = nanoseconds % ns_per_s;
    std.os.nanosleep(s, ns);
}

pub const TimeZone = @import("time/TimeZone.zig");

pub const LocalTimeError = error{
    /// The local time zone of the system could not be determined.
    LocalTimeUnavailable,
} || std.mem.Allocator.Error;

pub fn localtime(allocator: std.mem.Allocator) LocalTimeError!TimeZone {
    switch (builtin.os.tag) {
        .linux => {
            var tz_file = std.fs.openFileAbsolute("/etc/localtime", .{}) catch
                return error.LocalTimeUnavailable;
            defer tz_file.close();

            var buffered = std.io.bufferedReader(tz_file.reader());
            return TimeZone.parse(allocator, buffered.reader()) catch
                return error.LocalTimeUnavailable;
        },
        else => @compileError("`localtime` has not been implemented for this OS!"),
    }
}

/// ISO 8601 compliant date representation.
pub const Date = struct {
    /// milliseconds, range 0 to 999
    millisecond: u16,

    /// seconds, range 0 to 60
    second: u8,

    /// minutes, range 0 to 59
    minute: u8,

    /// hours, range 0 to 23
    hour: u8,

    /// day of the month, range 1 to 31
    day: u8,

    /// day of the year, range 1 to 366
    year_day: u16,

    /// day of the week, enum Monday to Sunday
    week_day: Weekday,

    /// month, enum January to December
    month: Month,

    /// year, year 0000 is equal to 1 BCE
    year: i32,

    utc_timestamp: i64,
    tt: TimeZone.TimeType,

    pub const Weekday = enum(u3) {
        monday = 1,
        tuesday = 2,
        wednesday = 3,
        thursday = 4,
        friday = 5,
        saturday = 6,
        sunday = 7,

        pub const names = [_][]const u8{
            "Monday",
            "Tuesday",
            "Wednesday",
            "Thursday",
            "Friday",
            "Saturday",
            "Sunday",
        };

        pub fn shortName(w: Weekday) []const u8 {
            return names[@intFromEnum(w) - 1][0..3];
        }

        pub fn longName(w: Weekday) []const u8 {
            return names[@intFromEnum(w) - 1];
        }
    };

    pub const Month = enum(u4) {
        january = 1,
        february = 2,
        march = 3,
        april = 4,
        may = 5,
        june = 6,
        july = 7,
        august = 8,
        september = 9,
        october = 10,
        november = 11,
        december = 12,

        pub const names = [_][]const u8{
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December",
        };

        pub fn shortName(m: Month) []const u8 {
            return names[@intFromEnum(m) - 1][0..3];
        }

        pub fn longName(m: Month) []const u8 {
            return names[@intFromEnum(m) - 1];
        }
    };

    /// Get current date in the system's local time.
    pub fn now(allocator: std.mem.Allocator) LocalTimeError!Date {
        const utc_timestamp = timestamp();

        if (builtin.os.tag == .windows) {
            var tzi: std.os.windows.TIME_ZONE_INFORMATION = undefined;
            const rc = std.os.windows.ntdll.NtQuerySystemInformation(
                .SystemCurrentTimeZoneInformation,
                &tzi,
                @sizeOf(std.os.windows.TIME_ZONE_INFORMATION),
                null,
            );
            if (rc != .SUCCESS) return error.LocalTimeUnavailable;
            return fromTimestamp(utc_timestamp, .{
                .name_data = .{
                    @intCast(tzi.StandardName[0]),
                    @intCast(tzi.StandardName[1]),
                    @intCast(tzi.StandardName[2]),
                    @intCast(tzi.StandardName[3]),
                    @intCast(tzi.StandardName[4]),
                    @intCast(tzi.StandardName[5]),
                },
                .flags = 0,
                .offset = tzi.Bias,
            });
        }

        var sf = std.heap.stackFallback(4096, allocator);
        var tz = try localtime(sf.allocator());
        defer tz.deinit(sf.allocator());

        return fromTimestamp(utc_timestamp, tz.project(utc_timestamp));
    }

    /// Convert timestamp in milliseconds to a Date.
    pub fn fromTimestamp(utc_timestamp: i64, tt: TimeZone.TimeType) Date {
        // Ported from musl, which is licensed under the MIT license:
        // https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT

        const days_in_month = [12]i8{ 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29 };
        // 2000-03-01 (mod 400 year, immediately after feb29
        const leapoch = 946684800 + 86400 * (31 + 29);
        const days_per_400y = 365 * 400 + 97;
        const days_per_100y = 365 * 100 + 24;
        const days_per_4y = 365 * 4 + 1;

        const seconds = @divTrunc(utc_timestamp, 1000) + tt.offset - leapoch;
        var days = @divTrunc(seconds, 86400);
        var rem_seconds = @as(i32, @truncate(@rem(seconds, 86400)));
        if (rem_seconds < 0) {
            rem_seconds += 86400;
            days -= 1;
        }

        var week_day = @rem((3 + days), 7);
        if (week_day < 0) {
            week_day += 7;
        }

        var qc_cycles = @divTrunc(days, days_per_400y);
        var rem_days = @as(i32, @intCast(@rem(days, days_per_400y)));
        if (rem_days < 0) {
            rem_days += days_per_400y;
            qc_cycles -= 1;
        }

        var c_cycles = @divTrunc(rem_days, days_per_100y);
        if (c_cycles == 4) {
            c_cycles -= 1;
        }
        rem_days -= c_cycles * days_per_100y;

        var q_cycles = @divTrunc(rem_days, days_per_4y);
        if (q_cycles == 25) {
            q_cycles -= 1;
        }
        rem_days -= q_cycles * days_per_4y;

        var rem_years = @divTrunc(rem_days, 365);
        if (rem_years == 4) {
            rem_years -= 1;
        }
        rem_days -= rem_years * 365;

        const leap: i32 = if (rem_years == 0 and (q_cycles != 0 or c_cycles == 0)) 1 else 0;
        var year_day = rem_days + 31 + 28 + leap;
        if (year_day >= 365 + leap) {
            year_day -= 365 + leap;
        }

        var years = rem_years + 4 * q_cycles + 100 * c_cycles + 400 * qc_cycles;

        var months: i32 = 0;
        while (days_in_month[@as(usize, @intCast(months))] <= rem_days) : (months += 1) {
            rem_days -= days_in_month[@as(usize, @intCast(months))];
        }

        if (months >= 10) {
            months -= 12;
            years += 1;
        }

        return .{
            .year = @intCast(years + 2000),
            .month = @enumFromInt(months + 3),
            .day = @intCast(rem_days + 1),
            .year_day = @intCast(year_day + 1),
            .week_day = @enumFromInt(week_day),
            .hour = @intCast(@divTrunc(rem_seconds, 3600)),
            .minute = @intCast(@rem(@divTrunc(rem_seconds, 60), 60)),
            .second = @intCast(@rem(rem_seconds, 60)),
            .millisecond = @intCast(@rem(utc_timestamp, 1000)),
            .utc_timestamp = utc_timestamp,
            .tt = tt,
        };
    }

    /// Compare two `Date`s.
    pub fn order(self: Date, other: Date) std.math.Order {
        var ord = std.math.order(self.year, other.year);
        if (ord != .eq) return ord;

        ord = std.math.order(self.year_day, other.year_day);
        if (ord != .eq) return ord;

        ord = std.math.order(self.hour, other.hour);
        if (ord != .eq) return ord;

        ord = std.math.order(self.minute, other.minute);
        if (ord != .eq) return ord;

        ord = std.math.order(self.second, other.second);
        if (ord != .eq) return ord;

        return std.math.order(self.millisecond, other.millisecond);
    }

    pub const default_fmt = "%Y-%m-%dT%H%c%M%c%S%z";

    /// %a Abbreviated weekday name (Sun)
    /// %A Full weekday name (Sunday)
    /// %b Abbreviated month name (Mar)
    /// %B Full month name (March)
    /// %c A colon ':'
    /// %d Day of the month (01-31)
    /// %H Hour in 24h format (00-23)
    /// %I Hour in 12h format (01-12)
    /// %j Day of the Year (001-366)
    /// %m Month as a decimal number (01-12)
    /// %M Minute (00-59)
    /// %p AM or PM designation
    /// %s Millisecond 891
    /// %S Second (00-60)
    /// %y Year, last two digits (00-99)
    /// %Y Year
    /// %z UTC offset in the form ±HHMM
    /// %Z Time zone name.
    /// %% A % sign
    pub fn format(
        date: Date,
        comptime user_fmt: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const fmt = if (user_fmt.len != 0) user_fmt else default_fmt;

        comptime var fmt_char = false;
        comptime var begin = 0;

        inline for (fmt, 0..) |c, i| {
            if (c == '%' and !fmt_char) {
                fmt_char = true;
                const other = fmt[begin..i];
                if (other.len > 0) {
                    try writer.writeAll(other);
                }
                begin = i + 2;
                continue;
            } else if (!fmt_char) {
                continue;
            }
            fmt_char = false;

            switch (c) {
                'a' => try writer.writeAll(date.week_day.shortName()),
                'A' => try writer.writeAll(date.week_day.longName()),
                'b' => try writer.writeAll(date.month.shortName()),
                'B' => try writer.writeAll(date.month.longName()),
                'c' => try writer.writeAll(":"),
                'm' => try std.fmt.formatInt(@intFromEnum(date.month), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                'd' => try std.fmt.formatInt(date.day, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                'Y' => try std.fmt.formatInt(date.year, 10, .lower, .{ .width = 0, .fill = '0' }, writer),
                'y' => try std.fmt.formatInt(@as(u32, @intCast(@mod(date.year, 100))), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                'I' => {
                    var h = date.hour;
                    if (h > 12) {
                        h -= 12;
                    } else if (h == 0) {
                        h = 12;
                    }
                    try std.fmt.formatInt(h, 10, .lower, .{ .width = 2, .fill = '0' }, writer);
                },
                'H' => try std.fmt.formatInt(date.hour, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                'M' => try std.fmt.formatInt(date.minute, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                'S' => try std.fmt.formatInt(date.second, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
                's' => try std.fmt.formatInt(date.millisecond, 10, .lower, .{ .width = 3, .fill = '0' }, writer),
                'j' => try std.fmt.formatInt(date.year_day, 10, .lower, .{ .width = 3, .fill = '0' }, writer),
                'p' => if (date.hour < 12) {
                    try writer.writeAll("AM");
                } else {
                    try writer.writeAll("PM");
                },
                '%' => {
                    try writer.writeAll("%");
                    begin = i + 1;
                },
                'z' => {
                    const sign = "+-"[@intFromBool(date.tt.offset < 0)];
                    try writer.writeByte(sign);
                    const abs = @abs(date.tt.offset);
                    const hours = @divFloor(abs, 3600);
                    const minutes = @rem(@divFloor(abs, 60), 60);
                    try std.fmt.formatInt(hours, 10, .lower, .{ .width = 2, .fill = '0' }, writer);
                    try std.fmt.formatInt(minutes, 10, .lower, .{ .width = 2, .fill = '0' }, writer);
                },
                'Z' => try writer.writeAll(date.tt.name()),
                else => @compileError("Unknown format character: " ++ [_]u8{fmt[i]}),
            }
        }
        if (fmt_char) {
            @compileError("Incomplete format string: " ++ fmt);
        }
        const remaining = fmt[begin..];
        if (remaining.len > 0) {
            try writer.writeAll(remaining);
        }
    }
};

test Date {
    const date = Date.fromTimestamp(1560870105000, TimeZone.TimeType.UTC);

    try testing.expect(date.millisecond == 0);
    try testing.expect(date.second == 45);
    try testing.expect(date.minute == 1);
    try testing.expect(date.hour == 15);
    try testing.expect(date.day == 18);
    try testing.expect(date.year_day == 169);
    try testing.expect(date.week_day == .tuesday);
    try testing.expect(date.month == .june);
    try testing.expect(date.year == 2019);
}

test "Date.format all" {
    const date = Date.fromTimestamp(1560816105000, TimeZone.TimeType.UTC);
    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{%a %A %b %B %m %d %y %Y %I %p %H%c%M%c%S.%s %j %%}", .{date});
    try testing.expectEqualStrings("Tue Tuesday Jun June 06 18 19 2019 12 AM 00:01:45.000 169 %", result);
}

test "Date.format no format" {
    const EEST: TimeZone.TimeType = .{
        .offset = 10800,
        .flags = 0,
        .name_data = "EEST\x00\x00".*,
    };
    const date = Date.fromTimestamp(1560870105000, EEST);
    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{}", .{date});
    try std.testing.expectEqualStrings("2019-06-18T18:01:45+0300", result);
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
    return @as(i64, @intCast(@divFloor(nanoTimestamp(), ns_per_ms)));
}

/// Get a calendar timestamp, in microseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn microTimestamp() i64 {
    return @as(i64, @intCast(@divFloor(nanoTimestamp(), ns_per_us)));
}

/// Get a calendar timestamp, in nanoseconds, relative to UTC 1970-01-01.
/// Precision of timing depends on the hardware and operating system.
/// On Windows this has a maximum granularity of 100 nanoseconds.
/// The return value is signed because it is possible to have a date that is
/// before the epoch.
/// See `std.os.clock_gettime` for a POSIX timestamp.
pub fn nanoTimestamp() i128 {
    if (builtin.os.tag == .windows) {
        // FileTime has a granularity of 100 nanoseconds and uses the NTFS/Windows epoch,
        // which is 1601-01-01.
        const epoch_adj = epoch.windows * (ns_per_s / 100);
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimeAsFileTime(&ft);
        const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
        return @as(i128, @as(i64, @bitCast(ft64)) + epoch_adj) * 100;
    }

    if (builtin.os.tag == .wasi and !builtin.link_libc) {
        var ns: os.wasi.timestamp_t = undefined;
        const err = os.wasi.clock_time_get(os.wasi.CLOCK.REALTIME, 1, &ns);
        assert(err == .SUCCESS);
        return ns;
    }

    var ts: os.timespec = undefined;
    os.clock_gettime(os.CLOCK.REALTIME, &ts) catch |err| switch (err) {
        error.UnsupportedClock, error.Unexpected => return 0, // "Precision of timing depends on hardware and OS".
    };
    return (@as(i128, ts.tv_sec) * ns_per_s) + ts.tv_nsec;
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

/// An Instant represents a timestamp with respect to the currently
/// executing program that ticks during suspend and can be used to
/// record elapsed time unlike `nanoTimestamp`.
///
/// It tries to sample the system's fastest and most precise timer available.
/// It also tries to be monotonic, but this is not a guarantee due to OS/hardware bugs.
/// If you need monotonic readings for elapsed time, consider `Timer` instead.
pub const Instant = struct {
    timestamp: if (is_posix) os.timespec else u64,

    // true if we should use clock_gettime()
    const is_posix = switch (builtin.os.tag) {
        .wasi => builtin.link_libc,
        .windows => false,
        else => true,
    };

    /// Queries the system for the current moment of time as an Instant.
    /// This is not guaranteed to be monotonic or steadily increasing, but for most implementations it is.
    /// Returns `error.Unsupported` when a suitable clock is not detected.
    pub fn now() error{Unsupported}!Instant {
        // QPC on windows doesn't fail on >= XP/2000 and includes time suspended.
        if (builtin.os.tag == .windows) {
            return Instant{ .timestamp = os.windows.QueryPerformanceCounter() };
        }

        // On WASI without libc, use clock_time_get directly.
        if (builtin.os.tag == .wasi and !builtin.link_libc) {
            var ns: os.wasi.timestamp_t = undefined;
            const rc = os.wasi.clock_time_get(os.wasi.CLOCK.MONOTONIC, 1, &ns);
            if (rc != .SUCCESS) return error.Unsupported;
            return Instant{ .timestamp = ns };
        }

        // On darwin, use UPTIME_RAW instead of MONOTONIC as it ticks while suspended.
        // On linux, use BOOTTIME instead of MONOTONIC as it ticks while suspended.
        // On freebsd derivatives, use MONOTONIC_FAST as currently there's no precision tradeoff.
        // On other posix systems, MONOTONIC is generally the fastest and ticks while suspended.
        const clock_id = switch (builtin.os.tag) {
            .macos, .ios, .tvos, .watchos => os.CLOCK.UPTIME_RAW,
            .freebsd, .dragonfly => os.CLOCK.MONOTONIC_FAST,
            .linux => os.CLOCK.BOOTTIME,
            else => os.CLOCK.MONOTONIC,
        };

        var ts: os.timespec = undefined;
        os.clock_gettime(clock_id, &ts) catch return error.Unsupported;
        return Instant{ .timestamp = ts };
    }

    /// Quickly compares two instances between each other.
    pub fn order(self: Instant, other: Instant) std.math.Order {
        // windows and wasi timestamps are in u64 which is easily comparible
        if (!is_posix) {
            return std.math.order(self.timestamp, other.timestamp);
        }

        var ord = std.math.order(self.timestamp.tv_sec, other.timestamp.tv_sec);
        if (ord == .eq) {
            ord = std.math.order(self.timestamp.tv_nsec, other.timestamp.tv_nsec);
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
            const qpf = os.windows.QueryPerformanceFrequency();

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
        if (builtin.os.tag == .wasi and !builtin.link_libc) {
            return self.timestamp - earlier.timestamp;
        }

        // Convert timespec diff to ns
        const seconds = @as(u64, @intCast(self.timestamp.tv_sec - earlier.timestamp.tv_sec));
        const elapsed = (seconds * ns_per_s) + @as(u32, @intCast(self.timestamp.tv_nsec));
        return elapsed - @as(u32, @intCast(earlier.timestamp.tv_nsec));
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

test "Timer + Instant" {
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
    _ = TimeZone;
}
