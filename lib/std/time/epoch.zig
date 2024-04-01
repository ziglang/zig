//! Gregorian calendar date and time relative to unix time.
//!
//! Unix time is time since midnight 1970-01-01, ignoring leap seconds.
//!
//! Uses algorithms from https://howardhinnant.github.io/date_algorithms.html
pub const epoch_year = 1970;

/// Using 32 bit arithmetic, overflow occurs approximately at +/- 5.8 million years.
/// Using 64 bit arithmetic overflow occurs far beyond +/- the age of the universe.
/// The intent is to make range checking superfluous.
pub const Int = i64;
// pub const UInt = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @typeInfo(Int).Int.bits } });

pub const Year = Int;
pub const MonthInt = IntFittingRange(1, 12);
pub const Month = enum(MonthInt) {
    jan = 1,
    feb = 2,
    mar = 3,
    apr = 4,
    may = 5,
    jun = 6,
    jul = 7,
    aug = 8,
    sep = 9,
    oct = 10,
    nov = 11,
    dec = 12,

    /// Convenient conversion to `MonthInt`. jan = 1, dec = 12
    pub fn numeric(self: Month) MonthInt {
        return @intFromEnum(self);
    }

    pub fn days(self: Month, is_leap_year: bool) IntFittingRange(1, 31) {
        return switch (self) {
            .jan => 31,
            .feb => @as(u5, switch (is_leap_year) {
                .leap => 29,
                .not_leap => 28,
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
};

pub fn isLeapYear(y: Year) bool {
    return @mod(y, 4) == 0 and (@mod(y, 100) != 0 or @mod(y, 400) == 0);
}

test isLeapYear {
    try testing.expectEqual(false, isLeapYear(2095));
    try testing.expectEqual(true, isLeapYear(2096));
    try testing.expectEqual(false, isLeapYear(2100));
    try testing.expectEqual(true, isLeapYear(2400));
}

const secs_per_day = 24 * 60 * 60;

pub const Date = struct {
    year: Year = epoch_year,
    month: Month = .jan,
    day: Day = 1,

    pub const Day = IntFittingRange(1, 31);

    pub fn fromSeconds(epoch_seconds: Int) Date {
        const days: Year = @divFloor(epoch_seconds, secs_per_day);
        return fromEpochDays(days);
    }

    pub fn toSeconds(date: Date) Int {
        return date.daysFromEpoch() * secs_per_day;
    }

    pub fn daysFromEpoch(date: Date) Int {
        const y = if (date.month.numeric() <= 2) date.year - 1 else date.year;
        const m: Int = @intCast(date.month.numeric());
        const d = date.day;

        const era = @divFloor(y, era_years);
        const yoe = y - era * era_years;
        const mp = @mod(m + 9, 12);
        const doy = @divTrunc(153 * mp + 2, 5) + d - 1;
        const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
        return era * era_days + doe - first_era;
    }

    pub fn fromEpochDays(days: Int) Date {
        const z = days + first_era;
        const era: Int = @divFloor(z, era_days);
        const doe = z - era * era_days;
        const yoe = @divTrunc(doe -
            @divTrunc(doe, 1460) +
            @divTrunc(doe, 365 * 100 + 100 / 4 - 1) -
            @divTrunc(doe, era_days - 1), 365);
        const doy = doe - (365 * yoe + @divTrunc(yoe, 4) - @divTrunc(yoe, 100));
        const mp = @divTrunc(5 * doy + 2, 153);
        const d: Day = @intCast(doy - @divTrunc(153 * mp + 2, 5) + 1);
        const m = if (mp < 10) mp + 3 else mp - 9;
        var y = yoe + era * era_years;
        if (m <= 2) y += 1;
        return .{ .year = y, .month = @enumFromInt(m), .day = d };
    }

    /// days between 0000-03-01 and 1970-01-01
    const first_era = 719468;
    // Every 400 years the Gregorian calendar repeats.
    const era_years = 400;
    const era_days = 146097;
};

pub const Time = struct {
    hour: Hour = 0,
    minute: Minute = 0,
    second: Second = 0,

    pub const Hour = IntFittingRange(0, 23);
    pub const Minute = IntFittingRange(0, 59);
    pub const Second = IntFittingRange(0, 59);

    pub fn fromSeconds(seconds: Int) Time {
        var day_seconds = std.math.comptimeMod(seconds, secs_per_day);
        const DaySeconds = @TypeOf(day_seconds);

        const hour: Hour = @intCast(day_seconds / (60 * 60));
        day_seconds -= @as(DaySeconds, @intCast(hour)) * 60 * 60;

        const minute: Minute = @intCast(@divFloor(day_seconds, 60));
        day_seconds -= @as(DaySeconds, @intCast(minute)) * 60;

        return .{ .hour = hour, .minute = minute, .second = @intCast(day_seconds) };
    }

    pub fn toSeconds(time: Time) Int {
        var sec: Int = 0;
        sec += @as(Int, time.hour) * 60 * 60;
        sec += @as(Int, time.minute) * 60;
        sec += @as(Int, time.second);

        return sec;
    }
};

pub const DateTime = struct {
    year: Year = epoch_year,
    month: Month = .jan,
    day: Date.Day = 1,
    hour: Time.Hour = 0,
    minute: Time.Minute = 0,
    second: Time.Second = 0,

    pub fn fromSeconds(epoch_seconds: Int) DateTime {
        const date = Date.fromSeconds(epoch_seconds);
        const time = Time.fromSeconds(epoch_seconds);

        return .{
            .year = date.year,
            .month = date.month,
            .day = date.day,
            .hour = time.hour,
            .minute = time.minute,
            .second = time.second,
        };
    }

    pub fn toSeconds(dt: DateTime) Int {
        const date = Date{ .year = dt.year, .month = dt.month, .day = dt.day };
        const time = Time{ .hour = dt.hour, .minute = dt.minute, .second = dt.second };
        return date.toSeconds() + time.toSeconds();
    }
};

pub const Rfc3339 = struct {
    pub fn parseDate(str: []const u8) !Date {
        if (str.len != 10) return error.Parsing;
        const Rfc3339Year = IntFittingRange(0, 9999);
        const year = try std.fmt.parseInt(Rfc3339Year, str[0..4], 10);
        if (str[4] != '-') return error.Parsing;
        const month = try std.fmt.parseInt(MonthInt, str[5..7], 10);
        if (str[7] != '-') return error.Parsing;
        const day = try std.fmt.parseInt(Date.Day, str[8..10], 10);
        return .{ .year = year, .month = @enumFromInt(month), .day = day };
    }

    pub fn parseTime(str: []const u8) !Time {
        if (str.len < 8) return error.Parsing;

        const hour = try std.fmt.parseInt(Time.Hour, str[0..2], 10);
        if (str[2] != ':') return error.Parsing;
        const minute = try std.fmt.parseInt(Time.Minute, str[3..5], 10);
        if (str[5] != ':') return error.Parsing;
        const second = try std.fmt.parseInt(Time.Second, str[6..8], 10);
        // ignore optional subseconds
        // ignore timezone

        return .{ .hour = hour, .minute = minute, .second = second };
    }

    pub fn parseDateTime(str: []const u8) !DateTime {
        if (str.len < 10 + 1 + 8) return error.Parsing;
        const date = try parseDate(str[0..10]);
        if (str[10] != 'T') return error.Parsing;
        const time = try parseTime(str[11..]);
        return .{
            .year = date.year,
            .month = date.month,
            .day = date.day,
            .hour = time.hour,
            .minute = time.minute,
            .second = time.second,
        };
    }
};

fn comptimeParse(comptime time: []const u8) DateTime {
    return Rfc3339.parseDateTime(time) catch unreachable;
}

/// Tests EpochSeconds -> DateTime and DateTime -> EpochSeconds
fn testEpoch(secs: Int, dt: DateTime) !void {
    const actual_dt = DateTime.fromSeconds(secs);
    try std.testing.expectEqualDeep(dt, actual_dt);

    const actual_secs = actual_dt.toSeconds();
    try std.testing.expectEqual(secs, actual_secs);
}

test DateTime {
    // $ date -d @31535999 --iso-8601=seconds
    try testEpoch(0, .{});
    try testEpoch(31535999, comptimeParse("1970-12-31T23:59:59"));
    try testEpoch(1622924906, comptimeParse("2021-06-05T20:28:26"));
    try testEpoch(1625159473, comptimeParse("2021-07-01T17:11:13"));
    // Washington bday, N.S.
    try testEpoch(-7506041400, comptimeParse("1732-02-22T12:30:00"));
    // outside Rfc3339 range
    try testEpoch(-97506041400, .{
        .year = -1120,
        .month = .feb,
        .day = 26,
        .hour = 20,
        .minute = 30,
        .second = 0,
    });
}

const std = @import("../std.zig");
const testing = std.testing;
const IntFittingRange = std.math.IntFittingRange;

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
