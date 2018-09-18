// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

const builtin = @import("builtin");

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    if (builtin.is_test) {
        @setCold(true);
        @import("std").debug.panic("{}", msg);
    } else {
        unreachable;
    }
}

export fn memset(dest: ?[*]u8, c: u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = c;

    return dest;
}

export fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = src.?[index];

    return dest;
}

export fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    if (@ptrToInt(dest) < @ptrToInt(src)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest.?[index] = src.?[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest.?[index] = src.?[index];
        }
    }

    return dest;
}

comptime {
    if (builtin.mode != builtin.Mode.ReleaseFast and
        builtin.mode != builtin.Mode.ReleaseSmall and
        builtin.os != builtin.Os.windows)
    {
        @export("__stack_chk_fail", __stack_chk_fail, builtin.GlobalLinkage.Strong);
    }
    if (builtin.os == builtin.Os.linux and builtin.arch == builtin.Arch.x86_64) {
        @export("clone", clone, builtin.GlobalLinkage.Strong);
    }
}
extern fn __stack_chk_fail() noreturn {
    @panic("stack smashing detected");
}

// TODO we should be able to put this directly in std/linux/x86_64.zig but
// it causes a segfault in release mode. this is a workaround of calling it
// across .o file boundaries. fix comptime @ptrCast of nakedcc functions.
nakedcc fn clone() void {
    asm volatile (
        \\      xor %%eax,%%eax
        \\      mov $56,%%al
        \\      mov %%rdi,%%r11
        \\      mov %%rdx,%%rdi
        \\      mov %%r8,%%rdx
        \\      mov %%r9,%%r8
        \\      mov 8(%%rsp),%%r10
        \\      mov %%r11,%%r9
        \\      and $-16,%%rsi
        \\      sub $8,%%rsi
        \\      mov %%rcx,(%%rsi)
        \\      syscall
        \\      test %%eax,%%eax
        \\      jnz 1f
        \\      xor %%ebp,%%ebp
        \\      pop %%rdi
        \\      call *%%r9
        \\      mov %%eax,%%edi
        \\      xor %%eax,%%eax
        \\      mov $60,%%al
        \\      syscall
        \\      hlt
        \\1:    ret
        \\
    );
}

const math = @import("../math/index.zig");

export fn fmodf(x: f32, y: f32) f32 {
    return generic_fmod(f32, x, y);
}
export fn fmod(x: f64, y: f64) f64 {
    return generic_fmod(f64, x, y);
}

// TODO add intrinsics for these (and probably the double version too)
// and have the math stuff use the intrinsic. same as @mod and @rem
export fn floorf(x: f32) f32 {
    return math.floor(x);
}
export fn ceilf(x: f32) f32 {
    return math.ceil(x);
}
export fn floor(x: f64) f64 {
    return math.floor(x);
}
export fn ceil(x: f64) f64 {
    return math.ceil(x);
}

fn generic_fmod(comptime T: type, x: T, y: T) T {
    @setRuntimeSafety(false);

    const uint = @IntType(false, T.bit_count);
    const log2uint = math.Log2Int(uint);
    const digits = if (T == f32) 23 else 52;
    const exp_bits = if (T == f32) 9 else 12;
    const bits_minus_1 = T.bit_count - 1;
    const mask = if (T == f32) 0xff else 0x7ff;
    var ux = @bitCast(uint, x);
    var uy = @bitCast(uint, y);
    var ex = @intCast(i32, (ux >> digits) & mask);
    var ey = @intCast(i32, (uy >> digits) & mask);
    const sx = if (T == f32) @intCast(u32, ux & 0x80000000) else @intCast(i32, ux >> bits_minus_1);
    var i: uint = undefined;

    if (uy << 1 == 0 or isNan(uint, uy) or ex == mask)
        return (x * y) / (x * y);

    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1)
            return 0 * x;
        return x;
    }

    // normalize x and y
    if (ex == 0) {
        i = ux << exp_bits;
        while (i >> bits_minus_1 == 0) : (b: {
            ex -= 1;
            i <<= 1;
        }) {}
        ux <<= @intCast(log2uint, @bitCast(u32, -ex + 1));
    } else {
        ux &= @maxValue(uint) >> exp_bits;
        ux |= 1 << digits;
    }
    if (ey == 0) {
        i = uy << exp_bits;
        while (i >> bits_minus_1 == 0) : (b: {
            ey -= 1;
            i <<= 1;
        }) {}
        uy <<= @intCast(log2uint, @bitCast(u32, -ey + 1));
    } else {
        uy &= @maxValue(uint) >> exp_bits;
        uy |= 1 << digits;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        i = ux -% uy;
        if (i >> bits_minus_1 == 0) {
            if (i == 0)
                return 0 * x;
            ux = i;
        }
        ux <<= 1;
    }
    i = ux -% uy;
    if (i >> bits_minus_1 == 0) {
        if (i == 0)
            return 0 * x;
        ux = i;
    }
    while (ux >> digits == 0) : (b: {
        ux <<= 1;
        ex -= 1;
    }) {}

    // scale result up
    if (ex > 0) {
        ux -%= 1 << digits;
        ux |= uint(@bitCast(u32, ex)) << digits;
    } else {
        ux >>= @intCast(log2uint, @bitCast(u32, -ex + 1));
    }
    if (T == f32) {
        ux |= sx;
    } else {
        ux |= @intCast(uint, sx) << bits_minus_1;
    }
    return @bitCast(T, ux);
}

