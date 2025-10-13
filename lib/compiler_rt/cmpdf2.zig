///! The quoted behavior definitions are from
///! https://gcc.gnu.org/onlinedocs/gcc-12.1.0/gccint/Soft-float-library-routines.html#Soft-float-library-routines
const common = @import("./common.zig");
const comparef = @import("./comparef.zig");

const std = @import("std");
const builtin = @import("builtin");

pub const panic = common.panic;

comptime {
    if (common.want_aeabi) {
        @export(&__aeabi_dcmpeq, .{ .name = "__aeabi_dcmpeq", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_dcmplt, .{ .name = "__aeabi_dcmplt", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__aeabi_dcmple, .{ .name = "__aeabi_dcmple", .linkage = common.linkage, .visibility = common.visibility });
        if (builtin.cpu.arch.isArm() and !builtin.cpu.arch.isThumb() and !builtin.cpu.has(.arm, .pacbti)) {
            @export(&__aeabi_cdcmple, .{ .name = "__aeabi_cdcmple", .linkage = common.linkage, .visibility = common.visibility });
            @export(&__aeabi_cdcmpeq, .{ .name = "__aeabi_cdcmpeq", .linkage = common.linkage, .visibility = common.visibility });
        }
    } else {
        @export(&__eqdf2, .{ .name = "__eqdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__nedf2, .{ .name = "__nedf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__ledf2, .{ .name = "__ledf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__cmpdf2, .{ .name = "__cmpdf2", .linkage = common.linkage, .visibility = common.visibility });
        @export(&__ltdf2, .{ .name = "__ltdf2", .linkage = common.linkage, .visibility = common.visibility });
    }
}

/// "These functions calculate a <=> b. That is, if a is less than b, they return -1;
/// if a is greater than b, they return 1; and if a and b are equal they return 0.
/// If either argument is NaN they return 1..."
///
/// Note that this matches the definition of `__ledf2`, `__eqdf2`, `__nedf2`, `__cmpdf2`,
/// and `__ltdf2`.
fn __cmpdf2(a: f64, b: f64) callconv(.c) i32 {
    return @intFromEnum(comparef.cmpf2(f64, comparef.LE, a, b));
}

/// "These functions return a value less than or equal to zero if neither argument is NaN,
/// and a is less than or equal to b."
pub fn __ledf2(a: f64, b: f64) callconv(.c) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return zero if neither argument is NaN, and a and b are equal."
/// Note that due to some kind of historical accident, __eqdf2 and __nedf2 are defined
/// to have the same return value.
pub fn __eqdf2(a: f64, b: f64) callconv(.c) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return a nonzero value if either argument is NaN, or if a and b are unequal."
/// Note that due to some kind of historical accident, __eqdf2 and __nedf2 are defined
/// to have the same return value.
pub fn __nedf2(a: f64, b: f64) callconv(.c) i32 {
    return __cmpdf2(a, b);
}

/// "These functions return a value less than zero if neither argument is NaN, and a
/// is strictly less than b."
pub fn __ltdf2(a: f64, b: f64) callconv(.c) i32 {
    return __cmpdf2(a, b);
}

fn __aeabi_dcmpeq(a: f64, b: f64) callconv(.{ .arm_aapcs = .{} }) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) == .Equal);
}

fn __aeabi_dcmplt(a: f64, b: f64) callconv(.{ .arm_aapcs = .{} }) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) == .Less);
}

fn __aeabi_dcmple(a: f64, b: f64) callconv(.{ .arm_aapcs = .{} }) i32 {
    return @intFromBool(comparef.cmpf2(f64, comparef.LE, a, b) != .Greater);
}

fn __aeabi_cdcmpeq_check_nan(a: f64, b: f64) callconv(.c) i32 {
    return @intFromBool(std.math.isNan(a) or std.math.isNan(b));
}

// This function compares two doubles and returns the result in CPSR register.
//
// C code equivalent:
//
// void __aeabi_cdcmpeq(double a, double b) {
//   if (isnan(a) || isnan(b)) {
//     Z = 0; C = 1;
//   } else {
//     __aeabi_cdcmple(a, b);
//   }
// }
//
// Code has been taken from LLVM implementation:
// https://github.com/llvm/llvm-project/blob/7eee67202378932d03331ad04e7d07ed4d988381/compiler-rt/lib/builtins/arm/aeabi_cdcmp.S
//
fn __aeabi_cdcmpeq(_: f64, _: f64) callconv(.naked) void {
    const apsr_c = 0x20000000;
    asm volatile (
        \\        push {r0-r3, lr}
        \\        bl %[__aeabi_cdcmpeq_check_nan]
        \\        cmp r0, #1
        \\        pop {r0-r3, lr}
        \\        bne %[__aeabi_cdcmple]
        \\        msr APSR_nzcvq, %[APSR_C]
        \\        bx lr
        :
        : [__aeabi_cdcmple] "X" (&__aeabi_cdcmple),
          [__aeabi_cdcmpeq_check_nan] "X" (&__aeabi_cdcmpeq_check_nan),
          [APSR_C] "i" (apsr_c),
    );
}

