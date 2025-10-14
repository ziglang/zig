// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/__expo2f.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/__expo2.c

const math = @import("../math.zig");
const std = @import("../std.zig");
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
/// Returns exp(x) / 2 for x >= log(maxFloat(T)).
pub fn expo2(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => expo2f(x),
        f64 => expo2d(x),
        else => @compileError("expo2 not implemented for " ++ @typeName(T)),
    };
}
/// Fast approximation of `2^x` for 32-bit floats.
///
/// This uses a scaling trick to approximate `2^x` as:
///     `exp(x - kln2) * scale^2`
/// where `kln2` ≈ k * ln(2), and `scale` is constructed using bit manipulation
/// to approximate `2^(k/2)`.
///
/// This avoids expensive floating-point operations and is optimized
/// for performance over precision.
fn expo2f(x: f32) f32 {
    const k: u32 = 235;
    const kln2 = 0x1.45C778p+7;

    const u = (0x7F + k / 2) << 23;
    const scale = @as(f32, @bitCast(u));
    return @exp(x - kln2) * scale * scale;
}

// This function is similar to `expo2f`, but for 64-bit floats.
fn expo2d(x: f64) f64 {
    const k: u32 = 2043;
    const kln2 = 0x1.62066151ADD8BP+10;

    const u = (0x3FF + k / 2) << 20;
    const scale = @as(f64, @bitCast(@as(u64, u) << 32));
    return @exp(x - kln2) * scale * scale;
}

test "expo2f approximates 2^x" {
    try expectApproxEqAbs(expo2f(7.3), math.pow(f32, 2.0, 7.3), 1e-6);
    try expectApproxEqAbs(expo2f(-1.0), math.pow(f32, 2.0, -1.0), 1e-6);
    try expectApproxEqAbs(expo2f(0.0), 1.0, 1e-6);
    try expectApproxEqAbs(expo2f(10.0), math.pow(f32, 2.0, 10.0), 1e-6);
    try expectApproxEqAbs(expo2f(3.5), math.pow(f32, 2.0, 3.5), 1e-6);
}

test "expo2d approximates 2^x" {
    try expectApproxEqAbs(expo2d(7.3), math.pow(f64, 2.0, 7.3), 1e-12);
    try expectApproxEqAbs(expo2d(-1.0), math.pow(f64, 2.0, -1.0), 1e-12);
    try expectApproxEqAbs(expo2d(0.0), 1.0, 1e-12);
    try expectApproxEqAbs(expo2d(10.0), math.pow(f64, 2.0, 10.0), 1e-12);
    try expectApproxEqAbs(expo2d(3.5), math.pow(f64, 2.0, 3.5), 1e-12);
}
