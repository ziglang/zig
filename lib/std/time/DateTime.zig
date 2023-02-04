date: Date = .{},
time: Time = .{},
is_dst: ?bool = null,

const DateTime = @This();
const std = @import("../std.zig");
const Date = std.Date;
const Time = std.Time;
const Month = Date.Month;
const Weekday = Date.Weekday;
const Year = Date.Year;
const DayOfMonth = Date.DayOfMonth;
const PosixTz = std.tz.PosixTz;

const s_per_day = std.time.s_per_day;
const s_per_hour = std.time.s_per_hour;

const days_per_quadricentennial = 365 * 400 + 97; // 400 years
const days_per_century = 365 * 100 + 24;
const days_per_quadrennial = 365 * 4 + 1; // 4 years

const seconds_from_epoch_to_y2k = 30 * (365 * s_per_day) + 7 * s_per_day;

pub const epoch = DateTime{};

/// Parse RFC2616 (HTTP) date/time string.
pub fn parse(str: []const u8) !DateTime {
    return parse1123(str) catch parseAsctime(str) catch parse850(str);
}

/// Parse RFC850 date/time string.
pub fn parse850(str: []const u8) !DateTime {
    // <wday-name>, <day>-<month-abbrev><2digit-year> <hour>:<minute>:<second> ["GMT"]
    // Sunday, 06-Nov-94 08:49:37 GMT

    var it = std.mem.tokenize(u8, str, ", ");
    _ = it.next() orelse return error.ParseError;

    var d_it = std.mem.split(u8, it.next() orelse return error.ParseError, "-");
    const mday = try std.fmt.parseInt(DayOfMonth, d_it.next() orelse return error.ParseError, 10);
    const month_abbrev = d_it.next() orelse return error.ParseError;
    const year = 1900 + try std.fmt.parseInt(Year, d_it.next() orelse return error.ParseError, 10);

    const time_part = it.next() orelse return error.ParseError;
    return DateTime{
        .date = .{
            .year = year,
            .month = Month.parse(month_abbrev) orelse return error.ParseError,
            .day_of_month = mday,
        },
        .time = try Time.parse(time_part),
    };
}

/// Parse RFC1123 date/time string.
pub fn parse1123(str: []const u8) !DateTime {
    // <wday-abbrev>, <day> <month-abbrev> <year> <hour>:<minute>:<second> ["GMT"]
    // Sun, 06 Nov 1994 08:49:37 GMT

    var it = std.mem.tokenize(u8, str, ", ");
    _ = it.next() orelse return error.ParseError;
    const mday = try std.fmt.parseInt(DayOfMonth, it.next() orelse return error.ParseError, 10);
    const month_abbrev = it.next() orelse return error.ParseError;
    const year = try std.fmt.parseInt(Year, it.next() orelse return error.ParseError, 10);
    const time_part = it.next() orelse return error.ParseError;

    return DateTime{
        .date = .{
            .year = year,
            .month = Month.parse(month_abbrev) orelse return error.ParseError,
            .day_of_month = mday,
        },
        .time = try Time.parse(time_part),
    };
}

/// Parse ANSI C asctime() date/time string.
pub fn parseAsctime(str: []const u8) !DateTime {
    // <wday-abbrev> <month-abbrev> <day> <hour>:<minute>:<second> <year>
    // Sun Nov  6 08:49:37 1994

    var it = std.mem.tokenize(u8, str, " ");
    _ = it.next() orelse return error.ParseError;
    const month_abbrev = it.next() orelse return error.ParseError;
    const mday = try std.fmt.parseInt(DayOfMonth, it.next() orelse return error.ParseError, 10);
    const time_part = it.next() orelse return error.ParseError;
    const year = try std.fmt.parseInt(Year, it.next() orelse return error.ParseError, 10);

    return DateTime{
        .date = .{
            .year = year,
            .month = Month.parse(month_abbrev) orelse return error.ParseError,
            .day_of_month = mday,
        },
        .time = try Time.parse(time_part),
    };
}

