const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

test "compile time recursion" {
    assert(some_data.len == 21);
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
    assert(should_be_1235 == 1235);
}

test "inlined loop" {
    comptime var i = 0;
    comptime var sum = 0;
    inline while (i <= 5) : (i += 1)
        sum += i;
    assert(sum == 15);
}

fn gimme1or2(comptime a: bool) i32 {
    const x: i32 = 1;
    const y: i32 = 2;
    comptime var z: i32 = if (a) x else y;
    return z;
}
test "inline variable gets result of const if" {
    assert(gimme1or2(true) == 1);
    assert(gimme1or2(false) == 2);
}

test "static function evaluation" {
    assert(statically_added_number == 3);
}
const statically_added_number = staticAdd(1, 2);
fn staticAdd(a: i32, b: i32) i32 {
    return a + b;
}

test "const expr eval on single expr blocks" {
    assert(constExprEvalOnSingleExprBlocksFn(1, true) == 3);
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
    assert(static_point_list[0].x == 1);
    assert(static_point_list[0].y == 2);
    assert(static_point_list[1].x == 3);
    assert(static_point_list[1].y == 4);
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
    assert(static_vec3.data[2] == 1.0);
    assert(vec3(0.0, 0.0, 3.0).data[2] == 3.0);
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
    assert(@sizeOf(@typeOf(array)) == 20);
}
const array_size: u8 = 20;

test "constant struct with negation" {
    assert(vertices[0].x == -0.6);
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
    assert(st_init_str_foo.x == 14);
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
    assert(y[3] == 4);
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
        assert(a.len == 10);
        const b = a[1..2];
        assert(b.len == 1);
        assert(b[0] == '2');
    }
}

