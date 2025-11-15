//! Epoch reference times in terms of their difference from
//! UTC 1970-01-01 in seconds.
const std = @import("../std.zig");
const native_os = @import("builtin").os.tag;
const testing = std.testing;
const math = std.math;

/// Jan 01, 1970 AD
pub const posix = 0;
/// Jan 01, 1980 AD
pub const dos = 315532800;
/// Jan 01, 2001 AD
pub const ios = 978307200;
/// Nov 17, 1858 AD
pub const openvms = -3506716800;
/// Jan 01, 1900 AD
pub const zos = -2208988800;
/// Jan 01, 1601 AD
pub const windows = -11644473600;
/// Jan 01, 1978 AD
pub const amiga = 252460800;
/// Dec 31, 1967 AD
pub const pickos = -63244800;
/// Jan 06, 1980 AD
pub const gps = 315964800;
/// Jan 01, 0001 AD
pub const clr = -62135769600;

pub const unix = posix;
pub const android = posix;
pub const os2 = dos;
pub const bios = dos;
pub const vfat = dos;
pub const ntfs = windows;
pub const ntp = zos;
pub const jbase = pickos;
pub const aros = amiga;
pub const morphos = amiga;
pub const brew = gps;
pub const atsc = gps;
pub const go = clr;

pub const epoch_year = if (native_os == .windows) 1601 else 1970;
pub const secs_per_day: u17 = 24 * 60 * 60;

pub fn isLeapYear(year: Year) bool {
    if (@mod(year, 4) != 0)
        return false;
    if (@mod(year, 100) != 0)
        return true;
    return (0 == @mod(year, 400));
}

test isLeapYear {
    try testing.expectEqual(false, isLeapYear(2095));
    try testing.expectEqual(true, isLeapYear(2096));
    try testing.expectEqual(false, isLeapYear(2100));
    try testing.expectEqual(true, isLeapYear(2400));
}

pub fn getDaysInYear(year: Year) u9 {
    return if (isLeapYear(year)) 366 else 365;
}

/// The type that holds the current year, i.e. 2016
pub const Year = u16;

pub const Month = enum(u4) {
    jan = 1,
    feb,
    mar,
    apr,
    may,
    jun,
    jul,
    aug,
    sep,
    oct,
    nov,
    dec,

    /// return the numeric calendar value for the given month
    /// i.e. jan=1, feb=2, etc
    pub fn numeric(self: Month) u4 {
        return @intFromEnum(self);
    }
};

/// Day of month (1 to 31)
pub const Day = u5;

/// Hour of day (0 to 23)
pub const Hour = u5;

/// Minute of hour (0 to 59)
pub const Minute = u6;

/// Second of minute (0 to 59)
pub const Second = u6;

pub const Datetime = struct {
    year: Year,
    month: Month,
    day: Day,
    hour: Hour,
    minute: Minute,
    second: Second,

    pub fn asTimestamp(d: *const Datetime) !std.Io.Timestamp {
        if (d.day == 0 or d.day > getDaysInMonth(d.year, d.month)) return error.InvalidDay;
        if (d.hour >= 24) return error.InvalidHour;
        if (d.minute >= 60) return error.InvalidMinute;
        if (d.second >= 60) return error.InvalidSecond;

        // Calculate days from epoch (can be negative for dates before epoch)
        var total_days: i96 = undefined;

        const total_years: i32 = @as(i32, d.year) - epoch_year;

        var total_leap_years: i30 = undefined;
        if (d.year >= epoch_year) {
            total_leap_years = countLeapYearsBetween(epoch_year, d.year);
        } else {
            total_leap_years = -@as(i30, countLeapYearsBetween(d.year, epoch_year));
        }
        total_days = @as(i96, total_years) * 365 + @as(i96, total_leap_years);

        // Add days for complete months in the given year
        var m: Month = .jan;
        while (@intFromEnum(m) < @intFromEnum(d.month)) {
            total_days += getDaysInMonth(d.year, m);
            m = @enumFromInt(@intFromEnum(m) + 1);
        }

        // Add remaining days (subtract 1 because day is 1-indexed)
        total_days += d.day - 1;

        // Convert to seconds and add time components
        var total_secs: i96 = total_days * @as(i96, secs_per_day);
        total_secs += @as(i96, d.hour) * 3600;
        total_secs += @as(i96, d.minute) * 60;
        total_secs += d.second;

        const nanoseconds: i96 = total_secs * std.time.ns_per_s;

        return std.Io.Timestamp{ .nanoseconds = nanoseconds };
    }
};

