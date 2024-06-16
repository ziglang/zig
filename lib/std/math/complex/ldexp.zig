// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/complex/__cexpf.c
// https://git.musl-libc.org/cgit/musl/tree/src/complex/__cexp.c

fn frexp_exp32(x: f32, expt: *i32) f32 {
    const k = 235; // reduction constant
    const kln2 = 162.88958740; // k * ln2
    const exp_x = @exp(x - kln2);
    const hx: u32 = @bitCast(exp_x);
    // TODO zig should allow this cast implicitly because it should know the value is in range
    expt.* = @as(i32, @intCast(hx >> 23)) - (0x7f + 127) + k;
    return @bitCast((hx & 0x7fffff) | ((0x7f + 127) << 23));
}

pub fn ldexp_cexp32(x: f32, y: f32, expt: i32) [2]f32 {
    var ex_expt: i32 = undefined;
    const exp_x = frexp_exp32(x, &ex_expt);
    const exptf = expt + ex_expt;
    const half_expt1 = @divTrunc(exptf, 2);
    const half_expt2 = exptf - half_expt1;
    const scale1: f32 = @bitCast((0x7f + half_expt1) << 23);
    const scale2: f32 = @bitCast((0x7f + half_expt2) << 23);
    return .{
        @cos(y) * exp_x * scale1 * scale2,
        @sin(y) * exp_x * scale1 * scale2,
    };
}

fn frexp_exp64(x: f64, expt: *i32) f64 {
    const k = 1799; // reduction constant
    const kln2 = 1246.97177782734161156; // k * ln2
    const exp_x = @exp(x - kln2);

    const fx: u64 = @bitCast(exp_x);
    const hx: u32 = @intCast(fx >> 32);
    const lx: u32 = @truncate(fx);

    expt.* = @as(i32, @intCast(hx >> 20)) - (0x3ff + 1023) + k;

    const high_word = (hx & 0xfffff) | ((0x3ff + 1023) << 20);
    return @bitCast((@as(u64, high_word) << 32) | lx);
}

pub fn ldexp_cexp64(x: f64, y: f64, expt: i32) [2]f64 {
    var ex_expt: i32 = undefined;
    const exp_x = frexp_exp64(x, &ex_expt);
    const exptf: i64 = expt + ex_expt;
    const half_expt1 = @divTrunc(exptf, 2);
    const half_expt2 = exptf - half_expt1;
    const scale1: f64 = @bitCast((0x3ff + half_expt1) << (20 + 32));
    const scale2: f64 = @bitCast((0x3ff + half_expt2) << (20 + 32));
    return .{
        @cos(y) * exp_x * scale1 * scale2,
        @sin(y) * exp_x * scale1 * scale2,
    };
}
