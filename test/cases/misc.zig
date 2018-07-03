const assert = @import("std").debug.assert;
const mem = @import("std").mem;
const cstr = @import("std").cstr;
const builtin = @import("builtin");

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
    assert(@IntType(true, 8) == i8);
    assert(@IntType(true, 16) == i16);
    assert(@IntType(true, 32) == i32);
    assert(@IntType(true, 64) == i64);

    assert(@IntType(false, 8) == u8);
    assert(@IntType(false, 16) == u16);
    assert(@IntType(false, 32) == u32);
    assert(@IntType(false, 64) == u64);

    assert(i8.bit_count == 8);
    assert(i16.bit_count == 16);
    assert(i32.bit_count == 32);
    assert(i64.bit_count == 64);

    assert(i8.is_signed);
    assert(i16.is_signed);
    assert(i32.is_signed);
    assert(i64.is_signed);
    assert(isize.is_signed);

    assert(!u8.is_signed);
    assert(!u16.is_signed);
    assert(!u32.is_signed);
    assert(!u64.is_signed);
    assert(!usize.is_signed);
}

test "floating point primitive bit counts" {
    assert(f16.bit_count == 16);
    assert(f32.bit_count == 32);
    assert(f64.bit_count == 64);
}

const u1 = @IntType(false, 1);
const u63 = @IntType(false, 63);
const i1 = @IntType(true, 1);
const i63 = @IntType(true, 63);

test "@minValue and @maxValue" {
    assert(@maxValue(u1) == 1);
    assert(@maxValue(u8) == 255);
    assert(@maxValue(u16) == 65535);
    assert(@maxValue(u32) == 4294967295);
    assert(@maxValue(u64) == 18446744073709551615);

    assert(@maxValue(i1) == 0);
    assert(@maxValue(i8) == 127);
    assert(@maxValue(i16) == 32767);
    assert(@maxValue(i32) == 2147483647);
    assert(@maxValue(i63) == 4611686018427387903);
    assert(@maxValue(i64) == 9223372036854775807);

    assert(@minValue(u1) == 0);
    assert(@minValue(u8) == 0);
    assert(@minValue(u16) == 0);
    assert(@minValue(u32) == 0);
    assert(@minValue(u63) == 0);
    assert(@minValue(u64) == 0);

    assert(@minValue(i1) == -1);
    assert(@minValue(i8) == -128);
    assert(@minValue(i16) == -32768);
    assert(@minValue(i32) == -2147483648);
    assert(@minValue(i63) == -4611686018427387904);
    assert(@minValue(i64) == -9223372036854775808);
}

test "max value type" {
    // If the type of @maxValue(i32) was i32 then this implicit cast to
    // u32 would not work. But since the value is a number literal,
    // it works fine.
    const x: u32 = @maxValue(i32);
    assert(x == 2147483647);
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
        assert(f);
        break :x f;
    }) {
        hit_1 = t;
    }
    if (f or x: {
        hit_2 = t;
        break :x f;
    }) {
        assert(f);
    }

    if (t and x: {
        hit_3 = t;
        break :x f;
    }) {
        assert(f);
    }
    if (f and x: {
        assert(f);
        break :x f;
    }) {
        assert(f);
    } else {
        hit_4 = t;
    }
    assert(hit_1);
    assert(hit_2);
    assert(hit_3);
    assert(hit_4);
}

test "truncate" {
    assert(testTruncate(0x10fd) == 0xfd);
}
fn testTruncate(x: u32) u8 {
    return @truncate(u8, x);
}

fn first4KeysOfHomeRow() []const u8 {
    return "aoeu";
}

test "return string from function" {
    assert(mem.eql(u8, first4KeysOfHomeRow(), "aoeu"));
}

const g1: i32 = 1233 + 1;
var g2: i32 = 0;

test "global variables" {
    assert(g2 == 0);
    g2 = g1;
    assert(g2 == 1234);
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
    assert(x == comptime 6);
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
    assert(comptime x: {
        break :x emptyFn == alias;
    });
}

fn emptyFn() void {}

test "hex escape" {
    assert(mem.eql(u8, "\x68\x65\x6c\x6c\x6f", "hello"));
}

test "string concatenation" {
    assert(mem.eql(u8, "OK" ++ " IT " ++ "WORKED", "OK IT WORKED"));
}

test "array mult operator" {
    assert(mem.eql(u8, "ab" ** 5, "ababababab"));
}

