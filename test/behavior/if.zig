const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "if statements" {
    shouldBeEqual(1, 1);
    firstEqlThird(2, 1, 2);
}
fn shouldBeEqual(a: i32, b: i32) void {
    if (a != b) {
        unreachable;
    } else {
        return;
    }
}
fn firstEqlThird(a: i32, b: i32, c: i32) void {
    if (a == b) {
        unreachable;
    } else if (b == c) {
        unreachable;
    } else if (a == c) {
        return;
    } else {
        unreachable;
    }
}

test "else if expression" {
    try expect(elseIfExpressionF(1) == 1);
}
fn elseIfExpressionF(c: u8) u8 {
    if (c == 0) {
        return 0;
    } else if (c == 1) {
        return 1;
    } else {
        return @as(u8, 2);
    }
}

// #2297
var global_with_val: anyerror!u32 = 0;
var global_with_err: anyerror!u32 = error.SomeError;

test "unwrap mutable global var" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (global_with_val) |v| {
        try expect(v == 0);
    } else |_| {
        unreachable;
    }
    if (global_with_err) |_| {
        unreachable;
    } else |e| {
        try expect(e == error.SomeError);
    }
}

test "labeled break inside comptime if inside runtime if" {
    var answer: i32 = 0;
    var c = true;
    if (c) {
        answer = if (true) blk: {
            break :blk @as(i32, 42);
        };
    }
    try expect(answer == 42);
}

test "const result loc, runtime if cond, else unreachable" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Num = enum { One, Two };

    var t = true;
    const x = if (t) Num.Two else unreachable;
    try expect(x == .Two);
}

test "if copies its payload" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var tmp: ?i32 = 10;
            if (tmp) |value| {
                // Modify the original variable
                tmp = null;
                try expect(value == 10);
            } else unreachable;
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "if prongs cast to expected type instead of peer type resolution" {
    const S = struct {
        fn doTheTest(f: bool) !void {
            var x: i32 = 0;
            x = if (f) 1 else 2;
            try expect(x == 2);

            var b = true;
            const y: i32 = if (b) 1 else 2;
            try expect(y == 1);
        }
    };
    try S.doTheTest(false);
    comptime try S.doTheTest(false);
}

test "if peer expressions inferred optional type" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var self: []const u8 = "abcdef";
    var index: usize = 0;
    var left_index = (index << 1) + 1;
    var right_index = left_index + 1;
    var left = if (left_index < self.len) self[left_index] else null;
    var right = if (right_index < self.len) self[right_index] else null;
    try expect(left_index < self.len);
    try expect(right_index < self.len);
    try expect(left.? == 98);
    try expect(right.? == 99);
}

test "if-else expression with runtime condition result location is inferred optional" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const A = struct { b: u64, c: u64 };
    var d: bool = true;
    const e = if (d) A{ .b = 15, .c = 30 } else null;
    try expect(e != null);
}

test "result location with inferred type ends up being pointer to comptime_int" {
    var a: ?u32 = 1234;
    var b: u32 = 2000;
    var c = if (a) |d| blk: {
        if (d < b) break :blk @as(u32, 1);
        break :blk 0;
    } else @as(u32, 0);
    try expect(c == 1);
}
