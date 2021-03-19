const std = @import("std");
const expect = std.testing.expect;

extern fn run_c_tests() void;

export fn zig_panic() noreturn {
    @panic("zig_panic called from C");
}

test "C importing Zig ABI Tests" {
    run_c_tests();
}

extern fn c_u8(u8) void;
extern fn c_u16(u16) void;
extern fn c_u32(u32) void;
extern fn c_u64(u64) void;
extern fn c_i8(i8) void;
extern fn c_i16(i16) void;
extern fn c_i32(i32) void;
extern fn c_i64(i64) void;

// On windows x64, the first 4 are passed via registers, others on the stack.
extern fn c_five_integers(i32, i32, i32, i32, i32) void;

export fn zig_five_integers(a: i32, b: i32, c: i32, d: i32, e: i32) void {
    expect(a == 12);
    expect(b == 34);
    expect(c == 56);
    expect(d == 78);
    expect(e == 90);
}

test "C ABI integers" {
    c_u8(0xff);
    c_u16(0xfffe);
    c_u32(0xfffffffd);
    c_u64(0xfffffffffffffffc);

    c_i8(-1);
    c_i16(-2);
    c_i32(-3);
    c_i64(-4);
    c_five_integers(12, 34, 56, 78, 90);
}

export fn zig_u8(x: u8) void {
    expect(x == 0xff);
}
export fn zig_u16(x: u16) void {
    expect(x == 0xfffe);
}
export fn zig_u32(x: u32) void {
    expect(x == 0xfffffffd);
}
export fn zig_u64(x: u64) void {
    expect(x == 0xfffffffffffffffc);
}
export fn zig_i8(x: i8) void {
    expect(x == -1);
}
export fn zig_i16(x: i16) void {
    expect(x == -2);
}
export fn zig_i32(x: i32) void {
    expect(x == -3);
}
export fn zig_i64(x: i64) void {
    expect(x == -4);
}

extern fn c_f32(f32) void;
extern fn c_f64(f64) void;

// On windows x64, the first 4 are passed via registers, others on the stack.
extern fn c_five_floats(f32, f32, f32, f32, f32) void;

export fn zig_five_floats(a: f32, b: f32, c: f32, d: f32, e: f32) void {
    expect(a == 1.0);
    expect(b == 2.0);
    expect(c == 3.0);
    expect(d == 4.0);
    expect(e == 5.0);
}

test "C ABI floats" {
    c_f32(12.34);
    c_f64(56.78);
    c_five_floats(1.0, 2.0, 3.0, 4.0, 5.0);
}

export fn zig_f32(x: f32) void {
    expect(x == 12.34);
}
export fn zig_f64(x: f64) void {
    expect(x == 56.78);
}

extern fn c_ptr(*c_void) void;

test "C ABI pointer" {
    c_ptr(@intToPtr(*c_void, 0xdeadbeef));
}

export fn zig_ptr(x: *c_void) void {
    expect(@ptrToInt(x) == 0xdeadbeef);
}

extern fn c_bool(bool) void;

test "C ABI bool" {
    c_bool(true);
}

export fn zig_bool(x: bool) void {
    expect(x);
}

const BigStruct = extern struct {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
    e: u8,
};
extern fn c_big_struct(BigStruct) void;

test "C ABI big struct" {
    var s = BigStruct{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
        .e = 5,
    };
    c_big_struct(s);
}

export fn zig_big_struct(x: BigStruct) void {
    expect(x.a == 1);
    expect(x.b == 2);
    expect(x.c == 3);
    expect(x.d == 4);
    expect(x.e == 5);
}

const BigUnion = extern union {
    a: BigStruct,
};
extern fn c_big_union(BigUnion) void;

test "C ABI big union" {
    var x = BigUnion{
        .a = BigStruct{
            .a = 1,
            .b = 2,
            .c = 3,
            .d = 4,
            .e = 5,
        },
    };
    c_big_union(x);
}

