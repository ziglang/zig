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

