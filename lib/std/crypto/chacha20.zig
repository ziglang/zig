// Based on public domain Supercop by Daniel J. Bernstein

const std = @import("../std.zig");
const builtin = @import("builtin");
const crypto = std.crypto;
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const testing = std.testing;
const maxInt = math.maxInt;
const Poly1305 = crypto.onetimeauth.Poly1305;
const AuthenticationError = crypto.errors.AuthenticationError;

/// IETF-variant of the ChaCha20 stream cipher, as designed for TLS.
pub const ChaCha20IETF = ChaChaIETF(20);

/// IETF-variant of the ChaCha20 stream cipher, reduced to 12 rounds.
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha12IETF = ChaChaIETF(12);

/// IETF-variant of the ChaCha20 stream cipher, reduced to 8 rounds.
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha8IETF = ChaChaIETF(8);

/// Original ChaCha20 stream cipher.
pub const ChaCha20With64BitNonce = ChaChaWith64BitNonce(20);

/// Original ChaCha20 stream cipher, reduced to 12 rounds.
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha12With64BitNonce = ChaChaWith64BitNonce(12);

/// Original ChaCha20 stream cipher, reduced to 8 rounds.
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha8With64BitNonce = ChaChaWith64BitNonce(8);

/// XChaCha20 (nonce-extended version of the IETF ChaCha20 variant) stream cipher
pub const XChaCha20IETF = XChaChaIETF(20);

/// XChaCha20 (nonce-extended version of the IETF ChaCha20 variant) stream cipher, reduced to 12 rounds
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const XChaCha12IETF = XChaChaIETF(12);

/// XChaCha20 (nonce-extended version of the IETF ChaCha20 variant) stream cipher, reduced to 8 rounds
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const XChaCha8IETF = XChaChaIETF(8);

/// ChaCha20-Poly1305 authenticated cipher, as designed for TLS
pub const ChaCha20Poly1305 = ChaChaPoly1305(20);

/// ChaCha20-Poly1305 authenticated cipher, reduced to 12 rounds
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha12Poly1305 = ChaChaPoly1305(12);

/// ChaCha20-Poly1305 authenticated cipher, reduced to 8 rounds
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const ChaCha8Poly1305 = ChaChaPoly1305(8);

/// XChaCha20-Poly1305 authenticated cipher
pub const XChaCha20Poly1305 = XChaChaPoly1305(20);

/// XChaCha20-Poly1305 authenticated cipher
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const XChaCha12Poly1305 = XChaChaPoly1305(12);

/// XChaCha20-Poly1305 authenticated cipher
/// Reduced-rounds versions are faster than the full-round version, but have a lower security margin.
/// However, ChaCha is still believed to have a comfortable security even with only 8 rounds.
pub const XChaCha8Poly1305 = XChaChaPoly1305(8);

