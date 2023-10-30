const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const math = std.math;

const __fixunshfti = @import("fixunshfti.zig").__fixunshfti;
const __fixunsxfti = @import("fixunsxfti.zig").__fixunsxfti;

// Conversion from f32
const __fixsfsi = @import("fixsfsi.zig").__fixsfsi;
const __fixunssfsi = @import("fixunssfsi.zig").__fixunssfsi;
const __fixsfdi = @import("fixsfdi.zig").__fixsfdi;
const __fixunssfdi = @import("fixunssfdi.zig").__fixunssfdi;
const __fixsfti = @import("fixsfti.zig").__fixsfti;
const __fixunssfti = @import("fixunssfti.zig").__fixunssfti;

// Conversion from f64
const __fixdfsi = @import("fixdfsi.zig").__fixdfsi;
const __fixunsdfsi = @import("fixunsdfsi.zig").__fixunsdfsi;
const __fixdfdi = @import("fixdfdi.zig").__fixdfdi;
const __fixunsdfdi = @import("fixunsdfdi.zig").__fixunsdfdi;
const __fixdfti = @import("fixdfti.zig").__fixdfti;
const __fixunsdfti = @import("fixunsdfti.zig").__fixunsdfti;

// Conversion from f128
const __fixtfsi = @import("fixtfsi.zig").__fixtfsi;
const __fixunstfsi = @import("fixunstfsi.zig").__fixunstfsi;
const __fixtfdi = @import("fixtfdi.zig").__fixtfdi;
const __fixunstfdi = @import("fixunstfdi.zig").__fixunstfdi;
const __fixtfti = @import("fixtfti.zig").__fixtfti;
const __fixunstfti = @import("fixunstfti.zig").__fixunstfti;

fn test__fixsfsi(a: f32, expected: i32) !void {
    const x = __fixsfsi(a);
    try testing.expect(x == expected);
}

fn test__fixunssfsi(a: f32, expected: u32) !void {
    const x = __fixunssfsi(a);
    try testing.expect(x == expected);
}

test "fixsfsi" {
    try test__fixsfsi(-math.floatMax(f32), math.minInt(i32));

    try test__fixsfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    try test__fixsfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    try test__fixsfsi(-0x1.0000000000000p+127, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    try test__fixsfsi(-0x1.0000000000001p+63, -0x80000000);
    try test__fixsfsi(-0x1.0000000000000p+63, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    try test__fixsfsi(-0x1.FFFFFEp+62, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFCp+62, -0x80000000);

    try test__fixsfsi(-0x1.000000p+31, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFFp+30, -0x80000000);
    try test__fixsfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixsfsi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixsfsi(-2.01, -2);
    try test__fixsfsi(-2.0, -2);
    try test__fixsfsi(-1.99, -1);
    try test__fixsfsi(-1.0, -1);
    try test__fixsfsi(-0.99, 0);
    try test__fixsfsi(-0.5, 0);

    try test__fixsfsi(-math.floatMin(f32), 0);
    try test__fixsfsi(0.0, 0);
    try test__fixsfsi(math.floatMin(f32), 0);
    try test__fixsfsi(0.5, 0);
    try test__fixsfsi(0.99, 0);
    try test__fixsfsi(1.0, 1);
    try test__fixsfsi(1.5, 1);
    try test__fixsfsi(1.99, 1);
    try test__fixsfsi(2.0, 2);
    try test__fixsfsi(2.01, 2);

    try test__fixsfsi(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixsfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixsfsi(0x1.FFFFFFp+30, 0x7FFFFFFF);
    try test__fixsfsi(0x1.000000p+31, 0x7FFFFFFF);

    try test__fixsfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    try test__fixsfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    try test__fixsfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    try test__fixsfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    try test__fixsfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    try test__fixsfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    try test__fixsfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    try test__fixsfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    try test__fixsfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    try test__fixsfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    try test__fixsfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    try test__fixsfsi(math.floatMax(f32), math.maxInt(i32));
}

test "fixunssfsi" {
    try test__fixunssfsi(0.0, 0);

    try test__fixunssfsi(0.5, 0);
    try test__fixunssfsi(0.99, 0);
    try test__fixunssfsi(1.0, 1);
    try test__fixunssfsi(1.5, 1);
    try test__fixunssfsi(1.99, 1);
    try test__fixunssfsi(2.0, 2);
    try test__fixunssfsi(2.01, 2);
    try test__fixunssfsi(-0.5, 0);
    try test__fixunssfsi(-0.99, 0);

    try test__fixunssfsi(-1.0, 0);
    try test__fixunssfsi(-1.5, 0);
    try test__fixunssfsi(-1.99, 0);
    try test__fixunssfsi(-2.0, 0);
    try test__fixunssfsi(-2.01, 0);

    try test__fixunssfsi(0x1.000000p+31, 0x80000000);
    try test__fixunssfsi(0x1.000000p+32, 0xFFFFFFFF);
    try test__fixunssfsi(0x1.FFFFFEp+31, 0xFFFFFF00);
    try test__fixunssfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixunssfsi(0x1.FFFFFCp+30, 0x7FFFFF00);

    try test__fixunssfsi(-0x1.FFFFFEp+30, 0);
    try test__fixunssfsi(-0x1.FFFFFCp+30, 0);
}

fn test__fixsfdi(a: f32, expected: i64) !void {
    const x = __fixsfdi(a);
    try testing.expect(x == expected);
}

fn test__fixunssfdi(a: f32, expected: u64) !void {
    const x = __fixunssfdi(a);
    try testing.expect(x == expected);
}

test "fixsfdi" {
    try test__fixsfdi(-math.floatMax(f32), math.minInt(i64));

    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i64));
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+1023, -0x8000000000000000);

    try test__fixsfdi(-0x1.0000000000000p+127, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+126, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFEp+126, -0x8000000000000000);

    try test__fixsfdi(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixsfdi(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFFp+62, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFFFFFFFFEp+62, -0x8000000000000000);

    try test__fixsfdi(-0x1.FFFFFFp+62, -0x8000000000000000);
    try test__fixsfdi(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixsfdi(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixsfdi(-2.01, -2);
    try test__fixsfdi(-2.0, -2);
    try test__fixsfdi(-1.99, -1);
    try test__fixsfdi(-1.0, -1);
    try test__fixsfdi(-0.99, 0);
    try test__fixsfdi(-0.5, 0);
    try test__fixsfdi(-math.floatMin(f32), 0);
    try test__fixsfdi(0.0, 0);
    try test__fixsfdi(math.floatMin(f32), 0);
    try test__fixsfdi(0.5, 0);
    try test__fixsfdi(0.99, 0);
    try test__fixsfdi(1.0, 1);
    try test__fixsfdi(1.5, 1);
    try test__fixsfdi(1.99, 1);
    try test__fixsfdi(2.0, 2);
    try test__fixsfdi(2.01, 2);

    try test__fixsfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixsfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixsfdi(0x1.FFFFFFp+62, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000000p+63, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000001p+63, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFF);

    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFF);
    try test__fixsfdi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i64));

    try test__fixsfdi(math.floatMax(f32), math.maxInt(i64));
}

