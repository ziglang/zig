const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");

fn unwrapAndAddOne(blah: ?i32) i32 {
    return blah.? + 1;
}
const should_be_1235 = unwrapAndAddOne(1234);
test "static add one" {
    assertOrPanic(should_be_1235 == 1235);
}

test "inlined loop" {
    comptime var i = 0;
    comptime var sum = 0;
    inline while (i <= 5) : (i += 1)
        sum += i;
    assertOrPanic(sum == 15);
}

fn gimme1or2(comptime a: bool) i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    comptime var z: i32 = if (a) x else y;
    return z;
}
test "inline variable gets result of const if" {
    assertOrPanic(gimme1or2(true) == 1);
    assertOrPanic(gimme1or2(false) == 2);
}

test "static function evaluation" {
    assertOrPanic(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) i32 {
    return a + b;
}

test "const expr eval on single expr blocks" {
    assertOrPanic(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
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

test "statically initialized list" {
    assertOrPanic(static_point_list[0].x == 1);
    assertOrPanic(static_point_list[0].y == 2);
    assertOrPanic(static_point_list[1].x == 3);
    assertOrPanic(static_point_list[1].y == 4);
}
const Point = struct {
    x: i32,
    y: i32,
};
const static_point_list = []Point{
    makePoint(1, 2),
    makePoint(3, 4),
};
fn makePoint(x: i32, y: i32) Point {
    return Point{
        .x = x,
        .y = y,
    };
}

test "static eval list init" {
    assertOrPanic(static_vec3.data[2] == 1.0);
    assertOrPanic(vec3(0.0, 0.0, 3.0).data[2] == 3.0);
}
const static_vec3 = vec3(0.0, 0.0, 1.0);
pub const Vec3 = struct {
    data: [3]f32,
};
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ .data = []f32{
        x,
        y,
        z,
    } };
}

test "constant expressions" {
    var array: [array_size]u8 = undefined;
    assertOrPanic(@sizeOf(@typeOf(array)) == 20);
}
const array_size: u8 = 20;

test "constant struct with negation" {
    assertOrPanic(vertices[0].x == -0.6);
}
const Vertex = struct {
    x: f32,
    y: f32,
    r: f32,
    g: f32,
    b: f32,
};
const vertices = []Vertex{
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

test "statically initialized struct" {
    st_init_str_foo.x += 1;
    assertOrPanic(st_init_str_foo.x == 14);
}
const StInitStrFoo = struct {
    x: i32,
    y: bool,
};
var st_init_str_foo = StInitStrFoo{
    .x = 13,
    .y = true,
};

test "statically initalized array literal" {
    const y: [4]u8 = st_init_arr_lit_x;
    assertOrPanic(y[3] == 4);
}
const st_init_arr_lit_x = []u8{
    1,
    2,
    3,
    4,
};

test "const slice" {
    comptime {
        const a = "1234567890";
        assertOrPanic(a.len == 10);
        const b = a[1..2];
        assertOrPanic(b.len == 1);
        assertOrPanic(b[0] == '2');
    }
}

test "try to trick eval with runtime if" {
    assertOrPanic(testTryToTrickEvalWithRuntimeIf(true) == 10);
}

fn testTryToTrickEvalWithRuntimeIf(b: bool) usize {
    comptime var i: usize = 0;
    inline while (i < 10) : (i += 1) {
        const result = if (b) false else true;
    }
    comptime {
        return i;
    }
}

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
    assertOrPanic(letsTryToCompareBools(true, true));
    assertOrPanic(letsTryToCompareBools(true, false));
    assertOrPanic(letsTryToCompareBools(false, true));
    assertOrPanic(!letsTryToCompareBools(false, false));

    comptime {
        assertOrPanic(letsTryToCompareBools(true, true));
        assertOrPanic(letsTryToCompareBools(true, false));
        assertOrPanic(letsTryToCompareBools(false, true));
        assertOrPanic(!letsTryToCompareBools(false, false));
    }
}

const CmdFn = struct {
    name: []const u8,
    func: fn (i32) i32,
};

const cmd_fns = []CmdFn{
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
    assertOrPanic(performFn('t', 1) == 6);
    assertOrPanic(performFn('o', 0) == 1);
    assertOrPanic(performFn('w', 99) == 99);
}

test "eval @setRuntimeSafety at compile-time" {
    const result = comptime fnWithSetRuntimeSafety();
    assertOrPanic(result == 1234);
}

fn fnWithSetRuntimeSafety() i32 {
    @setRuntimeSafety(true);
    return 1234;
}

test "eval @setFloatMode at compile-time" {
    const result = comptime fnWithFloatMode();
    assertOrPanic(result == 1234.0);
}

fn fnWithFloatMode() f32 {
    @setFloatMode(builtin.FloatMode.Strict);
    return 1234.0;
}

const SimpleStruct = struct {
    field: i32,

    fn method(self: *const SimpleStruct) i32 {
        return self.field + 3;
    }
};

var simple_struct = SimpleStruct{ .field = 1234 };

const bound_fn = simple_struct.method;

test "call method on bound fn referring to var instance" {
    assertOrPanic(bound_fn() == 1237);
}

test "ptr to local array argument at comptime" {
    comptime {
        var bytes: [10]u8 = undefined;
        modifySomeBytes(bytes[0..]);
        assertOrPanic(bytes[0] == 'a');
        assertOrPanic(bytes[9] == 'b');
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
        @compileError("this condition should be comptime known");
    }
    if (0 > x) {
        @compileError("this condition should be comptime known");
    }
    if (!(x >= 0)) {
        @compileError("this condition should be comptime known");
    }
    if (x < 0) {
        @compileError("this condition should be comptime known");
    }
}

test "const ptr to variable data changes at runtime" {
    assertOrPanic(foo_ref.name[0] == 'a');
    foo_ref.name = "b";
    assertOrPanic(foo_ref.name[0] == 'b');
}

const Foo = struct {
    name: []const u8,
};

var foo_contents = Foo{ .name = "a" };
const foo_ref = &foo_contents;

test "create global array with for loop" {
    assertOrPanic(global_array[5] == 5 * 5);
    assertOrPanic(global_array[9] == 9 * 9);
}

const global_array = x: {
    var result: [10]usize = undefined;
    for (result) |*item, index| {
        item.* = index * index;
    }
    break :x result;
};

test "compile-time downcast when the bits fit" {
    comptime {
        const spartan_count: u16 = 255;
        const byte = @intCast(u8, spartan_count);
        assertOrPanic(byte == 255);
    }
}

const hi1 = "hi";
const hi2 = hi1;
test "const global shares pointer with other same one" {
    assertEqualPtrs(&hi1[0], &hi2[0]);
    comptime assertOrPanic(&hi1[0] == &hi2[0]);
}
fn assertEqualPtrs(ptr1: *const u8, ptr2: *const u8) void {
    assertOrPanic(ptr1 == ptr2);
}

test "@setEvalBranchQuota" {
    comptime {
        // 1001 for the loop and then 1 more for the assertOrPanic fn call
        @setEvalBranchQuota(1002);
        var i = 0;
        var sum = 0;
        while (i < 1001) : (i += 1) {
            sum += i;
        }
        assertOrPanic(sum == 500500);
    }
}

// TODO test "float literal at compile time not lossy" {
// TODO     assertOrPanic(16777216.0 + 1.0 == 16777217.0);
// TODO     assertOrPanic(9007199254740992.0 + 1.0 == 9007199254740993.0);
// TODO }

test "f32 at compile time is lossy" {
    assertOrPanic(f32(1 << 24) + 1 == 1 << 24);
}

test "f64 at compile time is lossy" {
    assertOrPanic(f64(1 << 53) + 1 == 1 << 53);
}

test "f128 at compile time is lossy" {
    assertOrPanic(f128(10384593717069655257060992658440192.0) + 1 == 10384593717069655257060992658440192.0);
}

// TODO need a better implementation of bigfloat_init_bigint
// assertOrPanic(f128(1 << 113) == 10384593717069655257060992658440192);

pub fn TypeWithCompTimeSlice(comptime field_name: []const u8) type {
    return struct {
        pub const Node = struct {};
    };
}

test "string literal used as comptime slice is memoized" {
    const a = "link";
    const b = "link";
    comptime assertOrPanic(TypeWithCompTimeSlice(a).Node == TypeWithCompTimeSlice(b).Node);
    comptime assertOrPanic(TypeWithCompTimeSlice("link").Node == TypeWithCompTimeSlice("link").Node);
}

test "comptime slice of undefined pointer of length 0" {
    const slice1 = ([*]i32)(undefined)[0..0];
    assertOrPanic(slice1.len == 0);
    const slice2 = ([*]i32)(undefined)[100..100];
    assertOrPanic(slice2.len == 0);
}

fn copyWithPartialInline(s: []u32, b: []u8) void {
    comptime var i: usize = 0;
    inline while (i < 4) : (i += 1) {
        s[i] = 0;
        s[i] |= u32(b[i * 4 + 0]) << 24;
        s[i] |= u32(b[i * 4 + 1]) << 16;
        s[i] |= u32(b[i * 4 + 2]) << 8;
        s[i] |= u32(b[i * 4 + 3]) << 0;
    }
}

test "binary math operator in partially inlined function" {
    var s: [4]u32 = undefined;
    var b: [16]u8 = undefined;

    for (b) |*r, i|
        r.* = @intCast(u8, i + 1);

    copyWithPartialInline(s[0..], b[0..]);
    assertOrPanic(s[0] == 0x1020304);
    assertOrPanic(s[1] == 0x5060708);
    assertOrPanic(s[2] == 0x90a0b0c);
    assertOrPanic(s[3] == 0xd0e0f10);
}

test "comptime function with the same args is memoized" {
    comptime {
        assertOrPanic(MakeType(i32) == MakeType(i32));
        assertOrPanic(MakeType(i32) != MakeType(f64));
    }
}

fn MakeType(comptime T: type) type {
    return struct {
        field: T,
    };
}

test "comptime function with mutable pointer is not memoized" {
    comptime {
        var x: i32 = 1;
        const ptr = &x;
        increment(ptr);
        increment(ptr);
        assertOrPanic(x == 3);
    }
}

fn increment(value: *i32) void {
    value.* += 1;
}

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
    assertOrPanic(doesAlotT(u32, 2) == 2);
}

