const std = @import("std");
const builtin = @import("builtin");
const print = std.debug.print;
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
extern fn c_struct_u128(U128) void;
extern fn c_i8(i8) void;
extern fn c_i16(i16) void;
extern fn c_i32(i32) void;
extern fn c_i64(i64) void;
extern fn c_struct_i128(I128) void;

// On windows x64, the first 4 are passed via registers, others on the stack.
extern fn c_five_integers(i32, i32, i32, i32, i32) void;

export fn zig_five_integers(a: i32, b: i32, c: i32, d: i32, e: i32) void {
    expect(a == 12) catch @panic("test failure: zig_five_integers 12");
    expect(b == 34) catch @panic("test failure: zig_five_integers 34");
    expect(c == 56) catch @panic("test failure: zig_five_integers 56");
    expect(d == 78) catch @panic("test failure: zig_five_integers 78");
    expect(e == 90) catch @panic("test failure: zig_five_integers 90");
}

test "C ABI integers" {
    c_u8(0xff);
    c_u16(0xfffe);
    c_u32(0xfffffffd);
    c_u64(0xfffffffffffffffc);
    c_struct_u128(.{ .value = 0xfffffffffffffffc });

    c_i8(-1);
    c_i16(-2);
    c_i32(-3);
    c_i64(-4);
    c_struct_i128(.{ .value = -6 });
    c_five_integers(12, 34, 56, 78, 90);
}

export fn zig_u8(x: u8) void {
    expect(x == 0xff) catch @panic("test failure: zig_u8");
}
export fn zig_u16(x: u16) void {
    expect(x == 0xfffe) catch @panic("test failure: zig_u16");
}
export fn zig_u32(x: u32) void {
    expect(x == 0xfffffffd) catch @panic("test failure: zig_u32");
}
export fn zig_u64(x: u64) void {
    expect(x == 0xfffffffffffffffc) catch @panic("test failure: zig_u64");
}
export fn zig_i8(x: i8) void {
    expect(x == -1) catch @panic("test failure: zig_i8");
}
export fn zig_i16(x: i16) void {
    expect(x == -2) catch @panic("test failure: zig_i16");
}
export fn zig_i32(x: i32) void {
    expect(x == -3) catch @panic("test failure: zig_i32");
}
export fn zig_i64(x: i64) void {
    expect(x == -4) catch @panic("test failure: zig_i64");
}

const I128 = extern struct {
    value: i128,
};
const U128 = extern struct {
    value: u128,
};
export fn zig_struct_i128(a: I128) void {
    expect(a.value == -6) catch @panic("test failure: zig_struct_i128");
}
export fn zig_struct_u128(a: U128) void {
    expect(a.value == 0xfffffffffffffffc) catch @panic("test failure: zig_struct_u128");
}

extern fn c_f32(f32) void;
extern fn c_f64(f64) void;
extern fn c_long_double(c_longdouble) void;

// On windows x64, the first 4 are passed via registers, others on the stack.
extern fn c_five_floats(f32, f32, f32, f32, f32) void;

export fn zig_five_floats(a: f32, b: f32, c: f32, d: f32, e: f32) void {
    expect(a == 1.0) catch @panic("test failure: zig_five_floats 1.0");
    expect(b == 2.0) catch @panic("test failure: zig_five_floats 2.0");
    expect(c == 3.0) catch @panic("test failure: zig_five_floats 3.0");
    expect(d == 4.0) catch @panic("test failure: zig_five_floats 4.0");
    expect(e == 5.0) catch @panic("test failure: zig_five_floats 5.0");
}

test "C ABI floats" {
    c_f32(12.34);
    c_f64(56.78);
    c_five_floats(1.0, 2.0, 3.0, 4.0, 5.0);
}

test "C ABI long double" {
    if (!builtin.cpu.arch.isWasm() and !builtin.cpu.arch.isAARCH64()) return error.SkipZigTest;
    c_long_double(12.34);
}

export fn zig_f32(x: f32) void {
    expect(x == 12.34) catch @panic("test failure: zig_f32");
}
export fn zig_f64(x: f64) void {
    expect(x == 56.78) catch @panic("test failure: zig_f64");
}
export fn zig_longdouble(x: c_longdouble) void {
    if (!builtin.cpu.arch.isWasm()) return; // waiting for #1481
    expect(x == 12.34) catch @panic("test failure: zig_longdouble");
}

extern fn c_ptr(*anyopaque) void;

test "C ABI pointer" {
    c_ptr(@intToPtr(*anyopaque, 0xdeadbeef));
}

export fn zig_ptr(x: *anyopaque) void {
    expect(@ptrToInt(x) == 0xdeadbeef) catch @panic("test failure: zig_ptr");
}

extern fn c_bool(bool) void;

