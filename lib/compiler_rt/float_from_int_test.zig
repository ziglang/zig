const std = @import("std");
const testing = std.testing;
const math = std.math;

const __floatunsihf = @import("floatunsihf.zig").__floatunsihf;

// Conversion to f32
const __floatsisf = @import("floatsisf.zig").__floatsisf;
const __floatunsisf = @import("floatunsisf.zig").__floatunsisf;
const __floatdisf = @import("floatdisf.zig").__floatdisf;
const __floatundisf = @import("floatundisf.zig").__floatundisf;
const __floattisf = @import("floattisf.zig").__floattisf;
const __floatuntisf = @import("floatuntisf.zig").__floatuntisf;

// Conversion to f64
const __floatsidf = @import("floatsidf.zig").__floatsidf;
const __floatunsidf = @import("floatunsidf.zig").__floatunsidf;
const __floatdidf = @import("floatdidf.zig").__floatdidf;
const __floatundidf = @import("floatundidf.zig").__floatundidf;
const __floattidf = @import("floattidf.zig").__floattidf;
const __floatuntidf = @import("floatuntidf.zig").__floatuntidf;

// Conversion to f128
const __floatsitf = @import("floatsitf.zig").__floatsitf;
const __floatunsitf = @import("floatunsitf.zig").__floatunsitf;
const __floatditf = @import("floatditf.zig").__floatditf;
const __floatunditf = @import("floatunditf.zig").__floatunditf;
const __floattitf = @import("floattitf.zig").__floattitf;
const __floatuntitf = @import("floatuntitf.zig").__floatuntitf;

fn test__floatsisf(a: i32, expected: u32) !void {
    const r = __floatsisf(a);
    try std.testing.expect(@as(u32, @bitCast(r)) == expected);
}

fn test_one_floatunsisf(a: u32, expected: u32) !void {
    const r = __floatunsisf(a);
    try std.testing.expect(@as(u32, @bitCast(r)) == expected);
}

test "floatsisf" {
    try test__floatsisf(0, 0x00000000);
    try test__floatsisf(1, 0x3f800000);
    try test__floatsisf(-1, 0xbf800000);
    try test__floatsisf(0x7FFFFFFF, 0x4f000000);
    try test__floatsisf(@bitCast(@as(u32, @intCast(0x80000000))), 0xcf000000);
}

test "floatunsisf" {
    // Test the produced bit pattern
    try test_one_floatunsisf(0, 0);
    try test_one_floatunsisf(1, 0x3f800000);
    try test_one_floatunsisf(0x7FFFFFFF, 0x4f000000);
    try test_one_floatunsisf(0x80000000, 0x4f000000);
    try test_one_floatunsisf(0xFFFFFFFF, 0x4f800000);
}

fn test__floatdisf(a: i64, expected: f32) !void {
    const x = __floatdisf(a);
    try testing.expect(x == expected);
}

fn test__floatundisf(a: u64, expected: f32) !void {
    try std.testing.expectEqual(expected, __floatundisf(a));
}

test "floatdisf" {
    try test__floatdisf(0, 0.0);
    try test__floatdisf(1, 1.0);
    try test__floatdisf(2, 2.0);
    try test__floatdisf(-1, -1.0);
    try test__floatdisf(-2, -2.0);
    try test__floatdisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatdisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatdisf(@bitCast(@as(u64, 0x8000008000000000)), -0x1.FFFFFEp+62);
    try test__floatdisf(@bitCast(@as(u64, 0x8000010000000000)), -0x1.FFFFFCp+62);
    try test__floatdisf(@bitCast(@as(u64, 0x8000000000000000)), -0x1.000000p+63);
    try test__floatdisf(@bitCast(@as(u64, 0x8000000000000001)), -0x1.000000p+63);
    try test__floatdisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floatdisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floatdisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);
}

test "floatundisf" {
    try test__floatundisf(0, 0.0);
    try test__floatundisf(1, 1.0);
    try test__floatundisf(2, 2.0);
    try test__floatundisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatundisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatundisf(0x8000008000000000, 0x1p+63);
    try test__floatundisf(0x8000010000000000, 0x1.000002p+63);
    try test__floatundisf(0x8000000000000000, 0x1p+63);
    try test__floatundisf(0x8000000000000001, 0x1p+63);
    try test__floatundisf(0xFFFFFFFFFFFFFFFE, 0x1p+64);
    try test__floatundisf(0xFFFFFFFFFFFFFFFF, 0x1p+64);
    try test__floatundisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floatundisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floatundisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);
}

fn test__floattisf(a: i128, expected: f32) !void {
    const x = __floattisf(a);
    try testing.expect(x == expected);
}

fn test__floatuntisf(a: u128, expected: f32) !void {
    const x = __floatuntisf(a);
    try testing.expect(x == expected);
}