fn isNan(comptime T: type, bits: T) bool {
    if (T == u16) {
        return (bits & 0x7fff) > 0x7c00;
    } else if (T == u32) {
        return (bits & 0x7fffffff) > 0x7f800000;
    } else if (T == u64) {
        return (bits & (@maxValue(u64) >> 1)) > (u64(0x7ff) << 52);
    } else {
        unreachable;
    }
}

// NOTE: The original code is full of implicit signed -> unsigned assumptions and u32 wraparound
// behaviour. Most intermediate i32 values are changed to u32 where appropriate but there are
// potentially some edge cases remaining that are not handled in the same way.
export fn sqrt(x: f64) f64 {
    const tiny: f64 = 1.0e-300;
    const sign: u32 = 0x80000000;
    const u = @bitCast(u64, x);

    var ix0 = @intCast(u32, u >> 32);
    var ix1 = @intCast(u32, u & 0xFFFFFFFF);

    // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    if (ix0 & 0x7FF00000 == 0x7FF00000) {
        return x * x + x;
    }

    // sqrt(+-0) = +-0
    if (x == 0.0) {
        return x;
    }
    // sqrt(-ve) = snan
    if (ix0 & sign != 0) {
        return math.snan(f64);
    }

    // normalize x
    var m = @intCast(i32, ix0 >> 20);
    if (m == 0) {
        // subnormal
        while (ix0 == 0) {
            m -= 21;
            ix0 |= ix1 >> 11;
            ix1 <<= 21;
        }

        // subnormal
        var i: u32 = 0;
        while (ix0 & 0x00100000 == 0) : (i += 1) {
            ix0 <<= 1;
        }
        m -= @intCast(i32, i) - 1;
        ix0 |= ix1 >> @intCast(u5, 32 - i);
        ix1 <<= @intCast(u5, i);
    }

    // unbias exponent
    m -= 1023;
    ix0 = (ix0 & 0x000FFFFF) | 0x00100000;
    if (m & 1 != 0) {
        ix0 += ix0 + (ix1 >> 31);
        ix1 = ix1 +% ix1;
    }
    m >>= 1;

    // sqrt(x) bit by bit
    ix0 += ix0 + (ix1 >> 31);
    ix1 = ix1 +% ix1;

    var q: u32 = 0;
    var q1: u32 = 0;
    var s0: u32 = 0;
    var s1: u32 = 0;
    var r: u32 = 0x00200000;
    var t: u32 = undefined;
    var t1: u32 = undefined;

    while (r != 0) {
        t = s0 +% r;
        if (t <= ix0) {
            s0 = t + r;
            ix0 -= t;
            q += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    r = sign;
    while (r != 0) {
        t = s1 +% r;
        t = s0;
        if (t < ix0 or (t == ix0 and t1 <= ix1)) {
            s1 = t1 +% r;
            if (t1 & sign == sign and s1 & sign == 0) {
                s0 += 1;
            }
            ix0 -= t;
            if (ix1 < t1) {
                ix0 -= 1;
            }
            ix1 = ix1 -% t1;
            q1 += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    // rounding direction
    if (ix0 | ix1 != 0) {
        var z = 1.0 - tiny; // raise inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (q1 == 0xFFFFFFFF) {
                q1 = 0;
                q += 1;
            } else if (z > 1.0) {
                if (q1 == 0xFFFFFFFE) {
                    q += 1;
                }
                q1 += 2;
            } else {
                q1 += q1 & 1;
            }
        }
    }

    ix0 = (q >> 1) + 0x3FE00000;
    ix1 = q1 >> 1;
    if (q & 1 != 0) {
        ix1 |= 0x80000000;
    }

    // NOTE: musl here appears to rely on signed twos-complement wraparound. +% has the same
    // behaviour at least.
    var iix0 = @intCast(i32, ix0);
    iix0 = iix0 +% (m << 20);

    const uz = (@intCast(u64, iix0) << 32) | ix1;
    return @bitCast(f64, uz);
}

export fn sqrtf(x: f32) f32 {
    const tiny: f32 = 1.0e-30;
    const sign: i32 = @bitCast(i32, u32(0x80000000));
    var ix: i32 = @bitCast(i32, x);

    if ((ix & 0x7F800000) == 0x7F800000) {
        return x * x + x; // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = snan
    }

    // zero
    if (ix <= 0) {
        if (ix & ~sign == 0) {
            return x; // sqrt (+-0) = +-0
        }
        if (ix < 0) {
            return math.snan(f32);
        }
    }

    // normalize
    var m = ix >> 23;
    if (m == 0) {
        // subnormal
        var i: i32 = 0;
        while (ix & 0x00800000 == 0) : (i += 1) {
            ix <<= 1;
        }
        m -= i - 1;
    }

    m -= 127; // unbias exponent
    ix = (ix & 0x007FFFFF) | 0x00800000;

    if (m & 1 != 0) { // odd m, double x to even
        ix += ix;
    }

    m >>= 1; // m = [m / 2]

    // sqrt(x) bit by bit
    ix += ix;
    var q: i32 = 0; // q = sqrt(x)
    var s: i32 = 0;
    var r: i32 = 0x01000000; // r = moving bit right -> left

    while (r != 0) {
        const t = s + r;
        if (t <= ix) {
            s = t + r;
            ix -= t;
            q += r;
        }
        ix += ix;
        r >>= 1;
    }

    // floating add to find rounding direction
    if (ix != 0) {
        var z = 1.0 - tiny; // inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (z > 1.0) {
                q += 2;
            } else {
                if (q & 1 != 0) {
                    q += 1;
                }
            }
        }
    }

    ix = (q >> 1) + 0x3f000000;
    ix += m << 23;
    return @bitCast(f32, ix);
}
