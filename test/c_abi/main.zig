//! Tests for the C ABI.
//! Those tests are passing back and forth struct and values across C ABI
//! by combining Zig code here and its mirror in cfunc.c
//! To run all the tests on the tier 1 architecture you can use:
//! zig build test-c-abi -fqemu
//! To run the tests on a specific architecture:
//! zig test -lc main.zig cfuncs.c -target mips-linux --test-cmd qemu-mips --test-cmd-bin
const std = @import("std");
const builtin = @import("builtin");
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const have_i128 = builtin.cpu.arch != .x86 and !builtin.cpu.arch.isARM() and
    !builtin.cpu.arch.isMIPS() and !builtin.cpu.arch.isPowerPC32();

const have_f128 = builtin.cpu.arch.isX86() and !builtin.os.tag.isDarwin();
const have_f80 = builtin.cpu.arch.isX86();

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
    if (have_i128) c_struct_u128(.{ .value = 0xfffffffffffffffc });

    c_i8(-1);
    c_i16(-2);
    c_i32(-3);
    c_i64(-4);
    if (have_i128) c_struct_i128(.{ .value = -6 });
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
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    c_long_double(12.34);
}

export fn zig_f32(x: f32) void {
    expect(x == 12.34) catch @panic("test failure: zig_f32");
}
export fn zig_f64(x: f64) void {
    expect(x == 56.78) catch @panic("test failure: zig_f64");
}
export fn zig_longdouble(x: c_longdouble) void {
    if (!builtin.target.isWasm()) return; // waiting for #1481
    expect(x == 12.34) catch @panic("test failure: zig_longdouble");
}

extern fn c_ptr(*anyopaque) void;

test "C ABI pointer" {
    c_ptr(@as(*anyopaque, @ptrFromInt(0xdeadbeef)));
}

export fn zig_ptr(x: *anyopaque) void {
    expect(@intFromPtr(x) == 0xdeadbeef) catch @panic("test failure: zig_ptr");
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
// so our ABI is unavoidably broken on some platforms (such as x86)
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

const complex_abi_compatible = builtin.cpu.arch != .x86 and !builtin.cpu.arch.isMIPS() and
    !builtin.cpu.arch.isARM() and !builtin.cpu.arch.isPowerPC32() and !builtin.cpu.arch.isRISCV();

test "C ABI complex float" {
    if (!complex_abi_compatible) return error.SkipZigTest;

    const a = ComplexFloat{ .real = 1.25, .imag = 2.6 };
    const b = ComplexFloat{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultf(a, b);
    try expect(z.real == 1.5);
    try expect(z.imag == 13.5);
}

test "C ABI complex float by component" {
    if (!complex_abi_compatible) return error.SkipZigTest;

    const a = ComplexFloat{ .real = 1.25, .imag = 2.6 };
    const b = ComplexFloat{ .real = 11.3, .imag = -1.5 };

    const z2 = c_cmultf_comp(a.real, a.imag, b.real, b.imag);
    try expect(z2.real == 1.5);
    try expect(z2.imag == 13.5);
}

test "C ABI complex double" {
    if (!complex_abi_compatible) return error.SkipZigTest;

    const a = ComplexDouble{ .real = 1.25, .imag = 2.6 };
    const b = ComplexDouble{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultd(a, b);
    try expect(z.real == 1.5);
    try expect(z.imag == 13.5);
}

test "C ABI complex double by component" {
    if (!complex_abi_compatible) return error.SkipZigTest;

    const a = ComplexDouble{ .real = 1.25, .imag = 2.6 };
    const b = ComplexDouble{ .real = 11.3, .imag = -1.5 };

    const z = c_cmultd_comp(a.real, a.imag, b.real, b.imag);
    try expect(z.real == 1.5);
    try expect(z.imag == 13.5);
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

const Struct_u64_u64 = extern struct {
    a: u64,
    b: u64,
};

export fn zig_ret_struct_u64_u64() Struct_u64_u64 {
    return .{ .a = 1, .b = 2 };
}

export fn zig_struct_u64_u64_0(s: Struct_u64_u64) void {
    expect(s.a == 3) catch @panic("test failure");
    expect(s.b == 4) catch @panic("test failure");
}
export fn zig_struct_u64_u64_1(_: usize, s: Struct_u64_u64) void {
    expect(s.a == 5) catch @panic("test failure");
    expect(s.b == 6) catch @panic("test failure");
}
export fn zig_struct_u64_u64_2(_: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 7) catch @panic("test failure");
    expect(s.b == 8) catch @panic("test failure");
}
export fn zig_struct_u64_u64_3(_: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 9) catch @panic("test failure");
    expect(s.b == 10) catch @panic("test failure");
}
export fn zig_struct_u64_u64_4(_: usize, _: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 11) catch @panic("test failure");
    expect(s.b == 12) catch @panic("test failure");
}
export fn zig_struct_u64_u64_5(_: usize, _: usize, _: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 13) catch @panic("test failure");
    expect(s.b == 14) catch @panic("test failure");
}
export fn zig_struct_u64_u64_6(_: usize, _: usize, _: usize, _: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 15) catch @panic("test failure");
    expect(s.b == 16) catch @panic("test failure");
}
export fn zig_struct_u64_u64_7(_: usize, _: usize, _: usize, _: usize, _: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 17) catch @panic("test failure");
    expect(s.b == 18) catch @panic("test failure");
}
export fn zig_struct_u64_u64_8(_: usize, _: usize, _: usize, _: usize, _: usize, _: usize, _: usize, _: usize, s: Struct_u64_u64) void {
    expect(s.a == 19) catch @panic("test failure");
    expect(s.b == 20) catch @panic("test failure");
}

extern fn c_ret_struct_u64_u64() Struct_u64_u64;

