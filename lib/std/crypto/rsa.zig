const std = @import("std");
const der = @import("Certificate.zig").der;

const max_modulus_bits = 4096;
const Uint = std.crypto.ff.Uint(max_modulus_bits);
const Modulus = std.crypto.ff.Modulus(max_modulus_bits);
const Fe = Modulus.Fe;

pub const PssSignature = struct {
    pub fn fromBytes(comptime modulus_len: usize, msg: []const u8) [modulus_len]u8 {
        var result = [1]u8{0} ** modulus_len;
        std.mem.copyForwards(u8, &result, msg);
        return result;
    }

    pub fn verify(comptime modulus_len: usize, sig: [modulus_len]u8, msg: []const u8, public_key: PublicKey, comptime Hash: type) !void {
        const mod_bits = public_key.n.bits();
        const em_dec = try encrypt(modulus_len, sig, public_key);

        EMSA_PSS_VERIFY(msg, &em_dec, mod_bits - 1, Hash.digest_length, Hash) catch unreachable;
    }

    fn EMSA_PSS_VERIFY(msg: []const u8, em: []const u8, emBit: usize, sLen: usize, comptime Hash: type) !void {
        // 1.   If the length of M is greater than the input limitation for
        //      the hash function (2^61 - 1 octets for SHA-1), output
        //      "inconsistent" and stop.
        // All the cryptographic hash functions in the standard library have a limit of >= 2^61 - 1.
        // Even then, this check is only there for paranoia. In the context of TLS certifcates, emBit cannot exceed 4096.
        if (emBit >= 1 << 61) return error.InvalidSignature;

        // emLen = \ceil(emBits/8)
        const emLen = ((emBit - 1) / 8) + 1;
        std.debug.assert(emLen == em.len);

        // 2.   Let mHash = Hash(M), an octet string of length hLen.
        var mHash: [Hash.digest_length]u8 = undefined;
        Hash.hash(msg, &mHash, .{});

        // 3.   If emLen < hLen + sLen + 2, output "inconsistent" and stop.
        if (emLen < Hash.digest_length + sLen + 2) {
            return error.InvalidSignature;
        }

        // 4.   If the rightmost octet of EM does not have hexadecimal value
        //      0xbc, output "inconsistent" and stop.
        if (em[em.len - 1] != 0xbc) {
            return error.InvalidSignature;
        }

        // 5.   Let maskedDB be the leftmost emLen - hLen - 1 octets of EM,
        //      and let H be the next hLen octets.
        const maskedDB = em[0..(emLen - Hash.digest_length - 1)];
        const h = em[(emLen - Hash.digest_length - 1)..(emLen - 1)][0..Hash.digest_length];

        // 6.   If the leftmost 8emLen - emBits bits of the leftmost octet in
        //      maskedDB are not all equal to zero, output "inconsistent" and
        //      stop.
        const zero_bits = emLen * 8 - emBit;
        var mask: u8 = maskedDB[0];
        var i: usize = 0;
        while (i < 8 - zero_bits) : (i += 1) {
            mask = mask >> 1;
        }
        if (mask != 0) {
            return error.InvalidSignature;
        }

        // 7.   Let dbMask = MGF(H, emLen - hLen - 1).
        const mgf_len = emLen - Hash.digest_length - 1;
        var mgf_out_buf: [512]u8 = undefined;
        if (mgf_len > mgf_out_buf.len) { // Modulus > 4096 bits
            return error.InvalidSignature;
        }
        const mgf_out = mgf_out_buf[0 .. ((mgf_len - 1) / Hash.digest_length + 1) * Hash.digest_length];
        var dbMask = try MGF1(Hash, mgf_out, h, mgf_len);

        // 8.   Let DB = maskedDB \xor dbMask.
        i = 0;
        while (i < dbMask.len) : (i += 1) {
            dbMask[i] = maskedDB[i] ^ dbMask[i];
        }

        // 9.   Set the leftmost 8emLen - emBits bits of the leftmost octet
        //      in DB to zero.
        i = 0;
        mask = 0;
        while (i < 8 - zero_bits) : (i += 1) {
            mask = mask << 1;
            mask += 1;
        }
        dbMask[0] = dbMask[0] & mask;

        // 10.  If the emLen - hLen - sLen - 2 leftmost octets of DB are not
        //      zero or if the octet at position emLen - hLen - sLen - 1 (the
        //      leftmost position is "position 1") does not have hexadecimal
        //      value 0x01, output "inconsistent" and stop.
        if (dbMask[mgf_len - sLen - 2] != 0x00) {
            return error.InvalidSignature;
        }

        if (dbMask[mgf_len - sLen - 1] != 0x01) {
            return error.InvalidSignature;
        }

        // 11.  Let salt be the last sLen octets of DB.
        const salt = dbMask[(mgf_len - sLen)..];

        // 12.  Let
        //         M' = (0x)00 00 00 00 00 00 00 00 || mHash || salt ;
        //      M' is an octet string of length 8 + hLen + sLen with eight
        //      initial zero octets.
        if (sLen > Hash.digest_length) { // A seed larger than the hash length would be useless
            return error.InvalidSignature;
        }
        var m_p_buf: [8 + Hash.digest_length + Hash.digest_length]u8 = undefined;
        var m_p = m_p_buf[0 .. 8 + Hash.digest_length + sLen];
        std.mem.copyForwards(u8, m_p, &([_]u8{0} ** 8));
        std.mem.copyForwards(u8, m_p[8..], &mHash);
        std.mem.copyForwards(u8, m_p[(8 + Hash.digest_length)..], salt);

        // 13.  Let H' = Hash(M'), an octet string of length hLen.
        var h_p: [Hash.digest_length]u8 = undefined;
        Hash.hash(m_p, &h_p, .{});

        // 14.  If H = H', output "consistent".  Otherwise, output
        //      "inconsistent".
        if (!std.mem.eql(u8, h, &h_p)) {
            return error.InvalidSignature;
        }
    }

    fn MGF1(comptime Hash: type, out: []u8, seed: *const [Hash.digest_length]u8, len: usize) ![]u8 {
        var counter: usize = 0;
        var idx: usize = 0;
        var c: [4]u8 = undefined;
        var hash: [Hash.digest_length + c.len]u8 = undefined;
        @memcpy(hash[0..Hash.digest_length], seed);
        var hashed: [Hash.digest_length]u8 = undefined;

        while (idx < len) {
            c[0] = @as(u8, @intCast((counter >> 24) & 0xFF));
            c[1] = @as(u8, @intCast((counter >> 16) & 0xFF));
            c[2] = @as(u8, @intCast((counter >> 8) & 0xFF));
            c[3] = @as(u8, @intCast(counter & 0xFF));

            std.mem.copyForwards(u8, hash[seed.len..], &c);
            Hash.hash(&hash, &hashed, .{});

            std.mem.copyForwards(u8, out[idx..], &hashed);
            idx += hashed.len;

            counter += 1;
        }

        return out[0..len];
    }
};

