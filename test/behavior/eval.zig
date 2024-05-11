const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "compile time recursion" {
    try expect(some_data.len == 21);
}
var some_data: [@as(usize, @intCast(fibonacci(7)))]u8 = undefined;
fn fibonacci(x: i32) i32 {
    if (x <= 1) return 1;
    return fibonacci(x - 1) + fibonacci(x - 2);
}

fn unwrapAndAddOne(blah: ?i32) i32 {
    return blah.? + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
test "static add one" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    _ = &z;
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
    comptime assert(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var array: [array_size]u8 = undefined;
    _ = &array;
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
        const byte = @as(u8, @intCast(spartan_count));
        try expect(byte == 255);
    }
}

test "pointer to type" {
    comptime {
        var T: type = i32;
        try expect(T == i32);
        const ptr = &T;
        try expect(@TypeOf(ptr) == *type);
        ptr.* = f32;
        try expect(T == f32);
        try expect(*T == *f32);
    }
}

test "a type constructed in a global expression" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var l: List = undefined;
    l.array[0] = 10;
    l.array[1] = 11;
    l.array[2] = 12;
    const ptr = @as([*]u8, @ptrCast(&l.array));
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
    return comptime i;
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    for (&result, 0..) |*item, index| {
        item.* = index * index;
    }
    break :x result;
};

fn generateTable(comptime T: type) [1010]T {
    var res: [1010]T = undefined;
    var i: usize = 0;
    while (i < 1010) : (i += 1) {
        res[i] = @as(T, @intCast(i));
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    _ = .{ &zero_u0, &zero_u1 };
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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

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
        _ = &a;
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
    comptime assert(@as(f128, 1 << 113) == 10384593717069655257060992658440192);
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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var s: [4]u32 = undefined;
    var b: [16]u8 = undefined;

    for (&b, 0..) |*r, i|
        r.* = @as(u8, @intCast(i + 1));

    copyWithPartialInline(s[0..], b[0..]);
    try expect(s[0] == 0x1020304);
    try expect(s[1] == 0x5060708);
    try expect(s[2] == 0x90a0b0c);
    try expect(s[3] == 0xd0e0f10);
}

test "comptime shl" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const a: u128 = 3;
    const b: u7 = 63;
    const c: u128 = 3 << 63;
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

test "comptime shlWithOverflow" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const ct_shifted = @shlWithOverflow(~@as(u64, 0), 16)[0];
    var a = ~@as(u64, 0);
    _ = &a;
    const rt_shifted = @shlWithOverflow(a, 16)[0];

    try expect(ct_shifted == rt_shifted);
}

test "const ptr to variable data changes at runtime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(foo_ref.name[0] == 'a');
    foo_ref.name = "b";
    try expect(foo_ref.name[0] == 'b');
}

const Foo = struct {
    name: []const u8,
};

var foo_contents = Foo{ .name = "a" };
const foo_ref = &foo_contents;

test "runtime 128 bit integer division" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c and comptime builtin.cpu.arch.isArmOrThumb()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64 and builtin.target.ofmt != .elf and builtin.target.ofmt != .macho) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a: u128 = 152313999999999991610955792383;
    var b: u128 = 10000000000000000000;
    _ = .{ &a, &b };
    const c = a / b;
    try expect(c == 15231399999);
}

test "@tagName of @typeInfo" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const str = @tagName(@typeInfo(u8));
    try expect(std.mem.eql(u8, str, "Int"));
}

test "static eval list init" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try expect(static_vec3.data[2] == 1.0);
    try expect(vec3(0.0, 0.0, 3.0).data[2] == 3.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub const Vec3 = struct {
    data: [3]f32,
};
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{
        .data = [_]f32{ x, y, z },
    };
}