// Vectorized implementation of the core function
fn ChaChaVecImpl(comptime rounds_nb: usize, comptime degree: comptime_int) type {
    return struct {
        const Lane = @Vector(4 * degree, u32);
        const BlockVec = [4]Lane;

        fn initContext(key: [8]u32, d: [4]u32) BlockVec {
            const c = "expand 32-byte k";
            switch (degree) {
                1 => {
                    const constant_le = Lane{
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                    };
                    return BlockVec{
                        constant_le,
                        Lane{ key[0], key[1], key[2], key[3] },
                        Lane{ key[4], key[5], key[6], key[7] },
                        Lane{ d[0], d[1], d[2], d[3] },
                    };
                },
                2 => {
                    const constant_le = Lane{
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                    };
                    const n1 = @addWithOverflow(d[0], 1);
                    return BlockVec{
                        constant_le,
                        Lane{ key[0], key[1], key[2], key[3], key[0], key[1], key[2], key[3] },
                        Lane{ key[4], key[5], key[6], key[7], key[4], key[5], key[6], key[7] },
                        Lane{ d[0], d[1], d[2], d[3], n1[0], d[1] +% n1[1], d[2], d[3] },
                    };
                },
                4 => {
                    const n1 = @addWithOverflow(d[0], 1);
                    const n2 = @addWithOverflow(d[0], 2);
                    const n3 = @addWithOverflow(d[0], 3);
                    const constant_le = Lane{
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                        mem.readInt(u32, c[0..4], .little),
                        mem.readInt(u32, c[4..8], .little),
                        mem.readInt(u32, c[8..12], .little),
                        mem.readInt(u32, c[12..16], .little),
                    };
                    return BlockVec{
                        constant_le,
                        Lane{ key[0], key[1], key[2], key[3], key[0], key[1], key[2], key[3], key[0], key[1], key[2], key[3], key[0], key[1], key[2], key[3] },
                        Lane{ key[4], key[5], key[6], key[7], key[4], key[5], key[6], key[7], key[4], key[5], key[6], key[7], key[4], key[5], key[6], key[7] },
                        Lane{ d[0], d[1], d[2], d[3], n1[0], d[1] +% n1[1], d[2], d[3], n2[0], d[1] +% n2[1], d[2], d[3], n3[0], d[1] +% n3[1], d[2], d[3] },
                    };
                },
                else => @compileError("invalid degree"),
            }
        }

        inline fn chacha20Core(x: *BlockVec, input: BlockVec) void {
            x.* = input;

            const m0 = switch (degree) {
                1 => [_]i32{ 3, 0, 1, 2 },
                2 => [_]i32{ 3, 0, 1, 2 } ++ [_]i32{ 7, 4, 5, 6 },
                4 => [_]i32{ 3, 0, 1, 2 } ++ [_]i32{ 7, 4, 5, 6 } ++ [_]i32{ 11, 8, 9, 10 } ++ [_]i32{ 15, 12, 13, 14 },
                else => @compileError("invalid degree"),
            };
            const m1 = switch (degree) {
                1 => [_]i32{ 2, 3, 0, 1 },
                2 => [_]i32{ 2, 3, 0, 1 } ++ [_]i32{ 6, 7, 4, 5 },
                4 => [_]i32{ 2, 3, 0, 1 } ++ [_]i32{ 6, 7, 4, 5 } ++ [_]i32{ 10, 11, 8, 9 } ++ [_]i32{ 14, 15, 12, 13 },
                else => @compileError("invalid degree"),
            };
            const m2 = switch (degree) {
                1 => [_]i32{ 1, 2, 3, 0 },
                2 => [_]i32{ 1, 2, 3, 0 } ++ [_]i32{ 5, 6, 7, 4 },
                4 => [_]i32{ 1, 2, 3, 0 } ++ [_]i32{ 5, 6, 7, 4 } ++ [_]i32{ 9, 10, 11, 8 } ++ [_]i32{ 13, 14, 15, 12 },
                else => @compileError("invalid degree"),
            };

            var r: usize = 0;
            while (r < rounds_nb) : (r += 2) {
                x[0] +%= x[1];
                x[3] ^= x[0];
                x[3] = math.rotl(Lane, x[3], 16);

                x[2] +%= x[3];
                x[1] ^= x[2];
                x[1] = math.rotl(Lane, x[1], 12);

                x[0] +%= x[1];
                x[3] ^= x[0];
                x[0] = @shuffle(u32, x[0], undefined, m0);
                x[3] = math.rotl(Lane, x[3], 8);

                x[2] +%= x[3];
                x[3] = @shuffle(u32, x[3], undefined, m1);
                x[1] ^= x[2];
                x[2] = @shuffle(u32, x[2], undefined, m2);
                x[1] = math.rotl(Lane, x[1], 7);

                x[0] +%= x[1];
                x[3] ^= x[0];
                x[3] = math.rotl(Lane, x[3], 16);

                x[2] +%= x[3];
                x[1] ^= x[2];
                x[1] = math.rotl(Lane, x[1], 12);

                x[0] +%= x[1];
                x[3] ^= x[0];
                x[0] = @shuffle(u32, x[0], undefined, m2);
                x[3] = math.rotl(Lane, x[3], 8);

                x[2] +%= x[3];
                x[3] = @shuffle(u32, x[3], undefined, m1);
                x[1] ^= x[2];
                x[2] = @shuffle(u32, x[2], undefined, m0);
                x[1] = math.rotl(Lane, x[1], 7);
            }
        }

        inline fn hashToBytes(comptime dm: usize, out: *[64 * dm]u8, x: BlockVec) void {
            for (0..dm) |d| {
                for (0..4) |i| {
                    mem.writeInt(u32, out[64 * d + 16 * i + 0 ..][0..4], x[i][0 + 4 * d], .little);
                    mem.writeInt(u32, out[64 * d + 16 * i + 4 ..][0..4], x[i][1 + 4 * d], .little);
                    mem.writeInt(u32, out[64 * d + 16 * i + 8 ..][0..4], x[i][2 + 4 * d], .little);
                    mem.writeInt(u32, out[64 * d + 16 * i + 12 ..][0..4], x[i][3 + 4 * d], .little);
                }
            }
        }

        inline fn contextFeedback(x: *BlockVec, ctx: BlockVec) void {
            x[0] +%= ctx[0];
            x[1] +%= ctx[1];
            x[2] +%= ctx[2];
            x[3] +%= ctx[3];
        }

        fn chacha20Xor(out: []u8, in: []const u8, key: [8]u32, nonce_and_counter: [4]u32, comptime count64: bool) void {
            var ctx = initContext(key, nonce_and_counter);
            var x: BlockVec = undefined;
            var buf: [64 * degree]u8 = undefined;
            var i: usize = 0;
            inline for ([_]comptime_int{ 4, 2, 1 }) |d| {
                while (degree >= d and i + 64 * d <= in.len) : (i += 64 * d) {
                    chacha20Core(x[0..], ctx);
                    contextFeedback(&x, ctx);
                    hashToBytes(d, buf[0 .. 64 * d], x);

                    var xout = out[i..];
                    const xin = in[i..];
                    for (0..64 * d) |j| {
                        xout[j] = xin[j];
                    }
                    for (0..64 * d) |j| {
                        xout[j] ^= buf[j];
                    }
                    inline for (0..d) |d_| {
                        if (count64) {
                            const next = @addWithOverflow(ctx[3][4 * d_], d);
                            ctx[3][4 * d_] = next[0];
                            ctx[3][4 * d_ + 1] +%= next[1];
                        } else {
                            ctx[3][4 * d_] +%= d;
                        }
                    }
                }
            }
            if (i < in.len) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);
                hashToBytes(1, buf[0..64], x);

                var xout = out[i..];
                const xin = in[i..];
                for (0..in.len % 64) |j| {
                    xout[j] = xin[j] ^ buf[j];
                }
            }
        }

        fn chacha20Stream(out: []u8, key: [8]u32, nonce_and_counter: [4]u32, comptime count64: bool) void {
            var ctx = initContext(key, nonce_and_counter);
            var x: BlockVec = undefined;
            var i: usize = 0;
            inline for ([_]comptime_int{ 4, 2, 1 }) |d| {
                while (degree >= d and i + 64 * d <= out.len) : (i += 64 * d) {
                    chacha20Core(x[0..], ctx);
                    contextFeedback(&x, ctx);
                    hashToBytes(d, out[i..][0 .. 64 * d], x);
                    inline for (0..d) |d_| {
                        if (count64) {
                            const next = @addWithOverflow(ctx[3][4 * d_], d);
                            ctx[3][4 * d_] = next[0];
                            ctx[3][4 * d_ + 1] +%= next[1];
                        } else {
                            ctx[3][4 * d_] +%= d;
                        }
                    }
                }
            }
            if (i < out.len) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);

                var buf: [64]u8 = undefined;
                hashToBytes(1, buf[0..], x);
                @memcpy(out[i..], buf[0 .. out.len - i]);
            }
        }

        fn hchacha20(input: [16]u8, key: [32]u8) [32]u8 {
            var c: [4]u32 = undefined;
            for (c, 0..) |_, i| {
                c[i] = mem.readInt(u32, input[4 * i ..][0..4], .little);
            }
            const ctx = initContext(keyToWords(key), c);
            var x: BlockVec = undefined;
            chacha20Core(x[0..], ctx);
            var out: [32]u8 = undefined;
            mem.writeInt(u32, out[0..4], x[0][0], .little);
            mem.writeInt(u32, out[4..8], x[0][1], .little);
            mem.writeInt(u32, out[8..12], x[0][2], .little);
            mem.writeInt(u32, out[12..16], x[0][3], .little);
            mem.writeInt(u32, out[16..20], x[3][0], .little);
            mem.writeInt(u32, out[20..24], x[3][1], .little);
            mem.writeInt(u32, out[24..28], x[3][2], .little);
            mem.writeInt(u32, out[28..32], x[3][3], .little);
            return out;
        }
    };
}