test "floattisf" {
    try test__floattisf(0, 0.0);

    try test__floattisf(1, 1.0);
    try test__floattisf(2, 2.0);
    try test__floattisf(-1, -1.0);
    try test__floattisf(-2, -2.0);

    try test__floattisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floattisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);

    try test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000008000000000), -0x1.FFFFFEp+62);
    try test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000010000000000), -0x1.FFFFFCp+62);

    try test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000000000000000), -0x1.000000p+63);
    try test__floattisf(make_ti(0xFFFFFFFFFFFFFFFF, 0x8000000000000001), -0x1.000000p+63);

    try test__floattisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floattisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floattisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);

    try test__floattisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floattisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);

    try test__floattisf(make_ti(0x0007FB72E8000000, 0), 0x1.FEDCBAp+114);

    try test__floattisf(make_ti(0x0007FB72EA000000, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72EB000000, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72EBFFFFFF, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72EC000000, 0), 0x1.FEDCBCp+114);
    try test__floattisf(make_ti(0x0007FB72E8000001, 0), 0x1.FEDCBAp+114);

    try test__floattisf(make_ti(0x0007FB72E6000000, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72E7000000, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72E7FFFFFF, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72E4000001, 0), 0x1.FEDCBAp+114);
    try test__floattisf(make_ti(0x0007FB72E4000000, 0), 0x1.FEDCB8p+114);
}

test "floatuntisf" {
    try test__floatuntisf(0, 0.0);

    try test__floatuntisf(1, 1.0);
    try test__floatuntisf(2, 2.0);
    try test__floatuntisf(20, 20.0);

    try test__floatuntisf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatuntisf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);

    try test__floatuntisf(make_uti(0x8000008000000000, 0), 0x1.000001p+127);
    try test__floatuntisf(make_uti(0x8000000000000800, 0), 0x1.0p+127);
    try test__floatuntisf(make_uti(0x8000010000000000, 0), 0x1.000002p+127);

    try test__floatuntisf(make_uti(0x8000000000000000, 0), 0x1.000000p+127);

    try test__floatuntisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatuntisf(0x0007FB72EB000000, 0x1.FEDCBACp+50);

    try test__floatuntisf(0x0007FB72EC000000, 0x1.FEDCBBp+50);

    try test__floatuntisf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatuntisf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatuntisf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floatuntisf(0xFFFFFFFFFFFFFFFE, 0x1p+64);
    try test__floatuntisf(0xFFFFFFFFFFFFFFFF, 0x1p+64);

    try test__floatuntisf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72EA000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EB000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EBFFFFFF, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72EC000000, 0x1.FEDCBCp+50);
    try test__floatuntisf(0x0007FB72E8000001, 0x1.FEDCBAp+50);

    try test__floatuntisf(0x0007FB72E6000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E7000000, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E7FFFFFF, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E4000001, 0x1.FEDCBAp+50);
    try test__floatuntisf(0x0007FB72E4000000, 0x1.FEDCB8p+50);

    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCB90000000000001), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBA0000000000000), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBAFFFFFFFFFFFFF), 0x1.FEDCBAp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBB0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBB0000000000001), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBBFFFFFFFFFFFFF), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBC0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBC0000000000001), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBD0000000000000), 0x1.FEDCBCp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBD0000000000001), 0x1.FEDCBEp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBDFFFFFFFFFFFFF), 0x1.FEDCBEp+76);
    try test__floatuntisf(make_uti(0x0000000000001FED, 0xCBE0000000000000), 0x1.FEDCBEp+76);

    // Test overflow to infinity
    try test__floatuntisf(math.maxInt(u128), @bitCast(math.inf(f32)));
}

fn test_one_floatsidf(a: i32, expected: u64) !void {
    const r = __floatsidf(a);
    try std.testing.expect(@as(u64, @bitCast(r)) == expected);
}

fn test_one_floatunsidf(a: u32, expected: u64) !void {
    const r = __floatunsidf(a);
    try std.testing.expect(@as(u64, @bitCast(r)) == expected);
}

test "floatsidf" {
    try test_one_floatsidf(0, 0x0000000000000000);
    try test_one_floatsidf(1, 0x3ff0000000000000);
    try test_one_floatsidf(-1, 0xbff0000000000000);
    try test_one_floatsidf(0x7FFFFFFF, 0x41dfffffffc00000);
    try test_one_floatsidf(@bitCast(@as(u32, @intCast(0x80000000))), 0xc1e0000000000000);
}

test "floatunsidf" {
    try test_one_floatunsidf(0, 0x0000000000000000);
    try test_one_floatunsidf(1, 0x3ff0000000000000);
    try test_one_floatunsidf(0x7FFFFFFF, 0x41dfffffffc00000);
    try test_one_floatunsidf(@intCast(0x80000000), 0x41e0000000000000);
    try test_one_floatunsidf(@intCast(0xFFFFFFFF), 0x41efffffffe00000);
}