test "inlined loop has array literal with elided runtime scope on first iteration but not second iteration" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var runtime = [1]i32{3};
    _ = &runtime;
    comptime var i: usize = 0;
    inline while (i < 2) : (i += 1) {
        const result = if (i == 0) [1]i32{2} else runtime;
        _ = result;
    }
    comptime {
        try expect(i == 2);
    }
}

test "ptr to local array argument at comptime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime {
        var bytes: [10]u8 = undefined;
        modifySomeBytes(bytes[0..]);
        try expect(bytes[0] == 'a');
        try expect(bytes[9] == 'b');
    }
}

fn modifySomeBytes(bytes: []u8) void {
    bytes[0] = 'a';
    bytes[9] = 'b';
}

test "comparisons 0 <= uint and 0 > uint should be comptime" {
    testCompTimeUIntComparisons(1234);
}
fn testCompTimeUIntComparisons(x: u32) void {
    if (!(0 <= x)) {
        @compileError("this condition should be comptime-known");
    }
    if (0 > x) {
        @compileError("this condition should be comptime-known");
    }
    if (!(x >= 0)) {
        @compileError("this condition should be comptime-known");
    }
    if (x < 0) {
        @compileError("this condition should be comptime-known");
    }
}

const hi1 = "hi";
const hi2 = hi1;
test "const global shares pointer with other same one" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try assertEqualPtrs(&hi1[0], &hi2[0]);
    comptime assert(&hi1[0] == &hi2[0]);
}
fn assertEqualPtrs(ptr1: *const u8, ptr2: *const u8) !void {
    try expect(ptr1 == ptr2);
}

// This one is still up for debate in the language specification.
// Application code should not rely on this behavior until it is solidified.
// Historically, stage1 had special case code to make this pass for string literals
// but it did not work if the values are constructed with comptime code, or if
// arrays of non-u8 elements are used instead.
// The official language specification might not make this guarantee. However, if
// it does make this guarantee, it will make it consistently for all types, not
// only string literals. This is why Zig currently has a string table for
// string literals, to match legacy stage1 behavior and pass this test, however
// the end-game once the lang spec issue is settled would be to use a global
// InternPool for comptime memoized objects, making this behavior consistent
// across all types.
test "string literal used as comptime slice is memoized" {
    const a = "link";
    const b = "link";
    comptime assert(TypeWithCompTimeSlice(a).Node == TypeWithCompTimeSlice(b).Node);
    comptime assert(TypeWithCompTimeSlice("link").Node == TypeWithCompTimeSlice("link").Node);
}

pub fn TypeWithCompTimeSlice(comptime field_name: []const u8) type {
    _ = field_name;
    return struct {
        pub const Node = struct {};
    };
}

test "comptime function with mutable pointer is not memoized" {
    comptime {
        var x: i32 = 1;
        const ptr = &x;
        increment(ptr);
        increment(ptr);
        try expect(x == 3);
    }
}

fn increment(value: *i32) void {
    value.* += 1;
}

test "const ptr to comptime mutable data is not memoized" {
    comptime {
        var foo = SingleFieldStruct{ .x = 1 };
        try expect(foo.read_x() == 1);
        foo.x = 2;
        try expect(foo.read_x() == 2);
    }
}

const SingleFieldStruct = struct {
    x: i32,

    fn read_x(self: *const SingleFieldStruct) i32 {
        return self.x;
    }
};

test "function which returns struct with type field causes implicit comptime" {
    const ty = wrap(i32).T;
    try expect(ty == i32);
}

const Wrapper = struct {
    T: type,
};

fn wrap(comptime T: type) Wrapper {
    return Wrapper{ .T = T };
}

test "call method with comptime pass-by-non-copying-value self parameter" {
    const S = struct {
        a: u8,

        fn b(comptime s: @This()) u8 {
            return s.a;
        }
    };

    const s = S{ .a = 2 };
    const b = s.b();
    try expect(b == 2);
}

test "setting backward branch quota just before a generic fn call" {
    @setEvalBranchQuota(1001);
    loopNTimes(1001);
}