test "comptime slice of slice preserves comptime var" {
    comptime {
        var buff: [10]u8 = undefined;
        buff[0..][0..][0] = 1;
        assertOrPanic(buff[0..][0..][0] == 1);
    }
}

test "comptime slice of pointer preserves comptime var" {
    comptime {
        var buff: [10]u8 = undefined;
        var a = buff[0..].ptr;
        a[0..1][0] = 1;
        assertOrPanic(buff[0..][0..][0] == 1);
    }
}

const SingleFieldStruct = struct {
    x: i32,

    fn read_x(self: *const SingleFieldStruct) i32 {
        return self.x;
    }
};
test "const ptr to comptime mutable data is not memoized" {
    comptime {
        var foo = SingleFieldStruct{ .x = 1 };
        assertOrPanic(foo.read_x() == 1);
        foo.x = 2;
        assertOrPanic(foo.read_x() == 2);
    }
}

test "array concat of slices gives slice" {
    comptime {
        var a: []const u8 = "aoeu";
        var b: []const u8 = "asdf";
        const c = a ++ b;
        assertOrPanic(std.mem.eql(u8, c, "aoeuasdf"));
    }
}

test "comptime shlWithOverflow" {
    const ct_shifted: u64 = comptime amt: {
        var amt = u64(0);
        _ = @shlWithOverflow(u64, ~u64(0), 16, &amt);
        break :amt amt;
    };

    const rt_shifted: u64 = amt: {
        var amt = u64(0);
        _ = @shlWithOverflow(u64, ~u64(0), 16, &amt);
        break :amt amt;
    };

    assertOrPanic(ct_shifted == rt_shifted);
}