// Non-vectorized implementation of the core function
fn ChaChaNonVecImpl(comptime rounds_nb: usize) type {
    return struct {
        const BlockVec = [16]u32;

        fn initContext(key: [8]u32, d: [4]u32) BlockVec {
            const c = "expand 32-byte k";
            const constant_le = comptime [4]u32{
                mem.readInt(u32, c[0..4], .little),
                mem.readInt(u32, c[4..8], .little),
                mem.readInt(u32, c[8..12], .little),
                mem.readInt(u32, c[12..16], .little),
            };
            return BlockVec{
                constant_le[0], constant_le[1], constant_le[2], constant_le[3],
                key[0],         key[1],         key[2],         key[3],
                key[4],         key[5],         key[6],         key[7],
                d[0],           d[1],           d[2],           d[3],
            };
        }

        const QuarterRound = struct {
            a: usize,
            b: usize,
            c: usize,
            d: usize,
        };

        fn Rp(a: usize, b: usize, c: usize, d: usize) QuarterRound {
            return QuarterRound{
                .a = a,
                .b = b,
                .c = c,
                .d = d,
            };
        }

        inline fn chacha20Core(x: *BlockVec, input: BlockVec) void {
            x.* = input;

            const rounds = comptime [_]QuarterRound{
                Rp(0, 4, 8, 12),
                Rp(1, 5, 9, 13),
                Rp(2, 6, 10, 14),
                Rp(3, 7, 11, 15),
                Rp(0, 5, 10, 15),
                Rp(1, 6, 11, 12),
                Rp(2, 7, 8, 13),
                Rp(3, 4, 9, 14),
            };

            comptime var j: usize = 0;
            inline while (j < rounds_nb) : (j += 2) {
                inline for (rounds) |r| {
                    x[r.a] +%= x[r.b];
                    x[r.d] = math.rotl(u32, x[r.d] ^ x[r.a], @as(u32, 16));
                    x[r.c] +%= x[r.d];
                    x[r.b] = math.rotl(u32, x[r.b] ^ x[r.c], @as(u32, 12));
                    x[r.a] +%= x[r.b];
                    x[r.d] = math.rotl(u32, x[r.d] ^ x[r.a], @as(u32, 8));
                    x[r.c] +%= x[r.d];
                    x[r.b] = math.rotl(u32, x[r.b] ^ x[r.c], @as(u32, 7));
                }
            }
        }

        inline fn hashToBytes(out: *[64]u8, x: BlockVec) void {
            for (0..4) |i| {
                mem.writeInt(u32, out[16 * i + 0 ..][0..4], x[i * 4 + 0], .little);
                mem.writeInt(u32, out[16 * i + 4 ..][0..4], x[i * 4 + 1], .little);
                mem.writeInt(u32, out[16 * i + 8 ..][0..4], x[i * 4 + 2], .little);
                mem.writeInt(u32, out[16 * i + 12 ..][0..4], x[i * 4 + 3], .little);
            }
        }

        inline fn contextFeedback(x: *BlockVec, ctx: BlockVec) void {
            for (0..16) |i| {
                x[i] +%= ctx[i];
            }
        }

        fn chacha20Xor(out: []u8, in: []const u8, key: [8]u32, nonce_and_counter: [4]u32, comptime count64: bool) void {
            var ctx = initContext(key, nonce_and_counter);
            var x: BlockVec = undefined;
            var buf: [64]u8 = undefined;
            var i: usize = 0;
            while (i + 64 <= in.len) : (i += 64) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);
                hashToBytes(buf[0..], x);

                var xout = out[i..];
                const xin = in[i..];
                for (0..64) |j| {
                    xout[j] = xin[j];
                }
                for (0..64) |j| {
                    xout[j] ^= buf[j];
                }
                if (count64) {
                    const next = @addWithOverflow(ctx[12], 1);
                    ctx[12] = next[0];
                    ctx[13] +%= next[1];
                } else {
                    ctx[12] +%= 1;
                }
            }
            if (i < in.len) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);
                hashToBytes(buf[0..], x);

                var xout = out[i..];
                const xin = in[i..];
                for (0..in.len % 64) |j| {
                    xout[j] = xin[j] ^ buf[j];
                }
            }
        }

        fn chacha20Stream(out: []u8, key: [8]u32, nonce_and_counter: [4]u32, comptime count64: bool) void {
            var ctx = initContext(key, nonce_and_counter);
            var x: BlockVec = undefined;
            var i: usize = 0;
            while (i + 64 <= out.len) : (i += 64) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);
                hashToBytes(out[i..][0..64], x);
                if (count64) {
                    const next = @addWithOverflow(ctx[12], 1);
                    ctx[12] = next[0];
                    ctx[13] +%= next[1];
                } else {
                    ctx[12] +%= 1;
                }
            }
            if (i < out.len) {
                chacha20Core(x[0..], ctx);
                contextFeedback(&x, ctx);

                var buf: [64]u8 = undefined;
                hashToBytes(buf[0..], x);
                @memcpy(out[i..], buf[0 .. out.len - i]);
            }
        }

        fn hchacha20(input: [16]u8, key: [32]u8) [32]u8 {
            var c: [4]u32 = undefined;
            for (c, 0..) |_, i| {
                c[i] = mem.readInt(u32, input[4 * i ..][0..4], .little);
            }
            const ctx = initContext(keyToWords(key), c);
            var x: BlockVec = undefined;
            chacha20Core(x[0..], ctx);
            var out: [32]u8 = undefined;
            mem.writeInt(u32, out[0..4], x[0], .little);
            mem.writeInt(u32, out[4..8], x[1], .little);
            mem.writeInt(u32, out[8..12], x[2], .little);
            mem.writeInt(u32, out[12..16], x[3], .little);
            mem.writeInt(u32, out[16..20], x[12], .little);
            mem.writeInt(u32, out[20..24], x[13], .little);
            mem.writeInt(u32, out[24..28], x[14], .little);
            mem.writeInt(u32, out[28..32], x[15], .little);
            return out;
        }
    };
}

fn ChaChaImpl(comptime rounds_nb: usize) type {
    switch (builtin.cpu.arch) {
        .x86_64 => {
            if (builtin.zig_backend == .stage2_x86_64) return ChaChaNonVecImpl(rounds_nb);

            const has_avx2 = std.Target.x86.featureSetHas(builtin.cpu.features, .avx2);
            const has_avx512f = std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f);
            if (has_avx512f) return ChaChaVecImpl(rounds_nb, 4);
            if (has_avx2) return ChaChaVecImpl(rounds_nb, 2);
            return ChaChaVecImpl(rounds_nb, 1);
        },
        .aarch64 => {
            const has_neon = std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon);
            if (has_neon) return ChaChaVecImpl(rounds_nb, 4);
            return ChaChaNonVecImpl(rounds_nb);
        },
        else => return ChaChaNonVecImpl(rounds_nb),
    }
}

fn keyToWords(key: [32]u8) [8]u32 {
    var k: [8]u32 = undefined;
    for (0..8) |i| {
        k[i] = mem.readInt(u32, key[i * 4 ..][0..4], .little);
    }
    return k;
}