fn loopNTimes(comptime n: usize) void {
    comptime var i = 0;
    inline while (i < n) : (i += 1) {}
}

test "variable inside inline loop that has different types on different iterations" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    try testVarInsideInlineLoop(.{ true, @as(u32, 42) });
}

fn testVarInsideInlineLoop(args: anytype) !void {
    comptime var i = 0;
    inline while (i < args.len) : (i += 1) {
        const x = args[i];
        if (i == 0) try expect(x);
        if (i == 1) try expect(x == 42);
    }
}

test "*align(1) u16 is the same as *align(1:0:2) u16" {
    comptime {
        try expect(*align(1:0:2) u16 == *align(1) u16);
        try expect(*align(2:0:2) u16 == *u16);
    }
}

test "array concatenation of function calls" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = oneItem(3) ++ oneItem(4);
    try expect(std.mem.eql(i32, &a, &[_]i32{ 3, 4 }));
}

test "array multiplication of function calls" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = oneItem(3) ** scalar(2);
    try expect(std.mem.eql(i32, &a, &[_]i32{ 3, 3 }));
}

fn oneItem(x: i32) [1]i32 {
    return [_]i32{x};
}

fn scalar(x: u32) u32 {
    return x;
}

test "array concatenation peer resolves element types - value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2]u3{ 1, 7 };
    var b = [3]u8{ 200, 225, 255 };
    _ = .{ &a, &b };
    const c = a ++ b;
    comptime assert(@TypeOf(c) == [5]u8);
    try expect(c[0] == 1);
    try expect(c[1] == 7);
    try expect(c[2] == 200);
    try expect(c[3] == 225);
    try expect(c[4] == 255);
}

test "array concatenation peer resolves element types - pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2]u3{ 1, 7 };
    var b = [3]u8{ 200, 225, 255 };
    const c = &a ++ &b;
    comptime assert(@TypeOf(c) == *[5]u8);
    try expect(c[0] == 1);
    try expect(c[1] == 7);
    try expect(c[2] == 200);
    try expect(c[3] == 225);
    try expect(c[4] == 255);
}

test "array concatenation sets the sentinel - value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2]u3{ 1, 7 };
    var b = [3:69]u8{ 200, 225, 255 };
    _ = .{ &a, &b };
    const c = a ++ b;
    comptime assert(@TypeOf(c) == [5:69]u8);
    try expect(c[0] == 1);
    try expect(c[1] == 7);
    try expect(c[2] == 200);
    try expect(c[3] == 225);
    try expect(c[4] == 255);
    const ptr: [*]const u8 = &c;
    try expect(ptr[5] == 69);
}

test "array concatenation sets the sentinel - pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2]u3{ 1, 7 };
    var b = [3:69]u8{ 200, 225, 255 };
    const c = &a ++ &b;
    comptime assert(@TypeOf(c) == *[5:69]u8);
    try expect(c[0] == 1);
    try expect(c[1] == 7);
    try expect(c[2] == 200);
    try expect(c[3] == 225);
    try expect(c[4] == 255);
    const ptr: [*]const u8 = c;
    try expect(ptr[5] == 69);
}

test "array multiplication sets the sentinel - value" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2:7]u3{ 1, 6 };
    _ = &a;
    const b = a ** 2;
    comptime assert(@TypeOf(b) == [4:7]u3);
    try expect(b[0] == 1);
    try expect(b[1] == 6);
    try expect(b[2] == 1);
    try expect(b[3] == 6);
    const ptr: [*]const u3 = &b;
    try expect(ptr[4] == 7);
}

test "array multiplication sets the sentinel - pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var a = [2:7]u3{ 1, 6 };
    const b = &a ** 2;
    comptime assert(@TypeOf(b) == *[4:7]u3);
    try expect(b[0] == 1);
    try expect(b[1] == 6);
    try expect(b[2] == 1);
    try expect(b[3] == 6);
    const ptr: [*]const u3 = b;
    try expect(ptr[4] == 7);
}