/// Parse iso8601 date/time string.
pub fn parse8601(str: []const u8) !DateTime {
    // <year>-<month>-<day>[T<hour>:<minute>[:second[.millsec]]][Z]
    // 1994-11-06T08:49:37.000Z

    const no_z = std.mem.trimRight(u8, str, "Z");
    var it = std.mem.split(u8, no_z, "T");

    var d_it = std.mem.split(u8, it.next().?, "-");
    const year = try std.fmt.parseInt(Year, d_it.next().?, 10);
    const month = try std.fmt.parseInt(u4, d_it.next() orelse return error.ParseError, 10);
    const mday = try std.fmt.parseInt(DayOfMonth, d_it.next() orelse return error.ParseError, 10);

    const time = if (it.next()) |time_part|
        try Time.parse(time_part)
    else
        Time{};

    return DateTime{
        .date = .{
            .year = year,
            .month = try std.meta.intToEnum(Month, month),
            .day_of_month = mday,
        },
        .time = time,
    };
}

/// Initialize using the current UTC time.
pub fn now() DateTime {
    return fromSecondsSinceEpoch(std.time.timestamp());
}

/// Initialize using the current time in the specified timezone.
/// If `time_type` is not null, it will be updated.
pub fn local(tz: *const std.Tz, time_type: ?*std.tz.Timetype) !DateTime {
    return fromSecondsSinceEpochLocal(std.time.timestamp(), tz, time_type);
}

/// Initialize using the number of seconds elapsed since the epoch (Jan 1 1970 UTC) in the specified timezone.
/// If `time_type` is not null, it will be updated.
pub fn fromSecondsSinceEpochLocal(t: i64, tz: *const std.Tz, time_type: ?*std.tz.Timetype) !DateTime {
    const ttype = findTzType(t, tz) orelse return error.TimeTypeNotFound;
    var dt = fromSecondsSinceEpoch(t + ttype.offset);
    dt.is_dst = ttype.isDst();
    if (time_type) |ptr| ptr.* = ttype;
    return dt;
}

/// Initialize using the number of seconds elapsed since the epoch (Jan 1 1970 UTC) in UTC time.
pub fn fromSecondsSinceEpoch(t: i64) DateTime {
    // 2000-03-01
    const leapoch = seconds_from_epoch_to_y2k + (31 + 29) * s_per_day;

    var secs = t - leapoch;
    var days = @intCast(i32, @divFloor(secs, s_per_day));
    secs = @mod(secs, s_per_day);

    const quadricentennials = @divFloor(days, days_per_quadricentennial);
    days = @mod(days, days_per_quadricentennial);

    var centuries = @divTrunc(days, days_per_century);
    if (centuries == 4) centuries -= 1;
    days -= centuries * days_per_century;

    var quadrennials = @divTrunc(days, days_per_quadrennial);
    if (quadrennials == 25) quadrennials -= 1;
    days -= quadrennials * days_per_quadrennial;

    var years = @divTrunc(days, 365);
    if (years == 4) years -= 1;
    days -= years * 365;

    const days_in_month = [_]i32{ 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29 };

    var month: usize = 0;
    for (days_in_month) |dim| {
        if (days < dim) break;
        days -= dim;
        month += 1;
    }

    if (month >= 10) {
        month -= 9;
        years += 1;
    } else {
        month += 3;
    }

    return .{
        .date = .{
            .year = 2000 + years + 4 * quadrennials + 100 * centuries + 400 * quadricentennials,
            .month = @intToEnum(Month, month),
            .day_of_month = @intCast(u5, days + 1),
        },
        .time = Time.fromSecondsSinceMidnight(@intCast(u17, secs)),
    };
}

/// Get the number of seconds elapsed from this date/time in the specified timezone since the epoch (Jan 1 1970 UTC).
/// Negative values are returned for dates before the epoch.
/// If `time_type` is not null, it will be updated.
/// If `is_dst` is set, it will be used find the correct `time_type`.
pub fn secondsSinceEpochLocal(self: *const DateTime, tz: *const std.Tz, time_type: ?*std.tz.Timetype) !i64 {
    var t = self.secondsSinceEpoch();
    const ttype = self.findTzTypeLocal(t, tz) orelse return error.TimeTypeNotFound;
    if (time_type) |ptr| ptr.* = ttype;
    return t - ttype.offset;
}

/// Get the number of seconds elapsed from this date/time as UTC since the epoch (Jan 1 1970 UTC).
/// Negative values are returned for dates before the epoch.
pub fn secondsSinceEpoch(self: *const DateTime) i64 {
    return self.date.secondsSinceEpoch() + self.time.secondsSinceMidnight();
}

