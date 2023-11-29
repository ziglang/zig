const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@ptrCast from const to nullable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const c: u8 = 4;
    var x: ?*const u8 = @ptrCast(&c);
    _ = &x;
    try expect(x.?.* == 4);
}

test "@ptrCast from var in empty struct to nullable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const container = struct {
        var c: u8 = 4;
    };
    var x: ?*const u8 = @ptrCast(&container.c);
    _ = &x;
    try expect(x.?.* == 4);
}
