pub fn DateTime(comptime Year: type, time_precision: comptime_int) type {
    return struct {
        date: Date,
        time: Time = .{},

        pub const Date = date_mod.Date(Year);
        pub const Time = time_mod.Time(time_precision);
        pub const EpochSeconds = i64;

        const Self = @This();

        pub fn fromEpoch(seconds: EpochSeconds) Self {
            const days = @divFloor(seconds, s_per_day * Time.fs_per_s);
            const new_date = Date.fromEpoch(@intCast(days));
            const day_seconds = std.math.comptimeMod(seconds, s_per_day * Time.fs_per_s);
            const new_time = Time.fromDayFractionalSeconds(day_seconds);
            return .{ .date = new_date, .time = new_time };
        }

        pub fn toEpoch(self: Self) EpochSeconds {
            var res: EpochSeconds = 0;
            res += @as(EpochSeconds, self.date.toEpoch()) * s_per_day * Time.fs_per_s;
            res += self.time.toDayFractionalSeconds();
            return res;
        }
    };
}

pub const Date16Time = DateTime(i16, 0);
comptime {
    assert(@sizeOf(Date16Time) == 8);
}

/// Tests EpochSeconds -> DateTime and DateTime -> EpochSeconds
fn testEpoch(secs: i64, dt: Date16Time) !void {
    const actual_dt = Date16Time.fromEpoch(secs);
    try std.testing.expectEqualDeep(dt, actual_dt);
    try std.testing.expectEqual(secs, dt.toEpoch());
}

test Date16Time {
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
    // negative year
    try testEpoch(-97506041400, .{
        .date = .{ .year = -1120, .month = .feb, .day = 26 },
        .time = .{ .hour = 20, .minute = 30, .second = 0 },
    });
    // minimum date
    try testEpoch(-1096225401600, .{
        .date = .{ .year = std.math.minInt(i16), .month = .jan, .day = 1 },
    });
}

// pub const Rfc3339 = struct {
//     pub fn parseDate(str: []const u8) !Date {
//         if (str.len != 10) return error.Parsing;
//         const Rfc3339Year = IntFittingRange(0, 9999);
//         const year = try std.fmt.parseInt(Rfc3339Year, str[0..4], 10);
//         if (str[4] != '-') return error.Parsing;
//         const month = try std.fmt.parseInt(MonthInt, str[5..7], 10);
//         if (str[7] != '-') return error.Parsing;
//         const day = try std.fmt.parseInt(Date.Day, str[8..10], 10);
//         return .{ .year = year, .month = @enumFromInt(month), .day = day };
//     }
//
//     pub fn parseTime(str: []const u8) !Time {
//         if (str.len < 8) return error.Parsing;
//
//         const hour = try std.fmt.parseInt(Time.Hour, str[0..2], 10);
//         if (str[2] != ':') return error.Parsing;
//         const minute = try std.fmt.parseInt(Time.Minute, str[3..5], 10);
//         if (str[5] != ':') return error.Parsing;
//         const second = try std.fmt.parseInt(Time.Second, str[6..8], 10);
//         // ignore optional subseconds
//         // ignore timezone
//
//         return .{ .hour = hour, .minute = minute, .second = second };
//     }
//
//     pub fn parseDateTime(str: []const u8) !DateTime {
//         if (str.len < 10 + 1 + 8) return error.Parsing;
//         const date = try parseDate(str[0..10]);
//         if (str[10] != 'T') return error.Parsing;
//         const time = try parseTime(str[11..]);
//         return .{
//             .year = date.year,
//             .month = date.month,
//             .day = date.day,
//             .hour = time.hour,
//             .minute = time.minute,
//             .second = time.second,
//         };
//     }
// };
//
// fn comptimeParse(comptime time: []const u8) DateTime {
//     return Rfc3339.parseDateTime(time) catch unreachable;
// }

const std = @import("std.zig");
const date_mod = @import("./date.zig");
const time_mod = @import("./time.zig");
const s_per_day = time_mod.s_per_day;
const assert = std.debug.assert;
