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
const has_i128 = builtin.cpu.arch != .x86 and !builtin.cpu.arch.isARM() and
    !builtin.cpu.arch.isMIPS() and !builtin.cpu.arch.isPPC();

const has_f128 = builtin.cpu.arch.isX86() and !builtin.os.tag.isDarwin();
const has_f80 = builtin.cpu.arch.isX86();

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
    if (has_i128) c_struct_u128(.{ .value = 0xfffffffffffffffc });

    c_i8(-1);
    c_i16(-2);
    c_i32(-3);
    c_i64(-4);
    if (has_i128) c_struct_i128(.{ .value = -6 });
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
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

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
    !builtin.cpu.arch.isARM() and !builtin.cpu.arch.isPPC() and !builtin.cpu.arch.isRISCV();

test "C ABI complex float" {
    if (!complex_abi_compatible) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .x86_64) return error.SkipZigTest; // See https://github.com/ziglang/zig/issues/8465

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

const BigStruct = extern struct {
    a: u64,
    b: u64,
    c: u64,
    d: u64,
    e: u8,
};
extern fn c_big_struct(BigStruct) void;

test "C ABI big struct" {
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    var s = MedStructMixed{
        .a = 1234,
        .b = 100.0,
        .c = 1337.0,
    };
    c_med_struct_mixed(s);
    var s2 = c_ret_med_struct_mixed();
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    var s = SmallStructInts{
        .a = 1,
        .b = 2,
        .c = 3,
        .d = 4,
    };
    c_small_struct_ints(s);
    var s2 = c_ret_small_struct_ints();
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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    var s = MedStructInts{
        .x = 1,
        .y = 2,
        .z = 3,
    };
    c_med_struct_ints(s);
    var s2 = c_ret_med_struct_ints();
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
    if (!has_i128) return error.SkipZigTest;

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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

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
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    var s = SplitStructMixed{
        .a = 1234,
        .b = 100,
        .c = 1337.0,
    };
    c_split_struct_mixed(s);
    var s2 = c_ret_split_struct_mixed();
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    c_struct_with_array(.{ .a = 1, .padding = undefined, .b = 2 });

    var x = c_ret_struct_with_array();
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
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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

    var x = c_ret_float_array_struct();
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
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    c_small_vec(.{ 1, 2 });

    var x = c_ret_small_vec();
    try expect(x[0] == 3);
    try expect(x[1] == 4);
}

const MediumVec = @Vector(4, usize);

extern fn c_medium_vec(MediumVec) void;
extern fn c_ret_medium_vec() MediumVec;

test "medium simd vector" {
    if (builtin.zig_backend == .stage2_x86_64 and
        !comptime std.Target.x86.featureSetHas(builtin.cpu.features, .avx)) return error.SkipZigTest;

    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    c_medium_vec(.{ 1, 2, 3, 4 });

    var x = c_ret_medium_vec();
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

    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch == .x86_64 and builtin.os.tag == .macos and builtin.mode != .Debug) return error.SkipZigTest;

    c_big_vec(.{ 1, 2, 3, 4, 5, 6, 7, 8 });

    var x = c_ret_big_vec();
    try expect(x[0] == 9);
    try expect(x[1] == 10);
    try expect(x[2] == 11);
    try expect(x[3] == 12);
    try expect(x[4] == 13);
    try expect(x[5] == 14);
    try expect(x[6] == 15);
    try expect(x[7] == 16);
}

const Vector2 = extern struct { x: f32, y: f32 };

extern fn c_ptr_size_float_struct(Vector2) void;
extern fn c_ret_ptr_size_float_struct() Vector2;

test "C ABI pointer sized float struct" {
    if (builtin.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

    c_ptr_size_float_struct(.{ .x = 1, .y = 2 });

    var x = c_ret_ptr_size_float_struct();
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_DC(.{ .v1 = -0.25, .v2 = 15 }));
}
test "DC: Zig returns to C" {
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_ret_DC());
}
test "DC: C passes to Zig" {
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_send_DC());
}
test "DC: C returns to Zig" {
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectEqual(c_ret_DC(), .{ .v1 = -0.25, .v2 = 15 });
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_CFF(.{ .v1 = 39, .v2 = 0.875, .v3 = 1.0 }));
}
test "CFF: Zig returns to C" {
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_ret_CFF());
}
test "CFF: C passes to Zig" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV() and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch == .aarch64 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

    try expectOk(c_send_CFF());
}
test "CFF: C returns to Zig" {
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (builtin.cpu.arch == .aarch64 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isRISCV() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectEqual(c_ret_CFF(), .{ .v1 = 39, .v2 = 0.875, .v3 = 1.0 });
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
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_PD(.{ .v1 = null, .v2 = 0.5 }));
}
test "PD: Zig returns to C" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_assert_ret_PD());
}
test "PD: C passes to Zig" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectOk(c_send_PD());
}
test "PD: C returns to Zig" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;
    try expectEqual(c_ret_PD(), .{ .v1 = null, .v2 = 0.5 });
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
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
    if (builtin.cpu.arch == .x86 and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isMIPS() and builtin.mode != .Debug) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

    var fn_ptr = &c_func_ptr_byval;
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
    if (!comptime builtin.cpu.arch.isAARCH64()) return error.SkipZigTest;

    const a = c_f16(12);
    try expect(a == 34);
}

const f16_struct = extern struct {
    a: f16,
};
extern fn c_f16_struct(f16_struct) f16_struct;
test "f16 struct" {
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (comptime builtin.target.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.target.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.target.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isARM() and builtin.mode != .Debug) return error.SkipZigTest;

    const a = c_f16_struct(.{ .a = 12 });
    try expect(a.a == 34);
}

extern fn c_f80(f80) f80;
test "f80 bare" {
    if (!has_f80) return error.SkipZigTest;

    const a = c_f80(12.34);
    try expect(@as(f64, @floatCast(a)) == 56.78);
}

const f80_struct = extern struct {
    a: f80,
};
extern fn c_f80_struct(f80_struct) f80_struct;
test "f80 struct" {
    if (!has_f80) return error.SkipZigTest;
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm and builtin.mode != .Debug) return error.SkipZigTest;

    const a = c_f80_struct(.{ .a = 12.34 });
    try expect(@as(f64, @floatCast(a.a)) == 56.78);
}

const f80_extra_struct = extern struct {
    a: f80,
    b: c_int,
};
extern fn c_f80_extra_struct(f80_extra_struct) f80_extra_struct;
test "f80 extra struct" {
    if (!has_f80) return error.SkipZigTest;
    if (builtin.target.cpu.arch == .x86) return error.SkipZigTest;

    const a = c_f80_extra_struct(.{ .a = 12.34, .b = 42 });
    try expect(@as(f64, @floatCast(a.a)) == 56.78);
    try expect(a.b == 24);
}

extern fn c_f128(f128) f128;
test "f128 bare" {
    if (!has_f128) return error.SkipZigTest;

    const a = c_f128(12.34);
    try expect(@as(f64, @floatCast(a)) == 56.78);
}

const f128_struct = extern struct {
    a: f128,
};
extern fn c_f128_struct(f128_struct) f128_struct;
test "f128 struct" {
    if (!has_f128) return error.SkipZigTest;

    const a = c_f128_struct(.{ .a = 12.34 });
    try expect(@as(f64, @floatCast(a.a)) == 56.78);
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC64()) return error.SkipZigTest;

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
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

    var x = BigUnion{
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
    if (comptime builtin.cpu.arch.isMIPS()) return error.SkipZigTest;
    if (comptime builtin.cpu.arch.isPPC()) return error.SkipZigTest;

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