fn test__floatdidf(a: i64, expected: f64) !void {
    const r = __floatdidf(a);
    try testing.expect(r == expected);
}

fn test__floatundidf(a: u64, expected: f64) !void {
    const r = __floatundidf(a);
    try testing.expect(r == expected);
}

test "floatdidf" {
    try test__floatdidf(0, 0.0);
    try test__floatdidf(1, 1.0);
    try test__floatdidf(2, 2.0);
    try test__floatdidf(20, 20.0);
    try test__floatdidf(-1, -1.0);
    try test__floatdidf(-2, -2.0);
    try test__floatdidf(-20, -20.0);
    try test__floatdidf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatdidf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floatdidf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatdidf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000008000000000))), -0x1.FFFFFEp+62);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000000000000800))), -0x1.FFFFFFFFFFFFEp+62);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000010000000000))), -0x1.FFFFFCp+62);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000000000001000))), -0x1.FFFFFFFFFFFFCp+62);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000000000000000))), -0x1.000000p+63);
    try test__floatdidf(@bitCast(@as(u64, @intCast(0x8000000000000001))), -0x1.000000p+63); // 0x8000000000000001
    try test__floatdidf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    try test__floatdidf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatdidf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floatdidf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floatdidf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floatdidf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);
    try test__floatdidf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatdidf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatdidf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floatdidf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floatdidf(0x0007FB72E4000000, 0x1.FEDCB9p+50);
    try test__floatdidf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DA1, 0x1.1A3CFE870496Dp+57);
    try test__floatdidf(0x023479FD0E092DB0, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DB8, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DB6, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DBF, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DC1, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DC7, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DC8, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DCF, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DD0, 0x1.1A3CFE870496Ep+57);
    try test__floatdidf(0x023479FD0E092DD1, 0x1.1A3CFE870496Fp+57);
    try test__floatdidf(0x023479FD0E092DD8, 0x1.1A3CFE870496Fp+57);
    try test__floatdidf(0x023479FD0E092DDF, 0x1.1A3CFE870496Fp+57);
    try test__floatdidf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);
}

test "floatundidf" {
    try test__floatundidf(0, 0.0);
    try test__floatundidf(1, 1.0);
    try test__floatundidf(2, 2.0);
    try test__floatundidf(20, 20.0);
    try test__floatundidf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatundidf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floatundidf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatundidf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);
    try test__floatundidf(0x8000008000000000, 0x1.000001p+63);
    try test__floatundidf(0x8000000000000800, 0x1.0000000000001p+63);
    try test__floatundidf(0x8000010000000000, 0x1.000002p+63);
    try test__floatundidf(0x8000000000001000, 0x1.0000000000002p+63);
    try test__floatundidf(0x8000000000000000, 0x1p+63);
    try test__floatundidf(0x8000000000000001, 0x1p+63);
    try test__floatundidf(0x0007FB72E8000000, 0x1.FEDCBAp+50);
    try test__floatundidf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatundidf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floatundidf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floatundidf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floatundidf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);
    try test__floatundidf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatundidf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatundidf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floatundidf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floatundidf(0x0007FB72E4000000, 0x1.FEDCB9p+50);
    try test__floatundidf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DA1, 0x1.1A3CFE870496Dp+57);
    try test__floatundidf(0x023479FD0E092DB0, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DB8, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DB6, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DBF, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DC1, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DC7, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DC8, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DCF, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DD0, 0x1.1A3CFE870496Ep+57);
    try test__floatundidf(0x023479FD0E092DD1, 0x1.1A3CFE870496Fp+57);
    try test__floatundidf(0x023479FD0E092DD8, 0x1.1A3CFE870496Fp+57);
    try test__floatundidf(0x023479FD0E092DDF, 0x1.1A3CFE870496Fp+57);
    try test__floatundidf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);
}

fn test__floattidf(a: i128, expected: f64) !void {
    const x = __floattidf(a);
    try testing.expect(x == expected);
}

fn test__floatuntidf(a: u128, expected: f64) !void {
    const x = __floatuntidf(a);
    try testing.expect(x == expected);
}

