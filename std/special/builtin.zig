// These functions are provided when not linking against libc because LLVM
// sometimes generates code that calls them.

// Note that these functions do not return `dest`, like the libc API.
// The semantics of these functions is dictated by the corresponding
// LLVM intrinsics, not by the libc API.
const builtin = @import("builtin");

export fn memset(dest: ?&u8, c: u8, n: usize) {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        (??dest)[index] = c;
}

export fn memcpy(noalias dest: ?&u8, noalias src: ?&const u8, n: usize) {
    @setDebugSafety(this, false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        (??dest)[index] = (??src)[index];
}

export fn __stack_chk_fail() -> noreturn {
    if (builtin.mode == builtin.Mode.ReleaseFast or builtin.os == builtin.Os.windows) {
        @setGlobalLinkage(__stack_chk_fail, builtin.GlobalLinkage.Internal);
        unreachable;
    }
    @panic("stack smashing detected");
}

const math = @import("../math/index.zig");

export fn fmodf(x: f32, y: f32) -> f32 { generic_fmod(f32, x, y) }
export fn fmod(x: f64, y: f64) -> f64 { generic_fmod(f64, x, y) }

// TODO add intrinsics for these (and probably the double version too)
// and have the math stuff use the intrinsic. same as @mod and @rem
export fn floorf(x: f32) -> f32 { math.floor(x) }
export fn ceilf(x: f32) -> f32 { math.ceil(x) }
export fn floor(x: f64) -> f64 { math.floor(x) }
export fn ceil(x: f64) -> f64 { math.ceil(x) }

fn generic_fmod(comptime T: type, x: T, y: T) -> T {
    @setDebugSafety(this, false);

    const uint = @IntType(false, T.bit_count);
    const log2uint = math.Log2Int(uint);
    const digits = if (T == f32) 23 else 52;
    const exp_bits = if (T == f32) 9 else 12;
    const bits_minus_1 = T.bit_count - 1;
    const mask = if (T == f32) 0xff else 0x7ff;
    var ux = @bitCast(uint, x);
    var uy = @bitCast(uint, y);
    var ex = i32((ux >> digits) & mask);
    var ey = i32((uy >> digits) & mask);
    const sx = if (T == f32) u32(ux & 0x80000000) else i32(ux >> bits_minus_1);
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
        while (i >> bits_minus_1 == 0) : ({ex -= 1; i <<= 1}) {}
        ux <<= log2uint(@bitCast(u32, -ex + 1));
    } else {
        ux &= @maxValue(uint) >> exp_bits;
        ux |= 1 << digits;
    }
    if (ey == 0) {
        i = uy << exp_bits;
        while (i >> bits_minus_1 == 0) : ({ey -= 1; i <<= 1}) {}
        uy <<= log2uint(@bitCast(u32, -ey + 1));
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
    while (ux >> digits == 0) : ({ux <<= 1; ex -= 1}) {}

    // scale result up
    if (ex > 0) {
        ux -%= 1 << digits;
        ux |= uint(@bitCast(u32, ex)) << digits;
    } else {
        ux >>= log2uint(@bitCast(u32, -ex + 1));
    }
    if (T == f32) {
        ux |= sx;
    } else {
        ux |= uint(sx) << bits_minus_1;
    }
    return @bitCast(T, ux);
}

fn isNan(comptime T: type, bits: T) -> bool {
    if (T == u32) {
        return (bits & 0x7fffffff) > 0x7f800000;
    } else if (T == u64) {
        return (bits & (@maxValue(u64) >> 1)) > (u64(0x7ff) << 52);
    } else {
        unreachable;
    }
}
