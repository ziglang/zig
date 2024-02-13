const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "@memset on array pointers" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testMemsetArray();
    try comptime testMemsetArray();
}

fn testMemsetArray() !void {
    {
        // memset array to non-undefined, ABI size == 1
        var foo: [20]u8 = undefined;
        @memset(&foo, 'A');
        try expect(foo[0] == 'A');
        try expect(foo[11] == 'A');
        try expect(foo[19] == 'A');
    }
    {
        // memset array to non-undefined, ABI size > 1
        var foo: [20]u32 = undefined;
        @memset(&foo, 1234);
        try expect(foo[0] == 1234);
        try expect(foo[11] == 1234);
        try expect(foo[19] == 1234);
    }
}

test "@memset on slices" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testMemsetSlice();
    try comptime testMemsetSlice();
}

fn testMemsetSlice() !void {
    {
        // memset slice to non-undefined, ABI size == 1
        var array: [20]u8 = undefined;
        var len = array.len;
        _ = &len;
        const slice = array[0..len];
        @memset(slice, 'A');
        try expect(slice[0] == 'A');
        try expect(slice[11] == 'A');
        try expect(slice[19] == 'A');
    }
    {
        // memset slice to non-undefined, ABI size > 1
        var array: [20]u32 = undefined;
        var len = array.len;
        _ = &len;
        const slice = array[0..len];
        @memset(slice, 1234);
        try expect(slice[0] == 1234);
        try expect(slice[11] == 1234);
        try expect(slice[19] == 1234);
    }
}

test "memset with bool element" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var buf: [5]bool = undefined;
    @memset(&buf, true);
    try expect(buf[2]);
    try expect(buf[4]);
}

test "memset with 1-byte struct element" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct { x: bool };
    var buf: [5]S = undefined;
    @memset(&buf, .{ .x = true });
    try expect(buf[2].x);
    try expect(buf[4].x);
}

test "memset with 1-byte array element" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = [1]bool;
    var buf: [5]A = undefined;
    @memset(&buf, .{true});
    try expect(buf[2][0]);
    try expect(buf[4][0]);
}

test "memset with large array element, runtime known" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = [128]u64;
    var buf: [5]A = undefined;
    var runtime_known_element = [_]u64{0} ** 128;
    _ = &runtime_known_element;
    @memset(&buf, runtime_known_element);
    for (buf[0]) |elem| try expect(elem == 0);
    for (buf[1]) |elem| try expect(elem == 0);
    for (buf[2]) |elem| try expect(elem == 0);
    for (buf[3]) |elem| try expect(elem == 0);
    for (buf[4]) |elem| try expect(elem == 0);
}

test "memset with large array element, comptime known" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = [128]u64;
    var buf: [5]A = undefined;
    const comptime_known_element = [_]u64{0} ** 128;
    @memset(&buf, comptime_known_element);
    for (buf[0]) |elem| try expect(elem == 0);
    for (buf[1]) |elem| try expect(elem == 0);
    for (buf[2]) |elem| try expect(elem == 0);
    for (buf[3]) |elem| try expect(elem == 0);
    for (buf[4]) |elem| try expect(elem == 0);
}

test "@memset provides result type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct { x: u32 };

    var buf1: [5]S = undefined;
    @memset(&buf1, .{ .x = @intCast(12) });

    var buf2: [5]S = undefined;
    @memset(@as([]S, &buf2), .{ .x = @intCast(34) });

    for (buf1) |s| try expect(s.x == 12);
    for (buf2) |s| try expect(s.x == 34);
}

test "zero keys with @memset" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Keys = struct {
        up: bool,
        down: bool,
        left: bool,
        right: bool,
        var keys: @This() = undefined;
    };
    @memset(@as([*]u8, @ptrCast(&Keys.keys))[0..@sizeOf(@TypeOf(Keys.keys))], 0);
    try expect(!Keys.keys.up);
    try expect(!Keys.keys.down);
    try expect(!Keys.keys.left);
    try expect(!Keys.keys.right);
}