/// Counts the number of leap years in the range [start_year, end_year).
/// The end_year is exclusive.
pub fn countLeapYearsBetween(start_year: Year, end_year: Year) u15 {
    // We retrun u15 because `Year` is u16 and leap year is every 4 years.
    // (2 ** 16) / 4 = 2 ** 14, so u14 is clearly the best fit. But every 100
    // years is also leap year, which will result in very few extra leap years,
    // so we are adding 1 bit to make room for that, resulting in u15.

    if (end_year <= start_year) return 0;

    // Count leap years from year 0 to end_year-1, then subtract those before start_year
    const leaps_before_end = countLeapYearsFromZero(end_year - 1);
    const leaps_before_start = if (start_year > 0) countLeapYearsFromZero(start_year - 1) else 0;

    return leaps_before_end - leaps_before_start;
}

/// Counts leap years from year 0 to the given year (inclusive).
fn countLeapYearsFromZero(y: Year) u15 {
    // Divisible by 4, minus centuries (divisible by 100), plus quad-centuries (divisible by 400)
    return @as(u15, @intCast((y / 4) - (y / 100) + (y / 400)));
}

/// Get the number of days in the given month and year
pub fn getDaysInMonth(year: Year, month: Month) u5 {
    return switch (month) {
        .jan => 31,
        .feb => @as(u5, switch (isLeapYear(year)) {
            true => 29,
            false => 28,
        }),
        .mar => 31,
        .apr => 30,
        .may => 31,
        .jun => 30,
        .jul => 31,
        .aug => 31,
        .sep => 30,
        .oct => 31,
        .nov => 30,
        .dec => 31,
    };
}

pub const YearAndDay = struct {
    year: Year,
    /// The number of days into the year (0 to 365)
    day: u9,

    pub fn calculateMonthDay(self: YearAndDay) MonthAndDay {
        var month: Month = .jan;
        var days_left = self.day;
        while (true) {
            const days_in_month = getDaysInMonth(self.year, month);
            if (days_left < days_in_month)
                break;
            days_left -= days_in_month;
            month = @as(Month, @enumFromInt(@intFromEnum(month) + 1));
        }
        return .{ .month = month, .day_index = @as(u5, @intCast(days_left)) };
    }
};

pub const MonthAndDay = struct {
    month: Month,
    day_index: u5, // days into the month (0 to 30)
};

/// days since epoch Jan 1, 1970
pub const EpochDay = struct {
    day: u47, // u47 = u64 - u17 (because day = sec(u64) / secs_per_day(u17)
    pub fn calculateYearDay(self: EpochDay) YearAndDay {
        var year_day = self.day;
        var year: Year = epoch_year;
        while (true) {
            const year_size = getDaysInYear(year);
            if (year_day < year_size)
                break;
            year_day -= year_size;
            year += 1;
        }
        return .{ .year = year, .day = @as(u9, @intCast(year_day)) };
    }
};

/// seconds since start of day
pub const DaySeconds = struct {
    secs: u17, // max is 24*60*60 = 86400

    /// the number of hours past the start of the day (0 to 23)
    pub fn getHoursIntoDay(self: DaySeconds) u5 {
        return @as(u5, @intCast(@divTrunc(self.secs, 3600)));
    }
    /// the number of minutes past the hour (0 to 59)
    pub fn getMinutesIntoHour(self: DaySeconds) u6 {
        return @as(u6, @intCast(@divTrunc(@mod(self.secs, 3600), 60)));
    }
    /// the number of seconds past the start of the minute (0 to 59)
    pub fn getSecondsIntoMinute(self: DaySeconds) u6 {
        return math.comptimeMod(self.secs, 60);
    }
};

/// seconds since epoch Jan 1, 1970 at 12:00 AM
pub const EpochSeconds = struct {
    secs: u64,

    /// Returns the number of days since the epoch as an EpochDay.
    /// Use EpochDay to get information about the day of this time.
    pub fn getEpochDay(self: EpochSeconds) EpochDay {
        return EpochDay{ .day = @as(u47, @intCast(@divTrunc(self.secs, secs_per_day))) };
    }

    /// Returns the number of seconds into the day as DaySeconds.
    /// Use DaySeconds to get information about the time.
    pub fn getDaySeconds(self: EpochSeconds) DaySeconds {
        return DaySeconds{ .secs = math.comptimeMod(self.secs, secs_per_day) };
    }
};