test "floattidf" {
    try test__floattidf(0, 0.0);

    try test__floattidf(1, 1.0);
    try test__floattidf(2, 2.0);
    try test__floattidf(20, 20.0);
    try test__floattidf(-1, -1.0);
    try test__floattidf(-2, -2.0);
    try test__floattidf(-20, -20.0);

    try test__floattidf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floattidf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floattidf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floattidf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);

    try test__floattidf(make_ti(0x8000008000000000, 0), -0x1.FFFFFEp+126);
    try test__floattidf(make_ti(0x8000000000000800, 0), -0x1.FFFFFFFFFFFFEp+126);
    try test__floattidf(make_ti(0x8000010000000000, 0), -0x1.FFFFFCp+126);
    try test__floattidf(make_ti(0x8000000000001000, 0), -0x1.FFFFFFFFFFFFCp+126);

    try test__floattidf(make_ti(0x8000000000000000, 0), -0x1.000000p+127);
    try test__floattidf(make_ti(0x8000000000000001, 0), -0x1.000000p+127);

    try test__floattidf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floattidf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floattidf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floattidf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floattidf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floattidf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);

    try test__floattidf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floattidf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floattidf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floattidf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floattidf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floattidf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DA1, 0x1.1A3CFE870496Dp+57);
    try test__floattidf(0x023479FD0E092DB0, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DB8, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DB6, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DBF, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DC1, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DC7, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DC8, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DCF, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DD0, 0x1.1A3CFE870496Ep+57);
    try test__floattidf(0x023479FD0E092DD1, 0x1.1A3CFE870496Fp+57);
    try test__floattidf(0x023479FD0E092DD8, 0x1.1A3CFE870496Fp+57);
    try test__floattidf(0x023479FD0E092DDF, 0x1.1A3CFE870496Fp+57);
    try test__floattidf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);

    try test__floattidf(make_ti(0x023479FD0E092DC0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DA1, 1), 0x1.1A3CFE870496Dp+121);
    try test__floattidf(make_ti(0x023479FD0E092DB0, 2), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DB8, 3), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DB6, 4), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DBF, 5), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DC1, 6), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DC7, 7), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DC8, 8), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DCF, 9), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DD0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floattidf(make_ti(0x023479FD0E092DD1, 11), 0x1.1A3CFE870496Fp+121);
    try test__floattidf(make_ti(0x023479FD0E092DD8, 12), 0x1.1A3CFE870496Fp+121);
    try test__floattidf(make_ti(0x023479FD0E092DDF, 13), 0x1.1A3CFE870496Fp+121);
    try test__floattidf(make_ti(0x023479FD0E092DE0, 14), 0x1.1A3CFE870496Fp+121);
}

test "floatuntidf" {
    try test__floatuntidf(0, 0.0);

    try test__floatuntidf(1, 1.0);
    try test__floatuntidf(2, 2.0);
    try test__floatuntidf(20, 20.0);

    try test__floatuntidf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatuntidf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floatuntidf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatuntidf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);

    try test__floatuntidf(make_uti(0x8000008000000000, 0), 0x1.000001p+127);
    try test__floatuntidf(make_uti(0x8000000000000800, 0), 0x1.0000000000001p+127);
    try test__floatuntidf(make_uti(0x8000010000000000, 0), 0x1.000002p+127);
    try test__floatuntidf(make_uti(0x8000000000001000, 0), 0x1.0000000000002p+127);

    try test__floatuntidf(make_uti(0x8000000000000000, 0), 0x1.000000p+127);
    try test__floatuntidf(make_uti(0x8000000000000001, 0), 0x1.0000000000000002p+127);

    try test__floatuntidf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntidf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatuntidf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floatuntidf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floatuntidf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floatuntidf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);

    try test__floatuntidf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatuntidf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatuntidf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floatuntidf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floatuntidf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floatuntidf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DA1, 0x1.1A3CFE870496Dp+57);
    try test__floatuntidf(0x023479FD0E092DB0, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DB8, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DB6, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DBF, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DC1, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DC7, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DC8, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DCF, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DD0, 0x1.1A3CFE870496Ep+57);
    try test__floatuntidf(0x023479FD0E092DD1, 0x1.1A3CFE870496Fp+57);
    try test__floatuntidf(0x023479FD0E092DD8, 0x1.1A3CFE870496Fp+57);
    try test__floatuntidf(0x023479FD0E092DDF, 0x1.1A3CFE870496Fp+57);
    try test__floatuntidf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);

    try test__floatuntidf(make_uti(0x023479FD0E092DC0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DA1, 1), 0x1.1A3CFE870496Dp+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DB0, 2), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DB8, 3), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DB6, 4), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DBF, 5), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DC1, 6), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DC7, 7), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DC8, 8), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DCF, 9), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DD0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DD1, 11), 0x1.1A3CFE870496Fp+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DD8, 12), 0x1.1A3CFE870496Fp+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DDF, 13), 0x1.1A3CFE870496Fp+121);
    try test__floatuntidf(make_uti(0x023479FD0E092DE0, 14), 0x1.1A3CFE870496Fp+121);
}

fn test__floatsitf(a: i32, expected: u128) !void {
    const r = __floatsitf(a);
    try std.testing.expect(@as(u128, @bitCast(r)) == expected);
}

