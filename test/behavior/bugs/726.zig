const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "@ptrCast from const to nullable" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const c: u8 = 4;
    var x: ?*const u8 = @ptrCast(?*const u8, &c);
    try expect(x.?.* == 4);
}

test "@ptrCast from var in empty struct to nullable" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    const container = struct {
        var c: u8 = 4;
    };
    var x: ?*const u8 = @ptrCast(?*const u8, &container.c);
    try expect(x.?.* == 4);
}
