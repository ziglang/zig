const std = @import("std");
const builtin = @import("builtin");

const S = struct {
    f: ?*const fn () i32,
};

const s = S{ .f = &f };

fn f() i32 {
    return 1234;
}

test "don't emit an LLVM global for a const function when it's in an optional in a struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try std.testing.expect(s.f.?() == 1234);
}