fn extend(key: [32]u8, nonce: [24]u8, comptime rounds_nb: usize) struct { key: [32]u8, nonce: [12]u8 } {
    var subnonce: [12]u8 = undefined;
    @memset(subnonce[0..4], 0);
    subnonce[4..].* = nonce[16..24].*;
    return .{
        .key = ChaChaImpl(rounds_nb).hchacha20(nonce[0..16].*, key),
        .nonce = subnonce,
    };
}

fn ChaChaIETF(comptime rounds_nb: usize) type {
    return struct {
        /// Nonce length in bytes.
        pub const nonce_length = 12;
        /// Key length in bytes.
        pub const key_length = 32;
        /// Block length in bytes.
        pub const block_length = 64;

        /// Add the output of the ChaCha20 stream cipher to `in` and stores the result into `out`.
        /// WARNING: This function doesn't provide authenticated encryption.
        /// Using the AEAD or one of the `box` versions is usually preferred.
        pub fn xor(out: []u8, in: []const u8, counter: u32, key: [key_length]u8, nonce: [nonce_length]u8) void {
            assert(in.len == out.len);
            assert(in.len <= 64 * (@as(u39, 1 << 32) - counter));

            var d: [4]u32 = undefined;
            d[0] = counter;
            d[1] = mem.readInt(u32, nonce[0..4], .little);
            d[2] = mem.readInt(u32, nonce[4..8], .little);
            d[3] = mem.readInt(u32, nonce[8..12], .little);
            ChaChaImpl(rounds_nb).chacha20Xor(out, in, keyToWords(key), d, false);
        }

        /// Write the output of the ChaCha20 stream cipher into `out`.
        pub fn stream(out: []u8, counter: u32, key: [key_length]u8, nonce: [nonce_length]u8) void {
            assert(out.len <= 64 * (@as(u39, 1 << 32) - counter));

            var d: [4]u32 = undefined;
            d[0] = counter;
            d[1] = mem.readInt(u32, nonce[0..4], .little);
            d[2] = mem.readInt(u32, nonce[4..8], .little);
            d[3] = mem.readInt(u32, nonce[8..12], .little);
            ChaChaImpl(rounds_nb).chacha20Stream(out, keyToWords(key), d, false);
        }
    };
}

fn ChaChaWith64BitNonce(comptime rounds_nb: usize) type {
    return struct {
        /// Nonce length in bytes.
        pub const nonce_length = 8;
        /// Key length in bytes.
        pub const key_length = 32;
        /// Block length in bytes.
        pub const block_length = 64;

        /// Add the output of the ChaCha20 stream cipher to `in` and stores the result into `out`.
        /// WARNING: This function doesn't provide authenticated encryption.
        /// Using the AEAD or one of the `box` versions is usually preferred.
        pub fn xor(out: []u8, in: []const u8, counter: u64, key: [key_length]u8, nonce: [nonce_length]u8) void {
            assert(in.len == out.len);
            assert(in.len <= 64 * (@as(u71, 1 << 64) - counter));

            const k = keyToWords(key);
            var c: [4]u32 = undefined;
            c[0] = @truncate(counter);
            c[1] = @truncate(counter >> 32);
            c[2] = mem.readInt(u32, nonce[0..4], .little);
            c[3] = mem.readInt(u32, nonce[4..8], .little);
            ChaChaImpl(rounds_nb).chacha20Xor(out, in, k, c, true);
        }

        /// Write the output of the ChaCha20 stream cipher into `out`.
        pub fn stream(out: []u8, counter: u64, key: [key_length]u8, nonce: [nonce_length]u8) void {
            assert(out.len <= 64 * (@as(u71, 1 << 64) - counter));

            const k = keyToWords(key);
            var c: [4]u32 = undefined;
            c[0] = @truncate(counter);
            c[1] = @truncate(counter >> 32);
            c[2] = mem.readInt(u32, nonce[0..4], .little);
            c[3] = mem.readInt(u32, nonce[4..8], .little);
            ChaChaImpl(rounds_nb).chacha20Stream(out, k, c, true);
        }
    };
}

fn XChaChaIETF(comptime rounds_nb: usize) type {
    return struct {
        /// Nonce length in bytes.
        pub const nonce_length = 24;
        /// Key length in bytes.
        pub const key_length = 32;
        /// Block length in bytes.
        pub const block_length = 64;

        /// Add the output of the XChaCha20 stream cipher to `in` and stores the result into `out`.
        /// WARNING: This function doesn't provide authenticated encryption.
        /// Using the AEAD or one of the `box` versions is usually preferred.
        pub fn xor(out: []u8, in: []const u8, counter: u32, key: [key_length]u8, nonce: [nonce_length]u8) void {
            const extended = extend(key, nonce, rounds_nb);
            ChaChaIETF(rounds_nb).xor(out, in, counter, extended.key, extended.nonce);
        }

        /// Write the output of the XChaCha20 stream cipher into `out`.
        pub fn stream(out: []u8, counter: u32, key: [key_length]u8, nonce: [nonce_length]u8) void {
            const extended = extend(key, nonce, rounds_nb);
            ChaChaIETF(rounds_nb).stream(out, counter, extended.key, extended.nonce);
        }
    };
}

fn ChaChaPoly1305(comptime rounds_nb: usize) type {
    return struct {
        pub const tag_length = 16;
        pub const nonce_length = 12;
        pub const key_length = 32;

        /// c: ciphertext: output buffer should be of size m.len
        /// tag: authentication tag: output MAC
        /// m: message
        /// ad: Associated Data
        /// npub: public nonce
        /// k: private key
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) void {
            assert(c.len == m.len);
            assert(m.len <= 64 * (@as(u39, 1 << 32) - 1));

            var polyKey = [_]u8{0} ** 32;
            ChaChaIETF(rounds_nb).xor(polyKey[0..], polyKey[0..], 0, k, npub);

            ChaChaIETF(rounds_nb).xor(c[0..m.len], m, 1, k, npub);

            var mac = Poly1305.init(polyKey[0..]);
            mac.update(ad);
            if (ad.len % 16 != 0) {
                const zeros = [_]u8{0} ** 16;
                const padding = 16 - (ad.len % 16);
                mac.update(zeros[0..padding]);
            }
            mac.update(c[0..m.len]);
            if (m.len % 16 != 0) {
                const zeros = [_]u8{0} ** 16;
                const padding = 16 - (m.len % 16);
                mac.update(zeros[0..padding]);
            }
            var lens: [16]u8 = undefined;
            mem.writeInt(u64, lens[0..8], ad.len, .little);
            mem.writeInt(u64, lens[8..16], m.len, .little);
            mac.update(lens[0..]);
            mac.final(tag);
        }

        /// `m`: Message
        /// `c`: Ciphertext
        /// `tag`: Authentication tag
        /// `ad`: Associated data
        /// `npub`: Public nonce
        /// `k`: Private key
        /// Asserts `c.len == m.len`.
        ///
        /// Contents of `m` are undefined if an error is returned.
        pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) AuthenticationError!void {
            assert(c.len == m.len);

            var polyKey = [_]u8{0} ** 32;
            ChaChaIETF(rounds_nb).xor(polyKey[0..], polyKey[0..], 0, k, npub);

            var mac = Poly1305.init(polyKey[0..]);

            mac.update(ad);
            if (ad.len % 16 != 0) {
                const zeros = [_]u8{0} ** 16;
                const padding = 16 - (ad.len % 16);
                mac.update(zeros[0..padding]);
            }
            mac.update(c);
            if (c.len % 16 != 0) {
                const zeros = [_]u8{0} ** 16;
                const padding = 16 - (c.len % 16);
                mac.update(zeros[0..padding]);
            }
            var lens: [16]u8 = undefined;
            mem.writeInt(u64, lens[0..8], ad.len, .little);
            mem.writeInt(u64, lens[8..16], c.len, .little);
            mac.update(lens[0..]);
            var computed_tag: [16]u8 = undefined;
            mac.final(computed_tag[0..]);

            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
            ChaChaIETF(rounds_nb).xor(m[0..c.len], c, 1, k, npub);
        }
    };
}