test "fixunssfdi" {
    try test__fixunssfdi(0.0, 0);

    try test__fixunssfdi(0.5, 0);
    try test__fixunssfdi(0.99, 0);
    try test__fixunssfdi(1.0, 1);
    try test__fixunssfdi(1.5, 1);
    try test__fixunssfdi(1.99, 1);
    try test__fixunssfdi(2.0, 2);
    try test__fixunssfdi(2.01, 2);
    try test__fixunssfdi(-0.5, 0);
    try test__fixunssfdi(-0.99, 0);

    try test__fixunssfdi(-1.0, 0);
    try test__fixunssfdi(-1.5, 0);
    try test__fixunssfdi(-1.99, 0);
    try test__fixunssfdi(-2.0, 0);
    try test__fixunssfdi(-2.01, 0);

    try test__fixunssfdi(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    try test__fixunssfdi(0x1.000000p+63, 0x8000000000000000);
    try test__fixunssfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunssfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunssfdi(-0x1.FFFFFEp+62, 0x0000000000000000);
    try test__fixunssfdi(-0x1.FFFFFCp+62, 0x0000000000000000);
}

fn test__fixsfti(a: f32, expected: i128) !void {
    const x = __fixsfti(a);
    try testing.expect(x == expected);
}

fn test__fixunssfti(a: f32, expected: u128) !void {
    const x = __fixunssfti(a);
    try testing.expect(x == expected);
}

test "fixsfti" {
    try test__fixsfti(-math.floatMax(f32), math.minInt(i128));

    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i128));
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000000000000000000000000000);

    try test__fixsfti(-0x1.0000000000000p+127, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFEp+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFF0000000p+126, -0x80000000000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFE0000000p+126, -0x7FFFFF80000000000000000000000000);
    try test__fixsfti(-0x1.FFFFFC0000000p+126, -0x7FFFFF00000000000000000000000000);

    try test__fixsfti(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixsfti(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFFp+62, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFFFFFFFFEp+62, -0x8000000000000000);

    try test__fixsfti(-0x1.FFFFFFp+62, -0x8000000000000000);
    try test__fixsfti(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixsfti(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixsfti(-0x1.000000p+31, -0x80000000);
    try test__fixsfti(-0x1.FFFFFFp+30, -0x80000000);
    try test__fixsfti(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixsfti(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixsfti(-2.01, -2);
    try test__fixsfti(-2.0, -2);
    try test__fixsfti(-1.99, -1);
    try test__fixsfti(-1.0, -1);
    try test__fixsfti(-0.99, 0);
    try test__fixsfti(-0.5, 0);
    try test__fixsfti(-math.floatMin(f32), 0);
    try test__fixsfti(0.0, 0);
    try test__fixsfti(math.floatMin(f32), 0);
    try test__fixsfti(0.5, 0);
    try test__fixsfti(0.99, 0);
    try test__fixsfti(1.0, 1);
    try test__fixsfti(1.5, 1);
    try test__fixsfti(1.99, 1);
    try test__fixsfti(2.0, 2);
    try test__fixsfti(2.01, 2);

    try test__fixsfti(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixsfti(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixsfti(0x1.FFFFFFp+30, 0x80000000);
    try test__fixsfti(0x1.000000p+31, 0x80000000);

    try test__fixsfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixsfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixsfti(0x1.FFFFFFp+62, 0x8000000000000000);

    try test__fixsfti(0x1.FFFFFFFFFFFFEp+62, 0x8000000000000000);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+62, 0x8000000000000000);
    try test__fixsfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixsfti(0x1.0000000000001p+63, 0x8000000000000000);

    try test__fixsfti(0x1.FFFFFC0000000p+126, 0x7FFFFF00000000000000000000000000);
    try test__fixsfti(0x1.FFFFFE0000000p+126, 0x7FFFFF80000000000000000000000000);
    try test__fixsfti(0x1.FFFFFF0000000p+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixsfti(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixsfti(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i128));

    try test__fixsfti(math.floatMax(f32), math.maxInt(i128));
}

test "fixunssfti" {
    try test__fixunssfti(0.0, 0);

    try test__fixunssfti(0.5, 0);
    try test__fixunssfti(0.99, 0);
    try test__fixunssfti(1.0, 1);
    try test__fixunssfti(1.5, 1);
    try test__fixunssfti(1.99, 1);
    try test__fixunssfti(2.0, 2);
    try test__fixunssfti(2.01, 2);
    try test__fixunssfti(-0.5, 0);
    try test__fixunssfti(-0.99, 0);

    try test__fixunssfti(-1.0, 0);
    try test__fixunssfti(-1.5, 0);
    try test__fixunssfti(-1.99, 0);
    try test__fixunssfti(-2.0, 0);
    try test__fixunssfti(-2.01, 0);

    try test__fixunssfti(0x1.FFFFFEp+63, 0xFFFFFF0000000000);
    try test__fixunssfti(0x1.000000p+63, 0x8000000000000000);
    try test__fixunssfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunssfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixunssfti(0x1.FFFFFEp+127, 0xFFFFFF00000000000000000000000000);
    try test__fixunssfti(0x1.000000p+127, 0x80000000000000000000000000000000);
    try test__fixunssfti(0x1.FFFFFEp+126, 0x7FFFFF80000000000000000000000000);
    try test__fixunssfti(0x1.FFFFFCp+126, 0x7FFFFF00000000000000000000000000);

    try test__fixunssfti(-0x1.FFFFFEp+62, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFCp+62, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFEp+126, 0x0000000000000000);
    try test__fixunssfti(-0x1.FFFFFCp+126, 0x0000000000000000);
    try test__fixunssfti(math.floatMax(f32), 0xffffff00000000000000000000000000);
    try test__fixunssfti(math.inf(f32), math.maxInt(u128));
}

fn test__fixdfsi(a: f64, expected: i32) !void {
    const x = __fixdfsi(a);
    try testing.expect(x == expected);
}

fn test__fixunsdfsi(a: f64, expected: u32) !void {
    const x = __fixunsdfsi(a);
    try testing.expect(x == expected);
}

test "fixdfsi" {
    try test__fixdfsi(-math.floatMax(f64), math.minInt(i32));

    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    try test__fixdfsi(-0x1.0000000000000p+127, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    try test__fixdfsi(-0x1.0000000000001p+63, -0x80000000);
    try test__fixdfsi(-0x1.0000000000000p+63, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    try test__fixdfsi(-0x1.FFFFFEp+62, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFCp+62, -0x80000000);

    try test__fixdfsi(-0x1.000000p+31, -0x80000000);
    try test__fixdfsi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    try test__fixdfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);

    try test__fixdfsi(-2.01, -2);
    try test__fixdfsi(-2.0, -2);
    try test__fixdfsi(-1.99, -1);
    try test__fixdfsi(-1.0, -1);
    try test__fixdfsi(-0.99, 0);
    try test__fixdfsi(-0.5, 0);
    try test__fixdfsi(-math.floatMin(f64), 0);
    try test__fixdfsi(0.0, 0);
    try test__fixdfsi(math.floatMin(f64), 0);
    try test__fixdfsi(0.5, 0);
    try test__fixdfsi(0.99, 0);
    try test__fixdfsi(1.0, 1);
    try test__fixdfsi(1.5, 1);
    try test__fixdfsi(1.99, 1);
    try test__fixdfsi(2.0, 2);
    try test__fixdfsi(2.01, 2);

    try test__fixdfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixdfsi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    try test__fixdfsi(0x1.000000p+31, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    try test__fixdfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    try test__fixdfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    try test__fixdfsi(math.floatMax(f64), math.maxInt(i32));
}

test "fixunsdfsi" {
    try test__fixunsdfsi(0.0, 0);

    try test__fixunsdfsi(0.5, 0);
    try test__fixunsdfsi(0.99, 0);
    try test__fixunsdfsi(1.0, 1);
    try test__fixunsdfsi(1.5, 1);
    try test__fixunsdfsi(1.99, 1);
    try test__fixunsdfsi(2.0, 2);
    try test__fixunsdfsi(2.01, 2);
    try test__fixunsdfsi(-0.5, 0);
    try test__fixunsdfsi(-0.99, 0);
    try test__fixunsdfsi(-1.0, 0);
    try test__fixunsdfsi(-1.5, 0);
    try test__fixunsdfsi(-1.99, 0);
    try test__fixunsdfsi(-2.0, 0);
    try test__fixunsdfsi(-2.01, 0);

    try test__fixunsdfsi(0x1.000000p+31, 0x80000000);
    try test__fixunsdfsi(0x1.000000p+32, 0xFFFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFEp+31, 0xFFFFFF00);
    try test__fixunsdfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixunsdfsi(0x1.FFFFFCp+30, 0x7FFFFF00);

    try test__fixunsdfsi(-0x1.FFFFFEp+30, 0);
    try test__fixunsdfsi(-0x1.FFFFFCp+30, 0);

    try test__fixunsdfsi(0x1.FFFFFFFEp+31, 0xFFFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFFFC00000p+30, 0x7FFFFFFF);
    try test__fixunsdfsi(0x1.FFFFFFF800000p+30, 0x7FFFFFFE);
}

fn test__fixdfdi(a: f64, expected: i64) !void {
    const x = __fixdfdi(a);
    try testing.expect(x == expected);
}

fn test__fixunsdfdi(a: f64, expected: u64) !void {
    const x = __fixunsdfdi(a);
    try testing.expect(x == expected);
}

test "fixdfdi" {
    try test__fixdfdi(-math.floatMax(f64), math.minInt(i64));

    try test__fixdfdi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i64));
    try test__fixdfdi(-0x1.FFFFFFFFFFFFFp+1023, -0x8000000000000000);

    try test__fixdfdi(-0x1.0000000000000p+127, -0x8000000000000000);
    try test__fixdfdi(-0x1.FFFFFFFFFFFFFp+126, -0x8000000000000000);
    try test__fixdfdi(-0x1.FFFFFFFFFFFFEp+126, -0x8000000000000000);

    try test__fixdfdi(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixdfdi(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixdfdi(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    try test__fixdfdi(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    try test__fixdfdi(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixdfdi(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixdfdi(-2.01, -2);
    try test__fixdfdi(-2.0, -2);
    try test__fixdfdi(-1.99, -1);
    try test__fixdfdi(-1.0, -1);
    try test__fixdfdi(-0.99, 0);
    try test__fixdfdi(-0.5, 0);
    try test__fixdfdi(-math.floatMin(f64), 0);
    try test__fixdfdi(0.0, 0);
    try test__fixdfdi(math.floatMin(f64), 0);
    try test__fixdfdi(0.5, 0);
    try test__fixdfdi(0.99, 0);
    try test__fixdfdi(1.0, 1);
    try test__fixdfdi(1.5, 1);
    try test__fixdfdi(1.99, 1);
    try test__fixdfdi(2.0, 2);
    try test__fixdfdi(2.01, 2);

    try test__fixdfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixdfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    try test__fixdfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    try test__fixdfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixdfdi(0x1.0000000000000p+63, 0x7FFFFFFFFFFFFFFF);
    try test__fixdfdi(0x1.0000000000001p+63, 0x7FFFFFFFFFFFFFFF);

    try test__fixdfdi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixdfdi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixdfdi(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFF);

    try test__fixdfdi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFF);
    try test__fixdfdi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i64));

    try test__fixdfdi(math.floatMax(f64), math.maxInt(i64));
}

test "fixunsdfdi" {
    try test__fixunsdfdi(0.0, 0);
    try test__fixunsdfdi(0.5, 0);
    try test__fixunsdfdi(0.99, 0);
    try test__fixunsdfdi(1.0, 1);
    try test__fixunsdfdi(1.5, 1);
    try test__fixunsdfdi(1.99, 1);
    try test__fixunsdfdi(2.0, 2);
    try test__fixunsdfdi(2.01, 2);
    try test__fixunsdfdi(-0.5, 0);
    try test__fixunsdfdi(-0.99, 0);
    try test__fixunsdfdi(-1.0, 0);
    try test__fixunsdfdi(-1.5, 0);
    try test__fixunsdfdi(-1.99, 0);
    try test__fixunsdfdi(-2.0, 0);
    try test__fixunsdfdi(-2.01, 0);

    try test__fixunsdfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunsdfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunsdfdi(-0x1.FFFFFEp+62, 0);
    try test__fixunsdfdi(-0x1.FFFFFCp+62, 0);

    try test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+63, 0xFFFFFFFFFFFFF800);
    try test__fixunsdfdi(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixunsdfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixunsdfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    try test__fixunsdfdi(-0x1.FFFFFFFFFFFFFp+62, 0);
    try test__fixunsdfdi(-0x1.FFFFFFFFFFFFEp+62, 0);
}

fn test__fixdfti(a: f64, expected: i128) !void {
    const x = __fixdfti(a);
    try testing.expect(x == expected);
}

fn test__fixunsdfti(a: f64, expected: u128) !void {
    const x = __fixunsdfti(a);
    try testing.expect(x == expected);
}

test "fixdfti" {
    try test__fixdfti(-math.floatMax(f64), math.minInt(i128));

    try test__fixdfti(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i128));
    try test__fixdfti(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000000000000000000000000000);

    try test__fixdfti(-0x1.0000000000000p+127, -0x80000000000000000000000000000000);
    try test__fixdfti(-0x1.FFFFFFFFFFFFFp+126, -0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixdfti(-0x1.FFFFFFFFFFFFEp+126, -0x7FFFFFFFFFFFF8000000000000000000);

    try test__fixdfti(-0x1.0000000000001p+63, -0x8000000000000800);
    try test__fixdfti(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixdfti(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    try test__fixdfti(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    try test__fixdfti(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixdfti(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixdfti(-2.01, -2);
    try test__fixdfti(-2.0, -2);
    try test__fixdfti(-1.99, -1);
    try test__fixdfti(-1.0, -1);
    try test__fixdfti(-0.99, 0);
    try test__fixdfti(-0.5, 0);
    try test__fixdfti(-math.floatMin(f64), 0);
    try test__fixdfti(0.0, 0);
    try test__fixdfti(math.floatMin(f64), 0);
    try test__fixdfti(0.5, 0);
    try test__fixdfti(0.99, 0);
    try test__fixdfti(1.0, 1);
    try test__fixdfti(1.5, 1);
    try test__fixdfti(1.99, 1);
    try test__fixdfti(2.0, 2);
    try test__fixdfti(2.01, 2);

    try test__fixdfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixdfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    try test__fixdfti(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    try test__fixdfti(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixdfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixdfti(0x1.0000000000001p+63, 0x8000000000000800);

    try test__fixdfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFF8000000000000000000);
    try test__fixdfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixdfti(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixdfti(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixdfti(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i128));

    try test__fixdfti(math.floatMax(f64), math.maxInt(i128));
}

test "fixunsdfti" {
    try test__fixunsdfti(0.0, 0);

    try test__fixunsdfti(0.5, 0);
    try test__fixunsdfti(0.99, 0);
    try test__fixunsdfti(1.0, 1);
    try test__fixunsdfti(1.5, 1);
    try test__fixunsdfti(1.99, 1);
    try test__fixunsdfti(2.0, 2);
    try test__fixunsdfti(2.01, 2);
    try test__fixunsdfti(-0.5, 0);
    try test__fixunsdfti(-0.99, 0);
    try test__fixunsdfti(-1.0, 0);
    try test__fixunsdfti(-1.5, 0);
    try test__fixunsdfti(-1.99, 0);
    try test__fixunsdfti(-2.0, 0);
    try test__fixunsdfti(-2.01, 0);

    try test__fixunsdfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunsdfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunsdfti(-0x1.FFFFFEp+62, 0);
    try test__fixunsdfti(-0x1.FFFFFCp+62, 0);

    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+63, 0xFFFFFFFFFFFFF800);
    try test__fixunsdfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+127, 0xFFFFFFFFFFFFF8000000000000000000);
    try test__fixunsdfti(0x1.0000000000000p+127, 0x80000000000000000000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixunsdfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFF8000000000000000000);
    try test__fixunsdfti(0x1.0000000000000p+128, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixunsdfti(-0x1.FFFFFFFFFFFFFp+62, 0);
    try test__fixunsdfti(-0x1.FFFFFFFFFFFFEp+62, 0);
}

fn test__fixtfsi(a: f128, expected: i32) !void {
    const x = __fixtfsi(a);
    try testing.expect(x == expected);
}

fn test__fixunstfsi(a: f128, expected: u32) !void {
    const x = __fixunstfsi(a);
    try testing.expect(x == expected);
}

test "fixtfsi" {
    try test__fixtfsi(-math.floatMax(f128), math.minInt(i32));

    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i32));
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000);

    try test__fixtfsi(-0x1.0000000000000p+127, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+126, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFEp+126, -0x80000000);

    try test__fixtfsi(-0x1.0000000000001p+63, -0x80000000);
    try test__fixtfsi(-0x1.0000000000000p+63, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFFp+62, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFFFFFFFEp+62, -0x80000000);

    try test__fixtfsi(-0x1.FFFFFEp+62, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFCp+62, -0x80000000);

    try test__fixtfsi(-0x1.000000p+31, -0x80000000);
    try test__fixtfsi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    try test__fixtfsi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixtfsi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixtfsi(-2.01, -2);
    try test__fixtfsi(-2.0, -2);
    try test__fixtfsi(-1.99, -1);
    try test__fixtfsi(-1.0, -1);
    try test__fixtfsi(-0.99, 0);
    try test__fixtfsi(-0.5, 0);
    try test__fixtfsi(-math.floatMin(f32), 0);
    try test__fixtfsi(0.0, 0);
    try test__fixtfsi(math.floatMin(f32), 0);
    try test__fixtfsi(0.5, 0);
    try test__fixtfsi(0.99, 0);
    try test__fixtfsi(1.0, 1);
    try test__fixtfsi(1.5, 1);
    try test__fixtfsi(1.99, 1);
    try test__fixtfsi(2.0, 2);
    try test__fixtfsi(2.01, 2);

    try test__fixtfsi(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixtfsi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixtfsi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    try test__fixtfsi(0x1.000000p+31, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFCp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFEp+62, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000000p+63, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000001p+63, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFF);
    try test__fixtfsi(0x1.0000000000000p+127, 0x7FFFFFFF);

    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFF);
    try test__fixtfsi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i32));

    try test__fixtfsi(math.floatMax(f128), math.maxInt(i32));
}

test "fixunstfsi" {
    try test__fixunstfsi(math.inf(f128), 0xffffffff);
    try test__fixunstfsi(0, 0x0);
    try test__fixunstfsi(0x1.23456789abcdefp+5, 0x24);
    try test__fixunstfsi(0x1.23456789abcdefp-3, 0x0);
    try test__fixunstfsi(0x1.23456789abcdefp+20, 0x123456);
    try test__fixunstfsi(0x1.23456789abcdefp+40, 0xffffffff);
    try test__fixunstfsi(0x1.23456789abcdefp+256, 0xffffffff);
    try test__fixunstfsi(-0x1.23456789abcdefp+3, 0x0);

    try test__fixunstfsi(0x1p+32, 0xFFFFFFFF);
}

fn test__fixtfdi(a: f128, expected: i64) !void {
    const x = __fixtfdi(a);
    try testing.expect(x == expected);
}

fn test__fixunstfdi(a: f128, expected: u64) !void {
    const x = __fixunstfdi(a);
    try testing.expect(x == expected);
}

test "fixtfdi" {
    try test__fixtfdi(-math.floatMax(f128), math.minInt(i64));

    try test__fixtfdi(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i64));
    try test__fixtfdi(-0x1.FFFFFFFFFFFFFp+1023, -0x8000000000000000);

    try test__fixtfdi(-0x1.0000000000000p+127, -0x8000000000000000);
    try test__fixtfdi(-0x1.FFFFFFFFFFFFFp+126, -0x8000000000000000);
    try test__fixtfdi(-0x1.FFFFFFFFFFFFEp+126, -0x8000000000000000);

    try test__fixtfdi(-0x1.0000000000001p+63, -0x8000000000000000);
    try test__fixtfdi(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixtfdi(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    try test__fixtfdi(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    try test__fixtfdi(-0x1.FFFFFEp+62, -0x7FFFFF8000000000);
    try test__fixtfdi(-0x1.FFFFFCp+62, -0x7FFFFF0000000000);

    try test__fixtfdi(-0x1.000000p+31, -0x80000000);
    try test__fixtfdi(-0x1.FFFFFFp+30, -0x7FFFFFC0);
    try test__fixtfdi(-0x1.FFFFFEp+30, -0x7FFFFF80);
    try test__fixtfdi(-0x1.FFFFFCp+30, -0x7FFFFF00);

    try test__fixtfdi(-2.01, -2);
    try test__fixtfdi(-2.0, -2);
    try test__fixtfdi(-1.99, -1);
    try test__fixtfdi(-1.0, -1);
    try test__fixtfdi(-0.99, 0);
    try test__fixtfdi(-0.5, 0);
    try test__fixtfdi(-math.floatMin(f64), 0);
    try test__fixtfdi(0.0, 0);
    try test__fixtfdi(math.floatMin(f64), 0);
    try test__fixtfdi(0.5, 0);
    try test__fixtfdi(0.99, 0);
    try test__fixtfdi(1.0, 1);
    try test__fixtfdi(1.5, 1);
    try test__fixtfdi(1.99, 1);
    try test__fixtfdi(2.0, 2);
    try test__fixtfdi(2.01, 2);

    try test__fixtfdi(0x1.FFFFFCp+30, 0x7FFFFF00);
    try test__fixtfdi(0x1.FFFFFEp+30, 0x7FFFFF80);
    try test__fixtfdi(0x1.FFFFFFp+30, 0x7FFFFFC0);
    try test__fixtfdi(0x1.000000p+31, 0x80000000);

    try test__fixtfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixtfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    try test__fixtfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    try test__fixtfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixtfdi(0x1.0000000000000p+63, 0x7FFFFFFFFFFFFFFF);
    try test__fixtfdi(0x1.0000000000001p+63, 0x7FFFFFFFFFFFFFFF);

    try test__fixtfdi(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixtfdi(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFFFF);
    try test__fixtfdi(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFF);

    try test__fixtfdi(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFF);
    try test__fixtfdi(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i64));

    try test__fixtfdi(math.floatMax(f128), math.maxInt(i64));
}

test "fixunstfdi" {
    try test__fixunstfdi(0.0, 0);

    try test__fixunstfdi(0.5, 0);
    try test__fixunstfdi(0.99, 0);
    try test__fixunstfdi(1.0, 1);
    try test__fixunstfdi(1.5, 1);
    try test__fixunstfdi(1.99, 1);
    try test__fixunstfdi(2.0, 2);
    try test__fixunstfdi(2.01, 2);
    try test__fixunstfdi(-0.5, 0);
    try test__fixunstfdi(-0.99, 0);
    try test__fixunstfdi(-1.0, 0);
    try test__fixunstfdi(-1.5, 0);
    try test__fixunstfdi(-1.99, 0);
    try test__fixunstfdi(-2.0, 0);
    try test__fixunstfdi(-2.01, 0);

    try test__fixunstfdi(0x1.FFFFFEp+62, 0x7FFFFF8000000000);
    try test__fixunstfdi(0x1.FFFFFCp+62, 0x7FFFFF0000000000);

    try test__fixunstfdi(-0x1.FFFFFEp+62, 0);
    try test__fixunstfdi(-0x1.FFFFFCp+62, 0);

    try test__fixunstfdi(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixunstfdi(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);

    try test__fixunstfdi(-0x1.FFFFFFFFFFFFFp+62, 0);
    try test__fixunstfdi(-0x1.FFFFFFFFFFFFEp+62, 0);

    try test__fixunstfdi(0x1.FFFFFFFFFFFFFFFEp+63, 0xFFFFFFFFFFFFFFFF);
    try test__fixunstfdi(0x1.0000000000000002p+63, 0x8000000000000001);
    try test__fixunstfdi(0x1.0000000000000000p+63, 0x8000000000000000);
    try test__fixunstfdi(0x1.FFFFFFFFFFFFFFFCp+62, 0x7FFFFFFFFFFFFFFF);
    try test__fixunstfdi(0x1.FFFFFFFFFFFFFFF8p+62, 0x7FFFFFFFFFFFFFFE);
    try test__fixunstfdi(0x1p+64, 0xFFFFFFFFFFFFFFFF);

    try test__fixunstfdi(-0x1.0000000000000000p+63, 0);
    try test__fixunstfdi(-0x1.FFFFFFFFFFFFFFFCp+62, 0);
    try test__fixunstfdi(-0x1.FFFFFFFFFFFFFFF8p+62, 0);
}

fn test__fixtfti(a: f128, expected: i128) !void {
    const x = __fixtfti(a);
    try testing.expect(x == expected);
}

fn test__fixunstfti(a: f128, expected: u128) !void {
    const x = __fixunstfti(a);
    try testing.expect(x == expected);
}

test "fixtfti" {
    try test__fixtfti(-math.floatMax(f128), math.minInt(i128));

    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+1023, math.minInt(i128));
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+1023, -0x80000000000000000000000000000000);

    try test__fixtfti(-0x1.0000000000000p+127, -0x80000000000000000000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+126, -0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFEp+126, -0x7FFFFFFFFFFFF8000000000000000000);

    try test__fixtfti(-0x1.0000000000001p+63, -0x8000000000000800);
    try test__fixtfti(-0x1.0000000000000p+63, -0x8000000000000000);
    try test__fixtfti(-0x1.FFFFFFFFFFFFFp+62, -0x7FFFFFFFFFFFFC00);
    try test__fixtfti(-0x1.FFFFFFFFFFFFEp+62, -0x7FFFFFFFFFFFF800);

    try test__fixtfti(-0x1.FFFFFEp+62, -0x7fffff8000000000);
    try test__fixtfti(-0x1.FFFFFCp+62, -0x7fffff0000000000);

    try test__fixtfti(-2.01, -2);
    try test__fixtfti(-2.0, -2);
    try test__fixtfti(-1.99, -1);
    try test__fixtfti(-1.0, -1);
    try test__fixtfti(-0.99, 0);
    try test__fixtfti(-0.5, 0);
    try test__fixtfti(-math.floatMin(f128), 0);
    try test__fixtfti(0.0, 0);
    try test__fixtfti(math.floatMin(f128), 0);
    try test__fixtfti(0.5, 0);
    try test__fixtfti(0.99, 0);
    try test__fixtfti(1.0, 1);
    try test__fixtfti(1.5, 1);
    try test__fixtfti(1.99, 1);
    try test__fixtfti(2.0, 2);
    try test__fixtfti(2.01, 2);

    try test__fixtfti(0x1.FFFFFCp+62, 0x7FFFFF0000000000);
    try test__fixtfti(0x1.FFFFFEp+62, 0x7FFFFF8000000000);

    try test__fixtfti(0x1.FFFFFFFFFFFFEp+62, 0x7FFFFFFFFFFFF800);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+62, 0x7FFFFFFFFFFFFC00);
    try test__fixtfti(0x1.0000000000000p+63, 0x8000000000000000);
    try test__fixtfti(0x1.0000000000001p+63, 0x8000000000000800);

    try test__fixtfti(0x1.FFFFFFFFFFFFEp+126, 0x7FFFFFFFFFFFF8000000000000000000);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+126, 0x7FFFFFFFFFFFFC000000000000000000);
    try test__fixtfti(0x1.0000000000000p+127, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

    try test__fixtfti(0x1.FFFFFFFFFFFFFp+1023, 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__fixtfti(0x1.FFFFFFFFFFFFFp+1023, math.maxInt(i128));

    try test__fixtfti(math.floatMax(f128), math.maxInt(i128));
}

test "fixunstfti" {
    try test__fixunstfti(math.inf(f128), 0xffffffffffffffffffffffffffffffff);

    try test__fixunstfti(0.0, 0);

    try test__fixunstfti(0.5, 0);
    try test__fixunstfti(0.99, 0);
    try test__fixunstfti(1.0, 1);
    try test__fixunstfti(1.5, 1);
    try test__fixunstfti(1.99, 1);
    try test__fixunstfti(2.0, 2);
    try test__fixunstfti(2.01, 2);
    try test__fixunstfti(-0.01, 0);
    try test__fixunstfti(-0.99, 0);

    try test__fixunstfti(0x1p+128, 0xffffffffffffffffffffffffffffffff);

    try test__fixunstfti(0x1.FFFFFEp+126, 0x7fffff80000000000000000000000000);
    try test__fixunstfti(0x1.FFFFFEp+127, 0xffffff00000000000000000000000000);
    try test__fixunstfti(0x1.FFFFFEp+128, 0xffffffffffffffffffffffffffffffff);
    try test__fixunstfti(0x1.FFFFFEp+129, 0xffffffffffffffffffffffffffffffff);
}

fn test__fixunshfti(a: f16, expected: u128) !void {
    const x = __fixunshfti(a);
    try testing.expect(x == expected);
}

test "fixunshfti for f16" {
    try test__fixunshfti(math.inf(f16), math.maxInt(u128));
    try test__fixunshfti(math.floatMax(f16), 65504);
}

fn test__fixunsxfti(a: f80, expected: u128) !void {
    const x = __fixunsxfti(a);
    try testing.expect(x == expected);
}

test "fixunsxfti for f80" {
    try test__fixunsxfti(math.inf(f80), math.maxInt(u128));
    try test__fixunsxfti(math.floatMax(f80), math.maxInt(u128));
    try test__fixunsxfti(math.maxInt(u64), math.maxInt(u64));
}
