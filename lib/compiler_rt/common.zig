const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const is_test = builtin.is_test;

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    _ = error_return_trace;
    @setCold(true);
    if (is_test) {
        std.debug.panic("{s}", .{msg});
    } else {
        unreachable;
    }
}

pub fn wideMultiply(comptime Z: type, a: Z, b: Z, hi: *Z, lo: *Z) void {
    @setRuntimeSafety(is_test);
    switch (Z) {
        u16 => {
            // 16x16 --> 32 bit multiply
            const product = @as(u32, a) * @as(u32, b);
            hi.* = @intCast(u16, product >> 16);
            lo.* = @truncate(u16, product);
        },
        u32 => {
            // 32x32 --> 64 bit multiply
            const product = @as(u64, a) * @as(u64, b);
            hi.* = @truncate(u32, product >> 32);
            lo.* = @truncate(u32, product);
        },
        u64 => {
            const S = struct {
                fn loWord(x: u64) u64 {
                    return @truncate(u32, x);
                }
                fn hiWord(x: u64) u64 {
                    return @truncate(u32, x >> 32);
                }
            };
            // 64x64 -> 128 wide multiply for platforms that don't have such an operation;
            // many 64-bit platforms have this operation, but they tend to have hardware
            // floating-point, so we don't bother with a special case for them here.
            // Each of the component 32x32 -> 64 products
            const plolo: u64 = S.loWord(a) * S.loWord(b);
            const plohi: u64 = S.loWord(a) * S.hiWord(b);
            const philo: u64 = S.hiWord(a) * S.loWord(b);
            const phihi: u64 = S.hiWord(a) * S.hiWord(b);
            // Sum terms that contribute to lo in a way that allows us to get the carry
            const r0: u64 = S.loWord(plolo);
            const r1: u64 = S.hiWord(plolo) +% S.loWord(plohi) +% S.loWord(philo);
            lo.* = r0 +% (r1 << 32);
            // Sum terms contributing to hi with the carry from lo
            hi.* = S.hiWord(plohi) +% S.hiWord(philo) +% S.hiWord(r1) +% phihi;
        },
        u128 => {
            const Word_LoMask = @as(u64, 0x00000000ffffffff);
            const Word_HiMask = @as(u64, 0xffffffff00000000);
            const Word_FullMask = @as(u64, 0xffffffffffffffff);
            const S = struct {
                fn Word_1(x: u128) u64 {
                    return @truncate(u32, x >> 96);
                }
                fn Word_2(x: u128) u64 {
                    return @truncate(u32, x >> 64);
                }
                fn Word_3(x: u128) u64 {
                    return @truncate(u32, x >> 32);
                }
                fn Word_4(x: u128) u64 {
                    return @truncate(u32, x);
                }
            };
            // 128x128 -> 256 wide multiply for platforms that don't have such an operation;
            // many 64-bit platforms have this operation, but they tend to have hardware
            // floating-point, so we don't bother with a special case for them here.

            const product11: u64 = S.Word_1(a) * S.Word_1(b);
            const product12: u64 = S.Word_1(a) * S.Word_2(b);
            const product13: u64 = S.Word_1(a) * S.Word_3(b);
            const product14: u64 = S.Word_1(a) * S.Word_4(b);
            const product21: u64 = S.Word_2(a) * S.Word_1(b);
            const product22: u64 = S.Word_2(a) * S.Word_2(b);
            const product23: u64 = S.Word_2(a) * S.Word_3(b);
            const product24: u64 = S.Word_2(a) * S.Word_4(b);
            const product31: u64 = S.Word_3(a) * S.Word_1(b);
            const product32: u64 = S.Word_3(a) * S.Word_2(b);
            const product33: u64 = S.Word_3(a) * S.Word_3(b);
            const product34: u64 = S.Word_3(a) * S.Word_4(b);
            const product41: u64 = S.Word_4(a) * S.Word_1(b);
            const product42: u64 = S.Word_4(a) * S.Word_2(b);
            const product43: u64 = S.Word_4(a) * S.Word_3(b);
            const product44: u64 = S.Word_4(a) * S.Word_4(b);

            const sum0: u128 = @as(u128, product44);
            const sum1: u128 = @as(u128, product34) +%
                @as(u128, product43);
            const sum2: u128 = @as(u128, product24) +%
                @as(u128, product33) +%
                @as(u128, product42);
            const sum3: u128 = @as(u128, product14) +%
                @as(u128, product23) +%
                @as(u128, product32) +%
                @as(u128, product41);
            const sum4: u128 = @as(u128, product13) +%
                @as(u128, product22) +%
                @as(u128, product31);
            const sum5: u128 = @as(u128, product12) +%
                @as(u128, product21);
            const sum6: u128 = @as(u128, product11);

            const r0: u128 = (sum0 & Word_FullMask) +%
                ((sum1 & Word_LoMask) << 32);
            const r1: u128 = (sum0 >> 64) +%
                ((sum1 >> 32) & Word_FullMask) +%
                (sum2 & Word_FullMask) +%
                ((sum3 << 32) & Word_HiMask);

            lo.* = r0 +% (r1 << 64);
            hi.* = (r1 >> 64) +%
                (sum1 >> 96) +%
                (sum2 >> 64) +%
                (sum3 >> 32) +%
                sum4 +%
                (sum5 << 32) +%
                (sum6 << 64);
        },
        else => @compileError("unsupported"),
    }
}

// TODO: restore inline keyword, see: https://github.com/ziglang/zig/issues/2154
pub fn normalize(comptime T: type, significand: *std.meta.Int(.unsigned, @typeInfo(T).Float.bits)) i32 {
    const bits = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, bits);
    const S = std.meta.Int(.unsigned, bits - @clz(Z, @as(Z, bits) - 1));
    const fractionalBits = math.floatFractionalBits(T);
    const integerBit = @as(Z, 1) << fractionalBits;

    const shift = @clz(std.meta.Int(.unsigned, bits), significand.*) - @clz(Z, integerBit);
    significand.* <<= @intCast(S, shift);
    return @as(i32, 1) - shift;
}