test "comptime assign int to optional int" {
    comptime {
        var x: ?i32 = null;
        x = 2;
        x.? *= 10;
        try expectEqual(20, x.?);
    }
}

test "two comptime calls with array default initialized to undefined" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const A = struct {
            c: B = B{},

            pub fn d() void {
                var f: A = .{};
                f.e();
            }

            pub fn e(g: A) void {
                _ = g;
            }
        };

        const B = struct {
            buffer: [255]u8 = undefined,
        };
    };

    comptime {
        S.A.d();
        S.A.d();
    }
}

test "const type-annotated local initialized with function call has correct type" {
    const S = struct {
        fn foo() comptime_int {
            return 1234;
        }
    };
    const x: u64 = S.foo();
    try expect(@TypeOf(x) == u64);
    try expect(x == 1234);
}

test "comptime pointer load through elem_ptr" {
    const S = struct {
        x: usize,
    };

    comptime {
        var array: [10]S = undefined;
        for (&array, 0..) |*elem, i| {
            elem.* = .{
                .x = i,
            };
        }
        var ptr: [*]S = @ptrCast(&array);
        const x = ptr[0].x;
        assert(x == 0);
        ptr += 1;
        assert(ptr[1].x == 2);
    }
}

test "debug variable type resolved through indirect zero-bit types" {
    const T = struct { key: []void };
    const slice: []const T = &[_]T{};
    _ = slice;
}

test "const local with comptime init through array init" {
    const E1 = enum {
        A,
        pub fn a() void {}
    };

    const S = struct {
        fn declarations(comptime T: type) []const std.builtin.Type.Declaration {
            return @typeInfo(T).Enum.decls;
        }
    };

    const decls = comptime [_][]const std.builtin.Type.Declaration{
        S.declarations(E1),
    };

    comptime assert(decls[0][0].name[0] == 'a');
}

test "closure capture type of runtime-known parameter" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn b(c: anytype) !void {
            const D = struct { c: @TypeOf(c) };
            const d: D = .{ .c = c };
            try expect(d.c == 1234);
        }
    };
    var c: i32 = 1234;
    _ = &c;
    try S.b(c);
}

test "closure capture type of runtime-known var" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var x: u32 = 1234;
    _ = &x;
    const S = struct { val: @TypeOf(x + 100) };
    const s: S = .{ .val = x };
    try expect(s.val == 1234);
}

test "comptime break passing through runtime condition converted to runtime break" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var runtime: u8 = 'b';
            _ = &runtime;
            inline for ([3]u8{ 'a', 'b', 'c' }) |byte| {
                bar();
                if (byte == runtime) {
                    foo(byte);
                    break;
                }
            }
            try expect(ok);
            try expect(count == 2);
        }
        var ok = false;
        var count: usize = 0;

        fn foo(byte: u8) void {
            ok = byte == 'b';
        }

        fn bar() void {
            count += 1;
        }
    };

    try S.doTheTest();
}

test "comptime break to outer loop passing through runtime condition converted to runtime break" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn doTheTest() !void {
            var runtime: u8 = 'b';
            _ = &runtime;
            outer: inline for ([3]u8{ 'A', 'B', 'C' }) |outer_byte| {
                inline for ([3]u8{ 'a', 'b', 'c' }) |byte| {
                    bar(outer_byte);
                    if (byte == runtime) {
                        foo(byte);
                        break :outer;
                    }
                }
            }
            try expect(ok);
            try expect(count == 2);
        }
        var ok = false;
        var count: usize = 0;

        fn foo(byte: u8) void {
            ok = byte == 'b';
        }

        fn bar(byte: u8) void {
            _ = byte;
            count += 1;
        }
    };

    try S.doTheTest();
}

