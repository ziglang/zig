pub fn DateTime(comptime DateT: type, comptime TimeT: type) type {
    return struct {
        date: Date,
        time: Time = .{},

        pub const Date = DateT;
        pub const Time = TimeT;
        /// Fractional epoch seconds based on `TimeT.precision`:
        ///   0 = seconds
        ///   3 = milliseconds
        ///   6 = microseconds
        ///   9 = nanoseconds
        pub const EpochSubseconds = std.meta.Int(
            @typeInfo(Date.EpochDays).Int.signedness,
            @typeInfo(Date.EpochDays).Int.bits + std.math.log2_int_ceil(usize, Time.subseconds_per_day),
        );

        const Self = @This();

        /// New date time from fractional seconds since `Date.epoch`.
        pub fn fromEpoch(subseconds: EpochSubseconds, time_opts: Time.Options) Self {
            const days = @divFloor(subseconds, s_per_day * Time.subseconds_per_s);
            const new_date = Date.fromEpoch(@intCast(days));
            const day_seconds = std.math.comptimeMod(subseconds, s_per_day * Time.subseconds_per_s);
            const new_time = Time.fromDaySeconds(day_seconds, time_opts);
            return .{ .date = new_date, .time = new_time };
        }

        /// Returns fractional seconds since `Date.epoch`.
        pub fn toEpoch(self: Self) EpochSubseconds {
            var res: EpochSubseconds = 0;
            res += @as(EpochSubseconds, self.date.toEpoch()) * s_per_day * Time.subseconds_per_s;
            res += self.time.toDaySeconds();
            return res;
        }

        pub fn add(
            self: Self,
            year: Date.Year,
            month: Date.MonthAdd,
            day: Date.IEpochDays,
            hour: i64,
            minute: i64,
            second: i64,
            subsecond: i64,
        ) DateTime {
            const time = self.time.addWithOverflow(hour, minute, second, subsecond);
            const date = self.date.add(year, month, day + time.day_overflow);
            return .{ .date = date, .time = time.time };
        }

        pub fn fromRfc3339(str: []const u8) !Self {
            if (str.len < 10 + "hh:mm:ssZ".len) return error.Parsing;
            if (std.ascii.toUpper(str[10]) != 'T') return error.Parsing;
            return .{
                .date = try Date.fromRfc3339(str[0..10]),
                .time = try Time.fromRfc3339(str[11..]),
            };
        }

        pub fn toRfc3339(self: Self, writer: anytype) !void {
            try self.date.toRfc3339(writer);
            try writer.writeByte('T');
            try self.time.toRfc3339(writer);
        }
    };
}

pub fn DateTimeAdvanced(
    comptime Year: type,
    epoch: comptime_int,
    time_precision: comptime_int,
    comptime time_zoned: bool,
) type {
    return DateTime(date_mod.Date(Year, epoch), time_mod.Time(time_precision, time_zoned));
}

pub const Date16Time = DateTime(date_mod.Date16, time_mod.Time(0, false));

comptime {
    assert(@sizeOf(Date16Time) == 8);
}

/// Tests EpochSeconds -> DateTime and DateTime -> EpochSeconds
fn testEpoch(secs: Date16Time.EpochSubseconds, dt: Date16Time) !void {
    const actual_dt = Date16Time.fromEpoch(secs, .{});
    try std.testing.expectEqual(dt, actual_dt);
    try std.testing.expectEqual(secs, dt.toEpoch());
}

test "Date epoch" {
    // $ date -d @31535999 --iso-8601=seconds
    try testEpoch(0, .{ .date = .{ .year = 1970, .month = .jan, .day = 1 } });
    try testEpoch(31535999, .{
        .date = .{ .year = 1970, .month = .dec, .day = 31 },
        .time = .{ .hour = 23, .minute = 59, .second = 59 },
    });
    try testEpoch(1622924906, .{
        .date = .{ .year = 2021, .month = .jun, .day = 5 },
        .time = .{ .hour = 20, .minute = 28, .second = 26 },
    });
    try testEpoch(1625159473, .{
        .date = .{ .year = 2021, .month = .jul, .day = 1 },
        .time = .{ .hour = 17, .minute = 11, .second = 13 },
    });
    // Washington bday, proleptic
    try testEpoch(-7506041400, .{
        .date = .{ .year = 1732, .month = .feb, .day = 22 },
        .time = .{ .hour = 12, .minute = 30 },
    });
    // minimum date
    try testEpoch(-1096225401600, .{
        .date = .{ .year = std.math.minInt(i16), .month = .jan, .day = 1 },
    });
    // $ date -d '32767-12-31 UTC' +%s
    try testEpoch(971890876800, .{
        .date = .{ .year = std.math.maxInt(i16), .month = .dec, .day = 31 },
    });
}

test "Date RFC 3339 section 5.8" {
    const T = DateTime(date_mod.Date16, time_mod.Time(3, true));
    const expectEqual = std.testing.expectEqual;
    const t1 = T{
        .date = .{ .year = 1985, .month = .apr, .day = 12 },
        .time = .{ .hour = 23, .minute = 20, .second = 50, .subsecond = 520 },
    };
    try expectEqual(t1, try T.fromRfc3339("1985-04-12T23:20:50.52Z"));
    const t2 = T{
        .date = .{ .year = 1996, .month = .dec, .day = 19 },
        .time = .{ .hour = 16, .minute = 39, .second = 57, .offset = -8 * 60 },
    };
    try expectEqual(t2, try T.fromRfc3339("1996-12-19T16:39:57-08:00"));
    const t3 = T{
        .date = .{ .year = 1990, .month = .dec, .day = 31 },
        .time = .{ .hour = 23, .minute = 59, .second = 60 },
    };
    try expectEqual(t3, try T.fromRfc3339("1990-12-31T23:59:60Z"));
    const t4 = T{
        .date = .{ .year = 1990, .month = .dec, .day = 31 },
        .time = .{ .hour = 15, .minute = 59, .second = 60, .offset = -8 * 60 },
    };
    try expectEqual(t4, try T.fromRfc3339("1990-12-31T15:59:60-08:00"));
    const t5 = T{
        .date = .{ .year = 1937, .month = .jan, .day = 1 },
        .time = .{ .hour = 12, .second = 27, .subsecond = 870, .offset = 20 },
    };
    try expectEqual(t5, try T.fromRfc3339("1937-01-01T12:00:27.87+00:20"));

    var buf: [32]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try t5.toRfc3339(stream.writer());
    try std.testing.expectEqualStrings("1937-01-01T12:00:27.870+00:20", stream.getWritten());
}

const std = @import("std.zig");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const s_per_day = time_mod.s_per_day;
const assert = std.debug.assert;
