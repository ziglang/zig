const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "anyopaque extern symbol" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;

    const a = @extern(*anyopaque, .{ .name = "a_mystery_symbol" });
    const b: *i32 = @alignCast(@ptrCast(a));
    try expect(b.* == 1234);
}

export var a_mystery_symbol: i32 = 1234;

test "function extern symbol" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf) return error.SkipZigTest;

    const a = @extern(*const fn () callconv(.C) i32, .{ .name = "a_mystery_function" });
    try expect(a() == 4567);
}

export fn a_mystery_function() i32 {
    return 4567;
}
