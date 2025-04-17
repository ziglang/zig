//! CodeGen tests for the x86_64 backend.

test {
    const builtin = @import("builtin");
    if (builtin.zig_backend != .stage2_x86_64) return error.SkipZigTest;
    // MachO linker does not support executables this big.
    if (builtin.object_format == .macho) return error.SkipZigTest;
    // COFF linker does not support the new backend.
    if (builtin.object_format == .coff) return error.SkipZigTest;
    _ = @import("x86_64/binary.zig");
    _ = @import("x86_64/cast.zig");
    _ = @import("x86_64/mem.zig");
    _ = @import("x86_64/unary.zig");
}