fn XChaChaPoly1305(comptime rounds_nb: usize) type {
    return struct {
        pub const tag_length = 16;
        pub const nonce_length = 24;
        pub const key_length = 32;

        /// c: ciphertext: output buffer should be of size m.len
        /// tag: authentication tag: output MAC
        /// m: message
        /// ad: Associated Data
        /// npub: public nonce
        /// k: private key
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) void {
            const extended = extend(k, npub, rounds_nb);
            return ChaChaPoly1305(rounds_nb).encrypt(c, tag, m, ad, extended.nonce, extended.key);
        }

        /// `m`: Message
        /// `c`: Ciphertext
        /// `tag`: Authentication tag
        /// `ad`: Associated data
        /// `npub`: Public nonce
        /// `k`: Private key
        /// Asserts `c.len == m.len`.
        ///
        /// Contents of `m` are undefined if an error is returned.
        pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) AuthenticationError!void {
            const extended = extend(k, npub, rounds_nb);
            return ChaChaPoly1305(rounds_nb).decrypt(m, c, tag, ad, extended.nonce, extended.key);
        }
    };
}

test "AEAD API" {
    const aeads = [_]type{ ChaCha20Poly1305, XChaCha20Poly1305 };
    const m = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
    const ad = "Additional data";

    inline for (aeads) |aead| {
        const key = [_]u8{69} ** aead.key_length;
        const nonce = [_]u8{42} ** aead.nonce_length;
        var c: [m.len]u8 = undefined;
        var tag: [aead.tag_length]u8 = undefined;
        var out: [m.len]u8 = undefined;

        aead.encrypt(c[0..], tag[0..], m, ad, nonce, key);
        try aead.decrypt(out[0..], c[0..], tag, ad[0..], nonce, key);
        try testing.expectEqualSlices(u8, out[0..], m);
        c[0] +%= 1;
        try testing.expectError(error.AuthenticationFailed, aead.decrypt(out[0..], c[0..], tag, ad[0..], nonce, key));
    }
}

// https://tools.ietf.org/html/rfc7539#section-2.4.2
test "test vector sunscreen" {
    const expected_result = [_]u8{
        0x6e, 0x2e, 0x35, 0x9a, 0x25, 0x68, 0xf9, 0x80,
        0x41, 0xba, 0x07, 0x28, 0xdd, 0x0d, 0x69, 0x81,
        0xe9, 0x7e, 0x7a, 0xec, 0x1d, 0x43, 0x60, 0xc2,
        0x0a, 0x27, 0xaf, 0xcc, 0xfd, 0x9f, 0xae, 0x0b,
        0xf9, 0x1b, 0x65, 0xc5, 0x52, 0x47, 0x33, 0xab,
        0x8f, 0x59, 0x3d, 0xab, 0xcd, 0x62, 0xb3, 0x57,
        0x16, 0x39, 0xd6, 0x24, 0xe6, 0x51, 0x52, 0xab,
        0x8f, 0x53, 0x0c, 0x35, 0x9f, 0x08, 0x61, 0xd8,
        0x07, 0xca, 0x0d, 0xbf, 0x50, 0x0d, 0x6a, 0x61,
        0x56, 0xa3, 0x8e, 0x08, 0x8a, 0x22, 0xb6, 0x5e,
        0x52, 0xbc, 0x51, 0x4d, 0x16, 0xcc, 0xf8, 0x06,
        0x81, 0x8c, 0xe9, 0x1a, 0xb7, 0x79, 0x37, 0x36,
        0x5a, 0xf9, 0x0b, 0xbf, 0x74, 0xa3, 0x5b, 0xe6,
        0xb4, 0x0b, 0x8e, 0xed, 0xf2, 0x78, 0x5e, 0x42,
        0x87, 0x4d,
    };
    const m = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
    var result: [114]u8 = undefined;
    const key = [_]u8{
        0,  1,  2,  3,  4,  5,  6,  7,
        8,  9,  10, 11, 12, 13, 14, 15,
        16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31,
    };
    const nonce = [_]u8{
        0, 0, 0, 0,
        0, 0, 0, 0x4a,
        0, 0, 0, 0,
    };

    ChaCha20IETF.xor(result[0..], m[0..], 1, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);

    var m2: [114]u8 = undefined;
    ChaCha20IETF.xor(m2[0..], result[0..], 1, key, nonce);
    try testing.expect(mem.order(u8, m, &m2) == .eq);
}

// https://tools.ietf.org/html/draft-agl-tls-chacha20poly1305-04#section-7
test "test vector 1" {
    const expected_result = [_]u8{
        0x76, 0xb8, 0xe0, 0xad, 0xa0, 0xf1, 0x3d, 0x90,
        0x40, 0x5d, 0x6a, 0xe5, 0x53, 0x86, 0xbd, 0x28,
        0xbd, 0xd2, 0x19, 0xb8, 0xa0, 0x8d, 0xed, 0x1a,
        0xa8, 0x36, 0xef, 0xcc, 0x8b, 0x77, 0x0d, 0xc7,
        0xda, 0x41, 0x59, 0x7c, 0x51, 0x57, 0x48, 0x8d,
        0x77, 0x24, 0xe0, 0x3f, 0xb8, 0xd8, 0x4a, 0x37,
        0x6a, 0x43, 0xb8, 0xf4, 0x15, 0x18, 0xa1, 0x1c,
        0xc3, 0x87, 0xb6, 0x69, 0xb2, 0xee, 0x65, 0x86,
    };
    const m = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    var result: [64]u8 = undefined;
    const key = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };
    const nonce = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 };

    ChaCha20With64BitNonce.xor(result[0..], m[0..], 0, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);
}

