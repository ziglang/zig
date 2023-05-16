const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@ptrCast from const to nullable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const c: u8 = 4;
    var x: ?*const u8 = @ptrCast(?*const u8, &c);
    try expect(x.?.* == 4);
}

test "@ptrCast from var in empty struct to nullable" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const container = struct {
        var c: u8 = 4;
    };
    var x: ?*const u8 = @ptrCast(?*const u8, &container.c);
    try expect(x.?.* == 4);
}