// This function compares two doubles and returns the result in CPSR register.
//
// C code equivalent:
//
// void __aeabi_cdcmple(double a, double b) {
//   if (__aeabi_dcmplt(a, b)) {
//     Z = 0; C = 0;
//   } else if (__aeabi_dcmpeq(a, b)) {
//     Z = 1; C = 1;
//   } else {
//     Z = 0; C = 1;
//   }
// }
//
// Code has been taken from LLVM implementation:
// https://github.com/llvm/llvm-project/blob/7eee67202378932d03331ad04e7d07ed4d988381/compiler-rt/lib/builtins/arm/aeabi_cdcmp.S
//
fn __aeabi_cdcmple(_: f64, _: f64) callconv(.naked) void {
    const apsr_c = 0x20000000;
    const apsr_z = 0x40000000;
    asm volatile (
        \\        push {r0-r3, lr}
        \\        bl  %[__aeabi_dcmplt]
        \\        cmp r0, #1
        \\        moveq ip, #0
        \\        beq 1f
        \\        ldm sp, {r0-r3}
        \\        bl %[__aeabi_dcmpeq]
        \\        cmp r0, #1
        \\        moveq ip, %[APSR_CZ]
        \\        movne ip, %[APSR_C]
        \\1:
        \\        msr APSR_nzcvq, ip
        \\        pop {r0-r3}
        \\        pop {pc}
        :
        : [__aeabi_dcmplt] "X" (&__aeabi_dcmplt),
          [__aeabi_dcmpeq] "X" (&__aeabi_dcmpeq),
          [APSR_C] "i" (apsr_c),
          [APSR_CZ] "i" (apsr_c | apsr_z),
    );
}

const CPSRFlags = packed struct {
    filler: u28,
    v: u1,
    c: u1,
    z: u1,
    n: u1,
};

const CPSR = packed union {
    flags: CPSRFlags,
    value: u32,
};

const __aeabi_cdcmpxx = *const fn (f64, f64) callconv(.naked) void;

fn call__aeabi_cdcmpxx(comptime func: __aeabi_cdcmpxx, a: f64, b: f64) CPSR {
    const A: u64 = @bitCast(a);
    const B: u64 = @bitCast(b);

    const le = builtin.cpu.arch.endian() == .little;
    const a_lo: u32 = if (le) @truncate(A) else @truncate(A >> 32);
    const a_hi: u32 = if (le) @truncate(A >> 32) else @truncate(A);
    const b_lo: u32 = if (le) @truncate(B) else @truncate(B >> 32);
    const b_hi: u32 = if (le) @truncate(B >> 32) else @truncate(B);

    const result = asm volatile (
        \\ bl %[func]
        \\ mrs %[out], apsr
        : [out] "=r" (-> u32),
        : [r0] "{r0}" (a_lo),
          [r1] "{r1}" (a_hi),
          [r2] "{r2}" (b_lo),
          [r3] "{r3}" (b_hi),
          [func] "X" (func),
    );
    return .{ .value = result };
}

// This test has been copied from LLVM:
// https://github.com/llvm/llvm-project/blob/7eee67202378932d03331ad04e7d07ed4d988381/compiler-rt/test/builtins/Unit/arm/aeabi_cdcmpeq_test.c
//
test "test __aeabi_cdcmpeq" {
    if (!builtin.cpu.arch.isArm() or builtin.cpu.arch.isThumb() or builtin.cpu.has(.arm, .pacbti)) return error.SkipZigTest;

    const t = std.testing;
    const nan = std.math.nan(f64);
    const inf = std.math.inf(f64);

    try t.expectEqual(@as(u1, 1), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 1.0, 1.0).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 1234.567, 765.4321).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, -123.0, -678.0).flags.z);
    try t.expectEqual(@as(u1, 1), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 0.0, -0.0).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 1.0, nan).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, nan, 1.0).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, nan, nan).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, inf, 1.0).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 0.0, inf).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, -inf, 0.0).flags.z);
    try t.expectEqual(@as(u1, 0), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, 0.0, -inf).flags.z);
    try t.expectEqual(@as(u1, 1), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, inf, inf).flags.z);
    try t.expectEqual(@as(u1, 1), call__aeabi_cdcmpxx(&__aeabi_cdcmpeq, -inf, -inf).flags.z);
}

// This test has been copied from LLVM:
// https://github.com/llvm/llvm-project/blob/7eee67202378932d03331ad04e7d07ed4d988381/compiler-rt/test/builtins/Unit/arm/aeabi_cdcmple_test.c
//
test "test __aeabi_cdcmple" {
    if (!builtin.cpu.arch.isArm() or builtin.cpu.arch.isThumb() or builtin.cpu.has(.arm, .pacbti)) return error.SkipZigTest;

    const t = std.testing;
    const nan = std.math.nan(f64);

    var cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, 1.0, 1.0);
    try t.expectEqual(@as(u1, 1), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, 1234.567, 765.4321);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, 765.4321, 1234.567);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 0), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, -123.0, -678.0);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, -678.0, -123.0);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 0), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, 0.0, -0.0);
    try t.expectEqual(@as(u1, 1), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, 1.0, nan);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, nan, 1.0);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);

    cpsr = call__aeabi_cdcmpxx(&__aeabi_cdcmple, nan, nan);
    try t.expectEqual(@as(u1, 0), cpsr.flags.z);
    try t.expectEqual(@as(u1, 1), cpsr.flags.c);
}
