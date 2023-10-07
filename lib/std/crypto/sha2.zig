const std = @import("../std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const htest = @import("test.zig");

/////////////////////
// Sha224 + Sha256

const RoundParam256 = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    e: usize,
    f: usize,
    g: usize,
    h: usize,
    i: usize,
};

fn roundParam256(a: usize, b: usize, c: usize, d: usize, e: usize, f: usize, g: usize, h: usize, i: usize) RoundParam256 {
    return RoundParam256{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .e = e,
        .f = f,
        .g = g,
        .h = h,
        .i = i,
    };
}

const Sha2Params32 = struct {
    iv0: u32,
    iv1: u32,
    iv2: u32,
    iv3: u32,
    iv4: u32,
    iv5: u32,
    iv6: u32,
    iv7: u32,
    digest_bits: usize,
};

const Sha224Params = Sha2Params32{
    .iv0 = 0xC1059ED8,
    .iv1 = 0x367CD507,
    .iv2 = 0x3070DD17,
    .iv3 = 0xF70E5939,
    .iv4 = 0xFFC00B31,
    .iv5 = 0x68581511,
    .iv6 = 0x64F98FA7,
    .iv7 = 0xBEFA4FA4,
    .digest_bits = 224,
};

const Sha256Params = Sha2Params32{
    .iv0 = 0x6A09E667,
    .iv1 = 0xBB67AE85,
    .iv2 = 0x3C6EF372,
    .iv3 = 0xA54FF53A,
    .iv4 = 0x510E527F,
    .iv5 = 0x9B05688C,
    .iv6 = 0x1F83D9AB,
    .iv7 = 0x5BE0CD19,
    .digest_bits = 256,
};

const v4u32 = @Vector(4, u32);

/// SHA-224
pub const Sha224 = Sha2x32(Sha224Params);

/// SHA-256
pub const Sha256 = Sha2x32(Sha256Params);

