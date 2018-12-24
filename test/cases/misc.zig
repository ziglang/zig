const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

test "cast slice to u8 slice" {
    assertOrPanic(@sizeOf(i32) == 4);
    var big_thing_array = []i32{
        1,
        2,
        3,
        4,
    };
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

test "volatile load and store" {
    var number: i32 = 1234;
    const ptr = (*volatile i32)(&number);
    ptr.* += 1;
    assertOrPanic(ptr.* == 1235);
}

test "slice string literal has type []const u8" {
    comptime {
        assertOrPanic(@typeOf("aoeu"[0..]) == []const u8);
        const array = []i32{
            1,
            2,
            3,
            4,
        };
        assertOrPanic(@typeOf(array[0..]) == []const i32);
    }
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

test "pointer child field" {
    assertOrPanic((*u32).Child == u32);
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

    assertOrPanic(block.kind == 1235);
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