test "runtime 128 bit integer division" {
    var a: u128 = 152313999999999991610955792383;
    var b: u128 = 10000000000000000000;
    var c = a / b;
    assertOrPanic(c == 15231399999);
}

pub const Info = struct {
    version: u8,
};

pub const diamond_info = Info{ .version = 0 };

test "comptime modification of const struct field" {
    comptime {
        var res = diamond_info;
        res.version = 1;
        assertOrPanic(diamond_info.version == 0);
        assertOrPanic(res.version == 1);
    }
}

test "pointer to type" {
    comptime {
        var T: type = i32;
        assertOrPanic(T == i32);
        var ptr = &T;
        assertOrPanic(@typeOf(ptr) == *type);
        ptr.* = f32;
        assertOrPanic(T == f32);
        assertOrPanic(*T == *f32);
    }
}

test "slice of type" {
    comptime {
        var types_array = []type{ i32, f64, type };
        for (types_array) |T, i| {
            switch (i) {
                0 => assertOrPanic(T == i32),
                1 => assertOrPanic(T == f64),
                2 => assertOrPanic(T == type),
                else => unreachable,
            }
        }
        for (types_array[0..]) |T, i| {
            switch (i) {
                0 => assertOrPanic(T == i32),
                1 => assertOrPanic(T == f64),
                2 => assertOrPanic(T == type),
                else => unreachable,
            }
        }
    }
}

const Wrapper = struct {
    T: type,
};

fn wrap(comptime T: type) Wrapper {
    return Wrapper{ .T = T };
}