test "floatsitf" {
    try test__floatsitf(0, 0);
    try test__floatsitf(0x7FFFFFFF, 0x401dfffffffc00000000000000000000);
    try test__floatsitf(0x12345678, 0x401b2345678000000000000000000000);
    try test__floatsitf(-0x12345678, 0xc01b2345678000000000000000000000);
    try test__floatsitf(@bitCast(@as(u32, @intCast(0xffffffff))), 0xbfff0000000000000000000000000000);
    try test__floatsitf(@bitCast(@as(u32, @intCast(0x80000000))), 0xc01e0000000000000000000000000000);
}

fn test__floatunsitf(a: u32, expected_hi: u64, expected_lo: u64) !void {
    const x = __floatunsitf(a);

    const x_repr: u128 = @bitCast(x);
    const x_hi: u64 = @intCast(x_repr >> 64);
    const x_lo: u64 = @truncate(x_repr);

    if (x_hi == expected_hi and x_lo == expected_lo) {
        return;
    }
    // nan repr
    else if (expected_hi == 0x7fff800000000000 and expected_lo == 0x0) {
        if ((x_hi & 0x7fff000000000000) == 0x7fff000000000000 and ((x_hi & 0xffffffffffff) > 0 or x_lo > 0)) {
            return;
        }
    }

    @panic("__floatunsitf test failure");
}

test "floatunsitf" {
    try test__floatunsitf(0x7fffffff, 0x401dfffffffc0000, 0x0);
    try test__floatunsitf(0, 0x0, 0x0);
    try test__floatunsitf(0xffffffff, 0x401efffffffe0000, 0x0);
    try test__floatunsitf(0x12345678, 0x401b234567800000, 0x0);
}

fn test__floatditf(a: i64, expected: f128) !void {
    const x = __floatditf(a);
    try testing.expect(x == expected);
}

fn test__floatunditf(a: u64, expected_hi: u64, expected_lo: u64) !void {
    const x = __floatunditf(a);

    const x_repr: u128 = @bitCast(x);
    const x_hi: u64 = @intCast(x_repr >> 64);
    const x_lo: u64 = @truncate(x_repr);

    if (x_hi == expected_hi and x_lo == expected_lo) {
        return;
    }
    // nan repr
    else if (expected_hi == 0x7fff800000000000 and expected_lo == 0x0) {
        if ((x_hi & 0x7fff000000000000) == 0x7fff000000000000 and ((x_hi & 0xffffffffffff) > 0 or x_lo > 0)) {
            return;
        }
    }

    @panic("__floatunditf test failure");
}

test "floatditf" {
    try test__floatditf(0x7fffffffffffffff, make_tf(0x403dffffffffffff, 0xfffc000000000000));
    try test__floatditf(0x123456789abcdef1, make_tf(0x403b23456789abcd, 0xef10000000000000));
    try test__floatditf(0x2, make_tf(0x4000000000000000, 0x0));
    try test__floatditf(0x1, make_tf(0x3fff000000000000, 0x0));
    try test__floatditf(0x0, make_tf(0x0, 0x0));
    try test__floatditf(@bitCast(@as(u64, 0xffffffffffffffff)), make_tf(0xbfff000000000000, 0x0));
    try test__floatditf(@bitCast(@as(u64, 0xfffffffffffffffe)), make_tf(0xc000000000000000, 0x0));
    try test__floatditf(-0x123456789abcdef1, make_tf(0xc03b23456789abcd, 0xef10000000000000));
    try test__floatditf(@bitCast(@as(u64, 0x8000000000000000)), make_tf(0xc03e000000000000, 0x0));
}

test "floatunditf" {
    try test__floatunditf(0xffffffffffffffff, 0x403effffffffffff, 0xfffe000000000000);
    try test__floatunditf(0xfffffffffffffffe, 0x403effffffffffff, 0xfffc000000000000);
    try test__floatunditf(0x8000000000000000, 0x403e000000000000, 0x0);
    try test__floatunditf(0x7fffffffffffffff, 0x403dffffffffffff, 0xfffc000000000000);
    try test__floatunditf(0x123456789abcdef1, 0x403b23456789abcd, 0xef10000000000000);
    try test__floatunditf(0x2, 0x4000000000000000, 0x0);
    try test__floatunditf(0x1, 0x3fff000000000000, 0x0);
    try test__floatunditf(0x0, 0x0, 0x0);
}

fn test__floattitf(a: i128, expected: f128) !void {
    const x = __floattitf(a);
    try testing.expect(x == expected);
}

fn test__floatuntitf(a: u128, expected: f128) !void {
    const x = __floatuntitf(a);
    try testing.expect(x == expected);
}

