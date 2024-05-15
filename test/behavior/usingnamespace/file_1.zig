const std = @import("std");
const expect = std.testing.expect;
const imports = @import("imports.zig");
const builtin = @import("builtin");

const A = 456;

test {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(imports.A == 123);
}
