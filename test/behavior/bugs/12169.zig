const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .zsf_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .zsf_arm) return error.SkipZigTest; // TODO

    if (comptime builtin.zig_backend == .zsf_llvm and builtin.cpu.arch.endian() == .Big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    const a = @Vector(2, bool){ true, true };
    const b = @Vector(1, bool){true};
    try std.testing.expect(@reduce(.And, a));
    try std.testing.expect(@reduce(.And, b));
}
