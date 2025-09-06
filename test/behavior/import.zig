const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

const a_namespace = @import("import/a_namespace.zig");

test "call fn via namespace lookup" {
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(@as(i32, 1234) == a_namespace.foo());
}

test "importing the same thing gives the same import" {
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(@import("std") == @import("std"));
}

test "import empty file" {
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    _ = @import("import/empty.zig");
}
