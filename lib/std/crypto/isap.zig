const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const testing = std.testing;

/// ISAPv2 is an authenticated encryption system hardened against side channels and fault attacks.
/// https://csrc.nist.gov/CSRC/media/Projects/lightweight-cryptography/documents/round-2/spec-doc-rnd2/isap-spec-round2.pdf
///
/// Note that ISAP is not suitable for high-performance applications.
///
/// However:
/// - if allowing physical access to the device is part of your threat model,
/// - or if you need resistance against microcode/hardware-level side channel attacks,
/// - or if software-induced fault attacks such as rowhammer are a concern,
///
/// then you may consider ISAP for highly sensitive data.
pub const IsapA128A = struct {
    pub const key_length = 16;
    pub const nonce_length = 16;
    pub const tag_length: usize = 16;

    const iv1 = [_]u8{ 0x01, 0x80, 0x40, 0x01, 0x0c, 0x01, 0x06, 0x0c };
    const iv2 = [_]u8{ 0x02, 0x80, 0x40, 0x01, 0x0c, 0x01, 0x06, 0x0c };
    const iv3 = [_]u8{ 0x03, 0x80, 0x40, 0x01, 0x0c, 0x01, 0x06, 0x0c };

    const Block = [5]u64;

    block: Block,

    fn round(isap: *IsapA128A, rk: u64) void {
        var x = &isap.block;
        x[2] ^= rk;
        x[0] ^= x[4];
        x[4] ^= x[3];
        x[2] ^= x[1];
        var t = x.*;
        x[0] = t[0] ^ ((~t[1]) & t[2]);
        x[2] = t[2] ^ ((~t[3]) & t[4]);
        x[4] = t[4] ^ ((~t[0]) & t[1]);
        x[1] = t[1] ^ ((~t[2]) & t[3]);
        x[3] = t[3] ^ ((~t[4]) & t[0]);
        x[1] ^= x[0];
        t[1] = x[1];
        x[1] = math.rotr(u64, x[1], 39);
        x[3] ^= x[2];
        t[2] = x[2];
        x[2] = math.rotr(u64, x[2], 1);
        t[4] = x[4];
        t[2] ^= x[2];
        x[2] = math.rotr(u64, x[2], 5);
        t[3] = x[3];
        t[1] ^= x[1];
        x[3] = math.rotr(u64, x[3], 10);
        x[0] ^= x[4];
        x[4] = math.rotr(u64, x[4], 7);
        t[3] ^= x[3];
        x[2] ^= t[2];
        x[1] = math.rotr(u64, x[1], 22);
        t[0] = x[0];
        x[2] = ~x[2];
        x[3] = math.rotr(u64, x[3], 7);
        t[4] ^= x[4];
        x[4] = math.rotr(u64, x[4], 34);
        x[3] ^= t[3];
        x[1] ^= t[1];
        x[0] = math.rotr(u64, x[0], 19);
        x[4] ^= t[4];
        t[0] ^= x[0];
        x[0] = math.rotr(u64, x[0], 9);
        x[0] ^= t[0];
    }

    fn p12(isap: *IsapA128A) void {
        const rks = [12]u64{ 0xf0, 0xe1, 0xd2, 0xc3, 0xb4, 0xa5, 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b };
        inline for (rks) |rk| {
            isap.round(rk);
        }
    }

    fn p6(isap: *IsapA128A) void {
        const rks = [6]u64{ 0x96, 0x87, 0x78, 0x69, 0x5a, 0x4b };
        inline for (rks) |rk| {
            isap.round(rk);
        }
    }

    fn p1(isap: *IsapA128A) void {
        isap.round(0x4b);
    }

    fn absorb(isap: *IsapA128A, m: []const u8) void {
        var block = &isap.block;
        var i: usize = 0;
        while (true) : (i += 8) {
            const left = m.len - i;
            if (left >= 8) {
                block[0] ^= mem.readIntBig(u64, m[i..][0..8]);
                isap.p12();
                if (left == 8) {
                    block[0] ^= 0x8000000000000000;
                    isap.p12();
                    break;
                }
            } else {
                var padded = [_]u8{0} ** 8;
                mem.copy(u8, padded[0..left], m[i..]);
                padded[left] = 0x80;
                block[0] ^= mem.readIntBig(u64, padded[0..]);
                isap.p12();
                break;
            }
        }
    }

    fn trickle(k: [16]u8, iv: [8]u8, y: []const u8, comptime out_len: usize) [out_len]u8 {
        var isap = IsapA128A{
            .block = Block{
                mem.readIntBig(u64, k[0..8]),
                mem.readIntBig(u64, k[8..16]),
                mem.readIntBig(u64, iv[0..8]),
                0,
                0,
            },
        };
        isap.p12();

        var i: usize = 0;
        while (i < y.len * 8 - 1) : (i += 1) {
            const cur_byte_pos = i / 8;
            const cur_bit_pos = @truncate(u3, 7 - (i % 8));
            const cur_bit = @as(u64, ((y[cur_byte_pos] >> cur_bit_pos) & 1) << 7);
            isap.block[0] ^= cur_bit << 56;
            isap.p1();
        }
        const cur_bit = @as(u64, (y[y.len - 1] & 1) << 7);
        isap.block[0] ^= cur_bit << 56;
        isap.p12();

        var out: [out_len]u8 = undefined;
        var j: usize = 0;
        while (j < out_len) : (j += 8) {
            mem.writeIntBig(u64, out[j..][0..8], isap.block[j / 8]);
        }
        std.crypto.utils.secureZero(u64, &isap.block);
        return out;
    }

    fn mac(c: []const u8, ad: []const u8, npub: [16]u8, key: [16]u8) [16]u8 {
        var isap = IsapA128A{
            .block = Block{
                mem.readIntBig(u64, npub[0..8]),
                mem.readIntBig(u64, npub[8..16]),
                mem.readIntBig(u64, iv1[0..]),
                0,
                0,
            },
        };
        isap.p12();

        isap.absorb(ad);
        isap.block[4] ^= 1;
        isap.absorb(c);

        var y: [16]u8 = undefined;
        mem.writeIntBig(u64, y[0..8], isap.block[0]);
        mem.writeIntBig(u64, y[8..16], isap.block[1]);
        const nb = trickle(key, iv2, y[0..], 16);
        isap.block[0] = mem.readIntBig(u64, nb[0..8]);
        isap.block[1] = mem.readIntBig(u64, nb[8..16]);
        isap.p12();

        var tag: [16]u8 = undefined;
        mem.writeIntBig(u64, tag[0..8], isap.block[0]);
        mem.writeIntBig(u64, tag[8..16], isap.block[1]);
        std.crypto.utils.secureZero(u64, &isap.block);
        return tag;
    }

    fn xor(out: []u8, in: []const u8, npub: [16]u8, key: [16]u8) void {
        debug.assert(in.len == out.len);

        const nb = trickle(key, iv3, npub[0..], 24);
        var isap = IsapA128A{
            .block = Block{
                mem.readIntBig(u64, nb[0..8]),
                mem.readIntBig(u64, nb[8..16]),
                mem.readIntBig(u64, nb[16..24]),
                mem.readIntBig(u64, npub[0..8]),
                mem.readIntBig(u64, npub[8..16]),
            },
        };
        isap.p6();

        var i: usize = 0;
        while (true) : (i += 8) {
            const left = in.len - i;
            if (left >= 8) {
                mem.writeIntNative(u64, out[i..][0..8], mem.bigToNative(u64, isap.block[0]) ^ mem.readIntNative(u64, in[i..][0..8]));
                if (left == 8) {
                    break;
                }
                isap.p6();
            } else {
                var pad = [_]u8{0} ** 8;
                mem.copy(u8, pad[0..left], in[i..][0..left]);
                mem.writeIntNative(u64, pad[i..][0..8], mem.bigToNative(u64, isap.block[0]) ^ mem.readIntNative(u64, pad[i..][0..8]));
                mem.copy(u8, out[i..][0..left], pad[0..left]);
                break;
            }
        }
        std.crypto.utils.secureZero(u64, &isap.block);
    }

    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
        xor(c, m, npub, key);
        tag.* = mac(c, ad, npub, key);
    }

    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) !void {
        var computed_tag = mac(c, ad, npub, key);
        var acc: u8 = 0;
        for (computed_tag) |_, j| {
            acc |= (computed_tag[j] ^ tag[j]);
        }
        std.crypto.utils.secureZero(u8, &computed_tag);
        if (acc != 0) {
            return error.AuthenticationFailed;
        }
        xor(m, c, npub, key);
    }
};

test "ISAP" {
    const k = [_]u8{1} ** 16;
    const n = [_]u8{2} ** 16;
    var tag: [16]u8 = undefined;
    const ad = "ad";
    var msg = "test";
    var c: [msg.len]u8 = undefined;
    IsapA128A.encrypt(c[0..], &tag, msg[0..], ad, n, k);
    testing.expect(mem.eql(u8, &[_]u8{ 0x8f, 0x68, 0x03, 0x8d }, c[0..]));
    testing.expect(mem.eql(u8, &[_]u8{ 0x6c, 0x25, 0xe8, 0xe2, 0xe1, 0x1f, 0x38, 0xe9, 0x80, 0x75, 0xde, 0xd5, 0x2d, 0xb2, 0x31, 0x82 }, tag[0..]));
    try IsapA128A.decrypt(c[0..], c[0..], tag, ad, n, k);
    testing.expect(mem.eql(u8, msg, c[0..]));
}
