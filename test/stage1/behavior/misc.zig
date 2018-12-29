const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

// normal comment

/// this is a documentation comment
/// doc comment line 2
fn emptyFunctionWithComments() void {}

test "empty function with comments" {
    emptyFunctionWithComments();
}

comptime {
    @export("disabledExternFn", disabledExternFn, builtin.GlobalLinkage.Internal);
}

extern fn disabledExternFn() void {}

test "call disabled extern fn" {
    disabledExternFn();
}

test "@IntType builtin" {
    assertOrPanic(@IntType(true, 8) == i8);
    assertOrPanic(@IntType(true, 16) == i16);
    assertOrPanic(@IntType(true, 32) == i32);
    assertOrPanic(@IntType(true, 64) == i64);

    assertOrPanic(@IntType(false, 8) == u8);
    assertOrPanic(@IntType(false, 16) == u16);
    assertOrPanic(@IntType(false, 32) == u32);
    assertOrPanic(@IntType(false, 64) == u64);

    assertOrPanic(i8.bit_count == 8);
    assertOrPanic(i16.bit_count == 16);
    assertOrPanic(i32.bit_count == 32);
    assertOrPanic(i64.bit_count == 64);

    assertOrPanic(i8.is_signed);
    assertOrPanic(i16.is_signed);
    assertOrPanic(i32.is_signed);
    assertOrPanic(i64.is_signed);
    assertOrPanic(isize.is_signed);

    assertOrPanic(!u8.is_signed);
    assertOrPanic(!u16.is_signed);
    assertOrPanic(!u32.is_signed);
    assertOrPanic(!u64.is_signed);
    assertOrPanic(!usize.is_signed);
}

test "floating point primitive bit counts" {
    assertOrPanic(f16.bit_count == 16);
    assertOrPanic(f32.bit_count == 32);
    assertOrPanic(f64.bit_count == 64);
}

test "short circuit" {
    testShortCircuit(false, true);
    comptime testShortCircuit(false, true);
}

fn testShortCircuit(f: bool, t: bool) void {
    var hit_1 = f;
    var hit_2 = f;
    var hit_3 = f;
    var hit_4 = f;

    if (t or x: {
        assertOrPanic(f);
        break :x f;
    }) {
        hit_1 = t;
    }
    if (f or x: {
        hit_2 = t;
        break :x f;
    }) {
        assertOrPanic(f);
    }

    if (t and x: {
        hit_3 = t;
        break :x f;
    }) {
        assertOrPanic(f);
    }
    if (f and x: {
        assertOrPanic(f);
        break :x f;
    }) {
        assertOrPanic(f);
    } else {
        hit_4 = t;
    }
    assertOrPanic(hit_1);
    assertOrPanic(hit_2);
    assertOrPanic(hit_3);
    assertOrPanic(hit_4);
}

