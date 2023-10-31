const std = @import("std");
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const testing = std.testing;
const Ascon = crypto.core.Ascon(.big);
const AuthenticationError = crypto.errors.AuthenticationError;

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

    st: Ascon,

    fn absorb(isap: *IsapA128A, m: []const u8) void {
        var i: usize = 0;
        while (true) : (i += 8) {
            const left = m.len - i;
            if (left >= 8) {
                isap.st.addBytes(m[i..][0..8]);
                isap.st.permute();
                if (left == 8) {
                    isap.st.addByte(0x80, 0);
                    isap.st.permute();
                    break;
                }
            } else {
                var padded = [_]u8{0} ** 8;
                @memcpy(padded[0..left], m[i..]);
                padded[left] = 0x80;
                isap.st.addBytes(&padded);
                isap.st.permute();
                break;
            }
        }
    }

    fn trickle(k: [16]u8, iv: [8]u8, y: []const u8, comptime out_len: usize) [out_len]u8 {
        var isap = IsapA128A{
            .st = Ascon.initFromWords(.{
                mem.readInt(u64, k[0..8], .big),
                mem.readInt(u64, k[8..16], .big),
                mem.readInt(u64, iv[0..8], .big),
                0,
                0,
            }),
        };
        isap.st.permute();

        var i: usize = 0;
        while (i < y.len * 8 - 1) : (i += 1) {
            const cur_byte_pos = i / 8;
            const cur_bit_pos: u3 = @truncate(7 - (i % 8));
            const cur_bit = ((y[cur_byte_pos] >> cur_bit_pos) & 1) << 7;
            isap.st.addByte(cur_bit, 0);
            isap.st.permuteR(1);
        }
        const cur_bit = (y[y.len - 1] & 1) << 7;
        isap.st.addByte(cur_bit, 0);
        isap.st.permute();

        var out: [out_len]u8 = undefined;
        isap.st.extractBytes(&out);
        isap.st.secureZero();
        return out;
    }

    fn mac(c: []const u8, ad: []const u8, npub: [16]u8, key: [16]u8) [16]u8 {
        var isap = IsapA128A{
            .st = Ascon.initFromWords(.{
                mem.readInt(u64, npub[0..8], .big),
                mem.readInt(u64, npub[8..16], .big),
                mem.readInt(u64, iv1[0..], .big),
                0,
                0,
            }),
        };
        isap.st.permute();

        isap.absorb(ad);
        isap.st.addByte(1, Ascon.block_bytes - 1);
        isap.absorb(c);

        var y: [16]u8 = undefined;
        isap.st.extractBytes(&y);
        const nb = trickle(key, iv2, y[0..], 16);
        isap.st.setBytes(&nb);
        isap.st.permute();

        var tag: [16]u8 = undefined;
        isap.st.extractBytes(&tag);
        isap.st.secureZero();
        return tag;
    }

    fn xor(out: []u8, in: []const u8, npub: [16]u8, key: [16]u8) void {
        debug.assert(in.len == out.len);

        const nb = trickle(key, iv3, npub[0..], 24);
        var isap = IsapA128A{
            .st = Ascon.initFromWords(.{
                mem.readInt(u64, nb[0..8], .big),
                mem.readInt(u64, nb[8..16], .big),
                mem.readInt(u64, nb[16..24], .big),
                mem.readInt(u64, npub[0..8], .big),
                mem.readInt(u64, npub[8..16], .big),
            }),
        };
        isap.st.permuteR(6);

        var i: usize = 0;
        while (true) : (i += 8) {
            const left = in.len - i;
            if (left >= 8) {
                isap.st.xorBytes(out[i..][0..8], in[i..][0..8]);
                if (left == 8) {
                    break;
                }
                isap.st.permuteR(6);
            } else {
                isap.st.xorBytes(out[i..], in[i..]);
                break;
            }
        }
        isap.st.secureZero();
    }

    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
        xor(c, m, npub, key);
        tag.* = mac(c, ad, npub, key);
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
    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) AuthenticationError!void {
        var computed_tag = mac(c, ad, npub, key);
        const verify = crypto.utils.timingSafeEql([tag_length]u8, computed_tag, tag);
        if (!verify) {
            crypto.utils.secureZero(u8, &computed_tag);
            @memset(m, undefined);
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
    try testing.expect(mem.eql(u8, &[_]u8{ 0x8f, 0x68, 0x03, 0x8d }, c[0..]));
    try testing.expect(mem.eql(u8, &[_]u8{ 0x6c, 0x25, 0xe8, 0xe2, 0xe1, 0x1f, 0x38, 0xe9, 0x80, 0x75, 0xde, 0xd5, 0x2d, 0xb2, 0x31, 0x82 }, tag[0..]));
    try IsapA128A.decrypt(c[0..], c[0..], tag, ad, n, k);
    try testing.expect(mem.eql(u8, msg, c[0..]));
}