/// Calculate the weekday for this date.
pub inline fn weekday(self: *const DateTime) Weekday {
    return self.date.weekday();
}

// Calculate the number of days in this month.
pub fn daysInMonth(self: *const Date) DayOfMonth {
    return self.date.daysInMonth();
}

/// Determine if the year is a leap year.
pub inline fn isLeapYear(self: *const DateTime) bool {
    return self.date.isLeapYear();
}

/// Calculate the 0-based index of the day into the year.
pub inline fn dayOfYear(self: *const DateTime) Date.DayOfYear {
    return self.date.dayOfYear();
}

/// Formatter for date/time.  See man strftime(3) for description of each format specifier.
pub fn format(self: DateTime, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    inline for (fmt) |c, i| {
        switch (c) {
            'a', 'A', 'b', 'B', 'd', 'D', 'e', 'F', 'h', 'j', 'm', 'u', 'U', 'w', 'W', 'x', 'y', 'Y' => try self.date.format(fmt[i .. i + 1], .{}, writer),
            'H', 'I', 'k', 'l', 'M', 'p', 'P', 'r', 'R', 'S', 'T', 'X' => try self.time.format(fmt[i .. i + 1], .{}, writer),
            'c' => try writer.print("{s} {s} {d:2} {d:0>2}:{d:0>2}:{d:0>2} {d}", .{
                self.date.weekday().abbrev(),
                self.date.month.abbrev(),
                self.date.day_of_month,
                self.time.hour,
                self.time.minute,
                self.time.second,
                self.date.year,
            }),
            's' => try std.fmt.formatInt(self.secondsSinceEpoch(), 10, .lower, .{}, writer),
            '-', '/', '.', ',', ' ' => try writer.writeByte(c),
            ';' => try writer.writeByte(':'),
            else => @compileError("Unsupported date time format"),
        }
    }
}

pub fn eql(a: *const DateTime, b: *const DateTime) bool {
    return a.date.eql(b.date) and a.time.eql(b.time) and a.is_dst == b.is_dst;
}

/// `t` is the number of seconds since the epoch in UTC time.
/// It can only be associated with one timezone time type.
fn findTzType(t: i64, tz: *const std.Tz) ?std.tz.Timetype {
    if (findTransition(false, t, false, tz)) |transition| {
        return transition.timetype.*;
    }

    const posix = &(tz.posix orelse return null);
    var year = fromSecondsSinceEpoch(t).date.year;
    var start = PosixTz.ruleToSecs(posix.start_rule, year) - posix.std.offset;
    var end = PosixTz.ruleToSecs(posix.end_rule, year) - posix.dst.offset;

    const is_dst = if (start < end)
        t >= start and t < end
    else
        t < end or t >= start;

    return if (is_dst) posix.dst else posix.std;
}

/// `t` is the number of seconds since the epoch in local time.
/// It can be associated with two timezone time types,
/// so we use `self.is_dst` to apply the correct type.
fn findTzTypeLocal(self: *const DateTime, t: i64, tz: *const std.Tz) ?std.tz.Timetype {
    if (findTransition(true, t, self.is_dst, tz)) |transition| {
        return transition.timetype.*;
    }

    const posix = &(tz.posix orelse return null);
    var start = PosixTz.ruleToSecs(posix.start_rule, self.date.year);
    var end = PosixTz.ruleToSecs(posix.end_rule, self.date.year);

    const is_dst = self.is_dst orelse {
        const is_dst = if (start < end)
            t >= start and t < end
        else
            t < end or t >= start;
        return if (is_dst) posix.dst else posix.std;
    };

    if (is_dst) {
        // change start to dst time
        start -= posix.std.offset - posix.dst.offset;
        const is_dst2 = if (start < end)
            t >= start and t <= end
        else
            t <= end or t >= start;
        return if (is_dst2) posix.dst else null;
    } else {
        // change end to std time
        end -= posix.dst.offset - posix.std.offset;
        const is_std = if (start < end)
            t <= start or t >= end
        else
            t >= end and t <= start;
        return if (is_std) posix.std else null;
    }
}