export fn zig_big_union(x: BigUnion) void {
    expect(x.a.a == 1);
    expect(x.a.b == 2);
    expect(x.a.c == 3);
    expect(x.a.d == 4);
    expect(x.a.e == 5);
}

const SmallStructInts = extern struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
};
extern fn c_small_struct_ints(SmallStructInts) void;

test "C ABI small struct of ints" {
    var s = SmallStructInts{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
    c_small_struct_ints(s);
}

export fn zig_small_struct_ints(x: SmallStructInts) void {
    expect(x.a == 1);
    expect(x.b == 2);
    expect(x.c == 3);
    expect(x.d == 4);
}

const SplitStructInt = extern struct {
    a: u64,
    b: u8,
    c: u32,
};
extern fn c_split_struct_ints(SplitStructInt) void;

test "C ABI split struct of ints" {
    var s = SplitStructInt{
        .a = 1234,
        .b = 100,
        .c = 1337,
    };
    c_split_struct_ints(s);
}

export fn zig_split_struct_ints(x: SplitStructInt) void {
    expect(x.a == 1234);
    expect(x.b == 100);
    expect(x.c == 1337);
}

extern fn c_big_struct_both(BigStruct) BigStruct;

test "C ABI sret and byval together" {
    var s = BigStruct{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
        .e = 5,
    };
    var y = c_big_struct_both(s);
    expect(y.a == 10);
    expect(y.b == 11);
    expect(y.c == 12);
    expect(y.d == 13);
    expect(y.e == 14);
}

export fn zig_big_struct_both(x: BigStruct) BigStruct {
    expect(x.a == 30);
    expect(x.b == 31);
    expect(x.c == 32);
    expect(x.d == 33);
    expect(x.e == 34);
    var s = BigStruct{
        .a = 20,
        .b = 21,
        .c = 22,
        .d = 23,
        .e = 24,
    };
    return s;
}

const Vector3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};
extern fn c_small_struct_floats(Vector3) void;

const Vector5 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
    q: f32,
};
extern fn c_big_struct_floats(Vector5) void;

test "C ABI structs of floats as parameter" {
    var v3 = Vector3{
        .x = 3.0,
        .y = 6.0,
        .z = 12.0,
    };
    c_small_struct_floats(v3);

    var v5 = Vector5{
        .x = 76.0,
        .y = -1.0,
        .z = -12.0,
        .w = 69.0,
        .q = 55,
    };
    c_big_struct_floats(v5);
}

export fn zig_ret_bool() bool {
    return true;
}
export fn zig_ret_u8() u8 {
    return 0xff;
}
export fn zig_ret_u16() u16 {
    return 0xffff;
}
export fn zig_ret_u32() u32 {
    return 0xffffffff;
}
export fn zig_ret_u64() u64 {
    return 0xffffffffffffffff;
}
export fn zig_ret_i8() i8 {
    return -1;
}
export fn zig_ret_i16() i16 {
    return -1;
}
export fn zig_ret_i32() i32 {
    return -1;
}
export fn zig_ret_i64() i64 {
    return -1;
}

extern fn c_ret_bool() bool;
extern fn c_ret_u8() u8;
extern fn c_ret_u16() u16;
extern fn c_ret_u32() u32;
extern fn c_ret_u64() u64;
extern fn c_ret_i8() i8;
extern fn c_ret_i16() i16;
extern fn c_ret_i32() i32;
extern fn c_ret_i64() i64;

test "C ABI integer return types" {
    expect(c_ret_bool() == true);

    expect(c_ret_u8() == 0xff);
    expect(c_ret_u16() == 0xffff);
    expect(c_ret_u32() == 0xffffffff);
    expect(c_ret_u64() == 0xffffffffffffffff);

    expect(c_ret_i8() == -1);
    expect(c_ret_i16() == -1);
    expect(c_ret_i32() == -1);
    expect(c_ret_i64() == -1);
}