test "test vector 2" {
    const expected_result = [_]u8{
        0x45, 0x40, 0xf0, 0x5a, 0x9f, 0x1f, 0xb2, 0x96,
        0xd7, 0x73, 0x6e, 0x7b, 0x20, 0x8e, 0x3c, 0x96,
        0xeb, 0x4f, 0xe1, 0x83, 0x46, 0x88, 0xd2, 0x60,
        0x4f, 0x45, 0x09, 0x52, 0xed, 0x43, 0x2d, 0x41,
        0xbb, 0xe2, 0xa0, 0xb6, 0xea, 0x75, 0x66, 0xd2,
        0xa5, 0xd1, 0xe7, 0xe2, 0x0d, 0x42, 0xaf, 0x2c,
        0x53, 0xd7, 0x92, 0xb1, 0xc4, 0x3f, 0xea, 0x81,
        0x7e, 0x9a, 0xd2, 0x75, 0xae, 0x54, 0x69, 0x63,
    };
    const m = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    var result: [64]u8 = undefined;
    const key = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    };
    const nonce = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 };

    ChaCha20With64BitNonce.xor(result[0..], m[0..], 0, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);
}

test "test vector 3" {
    const expected_result = [_]u8{
        0xde, 0x9c, 0xba, 0x7b, 0xf3, 0xd6, 0x9e, 0xf5,
        0xe7, 0x86, 0xdc, 0x63, 0x97, 0x3f, 0x65, 0x3a,
        0x0b, 0x49, 0xe0, 0x15, 0xad, 0xbf, 0xf7, 0x13,
        0x4f, 0xcb, 0x7d, 0xf1, 0x37, 0x82, 0x10, 0x31,
        0xe8, 0x5a, 0x05, 0x02, 0x78, 0xa7, 0x08, 0x45,
        0x27, 0x21, 0x4f, 0x73, 0xef, 0xc7, 0xfa, 0x5b,
        0x52, 0x77, 0x06, 0x2e, 0xb7, 0xa0, 0x43, 0x3e,
        0x44, 0x5f, 0x41, 0xe3,
    };
    const m = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    var result: [60]u8 = undefined;
    const key = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };
    const nonce = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 1 };

    ChaCha20With64BitNonce.xor(result[0..], m[0..], 0, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);
}

test "test vector 4" {
    const expected_result = [_]u8{
        0xef, 0x3f, 0xdf, 0xd6, 0xc6, 0x15, 0x78, 0xfb,
        0xf5, 0xcf, 0x35, 0xbd, 0x3d, 0xd3, 0x3b, 0x80,
        0x09, 0x63, 0x16, 0x34, 0xd2, 0x1e, 0x42, 0xac,
        0x33, 0x96, 0x0b, 0xd1, 0x38, 0xe5, 0x0d, 0x32,
        0x11, 0x1e, 0x4c, 0xaf, 0x23, 0x7e, 0xe5, 0x3c,
        0xa8, 0xad, 0x64, 0x26, 0x19, 0x4a, 0x88, 0x54,
        0x5d, 0xdc, 0x49, 0x7a, 0x0b, 0x46, 0x6e, 0x7d,
        0x6b, 0xbd, 0xb0, 0x04, 0x1b, 0x2f, 0x58, 0x6b,
    };
    const m = [_]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    var result: [64]u8 = undefined;
    const key = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    };
    const nonce = [_]u8{ 1, 0, 0, 0, 0, 0, 0, 0 };

    ChaCha20With64BitNonce.xor(result[0..], m[0..], 0, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);
}

test "test vector 5" {
    const expected_result = [_]u8{
        0xf7, 0x98, 0xa1, 0x89, 0xf1, 0x95, 0xe6, 0x69,
        0x82, 0x10, 0x5f, 0xfb, 0x64, 0x0b, 0xb7, 0x75,
        0x7f, 0x57, 0x9d, 0xa3, 0x16, 0x02, 0xfc, 0x93,
        0xec, 0x01, 0xac, 0x56, 0xf8, 0x5a, 0xc3, 0xc1,
        0x34, 0xa4, 0x54, 0x7b, 0x73, 0x3b, 0x46, 0x41,
        0x30, 0x42, 0xc9, 0x44, 0x00, 0x49, 0x17, 0x69,
        0x05, 0xd3, 0xbe, 0x59, 0xea, 0x1c, 0x53, 0xf1,
        0x59, 0x16, 0x15, 0x5c, 0x2b, 0xe8, 0x24, 0x1a,

        0x38, 0x00, 0x8b, 0x9a, 0x26, 0xbc, 0x35, 0x94,
        0x1e, 0x24, 0x44, 0x17, 0x7c, 0x8a, 0xde, 0x66,
        0x89, 0xde, 0x95, 0x26, 0x49, 0x86, 0xd9, 0x58,
        0x89, 0xfb, 0x60, 0xe8, 0x46, 0x29, 0xc9, 0xbd,
        0x9a, 0x5a, 0xcb, 0x1c, 0xc1, 0x18, 0xbe, 0x56,
        0x3e, 0xb9, 0xb3, 0xa4, 0xa4, 0x72, 0xf8, 0x2e,
        0x09, 0xa7, 0xe7, 0x78, 0x49, 0x2b, 0x56, 0x2e,
        0xf7, 0x13, 0x0e, 0x88, 0xdf, 0xe0, 0x31, 0xc7,

        0x9d, 0xb9, 0xd4, 0xf7, 0xc7, 0xa8, 0x99, 0x15,
        0x1b, 0x9a, 0x47, 0x50, 0x32, 0xb6, 0x3f, 0xc3,
        0x85, 0x24, 0x5f, 0xe0, 0x54, 0xe3, 0xdd, 0x5a,
        0x97, 0xa5, 0xf5, 0x76, 0xfe, 0x06, 0x40, 0x25,
        0xd3, 0xce, 0x04, 0x2c, 0x56, 0x6a, 0xb2, 0xc5,
        0x07, 0xb1, 0x38, 0xdb, 0x85, 0x3e, 0x3d, 0x69,
        0x59, 0x66, 0x09, 0x96, 0x54, 0x6c, 0xc9, 0xc4,
        0xa6, 0xea, 0xfd, 0xc7, 0x77, 0xc0, 0x40, 0xd7,

        0x0e, 0xaf, 0x46, 0xf7, 0x6d, 0xad, 0x39, 0x79,
        0xe5, 0xc5, 0x36, 0x0c, 0x33, 0x17, 0x16, 0x6a,
        0x1c, 0x89, 0x4c, 0x94, 0xa3, 0x71, 0x87, 0x6a,
        0x94, 0xdf, 0x76, 0x28, 0xfe, 0x4e, 0xaa, 0xf2,
        0xcc, 0xb2, 0x7d, 0x5a, 0xaa, 0xe0, 0xad, 0x7a,
        0xd0, 0xf9, 0xd4, 0xb6, 0xad, 0x3b, 0x54, 0x09,
        0x87, 0x46, 0xd4, 0x52, 0x4d, 0x38, 0x40, 0x7a,
        0x6d, 0xeb, 0x3a, 0xb7, 0x8f, 0xab, 0x78, 0xc9,
    };
    const m = [_]u8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var result: [256]u8 = undefined;
    const key = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
        0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
    };
    const nonce = [_]u8{
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    };

    ChaCha20With64BitNonce.xor(result[0..], m[0..], 0, key, nonce);
    try testing.expectEqualSlices(u8, &expected_result, &result);
}

