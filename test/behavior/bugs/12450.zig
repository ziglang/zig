const expect = @import("std").testing.expect;
const builtin = @import("builtin");

const Foo = packed struct {
    a: i32,
    b: u8,
};

var buffer: [256]u8 = undefined;

test {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var f1: *align(16) Foo = @alignCast(@as(*align(1) Foo, @ptrCast(&buffer[0])));
    try expect(@typeInfo(@TypeOf(f1)).Pointer.alignment == 16);
    try expect(@intFromPtr(f1) == @intFromPtr(&f1.a));
    try expect(@typeInfo(@TypeOf(&f1.a)).Pointer.alignment == 16);
}
