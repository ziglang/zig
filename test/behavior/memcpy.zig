const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const assert = std.debug.assert;

test "memcpy and memset intrinsics" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

test "@memcpy dest many pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testMemcpyDestManyPtr();
    try comptime testMemcpyDestManyPtr();
}

fn testMemcpyDestManyPtr() !void {
    var str = "hello".*;
    var buf: [5]u8 = undefined;
    var len: usize = 5;
    _ = &len;
    @memcpy(@as([*]u8, @ptrCast(&buf)), @as([*]const u8, @ptrCast(&str))[0..len]);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'l');
    try expect(buf[4] == 'o');
}

test "@memcpy C pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testMemcpyCPointer();
    try comptime testMemcpyCPointer();
}

fn testMemcpyCPointer() !void {
    const src = "hello";
    var buf: [5]u8 = undefined;
    @memcpy(@as([*c]u8, &buf), src);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'l');
    try expect(buf[4] == 'o');
}

test "@memcpy slice" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testMemcpySlice();
    try comptime testMemcpySlice();
}

fn testMemcpySlice() !void {
    var buf: [5]u8 = undefined;
    const dst: []u8 = &buf;
    const src: []const u8 = "hello";
    @memcpy(dst, src);
    try expect(buf[0] == 'h');
    try expect(buf[1] == 'e');
    try expect(buf[2] == 'l');
    try expect(buf[3] == 'l');
    try expect(buf[4] == 'o');
}

comptime {
    const S = struct {
        buffer: [8]u8 = undefined,
        fn set(self: *@This(), items: []const u8) void {
            @memcpy(self.buffer[0..items.len], items);
        }
    };

    var s = S{};
    s.set("hello");
    if (!std.mem.eql(u8, s.buffer[0..5], "hello")) @compileError("bad");
}

test "@memcpy comptime-only type" {
    const in: [4]type = .{ u8, u16, u32, u64 };
    comptime var out: [4]type = undefined;
    @memcpy(&out, &in);

    comptime assert(out[0] == u8);
    comptime assert(out[1] == u16);
    comptime assert(out[2] == u32);
    comptime assert(out[3] == u64);
}

test "@memcpy zero-bit type with aliasing" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            var buf: [3]void = @splat({});
            const slice: []void = &buf;
            // These two pointers are the same, but it's still not considered aliasing because
            // the input and output slices both correspond to zero bits of memory.
            @memcpy(slice, slice);
            comptime assert(buf[0] == {});
            comptime assert(buf[1] == {});
            comptime assert(buf[2] == {});
        }
    };
    S.doTheTest();
    comptime S.doTheTest();
}

test "@memcpy with sentinel" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            const field = @typeInfo(struct { a: u32 }).@"struct".fields[0];
            var buffer: [field.name.len]u8 = undefined;
            @memcpy(&buffer, field.name);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}

test "@memcpy no sentinel source into sentinel destination" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            const src: []const u8 = &.{ 1, 2, 3 };
            comptime var dest_buf: [3:0]u8 = @splat(0);
            const dest: [:0]u8 = &dest_buf;
            @memcpy(dest, src);
        }
    };

    S.doTheTest();
    comptime S.doTheTest();
}