fn Sha2x32(comptime params: Sha2Params32) type {
    return struct {
        const Self = @This();
        pub const block_length = 64;
        pub const digest_length = params.digest_bits / 8;
        pub const Options = struct {};

        s: [8]u32 align(16),
        // Streaming Cache
        buf: [64]u8 = undefined,
        buf_len: u8 = 0,
        total_len: u64 = 0,

        pub fn init(options: Options) Self {
            _ = options;
            return Self{
                .s = [_]u32{
                    params.iv0,
                    params.iv1,
                    params.iv2,
                    params.iv3,
                    params.iv4,
                    params.iv5,
                    params.iv6,
                    params.iv7,
                },
            };
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len >= 64) {
                off += 64 - d.buf_len;
                @memcpy(d.buf[d.buf_len..][0..off], b[0..off]);

                d.round(&d.buf);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 64 <= b.len) : (off += 64) {
                d.round(b[off..][0..64]);
            }

            // Copy any remainder for next pass.
            const b_slice = b[off..];
            @memcpy(d.buf[d.buf_len..][0..b_slice.len], b_slice);
            d.buf_len += @as(u8, @intCast(b[off..].len));

            d.total_len += b.len;
        }

        pub fn peek(d: Self) [digest_length]u8 {
            var copy = d;
            return copy.finalResult();
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            // The buffer here will never be completely full.
            @memset(d.buf[d.buf_len..], 0);

            // Append padding bits.
            d.buf[d.buf_len] = 0x80;
            d.buf_len += 1;

            // > 448 mod 512 so need to add an extra round to wrap around.
            if (64 - d.buf_len < 8) {
                d.round(&d.buf);
                @memset(d.buf[0..], 0);
            }

            // Append message length.
            var i: usize = 1;
            var len = d.total_len >> 5;
            d.buf[63] = @as(u8, @intCast(d.total_len & 0x1f)) << 3;
            while (i < 8) : (i += 1) {
                d.buf[63 - i] = @as(u8, @intCast(len & 0xff));
                len >>= 8;
            }

            d.round(&d.buf);

            // May truncate for possible 224 output
            const rr = d.s[0 .. params.digest_bits / 32];

            for (rr, 0..) |s, j| {
                mem.writeIntBig(u32, out[4 * j ..][0..4], s);
            }
        }

        pub fn finalResult(d: *Self) [digest_length]u8 {
            var result: [digest_length]u8 = undefined;
            d.final(&result);
            return result;
        }

        const W = [64]u32{
            0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
            0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
            0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
            0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
            0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
            0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
            0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
            0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
        };

        fn round(d: *Self, b: *const [64]u8) void {
            var s: [64]u32 align(16) = undefined;
            for (@as(*align(1) const [16]u32, @ptrCast(b)), 0..) |*elem, i| {
                s[i] = mem.readIntBig(u32, mem.asBytes(elem));
            }

            if (!@inComptime()) {
                switch (builtin.cpu.arch) {
                    .aarch64 => if (builtin.zig_backend != .stage2_c and comptime std.Target.aarch64.featureSetHas(builtin.cpu.features, .sha2)) {
                        var x: v4u32 = d.s[0..4].*;
                        var y: v4u32 = d.s[4..8].*;
                        const s_v = @as(*[16]v4u32, @ptrCast(&s));

                        comptime var k: u8 = 0;
                        inline while (k < 16) : (k += 1) {
                            if (k > 3) {
                                s_v[k] = asm (
                                    \\sha256su0.4s %[w0_3], %[w4_7]
                                    \\sha256su1.4s %[w0_3], %[w8_11], %[w12_15]
                                    : [w0_3] "=w" (-> v4u32),
                                    : [_] "0" (s_v[k - 4]),
                                      [w4_7] "w" (s_v[k - 3]),
                                      [w8_11] "w" (s_v[k - 2]),
                                      [w12_15] "w" (s_v[k - 1]),
                                );
                            }

                            const w: v4u32 = s_v[k] +% @as(v4u32, W[4 * k ..][0..4].*);
                            asm volatile (
                                \\mov.4s v0, %[x]
                                \\sha256h.4s %[x], %[y], %[w]
                                \\sha256h2.4s %[y], v0, %[w]
                                : [x] "=w" (x),
                                  [y] "=w" (y),
                                : [_] "0" (x),
                                  [_] "1" (y),
                                  [w] "w" (w),
                                : "v0"
                            );
                        }

                        d.s[0..4].* = x +% @as(v4u32, d.s[0..4].*);
                        d.s[4..8].* = y +% @as(v4u32, d.s[4..8].*);
                        return;
                    },
                    // C backend doesn't currently support passing vectors to inline asm.
                    .x86_64 => if (builtin.zig_backend != .stage2_c and comptime std.Target.x86.featureSetHasAll(builtin.cpu.features, .{ .sha, .avx2 })) {
                        var x: v4u32 = [_]u32{ d.s[5], d.s[4], d.s[1], d.s[0] };
                        var y: v4u32 = [_]u32{ d.s[7], d.s[6], d.s[3], d.s[2] };
                        const s_v = @as(*[16]v4u32, @ptrCast(&s));

                        comptime var k: u8 = 0;
                        inline while (k < 16) : (k += 1) {
                            if (k < 12) {
                                var tmp = s_v[k];
                                s_v[k + 4] = asm (
                                    \\ sha256msg1 %[w4_7], %[tmp]
                                    \\ vpalignr $0x4, %[w8_11], %[w12_15], %[result]
                                    \\ paddd %[tmp], %[result]
                                    \\ sha256msg2 %[w12_15], %[result]
                                    : [tmp] "=&x" (tmp),
                                      [result] "=&x" (-> v4u32),
                                    : [_] "0" (tmp),
                                      [w4_7] "x" (s_v[k + 1]),
                                      [w8_11] "x" (s_v[k + 2]),
                                      [w12_15] "x" (s_v[k + 3]),
                                );
                            }

                            const w: v4u32 = s_v[k] +% @as(v4u32, W[4 * k ..][0..4].*);
                            y = asm ("sha256rnds2 %[x], %[y]"
                                : [y] "=x" (-> v4u32),
                                : [_] "0" (y),
                                  [x] "x" (x),
                                  [_] "{xmm0}" (w),
                            );

                            x = asm ("sha256rnds2 %[y], %[x]"
                                : [x] "=x" (-> v4u32),
                                : [_] "0" (x),
                                  [y] "x" (y),
                                  [_] "{xmm0}" (@as(v4u32, @bitCast(@as(u128, @bitCast(w)) >> 64))),
                            );
                        }

                        d.s[0] +%= x[3];
                        d.s[1] +%= x[2];
                        d.s[4] +%= x[1];
                        d.s[5] +%= x[0];
                        d.s[2] +%= y[3];
                        d.s[3] +%= y[2];
                        d.s[6] +%= y[1];
                        d.s[7] +%= y[0];
                        return;
                    },
                    else => {},
                }
            }

            var i: usize = 16;
            while (i < 64) : (i += 1) {
                s[i] = s[i - 16] +% s[i - 7] +% (math.rotr(u32, s[i - 15], @as(u32, 7)) ^ math.rotr(u32, s[i - 15], @as(u32, 18)) ^ (s[i - 15] >> 3)) +% (math.rotr(u32, s[i - 2], @as(u32, 17)) ^ math.rotr(u32, s[i - 2], @as(u32, 19)) ^ (s[i - 2] >> 10));
            }

            var v: [8]u32 = [_]u32{
                d.s[0],
                d.s[1],
                d.s[2],
                d.s[3],
                d.s[4],
                d.s[5],
                d.s[6],
                d.s[7],
            };

            const round0 = comptime [_]RoundParam256{
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 0),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 1),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 2),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 3),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 4),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 5),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 6),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 7),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 8),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 9),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 10),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 11),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 12),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 13),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 14),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 15),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 16),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 17),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 18),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 19),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 20),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 21),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 22),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 23),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 24),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 25),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 26),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 27),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 28),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 29),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 30),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 31),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 32),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 33),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 34),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 35),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 36),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 37),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 38),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 39),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 40),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 41),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 42),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 43),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 44),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 45),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 46),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 47),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 48),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 49),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 50),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 51),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 52),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 53),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 54),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 55),
                roundParam256(0, 1, 2, 3, 4, 5, 6, 7, 56),
                roundParam256(7, 0, 1, 2, 3, 4, 5, 6, 57),
                roundParam256(6, 7, 0, 1, 2, 3, 4, 5, 58),
                roundParam256(5, 6, 7, 0, 1, 2, 3, 4, 59),
                roundParam256(4, 5, 6, 7, 0, 1, 2, 3, 60),
                roundParam256(3, 4, 5, 6, 7, 0, 1, 2, 61),
                roundParam256(2, 3, 4, 5, 6, 7, 0, 1, 62),
                roundParam256(1, 2, 3, 4, 5, 6, 7, 0, 63),
            };
            inline for (round0) |r| {
                v[r.h] = v[r.h] +% (math.rotr(u32, v[r.e], @as(u32, 6)) ^ math.rotr(u32, v[r.e], @as(u32, 11)) ^ math.rotr(u32, v[r.e], @as(u32, 25))) +% (v[r.g] ^ (v[r.e] & (v[r.f] ^ v[r.g]))) +% W[r.i] +% s[r.i];

                v[r.d] = v[r.d] +% v[r.h];

                v[r.h] = v[r.h] +% (math.rotr(u32, v[r.a], @as(u32, 2)) ^ math.rotr(u32, v[r.a], @as(u32, 13)) ^ math.rotr(u32, v[r.a], @as(u32, 22))) +% ((v[r.a] & (v[r.b] | v[r.c])) | (v[r.b] & v[r.c]));
            }

            d.s[0] +%= v[0];
            d.s[1] +%= v[1];
            d.s[2] +%= v[2];
            d.s[3] +%= v[3];
            d.s[4] +%= v[4];
            d.s[5] +%= v[5];
            d.s[6] +%= v[6];
            d.s[7] +%= v[7];
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

