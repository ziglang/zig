const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "namespace depends on compile var" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (some_namespace.a_bool) {
        try expect(some_namespace.a_bool);
    } else {
        try expect(!some_namespace.a_bool);
    }
}
const some_namespace = switch (builtin.os.tag) {
    .linux => @import("namespace_depends_on_compile_var/a.zig"),
    else => @import("namespace_depends_on_compile_var/b.zig"),
};
