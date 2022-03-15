const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    const T = @TypeOf(.{ @as(i32, 0), @as(u32, 0) });
    var a = T{ 0, 0 };
    _ = a;
}
