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

test "a type constructed in a global expression" {
    var l: List = undefined;
    l.array[0] = 10;
    l.array[1] = 11;
    l.array[2] = 12;
    const ptr = @ptrCast([*]u8, &l.array);
    try expect(ptr[0] == 10);
    try expect(ptr[1] == 11);
    try expect(ptr[2] == 12);
}

const List = blk: {
    const T = [10]u8;
    break :blk struct {
        array: T,
    };
};

test "comptime function with the same args is memoized" {
    comptime {
        try expect(MakeType(i32) == MakeType(i32));
        try expect(MakeType(i32) != MakeType(f64));
    }
}

fn MakeType(comptime T: type) type {
    return struct {
        field: T,
    };
}

test "try to trick eval with runtime if" {
    try expect(testTryToTrickEvalWithRuntimeIf(true) == 10);
}

fn testTryToTrickEvalWithRuntimeIf(b: bool) usize {
    comptime var i: usize = 0;
    inline while (i < 10) : (i += 1) {
        const result = if (b) false else true;
        _ = result;
    }
    comptime {
        return i;
    }
}

test "@setEvalBranchQuota" {
    comptime {
        // 1001 for the loop and then 1 more for the expect fn call
        @setEvalBranchQuota(1002);
        var i = 0;
        var sum = 0;
        while (i < 1001) : (i += 1) {
            sum += i;
        }
        try expect(sum == 500500);
    }
}

test "constant struct with negation" {
    try expect(vertices[0].x == @as(f32, -0.6));
}
const Vertex = struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
};
const vertices = [_]Vertex{
    Vertex{
        .x = -0.6,
        .y = -0.4,
        .r = 1.0,
        .g = 0.0,
        .b = 0.0,
    },
    Vertex{
        .x = 0.6,
        .y = -0.4,
        .r = 0.0,
        .g = 1.0,
        .b = 0.0,
    },
    Vertex{
        .x = 0.0,
        .y = 0.6,
        .r = 0.0,
        .g = 0.0,
        .b = 1.0,
    },
};

test "statically initialized list" {
    try expect(static_point_list[0].x == 1);
    try expect(static_point_list[0].y == 2);
    try expect(static_point_list[1].x == 3);
    try expect(static_point_list[1].y == 4);
}
const Point = struct {
    x: i32,
    y: i32,
};
const static_point_list = [_]Point{
    makePoint(1, 2),
    makePoint(3, 4),
};
fn makePoint(x: i32, y: i32) Point {
    return Point{
        .x = x,
        .y = y,
    };
}

test "statically initialized array literal" {
    const y: [4]u8 = st_init_arr_lit_x;
    try expect(y[3] == 4);
}
const st_init_arr_lit_x = [_]u8{ 1, 2, 3, 4 };

const CmdFn = struct {
    name: []const u8,
    func: fn (i32) i32,
};

const cmd_fns = [_]CmdFn{
    CmdFn{
        .name = "one",
        .func = one,
    },
    CmdFn{
        .name = "two",
        .func = two,
    },
    CmdFn{
        .name = "three",
        .func = three,
    },
};
fn one(value: i32) i32 {
    return value + 1;
}
fn two(value: i32) i32 {
    return value + 2;
}
fn three(value: i32) i32 {
    return value + 3;
}

fn performFn(comptime prefix_char: u8, start_value: i32) i32 {
    var result: i32 = start_value;
    comptime var i = 0;
    inline while (i < cmd_fns.len) : (i += 1) {
        if (cmd_fns[i].name[0] == prefix_char) {
            result = cmd_fns[i].func(result);
        }
    }
    return result;
}

test "comptime iterate over fn ptr list" {
    try expect(performFn('t', 1) == 6);
    try expect(performFn('o', 0) == 1);
    try expect(performFn('w', 99) == 99);
}

test "create global array with for loop" {
    try expect(global_array[5] == 5 * 5);
    try expect(global_array[9] == 9 * 9);
}

const global_array = x: {
    var result: [10]usize = undefined;
    for (result) |*item, index| {
        item.* = index * index;
    }
    break :x result;
};

