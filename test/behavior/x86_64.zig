//! CodeGen tests for the x86_64 backend.

const builtin = @import("builtin");

test {
    if (builtin.zig_backend != .stage2_x86_64) return error.SkipZigTest;
    if (builtin.object_format == .coff) return error.SkipZigTest;
    _ = @import("x86_64/math.zig");
}