extern fn c_struct_u64_u64_0(Struct_u64_u64) void;
extern fn c_struct_u64_u64_1(usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_2(usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_3(usize, usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_4(usize, usize, usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_5(usize, usize, usize, usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_6(usize, usize, usize, usize, usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_7(usize, usize, usize, usize, usize, usize, usize, Struct_u64_u64) void;
extern fn c_struct_u64_u64_8(usize, usize, usize, usize, usize, usize, usize, usize, Struct_u64_u64) void;

test "C ABI struct u64 u64" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const s = c_ret_struct_u64_u64();
    try expect(s.a == 21);
    try expect(s.b == 22);
    c_struct_u64_u64_0(.{ .a = 23, .b = 24 });
    c_struct_u64_u64_1(0, .{ .a = 25, .b = 26 });
    c_struct_u64_u64_2(0, 1, .{ .a = 27, .b = 28 });
    c_struct_u64_u64_3(0, 1, 2, .{ .a = 29, .b = 30 });
    c_struct_u64_u64_4(0, 1, 2, 3, .{ .a = 31, .b = 32 });
    c_struct_u64_u64_5(0, 1, 2, 3, 4, .{ .a = 33, .b = 34 });
    c_struct_u64_u64_6(0, 1, 2, 3, 4, 5, .{ .a = 35, .b = 36 });
    c_struct_u64_u64_7(0, 1, 2, 3, 4, 5, 6, .{ .a = 37, .b = 38 });
    c_struct_u64_u64_8(0, 1, 2, 3, 4, 5, 6, 7, .{ .a = 39, .b = 40 });
}

const Struct_f32f32_f32 = extern struct {
    a: extern struct { b: f32, c: f32 },
    d: f32,
};

export fn zig_ret_struct_f32f32_f32() Struct_f32f32_f32 {
    return .{ .a = .{ .b = 1.0, .c = 2.0 }, .d = 3.0 };
}

export fn zig_struct_f32f32_f32(s: Struct_f32f32_f32) void {
    expect(s.a.b == 1.0) catch @panic("test failure");
    expect(s.a.c == 2.0) catch @panic("test failure");
    expect(s.d == 3.0) catch @panic("test failure");
}

extern fn c_ret_struct_f32f32_f32() Struct_f32f32_f32;

extern fn c_struct_f32f32_f32(Struct_f32f32_f32) void;

test "C ABI struct {f32,f32} f32" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const s = c_ret_struct_f32f32_f32();
    try expect(s.a.b == 1.0);
    try expect(s.a.c == 2.0);
    try expect(s.d == 3.0);
    c_struct_f32f32_f32(.{ .a = .{ .b = 1.0, .c = 2.0 }, .d = 3.0 });
}

const Struct_f32_f32f32 = extern struct {
    a: f32,
    b: extern struct { c: f32, d: f32 },
};

export fn zig_ret_struct_f32_f32f32() Struct_f32_f32f32 {
    return .{ .a = 1.0, .b = .{ .c = 2.0, .d = 3.0 } };
}

export fn zig_struct_f32_f32f32(s: Struct_f32_f32f32) void {
    expect(s.a == 1.0) catch @panic("test failure");
    expect(s.b.c == 2.0) catch @panic("test failure");
    expect(s.b.d == 3.0) catch @panic("test failure");
}

extern fn c_ret_struct_f32_f32f32() Struct_f32_f32f32;

extern fn c_struct_f32_f32f32(Struct_f32_f32f32) void;

test "C ABI struct f32 {f32,f32}" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const s = c_ret_struct_f32_f32f32();
    try expect(s.a == 1.0);
    try expect(s.b.c == 2.0);
    try expect(s.b.d == 3.0);
    c_struct_f32_f32f32(.{ .a = 1.0, .b = .{ .c = 2.0, .d = 3.0 } });
}

const Struct_u32_Union_u32_u32u32 = extern struct {
    a: u32,
    b: extern union {
        c: extern struct {
            d: u32,
            e: u32,
        },
    },
};

export fn zig_ret_struct_u32_union_u32_u32u32() Struct_u32_Union_u32_u32u32 {
    return .{ .a = 1, .b = .{ .c = .{ .d = 2, .e = 3 } } };
}

export fn zig_struct_u32_union_u32_u32u32(s: Struct_u32_Union_u32_u32u32) void {
    expect(s.a == 1) catch @panic("test failure");
    expect(s.b.c.d == 2) catch @panic("test failure");
    expect(s.b.c.e == 3) catch @panic("test failure");
}

extern fn c_ret_struct_u32_union_u32_u32u32() Struct_u32_Union_u32_u32u32;

extern fn c_struct_u32_union_u32_u32u32(Struct_u32_Union_u32_u32u32) void;

test "C ABI struct{u32,union{u32,struct{u32,u32}}}" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = c_ret_struct_u32_union_u32_u32u32();
    try expect(s.a == 1);
    try expect(s.b.c.d == 2);
    try expect(s.b.c.e == 3);
    c_struct_u32_union_u32_u32u32(.{ .a = 1, .b = .{ .c = .{ .d = 2, .e = 3 } } });
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
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const s = BigStruct{
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
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const x = BigUnion{
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
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = MedStructMixed{
        .a = 1234,
        .b = 100.0,
        .c = 1337.0,
    };
    c_med_struct_mixed(s);
    const s2 = c_ret_med_struct_mixed();
    try expect(s2.a == 1234);
    try expect(s2.b == 100.0);
    try expect(s2.c == 1337.0);
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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = SmallStructInts{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
    c_small_struct_ints(s);
    const s2 = c_ret_small_struct_ints();
    try expect(s2.a == 1);
    try expect(s2.b == 2);
    try expect(s2.c == 3);
    try expect(s2.d == 4);
}

export fn zig_small_struct_ints(x: SmallStructInts) void {
    expect(x.a == 1) catch @panic("test failure");
    expect(x.b == 2) catch @panic("test failure");
    expect(x.c == 3) catch @panic("test failure");
    expect(x.d == 4) catch @panic("test failure");
}

const MedStructInts = extern struct {
    x: i32,
    y: i32,
    z: i32,
};
extern fn c_med_struct_ints(MedStructInts) void;
extern fn c_ret_med_struct_ints() MedStructInts;

test "C ABI medium struct of ints" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = MedStructInts{
        .x = 1,
        .y = 2,
        .z = 3,
    };
    c_med_struct_ints(s);
    const s2 = c_ret_med_struct_ints();
    try expect(s2.x == 1);
    try expect(s2.y == 2);
    try expect(s2.z == 3);
}

export fn zig_med_struct_ints(s: MedStructInts) void {
    expect(s.x == 1) catch @panic("test failure");
    expect(s.y == 2) catch @panic("test failure");
    expect(s.z == 3) catch @panic("test failure");
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
    const s = SmallPackedStruct{ .a = 0, .b = 1, .c = 2, .d = 3 };
    c_small_packed_struct(s);
    const s2 = c_ret_small_packed_struct();
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
    if (!have_i128) return error.SkipZigTest;

    const s = BigPackedStruct{ .a = 1, .b = 2 };
    c_big_packed_struct(s);
    const s2 = c_ret_big_packed_struct();
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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = SplitStructInt{
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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const s = SplitStructMixed{
        .a = 1234,
        .b = 100,
        .c = 1337.0,
    };
    c_split_struct_mixed(s);
    const s2 = c_ret_split_struct_mixed();
    try expect(s2.a == 1234);
    try expect(s2.b == 100);
    try expect(s2.c == 1337.0);
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
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const s = BigStruct{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
        .e = 5,
    };
    const y = c_big_struct_both(s);
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
    const s = BigStruct{
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
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const v3 = Vector3{
        .x = 3.0,
        .y = 6.0,
        .z = 12.0,
    };
    c_small_struct_floats(v3);
    c_small_struct_floats_extra(v3, "hello");

    const v5 = Vector5{
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
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const r1 = Rect{
        .left = 1,
        .right = 21,
        .top = 16,
        .bottom = 4,
    };
    const r2 = Rect{
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
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const r1 = FloatRect{
        .left = 1,
        .right = 21,
        .top = 16,
        .bottom = 4,
    };
    const r2 = FloatRect{
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

export fn zig_ret_med_struct_ints() MedStructInts {
    return .{
        .x = 1,
        .y = 2,
        .z = 3,
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

const StructWithArray = extern struct {
    a: i32,
    padding: [4]u8,
    b: i64,
};
extern fn c_struct_with_array(StructWithArray) void;
extern fn c_ret_struct_with_array() StructWithArray;

test "Struct with array as padding." {
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    c_struct_with_array(.{ .a = 1, .padding = undefined, .b = 2 });

    const x = c_ret_struct_with_array();
    try expect(x.a == 4);
    try expect(x.b == 155);
}

const FloatArrayStruct = extern struct {
    origin: extern struct {
        x: f64,
        y: f64,
    },
    size: extern struct {
        width: f64,
        height: f64,
    },
};

extern fn c_float_array_struct(FloatArrayStruct) void;
extern fn c_ret_float_array_struct() FloatArrayStruct;

test "Float array like struct" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    c_float_array_struct(.{
        .origin = .{
            .x = 5,
            .y = 6,
        },
        .size = .{
            .width = 7,
            .height = 8,
        },
    });

    const x = c_ret_float_array_struct();
    try expect(x.origin.x == 1);
    try expect(x.origin.y == 2);
    try expect(x.size.width == 3);
    try expect(x.size.height == 4);
}

const SmallVec = @Vector(2, u32);

extern fn c_small_vec(SmallVec) void;
extern fn c_ret_small_vec() SmallVec;

test "small simd vector" {
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC64()) return error.SkipZigTest;

    c_small_vec(.{ 1, 2 });

    const x = c_ret_small_vec();
    try expect(x[0] == 3);
    try expect(x[1] == 4);
}

const MediumVec = @Vector(4, usize);

extern fn c_medium_vec(MediumVec) void;
extern fn c_ret_medium_vec() MediumVec;

test "medium simd vector" {
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .avx)) return error.SkipZigTest;

    if (builtin.cpu.arch.isPowerPC64()) return error.SkipZigTest;

    c_medium_vec(.{ 1, 2, 3, 4 });

    const x = c_ret_medium_vec();
    try expect(x[0] == 5);
    try expect(x[1] == 6);
    try expect(x[2] == 7);
    try expect(x[3] == 8);
}

const BigVec = @Vector(8, usize);

extern fn c_big_vec(BigVec) void;
extern fn c_ret_big_vec() BigVec;

test "big simd vector" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC64()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .x86_64 and builtin.os.tag == .macos and builtin.mode != .Debug) return error.SkipZigTest;

    c_big_vec(.{ 1, 2, 3, 4, 5, 6, 7, 8 });

    const x = c_ret_big_vec();
    try expect(x[0] == 9);
    try expect(x[1] == 10);
    try expect(x[2] == 11);
    try expect(x[3] == 12);
    try expect(x[4] == 13);
    try expect(x[5] == 14);
    try expect(x[6] == 15);
    try expect(x[7] == 16);
}

const Vector2Float = @Vector(2, f32);
const Vector4Float = @Vector(4, f32);

extern fn c_vector_2_float(Vector2Float) void;
extern fn c_vector_4_float(Vector4Float) void;

extern fn c_ret_vector_2_float() Vector2Float;
extern fn c_ret_vector_4_float() Vector4Float;

test "float simd vectors" {
    if (builtin.cpu.arch == .powerpc or builtin.cpu.arch == .powerpc64le) return error.SkipZigTest;

    {
        c_vector_2_float(.{ 1.0, 2.0 });
        const vec = c_ret_vector_2_float();
        try expect(vec[0] == 1.0);
        try expect(vec[1] == 2.0);
    }
    {
        c_vector_4_float(.{ 1.0, 2.0, 3.0, 4.0 });
        const vec = c_ret_vector_4_float();
        try expect(vec[0] == 1.0);
        try expect(vec[1] == 2.0);
        try expect(vec[2] == 3.0);
        try expect(vec[3] == 4.0);
    }
}

const Vector2Bool = @Vector(2, bool);
const Vector4Bool = @Vector(4, bool);
const Vector8Bool = @Vector(8, bool);
const Vector16Bool = @Vector(16, bool);
const Vector32Bool = @Vector(32, bool);
const Vector64Bool = @Vector(64, bool);
const Vector128Bool = @Vector(128, bool);
const Vector256Bool = @Vector(256, bool);
const Vector512Bool = @Vector(512, bool);

extern fn c_vector_2_bool(Vector2Bool) void;
extern fn c_vector_4_bool(Vector4Bool) void;
extern fn c_vector_8_bool(Vector8Bool) void;
extern fn c_vector_16_bool(Vector16Bool) void;
extern fn c_vector_32_bool(Vector32Bool) void;
extern fn c_vector_64_bool(Vector64Bool) void;
extern fn c_vector_128_bool(Vector128Bool) void;
extern fn c_vector_256_bool(Vector256Bool) void;
extern fn c_vector_512_bool(Vector512Bool) void;

extern fn c_ret_vector_2_bool() Vector2Bool;
extern fn c_ret_vector_4_bool() Vector4Bool;
extern fn c_ret_vector_8_bool() Vector8Bool;
extern fn c_ret_vector_16_bool() Vector16Bool;
extern fn c_ret_vector_32_bool() Vector32Bool;
extern fn c_ret_vector_64_bool() Vector64Bool;
extern fn c_ret_vector_128_bool() Vector128Bool;
extern fn c_ret_vector_256_bool() Vector256Bool;
extern fn c_ret_vector_512_bool() Vector512Bool;

test "bool simd vector" {
    if (builtin.zig_backend == .stage2_llvm and (builtin.cpu.arch != .powerpc and builtin.cpu.arch != .wasm32)) return error.SkipZigTest;

    {
        c_vector_2_bool(.{
            true,
            true,
        });

        const vec = c_ret_vector_2_bool();
        try expect(vec[0] == true);
        try expect(vec[1] == false);
    }
    {
        c_vector_4_bool(.{
            true,
            true,
            false,
            true,
        });

        const vec = c_ret_vector_4_bool();
        try expect(vec[0] == true);
        try expect(vec[1] == false);
        try expect(vec[2] == true);
        try expect(vec[3] == false);
    }
    {
        c_vector_8_bool(.{
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
        });

        const vec = c_ret_vector_8_bool();
        try expect(vec[0] == false);
        try expect(vec[1] == true);
        try expect(vec[2] == false);
        try expect(vec[3] == false);
        try expect(vec[4] == true);
        try expect(vec[5] == false);
        try expect(vec[6] == false);
        try expect(vec[7] == true);
    }
    {
        c_vector_16_bool(.{
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
        });

        const vec = c_ret_vector_16_bool();
        try expect(vec[0] == true);
        try expect(vec[1] == true);
        try expect(vec[2] == false);
        try expect(vec[3] == false);
        try expect(vec[4] == false);
        try expect(vec[5] == false);
        try expect(vec[6] == true);
        try expect(vec[7] == false);
        try expect(vec[8] == true);
        try expect(vec[9] == false);
        try expect(vec[10] == false);
        try expect(vec[11] == true);
        try expect(vec[12] == true);
        try expect(vec[13] == false);
        try expect(vec[14] == true);
        try expect(vec[15] == true);
    }
    {
        c_vector_32_bool(.{
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
        });

        const vec = c_ret_vector_32_bool();
        try expect(vec[0] == true);
        try expect(vec[1] == false);
        try expect(vec[2] == true);
        try expect(vec[3] == true);
        try expect(vec[4] == true);
        try expect(vec[5] == false);
        try expect(vec[6] == true);
        try expect(vec[7] == false);
        try expect(vec[8] == true);
        try expect(vec[9] == true);
        try expect(vec[10] == true);
        try expect(vec[11] == false);
        try expect(vec[12] == true);
        try expect(vec[13] == true);
        try expect(vec[14] == false);
        try expect(vec[15] == false);
        try expect(vec[16] == true);
        try expect(vec[17] == false);
        try expect(vec[18] == false);
        try expect(vec[19] == false);
        try expect(vec[20] == false);
        try expect(vec[21] == true);
        try expect(vec[22] == true);
        try expect(vec[23] == true);
        try expect(vec[24] == false);
        try expect(vec[25] == true);
        try expect(vec[26] == false);
        try expect(vec[27] == false);
        try expect(vec[28] == true);
        try expect(vec[29] == false);
        try expect(vec[30] == false);
        try expect(vec[31] == false);
    }
    {
        c_vector_64_bool(.{
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
        });

        const vec = c_ret_vector_64_bool();
        try expect(vec[0] == false);
        try expect(vec[1] == true);
        try expect(vec[2] == false);
        try expect(vec[3] == true);
        try expect(vec[4] == true);
        try expect(vec[5] == true);
        try expect(vec[6] == false);
        try expect(vec[7] == true);
        try expect(vec[8] == true);
        try expect(vec[9] == true);
        try expect(vec[10] == true);
        try expect(vec[11] == true);
        try expect(vec[12] == true);
        try expect(vec[13] == false);
        try expect(vec[14] == true);
        try expect(vec[15] == true);
        try expect(vec[16] == true);
        try expect(vec[17] == false);
        try expect(vec[18] == false);
        try expect(vec[19] == false);
        try expect(vec[20] == true);
        try expect(vec[21] == true);
        try expect(vec[22] == false);
        try expect(vec[23] == true);
        try expect(vec[24] == false);
        try expect(vec[25] == true);
        try expect(vec[26] == false);
        try expect(vec[27] == true);
        try expect(vec[28] == false);
        try expect(vec[29] == true);
        try expect(vec[30] == false);
        try expect(vec[31] == true);
        try expect(vec[32] == false);
        try expect(vec[33] == false);
        try expect(vec[34] == true);
        try expect(vec[35] == true);
        try expect(vec[36] == false);
        try expect(vec[37] == false);
        try expect(vec[38] == false);
        try expect(vec[39] == true);
        try expect(vec[40] == true);
        try expect(vec[41] == true);
        try expect(vec[42] == true);
        try expect(vec[43] == false);
        try expect(vec[44] == false);
        try expect(vec[45] == false);
        try expect(vec[46] == true);
        try expect(vec[47] == true);
        try expect(vec[48] == false);
        try expect(vec[49] == false);
        try expect(vec[50] == true);
        try expect(vec[51] == false);
        try expect(vec[52] == false);
        try expect(vec[53] == false);
        try expect(vec[54] == false);
        try expect(vec[55] == true);
        try expect(vec[56] == false);
        try expect(vec[57] == false);
        try expect(vec[58] == false);
        try expect(vec[59] == true);
        try expect(vec[60] == true);
        try expect(vec[61] == true);
        try expect(vec[62] == true);
        try expect(vec[63] == true);
    }
    {
        c_vector_128_bool(.{
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
        });

        const vec = c_ret_vector_128_bool();
        try expect(vec[0] == false);
        try expect(vec[1] == true);
        try expect(vec[2] == true);
        try expect(vec[3] == false);
        try expect(vec[4] == true);
        try expect(vec[5] == false);
        try expect(vec[6] == false);
        try expect(vec[7] == true);
        try expect(vec[8] == true);
        try expect(vec[9] == false);
        try expect(vec[10] == true);
        try expect(vec[11] == false);
        try expect(vec[12] == false);
        try expect(vec[13] == false);
        try expect(vec[14] == true);
        try expect(vec[15] == false);
        try expect(vec[16] == true);
        try expect(vec[17] == false);
        try expect(vec[18] == false);
        try expect(vec[19] == true);
        try expect(vec[20] == false);
        try expect(vec[21] == true);
        try expect(vec[22] == false);
        try expect(vec[23] == false);
        try expect(vec[24] == false);
        try expect(vec[25] == true);
        try expect(vec[26] == true);
        try expect(vec[27] == true);
        try expect(vec[28] == false);
        try expect(vec[29] == false);
        try expect(vec[30] == false);
        try expect(vec[31] == false);
        try expect(vec[32] == true);
        try expect(vec[33] == true);
        try expect(vec[34] == true);
        try expect(vec[35] == false);
        try expect(vec[36] == true);
        try expect(vec[37] == true);
        try expect(vec[38] == false);
        try expect(vec[39] == false);
        try expect(vec[40] == false);
        try expect(vec[41] == false);
        try expect(vec[42] == true);
        try expect(vec[43] == true);
        try expect(vec[44] == true);
        try expect(vec[45] == false);
        try expect(vec[46] == false);
        try expect(vec[47] == false);
        try expect(vec[48] == false);
        try expect(vec[49] == true);
        try expect(vec[50] == false);
        try expect(vec[51] == false);
        try expect(vec[52] == true);
        try expect(vec[53] == false);
        try expect(vec[54] == false);
        try expect(vec[55] == false);
        try expect(vec[56] == false);
        try expect(vec[57] == false);
        try expect(vec[58] == true);
        try expect(vec[59] == true);
        try expect(vec[60] == true);
        try expect(vec[61] == false);
        try expect(vec[62] == true);
        try expect(vec[63] == true);
        try expect(vec[64] == false);
        try expect(vec[65] == false);
        try expect(vec[66] == false);
        try expect(vec[67] == false);
        try expect(vec[68] == false);
        try expect(vec[69] == false);
        try expect(vec[70] == false);
        try expect(vec[71] == false);
        try expect(vec[72] == true);
        try expect(vec[73] == true);
        try expect(vec[74] == true);
        try expect(vec[75] == true);
        try expect(vec[76] == true);
        try expect(vec[77] == false);
        try expect(vec[78] == false);
        try expect(vec[79] == false);
        try expect(vec[80] == false);
        try expect(vec[81] == false);
        try expect(vec[82] == false);
        try expect(vec[83] == true);
        try expect(vec[84] == false);
        try expect(vec[85] == true);
        try expect(vec[86] == false);
        try expect(vec[87] == true);
        try expect(vec[88] == false);
        try expect(vec[89] == true);
        try expect(vec[90] == false);
        try expect(vec[91] == true);
        try expect(vec[92] == true);
        try expect(vec[93] == true);
        try expect(vec[94] == true);
        try expect(vec[95] == false);
        try expect(vec[96] == false);
        try expect(vec[97] == true);
        try expect(vec[98] == false);
        try expect(vec[99] == false);
        try expect(vec[100] == true);
        try expect(vec[101] == true);
        try expect(vec[102] == true);
        try expect(vec[103] == true);
        try expect(vec[104] == false);
        try expect(vec[105] == true);
        try expect(vec[106] == true);
        try expect(vec[107] == true);
        try expect(vec[108] == false);
        try expect(vec[109] == false);
        try expect(vec[110] == true);
        try expect(vec[111] == false);
        try expect(vec[112] == false);
        try expect(vec[113] == true);
        try expect(vec[114] == true);
        try expect(vec[115] == false);
        try expect(vec[116] == true);
        try expect(vec[117] == false);
        try expect(vec[118] == true);
        try expect(vec[119] == true);
        try expect(vec[120] == true);
        try expect(vec[121] == true);
        try expect(vec[122] == true);
        try expect(vec[123] == false);
        try expect(vec[124] == false);
        try expect(vec[125] == true);
        try expect(vec[126] == false);
        try expect(vec[127] == true);
    }

    {
        if (!builtin.target.isWasm()) c_vector_256_bool(.{
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
        });

        const vec = c_ret_vector_256_bool();
        try expect(vec[0] == true);
        try expect(vec[1] == false);
        try expect(vec[2] == true);
        try expect(vec[3] == true);
        try expect(vec[4] == false);
        try expect(vec[5] == false);
        try expect(vec[6] == false);
        try expect(vec[7] == false);
        try expect(vec[8] == false);
        try expect(vec[9] == true);
        try expect(vec[10] == false);
        try expect(vec[11] == true);
        try expect(vec[12] == false);
        try expect(vec[13] == true);
        try expect(vec[14] == false);
        try expect(vec[15] == false);
        try expect(vec[16] == true);
        try expect(vec[17] == true);
        try expect(vec[18] == true);
        try expect(vec[19] == false);
        try expect(vec[20] == false);
        try expect(vec[21] == false);
        try expect(vec[22] == true);
        try expect(vec[23] == false);
        try expect(vec[24] == true);
        try expect(vec[25] == false);
        try expect(vec[26] == false);
        try expect(vec[27] == true);
        try expect(vec[28] == true);
        try expect(vec[29] == true);
        try expect(vec[30] == false);
        try expect(vec[31] == false);
        try expect(vec[32] == true);
        try expect(vec[33] == true);
        try expect(vec[34] == true);
        try expect(vec[35] == false);
        try expect(vec[36] == true);
        try expect(vec[37] == true);
        try expect(vec[38] == true);
        try expect(vec[39] == false);
        try expect(vec[40] == true);
        try expect(vec[41] == false);
        try expect(vec[42] == true);
        try expect(vec[43] == true);
        try expect(vec[44] == false);
        try expect(vec[45] == true);
        try expect(vec[46] == false);
        try expect(vec[47] == true);
        try expect(vec[48] == true);
        try expect(vec[49] == false);
        try expect(vec[50] == false);
        try expect(vec[51] == true);
        try expect(vec[52] == true);
        try expect(vec[53] == false);
        try expect(vec[54] == false);
        try expect(vec[55] == true);
        try expect(vec[56] == false);
        try expect(vec[57] == true);
        try expect(vec[58] == true);
        try expect(vec[59] == true);
        try expect(vec[60] == false);
        try expect(vec[61] == true);
        try expect(vec[62] == true);
        try expect(vec[63] == false);
        try expect(vec[64] == true);
        try expect(vec[65] == true);
        try expect(vec[66] == false);
        try expect(vec[67] == true);
        try expect(vec[68] == false);
        try expect(vec[69] == true);
        try expect(vec[70] == true);
        try expect(vec[71] == true);
        try expect(vec[72] == false);
        try expect(vec[73] == true);
        try expect(vec[74] == true);
        try expect(vec[75] == false);
        try expect(vec[76] == true);
        try expect(vec[77] == true);
        try expect(vec[78] == true);
        try expect(vec[79] == true);
        try expect(vec[80] == false);
        try expect(vec[81] == true);
        try expect(vec[82] == false);
        try expect(vec[83] == true);
        try expect(vec[84] == true);
        try expect(vec[85] == true);
        try expect(vec[86] == false);
        try expect(vec[87] == true);
        try expect(vec[88] == false);
        try expect(vec[89] == true);
        try expect(vec[90] == false);
        try expect(vec[91] == false);
        try expect(vec[92] == true);
        try expect(vec[93] == false);
        try expect(vec[94] == false);
        try expect(vec[95] == false);
        try expect(vec[96] == true);
        try expect(vec[97] == true);
        try expect(vec[98] == false);
        try expect(vec[99] == false);
        try expect(vec[100] == false);
        try expect(vec[101] == true);
        try expect(vec[102] == true);
        try expect(vec[103] == true);
        try expect(vec[104] == false);
        try expect(vec[105] == false);
        try expect(vec[106] == false);
        try expect(vec[107] == true);
        try expect(vec[108] == false);
        try expect(vec[109] == true);
        try expect(vec[110] == true);
        try expect(vec[111] == true);
        try expect(vec[112] == true);
        try expect(vec[113] == true);
        try expect(vec[114] == true);
        try expect(vec[115] == true);
        try expect(vec[116] == true);
        try expect(vec[117] == false);
        try expect(vec[118] == true);
        try expect(vec[119] == false);
        try expect(vec[120] == true);
        try expect(vec[121] == false);
        try expect(vec[122] == false);
        try expect(vec[123] == true);
        try expect(vec[124] == true);
        try expect(vec[125] == false);
        try expect(vec[126] == true);
        try expect(vec[127] == false);
        try expect(vec[128] == false);
        try expect(vec[129] == false);
        try expect(vec[130] == false);
        try expect(vec[131] == true);
        try expect(vec[132] == false);
        try expect(vec[133] == false);
        try expect(vec[134] == true);
        try expect(vec[135] == false);
        try expect(vec[136] == false);
        try expect(vec[137] == false);
        try expect(vec[138] == false);
        try expect(vec[139] == false);
        try expect(vec[140] == false);
        try expect(vec[141] == true);
        try expect(vec[142] == false);
        try expect(vec[143] == true);
        try expect(vec[144] == false);
        try expect(vec[145] == true);
        try expect(vec[146] == true);
        try expect(vec[147] == true);
        try expect(vec[148] == false);
        try expect(vec[149] == true);
        try expect(vec[150] == true);
        try expect(vec[151] == false);
        try expect(vec[152] == true);
        try expect(vec[153] == true);
        try expect(vec[154] == false);
        try expect(vec[155] == true);
        try expect(vec[156] == true);
        try expect(vec[157] == true);
        try expect(vec[158] == true);
        try expect(vec[159] == true);
        try expect(vec[160] == true);
        try expect(vec[161] == true);
        try expect(vec[162] == false);
        try expect(vec[163] == false);
        try expect(vec[164] == false);
        try expect(vec[165] == true);
        try expect(vec[166] == false);
        try expect(vec[167] == false);
        try expect(vec[168] == true);
        try expect(vec[169] == false);
        try expect(vec[170] == true);
        try expect(vec[171] == true);
        try expect(vec[172] == true);
        try expect(vec[173] == false);
        try expect(vec[174] == false);
        try expect(vec[175] == true);
        try expect(vec[176] == true);
        try expect(vec[177] == true);
        try expect(vec[178] == true);
        try expect(vec[179] == false);
        try expect(vec[180] == true);
        try expect(vec[181] == true);
        try expect(vec[182] == false);
        try expect(vec[183] == true);
        try expect(vec[184] == false);
        try expect(vec[185] == false);
        try expect(vec[186] == false);
        try expect(vec[187] == true);
        try expect(vec[188] == true);
        try expect(vec[189] == true);
        try expect(vec[190] == true);
        try expect(vec[191] == true);
        try expect(vec[192] == true);
        try expect(vec[193] == true);
        try expect(vec[194] == true);
        try expect(vec[195] == false);
        try expect(vec[196] == false);
        try expect(vec[197] == true);
        try expect(vec[198] == false);
        try expect(vec[199] == false);
        try expect(vec[200] == false);
        try expect(vec[201] == true);
        try expect(vec[202] == true);
        try expect(vec[203] == true);
        try expect(vec[204] == true);
        try expect(vec[205] == true);
        try expect(vec[206] == true);
        try expect(vec[207] == false);
        try expect(vec[208] == false);
        try expect(vec[209] == false);
        try expect(vec[210] == true);
        try expect(vec[211] == true);
        try expect(vec[212] == true);
        try expect(vec[213] == false);
        try expect(vec[214] == true);
        try expect(vec[215] == false);
        try expect(vec[216] == true);
        try expect(vec[217] == false);
        try expect(vec[218] == true);
        try expect(vec[219] == false);
        try expect(vec[220] == true);
        try expect(vec[221] == true);
        try expect(vec[222] == true);
        try expect(vec[223] == false);
        try expect(vec[224] == true);
        try expect(vec[225] == false);
        try expect(vec[226] == true);
        try expect(vec[227] == false);
        try expect(vec[228] == true);
        try expect(vec[229] == false);
        try expect(vec[230] == true);
        try expect(vec[231] == false);
        try expect(vec[232] == false);
        try expect(vec[233] == true);
        try expect(vec[234] == false);
        try expect(vec[235] == true);
        try expect(vec[236] == true);
        try expect(vec[237] == false);
        try expect(vec[238] == false);
        try expect(vec[239] == true);
        try expect(vec[240] == false);
        try expect(vec[241] == false);
        try expect(vec[242] == false);
        try expect(vec[243] == true);
        try expect(vec[244] == true);
        try expect(vec[245] == false);
        try expect(vec[246] == false);
        try expect(vec[247] == false);
        try expect(vec[248] == false);
        try expect(vec[249] == false);
        try expect(vec[250] == true);
        try expect(vec[251] == false);
        try expect(vec[252] == true);
        try expect(vec[253] == false);
        try expect(vec[254] == false);
        try expect(vec[255] == false);
    }
    {
        if (!builtin.target.isWasm()) c_vector_512_bool(.{
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            true,
            false,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            false,
            true,
            true,
            true,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            true,
            false,
            true,
        });

        const vec = c_ret_vector_512_bool();
        try expect(vec[0] == false);
        try expect(vec[1] == true);
        try expect(vec[2] == false);
        try expect(vec[3] == false);
        try expect(vec[4] == false);
        try expect(vec[5] == true);
        try expect(vec[6] == false);
        try expect(vec[7] == false);
        try expect(vec[8] == false);
        try expect(vec[9] == true);
        try expect(vec[10] == false);
        try expect(vec[11] == false);
        try expect(vec[12] == false);
        try expect(vec[13] == true);
        try expect(vec[14] == false);
        try expect(vec[15] == true);
        try expect(vec[16] == false);
        try expect(vec[17] == false);
        try expect(vec[18] == false);
        try expect(vec[19] == false);
        try expect(vec[20] == false);
        try expect(vec[21] == false);
        try expect(vec[22] == true);
        try expect(vec[23] == true);
        try expect(vec[24] == false);
        try expect(vec[25] == false);
        try expect(vec[26] == false);
        try expect(vec[27] == false);
        try expect(vec[28] == true);
        try expect(vec[29] == true);
        try expect(vec[30] == false);
        try expect(vec[31] == true);
        try expect(vec[32] == false);
        try expect(vec[33] == true);
        try expect(vec[34] == true);
        try expect(vec[35] == true);
        try expect(vec[36] == false);
        try expect(vec[37] == false);
        try expect(vec[38] == true);
        try expect(vec[39] == true);
        try expect(vec[40] == false);
        try expect(vec[41] == false);
        try expect(vec[42] == false);
        try expect(vec[43] == false);
        try expect(vec[44] == false);
        try expect(vec[45] == true);
        try expect(vec[46] == false);
        try expect(vec[47] == true);
        try expect(vec[48] == true);
        try expect(vec[49] == false);
        try expect(vec[50] == true);
        try expect(vec[51] == true);
        try expect(vec[52] == true);
        try expect(vec[53] == true);
        try expect(vec[54] == false);
        try expect(vec[55] == false);
        try expect(vec[56] == false);
        try expect(vec[57] == true);
        try expect(vec[58] == true);
        try expect(vec[59] == false);
        try expect(vec[60] == false);
        try expect(vec[61] == false);
        try expect(vec[62] == false);
        try expect(vec[63] == true);
        try expect(vec[64] == true);
        try expect(vec[65] == true);
        try expect(vec[66] == true);
        try expect(vec[67] == true);
        try expect(vec[68] == false);
        try expect(vec[69] == false);
        try expect(vec[70] == false);
        try expect(vec[71] == false);
        try expect(vec[72] == false);
        try expect(vec[73] == true);
        try expect(vec[74] == false);
        try expect(vec[75] == true);
        try expect(vec[76] == false);
        try expect(vec[77] == false);
        try expect(vec[78] == true);
        try expect(vec[79] == true);
        try expect(vec[80] == false);
        try expect(vec[81] == false);
        try expect(vec[82] == false);
        try expect(vec[83] == true);
        try expect(vec[84] == false);
        try expect(vec[85] == true);
        try expect(vec[86] == true);
        try expect(vec[87] == true);
        try expect(vec[88] == false);
        try expect(vec[89] == true);
        try expect(vec[90] == false);
        try expect(vec[91] == false);
        try expect(vec[92] == true);
        try expect(vec[93] == true);
        try expect(vec[94] == false);
        try expect(vec[95] == true);
        try expect(vec[96] == true);
        try expect(vec[97] == false);
        try expect(vec[98] == true);
        try expect(vec[99] == false);
        try expect(vec[100] == true);
        try expect(vec[101] == true);
        try expect(vec[102] == false);
        try expect(vec[103] == true);
        try expect(vec[104] == true);
        try expect(vec[105] == false);
        try expect(vec[106] == false);
        try expect(vec[107] == false);
        try expect(vec[108] == true);
        try expect(vec[109] == false);
        try expect(vec[110] == false);
        try expect(vec[111] == false);
        try expect(vec[112] == true);
        try expect(vec[113] == true);
        try expect(vec[114] == true);
        try expect(vec[115] == false);
        try expect(vec[116] == true);
        try expect(vec[117] == false);
        try expect(vec[118] == true);
        try expect(vec[119] == false);
        try expect(vec[120] == true);
        try expect(vec[121] == true);
        try expect(vec[122] == false);
        try expect(vec[123] == true);
        try expect(vec[124] == false);
        try expect(vec[125] == true);
        try expect(vec[126] == true);
        try expect(vec[127] == true);
        try expect(vec[128] == false);
        try expect(vec[129] == true);
        try expect(vec[130] == false);
        try expect(vec[131] == false);
        try expect(vec[132] == false);
        try expect(vec[133] == false);
        try expect(vec[134] == false);
        try expect(vec[135] == false);
        try expect(vec[136] == true);
        try expect(vec[137] == false);
        try expect(vec[138] == true);
        try expect(vec[139] == false);
        try expect(vec[140] == true);
        try expect(vec[141] == true);
        try expect(vec[142] == false);
        try expect(vec[143] == true);
        try expect(vec[144] == false);
        try expect(vec[145] == false);
        try expect(vec[146] == true);
        try expect(vec[147] == false);
        try expect(vec[148] == false);
        try expect(vec[149] == true);
        try expect(vec[150] == false);
        try expect(vec[151] == true);
        try expect(vec[152] == false);
        try expect(vec[153] == true);
        try expect(vec[154] == false);
        try expect(vec[155] == false);
        try expect(vec[156] == true);
        try expect(vec[157] == false);
        try expect(vec[158] == true);
        try expect(vec[159] == true);
        try expect(vec[160] == true);
        try expect(vec[161] == false);
        try expect(vec[162] == false);
        try expect(vec[163] == true);
        try expect(vec[164] == false);
        try expect(vec[165] == false);
        try expect(vec[166] == false);
        try expect(vec[167] == true);
        try expect(vec[168] == true);
        try expect(vec[169] == true);
        try expect(vec[170] == false);
        try expect(vec[171] == true);
        try expect(vec[172] == false);
        try expect(vec[173] == false);
        try expect(vec[174] == false);
        try expect(vec[175] == false);
        try expect(vec[176] == false);
        try expect(vec[177] == true);
        try expect(vec[178] == true);
        try expect(vec[179] == false);
        try expect(vec[180] == false);
        try expect(vec[181] == true);
        try expect(vec[182] == false);
        try expect(vec[183] == false);
        try expect(vec[184] == false);
        try expect(vec[185] == false);
        try expect(vec[186] == false);
        try expect(vec[187] == true);
        try expect(vec[188] == true);
        try expect(vec[189] == false);
        try expect(vec[190] == false);
        try expect(vec[191] == false);
        try expect(vec[192] == false);
        try expect(vec[193] == false);
        try expect(vec[194] == false);
        try expect(vec[195] == true);
        try expect(vec[196] == true);
        try expect(vec[197] == false);
        try expect(vec[198] == true);
        try expect(vec[199] == true);
        try expect(vec[200] == true);
        try expect(vec[201] == true);
        try expect(vec[202] == true);
        try expect(vec[203] == true);
        try expect(vec[204] == false);
        try expect(vec[205] == false);
        try expect(vec[206] == false);
        try expect(vec[207] == false);
        try expect(vec[208] == true);
        try expect(vec[209] == false);
        try expect(vec[210] == true);
        try expect(vec[211] == true);
        try expect(vec[212] == true);
        try expect(vec[213] == true);
        try expect(vec[214] == false);
        try expect(vec[215] == false);
        try expect(vec[216] == false);
        try expect(vec[217] == true);
        try expect(vec[218] == true);
        try expect(vec[219] == false);
        try expect(vec[220] == true);
        try expect(vec[221] == true);
        try expect(vec[222] == false);
        try expect(vec[223] == false);
        try expect(vec[224] == false);
        try expect(vec[225] == true);
        try expect(vec[226] == true);
        try expect(vec[227] == true);
        try expect(vec[228] == true);
        try expect(vec[229] == false);
        try expect(vec[230] == true);
        try expect(vec[231] == false);
        try expect(vec[232] == true);
        try expect(vec[233] == true);
        try expect(vec[234] == true);
        try expect(vec[235] == true);
        try expect(vec[236] == false);
        try expect(vec[237] == true);
        try expect(vec[238] == false);
        try expect(vec[239] == true);
        try expect(vec[240] == false);
        try expect(vec[241] == true);
        try expect(vec[242] == false);
        try expect(vec[243] == false);
        try expect(vec[244] == false);
        try expect(vec[245] == true);
        try expect(vec[246] == true);
        try expect(vec[247] == false);
        try expect(vec[248] == true);
        try expect(vec[249] == false);
        try expect(vec[250] == false);
        try expect(vec[251] == false);
        try expect(vec[252] == true);
        try expect(vec[253] == true);
        try expect(vec[254] == true);
        try expect(vec[255] == true);
        try expect(vec[256] == true);
        try expect(vec[257] == false);
        try expect(vec[258] == true);
        try expect(vec[259] == true);
        try expect(vec[260] == true);
        try expect(vec[261] == true);
        try expect(vec[262] == false);
        try expect(vec[263] == true);
        try expect(vec[264] == false);
        try expect(vec[265] == false);
        try expect(vec[266] == true);
        try expect(vec[267] == false);
        try expect(vec[268] == true);
        try expect(vec[269] == false);
        try expect(vec[270] == false);
        try expect(vec[271] == true);
        try expect(vec[272] == true);
        try expect(vec[273] == false);
        try expect(vec[274] == true);
        try expect(vec[275] == false);
        try expect(vec[276] == false);
        try expect(vec[277] == true);
        try expect(vec[278] == false);
        try expect(vec[279] == false);
        try expect(vec[280] == true);
        try expect(vec[281] == true);
        try expect(vec[282] == true);
        try expect(vec[283] == false);
        try expect(vec[284] == false);
        try expect(vec[285] == true);
        try expect(vec[286] == true);
        try expect(vec[287] == true);
        try expect(vec[288] == false);
        try expect(vec[289] == false);
        try expect(vec[290] == false);
        try expect(vec[291] == false);
        try expect(vec[292] == false);
        try expect(vec[293] == false);
        try expect(vec[294] == true);
        try expect(vec[295] == false);
        try expect(vec[296] == true);
        try expect(vec[297] == false);
        try expect(vec[298] == true);
        try expect(vec[299] == true);
        try expect(vec[300] == false);
        try expect(vec[301] == false);
        try expect(vec[302] == false);
        try expect(vec[303] == false);
        try expect(vec[304] == true);
        try expect(vec[305] == true);
        try expect(vec[306] == true);
        try expect(vec[307] == true);
        try expect(vec[308] == true);
        try expect(vec[309] == false);
        try expect(vec[310] == true);
        try expect(vec[311] == true);
        try expect(vec[312] == true);
        try expect(vec[313] == true);
        try expect(vec[314] == true);
        try expect(vec[315] == false);
        try expect(vec[316] == true);
        try expect(vec[317] == true);
        try expect(vec[318] == true);
        try expect(vec[319] == false);
        try expect(vec[320] == true);
        try expect(vec[321] == false);
        try expect(vec[322] == true);
        try expect(vec[323] == true);
        try expect(vec[324] == true);
        try expect(vec[325] == false);
        try expect(vec[326] == false);
        try expect(vec[327] == true);
        try expect(vec[328] == true);
        try expect(vec[329] == true);
        try expect(vec[330] == false);
        try expect(vec[331] == false);
        try expect(vec[332] == true);
        try expect(vec[333] == true);
        try expect(vec[334] == false);
        try expect(vec[335] == true);
        try expect(vec[336] == true);
        try expect(vec[337] == true);
        try expect(vec[338] == true);
        try expect(vec[339] == true);
        try expect(vec[340] == true);
        try expect(vec[341] == false);
        try expect(vec[342] == true);
        try expect(vec[343] == false);
        try expect(vec[344] == true);
        try expect(vec[345] == false);
        try expect(vec[346] == false);
        try expect(vec[347] == false);
        try expect(vec[348] == false);
        try expect(vec[349] == true);
        try expect(vec[350] == true);
        try expect(vec[351] == true);
        try expect(vec[352] == true);
        try expect(vec[353] == false);
        try expect(vec[354] == true);
        try expect(vec[355] == false);
        try expect(vec[356] == true);
        try expect(vec[357] == true);
        try expect(vec[358] == false);
        try expect(vec[359] == true);
        try expect(vec[360] == false);
        try expect(vec[361] == false);
        try expect(vec[362] == true);
        try expect(vec[363] == false);
        try expect(vec[364] == false);
        try expect(vec[365] == false);
        try expect(vec[366] == false);
        try expect(vec[367] == false);
        try expect(vec[368] == false);
        try expect(vec[369] == false);
        try expect(vec[370] == true);
        try expect(vec[371] == false);
        try expect(vec[372] == true);
        try expect(vec[373] == true);
        try expect(vec[374] == false);
        try expect(vec[375] == false);
        try expect(vec[376] == true);
        try expect(vec[377] == false);
        try expect(vec[378] == false);
        try expect(vec[379] == true);
        try expect(vec[380] == false);
        try expect(vec[381] == false);
        try expect(vec[382] == true);
        try expect(vec[383] == false);
        try expect(vec[384] == false);
        try expect(vec[385] == false);
        try expect(vec[386] == false);
        try expect(vec[387] == true);
        try expect(vec[388] == true);
        try expect(vec[389] == true);
        try expect(vec[390] == true);
        try expect(vec[391] == true);
        try expect(vec[392] == true);
        try expect(vec[393] == true);
        try expect(vec[394] == false);
        try expect(vec[395] == true);
        try expect(vec[396] == true);
        try expect(vec[397] == false);
        try expect(vec[398] == false);
        try expect(vec[399] == false);
        try expect(vec[400] == true);
        try expect(vec[401] == false);
        try expect(vec[402] == true);
        try expect(vec[403] == true);
        try expect(vec[404] == false);
        try expect(vec[405] == true);
        try expect(vec[406] == true);
        try expect(vec[407] == true);
        try expect(vec[408] == true);
        try expect(vec[409] == false);
        try expect(vec[410] == false);
        try expect(vec[411] == false);
        try expect(vec[412] == true);
        try expect(vec[413] == true);
        try expect(vec[414] == false);
        try expect(vec[415] == true);
        try expect(vec[416] == false);
        try expect(vec[417] == true);
        try expect(vec[418] == false);
        try expect(vec[419] == false);
        try expect(vec[420] == false);
        try expect(vec[421] == false);
        try expect(vec[422] == true);
        try expect(vec[423] == true);
        try expect(vec[424] == true);
        try expect(vec[425] == false);
        try expect(vec[426] == true);
        try expect(vec[427] == false);
        try expect(vec[428] == false);
        try expect(vec[429] == false);
        try expect(vec[430] == true);
        try expect(vec[431] == true);
        try expect(vec[432] == false);
        try expect(vec[433] == true);
        try expect(vec[434] == false);
        try expect(vec[435] == false);
        try expect(vec[436] == true);
        try expect(vec[437] == true);
        try expect(vec[438] == true);
        try expect(vec[439] == true);
        try expect(vec[440] == true);
        try expect(vec[441] == true);
        try expect(vec[442] == false);
        try expect(vec[443] == false);
        try expect(vec[444] == false);
        try expect(vec[445] == true);
        try expect(vec[446] == true);
        try expect(vec[447] == true);
        try expect(vec[448] == false);
        try expect(vec[449] == false);
        try expect(vec[450] == false);
        try expect(vec[451] == false);
        try expect(vec[452] == false);
        try expect(vec[453] == false);
        try expect(vec[454] == false);
        try expect(vec[455] == false);
        try expect(vec[456] == false);
        try expect(vec[457] == false);
        try expect(vec[458] == false);
        try expect(vec[459] == true);
        try expect(vec[460] == false);
        try expect(vec[461] == false);
        try expect(vec[462] == false);
        try expect(vec[463] == true);
        try expect(vec[464] == false);
        try expect(vec[465] == false);
        try expect(vec[466] == false);
        try expect(vec[467] == false);
        try expect(vec[468] == true);
        try expect(vec[469] == true);
        try expect(vec[470] == true);
        try expect(vec[471] == true);
        try expect(vec[472] == true);
        try expect(vec[473] == false);
        try expect(vec[474] == false);
        try expect(vec[475] == true);
        try expect(vec[476] == true);
        try expect(vec[477] == true);
        try expect(vec[478] == false);
        try expect(vec[479] == true);
        try expect(vec[480] == true);
        try expect(vec[481] == true);
        try expect(vec[482] == false);
        try expect(vec[483] == true);
        try expect(vec[484] == false);
        try expect(vec[485] == true);
        try expect(vec[486] == false);
        try expect(vec[487] == true);
        try expect(vec[488] == false);
        try expect(vec[489] == true);
        try expect(vec[490] == true);
        try expect(vec[491] == true);
        try expect(vec[492] == true);
        try expect(vec[493] == false);
        try expect(vec[494] == true);
        try expect(vec[495] == true);
        try expect(vec[496] == false);
        try expect(vec[497] == true);
        try expect(vec[498] == false);
        try expect(vec[499] == false);
        try expect(vec[500] == false);
        try expect(vec[501] == false);
        try expect(vec[502] == false);
        try expect(vec[503] == false);
        try expect(vec[504] == false);
        try expect(vec[505] == false);
        try expect(vec[506] == false);
        try expect(vec[507] == true);
        try expect(vec[508] == true);
        try expect(vec[509] == false);
        try expect(vec[510] == true);
        try expect(vec[511] == false);
    }
}

comptime {
    skip: {
        if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .x86_64) break :skip;

        _ = struct {
            export fn zig_vector_2_bool(vec: Vector2Bool) void {
                expect(vec[0] == false) catch @panic("test failure");
                expect(vec[1] == true) catch @panic("test failure");
            }

            export fn zig_vector_4_bool(vec: Vector4Bool) void {
                expect(vec[0] == false) catch @panic("test failure");
                expect(vec[1] == false) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == false) catch @panic("test failure");
            }

            export fn zig_vector_8_bool(vec: Vector8Bool) void {
                expect(vec[0] == true) catch @panic("test failure");
                expect(vec[1] == true) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == true) catch @panic("test failure");
                expect(vec[4] == false) catch @panic("test failure");
                expect(vec[5] == true) catch @panic("test failure");
                expect(vec[6] == true) catch @panic("test failure");
                expect(vec[7] == false) catch @panic("test failure");
            }

            export fn zig_vector_16_bool(vec: Vector16Bool) void {
                expect(vec[0] == true) catch @panic("test failure");
                expect(vec[1] == false) catch @panic("test failure");
                expect(vec[2] == true) catch @panic("test failure");
                expect(vec[3] == true) catch @panic("test failure");
                expect(vec[4] == true) catch @panic("test failure");
                expect(vec[5] == false) catch @panic("test failure");
                expect(vec[6] == false) catch @panic("test failure");
                expect(vec[7] == false) catch @panic("test failure");
                expect(vec[8] == true) catch @panic("test failure");
                expect(vec[9] == true) catch @panic("test failure");
                expect(vec[10] == true) catch @panic("test failure");
                expect(vec[11] == true) catch @panic("test failure");
                expect(vec[12] == false) catch @panic("test failure");
                expect(vec[13] == false) catch @panic("test failure");
                expect(vec[14] == false) catch @panic("test failure");
                expect(vec[15] == true) catch @panic("test failure");
            }

            export fn zig_vector_32_bool(vec: Vector32Bool) void {
                expect(vec[0] == false) catch @panic("test failure");
                expect(vec[1] == false) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == true) catch @panic("test failure");
                expect(vec[4] == true) catch @panic("test failure");
                expect(vec[5] == false) catch @panic("test failure");
                expect(vec[6] == false) catch @panic("test failure");
                expect(vec[7] == true) catch @panic("test failure");
                expect(vec[8] == false) catch @panic("test failure");
                expect(vec[9] == true) catch @panic("test failure");
                expect(vec[10] == true) catch @panic("test failure");
                expect(vec[11] == true) catch @panic("test failure");
                expect(vec[12] == false) catch @panic("test failure");
                expect(vec[13] == false) catch @panic("test failure");
                expect(vec[14] == true) catch @panic("test failure");
                expect(vec[15] == true) catch @panic("test failure");
                expect(vec[16] == true) catch @panic("test failure");
                expect(vec[17] == true) catch @panic("test failure");
                expect(vec[18] == true) catch @panic("test failure");
                expect(vec[19] == false) catch @panic("test failure");
                expect(vec[20] == true) catch @panic("test failure");
                expect(vec[21] == true) catch @panic("test failure");
                expect(vec[22] == true) catch @panic("test failure");
                expect(vec[23] == false) catch @panic("test failure");
                expect(vec[24] == false) catch @panic("test failure");
                expect(vec[25] == true) catch @panic("test failure");
                expect(vec[26] == true) catch @panic("test failure");
                expect(vec[27] == false) catch @panic("test failure");
                expect(vec[28] == true) catch @panic("test failure");
                expect(vec[29] == true) catch @panic("test failure");
                expect(vec[30] == false) catch @panic("test failure");
                expect(vec[31] == true) catch @panic("test failure");
            }

            export fn zig_vector_64_bool(vec: Vector64Bool) void {
                expect(vec[0] == true) catch @panic("test failure");
                expect(vec[1] == true) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == true) catch @panic("test failure");
                expect(vec[4] == false) catch @panic("test failure");
                expect(vec[5] == true) catch @panic("test failure");
                expect(vec[6] == false) catch @panic("test failure");
                expect(vec[7] == false) catch @panic("test failure");
                expect(vec[8] == true) catch @panic("test failure");
                expect(vec[9] == true) catch @panic("test failure");
                expect(vec[10] == true) catch @panic("test failure");
                expect(vec[11] == true) catch @panic("test failure");
                expect(vec[12] == true) catch @panic("test failure");
                expect(vec[13] == true) catch @panic("test failure");
                expect(vec[14] == true) catch @panic("test failure");
                expect(vec[15] == false) catch @panic("test failure");
                expect(vec[16] == false) catch @panic("test failure");
                expect(vec[17] == true) catch @panic("test failure");
                expect(vec[18] == true) catch @panic("test failure");
                expect(vec[19] == false) catch @panic("test failure");
                expect(vec[20] == true) catch @panic("test failure");
                expect(vec[21] == true) catch @panic("test failure");
                expect(vec[22] == true) catch @panic("test failure");
                expect(vec[23] == true) catch @panic("test failure");
                expect(vec[24] == false) catch @panic("test failure");
                expect(vec[25] == false) catch @panic("test failure");
                expect(vec[26] == true) catch @panic("test failure");
                expect(vec[27] == false) catch @panic("test failure");
                expect(vec[28] == false) catch @panic("test failure");
                expect(vec[29] == true) catch @panic("test failure");
                expect(vec[30] == false) catch @panic("test failure");
                expect(vec[31] == true) catch @panic("test failure");
                expect(vec[32] == false) catch @panic("test failure");
                expect(vec[33] == true) catch @panic("test failure");
                expect(vec[34] == true) catch @panic("test failure");
                expect(vec[35] == false) catch @panic("test failure");
                expect(vec[36] == true) catch @panic("test failure");
                expect(vec[37] == true) catch @panic("test failure");
                expect(vec[38] == false) catch @panic("test failure");
                expect(vec[39] == false) catch @panic("test failure");
                expect(vec[40] == true) catch @panic("test failure");
                expect(vec[41] == true) catch @panic("test failure");
                expect(vec[42] == true) catch @panic("test failure");
                expect(vec[43] == true) catch @panic("test failure");
                expect(vec[44] == true) catch @panic("test failure");
                expect(vec[45] == false) catch @panic("test failure");
                expect(vec[46] == true) catch @panic("test failure");
                expect(vec[47] == false) catch @panic("test failure");
                expect(vec[48] == false) catch @panic("test failure");
                expect(vec[49] == false) catch @panic("test failure");
                expect(vec[50] == false) catch @panic("test failure");
                expect(vec[51] == false) catch @panic("test failure");
                expect(vec[52] == true) catch @panic("test failure");
                expect(vec[53] == false) catch @panic("test failure");
                expect(vec[54] == false) catch @panic("test failure");
                expect(vec[55] == true) catch @panic("test failure");
                expect(vec[56] == true) catch @panic("test failure");
                expect(vec[57] == false) catch @panic("test failure");
                expect(vec[58] == false) catch @panic("test failure");
                expect(vec[59] == false) catch @panic("test failure");
                expect(vec[60] == true) catch @panic("test failure");
                expect(vec[61] == true) catch @panic("test failure");
                expect(vec[62] == true) catch @panic("test failure");
                expect(vec[63] == true) catch @panic("test failure");
            }

            export fn zig_vector_128_bool(vec: Vector128Bool) void {
                expect(vec[0] == true) catch @panic("test failure");
                expect(vec[1] == true) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == true) catch @panic("test failure");
                expect(vec[4] == true) catch @panic("test failure");
                expect(vec[5] == false) catch @panic("test failure");
                expect(vec[6] == false) catch @panic("test failure");
                expect(vec[7] == true) catch @panic("test failure");
                expect(vec[8] == true) catch @panic("test failure");
                expect(vec[9] == true) catch @panic("test failure");
                expect(vec[10] == true) catch @panic("test failure");
                expect(vec[11] == true) catch @panic("test failure");
                expect(vec[12] == false) catch @panic("test failure");
                expect(vec[13] == false) catch @panic("test failure");
                expect(vec[14] == false) catch @panic("test failure");
                expect(vec[15] == true) catch @panic("test failure");
                expect(vec[16] == false) catch @panic("test failure");
                expect(vec[17] == true) catch @panic("test failure");
                expect(vec[18] == false) catch @panic("test failure");
                expect(vec[19] == false) catch @panic("test failure");
                expect(vec[20] == true) catch @panic("test failure");
                expect(vec[21] == false) catch @panic("test failure");
                expect(vec[22] == true) catch @panic("test failure");
                expect(vec[23] == false) catch @panic("test failure");
                expect(vec[24] == false) catch @panic("test failure");
                expect(vec[25] == false) catch @panic("test failure");
                expect(vec[26] == true) catch @panic("test failure");
                expect(vec[27] == false) catch @panic("test failure");
                expect(vec[28] == true) catch @panic("test failure");
                expect(vec[29] == true) catch @panic("test failure");
                expect(vec[30] == false) catch @panic("test failure");
                expect(vec[31] == true) catch @panic("test failure");
                expect(vec[32] == false) catch @panic("test failure");
                expect(vec[33] == true) catch @panic("test failure");
                expect(vec[34] == true) catch @panic("test failure");
                expect(vec[35] == false) catch @panic("test failure");
                expect(vec[36] == false) catch @panic("test failure");
                expect(vec[37] == false) catch @panic("test failure");
                expect(vec[38] == false) catch @panic("test failure");
                expect(vec[39] == true) catch @panic("test failure");
                expect(vec[40] == true) catch @panic("test failure");
                expect(vec[41] == false) catch @panic("test failure");
                expect(vec[42] == true) catch @panic("test failure");
                expect(vec[43] == false) catch @panic("test failure");
                expect(vec[44] == false) catch @panic("test failure");
                expect(vec[45] == true) catch @panic("test failure");
                expect(vec[46] == false) catch @panic("test failure");
                expect(vec[47] == false) catch @panic("test failure");
                expect(vec[48] == true) catch @panic("test failure");
                expect(vec[49] == true) catch @panic("test failure");
                expect(vec[50] == false) catch @panic("test failure");
                expect(vec[51] == false) catch @panic("test failure");
                expect(vec[52] == true) catch @panic("test failure");
                expect(vec[53] == false) catch @panic("test failure");
                expect(vec[54] == false) catch @panic("test failure");
                expect(vec[55] == true) catch @panic("test failure");
                expect(vec[56] == true) catch @panic("test failure");
                expect(vec[57] == true) catch @panic("test failure");
                expect(vec[58] == true) catch @panic("test failure");
                expect(vec[59] == true) catch @panic("test failure");
                expect(vec[60] == true) catch @panic("test failure");
                expect(vec[61] == true) catch @panic("test failure");
                expect(vec[62] == true) catch @panic("test failure");
                expect(vec[63] == false) catch @panic("test failure");
                expect(vec[64] == false) catch @panic("test failure");
                expect(vec[65] == true) catch @panic("test failure");
                expect(vec[66] == false) catch @panic("test failure");
                expect(vec[67] == true) catch @panic("test failure");
                expect(vec[68] == true) catch @panic("test failure");
                expect(vec[69] == true) catch @panic("test failure");
                expect(vec[70] == true) catch @panic("test failure");
                expect(vec[71] == false) catch @panic("test failure");
                expect(vec[72] == false) catch @panic("test failure");
                expect(vec[73] == false) catch @panic("test failure");
                expect(vec[74] == true) catch @panic("test failure");
                expect(vec[75] == true) catch @panic("test failure");
                expect(vec[76] == false) catch @panic("test failure");
                expect(vec[77] == true) catch @panic("test failure");
                expect(vec[78] == true) catch @panic("test failure");
                expect(vec[79] == true) catch @panic("test failure");
                expect(vec[80] == true) catch @panic("test failure");
                expect(vec[81] == false) catch @panic("test failure");
                expect(vec[82] == true) catch @panic("test failure");
                expect(vec[83] == true) catch @panic("test failure");
                expect(vec[84] == true) catch @panic("test failure");
                expect(vec[85] == true) catch @panic("test failure");
                expect(vec[86] == true) catch @panic("test failure");
                expect(vec[87] == true) catch @panic("test failure");
                expect(vec[88] == false) catch @panic("test failure");
                expect(vec[89] == true) catch @panic("test failure");
                expect(vec[90] == true) catch @panic("test failure");
                expect(vec[91] == true) catch @panic("test failure");
                expect(vec[92] == true) catch @panic("test failure");
                expect(vec[93] == true) catch @panic("test failure");
                expect(vec[94] == true) catch @panic("test failure");
                expect(vec[95] == false) catch @panic("test failure");
                expect(vec[96] == false) catch @panic("test failure");
                expect(vec[97] == false) catch @panic("test failure");
                expect(vec[98] == true) catch @panic("test failure");
                expect(vec[99] == true) catch @panic("test failure");
                expect(vec[100] == true) catch @panic("test failure");
                expect(vec[101] == true) catch @panic("test failure");
                expect(vec[102] == true) catch @panic("test failure");
                expect(vec[103] == true) catch @panic("test failure");
                expect(vec[104] == true) catch @panic("test failure");
                expect(vec[105] == false) catch @panic("test failure");
                expect(vec[106] == false) catch @panic("test failure");
                expect(vec[107] == false) catch @panic("test failure");
                expect(vec[108] == false) catch @panic("test failure");
                expect(vec[109] == false) catch @panic("test failure");
                expect(vec[110] == true) catch @panic("test failure");
                expect(vec[111] == true) catch @panic("test failure");
                expect(vec[112] == true) catch @panic("test failure");
                expect(vec[113] == false) catch @panic("test failure");
                expect(vec[114] == false) catch @panic("test failure");
                expect(vec[115] == false) catch @panic("test failure");
                expect(vec[116] == false) catch @panic("test failure");
                expect(vec[117] == false) catch @panic("test failure");
                expect(vec[118] == true) catch @panic("test failure");
                expect(vec[119] == false) catch @panic("test failure");
                expect(vec[120] == false) catch @panic("test failure");
                expect(vec[121] == false) catch @panic("test failure");
                expect(vec[122] == false) catch @panic("test failure");
                expect(vec[123] == true) catch @panic("test failure");
                expect(vec[124] == true) catch @panic("test failure");
                expect(vec[125] == false) catch @panic("test failure");
                expect(vec[126] == true) catch @panic("test failure");
                expect(vec[127] == false) catch @panic("test failure");
            }

            export fn zig_vector_256_bool(vec: Vector256Bool) void {
                expect(vec[0] == false) catch @panic("test failure");
                expect(vec[1] == false) catch @panic("test failure");
                expect(vec[2] == false) catch @panic("test failure");
                expect(vec[3] == false) catch @panic("test failure");
                expect(vec[4] == true) catch @panic("test failure");
                expect(vec[5] == true) catch @panic("test failure");
                expect(vec[6] == false) catch @panic("test failure");
                expect(vec[7] == false) catch @panic("test failure");
                expect(vec[8] == false) catch @panic("test failure");
                expect(vec[9] == true) catch @panic("test failure");
                expect(vec[10] == true) catch @panic("test failure");
                expect(vec[11] == false) catch @panic("test failure");
                expect(vec[12] == true) catch @panic("test failure");
                expect(vec[13] == false) catch @panic("test failure");
                expect(vec[14] == false) catch @panic("test failure");
                expect(vec[15] == false) catch @panic("test failure");
                expect(vec[16] == false) catch @panic("test failure");
                expect(vec[17] == true) catch @panic("test failure");
                expect(vec[18] == true) catch @panic("test failure");
                expect(vec[19] == true) catch @panic("test failure");
                expect(vec[20] == false) catch @panic("test failure");
                expect(vec[21] == true) catch @panic("test failure");
                expect(vec[22] == true) catch @panic("test failure");
                expect(vec[23] == false) catch @panic("test failure");
                expect(vec[24] == true) catch @panic("test failure");
                expect(vec[25] == false) catch @panic("test failure");
                expect(vec[26] == false) catch @panic("test failure");
                expect(vec[27] == true) catch @panic("test failure");
                expect(vec[28] == true) catch @panic("test failure");
                expect(vec[29] == true) catch @panic("test failure");
                expect(vec[30] == false) catch @panic("test failure");
                expect(vec[31] == true) catch @panic("test failure");
                expect(vec[32] == false) catch @panic("test failure");
                expect(vec[33] == true) catch @panic("test failure");
                expect(vec[34] == false) catch @panic("test failure");
                expect(vec[35] == false) catch @panic("test failure");
                expect(vec[36] == false) catch @panic("test failure");
                expect(vec[37] == true) catch @panic("test failure");
                expect(vec[38] == false) catch @panic("test failure");
                expect(vec[39] == false) catch @panic("test failure");
                expect(vec[40] == true) catch @panic("test failure");
                expect(vec[41] == true) catch @panic("test failure");
                expect(vec[42] == false) catch @panic("test failure");
                expect(vec[43] == true) catch @panic("test failure");
                expect(vec[44] == true) catch @panic("test failure");
                expect(vec[45] == false) catch @panic("test failure");
                expect(vec[46] == true) catch @panic("test failure");
                expect(vec[47] == false) catch @panic("test failure");
                expect(vec[48] == true) catch @panic("test failure");
                expect(vec[49] == false) catch @panic("test failure");
                expect(vec[50] == true) catch @panic("test failure");
                expect(vec[51] == false) catch @panic("test failure");
                expect(vec[52] == true) catch @panic("test failure");
                expect(vec[53] == true) catch @panic("test failure");
                expect(vec[54] == true) catch @panic("test failure");
                expect(vec[55] == false) catch @panic("test failure");
                expect(vec[56] == false) catch @panic("test failure");
                expect(vec[57] == true) catch @panic("test failure");
                expect(vec[58] == true) catch @panic("test failure");
                expect(vec[59] == false) catch @panic("test failure");
                expect(vec[60] == false) catch @panic("test failure");
                expect(vec[61] == true) catch @panic("test failure");
                expect(vec[62] == true) catch @panic("test failure");
                expect(vec[63] == false) catch @panic("test failure");
                expect(vec[64] == false) catch @panic("test failure");
                expect(vec[65] == false) catch @panic("test failure");
                expect(vec[66] == true) catch @panic("test failure");
                expect(vec[67] == true) catch @panic("test failure");
                expect(vec[68] == false) catch @panic("test failure");
                expect(vec[69] == true) catch @panic("test failure");
                expect(vec[70] == false) catch @panic("test failure");
                expect(vec[71] == true) catch @panic("test failure");
                expect(vec[72] == false) catch @panic("test failure");
                expect(vec[73] == true) catch @panic("test failure");
                expect(vec[74] == false) catch @panic("test failure");
                expect(vec[75] == false) catch @panic("test failure");
                expect(vec[76] == true) catch @panic("test failure");
                expect(vec[77] == false) catch @panic("test failure");
                expect(vec[78] == false) catch @panic("test failure");
                expect(vec[79] == false) catch @panic("test failure");
                expect(vec[80] == false) catch @panic("test failure");
                expect(vec[81] == false) catch @panic("test failure");
                expect(vec[82] == true) catch @panic("test failure");
                expect(vec[83] == false) catch @panic("test failure");
                expect(vec[84] == false) catch @panic("test failure");
                expect(vec[85] == false) catch @panic("test failure");
                expect(vec[86] == true) catch @panic("test failure");
                expect(vec[87] == true) catch @panic("test failure");
                expect(vec[88] == true) catch @panic("test failure");
                expect(vec[89] == false) catch @panic("test failure");
                expect(vec[90] == true) catch @panic("test failure");
                expect(vec[91] == false) catch @panic("test failure");
                expect(vec[92] == true) catch @panic("test failure");
                expect(vec[93] == false) catch @panic("test failure");
                expect(vec[94] == true) catch @panic("test failure");
                expect(vec[95] == true) catch @panic("test failure");
                expect(vec[96] == true) catch @panic("test failure");
                expect(vec[97] == true) catch @panic("test failure");
                expect(vec[98] == false) catch @panic("test failure");
                expect(vec[99] == true) catch @panic("test failure");
                expect(vec[100] == false) catch @panic("test failure");
                expect(vec[101] == true) catch @panic("test failure");
                expect(vec[102] == true) catch @panic("test failure");
                expect(vec[103] == false) catch @panic("test failure");
                expect(vec[104] == false) catch @panic("test failure");
                expect(vec[105] == true) catch @panic("test failure");
                expect(vec[106] == false) catch @panic("test failure");
                expect(vec[107] == true) catch @panic("test failure");
                expect(vec[108] == false) catch @panic("test failure");
                expect(vec[109] == false) catch @panic("test failure");
                expect(vec[110] == false) catch @panic("test failure");
                expect(vec[111] == false) catch @panic("test failure");
                expect(vec[112] == false) catch @panic("test failure");
                expect(vec[113] == false) catch @panic("test failure");
                expect(vec[114] == false) catch @panic("test failure");
                expect(vec[115] == false) catch @panic("test failure");
                expect(vec[116] == false) catch @panic("test failure");
                expect(vec[117] == false) catch @panic("test failure");
                expect(vec[118] == false) catch @panic("test failure");
                expect(vec[119] == false) catch @panic("test failure");
                expect(vec[120] == false) catch @panic("test failure");
                expect(vec[121] == false) catch @panic("test failure");
                expect(vec[122] == true) catch @panic("test failure");
                expect(vec[123] == true) catch @panic("test failure");
                expect(vec[124] == false) catch @panic("test failure");
                expect(vec[125] == false) catch @panic("test failure");
                expect(vec[126] == false) catch @panic("test failure");
                expect(vec[127] == true) catch @panic("test failure");
                expect(vec[128] == true) catch @panic("test failure");
                expect(vec[129] == true) catch @panic("test failure");
                expect(vec[130] == true) catch @panic("test failure");
                expect(vec[131] == false) catch @panic("test failure");
                expect(vec[132] == false) catch @panic("test failure");
                expect(vec[133] == false) catch @panic("test failure");
                expect(vec[134] == true) catch @panic("test failure");
                expect(vec[135] == true) catch @panic("test failure");
                expect(vec[136] == false) catch @panic("test failure");
                expect(vec[137] == false) catch @panic("test failure");
                expect(vec[138] == true) catch @panic("test failure");
                expect(vec[139] == true) catch @panic("test failure");
                expect(vec[140] == true) catch @panic("test failure");
                expect(vec[141] == true) catch @panic("test failure");
                expect(vec[142] == true) catch @panic("test failure");
                expect(vec[143] == false) catch @panic("test failure");
                expect(vec[144] == true) catch @panic("test failure");
                expect(vec[145] == true) catch @panic("test failure");
                expect(vec[146] == true) catch @panic("test failure");
                expect(vec[147] == false) catch @panic("test failure");
                expect(vec[148] == false) catch @panic("test failure");
                expect(vec[149] == false) catch @panic("test failure");
                expect(vec[150] == false) catch @panic("test failure");
                expect(vec[151] == false) catch @panic("test failure");
                expect(vec[152] == false) catch @panic("test failure");
                expect(vec[153] == false) catch @panic("test failure");
                expect(vec[154] == true) catch @panic("test failure");
                expect(vec[155] == false) catch @panic("test failure");
                expect(vec[156] == false) catch @panic("test failure");
                expect(vec[157] == false) catch @panic("test failure");
                expect(vec[158] == true) catch @panic("test failure");
                expect(vec[159] == true) catch @panic("test failure");
                expect(vec[160] == false) catch @panic("test failure");
                expect(vec[161] == true) catch @panic("test failure");
                expect(vec[162] == false) catch @panic("test failure");
                expect(vec[163] == false) catch @panic("test failure");
                expect(vec[164] == false) catch @panic("test failure");
                expect(vec[165] == true) catch @panic("test failure");
                expect(vec[166] == false) catch @panic("test failure");
                expect(vec[167] == true) catch @panic("test failure");
                expect(vec[168] == false) catch @panic("test failure");
                expect(vec[169] == false) catch @panic("test failure");
                expect(vec[170] == false) catch @panic("test failure");
                expect(vec[171] == false) catch @panic("test failure");
                expect(vec[172] == true) catch @panic("test failure");
                expect(vec[173] == true) catch @panic("test failure");
                expect(vec[174] == true) catch @panic("test failure");
                expect(vec[175] == true) catch @panic("test failure");
                expect(vec[176] == true) catch @panic("test failure");
                expect(vec[177] == true) catch @panic("test failure");
                expect(vec[178] == false) catch @panic("test failure");
                expect(vec[179] == true) catch @panic("test failure");
                expect(vec[180] == true) catch @panic("test failure");
                expect(vec[181] == false) catch @panic("test failure");
                expect(vec[182] == true) catch @panic("test failure");
                expect(vec[183] == false) catch @panic("test failure");
                expect(vec[184] == true) catch @panic("test failure");
                expect(vec[185] == false) catch @panic("test failure");
                expect(vec[186] == true) catch @panic("test failure");
                expect(vec[187] == false) catch @panic("test failure");
                expect(vec[188] == true) catch @panic("test failure");
                expect(vec[189] == false) catch @panic("test failure");
                expect(vec[190] == false) catch @panic("test failure");
                expect(vec[191] == false) catch @panic("test failure");
                expect(vec[192] == false) catch @panic("test failure");
                expect(vec[193] == true) catch @panic("test failure");
                expect(vec[194] == true) catch @panic("test failure");
                expect(vec[195] == true) catch @panic("test failure");
                expect(vec[196] == false) catch @panic("test failure");
                expect(vec[197] == false) catch @panic("test failure");
                expect(vec[198] == true) catch @panic("test failure");
                expect(vec[199] == false) catch @panic("test failure");
                expect(vec[200] == false) catch @panic("test failure");
                expect(vec[201] == true) catch @panic("test failure");
                expect(vec[202] == true) catch @panic("test failure");
                expect(vec[203] == false) catch @panic("test failure");
                expect(vec[204] == true) catch @panic("test failure");
                expect(vec[205] == false) catch @panic("test failure");
                expect(vec[206] == true) catch @panic("test failure");
                expect(vec[207] == false) catch @panic("test failure");
                expect(vec[208] == false) catch @panic("test failure");
                expect(vec[209] == false) catch @panic("test failure");
                expect(vec[210] == true) catch @panic("test failure");
                expect(vec[211] == true) catch @panic("test failure");
                expect(vec[212] == false) catch @panic("test failure");
                expect(vec[213] == false) catch @panic("test failure");
                expect(vec[214] == false) catch @panic("test failure");
                expect(vec[215] == true) catch @panic("test failure");
                expect(vec[216] == false) catch @panic("test failure");
                expect(vec[217] == true) catch @panic("test failure");
                expect(vec[218] == true) catch @panic("test failure");
                expect(vec[219] == true) catch @panic("test failure");
                expect(vec[220] == false) catch @panic("test failure");
                expect(vec[221] == true) catch @panic("test failure");
                expect(vec[222] == false) catch @panic("test failure");
                expect(vec[223] == true) catch @panic("test failure");
                expect(vec[224] == false) catch @panic("test failure");
                expect(vec[225] == false) catch @panic("test failure");
                expect(vec[226] == false) catch @panic("test failure");
                expect(vec[227] == true) catch @panic("test failure");
                expect(vec[228] == true) catch @panic("test failure");
                expect(vec[229] == false) catch @panic("test failure");
                expect(vec[230] == false) catch @panic("test failure");
                expect(vec[231] == false) catch @panic("test failure");
                expect(vec[232] == false) catch @panic("test failure");
                expect(vec[233] == false) catch @panic("test failure");
                expect(vec[234] == true) catch @panic("test failure");
                expect(vec[235] == false) catch @panic("test failure");
                expect(vec[236] == false) catch @panic("test failure");
                expect(vec[237] == false) catch @panic("test failure");
                expect(vec[238] == true) catch @panic("test failure");
                expect(vec[239] == false) catch @panic("test failure");
                expect(vec[240] == true) catch @panic("test failure");
                expect(vec[241] == true) catch @panic("test failure");
                expect(vec[242] == true) catch @panic("test failure");
                expect(vec[243] == false) catch @panic("test failure");
                expect(vec[244] == false) catch @panic("test failure");
                expect(vec[245] == true) catch @panic("test failure");
                expect(vec[246] == false) catch @panic("test failure");
                expect(vec[247] == false) catch @panic("test failure");
                expect(vec[248] == false) catch @panic("test failure");
                expect(vec[249] == true) catch @panic("test failure");
                expect(vec[250] == false) catch @panic("test failure");
                expect(vec[251] == false) catch @panic("test failure");
                expect(vec[252] == true) catch @panic("test failure");
                expect(vec[253] == true) catch @panic("test failure");
                expect(vec[254] == true) catch @panic("test failure");
                expect(vec[255] == true) catch @panic("test failure");
            }

            export fn zig_vector_512_bool(vec: Vector512Bool) void {
                expect(vec[0] == false) catch @panic("test failure");
                expect(vec[1] == true) catch @panic("test failure");
                expect(vec[2] == true) catch @panic("test failure");
                expect(vec[3] == false) catch @panic("test failure");
                expect(vec[4] == true) catch @panic("test failure");
                expect(vec[5] == false) catch @panic("test failure");
                expect(vec[6] == true) catch @panic("test failure");
                expect(vec[7] == false) catch @panic("test failure");
                expect(vec[8] == false) catch @panic("test failure");
                expect(vec[9] == false) catch @panic("test failure");
                expect(vec[10] == false) catch @panic("test failure");
                expect(vec[11] == false) catch @panic("test failure");
                expect(vec[12] == true) catch @panic("test failure");
                expect(vec[13] == false) catch @panic("test failure");
                expect(vec[14] == true) catch @panic("test failure");
                expect(vec[15] == false) catch @panic("test failure");
                expect(vec[16] == false) catch @panic("test failure");
                expect(vec[17] == false) catch @panic("test failure");
                expect(vec[18] == true) catch @panic("test failure");
                expect(vec[19] == true) catch @panic("test failure");
                expect(vec[20] == true) catch @panic("test failure");
                expect(vec[21] == true) catch @panic("test failure");
                expect(vec[22] == false) catch @panic("test failure");
                expect(vec[23] == false) catch @panic("test failure");
                expect(vec[24] == false) catch @panic("test failure");
                expect(vec[25] == true) catch @panic("test failure");
                expect(vec[26] == true) catch @panic("test failure");
                expect(vec[27] == false) catch @panic("test failure");
                expect(vec[28] == true) catch @panic("test failure");
                expect(vec[29] == true) catch @panic("test failure");
                expect(vec[30] == false) catch @panic("test failure");
                expect(vec[31] == false) catch @panic("test failure");
                expect(vec[32] == true) catch @panic("test failure");
                expect(vec[33] == true) catch @panic("test failure");
                expect(vec[34] == false) catch @panic("test failure");
                expect(vec[35] == false) catch @panic("test failure");
                expect(vec[36] == false) catch @panic("test failure");
                expect(vec[37] == false) catch @panic("test failure");
                expect(vec[38] == false) catch @panic("test failure");
                expect(vec[39] == false) catch @panic("test failure");
                expect(vec[40] == false) catch @panic("test failure");
                expect(vec[41] == true) catch @panic("test failure");
                expect(vec[42] == true) catch @panic("test failure");
                expect(vec[43] == true) catch @panic("test failure");
                expect(vec[44] == false) catch @panic("test failure");
                expect(vec[45] == true) catch @panic("test failure");
                expect(vec[46] == true) catch @panic("test failure");
                expect(vec[47] == true) catch @panic("test failure");
                expect(vec[48] == true) catch @panic("test failure");
                expect(vec[49] == true) catch @panic("test failure");
                expect(vec[50] == false) catch @panic("test failure");
                expect(vec[51] == true) catch @panic("test failure");
                expect(vec[52] == true) catch @panic("test failure");
                expect(vec[53] == true) catch @panic("test failure");
                expect(vec[54] == false) catch @panic("test failure");
                expect(vec[55] == true) catch @panic("test failure");
                expect(vec[56] == false) catch @panic("test failure");
                expect(vec[57] == false) catch @panic("test failure");
                expect(vec[58] == true) catch @panic("test failure");
                expect(vec[59] == false) catch @panic("test failure");
                expect(vec[60] == true) catch @panic("test failure");
                expect(vec[61] == true) catch @panic("test failure");
                expect(vec[62] == false) catch @panic("test failure");
                expect(vec[63] == false) catch @panic("test failure");
                expect(vec[64] == false) catch @panic("test failure");
                expect(vec[65] == true) catch @panic("test failure");
                expect(vec[66] == true) catch @panic("test failure");
                expect(vec[67] == true) catch @panic("test failure");
                expect(vec[68] == true) catch @panic("test failure");
                expect(vec[69] == false) catch @panic("test failure");
                expect(vec[70] == false) catch @panic("test failure");
                expect(vec[71] == true) catch @panic("test failure");
                expect(vec[72] == true) catch @panic("test failure");
                expect(vec[73] == false) catch @panic("test failure");
                expect(vec[74] == true) catch @panic("test failure");
                expect(vec[75] == true) catch @panic("test failure");
                expect(vec[76] == false) catch @panic("test failure");
                expect(vec[77] == false) catch @panic("test failure");
                expect(vec[78] == true) catch @panic("test failure");
                expect(vec[79] == false) catch @panic("test failure");
                expect(vec[80] == false) catch @panic("test failure");
                expect(vec[81] == false) catch @panic("test failure");
                expect(vec[82] == true) catch @panic("test failure");
                expect(vec[83] == true) catch @panic("test failure");
                expect(vec[84] == true) catch @panic("test failure");
                expect(vec[85] == false) catch @panic("test failure");
                expect(vec[86] == false) catch @panic("test failure");
                expect(vec[87] == true) catch @panic("test failure");
                expect(vec[88] == false) catch @panic("test failure");
                expect(vec[89] == true) catch @panic("test failure");
                expect(vec[90] == false) catch @panic("test failure");
                expect(vec[91] == false) catch @panic("test failure");
                expect(vec[92] == true) catch @panic("test failure");
                expect(vec[93] == false) catch @panic("test failure");
                expect(vec[94] == false) catch @panic("test failure");
                expect(vec[95] == true) catch @panic("test failure");
                expect(vec[96] == true) catch @panic("test failure");
                expect(vec[97] == false) catch @panic("test failure");
                expect(vec[98] == false) catch @panic("test failure");
                expect(vec[99] == false) catch @panic("test failure");
                expect(vec[100] == false) catch @panic("test failure");
                expect(vec[101] == true) catch @panic("test failure");
                expect(vec[102] == false) catch @panic("test failure");
                expect(vec[103] == false) catch @panic("test failure");
                expect(vec[104] == false) catch @panic("test failure");
                expect(vec[105] == false) catch @panic("test failure");
                expect(vec[106] == false) catch @panic("test failure");
                expect(vec[107] == false) catch @panic("test failure");
                expect(vec[108] == true) catch @panic("test failure");
                expect(vec[109] == true) catch @panic("test failure");
                expect(vec[110] == true) catch @panic("test failure");
                expect(vec[111] == true) catch @panic("test failure");
                expect(vec[112] == true) catch @panic("test failure");
                expect(vec[113] == false) catch @panic("test failure");
                expect(vec[114] == false) catch @panic("test failure");
                expect(vec[115] == false) catch @panic("test failure");
                expect(vec[116] == false) catch @panic("test failure");
                expect(vec[117] == true) catch @panic("test failure");
                expect(vec[118] == true) catch @panic("test failure");
                expect(vec[119] == false) catch @panic("test failure");
                expect(vec[120] == true) catch @panic("test failure");
                expect(vec[121] == true) catch @panic("test failure");
                expect(vec[122] == false) catch @panic("test failure");
                expect(vec[123] == false) catch @panic("test failure");
                expect(vec[124] == true) catch @panic("test failure");
                expect(vec[125] == false) catch @panic("test failure");
                expect(vec[126] == false) catch @panic("test failure");
                expect(vec[127] == false) catch @panic("test failure");
                expect(vec[128] == false) catch @panic("test failure");
                expect(vec[129] == true) catch @panic("test failure");
                expect(vec[130] == true) catch @panic("test failure");
                expect(vec[131] == true) catch @panic("test failure");
                expect(vec[132] == true) catch @panic("test failure");
                expect(vec[133] == false) catch @panic("test failure");
                expect(vec[134] == false) catch @panic("test failure");
                expect(vec[135] == false) catch @panic("test failure");
                expect(vec[136] == false) catch @panic("test failure");
                expect(vec[137] == true) catch @panic("test failure");
                expect(vec[138] == false) catch @panic("test failure");
                expect(vec[139] == false) catch @panic("test failure");
                expect(vec[140] == false) catch @panic("test failure");
                expect(vec[141] == false) catch @panic("test failure");
                expect(vec[142] == true) catch @panic("test failure");
                expect(vec[143] == true) catch @panic("test failure");
                expect(vec[144] == false) catch @panic("test failure");
                expect(vec[145] == true) catch @panic("test failure");
                expect(vec[146] == false) catch @panic("test failure");
                expect(vec[147] == true) catch @panic("test failure");
                expect(vec[148] == false) catch @panic("test failure");
                expect(vec[149] == false) catch @panic("test failure");
                expect(vec[150] == true) catch @panic("test failure");
                expect(vec[151] == true) catch @panic("test failure");
                expect(vec[152] == false) catch @panic("test failure");
                expect(vec[153] == true) catch @panic("test failure");
                expect(vec[154] == true) catch @panic("test failure");
                expect(vec[155] == false) catch @panic("test failure");
                expect(vec[156] == false) catch @panic("test failure");
                expect(vec[157] == false) catch @panic("test failure");
                expect(vec[158] == true) catch @panic("test failure");
                expect(vec[159] == false) catch @panic("test failure");
                expect(vec[160] == false) catch @panic("test failure");
                expect(vec[161] == false) catch @panic("test failure");
                expect(vec[162] == false) catch @panic("test failure");
                expect(vec[163] == true) catch @panic("test failure");
                expect(vec[164] == true) catch @panic("test failure");
                expect(vec[165] == false) catch @panic("test failure");
                expect(vec[166] == false) catch @panic("test failure");
                expect(vec[167] == true) catch @panic("test failure");
                expect(vec[168] == false) catch @panic("test failure");
                expect(vec[169] == true) catch @panic("test failure");
                expect(vec[170] == true) catch @panic("test failure");
                expect(vec[171] == false) catch @panic("test failure");
                expect(vec[172] == false) catch @panic("test failure");
                expect(vec[173] == false) catch @panic("test failure");
                expect(vec[174] == false) catch @panic("test failure");
                expect(vec[175] == false) catch @panic("test failure");
                expect(vec[176] == false) catch @panic("test failure");
                expect(vec[177] == true) catch @panic("test failure");
                expect(vec[178] == false) catch @panic("test failure");
                expect(vec[179] == false) catch @panic("test failure");
                expect(vec[180] == false) catch @panic("test failure");
                expect(vec[181] == false) catch @panic("test failure");
                expect(vec[182] == false) catch @panic("test failure");
                expect(vec[183] == false) catch @panic("test failure");
                expect(vec[184] == true) catch @panic("test failure");
                expect(vec[185] == false) catch @panic("test failure");
                expect(vec[186] == false) catch @panic("test failure");
                expect(vec[187] == false) catch @panic("test failure");
                expect(vec[188] == false) catch @panic("test failure");
                expect(vec[189] == true) catch @panic("test failure");
                expect(vec[190] == false) catch @panic("test failure");
                expect(vec[191] == false) catch @panic("test failure");
                expect(vec[192] == false) catch @panic("test failure");
                expect(vec[193] == false) catch @panic("test failure");
                expect(vec[194] == false) catch @panic("test failure");
                expect(vec[195] == false) catch @panic("test failure");
                expect(vec[196] == true) catch @panic("test failure");
                expect(vec[197] == true) catch @panic("test failure");
                expect(vec[198] == true) catch @panic("test failure");
                expect(vec[199] == false) catch @panic("test failure");
                expect(vec[200] == true) catch @panic("test failure");
                expect(vec[201] == true) catch @panic("test failure");
                expect(vec[202] == false) catch @panic("test failure");
                expect(vec[203] == false) catch @panic("test failure");
                expect(vec[204] == false) catch @panic("test failure");
                expect(vec[205] == false) catch @panic("test failure");
                expect(vec[206] == false) catch @panic("test failure");
                expect(vec[207] == true) catch @panic("test failure");
                expect(vec[208] == true) catch @panic("test failure");
                expect(vec[209] == false) catch @panic("test failure");
                expect(vec[210] == false) catch @panic("test failure");
                expect(vec[211] == false) catch @panic("test failure");
                expect(vec[212] == true) catch @panic("test failure");
                expect(vec[213] == false) catch @panic("test failure");
                expect(vec[214] == false) catch @panic("test failure");
                expect(vec[215] == true) catch @panic("test failure");
                expect(vec[216] == true) catch @panic("test failure");
                expect(vec[217] == true) catch @panic("test failure");
                expect(vec[218] == false) catch @panic("test failure");
                expect(vec[219] == false) catch @panic("test failure");
                expect(vec[220] == true) catch @panic("test failure");
                expect(vec[221] == false) catch @panic("test failure");
                expect(vec[222] == true) catch @panic("test failure");
                expect(vec[223] == true) catch @panic("test failure");
                expect(vec[224] == true) catch @panic("test failure");
                expect(vec[225] == true) catch @panic("test failure");
                expect(vec[226] == false) catch @panic("test failure");
                expect(vec[227] == true) catch @panic("test failure");
                expect(vec[228] == false) catch @panic("test failure");
                expect(vec[229] == false) catch @panic("test failure");
                expect(vec[230] == false) catch @panic("test failure");
                expect(vec[231] == true) catch @panic("test failure");
                expect(vec[232] == false) catch @panic("test failure");
                expect(vec[233] == false) catch @panic("test failure");
                expect(vec[234] == false) catch @panic("test failure");
                expect(vec[235] == false) catch @panic("test failure");
                expect(vec[236] == false) catch @panic("test failure");
                expect(vec[237] == false) catch @panic("test failure");
                expect(vec[238] == false) catch @panic("test failure");
                expect(vec[239] == true) catch @panic("test failure");
                expect(vec[240] == false) catch @panic("test failure");
                expect(vec[241] == false) catch @panic("test failure");
                expect(vec[242] == false) catch @panic("test failure");
                expect(vec[243] == true) catch @panic("test failure");
                expect(vec[244] == true) catch @panic("test failure");
                expect(vec[245] == true) catch @panic("test failure");
                expect(vec[246] == true) catch @panic("test failure");
                expect(vec[247] == false) catch @panic("test failure");
                expect(vec[248] == true) catch @panic("test failure");
                expect(vec[249] == true) catch @panic("test failure");
                expect(vec[250] == false) catch @panic("test failure");
                expect(vec[251] == false) catch @panic("test failure");
                expect(vec[252] == false) catch @panic("test failure");
                expect(vec[253] == true) catch @panic("test failure");
                expect(vec[254] == false) catch @panic("test failure");
                expect(vec[255] == false) catch @panic("test failure");
                expect(vec[256] == true) catch @panic("test failure");
                expect(vec[257] == true) catch @panic("test failure");
                expect(vec[258] == false) catch @panic("test failure");
                expect(vec[259] == true) catch @panic("test failure");
                expect(vec[260] == false) catch @panic("test failure");
                expect(vec[261] == true) catch @panic("test failure");
                expect(vec[262] == true) catch @panic("test failure");
                expect(vec[263] == false) catch @panic("test failure");
                expect(vec[264] == false) catch @panic("test failure");
                expect(vec[265] == false) catch @panic("test failure");
                expect(vec[266] == false) catch @panic("test failure");
                expect(vec[267] == true) catch @panic("test failure");
                expect(vec[268] == false) catch @panic("test failure");
                expect(vec[269] == true) catch @panic("test failure");
                expect(vec[270] == true) catch @panic("test failure");
                expect(vec[271] == false) catch @panic("test failure");
                expect(vec[272] == false) catch @panic("test failure");
                expect(vec[273] == true) catch @panic("test failure");
                expect(vec[274] == true) catch @panic("test failure");
                expect(vec[275] == true) catch @panic("test failure");
                expect(vec[276] == false) catch @panic("test failure");
                expect(vec[277] == true) catch @panic("test failure");
                expect(vec[278] == false) catch @panic("test failure");
                expect(vec[279] == false) catch @panic("test failure");
                expect(vec[280] == true) catch @panic("test failure");
                expect(vec[281] == true) catch @panic("test failure");
                expect(vec[282] == false) catch @panic("test failure");
                expect(vec[283] == true) catch @panic("test failure");
                expect(vec[284] == false) catch @panic("test failure");
                expect(vec[285] == true) catch @panic("test failure");
                expect(vec[286] == true) catch @panic("test failure");
                expect(vec[287] == true) catch @panic("test failure");
                expect(vec[288] == true) catch @panic("test failure");
                expect(vec[289] == true) catch @panic("test failure");
                expect(vec[290] == true) catch @panic("test failure");
                expect(vec[291] == true) catch @panic("test failure");
                expect(vec[292] == true) catch @panic("test failure");
                expect(vec[293] == true) catch @panic("test failure");
                expect(vec[294] == true) catch @panic("test failure");
                expect(vec[295] == false) catch @panic("test failure");
                expect(vec[296] == true) catch @panic("test failure");
                expect(vec[297] == false) catch @panic("test failure");
                expect(vec[298] == true) catch @panic("test failure");
                expect(vec[299] == false) catch @panic("test failure");
                expect(vec[300] == true) catch @panic("test failure");
                expect(vec[301] == true) catch @panic("test failure");
                expect(vec[302] == false) catch @panic("test failure");
                expect(vec[303] == true) catch @panic("test failure");
                expect(vec[304] == false) catch @panic("test failure");
                expect(vec[305] == true) catch @panic("test failure");
                expect(vec[306] == false) catch @panic("test failure");
                expect(vec[307] == true) catch @panic("test failure");
                expect(vec[308] == true) catch @panic("test failure");
                expect(vec[309] == false) catch @panic("test failure");
                expect(vec[310] == true) catch @panic("test failure");
                expect(vec[311] == true) catch @panic("test failure");
                expect(vec[312] == true) catch @panic("test failure");
                expect(vec[313] == false) catch @panic("test failure");
                expect(vec[314] == false) catch @panic("test failure");
                expect(vec[315] == false) catch @panic("test failure");
                expect(vec[316] == false) catch @panic("test failure");
                expect(vec[317] == true) catch @panic("test failure");
                expect(vec[318] == true) catch @panic("test failure");
                expect(vec[319] == true) catch @panic("test failure");
                expect(vec[320] == true) catch @panic("test failure");
                expect(vec[321] == true) catch @panic("test failure");
                expect(vec[322] == true) catch @panic("test failure");
                expect(vec[323] == true) catch @panic("test failure");
                expect(vec[324] == true) catch @panic("test failure");
                expect(vec[325] == true) catch @panic("test failure");
                expect(vec[326] == false) catch @panic("test failure");
                expect(vec[327] == true) catch @panic("test failure");
                expect(vec[328] == false) catch @panic("test failure");
                expect(vec[329] == false) catch @panic("test failure");
                expect(vec[330] == true) catch @panic("test failure");
                expect(vec[331] == false) catch @panic("test failure");
                expect(vec[332] == false) catch @panic("test failure");
                expect(vec[333] == false) catch @panic("test failure");
                expect(vec[334] == false) catch @panic("test failure");
                expect(vec[335] == false) catch @panic("test failure");
                expect(vec[336] == false) catch @panic("test failure");
                expect(vec[337] == false) catch @panic("test failure");
                expect(vec[338] == false) catch @panic("test failure");
                expect(vec[339] == false) catch @panic("test failure");
                expect(vec[340] == false) catch @panic("test failure");
                expect(vec[341] == false) catch @panic("test failure");
                expect(vec[342] == true) catch @panic("test failure");
                expect(vec[343] == true) catch @panic("test failure");
                expect(vec[344] == false) catch @panic("test failure");
                expect(vec[345] == false) catch @panic("test failure");
                expect(vec[346] == false) catch @panic("test failure");
                expect(vec[347] == false) catch @panic("test failure");
                expect(vec[348] == false) catch @panic("test failure");
                expect(vec[349] == true) catch @panic("test failure");
                expect(vec[350] == true) catch @panic("test failure");
                expect(vec[351] == true) catch @panic("test failure");
                expect(vec[352] == true) catch @panic("test failure");
                expect(vec[353] == false) catch @panic("test failure");
                expect(vec[354] == false) catch @panic("test failure");
                expect(vec[355] == false) catch @panic("test failure");
                expect(vec[356] == false) catch @panic("test failure");
                expect(vec[357] == true) catch @panic("test failure");
                expect(vec[358] == true) catch @panic("test failure");
                expect(vec[359] == false) catch @panic("test failure");
                expect(vec[360] == false) catch @panic("test failure");
                expect(vec[361] == false) catch @panic("test failure");
                expect(vec[362] == true) catch @panic("test failure");
                expect(vec[363] == true) catch @panic("test failure");
                expect(vec[364] == false) catch @panic("test failure");
                expect(vec[365] == false) catch @panic("test failure");
                expect(vec[366] == false) catch @panic("test failure");
                expect(vec[367] == false) catch @panic("test failure");
                expect(vec[368] == false) catch @panic("test failure");
                expect(vec[369] == true) catch @panic("test failure");
                expect(vec[370] == true) catch @panic("test failure");
                expect(vec[371] == false) catch @panic("test failure");
                expect(vec[372] == true) catch @panic("test failure");
                expect(vec[373] == true) catch @panic("test failure");
                expect(vec[374] == false) catch @panic("test failure");
                expect(vec[375] == true) catch @panic("test failure");
                expect(vec[376] == true) catch @panic("test failure");
                expect(vec[377] == false) catch @panic("test failure");
                expect(vec[378] == true) catch @panic("test failure");
                expect(vec[379] == true) catch @panic("test failure");
                expect(vec[380] == false) catch @panic("test failure");
                expect(vec[381] == true) catch @panic("test failure");
                expect(vec[382] == true) catch @panic("test failure");
                expect(vec[383] == false) catch @panic("test failure");
                expect(vec[384] == true) catch @panic("test failure");
                expect(vec[385] == false) catch @panic("test failure");
                expect(vec[386] == true) catch @panic("test failure");
                expect(vec[387] == true) catch @panic("test failure");
                expect(vec[388] == true) catch @panic("test failure");
                expect(vec[389] == true) catch @panic("test failure");
                expect(vec[390] == false) catch @panic("test failure");
                expect(vec[391] == false) catch @panic("test failure");
                expect(vec[392] == false) catch @panic("test failure");
                expect(vec[393] == true) catch @panic("test failure");
                expect(vec[394] == true) catch @panic("test failure");
                expect(vec[395] == true) catch @panic("test failure");
                expect(vec[396] == true) catch @panic("test failure");
                expect(vec[397] == false) catch @panic("test failure");
                expect(vec[398] == true) catch @panic("test failure");
                expect(vec[399] == true) catch @panic("test failure");
                expect(vec[400] == true) catch @panic("test failure");
                expect(vec[401] == false) catch @panic("test failure");
                expect(vec[402] == false) catch @panic("test failure");
                expect(vec[403] == true) catch @panic("test failure");
                expect(vec[404] == false) catch @panic("test failure");
                expect(vec[405] == false) catch @panic("test failure");
                expect(vec[406] == false) catch @panic("test failure");
                expect(vec[407] == true) catch @panic("test failure");
                expect(vec[408] == true) catch @panic("test failure");
                expect(vec[409] == true) catch @panic("test failure");
                expect(vec[410] == false) catch @panic("test failure");
                expect(vec[411] == true) catch @panic("test failure");
                expect(vec[412] == false) catch @panic("test failure");
                expect(vec[413] == false) catch @panic("test failure");
                expect(vec[414] == false) catch @panic("test failure");
                expect(vec[415] == true) catch @panic("test failure");
                expect(vec[416] == false) catch @panic("test failure");
                expect(vec[417] == false) catch @panic("test failure");
                expect(vec[418] == true) catch @panic("test failure");
                expect(vec[419] == true) catch @panic("test failure");
                expect(vec[420] == true) catch @panic("test failure");
                expect(vec[421] == true) catch @panic("test failure");
                expect(vec[422] == false) catch @panic("test failure");
                expect(vec[423] == true) catch @panic("test failure");
                expect(vec[424] == true) catch @panic("test failure");
                expect(vec[425] == false) catch @panic("test failure");
                expect(vec[426] == false) catch @panic("test failure");
                expect(vec[427] == false) catch @panic("test failure");
                expect(vec[428] == true) catch @panic("test failure");
                expect(vec[429] == false) catch @panic("test failure");
                expect(vec[430] == true) catch @panic("test failure");
                expect(vec[431] == true) catch @panic("test failure");
                expect(vec[432] == false) catch @panic("test failure");
                expect(vec[433] == false) catch @panic("test failure");
                expect(vec[434] == false) catch @panic("test failure");
                expect(vec[435] == false) catch @panic("test failure");
                expect(vec[436] == true) catch @panic("test failure");
                expect(vec[437] == false) catch @panic("test failure");
                expect(vec[438] == true) catch @panic("test failure");
                expect(vec[439] == false) catch @panic("test failure");
                expect(vec[440] == false) catch @panic("test failure");
                expect(vec[441] == false) catch @panic("test failure");
                expect(vec[442] == false) catch @panic("test failure");
                expect(vec[443] == true) catch @panic("test failure");
                expect(vec[444] == false) catch @panic("test failure");
                expect(vec[445] == false) catch @panic("test failure");
                expect(vec[446] == true) catch @panic("test failure");
                expect(vec[447] == true) catch @panic("test failure");
                expect(vec[448] == true) catch @panic("test failure");
                expect(vec[449] == false) catch @panic("test failure");
                expect(vec[450] == true) catch @panic("test failure");
                expect(vec[451] == true) catch @panic("test failure");
                expect(vec[452] == false) catch @panic("test failure");
                expect(vec[453] == true) catch @panic("test failure");
                expect(vec[454] == false) catch @panic("test failure");
                expect(vec[455] == true) catch @panic("test failure");
                expect(vec[456] == false) catch @panic("test failure");
                expect(vec[457] == false) catch @panic("test failure");
                expect(vec[458] == false) catch @panic("test failure");
                expect(vec[459] == true) catch @panic("test failure");
                expect(vec[460] == false) catch @panic("test failure");
                expect(vec[461] == false) catch @panic("test failure");
                expect(vec[462] == false) catch @panic("test failure");
                expect(vec[463] == true) catch @panic("test failure");
                expect(vec[464] == true) catch @panic("test failure");
                expect(vec[465] == true) catch @panic("test failure");
                expect(vec[466] == true) catch @panic("test failure");
                expect(vec[467] == true) catch @panic("test failure");
                expect(vec[468] == false) catch @panic("test failure");
                expect(vec[469] == false) catch @panic("test failure");
                expect(vec[470] == false) catch @panic("test failure");
                expect(vec[471] == false) catch @panic("test failure");
                expect(vec[472] == false) catch @panic("test failure");
                expect(vec[473] == false) catch @panic("test failure");
                expect(vec[474] == true) catch @panic("test failure");
                expect(vec[475] == true) catch @panic("test failure");
                expect(vec[476] == true) catch @panic("test failure");
                expect(vec[477] == true) catch @panic("test failure");
                expect(vec[478] == true) catch @panic("test failure");
                expect(vec[479] == false) catch @panic("test failure");
                expect(vec[480] == true) catch @panic("test failure");
                expect(vec[481] == true) catch @panic("test failure");
                expect(vec[482] == false) catch @panic("test failure");
                expect(vec[483] == true) catch @panic("test failure");
                expect(vec[484] == false) catch @panic("test failure");
                expect(vec[485] == true) catch @panic("test failure");
                expect(vec[486] == false) catch @panic("test failure");
                expect(vec[487] == true) catch @panic("test failure");
                expect(vec[488] == false) catch @panic("test failure");
                expect(vec[489] == false) catch @panic("test failure");
                expect(vec[490] == false) catch @panic("test failure");
                expect(vec[491] == true) catch @panic("test failure");
                expect(vec[492] == false) catch @panic("test failure");
                expect(vec[493] == false) catch @panic("test failure");
                expect(vec[494] == false) catch @panic("test failure");
                expect(vec[495] == true) catch @panic("test failure");
                expect(vec[496] == true) catch @panic("test failure");
                expect(vec[497] == false) catch @panic("test failure");
                expect(vec[498] == false) catch @panic("test failure");
                expect(vec[499] == true) catch @panic("test failure");
                expect(vec[500] == false) catch @panic("test failure");
                expect(vec[501] == true) catch @panic("test failure");
                expect(vec[502] == false) catch @panic("test failure");
                expect(vec[503] == false) catch @panic("test failure");
                expect(vec[504] == false) catch @panic("test failure");
                expect(vec[505] == true) catch @panic("test failure");
                expect(vec[506] == true) catch @panic("test failure");
                expect(vec[507] == true) catch @panic("test failure");
                expect(vec[508] == true) catch @panic("test failure");
                expect(vec[509] == false) catch @panic("test failure");
                expect(vec[510] == false) catch @panic("test failure");
                expect(vec[511] == true) catch @panic("test failure");
            }

            export fn zig_ret_vector_2_bool() Vector2Bool {
                return .{
                    false,
                    false,
                };
            }

            export fn zig_ret_vector_4_bool() Vector4Bool {
                return .{
                    false,
                    true,
                    true,
                    true,
                };
            }

            export fn zig_ret_vector_8_bool() Vector8Bool {
                return .{
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                };
            }

            export fn zig_ret_vector_16_bool() Vector16Bool {
                return .{
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                };
            }

            export fn zig_ret_vector_32_bool() Vector32Bool {
                return .{
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                };
            }

            export fn zig_ret_vector_64_bool() Vector64Bool {
                return .{
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                };
            }

            export fn zig_ret_vector_128_bool() Vector128Bool {
                return .{
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                };
            }

            export fn zig_ret_vector_256_bool() Vector256Bool {
                return .{
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                };
            }

            export fn zig_ret_vector_512_bool() Vector512Bool {
                return .{
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    false,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                    false,
                    false,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    false,
                    true,
                    false,
                    true,
                    true,
                    true,
                    true,
                    false,
                    false,
                    true,
                    true,
                    false,
                    false,
                };
            }
        };
    }
}