test "seal" {
    {
        const m = "";
        const ad = "";
        const key = [_]u8{
            0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
            0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
        };
        const nonce = [_]u8{ 0x7, 0x0, 0x0, 0x0, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47 };
        const exp_out = [_]u8{ 0xa0, 0x78, 0x4d, 0x7a, 0x47, 0x16, 0xf3, 0xfe, 0xb4, 0xf6, 0x4e, 0x7f, 0x4b, 0x39, 0xbf, 0x4 };

        var out: [exp_out.len]u8 = undefined;
        ChaCha20Poly1305.encrypt(out[0..m.len], out[m.len..], m, ad, nonce, key);
        try testing.expectEqualSlices(u8, exp_out[0..], out[0..]);
    }
    {
        const m = [_]u8{
            0x4c, 0x61, 0x64, 0x69, 0x65, 0x73, 0x20, 0x61, 0x6e, 0x64, 0x20, 0x47, 0x65, 0x6e, 0x74, 0x6c,
            0x65, 0x6d, 0x65, 0x6e, 0x20, 0x6f, 0x66, 0x20, 0x74, 0x68, 0x65, 0x20, 0x63, 0x6c, 0x61, 0x73,
            0x73, 0x20, 0x6f, 0x66, 0x20, 0x27, 0x39, 0x39, 0x3a, 0x20, 0x49, 0x66, 0x20, 0x49, 0x20, 0x63,
            0x6f, 0x75, 0x6c, 0x64, 0x20, 0x6f, 0x66, 0x66, 0x65, 0x72, 0x20, 0x79, 0x6f, 0x75, 0x20, 0x6f,
            0x6e, 0x6c, 0x79, 0x20, 0x6f, 0x6e, 0x65, 0x20, 0x74, 0x69, 0x70, 0x20, 0x66, 0x6f, 0x72, 0x20,
            0x74, 0x68, 0x65, 0x20, 0x66, 0x75, 0x74, 0x75, 0x72, 0x65, 0x2c, 0x20, 0x73, 0x75, 0x6e, 0x73,
            0x63, 0x72, 0x65, 0x65, 0x6e, 0x20, 0x77, 0x6f, 0x75, 0x6c, 0x64, 0x20, 0x62, 0x65, 0x20, 0x69,
            0x74, 0x2e,
        };
        const ad = [_]u8{ 0x50, 0x51, 0x52, 0x53, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7 };
        const key = [_]u8{
            0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
            0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
        };
        const nonce = [_]u8{ 0x7, 0x0, 0x0, 0x0, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47 };
        const exp_out = [_]u8{
            0xd3, 0x1a, 0x8d, 0x34, 0x64, 0x8e, 0x60, 0xdb, 0x7b, 0x86, 0xaf, 0xbc, 0x53, 0xef, 0x7e, 0xc2,
            0xa4, 0xad, 0xed, 0x51, 0x29, 0x6e, 0x8,  0xfe, 0xa9, 0xe2, 0xb5, 0xa7, 0x36, 0xee, 0x62, 0xd6,
            0x3d, 0xbe, 0xa4, 0x5e, 0x8c, 0xa9, 0x67, 0x12, 0x82, 0xfa, 0xfb, 0x69, 0xda, 0x92, 0x72, 0x8b,
            0x1a, 0x71, 0xde, 0xa,  0x9e, 0x6,  0xb,  0x29, 0x5,  0xd6, 0xa5, 0xb6, 0x7e, 0xcd, 0x3b, 0x36,
            0x92, 0xdd, 0xbd, 0x7f, 0x2d, 0x77, 0x8b, 0x8c, 0x98, 0x3,  0xae, 0xe3, 0x28, 0x9,  0x1b, 0x58,
            0xfa, 0xb3, 0x24, 0xe4, 0xfa, 0xd6, 0x75, 0x94, 0x55, 0x85, 0x80, 0x8b, 0x48, 0x31, 0xd7, 0xbc,
            0x3f, 0xf4, 0xde, 0xf0, 0x8e, 0x4b, 0x7a, 0x9d, 0xe5, 0x76, 0xd2, 0x65, 0x86, 0xce, 0xc6, 0x4b,
            0x61, 0x16, 0x1a, 0xe1, 0xb,  0x59, 0x4f, 0x9,  0xe2, 0x6a, 0x7e, 0x90, 0x2e, 0xcb, 0xd0, 0x60,
            0x6,  0x91,
        };

        var out: [exp_out.len]u8 = undefined;
        ChaCha20Poly1305.encrypt(out[0..m.len], out[m.len..], m[0..], ad[0..], nonce, key);
        try testing.expectEqualSlices(u8, exp_out[0..], out[0..]);
    }
}

