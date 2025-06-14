//! Epoch reference times in terms of their difference from UTC 1970-01-01 in seconds.

const std = @import("../std.zig");
const time = std.time;
const testing = std.testing;
const math = std.math;

/// 1970-01-01.
pub const posix = 0;
/// 1980-01-01.
pub const dos = 315532800;
/// 2001-01-01.
pub const ios = 978307200;
/// 1858-11-17.
pub const openvms = -3506716800;
/// 1900-01-01.
pub const zos = -2208988800;
/// 1601-01-01.
pub const windows = -11644473600;
/// 1978-01-01.
pub const amiga = 252460800;
/// 1967-12-31.
pub const pickos = -63244800;
/// 1980-01-06.
pub const gps = 315964800;
/// 0001-01-01.
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

/// Example: 2016.
pub const Year = u16;

/// Deprecated: use functions provided by this structure.
pub const epoch_year = 1970;

/// Deprecated: use `std.time.s_per_day`.
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

    /// Returns the numeric calendar value for the given month, i.e. jan=1, feb=2, etc.
    pub fn numeric(month: Month) u4 {
        return @intFromEnum(month);
    }
};

/// Returns the number of days in the given year and month.
pub fn getDaysInMonth(year: Year, month: Month) u5 {
    return switch (month) {
        .jan => 31,
        .feb => switch (isLeapYear(year)) {
            true => 29,
            false => 28,
        },
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

/// The year of the time and the number of days into the year.
pub const YearAndDays = struct {
    year: Year,
    /// The number of days into the year (0 to 365).
    days: u9,

    pub fn calculateMonthAndDay(year_and_days: YearAndDays) MonthAndDay {
        var month: Month = .jan;
        var days_left = year_and_days.days;
        while (true) {
            const days_in_month = getDaysInMonth(year_and_days.year, month);
            if (days_left < days_in_month)
                break;
            days_left -= days_in_month;
            month = @enumFromInt(@intFromEnum(month) + 1);
        }
        return .{ .month = month, .day_index = @intCast(days_left) };
    }
};

/// The month and day of the time.
pub const MonthAndDay = struct {
    month: Month,
    /// The day of the month (0 to 30).
    day_index: u5,
};

/// Days since the epoch.
pub const Days = struct {
    days: u47, // = u64 - u17 (because day = sec(u64) / time.s_per_day(u17)

    pub fn calculateYearAndDays(days: Days) YearAndDays {
        var year_days = days.days;
        var year: Year = 1970;
        while (true) {
            const year_size = getDaysInYear(year);
            if (year_days < year_size)
                break;
            year_days -= year_size;
            year += 1;
        }
        return .{ .year = year, .days = @intCast(year_days) };
    }
};

/// Seconds into the day.
pub const DaySeconds = struct {
    secs: u17, // Maximum is `time.s_per_day`.

    /// Returns the number of hours past the start of the day (0 to 23).
    pub fn getHoursIntoDay(day_seconds: DaySeconds) u5 {
        return @intCast(@divTrunc(day_seconds.secs, 3600));
    }

    /// Returns the number of minutes past the hour (0 to 59).
    pub fn getMinutesIntoHour(day_seconds: DaySeconds) u6 {
        return @intCast(@divTrunc(@mod(day_seconds.secs, 3600), 60));
    }

    /// Returns the number of seconds past the start of the minute (0 to 59).
    pub fn getSecondsIntoMinute(day_seconds: DaySeconds) u6 {
        return math.comptimeMod(day_seconds.secs, 60);
    }
};

/// Seconds since the epoch.
pub const Seconds = struct {
    secs: u64,

    /// Returns the number of days since the epoch as an Days.
    /// Use Days to get information about the day of this time.
    pub fn getDays(seconds: Seconds) Days {
        return Days{ .days = @intCast(@divTrunc(seconds.secs, time.s_per_day)) };
    }

    /// Returns the number of seconds into the day as DaySeconds.
    /// Use DaySeconds to get information about the time.
    pub fn getSecondsIntoDay(seconds: Seconds) DaySeconds {
        return DaySeconds{ .secs = math.comptimeMod(seconds.secs, time.s_per_day) };
    }
};

/// Deprecated: use `YearAndDays`.
pub const YearAndDay = struct {
    year: Year,
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
/// Deprecated: use `Days`.
pub const EpochDay = struct {
    day: u47,
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
/// Deprecated: use `Seconds`.
pub const EpochSeconds = struct {
    secs: u64,
    pub fn getEpochDay(self: EpochSeconds) EpochDay {
        return EpochDay{ .day = @as(u47, @intCast(@divTrunc(self.secs, secs_per_day))) };
    }
    pub fn getDaySeconds(self: EpochSeconds) DaySeconds {
        return DaySeconds{ .secs = math.comptimeMod(self.secs, secs_per_day) };
    }
};

fn testDecode(secs: u64, expected_year_day: YearAndDays, expected_month_day: MonthAndDay, expected_day_seconds: struct {
    /// 0 to 23.
    hours_into_day: u5,
    /// 0 to 59.
    minutes_into_hour: u6,
    /// 0 to 59.
    seconds_into_minute: u6,
}) !void {
    const seconds = Seconds{ .secs = secs };
    const days = seconds.getDays();
    const day_seconds = seconds.getSecondsIntoDay();
    const year_and_days = days.calculateYearAndDays();
    try testing.expectEqual(expected_year_day, year_and_days);
    try testing.expectEqual(expected_month_day, year_and_days.calculateMonthAndDay());
    try testing.expectEqual(expected_day_seconds.hours_into_day, day_seconds.getHoursIntoDay());
    try testing.expectEqual(expected_day_seconds.minutes_into_hour, day_seconds.getMinutesIntoHour());
    try testing.expectEqual(expected_day_seconds.seconds_into_minute, day_seconds.getSecondsIntoMinute());
}

test "decoding" {
    try testDecode(0, .{ .year = 1970, .days = 0 }, .{
        .month = .jan,
        .day_index = 0,
    }, .{ .hours_into_day = 0, .minutes_into_hour = 0, .seconds_into_minute = 0 });

    try testDecode(31535999, .{ .year = 1970, .days = 364 }, .{
        .month = .dec,
        .day_index = 30,
    }, .{ .hours_into_day = 23, .minutes_into_hour = 59, .seconds_into_minute = 59 });

    try testDecode(1622924906, .{ .year = 2021, .days = 31 + 28 + 31 + 30 + 31 + 4 }, .{
        .month = .jun,
        .day_index = 4,
    }, .{ .hours_into_day = 20, .minutes_into_hour = 28, .seconds_into_minute = 26 });

    try testDecode(1625159473, .{ .year = 2021, .days = 31 + 28 + 31 + 30 + 31 + 30 }, .{
        .month = .jul,
        .day_index = 0,
    }, .{ .hours_into_day = 17, .minutes_into_hour = 11, .seconds_into_minute = 13 });
}
