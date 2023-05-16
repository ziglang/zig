const A = extern struct {
    field: c_int,
};

extern fn issue529(?*A) void;

comptime {
    _ = @import("529_other_file_2.zig");
}

const builtin = @import("builtin");

test "issue 529 fixed" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    @import("529_other_file.zig").issue529(null);
    issue529(null);
}