fn findTransition(comptime is_local: bool, t: i64, want_dst: ?bool, tz: *const std.Tz) ?std.tz.Transition {
    var n: usize = tz.transitions.len;
    if (n == 0) return null;

    const transition0 = &tz.transitions[0];
    const tt0 = transition0.ts + (if (is_local) transition0.timetype.offset else 0);
    if (tt0 > t) {
        // find first non-dst
        for (tz.transitions) |transition| {
            if (!transition.timetype.isDst()) {
                return transition;
            }
        }
        return null;
    }

    const transitionN = &tz.transitions[n - 1];
    const ttN = transitionN.ts + (if (is_local) transitionN.timetype.offset else 0);
    if (ttN < t) {
        return null;
    }

    // binary search
    var left: usize = 0;
    while (n > 1) {
        const idx = left + n / 2;
        const transition = &tz.transitions[idx];
        const tt = transition.ts + (if (is_local) transition.timetype.offset else 0);
        if (tt <= t) {
            left = idx;
            n /= 2;
        } else {
            n -= n / 2;
        }
    }

    const transition = tz.transitions[left];
    if (!is_local) {
        return transition;
    }

    // for transitions that fall backwards,
    // we might actually want to use the previous transition

    const w_dst = want_dst orelse return transition;
    if (transition.timetype.isDst() != w_dst and left > 0) {
        const prev = tz.transitions[left - 1];
        if (prev.timetype.isDst() == w_dst) {
            // convert current transition using previous offset
            const tt = transition.ts + prev.timetype.offset;
            if (t <= tt) {
                return prev;
            }
        }
        return null;
    }

    // make sure that time occurs before the next transition
    // otherwise, the time might not exist (eg 02:01 on day DST ends)

    if (left + 1 < tz.transitions.len) {
        const next = tz.transitions[left - 1];
        // convert next transition using current offset
        const tt = next.ts + transition.timetype.offset;
        if (t > tt) {
            return null;
        }
    }

    return transition;
}

fn testDateTime(wday: Weekday, yday: Date.DayOfYear, ts: i64, datetime: DateTime) !void {
    try std.testing.expectEqual(wday, datetime.weekday());
    try std.testing.expectEqual(yday, datetime.dayOfYear());
    try std.testing.expectEqual(ts, datetime.secondsSinceEpoch());
    try std.testing.expectEqual(DateTime.fromSecondsSinceEpoch(ts), datetime);
}

test "utc datetime" {
    try testDateTime(.Thursday, 0, 0, epoch);
    try testDateTime(.Wednesday, 303, -2182809600, .{
        .date = .{ .year = 1900, .month = .October, .day_of_month = 31 },
        .time = Time.midnight,
    });
    try testDateTime(.Sunday, 67, 1583632799, .{
        .date = .{ .year = 2020, .month = .March, .day_of_month = 8 },
        .time = .{ .hour = 1, .minute = 59, .second = 59 },
    });
    try testDateTime(.Thursday, 364, 4102444799, .{
        .date = .{ .year = 2099, .month = .December, .day_of_month = 31 },
        .time = .{ .hour = 23, .minute = 59, .second = 59 },
    });
    try testDateTime(.Friday, 0, 4102444800, .{
        .date = .{ .year = 2100, .month = .January, .day_of_month = 1 },
        .time = Time.midnight,
    });
    try testDateTime(.Saturday, 0, 13569465600, .{
        .date = .{ .year = 2400, .month = .January, .day_of_month = 1 },
        .time = Time.midnight,
    });
    try testDateTime(.Sunday, 130, 33777129600, .{
        .date = .{ .year = 3040, .month = .May, .day_of_month = 10 },
        .time = Time.midnight,
    });
}

fn testLocalDateTime(tz: *const std.Tz, ts: i64, datetime: DateTime) !void {
    try std.testing.expectEqual(ts, try datetime.secondsSinceEpochLocal(tz, null));
    try std.testing.expectEqual(try DateTime.fromSecondsSinceEpochLocal(ts, tz, null), datetime);
}

fn testLocalDateTimeNotExists(tz: *const std.Tz, datetime: DateTime) !void {
    try std.testing.expectError(error.TimeTypeNotFound, datetime.secondsSinceEpochLocal(tz, null));
}

