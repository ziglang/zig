const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const cstr = std.cstr;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

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
