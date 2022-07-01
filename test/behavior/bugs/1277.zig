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
    if (builtin.zig_backend == .stage1) return error.SkipZigTest; // stage1 has different function pointers
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    try std.testing.expect(s.f.?() == 1234);
}