test "sha224 single" {
    try htest.assertEqualHash(Sha224, "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f", "");
    try htest.assertEqualHash(Sha224, "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7", "abc");
    try htest.assertEqualHash(Sha224, "c97ca9a559850ce97a04a96def6d99a9e0e0e2ab14e6b8df265fc0b3", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha224 streaming" {
    var h = Sha224.init(.{});
    var out: [28]u8 = undefined;

    h.final(out[0..]);
    try htest.assertEqual("d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f", out[0..]);

    h = Sha224.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual("23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7", out[0..]);

    h = Sha224.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual("23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7", out[0..]);
}

test "sha256 single" {
    try htest.assertEqualHash(Sha256, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "");
    try htest.assertEqualHash(Sha256, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "abc");
    try htest.assertEqualHash(Sha256, "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha256 streaming" {
    var h = Sha256.init(.{});
    var out: [32]u8 = undefined;

    h.final(out[0..]);
    try htest.assertEqual("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", out[0..]);

    h = Sha256.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", out[0..]);

    h = Sha256.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", out[0..]);
}

test "sha256 aligned final" {
    var block = [_]u8{0} ** Sha256.block_length;
    var out: [Sha256.digest_length]u8 = undefined;

    var h = Sha256.init(.{});
    h.update(&block);
    h.final(out[0..]);
}

/////////////////////
// Sha384 + Sha512

const RoundParam512 = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    e: usize,
    f: usize,
    g: usize,
    h: usize,
    i: usize,
    k: u64,
};

fn roundParam512(a: usize, b: usize, c: usize, d: usize, e: usize, f: usize, g: usize, h: usize, i: usize, k: u64) RoundParam512 {
    return RoundParam512{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .e = e,
        .f = f,
        .g = g,
        .h = h,
        .i = i,
        .k = k,
    };
}

const Sha2Params64 = struct {
    iv0: u64,
    iv1: u64,
    iv2: u64,
    iv3: u64,
    iv4: u64,
    iv5: u64,
    iv6: u64,
    iv7: u64,
    digest_bits: usize,
};

const Sha384Params = Sha2Params64{
    .iv0 = 0xCBBB9D5DC1059ED8,
    .iv1 = 0x629A292A367CD507,
    .iv2 = 0x9159015A3070DD17,
    .iv3 = 0x152FECD8F70E5939,
    .iv4 = 0x67332667FFC00B31,
    .iv5 = 0x8EB44A8768581511,
    .iv6 = 0xDB0C2E0D64F98FA7,
    .iv7 = 0x47B5481DBEFA4FA4,
    .digest_bits = 384,
};

const Sha512Params = Sha2Params64{
    .iv0 = 0x6A09E667F3BCC908,
    .iv1 = 0xBB67AE8584CAA73B,
    .iv2 = 0x3C6EF372FE94F82B,
    .iv3 = 0xA54FF53A5F1D36F1,
    .iv4 = 0x510E527FADE682D1,
    .iv5 = 0x9B05688C2B3E6C1F,
    .iv6 = 0x1F83D9ABFB41BD6B,
    .iv7 = 0x5BE0CD19137E2179,
    .digest_bits = 512,
};

const Sha512256Params = Sha2Params64{
    .iv0 = 0x22312194FC2BF72C,
    .iv1 = 0x9F555FA3C84C64C2,
    .iv2 = 0x2393B86B6F53B151,
    .iv3 = 0x963877195940EABD,
    .iv4 = 0x96283EE2A88EFFE3,
    .iv5 = 0xBE5E1E2553863992,
    .iv6 = 0x2B0199FC2C85B8AA,
    .iv7 = 0x0EB72DDC81C52CA2,
    .digest_bits = 256,
};

const Sha512T256Params = Sha2Params64{
    .iv0 = 0x6A09E667F3BCC908,
    .iv1 = 0xBB67AE8584CAA73B,
    .iv2 = 0x3C6EF372FE94F82B,
    .iv3 = 0xA54FF53A5F1D36F1,
    .iv4 = 0x510E527FADE682D1,
    .iv5 = 0x9B05688C2B3E6C1F,
    .iv6 = 0x1F83D9ABFB41BD6B,
    .iv7 = 0x5BE0CD19137E2179,
    .digest_bits = 256,
};

/// SHA-384
pub const Sha384 = Sha2x64(Sha384Params);

/// SHA-512
pub const Sha512 = Sha2x64(Sha512Params);

/// SHA-512/256
pub const Sha512256 = Sha2x64(Sha512256Params);

/// Truncated SHA-512
pub const Sha512T256 = Sha2x64(Sha512T256Params);

fn Sha2x64(comptime params: Sha2Params64) type {
    return struct {
        const Self = @This();
        pub const block_length = 128;
        pub const digest_length = params.digest_bits / 8;
        pub const Options = struct {};

        s: [8]u64,
        // Streaming Cache
        buf: [128]u8 = undefined,
        buf_len: u8 = 0,
        total_len: u128 = 0,

        pub fn init(options: Options) Self {
            _ = options;
            return Self{
                .s = [_]u64{
                    params.iv0,
                    params.iv1,
                    params.iv2,
                    params.iv3,
                    params.iv4,
                    params.iv5,
                    params.iv6,
                    params.iv7,
                },
            };
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len >= 128) {
                off += 128 - d.buf_len;
                @memcpy(d.buf[d.buf_len..][0..off], b[0..off]);

                d.round(&d.buf);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 128 <= b.len) : (off += 128) {
                d.round(b[off..][0..128]);
            }

            // Copy any remainder for next pass.
            const b_slice = b[off..];
            @memcpy(d.buf[d.buf_len..][0..b_slice.len], b_slice);
            d.buf_len += @as(u8, @intCast(b[off..].len));

            d.total_len += b.len;
        }

        pub fn peek(d: Self) [digest_length]u8 {
            var copy = d;
            return copy.finalResult();
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            // The buffer here will never be completely full.
            @memset(d.buf[d.buf_len..], 0);

            // Append padding bits.
            d.buf[d.buf_len] = 0x80;
            d.buf_len += 1;

            // > 896 mod 1024 so need to add an extra round to wrap around.
            if (128 - d.buf_len < 16) {
                d.round(d.buf[0..]);
                @memset(d.buf[0..], 0);
            }

            // Append message length.
            var i: usize = 1;
            var len = d.total_len >> 5;
            d.buf[127] = @as(u8, @intCast(d.total_len & 0x1f)) << 3;
            while (i < 16) : (i += 1) {
                d.buf[127 - i] = @as(u8, @intCast(len & 0xff));
                len >>= 8;
            }

            d.round(d.buf[0..]);

            // May truncate for possible 384 output
            const rr = d.s[0 .. params.digest_bits / 64];

            for (rr, 0..) |s, j| {
                mem.writeIntBig(u64, out[8 * j ..][0..8], s);
            }
        }

        pub fn finalResult(d: *Self) [digest_length]u8 {
            var result: [digest_length]u8 = undefined;
            d.final(&result);
            return result;
        }

        fn round(d: *Self, b: *const [128]u8) void {
            var s: [80]u64 = undefined;

            var i: usize = 0;
            while (i < 16) : (i += 1) {
                s[i] = mem.readIntBig(u64, b[i * 8 ..][0..8]);
            }
            while (i < 80) : (i += 1) {
                s[i] = s[i - 16] +% s[i - 7] +%
                    (math.rotr(u64, s[i - 15], @as(u64, 1)) ^ math.rotr(u64, s[i - 15], @as(u64, 8)) ^ (s[i - 15] >> 7)) +%
                    (math.rotr(u64, s[i - 2], @as(u64, 19)) ^ math.rotr(u64, s[i - 2], @as(u64, 61)) ^ (s[i - 2] >> 6));
            }

            var v: [8]u64 = [_]u64{
                d.s[0],
                d.s[1],
                d.s[2],
                d.s[3],
                d.s[4],
                d.s[5],
                d.s[6],
                d.s[7],
            };

            const round0 = comptime [_]RoundParam512{
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 0, 0x428A2F98D728AE22),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 1, 0x7137449123EF65CD),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 2, 0xB5C0FBCFEC4D3B2F),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 3, 0xE9B5DBA58189DBBC),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 4, 0x3956C25BF348B538),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 5, 0x59F111F1B605D019),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 6, 0x923F82A4AF194F9B),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 7, 0xAB1C5ED5DA6D8118),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 8, 0xD807AA98A3030242),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 9, 0x12835B0145706FBE),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 10, 0x243185BE4EE4B28C),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 11, 0x550C7DC3D5FFB4E2),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 12, 0x72BE5D74F27B896F),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 13, 0x80DEB1FE3B1696B1),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 14, 0x9BDC06A725C71235),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 15, 0xC19BF174CF692694),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 16, 0xE49B69C19EF14AD2),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 17, 0xEFBE4786384F25E3),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 18, 0x0FC19DC68B8CD5B5),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 19, 0x240CA1CC77AC9C65),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 20, 0x2DE92C6F592B0275),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 21, 0x4A7484AA6EA6E483),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 22, 0x5CB0A9DCBD41FBD4),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 23, 0x76F988DA831153B5),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 24, 0x983E5152EE66DFAB),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 25, 0xA831C66D2DB43210),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 26, 0xB00327C898FB213F),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 27, 0xBF597FC7BEEF0EE4),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 28, 0xC6E00BF33DA88FC2),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 29, 0xD5A79147930AA725),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 30, 0x06CA6351E003826F),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 31, 0x142929670A0E6E70),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 32, 0x27B70A8546D22FFC),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 33, 0x2E1B21385C26C926),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 34, 0x4D2C6DFC5AC42AED),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 35, 0x53380D139D95B3DF),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 36, 0x650A73548BAF63DE),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 37, 0x766A0ABB3C77B2A8),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 38, 0x81C2C92E47EDAEE6),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 39, 0x92722C851482353B),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 40, 0xA2BFE8A14CF10364),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 41, 0xA81A664BBC423001),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 42, 0xC24B8B70D0F89791),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 43, 0xC76C51A30654BE30),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 44, 0xD192E819D6EF5218),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 45, 0xD69906245565A910),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 46, 0xF40E35855771202A),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 47, 0x106AA07032BBD1B8),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 48, 0x19A4C116B8D2D0C8),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 49, 0x1E376C085141AB53),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 50, 0x2748774CDF8EEB99),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 51, 0x34B0BCB5E19B48A8),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 52, 0x391C0CB3C5C95A63),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 53, 0x4ED8AA4AE3418ACB),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 54, 0x5B9CCA4F7763E373),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 55, 0x682E6FF3D6B2B8A3),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 56, 0x748F82EE5DEFB2FC),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 57, 0x78A5636F43172F60),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 58, 0x84C87814A1F0AB72),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 59, 0x8CC702081A6439EC),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 60, 0x90BEFFFA23631E28),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 61, 0xA4506CEBDE82BDE9),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 62, 0xBEF9A3F7B2C67915),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 63, 0xC67178F2E372532B),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 64, 0xCA273ECEEA26619C),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 65, 0xD186B8C721C0C207),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 66, 0xEADA7DD6CDE0EB1E),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 67, 0xF57D4F7FEE6ED178),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 68, 0x06F067AA72176FBA),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 69, 0x0A637DC5A2C898A6),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 70, 0x113F9804BEF90DAE),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 71, 0x1B710B35131C471B),
                roundParam512(0, 1, 2, 3, 4, 5, 6, 7, 72, 0x28DB77F523047D84),
                roundParam512(7, 0, 1, 2, 3, 4, 5, 6, 73, 0x32CAAB7B40C72493),
                roundParam512(6, 7, 0, 1, 2, 3, 4, 5, 74, 0x3C9EBE0A15C9BEBC),
                roundParam512(5, 6, 7, 0, 1, 2, 3, 4, 75, 0x431D67C49C100D4C),
                roundParam512(4, 5, 6, 7, 0, 1, 2, 3, 76, 0x4CC5D4BECB3E42B6),
                roundParam512(3, 4, 5, 6, 7, 0, 1, 2, 77, 0x597F299CFC657E2A),
                roundParam512(2, 3, 4, 5, 6, 7, 0, 1, 78, 0x5FCB6FAB3AD6FAEC),
                roundParam512(1, 2, 3, 4, 5, 6, 7, 0, 79, 0x6C44198C4A475817),
            };
            inline for (round0) |r| {
                v[r.h] = v[r.h] +% (math.rotr(u64, v[r.e], @as(u64, 14)) ^ math.rotr(u64, v[r.e], @as(u64, 18)) ^ math.rotr(u64, v[r.e], @as(u64, 41))) +% (v[r.g] ^ (v[r.e] & (v[r.f] ^ v[r.g]))) +% r.k +% s[r.i];

                v[r.d] = v[r.d] +% v[r.h];

                v[r.h] = v[r.h] +% (math.rotr(u64, v[r.a], @as(u64, 28)) ^ math.rotr(u64, v[r.a], @as(u64, 34)) ^ math.rotr(u64, v[r.a], @as(u64, 39))) +% ((v[r.a] & (v[r.b] | v[r.c])) | (v[r.b] & v[r.c]));
            }

            d.s[0] +%= v[0];
            d.s[1] +%= v[1];
            d.s[2] +%= v[2];
            d.s[3] +%= v[3];
            d.s[4] +%= v[4];
            d.s[5] +%= v[5];
            d.s[6] +%= v[6];
            d.s[7] +%= v[7];
        }
    };
}