test "comptime break operand passing through runtime condition converted to runtime break" {
    const S = struct {
        fn doTheTest(runtime: u8) !void {
            const result = inline for ([3]u8{ 'a', 'b', 'c' }) |byte| {
                if (byte == runtime) {
                    break runtime;
                }
            } else 'z';
            try expect(result == 'b');
        }
    };

    try S.doTheTest('b');
    try comptime S.doTheTest('b');
}

test "comptime break operand passing through runtime switch converted to runtime break" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(runtime: u8) !void {
            const result = inline for ([3]u8{ 'a', 'b', 'c' }) |byte| {
                switch (runtime) {
                    byte => break runtime,
                    else => {},
                }
            } else 'z';
            try expect(result == 'b');
        }
    };

    try S.doTheTest('b');
    try comptime S.doTheTest('b');
}

test "no dependency loop for alignment of self struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: namespace.A = undefined;
            a.d = .{ .g = &buf };
            a.d.g[3] = 42;
            a.d.g[3] += 1;
            try expect(a.d.g[3] == 43);
        }

        var buf: [10]u8 align(@alignOf([*]u8)) = undefined;

        const namespace = struct {
            const B = struct { a: A };
            const A = C(B);
        };

        pub fn C(comptime B: type) type {
            return struct {
                d: D(F) = .{},

                const F = struct { b: B };
            };
        }

        pub fn D(comptime F: type) type {
            return struct {
                g: [*]align(@alignOf(F)) u8 = undefined,
            };
        }
    };
    try S.doTheTest();
}

test "no dependency loop for alignment of self bare union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: namespace.A = undefined;
            a.d = .{ .g = &buf };
            a.d.g[3] = 42;
            a.d.g[3] += 1;
            try expect(a.d.g[3] == 43);
        }

        var buf: [10]u8 align(@alignOf([*]u8)) = undefined;

        const namespace = struct {
            const B = union { a: A, b: void };
            const A = C(B);
        };

        pub fn C(comptime B: type) type {
            return struct {
                d: D(F) = .{},

                const F = struct { b: B };
            };
        }

        pub fn D(comptime F: type) type {
            return struct {
                g: [*]align(@alignOf(F)) u8 = undefined,
            };
        }
    };
    try S.doTheTest();
}

test "no dependency loop for alignment of self tagged union" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() !void {
            var a: namespace.A = undefined;
            a.d = .{ .g = &buf };
            a.d.g[3] = 42;
            a.d.g[3] += 1;
            try expect(a.d.g[3] == 43);
        }

        var buf: [10]u8 align(@alignOf([*]u8)) = undefined;

        const namespace = struct {
            const B = union(enum) { a: A, b: void };
            const A = C(B);
        };

        pub fn C(comptime B: type) type {
            return struct {
                d: D(F) = .{},

                const F = struct { b: B };
            };
        }

        pub fn D(comptime F: type) type {
            return struct {
                g: [*]align(@alignOf(F)) u8 = undefined,
            };
        }
    };
    try S.doTheTest();
}

test "equality of pointers to comptime const" {
    const a: i32 = undefined;
    comptime assert(&a == &a);
}

test "storing an array of type in a field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest() void {
            const foobar = Foobar.foo();
            foo(foobar.str[0..10]);
        }
        const Foobar = struct {
            myTypes: [128]type,
            str: [1024]u8,

            fn foo() @This() {
                comptime var foobar: Foobar = undefined;
                foobar.str = [_]u8{'a'} ** 1024;
                return foobar;
            }
        };

        fn foo(arg: anytype) void {
            _ = arg;
        }
    };

    S.doTheTest();
}

test "pass pointer to field of comptime-only type as a runtime parameter" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        const Mixed = struct {
            T: type,
            x: i32,
        };
        const bag: Mixed = .{
            .T = bool,
            .x = 1234,
        };

        var ok = false;

        fn doTheTest() !void {
            foo(&bag.x);
            try expect(ok);
        }

        fn foo(ptr: *const i32) void {
            ok = ptr.* == 1234;
        }
    };
    try S.doTheTest();
}