fn testEpoch(secs: u64, expected_year_day: YearAndDay, expected_month_day: MonthAndDay, expected_day_seconds: struct {
    /// 0 to 23
    hours_into_day: u5,
    /// 0 to 59
    minutes_into_hour: u6,
    /// 0 to 59
    seconds_into_minute: u6,
}) !void {
    const epoch_seconds = EpochSeconds{ .secs = secs };
    const epoch_day = epoch_seconds.getEpochDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    const year_day = epoch_day.calculateYearDay();
    try testing.expectEqual(expected_year_day, year_day);
    try testing.expectEqual(expected_month_day, year_day.calculateMonthDay());
    try testing.expectEqual(expected_day_seconds.hours_into_day, day_seconds.getHoursIntoDay());
    try testing.expectEqual(expected_day_seconds.minutes_into_hour, day_seconds.getMinutesIntoHour());
    try testing.expectEqual(expected_day_seconds.seconds_into_minute, day_seconds.getSecondsIntoMinute());
}

fn testDatetimeToNanoseconds(seconds: i96, dt: Datetime) !void {
    try testing.expectEqual(seconds * std.time.ns_per_s, (try dt.asTimestamp()).nanoseconds);
}

test "epoch decoding" {
    try testEpoch(0, .{ .year = 1970, .day = 0 }, .{
        .month = .jan,
        .day_index = 0,
    }, .{ .hours_into_day = 0, .minutes_into_hour = 0, .seconds_into_minute = 0 });

    try testEpoch(31535999, .{ .year = 1970, .day = 364 }, .{
        .month = .dec,
        .day_index = 30,
    }, .{ .hours_into_day = 23, .minutes_into_hour = 59, .seconds_into_minute = 59 });

    try testEpoch(1622924906, .{ .year = 2021, .day = 31 + 28 + 31 + 30 + 31 + 4 }, .{
        .month = .jun,
        .day_index = 4,
    }, .{ .hours_into_day = 20, .minutes_into_hour = 28, .seconds_into_minute = 26 });

    try testEpoch(1625159473, .{ .year = 2021, .day = 31 + 28 + 31 + 30 + 31 + 30 }, .{
        .month = .jul,
        .day_index = 0,
    }, .{ .hours_into_day = 17, .minutes_into_hour = 11, .seconds_into_minute = 13 });
}

test "datetime to epochseconds" {
    // epoc time exactly
    try testDatetimeToNanoseconds(0, .{
        .year = 1970,
        .month = .jan,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    });

    // last second of a year
    try testDatetimeToNanoseconds(31535999, .{
        .year = 1970,
        .month = .dec,
        .day = 31,
        .hour = 23,
        .minute = 59,
        .second = 59,
    });

    // first second of next year
    try testDatetimeToNanoseconds(31536000, .{
        .year = 1971,
        .month = .jan,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    });

    // leap year
    try testDatetimeToNanoseconds(68256000, .{
        .year = 1972,
        .month = .mar,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    });

    // super far in the future
    try testDatetimeToNanoseconds(11991628800, .{
        .year = 2350,
        .month = .jan,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    });

    // time before epoch
    try testDatetimeToNanoseconds(-14831769600, .{
        .year = 1500,
        .month = .jan,
        .day = 1,
        .hour = 0,
        .minute = 0,
        .second = 0,
    });

    // invalid input
    const dt = Datetime{
        .year = 1970,
        .month = .feb,
        .day = 29, // invalid because it's not leap year
        .hour = 0,
        .minute = 0,
        .second = 0,
    };

    try testing.expectError(error.InvalidDay, dt.asTimestamp());
}

test "countLeapYearsBetween" {
    // Between 1970-1980: 1972, 1976 = 2 leap years
    try std.testing.expectEqual(@as(u47, 2), countLeapYearsBetween(1970, 1980));

    // Between 1970-2000: excludes 2000 which is a leap year (divisible by 400)
    try std.testing.expectEqual(@as(u47, 7), countLeapYearsBetween(1970, 2000));

    // Between 1970-2001: adds 2000
    try std.testing.expectEqual(@as(u47, 8), countLeapYearsBetween(1970, 2001));

    // Century test: 1900 is NOT a leap year, 2000 IS
    try std.testing.expectEqual(@as(u47, 0), countLeapYearsBetween(1900, 1901));
    try std.testing.expectEqual(@as(u47, 1), countLeapYearsBetween(2000, 2001));
}
