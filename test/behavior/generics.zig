const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;

test "one param, explicit comptime" {
    var x: usize = 0;
    x += checkSize(i32);
    x += checkSize(bool);
    x += checkSize(bool);
    try expect(x == 6);
}

fn checkSize(comptime T: type) usize {
    return @sizeOf(T);
}

test "simple generic fn" {
    try expect(max(i32, 3, -1) == 3);
    try expect(max(u8, 1, 100) == 100);
    if (!builtin.zig_is_stage2) {
        // TODO: stage2 is incorrectly emitting the following:
        // error: cast of value 1.23e-01 to type 'f32' loses information
        try expect(max(f32, 0.123, 0.456) == 0.456);
    }
    try expect(add(2, 3) == 5);
}

fn max(comptime T: type, a: T, b: T) T {
    if (!builtin.zig_is_stage2) {
        // TODO: stage2 is incorrectly emitting AIR that allocates a result
        // value, stores to it, but then returns void instead of the result.
        return if (a > b) a else b;
    }
    if (a > b) {
        return a;
    } else {
        return b;
    }
}

fn add(comptime a: i32, b: i32) i32 {
    return (comptime a) + b;
}

const the_max = max(u32, 1234, 5678);
test "compile time generic eval" {
    try expect(the_max == 5678);
}

fn gimmeTheBigOne(a: u32, b: u32) u32 {
    return max(u32, a, b);
}

fn shouldCallSameInstance(a: u32, b: u32) u32 {
    return max(u32, a, b);
}

fn sameButWithFloats(a: f64, b: f64) f64 {
    return max(f64, a, b);
}

test "fn with comptime args" {
    try expect(gimmeTheBigOne(1234, 5678) == 5678);
    try expect(shouldCallSameInstance(34, 12) == 34);
    if (!builtin.zig_is_stage2) {
        // TODO: stage2 llvm backend needs to use fcmp instead of icmp
        // probably AIR should just have different instructions for floats.
        try expect(sameButWithFloats(0.43, 0.49) == 0.49);
    }
}