test "comptime write through extern struct reinterpreted as array" {
    comptime {
        const S = extern struct {
            a: u8,
            b: u8,
            c: u8,
        };
        var s: S = undefined;
        @as(*[3]u8, @ptrCast(&s))[0] = 1;
        @as(*[3]u8, @ptrCast(&s))[1] = 2;
        @as(*[3]u8, @ptrCast(&s))[2] = 3;
        assert(s.a == 1);
        assert(s.b == 2);
        assert(s.c == 3);
    }
}

test "continue nested in a conditional in an inline for" {
    var x: u32 = 1;
    inline for ([_]u8{ 1, 2, 3 }) |_| {
        if (1 == 1) {
            x = 0;
            continue;
        }
    }
    try expect(x == 0);
}

test "optional pointer represented as a pointer value" {
    comptime {
        var val: u8 = 15;
        const opt_ptr: ?*u8 = &val;

        const payload_ptr = &opt_ptr.?;
        try expect(payload_ptr.*.* == 15);
    }
}

test "mutate through pointer-like optional at comptime" {
    comptime {
        var val: u8 = 15;
        var opt_ptr: ?*const u8 = &val;

        const payload_ptr = &opt_ptr.?;
        payload_ptr.* = &@as(u8, 16);
        try expect(payload_ptr.*.* == 16);
    }
}

test "repeated value is correctly expanded" {
    const S = struct { x: [4]i8 = std.mem.zeroes([4]i8) };
    const M = struct { x: [4]S = std.mem.zeroes([4]S) };

    comptime {
        var res = M{};
        for (.{ 1, 2, 3 }) |i| res.x[i].x[i] = i;

        try expectEqual(M{ .x = .{
            .{ .x = .{ 0, 0, 0, 0 } },
            .{ .x = .{ 0, 1, 0, 0 } },
            .{ .x = .{ 0, 0, 2, 0 } },
            .{ .x = .{ 0, 0, 0, 3 } },
        } }, res);
    }
}

test "value in if block is comptime-known" {
    const first = blk: {
        const s = if (false) "a" else "b";
        break :blk "foo" ++ s;
    };
    const second = blk: {
        const S = struct { str: []const u8 };
        const s = if (false) S{ .str = "a" } else S{ .str = "b" };
        break :blk "foo" ++ s.str;
    };
    comptime assert(std.mem.eql(u8, first, second));
}

test "lazy sizeof is resolved in division" {
    const A = struct {
        a: u32,
    };
    const a = 2;
    try expect(@sizeOf(A) / a == 2);
    try expect(@sizeOf(A) - a == 2);
}

test "lazy value is resolved as slice operand" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const A = struct { a: u32 };
    var a: [512]u64 = undefined;

    const ptr1 = a[0..@sizeOf(A)];
    const ptr2 = @as([*]u8, @ptrCast(&a))[0..@sizeOf(A)];
    try expect(@intFromPtr(ptr1) == @intFromPtr(ptr2));
    try expect(ptr1.len == ptr2.len);
}

test "break from inline loop depends on runtime condition" {
    const S = struct {
        fn foo(a: u8) bool {
            return a == 4;
        }
    };
    const arr = [_]u8{ 1, 2, 3, 4 };
    {
        const blk = blk: {
            inline for (arr) |val| {
                if (S.foo(val)) {
                    break :blk val;
                }
            }
            return error.TestFailed;
        };
        try expect(blk == 4);
    }

    {
        comptime var i = 0;
        const blk = blk: {
            inline while (i < arr.len) : (i += 1) {
                const val = arr[i];
                if (S.foo(val)) {
                    break :blk val;
                }
            }
            return error.TestFailed;
        };
        try expect(blk == 4);
    }
}