fn generateTable(comptime T: type) [1010]T {
    var res: [1010]T = undefined;
    var i: usize = 0;
    while (i < 1010) : (i += 1) {
        res[i] = @intCast(T, i);
    }
    return res;
}

fn doesAlotT(comptime T: type, value: usize) T {
    @setEvalBranchQuota(5000);
    const table = comptime blk: {
        break :blk generateTable(T);
    };
    return table[value];
}

test "@setEvalBranchQuota at same scope as generic function call" {
    try expect(doesAlotT(u32, 2) == 2);
}

pub const Info = struct {
    version: u8,
};

pub const diamond_info = Info{ .version = 0 };

test "comptime modification of const struct field" {
    comptime {
        var res = diamond_info;
        res.version = 1;
        try expect(diamond_info.version == 0);
        try expect(res.version == 1);
    }
}

test "refer to the type of a generic function" {
    const Func = fn (type) void;
    const f: Func = doNothingWithType;
    f(i32);
}

fn doNothingWithType(comptime T: type) void {
    _ = T;
}

test "zero extend from u0 to u1" {
    var zero_u0: u0 = 0;
    var zero_u1: u1 = zero_u0;
    try expect(zero_u1 == 0);
}

test "return 0 from function that has u0 return type" {
    const S = struct {
        fn foo_zero() u0 {
            return 0;
        }
    };
    comptime {
        if (S.foo_zero() != 0) {
            @compileError("test failed");
        }
    }
}

test "statically initialized struct" {
    st_init_str_foo.x += 1;
    try expect(st_init_str_foo.x == 14);
}
const StInitStrFoo = struct {
    x: i32,
    y: bool,
};
var st_init_str_foo = StInitStrFoo{
    .x = 13,
    .y = true,
};

test "inline for with same type but different values" {
    var res: usize = 0;
    inline for ([_]type{ [2]u8, [1]u8, [2]u8 }) |T| {
        var a: T = undefined;
        res += a.len;
    }
    try expect(res == 5);
}

test "f32 at compile time is lossy" {
    try expect(@as(f32, 1 << 24) + 1 == 1 << 24);
}

test "f64 at compile time is lossy" {
    try expect(@as(f64, 1 << 53) + 1 == 1 << 53);
}

test {
    comptime try expect(@as(f128, 1 << 113) == 10384593717069655257060992658440192);
}

fn copyWithPartialInline(s: []u32, b: []u8) void {
    comptime var i: usize = 0;
    inline while (i < 4) : (i += 1) {
        s[i] = 0;
        s[i] |= @as(u32, b[i * 4 + 0]) << 24;
        s[i] |= @as(u32, b[i * 4 + 1]) << 16;
        s[i] |= @as(u32, b[i * 4 + 2]) << 8;
        s[i] |= @as(u32, b[i * 4 + 3]) << 0;
    }
}

test "binary math operator in partially inlined function" {
    var s: [4]u32 = undefined;
    var b: [16]u8 = undefined;

    for (b) |*r, i|
        r.* = @intCast(u8, i + 1);

    copyWithPartialInline(s[0..], b[0..]);
    try expect(s[0] == 0x1020304);
    try expect(s[1] == 0x5060708);
    try expect(s[2] == 0x90a0b0c);
    try expect(s[3] == 0xd0e0f10);
}

test "comptime shl" {
    var a: u128 = 3;
    var b: u7 = 63;
    var c: u128 = 3 << 63;
    try expect((a << b) == c);
}

test "comptime bitwise operators" {
    comptime {
        try expect(3 & 1 == 1);
        try expect(3 & -1 == 3);
        try expect(-3 & -1 == -3);
        try expect(3 | -1 == -1);
        try expect(-3 | -1 == -1);
        try expect(3 ^ -1 == -4);
        try expect(-3 ^ -1 == 2);
        try expect(~@as(i8, -1) == 0);
        try expect(~@as(i128, -1) == 0);
        try expect(18446744073709551615 & 18446744073709551611 == 18446744073709551611);
        try expect(-18446744073709551615 & -18446744073709551611 == -18446744073709551615);
        try expect(~@as(u128, 0) == 0xffffffffffffffffffffffffffffffff);
    }
}
