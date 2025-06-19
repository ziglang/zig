const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "memmove and memset intrinsics" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try testMemmoveMemset();
    try comptime testMemmoveMemset();
}

fn testMemmoveMemset() !void {
    var foo: [20]u8 = undefined;

    @memset(foo[0..10], 'A');
    @memset(foo[10..20], 'B');

    try expect(foo[0] == 'A');
    try expect(foo[11] == 'B');
    try expect(foo[19] == 'B');

    @memmove(foo[10..20], foo[0..10]);

    try expect(foo[0] == 'A');
    try expect(foo[11] == 'A');
    try expect(foo[19] == 'A');
}

test "@memmove with both operands single-ptr-to-array, one is null-terminated" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try testMemmoveBothSinglePtrArrayOneIsNullTerminated();
    try comptime testMemmoveBothSinglePtrArrayOneIsNullTerminated();
}

fn testMemmoveBothSinglePtrArrayOneIsNullTerminated() !void {
    var buf: [100]u8 = undefined;
    const suffix = "hello";
    @memmove(buf[buf.len - suffix.len ..], suffix);
    try expect(buf[95] == 'h');
    try expect(buf[96] == 'e');
    try expect(buf[97] == 'l');
    try expect(buf[98] == 'l');
    try expect(buf[99] == 'o');

    const start = buf.len - suffix.len - 3;
    const end = start + suffix.len;
    @memmove(buf[start..end], buf[buf.len - suffix.len ..]);
    try expect(buf[92] == 'h');
    try expect(buf[93] == 'e');
    try expect(buf[94] == 'l');
    try expect(buf[95] == 'l');
    try expect(buf[96] == 'o');
    try expect(buf[97] == 'l');
    try expect(buf[98] == 'l');
    try expect(buf[99] == 'o');

    @memmove(buf[start + 2 .. end + 2], buf[start..end]);
    try expect(buf[92] == 'h');
    try expect(buf[93] == 'e');
    try expect(buf[94] == 'h');
    try expect(buf[95] == 'e');
    try expect(buf[96] == 'l');
    try expect(buf[97] == 'l');
    try expect(buf[98] == 'o');
    try expect(buf[99] == 'o');
}

test "@memmove dest many pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try testMemmoveDestManyPtr();
    try comptime testMemmoveDestManyPtr();
}

fn testMemmoveDestManyPtr() !void {
    var str = "hello".*;
    var buf: [8]u8 = undefined;
    var len: usize = 5;
    _ = &len;
    @memmove(@as([*]u8, @ptrCast(&buf)), @as([*]const u8, @ptrCast(&str))[0..len]);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'l');
    try expect(buf[4] == 'o');
    @memmove(buf[3..].ptr, buf[0..len]);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'h');
    try expect(buf[4] == 'e');
    try expect(buf[5] == 'l');
    try expect(buf[6] == 'l');
    try expect(buf[7] == 'o');
    @memmove(buf[2..7].ptr, buf[3 .. len + 3]);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'h');
    try expect(buf[3] == 'e');
    try expect(buf[4] == 'l');
    try expect(buf[5] == 'l');
    try expect(buf[6] == 'o');
    try expect(buf[7] == 'o');
}

test "@memmove slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;

    try testMemmoveSlice();
    try comptime testMemmoveSlice();
}

fn testMemmoveSlice() !void {
    var buf: [8]u8 = undefined;
    const dst1: []u8 = buf[0..5];
    const dst2: []u8 = buf[3..8];
    const dst3: []u8 = buf[2..7];
    const src: []const u8 = "hello";
    @memmove(dst1, src);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'l');
    try expect(buf[4] == 'o');
    @memmove(dst2, dst1);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'h');
    try expect(buf[4] == 'e');
    try expect(buf[5] == 'l');
    try expect(buf[6] == 'l');
    try expect(buf[7] == 'o');
    @memmove(dst3, dst2);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'h');
    try expect(buf[3] == 'e');
    try expect(buf[4] == 'l');
    try expect(buf[5] == 'l');
    try expect(buf[6] == 'o');
    try expect(buf[7] == 'o');
}

comptime {
    const S = struct {
        buffer: [8]u8 = undefined,
        fn set(self: *@This(), items: []const u8) void {
            @memmove(self.buffer[0..items.len], items);
            @memmove(self.buffer[3..], self.buffer[0..items.len]);
            @memmove(self.buffer[2 .. 2 + items.len], self.buffer[3..]);
        }
    };

    var s = S{};
    s.set("hello");
    if (!std.mem.eql(u8, s.buffer[0..8], "hehelloo")) @compileError("bad");
}