test "inline for inside a runtime condition" {
    var a = false;
    _ = &a;
    if (a) {
        const arr = .{ 1, 2, 3 };
        inline for (arr) |val| {
            if (val < 3) continue;
            try expect(val == 3);
        }
    }
}

test "continue in inline for inside a comptime switch" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const arr = .{ 1, 2, 3 };
    var count: u8 = 0;
    switch (arr[1]) {
        2 => {
            inline for (arr) |val| {
                if (val == 2) continue;

                count += val;
            }
        },
        else => {},
    }
    try expect(count == 4);
}

test "length of global array is determinable at comptime" {
    const S = struct {
        var bytes: [1024]u8 = undefined;

        fn foo() !void {
            try std.testing.expect(bytes.len == 1024);
        }
    };
    try comptime S.foo();
}

test "continue nested inline for loop" {
    // TODO: https://github.com/ziglang/zig/issues/13175
    if (true) return error.SkipZigTest;

    var a: u8 = 0;
    loop: inline for ([_]u8{ 1, 2 }) |x| {
        inline for ([_]u8{1}) |y| {
            if (x == y) {
                continue :loop;
            }
        }
        a = x;
        try expect(x == 2);
    }
    try expect(a == 2);
}

test "continue nested inline for loop in named block expr" {
    // TODO: https://github.com/ziglang/zig/issues/13175
    if (true) return error.SkipZigTest;

    var a: u8 = 0;
    loop: inline for ([_]u8{ 1, 2 }) |x| {
        a = b: {
            inline for ([_]u8{1}) |y| {
                if (x == y) {
                    continue :loop;
                }
            }
            break :b x;
        };
        try expect(x == 2);
    }
    try expect(a == 2);
}

test "x and false is comptime-known false" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = struct {
        var x: u32 = 0;

        fn foo() bool {
            x += 1; // Observable side-effect
            return true;
        }
    };

    if (T.foo() and T.foo() and false and T.foo()) {
        @compileError("Condition should be comptime-known false");
    }
    try expect(T.x == 2);

    T.x = 0;
    if (T.foo() and T.foo() and b: {
        _ = T.foo();
        break :b false;
    } and T.foo()) {
        @compileError("Condition should be comptime-known false");
    }
    try expect(T.x == 3);
}

test "x or true is comptime-known true" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = struct {
        var x: u32 = 0;

        fn foo() bool {
            x += 1; // Observable side-effect
            return false;
        }
    };

    if (!(T.foo() or T.foo() or true or T.foo())) {
        @compileError("Condition should be comptime-known false");
    }
    try expect(T.x == 2);

    T.x = 0;
    if (!(T.foo() or T.foo() or b: {
        _ = T.foo();
        break :b true;
    } or T.foo())) {
        @compileError("Condition should be comptime-known false");
    }
    try expect(T.x == 3);
}

test "non-optional and optional array elements concatenated" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const array = [1]u8{'A'} ++ [1]?u8{null};
    var index: usize = 0;
    _ = &index;
    try expect(array[index].? == 'A');
}

test "inline call in @TypeOf inherits is_inline property" {
    const S = struct {
        inline fn doNothing() void {}
        const T = @TypeOf(doNothing());
    };
    try expect(S.T == void);
}

test "comptime function turns function value to function pointer" {
    const S = struct {
        fn fnPtr(function: anytype) *const @TypeOf(function) {
            return &function;
        }
        fn Nil() u8 {
            return 0;
        }
        const foo = &[_]*const fn () u8{
            fnPtr(Nil),
        };
    };
    comptime assert(S.foo[0] == &S.Nil);
}

test "container level const and var have unique addresses" {
    const S = struct {
        x: i32,
        y: i32,
        const c = @This(){ .x = 1, .y = 1 };
        var v: @This() = c;
    };
    var p = &S.c;
    _ = &p;
    try std.testing.expect(p.x == S.c.x);
    S.v.x = 2;
    try std.testing.expect(p.x == S.c.x);
}

