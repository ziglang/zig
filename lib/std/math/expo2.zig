// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/__expo2f.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/__expo2.c

const math = @import("../math.zig");

/// Returns exp(x) / 2 for x >= log(maxFloat(T)).
pub fn expo2(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => expo2f(x),
        f64 => expo2d(x),
        else => @compileError("expo2 not implemented for " ++ @typeName(T)),
    };
}

fn expo2f(x: f32) f32 {
    const k: u32 = 235;
    const kln2 = 0x1.45C778p+7;

    const u = (0x7F + k / 2) << 23;
    const scale = @bitCast(f32, u);
    return math.exp(x - kln2) * scale * scale;
}

fn expo2d(x: f64) f64 {
    const k: u32 = 2043;
    const kln2 = 0x1.62066151ADD8BP+10;

    const u = (0x3FF + k / 2) << 20;
    const scale = @bitCast(f64, @as(u64, u) << 32);
    return math.exp(x - kln2) * scale * scale;
}