test "function which returns struct with type field causes implicit comptime" {
    const ty = wrap(i32).T;
    assertOrPanic(ty == i32);
}

test "call method with comptime pass-by-non-copying-value self parameter" {
    const S = struct {
        a: u8,

        fn b(comptime s: @This()) u8 {
            return s.a;
        }
    };

    const s = S{ .a = 2 };
    var b = s.b();
    assertOrPanic(b == 2);
}

test "@tagName of @typeId" {
    const str = @tagName(@typeId(u8));
    assertOrPanic(std.mem.eql(u8, str, "Int"));
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
    testVarInsideInlineLoop(true, u32(42));
}

fn testVarInsideInlineLoop(args: ...) void {
    comptime var i = 0;
    inline while (i < args.len) : (i += 1) {
        const x = args[i];
        if (i == 0) assertOrPanic(x);
        if (i == 1) assertOrPanic(x == 42);
    }
}

test "inline for with same type but different values" {
    var res: usize = 0;
    inline for ([]type{ [2]u8, [1]u8, [2]u8 }) |T| {
        var a: T = undefined;
        res += a.len;
    }
    assertOrPanic(res == 5);
}

test "refer to the type of a generic function" {
    const Func = fn (type) void;
    const f: Func = doNothingWithType;
    f(i32);
}

fn doNothingWithType(comptime T: type) void {}

test "zero extend from u0 to u1" {
    var zero_u0: u0 = 0;
    var zero_u1: u1 = zero_u0;
    assertOrPanic(zero_u1 == 0);
}

test "bit shift a u1" {
    var x: u1 = 1;
    var y = x << 0;
    assertOrPanic(y == 1);
}

test "@intCast to a u0" {
    var x: u8 = 0;
    var y: u0 = @intCast(u0, x);
    assertOrPanic(y == 0);
}

test "@bytesToslice on a packed struct" {
    const F = packed struct {
        a: u8,
    };

    var b = [1]u8{9};
    var f = @bytesToSlice(F, b);
    assertOrPanic(f[0].a == 9);
}

test "comptime pointer cast array and then slice" {
    const array = []u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const ptrA: [*]const u8 = @ptrCast([*]const u8, &array);
    const sliceA: []const u8 = ptrA[0..2];

    const ptrB: [*]const u8 = &array;
    const sliceB: []const u8 = ptrB[0..2];

    assertOrPanic(sliceA[1] == 2);
    assertOrPanic(sliceB[1] == 2);
}

test "slice bounds in comptime concatenation" {
    const bs = comptime blk: {
        const b = c"11";
        break :blk b[0..1];
    };
    const str = "" ++ bs;
    assertOrPanic(str.len == 1);
    assertOrPanic(std.mem.eql(u8, str, "1"));

    const str2 = bs ++ "";
    assertOrPanic(str2.len == 1);
    assertOrPanic(std.mem.eql(u8, str2, "1"));
}

test "comptime bitwise operators" {
    comptime {
        assertOrPanic(3 & 1 == 1);
        assertOrPanic(3 & -1 == 3);
        assertOrPanic(-3 & -1 == -3);
        assertOrPanic(3 | -1 == -1);
        assertOrPanic(-3 | -1 == -1);
        assertOrPanic(3 ^ -1 == -4);
        assertOrPanic(-3 ^ -1 == 2);
        assertOrPanic(~i8(-1) == 0);
        assertOrPanic(~i128(-1) == 0);
        assertOrPanic(18446744073709551615 & 18446744073709551611 == 18446744073709551611);
        assertOrPanic(-18446744073709551615 & -18446744073709551611 == -18446744073709551615);
        assertOrPanic(~u128(0) == 0xffffffffffffffffffffffffffffffff);
    }
}

test "*align(1) u16 is the same as *align(1:0:2) u16" {
    comptime {
        assertOrPanic(*align(1:0:2) u16 == *align(1) u16);
        // TODO add parsing support for this syntax
        //assertOrPanic(*align(:0:2) u16 == *u16);
    }
}

test "array concatenation forces comptime" {
    var a = oneItem(3) ++ oneItem(4);
    assertOrPanic(std.mem.eql(i32, a, []i32{ 3, 4 }));
}

test "array multiplication forces comptime" {
    var a = oneItem(3) ** scalar(2);
    assertOrPanic(std.mem.eql(i32, a, []i32{ 3, 3 }));
}

fn oneItem(x: i32) [1]i32 {
    return []i32{x};
}

fn scalar(x: u32) u32 {
    return x;
}