test "floattitf" {
    try test__floattitf(0, 0.0);

    try test__floattitf(1, 1.0);
    try test__floattitf(2, 2.0);
    try test__floattitf(20, 20.0);
    try test__floattitf(-1, -1.0);
    try test__floattitf(-2, -2.0);
    try test__floattitf(-20, -20.0);

    try test__floattitf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floattitf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floattitf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floattitf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);

    try test__floattitf(make_ti(0x8000008000000000, 0), -0x1.FFFFFEp+126);
    try test__floattitf(make_ti(0x8000000000000800, 0), -0x1.FFFFFFFFFFFFEp+126);
    try test__floattitf(make_ti(0x8000010000000000, 0), -0x1.FFFFFCp+126);
    try test__floattitf(make_ti(0x8000000000001000, 0), -0x1.FFFFFFFFFFFFCp+126);

    try test__floattitf(make_ti(0x8000000000000000, 0), -0x1.000000p+127);
    try test__floattitf(make_ti(0x8000000000000001, 0), -0x1.FFFFFFFFFFFFFFFCp+126);

    try test__floattitf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floattitf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floattitf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floattitf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floattitf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floattitf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);

    try test__floattitf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floattitf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floattitf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floattitf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floattitf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floattitf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floattitf(0x023479FD0E092DA1, 0x1.1A3CFE870496D08p+57);
    try test__floattitf(0x023479FD0E092DB0, 0x1.1A3CFE870496D8p+57);
    try test__floattitf(0x023479FD0E092DB8, 0x1.1A3CFE870496DCp+57);
    try test__floattitf(0x023479FD0E092DB6, 0x1.1A3CFE870496DBp+57);
    try test__floattitf(0x023479FD0E092DBF, 0x1.1A3CFE870496DF8p+57);
    try test__floattitf(0x023479FD0E092DC1, 0x1.1A3CFE870496E08p+57);
    try test__floattitf(0x023479FD0E092DC7, 0x1.1A3CFE870496E38p+57);
    try test__floattitf(0x023479FD0E092DC8, 0x1.1A3CFE870496E4p+57);
    try test__floattitf(0x023479FD0E092DCF, 0x1.1A3CFE870496E78p+57);
    try test__floattitf(0x023479FD0E092DD0, 0x1.1A3CFE870496E8p+57);
    try test__floattitf(0x023479FD0E092DD1, 0x1.1A3CFE870496E88p+57);
    try test__floattitf(0x023479FD0E092DD8, 0x1.1A3CFE870496ECp+57);
    try test__floattitf(0x023479FD0E092DDF, 0x1.1A3CFE870496EF8p+57);
    try test__floattitf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);

    try test__floattitf(make_ti(0x023479FD0E092DC0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floattitf(make_ti(0x023479FD0E092DA1, 1), 0x1.1A3CFE870496D08p+121);
    try test__floattitf(make_ti(0x023479FD0E092DB0, 2), 0x1.1A3CFE870496D8p+121);
    try test__floattitf(make_ti(0x023479FD0E092DB8, 3), 0x1.1A3CFE870496DCp+121);
    try test__floattitf(make_ti(0x023479FD0E092DB6, 4), 0x1.1A3CFE870496DBp+121);
    try test__floattitf(make_ti(0x023479FD0E092DBF, 5), 0x1.1A3CFE870496DF8p+121);
    try test__floattitf(make_ti(0x023479FD0E092DC1, 6), 0x1.1A3CFE870496E08p+121);
    try test__floattitf(make_ti(0x023479FD0E092DC7, 7), 0x1.1A3CFE870496E38p+121);
    try test__floattitf(make_ti(0x023479FD0E092DC8, 8), 0x1.1A3CFE870496E4p+121);
    try test__floattitf(make_ti(0x023479FD0E092DCF, 9), 0x1.1A3CFE870496E78p+121);
    try test__floattitf(make_ti(0x023479FD0E092DD0, 0), 0x1.1A3CFE870496E8p+121);
    try test__floattitf(make_ti(0x023479FD0E092DD1, 11), 0x1.1A3CFE870496E88p+121);
    try test__floattitf(make_ti(0x023479FD0E092DD8, 12), 0x1.1A3CFE870496ECp+121);
    try test__floattitf(make_ti(0x023479FD0E092DDF, 13), 0x1.1A3CFE870496EF8p+121);
    try test__floattitf(make_ti(0x023479FD0E092DE0, 14), 0x1.1A3CFE870496Fp+121);

    try test__floattitf(make_ti(0, 0xFFFFFFFFFFFFFFFF), 0x1.FFFFFFFFFFFFFFFEp+63);

    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC2801), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC3000), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC37FF), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC3800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4000), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC47FF), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC4801), 0x1.23456789ABCDEF0123456789ABC5p+124);
    try test__floattitf(make_ti(0x123456789ABCDEF0, 0x123456789ABC57FF), 0x1.23456789ABCDEF0123456789ABC5p+124);
}