test "try to trick eval with runtime if" {
    assert(testTryToTrickEvalWithRuntimeIf(true) == 10);
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
    assert(letsTryToCompareBools(true, true));
    assert(letsTryToCompareBools(true, false));
    assert(letsTryToCompareBools(false, true));
    assert(!letsTryToCompareBools(false, false));

    comptime {
        assert(letsTryToCompareBools(true, true));
        assert(letsTryToCompareBools(true, false));
        assert(letsTryToCompareBools(false, true));
        assert(!letsTryToCompareBools(false, false));
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
    assert(performFn('t', 1) == 6);
    assert(performFn('o', 0) == 1);
    assert(performFn('w', 99) == 99);
}

test "eval @setRuntimeSafety at compile-time" {
    const result = comptime fnWithSetRuntimeSafety();
    assert(result == 1234);
}

fn fnWithSetRuntimeSafety() i32 {
    @setRuntimeSafety(true);
    return 1234;
}

test "eval @setFloatMode at compile-time" {
    const result = comptime fnWithFloatMode();
    assert(result == 1234.0);
}

fn fnWithFloatMode() f32 {
    @setFloatMode(this, builtin.FloatMode.Strict);
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
    assert(bound_fn() == 1237);
}

test "ptr to local array argument at comptime" {
    comptime {
        var bytes: [10]u8 = undefined;
        modifySomeBytes(bytes[0..]);
        assert(bytes[0] == 'a');
        assert(bytes[9] == 'b');
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
    assert(foo_ref.name[0] == 'a');
    foo_ref.name = "b";
    assert(foo_ref.name[0] == 'b');
}

const Foo = struct {
    name: []const u8,
};

var foo_contents = Foo{ .name = "a" };
const foo_ref = &foo_contents;

test "create global array with for loop" {
    assert(global_array[5] == 5 * 5);
    assert(global_array[9] == 9 * 9);
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
        assert(byte == 255);
    }
}

const hi1 = "hi";
const hi2 = hi1;
test "const global shares pointer with other same one" {
    assertEqualPtrs(&hi1[0], &hi2[0]);
    comptime assert(&hi1[0] == &hi2[0]);
}
fn assertEqualPtrs(ptr1: *const u8, ptr2: *const u8) void {
    assert(ptr1 == ptr2);
}

test "@setEvalBranchQuota" {
    comptime {
        // 1001 for the loop and then 1 more for the assert fn call
        @setEvalBranchQuota(1002);
        var i = 0;
        var sum = 0;
        while (i < 1001) : (i += 1) {
            sum += i;
        }
        assert(sum == 500500);
    }
}

// TODO test "float literal at compile time not lossy" {
// TODO     assert(16777216.0 + 1.0 == 16777217.0);
// TODO     assert(9007199254740992.0 + 1.0 == 9007199254740993.0);
// TODO }

test "f32 at compile time is lossy" {
    assert(f32(1 << 24) + 1 == 1 << 24);
}

test "f64 at compile time is lossy" {
    assert(f64(1 << 53) + 1 == 1 << 53);
}

test "f128 at compile time is lossy" {
    assert(f128(10384593717069655257060992658440192.0) + 1 == 10384593717069655257060992658440192.0);
}

// TODO need a better implementation of bigfloat_init_bigint
// assert(f128(1 << 113) == 10384593717069655257060992658440192);

pub fn TypeWithCompTimeSlice(comptime field_name: []const u8) type {
    return struct {
        pub const Node = struct {};
    };
}

test "string literal used as comptime slice is memoized" {
    const a = "link";
    const b = "link";
    comptime assert(TypeWithCompTimeSlice(a).Node == TypeWithCompTimeSlice(b).Node);
    comptime assert(TypeWithCompTimeSlice("link").Node == TypeWithCompTimeSlice("link").Node);
}

test "comptime slice of undefined pointer of length 0" {
    const slice1 = ([*]i32)(undefined)[0..0];
    assert(slice1.len == 0);
    const slice2 = ([*]i32)(undefined)[100..100];
    assert(slice2.len == 0);
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
    assert(s[0] == 0x1020304);
    assert(s[1] == 0x5060708);
    assert(s[2] == 0x90a0b0c);
    assert(s[3] == 0xd0e0f10);
}

test "comptime function with the same args is memoized" {
    comptime {
        assert(MakeType(i32) == MakeType(i32));
        assert(MakeType(i32) != MakeType(f64));
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
        assert(x == 3);
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
    assert(doesAlotT(u32, 2) == 2);
}

test "comptime slice of slice preserves comptime var" {
    comptime {
        var buff: [10]u8 = undefined;
        buff[0..][0..][0] = 1;
        assert(buff[0..][0..][0] == 1);
    }
}

test "comptime slice of pointer preserves comptime var" {
    comptime {
        var buff: [10]u8 = undefined;
        var a = buff[0..].ptr;
        a[0..1][0] = 1;
        assert(buff[0..][0..][0] == 1);
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
        assert(foo.read_x() == 1);
        foo.x = 2;
        assert(foo.read_x() == 2);
    }
}

test "array concat of slices gives slice" {
    comptime {
        var a: []const u8 = "aoeu";
        var b: []const u8 = "asdf";
        const c = a ++ b;
        assert(std.mem.eql(u8, c, "aoeuasdf"));
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

    assert(ct_shifted == rt_shifted);
}

test "runtime 128 bit integer division" {
    var a: u128 = 152313999999999991610955792383;
    var b: u128 = 10000000000000000000;
    var c = a / b;
    assert(c == 15231399999);
}

pub const Info = struct {
    version: u8,
};

pub const diamond_info = Info{ .version = 0 };

test "comptime modification of const struct field" {
    comptime {
        var res = diamond_info;
        res.version = 1;
        assert(diamond_info.version == 0);
        assert(res.version == 1);
    }
}

test "pointer to type" {
    comptime {
        var T: type = i32;
        assert(T == i32);
        var ptr = &T;
        assert(@typeOf(ptr) == *type);
        ptr.* = f32;
        assert(T == f32);
        assert(*T == *f32);
    }
}

test "slice of type" {
    comptime {
        var types_array = []type{ i32, f64, type };
        for (types_array) |T, i| {
            switch (i) {
                0 => assert(T == i32),
                1 => assert(T == f64),
                2 => assert(T == type),
                else => unreachable,
            }
        }
        for (types_array[0..]) |T, i| {
            switch (i) {
                0 => assert(T == i32),
                1 => assert(T == f64),
                2 => assert(T == type),
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
    assert(ty == i32);
}

test "call method with comptime pass-by-non-copying-value self parameter" {
    const S = struct {
        a: u8,

        fn b(comptime s: this) u8 {
            return s.a;
        }
    };

    const s = S{ .a = 2 };
    var b = s.b();
    assert(b == 2);
}

test "@tagName of @typeId" {
    const str = @tagName(@typeId(u8));
    assert(std.mem.eql(u8, str, "Int"));
}