test "truncate" {
    assertOrPanic(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) u8 {
    return @truncate(u8, x);
}

fn first4KeysOfHomeRow() []const u8 {
    return "aoeu";
}

test "return string from function" {
    assertOrPanic(mem.eql(u8, first4KeysOfHomeRow(), "aoeu"));
}

const g1: i32 = 1233 + 1;
var g2: i32 = 0;

test "global variables" {
    assertOrPanic(g2 == 0);
    g2 = g1;
    assertOrPanic(g2 == 1234);
}

test "memcpy and memset intrinsics" {
    var foo: [20]u8 = undefined;
    var bar: [20]u8 = undefined;

    @memset(foo[0..].ptr, 'A', foo.len);
    @memcpy(bar[0..].ptr, foo[0..].ptr, bar.len);

    if (bar[11] != 'A') unreachable;
}

test "builtin static eval" {
    const x: i32 = comptime x: {
        break :x 1 + 2 + 3;
    };
    assertOrPanic(x == comptime 6);
}

test "slicing" {
    var array: [20]i32 = undefined;

    array[5] = 1234;

    var slice = array[5..10];

    if (slice.len != 5) unreachable;

    const ptr = &slice[0];
    if (ptr.* != 1234) unreachable;

    var slice_rest = array[10..];
    if (slice_rest.len != 10) unreachable;
}

test "constant equal function pointers" {
    const alias = emptyFn;
    assertOrPanic(comptime x: {
        break :x emptyFn == alias;
    });
}

fn emptyFn() void {}

test "hex escape" {
    assertOrPanic(mem.eql(u8, "\x68\x65\x6c\x6c\x6f", "hello"));
}

test "string concatenation" {
    assertOrPanic(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    assertOrPanic(mem.eql(u8, "ab" ** 5, "ababababab"));
}

test "string escapes" {
    assertOrPanic(mem.eql(u8, "\"", "\x22"));
    assertOrPanic(mem.eql(u8, "\'", "\x27"));
    assertOrPanic(mem.eql(u8, "\n", "\x0a"));
    assertOrPanic(mem.eql(u8, "\r", "\x0d"));
    assertOrPanic(mem.eql(u8, "\t", "\x09"));
    assertOrPanic(mem.eql(u8, "\\", "\x5c"));
    assertOrPanic(mem.eql(u8, "\u1234\u0069", "\xe1\x88\xb4\x69"));
}

test "multiline string" {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    assertOrPanic(mem.eql(u8, s1, s2));
}

test "multiline C string" {
    const s1 =
        c\\one
        c\\two)
        c\\three
    ;
    const s2 = c"one\ntwo)\nthree";
    assertOrPanic(cstr.cmp(s1, s2) == 0);
}

test "type equality" {
    assertOrPanic(*const u8 != *u8);
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    assertOrPanic(d.* == 1234);
}

test "explicit cast maybe pointers" {
    const a: ?*i32 = undefined;
    const b: ?*f32 = @ptrCast(?*f32, a);
}

test "generic malloc free" {
    const a = memAlloc(u8, 10) catch unreachable;
    memFree(u8, a);
}
var some_mem: [100]u8 = undefined;
fn memAlloc(comptime T: type, n: usize) anyerror![]T {
    return @ptrCast([*]T, &some_mem[0])[0..n];
}
fn memFree(comptime T: type, memory: []T) void {}

test "cast undefined" {
    const array: [100]u8 = undefined;
    const slice = ([]const u8)(array);
    testCastUndefined(slice);
}
fn testCastUndefined(x: []const u8) void {}

test "cast small unsigned to larger signed" {
    assertOrPanic(castSmallUnsignedToLargerSigned1(200) == i16(200));
    assertOrPanic(castSmallUnsignedToLargerSigned2(9999) == i64(9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) i16 {
    return x;
}
fn castSmallUnsignedToLargerSigned2(x: u16) i64 {
    return x;
}

test "implicit cast after unreachable" {
    assertOrPanic(outer() == 1234);
}
fn inner() i32 {
    return 1234;
}
fn outer() i64 {
    return inner();
}

test "pointer dereferencing" {
    var x = i32(3);
    const y = &x;

    y.* += 1;

    assertOrPanic(x == 4);
    assertOrPanic(y.* == 4);
}

test "call result of if else expression" {
    assertOrPanic(mem.eql(u8, f2(true), "a"));
    assertOrPanic(mem.eql(u8, f2(false), "b"));
}
fn f2(x: bool) []const u8 {
    return (if (x) fA else fB)();
}
fn fA() []const u8 {
    return "a";
}
fn fB() []const u8 {
    return "b";
}

test "const expression eval handling of variables" {
    var x = true;
    while (x) {
        x = false;
    }
}

test "constant enum initialization with differing sizes" {
    test3_1(test3_foo);
    test3_2(test3_bar);
}
const Test3Foo = union(enum) {
    One: void,
    Two: f32,
    Three: Test3Point,
};
const Test3Point = struct {
    x: i32,
    y: i32,
};
const test3_foo = Test3Foo{
    .Three = Test3Point{
        .x = 3,
        .y = 4,
    },
};
const test3_bar = Test3Foo{ .Two = 13 };
fn test3_1(f: Test3Foo) void {
    switch (f) {
        Test3Foo.Three => |pt| {
            assertOrPanic(pt.x == 3);
            assertOrPanic(pt.y == 4);
        },
        else => unreachable,
    }
}
fn test3_2(f: Test3Foo) void {
    switch (f) {
        Test3Foo.Two => |x| {
            assertOrPanic(x == 13);
        },
        else => unreachable,
    }
}

test "character literals" {
    assertOrPanic('\'' == single_quote);
}
const single_quote = '\'';

test "take address of parameter" {
    testTakeAddressOfParameter(12.34);
}
fn testTakeAddressOfParameter(f: f32) void {
    const f_ptr = &f;
    assertOrPanic(f_ptr.* == 12.34);
}

test "pointer comparison" {
    const a = ([]const u8)("a");
    const b = &a;
    assertOrPanic(ptrEql(b, b));
}
fn ptrEql(a: *const []const u8, b: *const []const u8) bool {
    return a == b;
}

test "C string concatenation" {
    const a = c"OK" ++ c" IT " ++ c"WORKED";
    const b = c"OK IT WORKED";

    const len = cstr.len(b);
    const len_with_null = len + 1;
    {
        var i: u32 = 0;
        while (i < len_with_null) : (i += 1) {
            assertOrPanic(a[i] == b[i]);
        }
    }
    assertOrPanic(a[len] == 0);
    assertOrPanic(b[len] == 0);
}

test "cast slice to u8 slice" {
    assertOrPanic(@sizeOf(i32) == 4);
    var big_thing_array = []i32{ 1, 2, 3, 4 };
    const big_thing_slice: []i32 = big_thing_array[0..];
    const bytes = @sliceToBytes(big_thing_slice);
    assertOrPanic(bytes.len == 4 * 4);
    bytes[4] = 0;
    bytes[5] = 0;
    bytes[6] = 0;
    bytes[7] = 0;
    assertOrPanic(big_thing_slice[1] == 0);
    const big_thing_again = @bytesToSlice(i32, bytes);
    assertOrPanic(big_thing_again[2] == 3);
    big_thing_again[2] = -1;
    assertOrPanic(bytes[8] == maxInt(u8));
    assertOrPanic(bytes[9] == maxInt(u8));
    assertOrPanic(bytes[10] == maxInt(u8));
    assertOrPanic(bytes[11] == maxInt(u8));
}

test "pointer to void return type" {
    testPointerToVoidReturnType() catch unreachable;
}
fn testPointerToVoidReturnType() anyerror!void {
    const a = testPointerToVoidReturnType2();
    return a.*;
}
const test_pointer_to_void_return_type_x = void{};
fn testPointerToVoidReturnType2() *const void {
    return &test_pointer_to_void_return_type_x;
}

test "non const ptr to aliased type" {
    const int = i32;
    assertOrPanic(?*int == ?*i32);
}

test "array 2D const double ptr" {
    const rect_2d_vertexes = [][1]f32{
        []f32{1.0},
        []f32{2.0},
    };
    testArray2DConstDoublePtr(&rect_2d_vertexes[0][0]);
}

fn testArray2DConstDoublePtr(ptr: *const f32) void {
    const ptr2 = @ptrCast([*]const f32, ptr);
    assertOrPanic(ptr2[0] == 1.0);
    assertOrPanic(ptr2[1] == 2.0);
}

const Tid = builtin.TypeId;
const AStruct = struct {
    x: i32,
};
const AnEnum = enum {
    One,
    Two,
};
const AUnionEnum = union(enum) {
    One: i32,
    Two: void,
};
const AUnion = union {
    One: void,
    Two: void,
};

test "@typeId" {
    comptime {
        assertOrPanic(@typeId(type) == Tid.Type);
        assertOrPanic(@typeId(void) == Tid.Void);
        assertOrPanic(@typeId(bool) == Tid.Bool);
        assertOrPanic(@typeId(noreturn) == Tid.NoReturn);
        assertOrPanic(@typeId(i8) == Tid.Int);
        assertOrPanic(@typeId(u8) == Tid.Int);
        assertOrPanic(@typeId(i64) == Tid.Int);
        assertOrPanic(@typeId(u64) == Tid.Int);
        assertOrPanic(@typeId(f32) == Tid.Float);
        assertOrPanic(@typeId(f64) == Tid.Float);
        assertOrPanic(@typeId(*f32) == Tid.Pointer);
        assertOrPanic(@typeId([2]u8) == Tid.Array);
        assertOrPanic(@typeId(AStruct) == Tid.Struct);
        assertOrPanic(@typeId(@typeOf(1)) == Tid.ComptimeInt);
        assertOrPanic(@typeId(@typeOf(1.0)) == Tid.ComptimeFloat);
        assertOrPanic(@typeId(@typeOf(undefined)) == Tid.Undefined);
        assertOrPanic(@typeId(@typeOf(null)) == Tid.Null);
        assertOrPanic(@typeId(?i32) == Tid.Optional);
        assertOrPanic(@typeId(anyerror!i32) == Tid.ErrorUnion);
        assertOrPanic(@typeId(anyerror) == Tid.ErrorSet);
        assertOrPanic(@typeId(AnEnum) == Tid.Enum);
        assertOrPanic(@typeId(@typeOf(AUnionEnum.One)) == Tid.Enum);
        assertOrPanic(@typeId(AUnionEnum) == Tid.Union);
        assertOrPanic(@typeId(AUnion) == Tid.Union);
        assertOrPanic(@typeId(fn () void) == Tid.Fn);
        assertOrPanic(@typeId(@typeOf(builtin)) == Tid.Namespace);
        // TODO bound fn
        // TODO arg tuple
        // TODO opaque
    }
}

test "@typeName" {
    const Struct = struct {};
    const Union = union {
        unused: u8,
    };
    const Enum = enum {
        Unused,
    };
    comptime {
        assertOrPanic(mem.eql(u8, @typeName(i64), "i64"));
        assertOrPanic(mem.eql(u8, @typeName(*usize), "*usize"));
        // https://github.com/ziglang/zig/issues/675
        assertOrPanic(mem.eql(u8, @typeName(TypeFromFn(u8)), "TypeFromFn(u8)"));
        assertOrPanic(mem.eql(u8, @typeName(Struct), "Struct"));
        assertOrPanic(mem.eql(u8, @typeName(Union), "Union"));
        assertOrPanic(mem.eql(u8, @typeName(Enum), "Enum"));
    }
}

fn TypeFromFn(comptime T: type) type {
    return struct {};
}

test "double implicit cast in same expression" {
    var x = i32(u16(nine()));
    assertOrPanic(x == 9);
}
fn nine() u8 {
    return 9;
}

test "global variable initialized to global variable array element" {
    assertOrPanic(global_ptr == &gdt[0]);
}
const GDTEntry = struct {
    field: i32,
};
var gdt = []GDTEntry{
    GDTEntry{ .field = 1 },
    GDTEntry{ .field = 2 },
};
var global_ptr = &gdt[0];

// can't really run this test but we can make sure it has no compile error
// and generates code
const vram = @intToPtr([*]volatile u8, 0x20000000)[0..0x8000];
export fn writeToVRam() void {
    vram[0] = 'X';
}

const OpaqueA = @OpaqueType();
const OpaqueB = @OpaqueType();
test "@OpaqueType" {
    assertOrPanic(*OpaqueA != *OpaqueB);
    assertOrPanic(mem.eql(u8, @typeName(OpaqueA), "OpaqueA"));
    assertOrPanic(mem.eql(u8, @typeName(OpaqueB), "OpaqueB"));
}

test "variable is allowed to be a pointer to an opaque type" {
    var x: i32 = 1234;
    _ = hereIsAnOpaqueType(@ptrCast(*OpaqueA, &x));
}
fn hereIsAnOpaqueType(ptr: *OpaqueA) *OpaqueA {
    var a = ptr;
    return a;
}

test "comptime if inside runtime while which unconditionally breaks" {
    testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
    comptime testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(true);
}
fn testComptimeIfInsideRuntimeWhileWhichUnconditionallyBreaks(cond: bool) void {
    while (cond) {
        if (false) {}
        break;
    }
}

test "implicit comptime while" {
    while (false) {
        @compileError("bad");
    }
}

fn fnThatClosesOverLocalConst() type {
    const c = 1;
    return struct {
        fn g() i32 {
            return c;
        }
    };
}

test "function closes over local const" {
    const x = fnThatClosesOverLocalConst().g();
    assertOrPanic(x == 1);
}

test "cold function" {
    thisIsAColdFn();
    comptime thisIsAColdFn();
}

fn thisIsAColdFn() void {
    @setCold(true);
}

const PackedStruct = packed struct {
    a: u8,
    b: u8,
};
const PackedUnion = packed union {
    a: u8,
    b: u32,
};
const PackedEnum = packed enum {
    A,
    B,
};

test "packed struct, enum, union parameters in extern function" {
    testPackedStuff(&(PackedStruct{
        .a = 1,
        .b = 2,
    }), &(PackedUnion{ .a = 1 }), PackedEnum.A);
}

export fn testPackedStuff(a: *const PackedStruct, b: *const PackedUnion, c: PackedEnum) void {}

test "slicing zero length array" {
    const s1 = ""[0..];
    const s2 = ([]u32{})[0..];
    assertOrPanic(s1.len == 0);
    assertOrPanic(s2.len == 0);
    assertOrPanic(mem.eql(u8, s1, ""));
    assertOrPanic(mem.eql(u32, s2, []u32{}));
}

const addr1 = @ptrCast(*const u8, emptyFn);
test "comptime cast fn to ptr" {
    const addr2 = @ptrCast(*const u8, emptyFn);
    comptime assertOrPanic(addr1 == addr2);
}

test "equality compare fn ptrs" {
    var a = emptyFn;
    assertOrPanic(a == a);
}

test "self reference through fn ptr field" {
    const S = struct {
        const A = struct {
            f: fn (A) u8,
        };

        fn foo(a: A) u8 {
            return 12;
        }
    };
    var a: S.A = undefined;
    a.f = S.foo;
    assertOrPanic(a.f(a) == 12);
}

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = (*volatile i32)(&number);
    ptr.* += 1;
    assertOrPanic(ptr.* == 1235);
}

test "slice string literal has type []const u8" {
    comptime {
        assertOrPanic(@typeOf("aoeu"[0..]) == []const u8);
        const array = []i32{ 1, 2, 3, 4 };
        assertOrPanic(@typeOf(array[0..]) == []const i32);
    }
}

test "pointer child field" {
    assertOrPanic((*u32).Child == u32);
}