test "floatuntitf" {
    try test__floatuntitf(0, 0.0);

    try test__floatuntitf(1, 1.0);
    try test__floatuntitf(2, 2.0);
    try test__floatuntitf(20, 20.0);

    try test__floatuntitf(0x7FFFFF8000000000, 0x1.FFFFFEp+62);
    try test__floatuntitf(0x7FFFFFFFFFFFF800, 0x1.FFFFFFFFFFFFEp+62);
    try test__floatuntitf(0x7FFFFF0000000000, 0x1.FFFFFCp+62);
    try test__floatuntitf(0x7FFFFFFFFFFFF000, 0x1.FFFFFFFFFFFFCp+62);
    try test__floatuntitf(0x7FFFFFFFFFFFFFFF, 0xF.FFFFFFFFFFFFFFEp+59);
    try test__floatuntitf(0xFFFFFFFFFFFFFFFE, 0xF.FFFFFFFFFFFFFFEp+60);
    try test__floatuntitf(0xFFFFFFFFFFFFFFFF, 0xF.FFFFFFFFFFFFFFFp+60);

    try test__floatuntitf(0x8000008000000000, 0x8.000008p+60);
    try test__floatuntitf(0x8000000000000800, 0x8.0000000000008p+60);
    try test__floatuntitf(0x8000010000000000, 0x8.00001p+60);
    try test__floatuntitf(0x8000000000001000, 0x8.000000000001p+60);

    try test__floatuntitf(0x8000000000000000, 0x8p+60);
    try test__floatuntitf(0x8000000000000001, 0x8.000000000000001p+60);

    try test__floatuntitf(0x0007FB72E8000000, 0x1.FEDCBAp+50);

    try test__floatuntitf(0x0007FB72EA000000, 0x1.FEDCBA8p+50);
    try test__floatuntitf(0x0007FB72EB000000, 0x1.FEDCBACp+50);
    try test__floatuntitf(0x0007FB72EBFFFFFF, 0x1.FEDCBAFFFFFFCp+50);
    try test__floatuntitf(0x0007FB72EC000000, 0x1.FEDCBBp+50);
    try test__floatuntitf(0x0007FB72E8000001, 0x1.FEDCBA0000004p+50);

    try test__floatuntitf(0x0007FB72E6000000, 0x1.FEDCB98p+50);
    try test__floatuntitf(0x0007FB72E7000000, 0x1.FEDCB9Cp+50);
    try test__floatuntitf(0x0007FB72E7FFFFFF, 0x1.FEDCB9FFFFFFCp+50);
    try test__floatuntitf(0x0007FB72E4000001, 0x1.FEDCB90000004p+50);
    try test__floatuntitf(0x0007FB72E4000000, 0x1.FEDCB9p+50);

    try test__floatuntitf(0x023479FD0E092DC0, 0x1.1A3CFE870496Ep+57);
    try test__floatuntitf(0x023479FD0E092DA1, 0x1.1A3CFE870496D08p+57);
    try test__floatuntitf(0x023479FD0E092DB0, 0x1.1A3CFE870496D8p+57);
    try test__floatuntitf(0x023479FD0E092DB8, 0x1.1A3CFE870496DCp+57);
    try test__floatuntitf(0x023479FD0E092DB6, 0x1.1A3CFE870496DBp+57);
    try test__floatuntitf(0x023479FD0E092DBF, 0x1.1A3CFE870496DF8p+57);
    try test__floatuntitf(0x023479FD0E092DC1, 0x1.1A3CFE870496E08p+57);
    try test__floatuntitf(0x023479FD0E092DC7, 0x1.1A3CFE870496E38p+57);
    try test__floatuntitf(0x023479FD0E092DC8, 0x1.1A3CFE870496E4p+57);
    try test__floatuntitf(0x023479FD0E092DCF, 0x1.1A3CFE870496E78p+57);
    try test__floatuntitf(0x023479FD0E092DD0, 0x1.1A3CFE870496E8p+57);
    try test__floatuntitf(0x023479FD0E092DD1, 0x1.1A3CFE870496E88p+57);
    try test__floatuntitf(0x023479FD0E092DD8, 0x1.1A3CFE870496ECp+57);
    try test__floatuntitf(0x023479FD0E092DDF, 0x1.1A3CFE870496EF8p+57);
    try test__floatuntitf(0x023479FD0E092DE0, 0x1.1A3CFE870496Fp+57);

    try test__floatuntitf(make_uti(0x023479FD0E092DC0, 0), 0x1.1A3CFE870496Ep+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DA1, 1), 0x1.1A3CFE870496D08p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DB0, 2), 0x1.1A3CFE870496D8p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DB8, 3), 0x1.1A3CFE870496DCp+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DB6, 4), 0x1.1A3CFE870496DBp+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DBF, 5), 0x1.1A3CFE870496DF8p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DC1, 6), 0x1.1A3CFE870496E08p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DC7, 7), 0x1.1A3CFE870496E38p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DC8, 8), 0x1.1A3CFE870496E4p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DCF, 9), 0x1.1A3CFE870496E78p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DD0, 0), 0x1.1A3CFE870496E8p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DD1, 11), 0x1.1A3CFE870496E88p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DD8, 12), 0x1.1A3CFE870496ECp+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DDF, 13), 0x1.1A3CFE870496EF8p+121);
    try test__floatuntitf(make_uti(0x023479FD0E092DE0, 14), 0x1.1A3CFE870496Fp+121);

    try test__floatuntitf(make_uti(0, 0xFFFFFFFFFFFFFFFF), 0x1.FFFFFFFFFFFFFFFEp+63);

    try test__floatuntitf(make_uti(0xFFFFFFFFFFFFFFFF, 0x0000000000000000), 0x1.FFFFFFFFFFFFFFFEp+127);
    try test__floatuntitf(make_uti(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF), 0x1.0000000000000000p+128);

    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC2801), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC3000), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC37FF), 0x1.23456789ABCDEF0123456789ABC3p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC3800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC4000), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC47FF), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC4800), 0x1.23456789ABCDEF0123456789ABC4p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC4801), 0x1.23456789ABCDEF0123456789ABC5p+124);
    try test__floatuntitf(make_uti(0x123456789ABCDEF0, 0x123456789ABC57FF), 0x1.23456789ABCDEF0123456789ABC5p+124);
}