const Vector2 = extern struct { x: f32, y: f32 };

extern fn c_ptr_size_float_struct(Vector2) void;
extern fn c_ret_ptr_size_float_struct() Vector2;

test "C ABI pointer sized float struct" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    c_ptr_size_float_struct(.{ .x = 1, .y = 2 });

    const x = c_ret_ptr_size_float_struct();
    try expect(x.x == 3);
    try expect(x.y == 4);
}

//=== Helpers for struct test ===//
pub inline fn expectOk(c_err: c_int) !void {
    if (c_err != 0) {
        std.debug.print("ABI mismatch on field v{d}.\n", .{c_err});
        return error.TestExpectedEqual;
    }
}

/// Tests for Double + Char struct
const DC = extern struct { v1: f64, v2: u8 };
test "DC: Zig passes to C" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_DC(.{ .v1 = -0.25, .v2 = 15 }));
}
test "DC: Zig returns to C" {
    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_ret_DC());
}
test "DC: C passes to Zig" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_send_DC());
}
test "DC: C returns to Zig" {
    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectEqual(DC{ .v1 = -0.25, .v2 = 15 }, c_ret_DC());
}

pub extern fn c_assert_DC(lv: DC) c_int;
pub extern fn c_assert_ret_DC() c_int;
pub extern fn c_send_DC() c_int;
pub extern fn c_ret_DC() DC;
pub export fn zig_assert_DC(lv: DC) c_int {
    var err: c_int = 0;
    if (lv.v1 != -0.25) err = 1;
    if (lv.v2 != 15) err = 2;
    if (err != 0) std.debug.print("Received {}", .{lv});
    return err;
}
pub export fn zig_ret_DC() DC {
    return .{ .v1 = -0.25, .v2 = 15 };
}