test "C ABI bool" {
    c_bool(true);
}

export fn zig_bool(x: bool) void {
    expect(x) catch @panic("test failure: zig_bool");
}

// TODO: Replace these with the correct types once we resolve
//       https://github.com/ziglang/zig/issues/8465
//
// For now, we have no way of referring to the _Complex C types from Zig,
// so our ABI is unavoidably broken on some platforms (such as i386)
const ComplexFloat = extern struct {
    real: f32,
    imag: f32,
};
const ComplexDouble = extern struct {
    real: f64,
    imag: f64,
};

// Note: These two functions match the signature of __mulsc3 and __muldc3 in compiler-rt (and libgcc)
extern fn c_cmultf_comp(a_r: f32, a_i: f32, b_r: f32, b_i: f32) ComplexFloat;
extern fn c_cmultd_comp(a_r: f64, a_i: f64, b_r: f64, b_i: f64) ComplexDouble;

extern fn c_cmultf(a: ComplexFloat, b: ComplexFloat) ComplexFloat;
extern fn c_cmultd(a: ComplexDouble, b: ComplexDouble) ComplexDouble;

test "C ABI complex float" {
    if (true) return error.SkipZigTest; // See https://github.com/ziglang/zig/issues/8465

    const a = ComplexFloat{ .real = 1.25, .imag = 2.6 };
    const b = ComplexFloat{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultf(a, b);
    expect(z.real == 1.5) catch @panic("test failure: zig_complex_float 1");
    expect(z.imag == 13.5) catch @panic("test failure: zig_complex_float 2");
}

test "C ABI complex float by component" {
    const a = ComplexFloat{ .real = 1.25, .imag = 2.6 };
    const b = ComplexFloat{ .real = 11.3, .imag = -1.5 };

    const z2 = c_cmultf_comp(a.real, a.imag, b.real, b.imag);
    expect(z2.real == 1.5) catch @panic("test failure: zig_complex_float 3");
    expect(z2.imag == 13.5) catch @panic("test failure: zig_complex_float 4");
}

test "C ABI complex double" {
    const a = ComplexDouble{ .real = 1.25, .imag = 2.6 };
    const b = ComplexDouble{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultd(a, b);
    expect(z.real == 1.5) catch @panic("test failure: zig_complex_double 1");
    expect(z.imag == 13.5) catch @panic("test failure: zig_complex_double 2");
}

test "C ABI complex double by component" {
    const a = ComplexDouble{ .real = 1.25, .imag = 2.6 };
    const b = ComplexDouble{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultd_comp(a.real, a.imag, b.real, b.imag);
    expect(z.real == 1.5) catch @panic("test failure: zig_complex_double 3");
    expect(z.imag == 13.5) catch @panic("test failure: zig_complex_double 4");
}

export fn zig_cmultf(a: ComplexFloat, b: ComplexFloat) ComplexFloat {
    expect(a.real == 1.25) catch @panic("test failure: zig_cmultf 1");
    expect(a.imag == 2.6) catch @panic("test failure: zig_cmultf 2");
    expect(b.real == 11.3) catch @panic("test failure: zig_cmultf 3");
    expect(b.imag == -1.5) catch @panic("test failure: zig_cmultf 4");

    return .{ .real = 1.5, .imag = 13.5 };
}

export fn zig_cmultd(a: ComplexDouble, b: ComplexDouble) ComplexDouble {
    expect(a.real == 1.25) catch @panic("test failure: zig_cmultd 1");
    expect(a.imag == 2.6) catch @panic("test failure: zig_cmultd 2");
    expect(b.real == 11.3) catch @panic("test failure: zig_cmultd 3");
    expect(b.imag == -1.5) catch @panic("test failure: zig_cmultd 4");

    return .{ .real = 1.5, .imag = 13.5 };
}

export fn zig_cmultf_comp(a_r: f32, a_i: f32, b_r: f32, b_i: f32) ComplexFloat {
    expect(a_r == 1.25) catch @panic("test failure: zig_cmultf_comp 1");
    expect(a_i == 2.6) catch @panic("test failure: zig_cmultf_comp 2");
    expect(b_r == 11.3) catch @panic("test failure: zig_cmultf_comp 3");
    expect(b_i == -1.5) catch @panic("test failure: zig_cmultf_comp 4");

    return .{ .real = 1.5, .imag = 13.5 };
}

export fn zig_cmultd_comp(a_r: f64, a_i: f64, b_r: f64, b_i: f64) ComplexDouble {
    expect(a_r == 1.25) catch @panic("test failure: zig_cmultd_comp 1");
    expect(a_i == 2.6) catch @panic("test failure: zig_cmultd_comp 2");
    expect(b_r == 11.3) catch @panic("test failure: zig_cmultd_comp 3");
    expect(b_i == -1.5) catch @panic("test failure: zig_cmultd_comp 4");

    return .{ .real = 1.5, .imag = 13.5 };
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
    expect(x.a == 1) catch @panic("test failure: zig_big_struct 1");
    expect(x.b == 2) catch @panic("test failure: zig_big_struct 2");
    expect(x.c == 3) catch @panic("test failure: zig_big_struct 3");
    expect(x.d == 4) catch @panic("test failure: zig_big_struct 4");
    expect(x.e == 5) catch @panic("test failure: zig_big_struct 5");
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
    expect(x.a.a == 1) catch @panic("test failure: zig_big_union a");
    expect(x.a.b == 2) catch @panic("test failure: zig_big_union b");
    expect(x.a.c == 3) catch @panic("test failure: zig_big_union c");
    expect(x.a.d == 4) catch @panic("test failure: zig_big_union d");
    expect(x.a.e == 5) catch @panic("test failure: zig_big_union e");
}

const MedStructMixed = extern struct {
    a: u32,
    b: f32,
    c: f32,
    d: u32 = 0,
};
extern fn c_med_struct_mixed(MedStructMixed) void;
extern fn c_ret_med_struct_mixed() MedStructMixed;

test "C ABI medium struct of ints and floats" {
    var s = MedStructMixed{
        .a = 1234,
        .b = 100.0,
        .c = 1337.0,
    };
    c_med_struct_mixed(s);
    var s2 = c_ret_med_struct_mixed();
    expect(s2.a == 1234) catch @panic("test failure");
    expect(s2.b == 100.0) catch @panic("test failure");
    expect(s2.c == 1337.0) catch @panic("test failure");
}

export fn zig_med_struct_mixed(x: MedStructMixed) void {
    expect(x.a == 1234) catch @panic("test failure");
    expect(x.b == 100.0) catch @panic("test failure");
    expect(x.c == 1337.0) catch @panic("test failure");
}

const SmallStructInts = extern struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
};
extern fn c_small_struct_ints(SmallStructInts) void;
extern fn c_ret_small_struct_ints() SmallStructInts;

test "C ABI small struct of ints" {
    var s = SmallStructInts{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
    c_small_struct_ints(s);
    var s2 = c_ret_small_struct_ints();
    expect(s2.a == 1) catch @panic("test failure");
    expect(s2.b == 2) catch @panic("test failure");
    expect(s2.c == 3) catch @panic("test failure");
    expect(s2.d == 4) catch @panic("test failure");
}

export fn zig_small_struct_ints(x: SmallStructInts) void {
    expect(x.a == 1) catch @panic("test failure");
    expect(x.b == 2) catch @panic("test failure");
    expect(x.c == 3) catch @panic("test failure");
    expect(x.d == 4) catch @panic("test failure");
}

const SmallPackedStruct = packed struct {
    a: u2,
    b: u2,
    c: u2,
    d: u2,
};
extern fn c_small_packed_struct(SmallPackedStruct) void;
extern fn c_ret_small_packed_struct() SmallPackedStruct;

export fn zig_small_packed_struct(x: SmallPackedStruct) void {
    expect(x.a == 0) catch @panic("test failure");
    expect(x.b == 1) catch @panic("test failure");
    expect(x.c == 2) catch @panic("test failure");
    expect(x.d == 3) catch @panic("test failure");
}

test "C ABI small packed struct" {
    var s = SmallPackedStruct{ .a = 0, .b = 1, .c = 2, .d = 3 };
    c_small_packed_struct(s);
    var s2 = c_ret_small_packed_struct();
    try expect(s2.a == 0);
    try expect(s2.b == 1);
    try expect(s2.c == 2);
    try expect(s2.d == 3);
}

const BigPackedStruct = packed struct {
    a: u64,
    b: u64,
};
extern fn c_big_packed_struct(BigPackedStruct) void;
extern fn c_ret_big_packed_struct() BigPackedStruct;

export fn zig_big_packed_struct(x: BigPackedStruct) void {
    expect(x.a == 1) catch @panic("test failure");
    expect(x.b == 2) catch @panic("test failure");
}

test "C ABI big packed struct" {
    var s = BigPackedStruct{ .a = 1, .b = 2 };
    c_big_packed_struct(s);
    var s2 = c_ret_big_packed_struct();
    try expect(s2.a == 1);
    try expect(s2.b == 2);
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
    expect(x.a == 1234) catch @panic("test failure");
    expect(x.b == 100) catch @panic("test failure");
    expect(x.c == 1337) catch @panic("test failure");
}

const SplitStructMixed = extern struct {
    a: u64,
    b: u8,
    c: f32,
};
extern fn c_split_struct_mixed(SplitStructMixed) void;
extern fn c_ret_split_struct_mixed() SplitStructMixed;

test "C ABI split struct of ints and floats" {
    var s = SplitStructMixed{
        .a = 1234,
        .b = 100,
        .c = 1337.0,
    };
    c_split_struct_mixed(s);
    var s2 = c_ret_split_struct_mixed();
    expect(s2.a == 1234) catch @panic("test failure");
    expect(s2.b == 100) catch @panic("test failure");
    expect(s2.c == 1337.0) catch @panic("test failure");
}

export fn zig_split_struct_mixed(x: SplitStructMixed) void {
    expect(x.a == 1234) catch @panic("test failure");
    expect(x.b == 100) catch @panic("test failure");
    expect(x.c == 1337.0) catch @panic("test failure");
}

extern fn c_big_struct_both(BigStruct) BigStruct;

extern fn c_multiple_struct_ints(Rect, Rect) void;
extern fn c_multiple_struct_floats(FloatRect, FloatRect) void;

test "C ABI sret and byval together" {
    var s = BigStruct{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
        .e = 5,
    };
    var y = c_big_struct_both(s);
    try expect(y.a == 10);
    try expect(y.b == 11);
    try expect(y.c == 12);
    try expect(y.d == 13);
    try expect(y.e == 14);
}

export fn zig_big_struct_both(x: BigStruct) BigStruct {
    expect(x.a == 30) catch @panic("test failure");
    expect(x.b == 31) catch @panic("test failure");
    expect(x.c == 32) catch @panic("test failure");
    expect(x.d == 33) catch @panic("test failure");
    expect(x.e == 34) catch @panic("test failure");
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
extern fn c_small_struct_floats_extra(Vector3, ?[*]const u8) void;

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
    c_small_struct_floats_extra(v3, "hello");

    var v5 = Vector5{
        .x = 76.0,
        .y = -1.0,
        .z = -12.0,
        .w = 69.0,
        .q = 55,
    };
    c_big_struct_floats(v5);
}

const Rect = extern struct {
    left: u32,
    right: u32,
    top: u32,
    bottom: u32,
};

export fn zig_multiple_struct_ints(x: Rect, y: Rect) void {
    expect(x.left == 1) catch @panic("test failure");
    expect(x.right == 21) catch @panic("test failure");
    expect(x.top == 16) catch @panic("test failure");
    expect(x.bottom == 4) catch @panic("test failure");
    expect(y.left == 178) catch @panic("test failure");
    expect(y.right == 189) catch @panic("test failure");
    expect(y.top == 21) catch @panic("test failure");
    expect(y.bottom == 15) catch @panic("test failure");
}

test "C ABI structs of ints as multiple parameters" {
    var r1 = Rect{
        .left = 1,
        .right = 21,
        .top = 16,
        .bottom = 4,
    };
    var r2 = Rect{
        .left = 178,
        .right = 189,
        .top = 21,
        .bottom = 15,
    };
    c_multiple_struct_ints(r1, r2);
}

const FloatRect = extern struct {
    left: f32,
    right: f32,
    top: f32,
    bottom: f32,
};

export fn zig_multiple_struct_floats(x: FloatRect, y: FloatRect) void {
    expect(x.left == 1) catch @panic("test failure");
    expect(x.right == 21) catch @panic("test failure");
    expect(x.top == 16) catch @panic("test failure");
    expect(x.bottom == 4) catch @panic("test failure");
    expect(y.left == 178) catch @panic("test failure");
    expect(y.right == 189) catch @panic("test failure");
    expect(y.top == 21) catch @panic("test failure");
    expect(y.bottom == 15) catch @panic("test failure");
}

test "C ABI structs of floats as multiple parameters" {
    var r1 = FloatRect{
        .left = 1,
        .right = 21,
        .top = 16,
        .bottom = 4,
    };
    var r2 = FloatRect{
        .left = 178,
        .right = 189,
        .top = 21,
        .bottom = 15,
    };
    c_multiple_struct_floats(r1, r2);
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

export fn zig_ret_small_struct_ints() SmallStructInts {
    return .{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
}

export fn zig_ret_med_struct_mixed() MedStructMixed {
    return .{
        .a = 1234,
        .b = 100.0,
        .c = 1337.0,
    };
}

export fn zig_ret_split_struct_mixed() SplitStructMixed {
    return .{
        .a = 1234,
        .b = 100,
        .c = 1337.0,
    };
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
    try expect(c_ret_bool() == true);

    try expect(c_ret_u8() == 0xff);
    try expect(c_ret_u16() == 0xffff);
    try expect(c_ret_u32() == 0xffffffff);
    try expect(c_ret_u64() == 0xffffffffffffffff);

    try expect(c_ret_i8() == -1);
    try expect(c_ret_i16() == -1);
    try expect(c_ret_i32() == -1);
    try expect(c_ret_i64() == -1);
}
