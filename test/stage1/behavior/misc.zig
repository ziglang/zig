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