test "open" {
    {
        const c = [_]u8{ 0xa0, 0x78, 0x4d, 0x7a, 0x47, 0x16, 0xf3, 0xfe, 0xb4, 0xf6, 0x4e, 0x7f, 0x4b, 0x39, 0xbf, 0x4 };
        const ad = "";
        const key = [_]u8{
            0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
            0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
        };
        const nonce = [_]u8{ 0x7, 0x0, 0x0, 0x0, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47 };
        const exp_out = "";

        var out: [exp_out.len]u8 = undefined;
        try ChaCha20Poly1305.decrypt(out[0..], c[0..exp_out.len], c[exp_out.len..].*, ad[0..], nonce, key);
        try testing.expectEqualSlices(u8, exp_out[0..], out[0..]);
    }
    {
        const c = [_]u8{
            0xd3, 0x1a, 0x8d, 0x34, 0x64, 0x8e, 0x60, 0xdb, 0x7b, 0x86, 0xaf, 0xbc, 0x53, 0xef, 0x7e, 0xc2,
            0xa4, 0xad, 0xed, 0x51, 0x29, 0x6e, 0x8,  0xfe, 0xa9, 0xe2, 0xb5, 0xa7, 0x36, 0xee, 0x62, 0xd6,
            0x3d, 0xbe, 0xa4, 0x5e, 0x8c, 0xa9, 0x67, 0x12, 0x82, 0xfa, 0xfb, 0x69, 0xda, 0x92, 0x72, 0x8b,
            0x1a, 0x71, 0xde, 0xa,  0x9e, 0x6,  0xb,  0x29, 0x5,  0xd6, 0xa5, 0xb6, 0x7e, 0xcd, 0x3b, 0x36,
            0x92, 0xdd, 0xbd, 0x7f, 0x2d, 0x77, 0x8b, 0x8c, 0x98, 0x3,  0xae, 0xe3, 0x28, 0x9,  0x1b, 0x58,
            0xfa, 0xb3, 0x24, 0xe4, 0xfa, 0xd6, 0x75, 0x94, 0x55, 0x85, 0x80, 0x8b, 0x48, 0x31, 0xd7, 0xbc,
            0x3f, 0xf4, 0xde, 0xf0, 0x8e, 0x4b, 0x7a, 0x9d, 0xe5, 0x76, 0xd2, 0x65, 0x86, 0xce, 0xc6, 0x4b,
            0x61, 0x16, 0x1a, 0xe1, 0xb,  0x59, 0x4f, 0x9,  0xe2, 0x6a, 0x7e, 0x90, 0x2e, 0xcb, 0xd0, 0x60,
            0x6,  0x91,
        };
        const ad = [_]u8{ 0x50, 0x51, 0x52, 0x53, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7 };
        const key = [_]u8{
            0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
            0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
        };
        const nonce = [_]u8{ 0x7, 0x0, 0x0, 0x0, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47 };
        const exp_out = [_]u8{
            0x4c, 0x61, 0x64, 0x69, 0x65, 0x73, 0x20, 0x61, 0x6e, 0x64, 0x20, 0x47, 0x65, 0x6e, 0x74, 0x6c,
            0x65, 0x6d, 0x65, 0x6e, 0x20, 0x6f, 0x66, 0x20, 0x74, 0x68, 0x65, 0x20, 0x63, 0x6c, 0x61, 0x73,
            0x73, 0x20, 0x6f, 0x66, 0x20, 0x27, 0x39, 0x39, 0x3a, 0x20, 0x49, 0x66, 0x20, 0x49, 0x20, 0x63,
            0x6f, 0x75, 0x6c, 0x64, 0x20, 0x6f, 0x66, 0x66, 0x65, 0x72, 0x20, 0x79, 0x6f, 0x75, 0x20, 0x6f,
            0x6e, 0x6c, 0x79, 0x20, 0x6f, 0x6e, 0x65, 0x20, 0x74, 0x69, 0x70, 0x20, 0x66, 0x6f, 0x72, 0x20,
            0x74, 0x68, 0x65, 0x20, 0x66, 0x75, 0x74, 0x75, 0x72, 0x65, 0x2c, 0x20, 0x73, 0x75, 0x6e, 0x73,
            0x63, 0x72, 0x65, 0x65, 0x6e, 0x20, 0x77, 0x6f, 0x75, 0x6c, 0x64, 0x20, 0x62, 0x65, 0x20, 0x69,
            0x74, 0x2e,
        };

        var out: [exp_out.len]u8 = undefined;
        try ChaCha20Poly1305.decrypt(out[0..], c[0..exp_out.len], c[exp_out.len..].*, ad[0..], nonce, key);
        try testing.expectEqualSlices(u8, exp_out[0..], out[0..]);

        // corrupting the ciphertext, data, key, or nonce should cause a failure
        var bad_c = c;
        bad_c[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, ChaCha20Poly1305.decrypt(out[0..], bad_c[0..out.len], bad_c[out.len..].*, ad[0..], nonce, key));
        var bad_ad = ad;
        bad_ad[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, ChaCha20Poly1305.decrypt(out[0..], c[0..out.len], c[out.len..].*, bad_ad[0..], nonce, key));
        var bad_key = key;
        bad_key[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, ChaCha20Poly1305.decrypt(out[0..], c[0..out.len], c[out.len..].*, ad[0..], nonce, bad_key));
        var bad_nonce = nonce;
        bad_nonce[0] ^= 1;
        try testing.expectError(error.AuthenticationFailed, ChaCha20Poly1305.decrypt(out[0..], c[0..out.len], c[out.len..].*, ad[0..], bad_nonce, key));
    }
}

test "xchacha20" {
    const key = [_]u8{69} ** 32;
    const nonce = [_]u8{42} ** 24;
    const m = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
    {
        var c: [m.len]u8 = undefined;
        XChaCha20IETF.xor(c[0..], m[0..], 0, key, nonce);
        var buf: [2 * c.len]u8 = undefined;
        try testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexUpper(&c)}), "E0A1BCF939654AFDBDC1746EC49832647C19D891F0D1A81FC0C1703B4514BDEA584B512F6908C2C5E9DD18D5CBC1805DE5803FE3B9CA5F193FB8359E91FAB0C3BB40309A292EB1CF49685C65C4A3ADF4F11DB0CD2B6B67FBC174BC2E860E8F769FD3565BBFAD1C845E05A0FED9BE167C240D");
    }
    {
        const ad = "Additional data";
        var c: [m.len + XChaCha20Poly1305.tag_length]u8 = undefined;
        XChaCha20Poly1305.encrypt(c[0..m.len], c[m.len..], m, ad, nonce, key);
        var out: [m.len]u8 = undefined;
        try XChaCha20Poly1305.decrypt(out[0..], c[0..m.len], c[m.len..].*, ad, nonce, key);
        var buf: [2 * c.len]u8 = undefined;
        try testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexUpper(&c)}), "994D2DD32333F48E53650C02C7A2ABB8E018B0836D7175AEC779F52E961780768F815C58F1AA52D211498DB89B9216763F569C9433A6BBFCEFB4D4A49387A4C5207FBB3B5A92B5941294DF30588C6740D39DC16FA1F0E634F7246CF7CDCB978E44347D89381B7A74EB7084F754B90BDE9AAF5A94B8F2A85EFD0B50692AE2D425E234");
        try testing.expectEqualSlices(u8, out[0..], m);
        c[0] +%= 1;
        try testing.expectError(error.AuthenticationFailed, XChaCha20Poly1305.decrypt(out[0..], c[0..m.len], c[m.len..].*, ad, nonce, key));
    }
}