test "string escapes" {
    assert(mem.eql(u8, "\"", "\x22"));
    assert(mem.eql(u8, "\'", "\x27"));
    assert(mem.eql(u8, "\n", "\x0a"));
    assert(mem.eql(u8, "\r", "\x0d"));
    assert(mem.eql(u8, "\t", "\x09"));
    assert(mem.eql(u8, "\\", "\x5c"));
    assert(mem.eql(u8, "\u1234\u0069", "\xe1\x88\xb4\x69"));
}

test "multiline string" {
    const s1 =
        \\one
        \\two)
        \\three
    ;
    const s2 = "one\ntwo)\nthree";
    assert(mem.eql(u8, s1, s2));
}

test "multiline C string" {
    const s1 =
        c\\one
        c\\two)
        c\\three
    ;
    const s2 = c"one\ntwo)\nthree";
    assert(cstr.cmp(s1, s2) == 0);
}

test "type equality" {
    assert(*const u8 != *u8);
}

const global_a: i32 = 1234;
const global_b: *const i32 = &global_a;
const global_c: *const f32 = @ptrCast(*const f32, global_b);
test "compile time global reinterpret" {
    const d = @ptrCast(*const i32, global_c);
    assert(d.* == 1234);
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
fn memAlloc(comptime T: type, n: usize) error![]T {
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
    assert(castSmallUnsignedToLargerSigned1(200) == i16(200));
    assert(castSmallUnsignedToLargerSigned2(9999) == i64(9999));
}
fn castSmallUnsignedToLargerSigned1(x: u8) i16 {
    return x;
}
fn castSmallUnsignedToLargerSigned2(x: u16) i64 {
    return x;
}

test "implicit cast after unreachable" {
    assert(outer() == 1234);
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

    assert(x == 4);
    assert(y.* == 4);
}

test "call result of if else expression" {
    assert(mem.eql(u8, f2(true), "a"));
    assert(mem.eql(u8, f2(false), "b"));
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
fn test3_1(f: *const Test3Foo) void {
    switch (f.*) {
        Test3Foo.Three => |pt| {
            assert(pt.x == 3);
            assert(pt.y == 4);
        },
        else => unreachable,
    }
}
fn test3_2(f: *const Test3Foo) void {
    switch (f.*) {
        Test3Foo.Two => |x| {
            assert(x == 13);
        },
        else => unreachable,
    }
}

test "character literals" {
    assert('\'' == single_quote);
}
const single_quote = '\'';

test "take address of parameter" {
    testTakeAddressOfParameter(12.34);
}
fn testTakeAddressOfParameter(f: f32) void {
    const f_ptr = &f;
    assert(f_ptr.* == 12.34);
}

test "pointer comparison" {
    const a = ([]const u8)("a");
    const b = &a;
    assert(ptrEql(b, b));
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
            assert(a[i] == b[i]);
        }
    }
    assert(a[len] == 0);
    assert(b[len] == 0);
}

test "cast slice to u8 slice" {
    assert(@sizeOf(i32) == 4);
    var big_thing_array = []i32{
        1,
        2,
        3,
        4,
    };
    const big_thing_slice: []i32 = big_thing_array[0..];
    const bytes = @sliceToBytes(big_thing_slice);
    assert(bytes.len == 4 * 4);
    bytes[4] = 0;
    bytes[5] = 0;
    bytes[6] = 0;
    bytes[7] = 0;
    assert(big_thing_slice[1] == 0);
    const big_thing_again = @bytesToSlice(i32, bytes);
    assert(big_thing_again[2] == 3);
    big_thing_again[2] = -1;
    assert(bytes[8] == @maxValue(u8));
    assert(bytes[9] == @maxValue(u8));
    assert(bytes[10] == @maxValue(u8));
    assert(bytes[11] == @maxValue(u8));
}

test "pointer to void return type" {
    testPointerToVoidReturnType() catch unreachable;
}
fn testPointerToVoidReturnType() error!void {
    const a = testPointerToVoidReturnType2();
    return a.*;
}
const test_pointer_to_void_return_type_x = void{};
fn testPointerToVoidReturnType2() *const void {
    return &test_pointer_to_void_return_type_x;
}

