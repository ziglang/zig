const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "ignore lval with underscore" {
    _ = false;
}

test "ignore lval with underscore (while loop)" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    while (optionalReturnError()) |_| {
        while (optionalReturnError()) |_| {
            break;
        } else |_| {}
        break;
    } else |_| {}
}

fn optionalReturnError() !?u32 {
    return error.optionalReturnError;
}