/// Tests for Char + Float + FloatRect struct
const CFF = extern struct { v1: u8, v2: f32, v3: f32 };

test "CFF: Zig passes to C" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_CFF(.{ .v1 = 39, .v2 = 0.875, .v3 = 1.0 }));
}
test "CFF: Zig returns to C" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_ret_CFF());
}
test "CFF: C passes to Zig" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch == .aarch64 and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    try expectOk(c_send_CFF());
}
test "CFF: C returns to Zig" {
    if (builtin.cpu.arch == .aarch64 and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isRISCV() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectEqual(CFF{ .v1 = 39, .v2 = 0.875, .v3 = 1.0 }, c_ret_CFF());
}
pub extern fn c_assert_CFF(lv: CFF) c_int;
pub extern fn c_assert_ret_CFF() c_int;
pub extern fn c_send_CFF() c_int;
pub extern fn c_ret_CFF() CFF;
pub export fn zig_assert_CFF(lv: CFF) c_int {
    var err: c_int = 0;
    if (lv.v1 != 39) err = 1;
    if (lv.v2 != 0.875) err = 2;
    if (lv.v3 != 1.0) err = 3;
    if (err != 0) std.debug.print("Received {}", .{lv});
    return err;
}
pub export fn zig_ret_CFF() CFF {
    return .{ .v1 = 39, .v2 = 0.875, .v3 = 1.0 };
}

/// Tests for Pointer + Double struct
const PD = extern struct { v1: ?*anyopaque, v2: f64 };

test "PD: Zig passes to C" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_PD(.{ .v1 = null, .v2 = 0.5 }));
}
test "PD: Zig returns to C" {
    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_assert_ret_PD());
}
test "PD: C passes to Zig" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectOk(c_send_PD());
}
test "PD: C returns to Zig" {
    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;
    try expectEqual(PD{ .v1 = null, .v2 = 0.5 }, c_ret_PD());
}
pub extern fn c_assert_PD(lv: PD) c_int;
pub extern fn c_assert_ret_PD() c_int;
pub extern fn c_send_PD() c_int;
pub extern fn c_ret_PD() PD;
pub export fn zig_c_assert_PD(lv: PD) c_int {
    var err: c_int = 0;
    if (lv.v1 != null) err = 1;
    if (lv.v2 != 0.5) err = 2;
    if (err != 0) std.debug.print("Received {}", .{lv});
    return err;
}
pub export fn zig_ret_PD() PD {
    return .{ .v1 = null, .v2 = 0.5 };
}
pub export fn zig_assert_PD(lv: PD) c_int {
    var err: c_int = 0;
    if (lv.v1 != null) err = 1;
    if (lv.v2 != 0.5) err = 2;
    if (err != 0) std.debug.print("Received {}", .{lv});
    return err;
}

