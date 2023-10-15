const std = @import("std");
const builtin = @import("builtin");

pub fn DeleagateWithContext(comptime Function: type) type {
    const ArgArgs = std.meta.ArgsTuple(Function);
    return struct {
        t: ArgArgs,
    };
}

pub const OnConfirm = DeleagateWithContext(fn (bool) void);
pub const CustomDraw = DeleagateWithContext(fn (?OnConfirm) void);

test "simple test" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var c: CustomDraw = undefined;
    _ = c;
}