test "non const ptr to aliased type" {
    const int = i32;
    assert(?*int == ?*i32);
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
    assert(ptr2[0] == 1.0);
    assert(ptr2[1] == 2.0);
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
        assert(@typeId(type) == Tid.Type);
        assert(@typeId(void) == Tid.Void);
        assert(@typeId(bool) == Tid.Bool);
        assert(@typeId(noreturn) == Tid.NoReturn);
        assert(@typeId(i8) == Tid.Int);
        assert(@typeId(u8) == Tid.Int);
        assert(@typeId(i64) == Tid.Int);
        assert(@typeId(u64) == Tid.Int);
        assert(@typeId(f32) == Tid.Float);
        assert(@typeId(f64) == Tid.Float);
        assert(@typeId(*f32) == Tid.Pointer);
        assert(@typeId([2]u8) == Tid.Array);
        assert(@typeId(AStruct) == Tid.Struct);
        assert(@typeId(@typeOf(1)) == Tid.ComptimeInt);
        assert(@typeId(@typeOf(1.0)) == Tid.ComptimeFloat);
        assert(@typeId(@typeOf(undefined)) == Tid.Undefined);
        assert(@typeId(@typeOf(null)) == Tid.Null);
        assert(@typeId(?i32) == Tid.Optional);
        assert(@typeId(error!i32) == Tid.ErrorUnion);
        assert(@typeId(error) == Tid.ErrorSet);
        assert(@typeId(AnEnum) == Tid.Enum);
        assert(@typeId(@typeOf(AUnionEnum.One)) == Tid.Enum);
        assert(@typeId(AUnionEnum) == Tid.Union);
        assert(@typeId(AUnion) == Tid.Union);
        assert(@typeId(fn () void) == Tid.Fn);
        assert(@typeId(@typeOf(builtin)) == Tid.Namespace);
        assert(@typeId(@typeOf(x: {
            break :x this;
        })) == Tid.Block);
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
        assert(mem.eql(u8, @typeName(i64), "i64"));
        assert(mem.eql(u8, @typeName(*usize), "*usize"));
        // https://github.com/ziglang/zig/issues/675
        assert(mem.eql(u8, @typeName(TypeFromFn(u8)), "TypeFromFn(u8)"));
        assert(mem.eql(u8, @typeName(Struct), "Struct"));
        assert(mem.eql(u8, @typeName(Union), "Union"));
        assert(mem.eql(u8, @typeName(Enum), "Enum"));
    }
}

fn TypeFromFn(comptime T: type) type {
    return struct {};
}

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = (*volatile i32)(&number);
    ptr.* += 1;
    assert(ptr.* == 1235);
}

test "slice string literal has type []const u8" {
    comptime {
        assert(@typeOf("aoeu"[0..]) == []const u8);
        const array = []i32{
            1,
            2,
            3,
            4,
        };
        assert(@typeOf(array[0..]) == []const i32);
    }
}

test "global variable initialized to global variable array element" {
    assert(global_ptr == &gdt[0]);
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

test "pointer child field" {
    assert((*u32).Child == u32);
}

const OpaqueA = @OpaqueType();
const OpaqueB = @OpaqueType();
test "@OpaqueType" {
    assert(*OpaqueA != *OpaqueB);
    assert(mem.eql(u8, @typeName(OpaqueA), "OpaqueA"));
    assert(mem.eql(u8, @typeName(OpaqueB), "OpaqueB"));
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

test "struct inside function" {
    testStructInFn();
    comptime testStructInFn();
}

fn testStructInFn() void {
    const BlockKind = u32;

    const Block = struct {
        kind: BlockKind,
    };

    var block = Block{ .kind = 1234 };

    block.kind += 1;

    assert(block.kind == 1235);
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
    assert(x == 1);
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
    testPackedStuff(PackedStruct{
        .a = 1,
        .b = 2,
    }, PackedUnion{ .a = 1 }, PackedEnum.A);
}

export fn testPackedStuff(a: *const PackedStruct, b: *const PackedUnion, c: PackedEnum) void {}

test "slicing zero length array" {
    const s1 = ""[0..];
    const s2 = ([]u32{})[0..];
    assert(s1.len == 0);
    assert(s2.len == 0);
    assert(mem.eql(u8, s1, ""));
    assert(mem.eql(u32, s2, []u32{}));
}

const addr1 = @ptrCast(*const u8, emptyFn);
test "comptime cast fn to ptr" {
    const addr2 = @ptrCast(*const u8, emptyFn);
    comptime assert(addr1 == addr2);
}

test "equality compare fn ptrs" {
    var a = emptyFn;
    assert(a == a);
}
