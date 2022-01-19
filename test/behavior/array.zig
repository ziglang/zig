const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const mem = std.mem;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "array to slice" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const a: u32 align(4) = 3;
    const b: u32 align(8) = 4;
    const a_slice: []align(1) const u32 = @as(*const [1]u32, &a)[0..];
    const b_slice: []align(1) const u32 = @as(*const [1]u32, &b)[0..];
    try expect(a_slice[0] + b_slice[0] == 7);

    const d: []const u32 = &[2]u32{ 1, 2 };
    const e: []const u32 = &[3]u32{ 3, 4, 5 };
    try expect(d[0] + e[0] + d[1] + e[1] == 10);
}

test "arrays" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array: [5]u32 = undefined;

    var i: u32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator = @as(u32, 0);
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    try expect(accumulator == 15);
    try expect(getArrayLen(&array) == 5);
}
fn getArrayLen(a: []const u32) usize {
    return a.len;
}

test "array init with mult" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const a = 'a';
    var i: [8]u8 = [2]u8{ a, 'b' } ** 4;
    try expect(std.mem.eql(u8, &i, "abababab"));

    var j: [4]u8 = [1]u8{'a'} ** 4;
    try expect(std.mem.eql(u8, &j, "aaaa"));
}

test "array literal with explicit type" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const hex_mult: [4]u16 = .{ 4096, 256, 16, 1 };

    try expect(hex_mult.len == 4);
    try expect(hex_mult[1] == 256);
}

test "array literal with inferred length" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const hex_mult = [_]u16{ 4096, 256, 16, 1 };

    try expect(hex_mult.len == 4);
    try expect(hex_mult[1] == 256);
}

test "array dot len const expr" {
    try expect(comptime x: {
        break :x some_array.len == 4;
    });
}

const ArrayDotLenConstExpr = struct {
    y: [some_array.len]u8,
};
const some_array = [_]u8{ 0, 1, 2, 3 };

test "array literal with specified size" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array = [2]u8{ 1, 2 };
    try expect(array[0] == 1);
    try expect(array[1] == 2);
}

test "array len field" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var arr = [4]u8{ 0, 0, 0, 0 };
    var ptr = &arr;
    try expect(arr.len == 4);
    comptime try expect(arr.len == 4);
    try expect(ptr.len == 4);
    comptime try expect(ptr.len == 4);
}

test "array with sentinels" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(is_ct: bool) !void {
            if (is_ct or builtin.zig_backend != .stage1) {
                var zero_sized: [0:0xde]u8 = [_:0xde]u8{};
                // Stage1 test coverage disabled at runtime because of
                // https://github.com/ziglang/zig/issues/4372
                try expect(zero_sized[0] == 0xde);
                var reinterpreted = @ptrCast(*[1]u8, &zero_sized);
                try expect(reinterpreted[0] == 0xde);
            }
            var arr: [3:0x55]u8 = undefined;
            // Make sure the sentinel pointer is pointing after the last element.
            if (!is_ct) {
                const sentinel_ptr = @ptrToInt(&arr[3]);
                const last_elem_ptr = @ptrToInt(&arr[2]);
                try expect((sentinel_ptr - last_elem_ptr) == 1);
            }
            // Make sure the sentinel is writeable.
            arr[3] = 0x55;
        }
    };

    try S.doTheTest(false);
    comptime try S.doTheTest(true);
}

test "void arrays" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var array: [4]void = undefined;
    array[0] = void{};
    array[1] = array[2];
    try expect(@sizeOf(@TypeOf(array)) == 0);
    try expect(array.len == 4);
}

test "nested arrays" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_wasm) {
        // TODO this is a recent stage2 test case regression due to an enhancement;
        // now arrays are properly detected as comptime. This exercised a new code
        // path in the wasm backend that is not yet implemented.
        return error.SkipZigTest;
    }

    const array_of_strings = [_][]const u8{ "hello", "this", "is", "my", "thing" };
    for (array_of_strings) |s, i| {
        if (i == 0) try expect(mem.eql(u8, s, "hello"));
        if (i == 1) try expect(mem.eql(u8, s, "this"));
        if (i == 2) try expect(mem.eql(u8, s, "is"));
        if (i == 3) try expect(mem.eql(u8, s, "my"));
        if (i == 4) try expect(mem.eql(u8, s, "thing"));
    }
}

test "implicit comptime in array type size" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    var arr: [plusOne(10)]bool = undefined;
    try expect(arr.len == 11);
}

fn plusOne(x: u32) u32 {
    return x + 1;
}

test "single-item pointer to array indexing and slicing" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    try testSingleItemPtrArrayIndexSlice();
    comptime try testSingleItemPtrArrayIndexSlice();
}

fn testSingleItemPtrArrayIndexSlice() !void {
    {
        var array: [4]u8 = "aaaa".*;
        doSomeMangling(&array);
        try expect(mem.eql(u8, "azya", &array));
    }
    {
        var array = "aaaa".*;
        doSomeMangling(&array);
        try expect(mem.eql(u8, "azya", &array));
    }
}

fn doSomeMangling(array: *[4]u8) void {
    array[1] = 'z';
    array[2..3][0] = 'y';
}

test "implicit cast zero sized array ptr to slice" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    {
        var b = "".*;
        const c: []const u8 = &b;
        try expect(c.len == 0);
    }
    {
        var b: [0]u8 = "".*;
        const c: []const u8 = &b;
        try expect(c.len == 0);
    }
}

test "anonymous list literal syntax" {
    if (builtin.zig_backend == .stage2_x86_64 or builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var array: [4]u8 = .{ 1, 2, 3, 4 };
            try expect(array[0] == 1);
            try expect(array[1] == 2);
            try expect(array[2] == 3);
            try expect(array[3] == 4);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
