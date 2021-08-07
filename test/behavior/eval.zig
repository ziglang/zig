const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "compile time recursion" {
    try expect(some_data.len == 21);
}
var some_data: [@intCast(usize, fibonacci(7))]u8 = undefined;
fn fibonacci(x: i32) i32 {
    if (x <= 1) return 1;
    return fibonacci(x - 1) + fibonacci(x - 2);
}

fn unwrapAndAddOne(blah: ?i32) i32 {
    return blah.? + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
test "static add one" {
    try expect(should_be_1235 == 1235);
}

test "inlined loop" {
    comptime var i = 0;
    comptime var sum = 0;
    inline while (i <= 5) : (i += 1)
        sum += i;
    try expect(sum == 15);
}

fn gimme1or2(comptime a: bool) i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    comptime var z: i32 = if (a) x else y;
    return z;
}
test "inline variable gets result of const if" {
    try expect(gimme1or2(true) == 1);
    try expect(gimme1or2(false) == 2);
}

test "static function evaluation" {
    try expect(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) i32 {
    return a + b;
}

test "const expr eval on single expr blocks" {
    try expect(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
    comptime try expect(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
}

fn constExprEvalOnSingleExprBlocksFn(x: i32, b: bool) i32 {
    const literal = 3;

    const result = if (b) b: {
        break :b literal;
    } else b: {
        break :b x;
    };

    return result;
}

test "constant expressions" {
    var array: [array_size]u8 = undefined;
    try expect(@sizeOf(@TypeOf(array)) == 20);
}
const array_size: u8 = 20;

fn max(comptime T: type, a: T, b: T) T {
    if (T == bool) {
        return a or b;
    } else if (a > b) {
        return a;
    } else {
        return b;
    }
}
fn letsTryToCompareBools(a: bool, b: bool) bool {
    return max(bool, a, b);
}
test "inlined block and runtime block phi" {
    try expect(letsTryToCompareBools(true, true));
    try expect(letsTryToCompareBools(true, false));
    try expect(letsTryToCompareBools(false, true));
    try expect(!letsTryToCompareBools(false, false));

    comptime {
        try expect(letsTryToCompareBools(true, true));
        try expect(letsTryToCompareBools(true, false));
        try expect(letsTryToCompareBools(false, true));
        try expect(!letsTryToCompareBools(false, false));
    }
}

test "eval @setRuntimeSafety at compile-time" {
    const result = comptime fnWithSetRuntimeSafety();
    try expect(result == 1234);
}

fn fnWithSetRuntimeSafety() i32 {
    @setRuntimeSafety(true);
    return 1234;
}

test "compile-time downcast when the bits fit" {
    comptime {
        const spartan_count: u16 = 255;
        const byte = @intCast(u8, spartan_count);
        try expect(byte == 255);
    }
}

test "pointer to type" {
    comptime {
        var T: type = i32;
        try expect(T == i32);
        var ptr = &T;
        try expect(@TypeOf(ptr) == *type);
        ptr.* = f32;
        try expect(T == f32);
        try expect(*T == *f32);
    }
}

test "no undeclared identifier error in unanalyzed branches" {
    if (false) {
        lol_this_doesnt_exist = nonsense;
    }
}
