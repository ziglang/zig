const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "memcpy and memset intrinsics" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testMemcpyMemset();
    try comptime testMemcpyMemset();
}

fn testMemcpyMemset() !void {
    var foo: [20]u8 = undefined;
    var bar: [20]u8 = undefined;

    @memset(&foo, 'A');
    @memcpy(&bar, &foo);

    try expect(bar[0] == 'A');
    try expect(bar[11] == 'A');
    try expect(bar[19] == 'A');
}

test "@memcpy with both operands single-ptr-to-array, one is null-terminated" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;

    try testMemcpyBothSinglePtrArrayOneIsNullTerminated();
    try comptime testMemcpyBothSinglePtrArrayOneIsNullTerminated();
}

fn testMemcpyBothSinglePtrArrayOneIsNullTerminated() !void {
    var buf: [100]u8 = undefined;
    const suffix = "hello";
    @memcpy(buf[buf.len - suffix.len ..], suffix);
    try expect(buf[95] == 'h');
    try expect(buf[96] == 'e');
    try expect(buf[97] == 'l');
    try expect(buf[98] == 'l');
    try expect(buf[99] == 'o');
}