const ByRef = extern struct {
    val: c_int,
    arr: [15]c_int,
};
extern fn c_modify_by_ref_param(ByRef) ByRef;

test "C function modifies by ref param" {
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const res = c_modify_by_ref_param(.{ .val = 1, .arr = undefined });
    try expect(res.val == 42);
}

const ByVal = extern struct {
    origin: extern struct {
        x: c_ulong,
        y: c_ulong,
        z: c_ulong,
    },
    size: extern struct {
        width: c_ulong,
        height: c_ulong,
        depth: c_ulong,
    },
};

extern fn c_func_ptr_byval(*anyopaque, *anyopaque, ByVal, c_ulong, *anyopaque, c_ulong) void;
test "C function that takes byval struct called via function pointer" {
    if (builtin.cpu.arch.isMIPS64() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    var fn_ptr = &c_func_ptr_byval;
    _ = &fn_ptr;
    fn_ptr(
        @as(*anyopaque, @ptrFromInt(1)),
        @as(*anyopaque, @ptrFromInt(2)),
        ByVal{
            .origin = .{ .x = 9, .y = 10, .z = 11 },
            .size = .{ .width = 12, .height = 13, .depth = 14 },
        },
        @as(c_ulong, 3),
        @as(*anyopaque, @ptrFromInt(4)),
        @as(c_ulong, 5),
    );
}

extern fn c_f16(f16) f16;
test "f16 bare" {
    if (!builtin.cpu.arch.isAARCH64()) return error.SkipZigTest;

    const a = c_f16(12);
    try expect(a == 34);
}

const f16_struct = extern struct {
    a: f16,
};
extern fn c_f16_struct(f16_struct) f16_struct;
test "f16 struct" {
    if (builtin.target.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.target.cpu.arch.isPowerPC32()) return error.SkipZigTest;
    if (builtin.cpu.arch.isARM() and builtin.mode != .Debug) return error.SkipZigTest;

    const a = c_f16_struct(.{ .a = 12 });
    try expect(a.a == 34);
}

extern fn c_f80(f80) f80;
test "f80 bare" {
    if (!have_f80) return error.SkipZigTest;

    const a = c_f80(12.34);
    try expect(@as(f64, @floatCast(a)) == 56.78);
}

const f80_struct = extern struct {
    a: f80,
};
extern fn c_f80_struct(f80_struct) f80_struct;
test "f80 struct" {
    if (!have_f80) return error.SkipZigTest;

    const a = c_f80_struct(.{ .a = 12.34 });
    try expect(@as(f64, @floatCast(a.a)) == 56.78);
}

const f80_extra_struct = extern struct {
    a: f80,
    b: c_int,
};
extern fn c_f80_extra_struct(f80_extra_struct) f80_extra_struct;
test "f80 extra struct" {
    if (!have_f80) return error.SkipZigTest;

    const a = c_f80_extra_struct(.{ .a = 12.34, .b = 42 });
    try expect(@as(f64, @floatCast(a.a)) == 56.78);
    try expect(a.b == 24);
}

comptime {
    skip: {
        if (builtin.target.isWasm()) break :skip;

        _ = struct {
            export fn zig_f128(x: f128) f128 {
                expect(x == 12) catch @panic("test failure");
                return 34;
            }
            extern fn c_f128(f128) f128;
            test "f128 bare" {
                if (!have_f128) return error.SkipZigTest;

                const a = c_f128(12.34);
                try expect(@as(f64, @floatCast(a)) == 56.78);
            }

            const f128_struct = extern struct {
                a: f128,
            };
            export fn zig_f128_struct(a: f128_struct) f128_struct {
                expect(a.a == 12345) catch @panic("test failure");
                return .{ .a = 98765 };
            }
            extern fn c_f128_struct(f128_struct) f128_struct;
            test "f128 struct" {
                if (!have_f128) return error.SkipZigTest;

                const a = c_f128_struct(.{ .a = 12.34 });
                try expect(@as(f64, @floatCast(a.a)) == 56.78);

                const b = c_f128_f128_struct(.{ .a = 12.34, .b = 87.65 });
                try expect(@as(f64, @floatCast(b.a)) == 56.78);
                try expect(@as(f64, @floatCast(b.b)) == 43.21);
            }

            const f128_f128_struct = extern struct {
                a: f128,
                b: f128,
            };
            export fn zig_f128_f128_struct(a: f128_f128_struct) f128_f128_struct {
                expect(a.a == 13) catch @panic("test failure");
                expect(a.b == 57) catch @panic("test failure");
                return .{ .a = 24, .b = 68 };
            }
            extern fn c_f128_f128_struct(f128_f128_struct) f128_f128_struct;
            test "f128 f128 struct" {
                if (!have_f128) return error.SkipZigTest;

                const a = c_f128_struct(.{ .a = 12.34 });
                try expect(@as(f64, @floatCast(a.a)) == 56.78);

                const b = c_f128_f128_struct(.{ .a = 12.34, .b = 87.65 });
                try expect(@as(f64, @floatCast(b.a)) == 56.78);
                try expect(@as(f64, @floatCast(b.b)) == 43.21);
            }
        };
    }
}

// The stdcall attribute on C functions is ignored when compiled on non-x86
const stdcall_callconv: std.builtin.CallingConvention = if (builtin.cpu.arch == .x86) .Stdcall else .C;

extern fn stdcall_scalars(i8, i16, i32, f32, f64) callconv(stdcall_callconv) void;
test "Stdcall ABI scalars" {
    stdcall_scalars(1, 2, 3, 4.0, 5.0);
}

const Coord2 = extern struct {
    x: i16,
    y: i16,
};

extern fn stdcall_coord2(Coord2, Coord2, Coord2) callconv(stdcall_callconv) Coord2;
test "Stdcall ABI structs" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC()) return error.SkipZigTest;

    const res = stdcall_coord2(
        .{ .x = 0x1111, .y = 0x2222 },
        .{ .x = 0x3333, .y = 0x4444 },
        .{ .x = 0x5555, .y = 0x6666 },
    );
    try expect(res.x == 123);
    try expect(res.y == 456);
}