fn testEastern(tz: *const std.Tz) !void {
    try testLocalDateTime(tz, 1583650800 - 1, .{
        .date = .{ .year = 2020, .month = .March, .day_of_month = 8 },
        .time = .{ .hour = 1, .minute = 59, .second = 59 },
        .is_dst = false,
    });
    // one hour spring forward
    try testLocalDateTime(tz, 1583650800, .{
        .date = .{ .year = 2020, .month = .March, .day_of_month = 8 },
        .time = .{ .hour = 3 },
        .is_dst = true,
    });
    // time that does not exist
    try testLocalDateTimeNotExists(tz, .{
        .date = .{ .year = 2020, .month = .March, .day_of_month = 8 },
        .time = .{ .hour = 2, .minute = 1, .second = 0 },
        .is_dst = false,
    });
    try testLocalDateTimeNotExists(tz, .{
        .date = .{ .year = 2020, .month = .March, .day_of_month = 8 },
        .time = .{ .hour = 2, .minute = 1, .second = 0 },
        .is_dst = true,
    });

    try testLocalDateTime(tz, 1604210400 - 1, .{
        .date = .{ .year = 2020, .month = .November, .day_of_month = 1 },
        .time = .{ .hour = 1, .minute = 59, .second = 59 },
        .is_dst = true,
    });
    // one hour fallback
    try testLocalDateTime(tz, 1604210400, .{
        .date = .{ .year = 2020, .month = .November, .day_of_month = 1 },
        .time = .{ .hour = 1 },
        .is_dst = false,
    });
    // same time as above, but before fallback
    try testLocalDateTime(tz, 1604210400 - s_per_hour, .{
        .date = .{ .year = 2020, .month = .November, .day_of_month = 1 },
        .time = .{ .hour = 1 },
        .is_dst = true,
    });
}

test "local datetime (posix)" {
    const tz = std.Tz{
        .allocator = undefined,
        .transitions = &.{},
        .timetypes = &.{},
        .leapseconds = &.{},
        .posix = try std.tz.PosixTz.parse("EST5EDT,M3.2.0,M11.1.0"),
    };

    try testEastern(&tz);
}

test "local datetime (tzfile)" {
    const data = @embedFile("../tz/new_york.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try testEastern(&tz);
}

test "parse datetime" {
    const dt = DateTime{
        .date = .{ .year = 1994, .month = .November, .day_of_month = 6 },
        .time = .{ .hour = 8, .minute = 49, .second = 37 },
    };

    try std.testing.expectEqual(dt, try DateTime.parse1123("Sun, 06 Nov 1994 08:49:37 GMT"));
    try std.testing.expectEqual(dt, try DateTime.parse850("Sunday, 06-Nov-94 08:49:37 GMT"));
    try std.testing.expectEqual(dt, try DateTime.parseAsctime("Sun Nov  6 08:49:37 1994"));

    try std.testing.expectEqual(dt, try DateTime.parse("Sun, 06 Nov 1994 08:49:37 GMT"));
    try std.testing.expectEqual(dt, try DateTime.parse("Sunday, 06-Nov-94 08:49:37 GMT"));
    try std.testing.expectEqual(dt, try DateTime.parse("Sun Nov  6 08:49:37 1994"));

    try std.testing.expectEqual(dt, try DateTime.parse8601("1994-11-06T08:49:37.000Z"));
}

test "format datetime" {
    const dt = DateTime{
        .date = .{ .year = 2010, .month = .March, .day_of_month = 11 },
        .time = .{ .hour = 0, .minute = 59, .second = 59 },
    };
    try std.testing.expectFmt("-/., ", "{-/., }", .{dt});
    try std.testing.expectFmt(" 0 12", "{k l}", .{dt});
    try std.testing.expectFmt("00:59:59 AM", "{H;M;S p}", .{dt});
    try std.testing.expectFmt("12:59:59 AM", "{r}", .{dt});
    try std.testing.expectFmt("00:59:59", "{T}", .{dt});
    try std.testing.expectFmt("10 070 10 10", "{y j U W}", .{dt});
    try std.testing.expectFmt("03/11/10", "{D}", .{dt});
    try std.testing.expectFmt("2010-03-11 am", "{F P}", .{dt});
    try std.testing.expectFmt("Thu Mar 11 00:59:59 2010", "{a b d T Y}", .{dt});
    try std.testing.expectFmt("Thu Mar 11 00:59:59 2010", "{c}", .{dt});
    try std.testing.expectFmt("1268269199", "{s}", .{dt});
}