test "break from block results in type" {
    const S = struct {
        fn NewType(comptime T: type) type {
            const Padded = blk: {
                if (@sizeOf(T) <= @sizeOf(usize)) break :blk void;
                break :blk T;
            };

            return Padded;
        }
    };
    const T = S.NewType(usize);
    try expect(T == void);
}

test "struct in comptime false branch is not evaluated" {
    const S = struct {
        const comptime_const = 2;
        fn some(comptime V: type) type {
            return switch (comptime_const) {
                3 => struct { a: V.foo },
                2 => V,
                else => unreachable,
            };
        }
    };
    try expect(S.some(u32) == u32);
}

test "result of nested switch assigned to variable" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var zds: u32 = 0;
    zds = switch (zds) {
        0 => switch (zds) {
            0...0 => 1234,
            1...1 => zds,
            2 => zds,
            else => return,
        },
        else => zds,
    };
    try expect(zds == 1234);
}

test "inline for loop of functions returning error unions" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const T1 = struct {
        fn v() error{}!usize {
            return 1;
        }
    };
    const T2 = struct {
        fn v() error{Error}!usize {
            return 2;
        }
    };
    var a: usize = 0;
    inline for (.{ T1, T2 }) |T| {
        a += try T.v();
    }
    try expect(a == 3);
}

test "if inside a switch" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    var condition = true;
    var wave_type: u32 = 0;
    _ = .{ &condition, &wave_type };
    const sample: i32 = switch (wave_type) {
        0 => if (condition) 2 else 3,
        1 => 100,
        2 => 200,
        3 => 300,
        else => unreachable,
    };
    try expect(sample == 2);
}

test "function has correct return type when previous return is casted to smaller type" {
    const S = struct {
        fn foo(b: bool) u16 {
            if (b) return @as(u8, 0xFF);
            return 0xFFFF;
        }
    };
    try expect(S.foo(true) == 0xFF);
}

test "early exit in container level const" {
    const S = struct {
        const value = blk: {
            if (true) {
                break :blk @as(u32, 1);
            }
            break :blk @as(u32, 0);
        };
    };
    try expect(S.value == 1);
}

test "@inComptime" {
    const S = struct {
        fn inComptime() bool {
            return @inComptime();
        }
    };
    try expectEqual(false, @inComptime());
    try expectEqual(true, comptime @inComptime());
    try expectEqual(false, S.inComptime());
    try expectEqual(true, comptime S.inComptime());
}

// comptime partial array assign
comptime {
    var foo = [3]u8{ 0x55, 0x55, 0x55 };
    var bar = [2]u8{ 1, 2 };
    _ = .{ &foo, &bar };
    foo[0..2].* = bar;
    assert(foo[0] == 1);
    assert(foo[1] == 2);
    assert(foo[2] == 0x55);
}

test "const with allocation before result is comptime-known" {
    const x = blk: {
        const y = [1]u32{2};
        _ = y;
        break :blk [1]u32{42};
    };
    comptime assert(@TypeOf(x) == [1]u32);
    comptime assert(x[0] == 42);
}

test "const with specified type initialized with typed array is comptime-known" {
    const x: [3]u16 = [3]u16{ 1, 2, 3 };
    comptime assert(@TypeOf(x) == [3]u16);
    comptime assert(x[0] == 1);
    comptime assert(x[1] == 2);
    comptime assert(x[2] == 3);
}

test "block with comptime-known result but possible runtime exit is comptime-known" {
    var t: bool = true;
    _ = &t;

    const a: comptime_int = a: {
        if (!t) return error.TestFailed;
        break :a 123;
    };

    const b: comptime_int = b: {
        if (t) break :b 456;
        return error.TestFailed;
    };

    comptime assert(a == 123);
    comptime assert(b == 456);
}
