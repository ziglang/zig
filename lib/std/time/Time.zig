hour: Hour = 0,
minute: Minute = 0,
second: Second = 0,
millisec: MilliSecond = 0,

const Time = @This();
const std = @import("../std.zig");
const s_per_hour = std.time.s_per_hour;
const s_per_min = std.time.s_per_min;

pub const Hour = u5;
pub const Minute = u6;
pub const Second = u6;
pub const MilliSecond = u10;

pub const midnight = Time{};
pub const noon = Time{ .hour = 12 };

pub fn parse(str: []const u8) !Time {
    // <hour>:<minute>[:<second>[.<millisec>]]
    var it = std.mem.split(u8, str, ":");

    var time = Time{
        .hour = try std.fmt.parseInt(Hour, it.next().?, 10),
        .minute = try std.fmt.parseInt(Minute, it.next() orelse return error.ParseError, 10),
    };

    if (it.next()) |sec_part| {
        var sit = std.mem.split(u8, sec_part, ".");
        time.second = try std.fmt.parseInt(Second, sit.next().?, 10);
        time.millisec = if (sit.next()) |milli| try std.fmt.parseInt(MilliSecond, milli, 10) else 0;
    }
    return time;
}

/// Initialize using the number of seconds elapsed since the start of the day.
pub fn fromSecondsSinceMidnight(secs: u17) Time {
    return .{
        .hour = @intCast(u5, secs / s_per_hour),
        .minute = @intCast(u6, (secs / 60) % 60),
        .second = @intCast(u6, secs % 60),
    };
}

/// Get the number of seconds elapsed since the start of the day.
pub fn secondsSinceMidnight(self: Time) u17 {
    return @as(u17, self.hour) * s_per_hour + @as(u17, self.minute) * s_per_min + self.second;
}

pub fn eql(a: Time, b: Time) bool {
    return a.hour == b.hour and a.minute == b.minute and a.second == b.second and a.millisec == b.millisec;
}

/// Formatter for time.  See man strftime(3) for description of each format specifier.
pub fn format(self: Time, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    inline for (fmt) |c| {
        switch (c) {
            'H' => try std.fmt.formatInt(self.hour, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'I' => try std.fmt.formatInt(hour12(self.hour), 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'k' => try std.fmt.formatInt(self.hour, 10, .lower, .{ .width = 2 }, writer),
            'l' => try std.fmt.formatInt(hour12(self.hour), 10, .lower, .{ .width = 2 }, writer),
            'M' => try std.fmt.formatInt(self.minute, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'p' => try writer.writeAll(if (self.hour < 12) "AM" else "PM"),
            'P' => try writer.writeAll(if (self.hour < 12) "am" else "pm"),
            'r' => try writer.print("{d:0>2}:{d:0>2}:{d:0>2} {s}", .{
                hour12(self.hour),
                self.minute,
                self.second,
                if (self.hour < 12) "AM" else "PM",
            }),
            'R' => try writer.print("{d:0>2}:{d:0>2}", .{ self.hour, self.minute }),
            'S' => try std.fmt.formatInt(self.second, 10, .lower, .{ .width = 2, .fill = '0' }, writer),
            'T', 'X' => try writer.print("{d:0>2}:{d:0>2}:{d:0>2}", .{ self.hour, self.minute, self.second }),
            '-', '/', '.', ',', ' ' => try writer.writeByte(c),
            ';' => try writer.writeByte(':'),
            else => @compileError("Unsupported time format"),
        }
    }
}

fn hour12(hour: Hour) Hour {
    const h = hour % 12;
    return if (h == 0) 12 else h;
}