test "sha384 single" {
    const h1 = "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b";
    try htest.assertEqualHash(Sha384, h1, "");

    const h2 = "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7";
    try htest.assertEqualHash(Sha384, h2, "abc");

    const h3 = "09330c33f71147e83d192fc782cd1b4753111b173b3b05d22fa08086e3b0f712fcc7c71a557e2db966c3e9fa91746039";
    try htest.assertEqualHash(Sha384, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha384 streaming" {
    var h = Sha384.init(.{});
    var out: [48]u8 = undefined;

    const h1 = "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b";
    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7";

    h = Sha384.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Sha384.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);
}

test "sha512 single" {
    const h1 = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e";
    try htest.assertEqualHash(Sha512, h1, "");

    const h2 = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f";
    try htest.assertEqualHash(Sha512, h2, "abc");

    const h3 = "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909";
    try htest.assertEqualHash(Sha512, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha512 streaming" {
    var h = Sha512.init(.{});
    var out: [64]u8 = undefined;

    const h1 = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e";
    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f";

    h = Sha512.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Sha512.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);
}

test "sha512 aligned final" {
    var block = [_]u8{0} ** Sha512.block_length;
    var out: [Sha512.digest_length]u8 = undefined;

    var h = Sha512.init(.{});
    h.update(&block);
    h.final(out[0..]);
}
