const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "allocation and looping over 3-byte integer" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and builtin.os.tag == .macos) {
        return error.SkipZigTest; // TODO
    }

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .wasm32) {
        return error.SkipZigTest; // TODO
    }

    try expect(@sizeOf(u24) == 4);
    try expect(@sizeOf([1]u24) == 4);
    try expect(@alignOf(u24) == 4);
    try expect(@alignOf([1]u24) == 4);

    var x = try std.testing.allocator.alloc(u24, 2);
    defer std.testing.allocator.free(x);
    try expect(x.len == 2);
    x[0] = 0xFFFFFF;
    x[1] = 0xFFFFFF;

    const bytes = std.mem.sliceAsBytes(x);
    try expect(@TypeOf(bytes) == []align(4) u8);
    try expect(bytes.len == 8);

    for (bytes) |*b| {
        b.* = 0x00;
    }

    try expect(x[0] == 0x00);
    try expect(x[1] == 0x00);
}
