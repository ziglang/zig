const std = @import("std.zig");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const s_per_day = time_mod.s_per_day;
const assert = std.debug.assert;

pub fn DateTimeAdvanced(comptime DateT: type, comptime TimeT: type) type {
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
        pub fn fromEpoch(subseconds: EpochSubseconds) Self {
            const days = @divFloor(subseconds, s_per_day * Time.subseconds_per_s);
            const new_date = Date.fromEpoch(@intCast(days));
            const day_seconds = std.math.comptimeMod(subseconds, s_per_day * Time.subseconds_per_s);
            const new_time = Time.fromDaySeconds(day_seconds);
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
        ) Self {
            const time = self.time.addWithOverflow(hour, minute, second, subsecond);
            const date = self.date.add(year, month, day + time.day_overflow);
            return .{ .date = date, .time = time.time };
        }
    };
}

/// A DateTime using days since `1970-01-01` for its epoch methods.
///
/// Supports dates between years -32_768 and 32_768.
/// Supports times at a second resolution.
pub const DateTime = DateTimeAdvanced(date_mod.Date, time_mod.Time(0));

comptime {
    assert(@sizeOf(DateTime) == 8);
}

/// Tests EpochSeconds -> DateTime and DateTime -> EpochSeconds
fn testEpoch(secs: DateTime.EpochSubseconds, dt: DateTime) !void {
    const actual_dt = DateTime.fromEpoch(secs);
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