pub const PublicKey = struct {
    n: Modulus,
    e: Fe,

    pub fn fromBytes(pub_bytes: []const u8, modulus_bytes: []const u8) !PublicKey {
        // Reject modulus below 512 bits.
        // 512-bit RSA was factored in 1999, so this limit barely means anything,
        // but establish some limit now to ratchet in what we can.
        const _n = Modulus.fromBytes(modulus_bytes, .big) catch return error.CertificatePublicKeyInvalid;
        if (_n.bits() < 512) return error.CertificatePublicKeyInvalid;

        // Exponent must be odd and greater than 2.
        // Also, it must be less than 2^32 to mitigate DoS attacks.
        // Windows CryptoAPI doesn't support values larger than 32 bits [1], so it is
        // unlikely that exponents larger than 32 bits are being used for anything
        // Windows commonly does.
        // [1] https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/ns-wincrypt-rsapubkey
        if (pub_bytes.len > 4) return error.CertificatePublicKeyInvalid;
        const _e = Fe.fromBytes(_n, pub_bytes, .big) catch return error.CertificatePublicKeyInvalid;
        if (!_e.isOdd()) return error.CertificatePublicKeyInvalid;
        const e_v = _e.toPrimitive(u32) catch return error.CertificatePublicKeyInvalid;
        if (e_v < 2) return error.CertificatePublicKeyInvalid;

        return .{
            .n = _n,
            .e = _e,
        };
    }

    pub fn parseDer(pub_key: []const u8) !struct { modulus: []const u8, exponent: []const u8 } {
        const pub_key_seq = try der.Element.parse(pub_key, 0);
        if (pub_key_seq.identifier.tag != .sequence) return error.CertificateFieldHasWrongDataType;
        const modulus_elem = try der.Element.parse(pub_key, pub_key_seq.slice.start);
        if (modulus_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
        const exponent_elem = try der.Element.parse(pub_key, modulus_elem.slice.end);
        if (exponent_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
        // Skip over meaningless zeroes in the modulus.
        const modulus_raw = pub_key[modulus_elem.slice.start..modulus_elem.slice.end];
        const modulus_offset = for (modulus_raw, 0..) |byte, i| {
            if (byte != 0) break i;
        } else modulus_raw.len;
        return .{
            .modulus = modulus_raw[modulus_offset..],
            .exponent = pub_key[exponent_elem.slice.start..exponent_elem.slice.end],
        };
    }
};

fn encrypt(comptime modulus_len: usize, msg: [modulus_len]u8, public_key: PublicKey) ![modulus_len]u8 {
    const m = Fe.fromBytes(public_key.n, &msg, .big) catch return error.MessageTooLong;
    const e = public_key.n.powPublic(m, public_key.e) catch unreachable;
    var res: [modulus_len]u8 = undefined;
    e.toBytes(&res, .big) catch unreachable;
    return res;
}

/// Version 1.5
pub const PkcsSignature = struct {
    pub fn verify(comptime modulus_len: usize, sig: [modulus_len]u8, msg: []const u8, public_key: PublicKey, comptime Hash: type) !void {
        const hash = std.crypto.hash;
        const hash_der = switch (Hash) {
            hash.Sha1 => [_]u8{
                0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e,
                0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14,
            },
            hash.sha2.Sha224 => [_]u8{
                0x30, 0x2d, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x04, 0x05,
                0x00, 0x04, 0x1c,
            },
            hash.sha2.Sha256 => [_]u8{
                0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
                0x00, 0x04, 0x20,
            },
            hash.sha2.Sha384 => [_]u8{
                0x30, 0x41, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02, 0x05,
                0x00, 0x04, 0x30,
            },
            hash.sha2.Sha512 => [_]u8{
                0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05,
                0x00, 0x04, 0x40,
            },
            else => @compileError("unreachable"),
        };

        var msg_hashed: [Hash.digest_length]u8 = undefined;
        Hash.hash(msg, &msg_hashed, .{});

        const ps_len = modulus_len - (hash_der.len + msg_hashed.len) - 3;
        const em: [modulus_len]u8 =
            [2]u8{ 0, 1 } ++
            ([1]u8{0xff} ** ps_len) ++
            [1]u8{0} ++
            hash_der ++
            msg_hashed;

        const em_dec = encrypt(modulus_len, sig[0..modulus_len].*, public_key) catch |err| switch (err) {
            error.MessageTooLong => unreachable,
        };

        if (!std.mem.eql(u8, &em, &em_dec)) {
            return error.CertificateSignatureInvalid;
        }
    }
};
