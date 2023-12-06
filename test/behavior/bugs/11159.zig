const std = @import("std");
const builtin = @import("builtin");

test {
    const T = @TypeOf(.{ @as(i32, 0), @as(u32, 0) });
    var a: T = .{ 0, 0 };
    _ = &a;
}

test {
    const S = struct {
        comptime x: i32 = 0,
        comptime y: u32 = 0,
    };
    var a: S = .{};
    _ = &a;
    var b = S{};
    _ = &b;
}