fn make_ti(high: u64, low: u64) i128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return @bitCast(result);
}

fn make_uti(high: u64, low: u64) u128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return result;
}

fn make_tf(high: u64, low: u64) f128 {
    var result: u128 = high;
    result <<= 64;
    result |= low;
    return @bitCast(result);
}

test "conversion to f16" {
    try testing.expect(__floatunsihf(@as(u32, 0)) == 0.0);
    try testing.expect(__floatunsihf(@as(u32, 1)) == 1.0);
    try testing.expect(__floatunsihf(@as(u32, 65504)) == 65504);
    try testing.expect(__floatunsihf(@as(u32, 65504 + (1 << 4))) == math.inf(f16));
}

test "conversion to f32" {
    try testing.expect(__floatunsisf(@as(u32, 0)) == 0.0);
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u32))) != 1.0);
    try testing.expect(__floatsisf(@as(i32, math.minInt(i32))) != 1.0);
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24))) == math.maxInt(u24));
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24)) + 1) == math.maxInt(u24) + 1); // 0x100_0000 - Exact
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24)) + 2) == math.maxInt(u24) + 1); // 0x100_0001 - Tie: Rounds down to even
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24)) + 3) == math.maxInt(u24) + 3); // 0x100_0002 - Exact
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24)) + 4) == math.maxInt(u24) + 5); // 0x100_0003 - Tie: Rounds up to even
    try testing.expect(__floatunsisf(@as(u32, math.maxInt(u24)) + 5) == math.maxInt(u24) + 5); // 0x100_0004 - Exact
}

test "conversion to f80" {
    if (std.debug.runtime_safety) return error.SkipZigTest;

    const floatFromInt = @import("./float_from_int.zig").floatFromInt;

    try testing.expect(floatFromInt(f80, @as(i80, -12)) == -12);
    try testing.expect(@as(u80, @intFromFloat(floatFromInt(f80, @as(u64, math.maxInt(u64)) + 0))) == math.maxInt(u64) + 0);
    try testing.expect(@as(u80, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 1))) == math.maxInt(u64) + 1);

    try testing.expect(floatFromInt(f80, @as(u32, 0)) == 0.0);
    try testing.expect(floatFromInt(f80, @as(u32, 1)) == 1.0);
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u32, math.maxInt(u24)) + 0))) == math.maxInt(u24));
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 0))) == math.maxInt(u64));
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 1))) == math.maxInt(u64) + 1); // Exact
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 2))) == math.maxInt(u64) + 1); // Rounds down
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 3))) == math.maxInt(u64) + 3); // Tie - Exact
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u64)) + 4))) == math.maxInt(u64) + 5); // Rounds up

    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 0))) == math.maxInt(u65) + 1); // Rounds up
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 1))) == math.maxInt(u65) + 1); // Exact
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 2))) == math.maxInt(u65) + 1); // Rounds down
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 3))) == math.maxInt(u65) + 1); // Tie - Rounds down
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 4))) == math.maxInt(u65) + 5); // Rounds up
    try testing.expect(@as(u128, @intFromFloat(floatFromInt(f80, @as(u80, math.maxInt(u65)) + 5))) == math.maxInt(u65) + 5); // Exact
}
