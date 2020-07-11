// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/scalbnf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/scalbn.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns x * 2^n.
pub fn scalbn(x: anytype, n: i32) @TypeOf(x) {
    const T = @TypeOf(x);
    return switch (T) {
        f32 => scalbn32(x, n),
        f64 => scalbn64(x, n),
        else => @compileError("scalbn not implemented for " ++ @typeName(T)),
    };
}

fn scalbn32(x: f32, n_: i32) f32 {
    var y = x;
    var n = n_;

    if (n > 127) {
        y *= 0x1.0p127;
        n -= 127;
        if (n > 1023) {
            y *= 0x1.0p127;
            n -= 127;
            if (n > 127) {
                n = 127;
            }
        }
    } else if (n < -126) {
        y *= 0x1.0p-126 * 0x1.0p24;
        n += 126 - 24;
        if (n < -126) {
            y *= 0x1.0p-126 * 0x1.0p24;
            n += 126 - 24;
            if (n < -126) {
                n = -126;
            }
        }
    }

    const u = @intCast(u32, n +% 0x7F) << 23;
    return y * @bitCast(f32, u);
}

fn scalbn64(x: f64, n_: i32) f64 {
    var y = x;
    var n = n_;

    if (n > 1023) {
        y *= 0x1.0p1023;
        n -= 1023;
        if (n > 1023) {
            y *= 0x1.0p1023;
            n -= 1023;
            if (n > 1023) {
                n = 1023;
            }
        }
    } else if (n < -1022) {
        y *= 0x1.0p-1022 * 0x1.0p53;
        n += 1022 - 53;
        if (n < -1022) {
            y *= 0x1.0p-1022 * 0x1.0p53;
            n += 1022 - 53;
            if (n < -1022) {
                n = -1022;
            }
        }
    }

    const u = @intCast(u64, n +% 0x3FF) << 52;
    return y * @bitCast(f64, u);
}

test "math.scalbn" {
    expect(scalbn(@as(f32, 1.5), 4) == scalbn32(1.5, 4));
    expect(scalbn(@as(f64, 1.5), 4) == scalbn64(1.5, 4));
}

test "math.scalbn32" {
    expect(scalbn32(1.5, 4) == 24.0);
}

test "math.scalbn64" {
    expect(scalbn64(1.5, 4) == 24.0);
}
