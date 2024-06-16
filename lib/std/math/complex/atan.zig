// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/catanf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/catan.c

const std = @import("../../std.zig");
const testing = std.testing;
const math = std.math;

fn redupif32(x: f32) f32 {
    const DP1 = 3.140625;
    const DP2 = 9.67502593994140625e-4;
    const DP3 = 1.509957990978376432e-7;

    var t = x / math.pi;
    if (t >= 0.0) {
        t += 0.5;
    } else {
        t -= 0.5;
    }

    const u = @as(f32, @floatFromInt(@as(i32, @intFromFloat(t))));
    return ((x - u * DP1) - u * DP2) - t * DP3;
}

pub fn atan32(x: f32, y: f32) [2]f32 {
    const maxnum = 1.0e38;
    const overflow = .{ maxnum, maxnum };

    if ((x == 0.0) and (y > 1.0)) return overflow;

    const x2 = x * x;
    var a = 1.0 - x2 - (y * y);
    if (a == 0.0) return overflow;

    var t = 0.5 * math.atan2(2.0 * x, a);
    const w = redupif32(t);

    t = y - 1.0;
    a = x2 + t * t;
    if (a == 0.0) return overflow;

    t = y + 1.0;
    a = (x2 + (t * t)) / a;
    return .{ w, 0.25 * @log(a) };
}

fn redupif64(x: f64) f64 {
    const DP1 = 3.14159265160560607910;
    const DP2 = 1.98418714791870343106e-9;
    const DP3 = 1.14423774522196636802e-17;

    var t = x / math.pi;
    if (t >= 0.0) {
        t += 0.5;
    } else {
        t -= 0.5;
    }

    const u = @as(f64, @floatFromInt(@as(i64, @intFromFloat(t))));
    return ((x - u * DP1) - u * DP2) - t * DP3;
}

pub fn atan64(x: f64, y: f64) [2]f64 {
    const maxnum = 1.0e308;
    const overflow = .{ maxnum, maxnum };

    if ((x == 0.0) and (y > 1.0)) return overflow;

    const x2 = x * x;
    var a = 1.0 - x2 - (y * y);
    if (a == 0.0) return overflow;

    var t = 0.5 * math.atan2(2.0 * x, a);
    const w = redupif64(t);

    t = y - 1.0;
    a = x2 + t * t;
    if (a == 0.0) return overflow;

    t = y + 1.0;
    a = (x2 + (t * t)) / a;
    return .{ w, 0.25 * @log(a) };
}

pub fn atanFallback(comptime T: type, x: T, y: T) [2]T {
    const x2 = x * x;
    var a = 1.0 - x2 - (y * y);

    var t = 0.5 * math.atan2(2.0 * x, a);
    const w = t;

    t = y - 1.0;
    a = x2 + t * t;

    t = y + 1.0;
    a = (x2 + (t * t)) / a;
    return .{ w, 0.25 * @log(a) };
}

test atan32 {
    const z = atan32(5, 3);
    const re: f32 = 1.4236790442393028;
    const im: f32 = 0.08656905917945844;
    try testing.expect(math.approxEqAbs(f32, z[0], re, @sqrt(math.floatEpsAt(f32, re))));
    try testing.expect(math.approxEqAbs(f32, z[1], im, @sqrt(math.floatEpsAt(f32, im))));
}

test atan64 {
    const z = atan64(5, 3);
    const re: f64 = 1.4236790442393028;
    const im: f64 = 0.08656905917945844;
    try testing.expect(math.approxEqAbs(f64, z[0], re, @sqrt(math.floatEpsAt(f64, re))));
    try testing.expect(math.approxEqAbs(f64, z[1], im, @sqrt(math.floatEpsAt(f64, im))));
}

test atanFallback {
    const re = 1.4236790442393028;
    const im = 0.08656905917945844;
    inline for (.{ f32, f64 }) |F| {
        const z = atanFallback(F, 5, 3);
        try testing.expect(math.approxEqAbs(F, z[0], re, @sqrt(math.floatEpsAt(F, re))));
        try testing.expect(math.approxEqAbs(F, z[1], im, @sqrt(math.floatEpsAt(F, im))));
    }
}
