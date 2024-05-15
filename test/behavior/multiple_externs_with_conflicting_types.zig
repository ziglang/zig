const A = extern struct {
    field: c_int,
};

extern fn issue529(?*A) void;

comptime {
    _ = @import("conflicting_externs/b.zig");
}

const builtin = @import("builtin");

test "call extern function defined with conflicting type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    @import("conflicting_externs/a.zig").issue529(null);
    issue529(null);
}
