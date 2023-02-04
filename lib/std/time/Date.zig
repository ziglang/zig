year: Year = 1970,
month: Month = .January,
day_of_month: DayOfMonth = 1, // 1 - 31

const Date = @This();
const std = @import("../std.zig");
const s_per_day = std.time.s_per_day;

const seconds_from_epoch_to_y2k = 30 * (365 * s_per_day) + 7 * s_per_day;

pub const Year = i32;
pub const DayOfMonth = u5; // 1-31
pub const DayOfYear = u9; // 0-365
pub const WeekOfYear = u6; // 0-53

pub const Month = enum(u4) {
    January = 1,
    February,
    March,
    April,
    May,
    June,
    July,
    August,
    September,
    October,
    November,
    December,

    /// Get the 3 letter abbreviation of the month
    pub fn abbrev(month: Month) []const u8 {
        return @tagName(month)[0..3];
    }

    /// Determine the month from the first three letters of `str`.
    pub fn parse(str: []const u8) ?Month {
        const str3 = if (str.len >= 3) str[0..3] else return null;
        inline for (std.meta.fields(Month)) |field| {
            const month = @field(Month, field.name);
            if (std.ascii.eqlIgnoreCase(str3, field.name[0..3])) {
                return month;
            }
        }
        return null;
    }

    /// Calculate the number of days in this month.
    pub fn daysInMonth(month: Month, is_leap: bool) DayOfMonth {
        return if (month == .February and is_leap)
            29
        else
            ([_]DayOfMonth{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[@enumToInt(month) - 1];
    }

    /// Calculate the number of seconds this month is into the year.
    pub fn secondsIntoYear(month: Month, is_leap: bool) u32 {
        const S = s_per_day;
        const secs_through_month = [_]u32{ 0, 31 * S, 59 * S, 90 * S, 120 * S, 151 * S, 181 * S, 212 * S, 243 * S, 273 * S, 304 * S, 334 * S };
        const midx = @enumToInt(month) - 1;
        return secs_through_month[midx] + @as(u32, if (is_leap and midx >= 2) S else 0);
    }
};

pub const Weekday = enum(u3) {
    Sunday,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,

    /// Get the 3 letter abbreviation of the weekday
    pub fn abbrev(wday: Weekday) []const u8 {
        return @tagName(wday)[0..3];
    }
};

/// Get the number of seconds elapsed from this date as UTC since the epoch (Jan 1 1970 UTC).
/// Negative values are returned for dates before the epoch.
pub fn secondsSinceEpoch(self: *const Date) i64 {
    var is_leap = false;
    const t = yearToSecs(self.year, &is_leap);
    return t + self.month.secondsIntoYear(is_leap) + @as(i64, self.day_of_month - 1) * s_per_day;
}

/// Calculate the weekday for this date.
pub fn weekday(self: *const Date) Weekday {
    const secs = self.secondsSinceEpoch();
    const days = @divFloor(secs, s_per_day);
    return @intToEnum(Weekday, @mod(days + 4, 7));
}

/// Calculate the number of days in this month.
pub fn daysInMonth(self: *const Date) DayOfMonth {
    return self.month.daysInMonth(self.isLeapYear());
}

/// Determine if the year is a leap year.
pub fn isLeapYear(self: *const Date) bool {
    if (@mod(self.year, 4) != 0) return false;
    return @mod(self.year, 100) != 0 or @mod(self.year, 400) == 0;
}

/// Calculate the 0-based index of the day into the year.
pub fn dayOfYear(self: *const Date) DayOfYear {
    const days_through_month = [_]u9{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    const midx = @enumToInt(self.month) - 1;
    return days_through_month[midx] + self.day_of_month - @as(u9, if (self.isLeapYear() and midx >= 2) 0 else 1);
}

/// Calculate the 0-based week number of the year, where the first Sunday starts week 1.
pub fn weekOfYearFromFirstSunday(self: *const Date) WeekOfYear {
    return @intCast(WeekOfYear, (self.dayOfYear() + 7 - @enumToInt(self.weekday())) / 7);
}

/// Calculate the 0-based week number of the year, where the first Monday starts week 1.
pub fn weekOfYearFromFirstMonday(self: *const Date) WeekOfYear {
    return @intCast(WeekOfYear, (self.dayOfYear() + 7 - ((@as(u6, @enumToInt(self.weekday())) + 6) % 7)) / 7);
}

/// Return the date for the following day.
pub fn tomorrow(self: *const Date) Date {
    if (self.day_of_month < self.daysInMonth()) {
        return .{
            .year = self.year,
            .month = self.month,
            .day_of_month = self.day_of_month + 1,
        };
    }
    var month = self.month;
    var year = self.year;
    if (month == .December) {
        month = .January;
        year += 1;
    } else {
        month = @intToEnum(Month, @enumToInt(month) + 1);
    }
    return .{
        .year = year,
        .month = month,
        .day_of_month = 1,
    };
}

/// Return the date for the previous day.
pub fn yesterday(self: *const Date) Date {
    if (self.day_of_month > 1) {
        return .{
            .year = self.year,
            .month = self.month,
            .day_of_month = self.day_of_month - 1,
        };
    }
    var date = Date{
        .year = self.year,
        .month = self.month,
        .day_of_month = 1,
    };
    if (date.month == .January) {
        date.month = .December;
        date.year -= 1;
    } else {
        date.month = @intToEnum(Month, @enumToInt(date.month) - 1);
    }
    date.day_of_month = date.daysInMonth();
    return date;
}

/// Formatter for dates.  See man strftime(3) for description of each format specifier.
pub fn format(self: Date, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    inline for (fmt) |c| {
        switch (c) {
            'a' => try writer.writeAll(self.weekday().abbrev()),
            'A' => try writer.writeAll(@tagName(self.weekday())),
            'b', 'h' => try writer.writeAll(self.month.abbrev()),
            'B' => try writer.writeAll(@tagName(self.month)),
            'd' => try std.fmt.formatInt(self.day_of_month, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'D' => try writer.print("{d:0>2}/{d:0>2}/{d:0>2}", .{ @enumToInt(self.month), self.day_of_month, @intCast(u7, @mod(self.year, 100)) }),
            'e' => try std.fmt.formatInt(self.day_of_month, 10, .lower, .{ .width = 2 }, writer),
            'F', 'x' => try writer.print("{d}-{d:0>2}-{d:0>2}", .{ self.year, @enumToInt(self.month), self.day_of_month }),
            'j' => try std.fmt.formatInt(self.dayOfYear() + 1, 10, .lower, .{ .width = 3, .fill = '0' }, writer),
            'm' => try std.fmt.formatInt(@enumToInt(self.month), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'u' => try std.fmt.formatInt(@enumToInt(self.weekday() + 1), 10, .lower, .{}, writer),
            'U' => try std.fmt.formatInt(self.weekOfYearFromFirstSunday(), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'w' => try std.fmt.formatInt(@enumToInt(self.weekday()), 10, .lower, .{}, writer),
            'W' => try std.fmt.formatInt(self.weekOfYearFromFirstMonday(), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'y' => try std.fmt.formatInt(@intCast(u7, @mod(self.year, 100)), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'Y' => try std.fmt.formatInt(self.year, 10, .lower, .{}, writer),
            '-', '/', '.', ',', ' ' => try writer.writeByte(c),
            ';' => try writer.writeByte(':'),
            else => @compileError("Unsupported date format"),
        }
    }
}

pub fn eql(a: Date, b: Date) bool {
    return a.year == b.year and a.month == b.month and a.day_of_month == b.day_of_month;
}

pub fn yearToSecs(year: i32, is_leap: *bool) i64 {
    if (year >= 1970 and year < 2100) {
        is_leap.* = (year & 3) == 0;
        const leaps = ((year - 1968) >> 2) - @as(i64, if (is_leap.*) 1 else 0);
        return @as(i64, year - 1970) * (365 * s_per_day) + leaps * s_per_day;
    }

    const years_since_y2k = year - 2000;
    const quadricentennials = @divFloor(years_since_y2k, 400);
    const years_since_quadricentennial = @mod(years_since_y2k, 400);
    var leaps = quadricentennials * 97;

    if (years_since_quadricentennial == 0) {
        is_leap.* = true;
    } else {
        const centuries = @divTrunc(years_since_quadricentennial, 100);
        leaps += centuries * 24;

        const years_since_century = @rem(years_since_quadricentennial, 100);
        if (years_since_century == 0) {
            is_leap.* = false;
            leaps += 1;
        } else {
            leaps += years_since_century >> 2;
            is_leap.* = (year & 3) == 0;
            if (!is_leap.*) {
                leaps += 1;
            }
        }
    }

    return @as(i64, years_since_y2k) * (365 * s_per_day) + @as(i64, leaps) * s_per_day + seconds_from_epoch_to_y2k;
}

test "month abbrev" {
    try std.testing.expectEqualStrings("Mar", Month.abbrev(.March));
    try std.testing.expectEqualStrings("Oct", Month.abbrev(.October));
}

test "weekday abbrev" {
    try std.testing.expectEqualStrings("Tue", Weekday.abbrev(.Tuesday));
    try std.testing.expectEqualStrings("Fri", Weekday.abbrev(.Friday));
}

test "parse month" {
    try std.testing.expectEqual(Month.March, Month.parse("Mar") orelse return error.TestFailed);
    try std.testing.expectEqual(Month.March, Month.parse("marc") orelse return error.TestFailed);
    try std.testing.expectEqual(@as(?Month, null), Month.parse("Invalid"));
}

test "date weekday" {
    var date = Date{
        .year = 1969,
        .month = .December,
        .day_of_month = 31,
    };
    try std.testing.expectEqual(Weekday.Wednesday, date.weekday());

    date = .{
        .year = 2400,
        .month = .January,
        .day_of_month = 1,
    };
    try std.testing.expectEqual(Weekday.Saturday, date.weekday());
}