extern fn stdcall_big_union(BigUnion) callconv(stdcall_callconv) void;
test "Stdcall ABI big union" {
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    const x = BigUnion{
        .a = BigStruct{
            .a = 1,
            .b = 2,
            .c = 3,
            .d = 4,
            .e = 5,
        },
    };
    stdcall_big_union(x);
}

extern fn c_explict_win64(ByRef) callconv(.Win64) ByRef;
test "explicit SysV calling convention" {
    if (builtin.cpu.arch != .x86_64) return error.SkipZigTest;

    const res = c_explict_win64(.{ .val = 1, .arr = undefined });
    try expect(res.val == 42);
}

extern fn c_explict_sys_v(ByRef) callconv(.SysV) ByRef;
test "explicit Win64 calling convention" {
    if (builtin.cpu.arch != .x86_64) return error.SkipZigTest;

    const res = c_explict_sys_v(.{ .val = 1, .arr = undefined });
    try expect(res.val == 42);
}

const byval_tail_callsite_attr = struct {
    const struct_Point = extern struct {
        x: f64,
        y: f64,
    };
    const struct_Size = extern struct {
        width: f64,
        height: f64,
    };
    const struct_Rect = extern struct {
        origin: struct_Point,
        size: struct_Size,
    };

    const Point = extern struct {
        x: f64,
        y: f64,
    };

    const Size = extern struct {
        width: f64,
        height: f64,
    };

    const MyRect = extern struct {
        origin: Point,
        size: Size,

        fn run(self: MyRect) f64 {
            return c_byval_tail_callsite_attr(cast(self));
        }

        fn cast(self: MyRect) struct_Rect {
            return @bitCast(self);
        }

        extern fn c_byval_tail_callsite_attr(struct_Rect) f64;
    };
};

test "byval tail callsite attribute" {
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest;
    if (builtin.cpu.arch.isPowerPC32()) return error.SkipZigTest;

    // Originally reported at https://github.com/ziglang/zig/issues/16290
    // the bug was that the extern function had the byval attribute, but
    // zig did not put the byval attribute at the callsite. Some LLVM optimization
    // passes would then pass undefined for that parameter.
    var v: byval_tail_callsite_attr.MyRect = .{
        .origin = .{ .x = 1, .y = 2 },
        .size = .{ .width = 3, .height = 4 },
    };
    try expect(v.run() == 3.0);
}
