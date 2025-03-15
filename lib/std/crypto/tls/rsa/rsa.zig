//! RFC8017: Public Key Cryptography Standards #1 v2.2 (PKCS1)
const std = @import("std");
const der = @import("der.zig");
const ff = std.crypto.ff;

pub const max_modulus_bits = 4096;
const max_modulus_len = max_modulus_bits / 8;

const Modulus = std.crypto.ff.Modulus(max_modulus_bits);
const Fe = Modulus.Fe;

pub const ValueError = error{
    Modulus,
    Exponent,
};

pub const PublicKey = struct {
    /// `n`
    modulus: Modulus,
    /// `e`
    public_exponent: Fe,

    pub const FromBytesError = ValueError || ff.OverflowError || ff.FieldElementError || ff.InvalidModulusError || error{InsecureBitCount};

    pub fn fromBytes(mod: []const u8, exp: []const u8) FromBytesError!PublicKey {
        const modulus = try Modulus.fromBytes(mod, .big);
        if (modulus.bits() <= 512) return error.InsecureBitCount;
        const public_exponent = try Fe.fromBytes(modulus, exp, .big);

        if (std.debug.runtime_safety) {
            // > the RSA public exponent e is an integer between 3 and n - 1 satisfying
            // > GCD(e,\lambda(n)) = 1, where \lambda(n) = LCM(r_1 - 1, ..., r_u - 1)
            const e_v = public_exponent.toPrimitive(u32) catch return error.Exponent;
            if (!public_exponent.isOdd()) return error.Exponent;
            if (e_v < 3) return error.Exponent;
            if (modulus.v.compare(public_exponent.v) == .lt) return error.Exponent;
        }

        return .{ .modulus = modulus, .public_exponent = public_exponent };
    }

    pub fn fromDer(bytes: []const u8) (der.Parser.Error || FromBytesError)!PublicKey {
        var parser = der.Parser{ .bytes = bytes };

        const seq = try parser.expectSequence();
        defer parser.seek(seq.slice.end);

        const modulus = try parser.expectPrimitive(.integer);
        const pub_exp = try parser.expectPrimitive(.integer);

        try parser.expectEnd(seq.slice.end);
        try parser.expectEnd(bytes.len);

        return try fromBytes(parser.view(modulus), parser.view(pub_exp));
    }

    /// Deprecated.
    ///
    /// Encrypt a short message using RSAES-PKCS1-v1_5.
    /// The use of this scheme for encrypting an arbitrary message, as opposed to a
    /// randomly generated key, is NOT RECOMMENDED.
    pub fn encryptPkcsv1_5(pk: PublicKey, msg: []const u8, out: []u8) ![]const u8 {
        // align variable names with spec
        const k = byteLen(pk.modulus.bits());
        if (out.len < k) return error.BufferTooSmall;
        if (msg.len > k - 11) return error.MessageTooLong;

        // EM = 0x00 || 0x02 || PS || 0x00 || M.
        var em = out[0..k];
        em[0] = 0;
        em[1] = 2;

        const ps = em[2..][0 .. k - msg.len - 3];
        // Section: 7.2.1
        // PS consists of pseudo-randomly generated nonzero octets.
        for (ps) |*v| {
            v.* = std.crypto.random.uintLessThan(u8, 0xff) + 1;
        }

        em[em.len - msg.len - 1] = 0;
        @memcpy(em[em.len - msg.len ..][0..msg.len], msg);

        const m = try Fe.fromBytes(pk.modulus, em, .big);
        const e = try pk.modulus.powPublic(m, pk.public_exponent);
        try e.toBytes(em, .big);
        return em;
    }

    /// Encrypt a short message using Optimal Asymmetric Encryption Padding (RSAES-OAEP).
    pub fn encryptOaep(
        pk: PublicKey,
        comptime Hash: type,
        msg: []const u8,
        label: []const u8,
        out: []u8,
    ) ![]const u8 {
        // align variable names with spec
        const k = byteLen(pk.modulus.bits());
        if (out.len < k) return error.BufferTooSmall;

        if (msg.len > k - 2 * Hash.digest_length - 2) return error.MessageTooLong;

        // EM = 0x00 || maskedSeed || maskedDB.
        var em = out[0..k];
        em[0] = 0;
        const seed = em[1..][0..Hash.digest_length];
        std.crypto.random.bytes(seed);

        // DB = lHash || PS || 0x01 || M.
        var db = em[1 + seed.len ..];
        const lHash = labelHash(Hash, label);
        @memcpy(db[0..lHash.len], &lHash);
        @memset(db[lHash.len .. db.len - msg.len - 2], 0);
        db[db.len - msg.len - 1] = 1;
        @memcpy(db[db.len - msg.len ..], msg);

        var mgf_buf: [max_modulus_len]u8 = undefined;

        const db_mask = mgf1(Hash, seed, mgf_buf[0..db.len]);
        for (db, db_mask) |*v, m| v.* ^= m;

        const seed_mask = mgf1(Hash, db, mgf_buf[0..seed.len]);
        for (seed, seed_mask) |*v, m| v.* ^= m;

        const m = try Fe.fromBytes(pk.modulus, em, .big);
        const e = try pk.modulus.powPublic(m, pk.public_exponent);
        try e.toBytes(em, .big);
        return em;
    }
};

pub fn byteLen(bits: usize) usize {
    return std.math.divCeil(usize, bits, 8) catch unreachable;
}

pub const SecretKey = struct {
    /// `d`
    private_exponent: Fe,

    pub const FromBytesError = ValueError || ff.OverflowError || ff.FieldElementError;

    pub fn fromBytes(n: Modulus, exp: []const u8) FromBytesError!SecretKey {
        const d = try Fe.fromBytes(n, exp, .big);
        if (std.debug.runtime_safety) {
            // > The RSA private exponent d is a positive integer less than n
            // > satisfying e * d == 1 (mod \lambda(n)),
            if (!d.isOdd()) return error.Exponent;
            if (d.v.compare(n.v) != .lt) return error.Exponent;
        }

        return .{ .private_exponent = d };
    }
};

pub const KeyPair = struct {
    public: PublicKey,
    secret: SecretKey,

    pub const FromDerError = PublicKey.FromBytesError || SecretKey.FromBytesError || der.Parser.Error || error{ KeyMismatch, InvalidVersion };

    pub fn fromDer(bytes: []const u8) FromDerError!KeyPair {
        var parser = der.Parser{ .bytes = bytes };
        const seq = try parser.expectSequence();
        const version = try parser.expectInt(u8);

        const mod = try parser.expectPrimitive(.integer);
        const pub_exp = try parser.expectPrimitive(.integer);
        const sec_exp = try parser.expectPrimitive(.integer);

        const public = try PublicKey.fromBytes(parser.view(mod), parser.view(pub_exp));
        const secret = try SecretKey.fromBytes(public.modulus, parser.view(sec_exp));

        const prime1 = try parser.expectPrimitive(.integer);
        const prime2 = try parser.expectPrimitive(.integer);
        const exp1 = try parser.expectPrimitive(.integer);
        const exp2 = try parser.expectPrimitive(.integer);
        const coeff = try parser.expectPrimitive(.integer);
        _ = .{ exp1, exp2, coeff };

        switch (version) {
            0 => {},
            1 => {
                _ = try parser.expectSequenceOf();
                while (!parser.eof()) {
                    _ = try parser.expectSequence();
                    const ri = try parser.expectPrimitive(.integer);
                    const di = try parser.expectPrimitive(.integer);
                    const ti = try parser.expectPrimitive(.integer);
                    _ = .{ ri, di, ti };
                }
            },
            else => return error.InvalidVersion,
        }

        try parser.expectEnd(seq.slice.end);
        try parser.expectEnd(bytes.len);

        if (std.debug.runtime_safety) {
            const p = try Fe.fromBytes(public.modulus, parser.view(prime1), .big);
            const q = try Fe.fromBytes(public.modulus, parser.view(prime2), .big);

            // check that n = p * q
            const expected_zero = public.modulus.mul(p, q);
            if (!expected_zero.isZero()) return error.KeyMismatch;

            // TODO: check that d * e is one mod p-1 and mod q-1. Note d and e were bound
            // const de = secret.private_exponent.mul(public.public_exponent);
            // const one = public.modulus.one();

            // if (public.modulus.mul(de, p).compare(one) != .eq) return error.KeyMismatch;
            // if (public.modulus.mul(de, q).compare(one) != .eq) return error.KeyMismatch;
        }

        return .{ .public = public, .secret = secret };
    }

    /// Deprecated.
    pub fn signPkcsv1_5(kp: KeyPair, comptime Hash: type, msg: []const u8, out: []u8) !PKCS1v1_5(Hash).Signature {
        var st = try signerPkcsv1_5(kp, Hash);
        st.update(msg);
        return try st.finalize(out);
    }

    /// Deprecated.
    pub fn signerPkcsv1_5(kp: KeyPair, comptime Hash: type) !PKCS1v1_5(Hash).Signer {
        return PKCS1v1_5(Hash).Signer.init(kp);
    }

    /// Deprecated.
    pub fn decryptPkcsv1_5(kp: KeyPair, ciphertext: []const u8, out: []u8) ![]const u8 {
        const k = byteLen(kp.public.modulus.bits());
        if (out.len < k) return error.BufferTooSmall;

        const em = out[0..k];

        const m = try Fe.fromBytes(kp.public.modulus, ciphertext, .big);
        const e = try kp.public.modulus.pow(m, kp.secret.private_exponent);
        try e.toBytes(em, .big);

        // Care shall be taken to ensure that an opponent cannot
        // distinguish these error conditions, whether by error
        // message or timing.
        const msg_start = ct.lastIndexOfScalar(em, 0) orelse em.len;
        const ps_len = em.len - msg_start;
        if (ct.@"or"(em[0] != 0, ct.@"or"(em[1] != 2, ps_len < 8))) {
            return error.Inconsistent;
        }

        return em[msg_start + 1 ..];
    }

    pub fn signOaep(
        kp: KeyPair,
        comptime Hash: type,
        msg: []const u8,
        salt: ?[]const u8,
        out: []u8,
    ) !Pss(Hash).Signature {
        var st = try signerOaep(kp, Hash, salt);
        st.update(msg);
        return try st.finalize(out);
    }

    /// Salt must outlive returned `PSS.Signer`.
    pub fn signerOaep(kp: KeyPair, comptime Hash: type, salt: ?[]const u8) !Pss(Hash).Signer {
        return Pss(Hash).Signer.init(kp, salt);
    }

    pub fn decryptOaep(
        kp: KeyPair,
        comptime Hash: type,
        ciphertext: []const u8,
        label: []const u8,
        out: []u8,
    ) ![]u8 {
        // align variable names with spec
        const k = byteLen(kp.public.modulus.bits());
        if (out.len < k) return error.BufferTooSmall;

        const mod = try Fe.fromBytes(kp.public.modulus, ciphertext, .big);
        const exp = kp.public.modulus.pow(mod, kp.secret.private_exponent) catch unreachable;
        const em = out[0..k];
        try exp.toBytes(em, .big);

        const y = em[0];
        const seed = em[1..][0..Hash.digest_length];
        const db = em[1 + Hash.digest_length ..];

        var mgf_buf: [max_modulus_len]u8 = undefined;

        const seed_mask = mgf1(Hash, db, mgf_buf[0..seed.len]);
        for (seed, seed_mask) |*v, m| v.* ^= m;

        const db_mask = mgf1(Hash, seed, mgf_buf[0..db.len]);
        for (db, db_mask) |*v, m| v.* ^= m;

        const expected_hash = labelHash(Hash, label);
        const actual_hash = db[0..expected_hash.len];

        // Care shall be taken to ensure that an opponent cannot
        // distinguish these error conditions, whether by error
        // message or timing.
        const msg_start = ct.indexOfScalarPos(em, expected_hash.len + 1, 1) orelse 0;
        if (ct.@"or"(y != 0, ct.@"or"(msg_start == 0, !ct.memEql(&expected_hash, actual_hash)))) {
            return error.Inconsistent;
        }

        return em[msg_start + 1 ..];
    }

    /// Encrypt short plaintext with secret key.
    pub fn encrypt(kp: KeyPair, plaintext: []const u8, out: []u8) !void {
        const n = kp.public.modulus;
        const k = byteLen(n.bits());
        if (plaintext.len > k) return error.MessageTooLong;

        const msg_as_int = try Fe.fromBytes(n, plaintext, .big);
        const enc_as_int = try n.pow(msg_as_int, kp.secret.private_exponent);
        try enc_as_int.toBytes(out, .big);
    }
};

/// Deprecated.
///
/// Signature Scheme with Appendix v1.5 (RSASSA-PKCS1-v1_5)
///
/// This standard has been superceded by PSS which is formally proven secure
/// and has fewer footguns.
pub fn PKCS1v1_5(comptime Hash: type) type {
    return struct {
        const PkcsT = @This();
        pub const Signature = struct {
            bytes: []const u8,

            const Self = @This();

            pub fn verifier(self: Self, public_key: PublicKey) !Verifier {
                return Verifier.init(self, public_key);
            }

            pub fn verify(self: Self, msg: []const u8, public_key: PublicKey) !void {
                var st = Verifier.init(self, public_key);
                st.update(msg);
                return st.verify();
            }
        };

        pub const Signer = struct {
            h: Hash,
            key_pair: KeyPair,

            fn init(key_pair: KeyPair) Signer {
                return .{
                    .h = Hash.init(.{}),
                    .key_pair = key_pair,
                };
            }

            pub fn update(self: *Signer, data: []const u8) void {
                self.h.update(data);
            }

            pub fn finalize(self: *Signer, out: []u8) !PkcsT.Signature {
                const k = byteLen(self.key_pair.public.modulus.bits());
                if (out.len < k) return error.BufferTooSmall;

                var hash: [Hash.digest_length]u8 = undefined;
                self.h.final(&hash);

                const em = try emsaEncode(hash, out[0..k]);
                try self.key_pair.encrypt(em, em);
                return .{ .bytes = em };
            }
        };

        pub const Verifier = struct {
            h: Hash,
            sig: PkcsT.Signature,
            public_key: PublicKey,

            fn init(sig: PkcsT.Signature, public_key: PublicKey) Verifier {
                return Verifier{
                    .h = Hash.init(.{}),
                    .sig = sig,
                    .public_key = public_key,
                };
            }

            pub fn update(self: *Verifier, data: []const u8) void {
                self.h.update(data);
            }

            pub fn verify(self: *Verifier) !void {
                const pk = self.public_key;
                const s = try Fe.fromBytes(pk.modulus, self.sig.bytes, .big);
                const emm = try pk.modulus.powPublic(s, pk.public_exponent);

                var em_buf: [max_modulus_len]u8 = undefined;
                const em = em_buf[0..byteLen(pk.modulus.bits())];
                try emm.toBytes(em, .big);

                var hash: [Hash.digest_length]u8 = undefined;
                self.h.final(&hash);

                // TODO: compare hash values instead of emsa values
                const expected = try emsaEncode(hash, em);

                if (!std.mem.eql(u8, expected, em)) return error.Inconsistent;
            }
        };

        /// PKCS Encrypted Message Signature Appendix
        fn emsaEncode(hash: [Hash.digest_length]u8, out: []u8) ![]u8 {
            const digest_header = comptime digestHeader();
            const tLen = digest_header.len + Hash.digest_length;
            const emLen = out.len;
            if (emLen < tLen + 11) return error.ModulusTooShort;
            if (out.len < emLen) return error.BufferTooSmall;

            var res = out[0..emLen];
            res[0] = 0;
            res[1] = 1;
            const padding_len = emLen - tLen - 3;
            @memset(res[2..][0..padding_len], 0xff);
            res[2 + padding_len] = 0;
            @memcpy(res[2 + padding_len + 1 ..][0..digest_header.len], digest_header);
            @memcpy(res[res.len - hash.len ..], &hash);

            return res;
        }

        /// DER encoded header. Sequence of digest algo + digest.
        /// TODO: use a DER encoder instead
        fn digestHeader() []const u8 {
            const sha2 = std.crypto.hash.sha2;
            // Section 9.2 Notes 1.
            return switch (Hash) {
                std.crypto.hash.Sha1 => &hexToBytes(
                    \\30 21 30 09 06 05 2b 0e 03 02 1a 05 00 04 14
                ),
                sha2.Sha224 => &hexToBytes(
                    \\30 2d 30 0d 06 09 60 86 48 01 65 03 04 02 04
                    \\05 00 04 1c
                ),
                sha2.Sha256 => &hexToBytes(
                    \\30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00
                    \\04 20
                ),
                sha2.Sha384 => &hexToBytes(
                    \\30 41 30 0d 06 09 60 86 48 01 65 03 04 02 02 05 00
                    \\04 30
                ),
                sha2.Sha512 => &hexToBytes(
                    \\30 51 30 0d 06 09 60 86 48 01 65 03 04 02 03 05 00
                    \\04 40
                ),
                // sha2.Sha512224 => &hexToBytes(
                //     \\30 2d 30 0d 06 09 60 86 48 01 65 03 04 02 05
                //     \\05 00 04 1c
                // ),
                // sha2.Sha512256 => &hexToBytes(
                //     \\30 31 30 0d 06 09 60 86 48 01 65 03 04 02 06
                //     \\05 00 04 20
                // ),
                else => @compileError("unknown Hash " ++ @typeName(Hash)),
            };
        }
    };
}

/// Probabilistic Signature Scheme (RSASSA-PSS)
pub fn Pss(comptime Hash: type) type {
    // RFC 4055 S3.1
    const default_salt_len = Hash.digest_length;
    return struct {
        pub const Signature = struct {
            bytes: []const u8,

            const Self = @This();

            pub fn verifier(self: Self, public_key: PublicKey) !Verifier {
                return Verifier.init(self, public_key);
            }

            pub fn verify(self: Self, msg: []const u8, public_key: PublicKey, salt_len: ?usize) !void {
                var st = Verifier.init(self, public_key, salt_len orelse default_salt_len);
                st.update(msg);
                return st.verify();
            }
        };

        const PssT = @This();

        pub const Signer = struct {
            h: Hash,
            key_pair: KeyPair,
            salt: ?[]const u8,

            fn init(key_pair: KeyPair, salt: ?[]const u8) Signer {
                return .{
                    .h = Hash.init(.{}),
                    .key_pair = key_pair,
                    .salt = salt,
                };
            }

            pub fn update(self: *Signer, data: []const u8) void {
                self.h.update(data);
            }

            pub fn finalize(self: *Signer, out: []u8) !PssT.Signature {
                var hashed: [Hash.digest_length]u8 = undefined;
                self.h.final(&hashed);

                const salt = if (self.salt) |s| s else brk: {
                    var res: [default_salt_len]u8 = undefined;
                    std.crypto.random.bytes(&res);
                    break :brk &res;
                };

                const em_bits = self.key_pair.public.modulus.bits() - 1;
                const em = try emsaEncode(hashed, salt, em_bits, out);
                try self.key_pair.encrypt(em, em);
                return .{ .bytes = em };
            }
        };

        pub const Verifier = struct {
            h: Hash,
            sig: PssT.Signature,
            public_key: PublicKey,
            salt_len: usize,

            fn init(sig: PssT.Signature, public_key: PublicKey, salt_len: usize) Verifier {
                return Verifier{
                    .h = Hash.init(.{}),
                    .sig = sig,
                    .public_key = public_key,
                    .salt_len = salt_len,
                };
            }

            pub fn update(self: *Verifier, data: []const u8) void {
                self.h.update(data);
            }

            pub fn verify(self: *Verifier) !void {
                const pk = self.public_key;
                const s = try Fe.fromBytes(pk.modulus, self.sig.bytes, .big);
                const emm = try pk.modulus.powPublic(s, pk.public_exponent);

                var em_buf: [max_modulus_len]u8 = undefined;
                const em_bits = pk.modulus.bits() - 1;
                const em_len = std.math.divCeil(usize, em_bits, 8) catch unreachable;
                var em = em_buf[0..em_len];
                try emm.toBytes(em, .big);

                if (em.len < Hash.digest_length + self.salt_len + 2) return error.Inconsistent;
                if (em[em.len - 1] != 0xbc) return error.Inconsistent;

                const db = em[0 .. em.len - Hash.digest_length - 1];
                if (@clz(db[0]) < em.len * 8 - em_bits) return error.Inconsistent;

                const expected_hash = em[db.len..][0..Hash.digest_length];
                var mgf_buf: [max_modulus_len]u8 = undefined;
                const db_mask = mgf1(Hash, expected_hash, mgf_buf[0..db.len]);
                for (db, db_mask) |*v, m| v.* ^= m;

                for (1..db.len - self.salt_len - 1) |i| {
                    if (db[i] != 0) return error.Inconsistent;
                }
                if (db[db.len - self.salt_len - 1] != 1) return error.Inconsistent;
                const salt = db[db.len - self.salt_len ..];
                var mp_buf: [max_modulus_len]u8 = undefined;
                var mp = mp_buf[0 .. 8 + Hash.digest_length + self.salt_len];
                @memset(mp[0..8], 0);
                self.h.final(mp[8..][0..Hash.digest_length]);
                @memcpy(mp[8 + Hash.digest_length ..][0..salt.len], salt);

                var actual_hash: [Hash.digest_length]u8 = undefined;
                Hash.hash(mp, &actual_hash, .{});

                if (!std.mem.eql(u8, expected_hash, &actual_hash)) return error.Inconsistent;
            }
        };

        /// PSS Encrypted Message Signature Appendix
        fn emsaEncode(msg_hash: [Hash.digest_length]u8, salt: []const u8, em_bits: usize, out: []u8) ![]u8 {
            const em_len = std.math.divCeil(usize, em_bits, 8) catch unreachable;

            if (em_len < Hash.digest_length + salt.len + 2) return error.Encoding;

            // EM = maskedDB || H || 0xbc
            var em = out[0..em_len];
            em[em.len - 1] = 0xbc;

            var mp_buf: [max_modulus_len]u8 = undefined;
            // M' = (0x)00 00 00 00 00 00 00 00 || mHash || salt;
            const mp = mp_buf[0 .. 8 + Hash.digest_length + salt.len];
            @memset(mp[0..8], 0);
            @memcpy(mp[8..][0..Hash.digest_length], &msg_hash);
            @memcpy(mp[8 + Hash.digest_length ..][0..salt.len], salt);

            // H = Hash(M')
            const hash = em[em.len - 1 - Hash.digest_length ..][0..Hash.digest_length];
            Hash.hash(mp, hash, .{});

            // DB = PS || 0x01 || salt
            var db = em[0 .. em_len - Hash.digest_length - 1];
            @memset(db[0 .. db.len - salt.len - 1], 0);
            db[db.len - salt.len - 1] = 1;
            @memcpy(db[db.len - salt.len ..], salt);

            var mgf_buf: [max_modulus_len]u8 = undefined;
            const db_mask = mgf1(Hash, hash, mgf_buf[0..db.len]);
            for (db, db_mask) |*v, m| v.* ^= m;

            // Set the leftmost 8emLen - emBits bits of the leftmost octet
            // in maskedDB to zero.
            const shift = std.math.comptimeMod(8 * em_len - em_bits, 8);
            const mask = @as(u8, 0xff) >> shift;
            db[0] &= mask;

            return em;
        }
    };
}

/// Mask generation function. Currently the only one defined.
fn mgf1(comptime Hash: type, seed: []const u8, out: []u8) []u8 {
    var c: [@sizeOf(u32)]u8 = undefined;
    var tmp: [Hash.digest_length]u8 = undefined;

    var i: usize = 0;
    var counter: u32 = 0;
    while (i < out.len) : (counter += 1) {
        var hasher = Hash.init(.{});
        hasher.update(seed);
        std.mem.writeInt(u32, &c, counter, .big);
        hasher.update(&c);

        const left = out.len - i;
        if (left >= Hash.digest_length) {
            // optimization: write straight to `out`
            hasher.final(out[i..][0..Hash.digest_length]);
            i += Hash.digest_length;
        } else {
            hasher.final(&tmp);
            @memcpy(out[i..][0..left], tmp[0..left]);
            i += left;
        }
    }

    return out;
}

test mgf1 {
    const Hash = std.crypto.hash.sha2.Sha256;
    var out: [Hash.digest_length * 2 + 1]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &hexToBytes(
            \\ed 1b 84 6b b9 26 39 00  c8 17 82 ad 08 eb 17 01
            \\fa 8c 72 21 c6 57 63 77  31 7f 5c e8 09 89 9f
        ),
        mgf1(Hash, "asdf", out[0 .. Hash.digest_length - 1]),
    );
    try std.testing.expectEqualSlices(
        u8,
        &hexToBytes(
            \\ed 1b 84 6b b9 26 39 00  c8 17 82 ad 08 eb 17 01
            \\fa 8c 72 21 c6 57 63 77  31 7f 5c e8 09 89 9f 5a
            \\22 F2 80 D5 28 08 F4 93  83 76 00 DE 09 E4 EC 92
            \\4A 2C 7C EF 0D F7 7B BE  8F 7F 12 CB 8F 33 A6 65
            \\AB
        ),
        mgf1(Hash, "asdf", &out),
    );
}

/// For OAEP.
inline fn labelHash(comptime Hash: type, label: []const u8) [Hash.digest_length]u8 {
    if (label.len == 0) {
        // magic constants from NIST
        const sha2 = std.crypto.hash.sha2;
        switch (Hash) {
            std.crypto.hash.Sha1 => return hexToBytes(
                \\da39a3ee 5e6b4b0d 3255bfef 95601890
                \\afd80709
            ),
            sha2.Sha256 => return hexToBytes(
                \\e3b0c442 98fc1c14 9afbf4c8 996fb924
                \\27ae41e4 649b934c a495991b 7852b855
            ),
            sha2.Sha384 => return hexToBytes(
                \\38b060a7 51ac9638 4cd9327e b1b1e36a
                \\21fdb711 14be0743 4c0cc7bf 63f6e1da
                \\274edebf e76f65fb d51ad2f1 4898b95b
            ),
            sha2.Sha512 => return hexToBytes(
                \\cf83e135 7eefb8bd f1542850 d66d8007
                \\d620e405 0b5715dc 83f4a921 d36ce9ce
                \\47d0d13c 5d85f2b0 ff8318d2 877eec2f
                \\63b931bd 47417a81 a538327a f927da3e
            ),
            // just use the empty hash...
            else => {},
        }
    }
    var res: [Hash.digest_length]u8 = undefined;
    Hash.hash(label, &res, .{});
    return res;
}

const ct = if (std.options.side_channels_mitigations == .none) ct_unprotected else ct_protected;

const ct_unprotected = struct {
    fn lastIndexOfScalar(slice: []const u8, value: u8) ?usize {
        return std.mem.lastIndexOfScalar(u8, slice, value);
    }

    fn indexOfScalarPos(slice: []const u8, start_index: usize, value: u8) ?usize {
        return std.mem.indexOfScalarPos(u8, slice, start_index, value);
    }

    fn memEql(a: []const u8, b: []const u8) bool {
        return std.mem.eql(u8, a, b);
    }

    fn @"and"(a: bool, b: bool) bool {
        return a and b;
    }

    fn @"or"(a: bool, b: bool) bool {
        return a or b;
    }
};

const ct_protected = struct {
    fn lastIndexOfScalar(slice: []const u8, value: u8) ?usize {
        var res: ?usize = null;
        var i: usize = slice.len;
        while (i != 0) {
            i -= 1;
            if (@intFromBool(res == null) & @intFromBool(slice[i] == value) == 1) res = i;
        }
        return res;
    }

    fn indexOfScalarPos(slice: []const u8, start_index: usize, value: u8) ?usize {
        var res: ?usize = null;
        for (slice[start_index..], start_index..) |c, j| {
            if (c == value) res = j;
        }
        return res;
    }

    fn memEql(a: []const u8, b: []const u8) bool {
        var res: u1 = 1;
        for (a, b) |a_elem, b_elem| {
            res &= @intFromBool(a_elem == b_elem);
        }
        return res == 1;
    }

    fn @"and"(a: bool, b: bool) bool {
        return (@intFromBool(a) & @intFromBool(b)) == 1;
    }

    fn @"or"(a: bool, b: bool) bool {
        return (@intFromBool(a) | @intFromBool(b)) == 1;
    }
};

test ct {
    const c = ct_unprotected;
    try std.testing.expectEqual(true, c.@"or"(true, false));
    try std.testing.expectEqual(true, c.@"and"(true, true));
    try std.testing.expectEqual(true, c.memEql("Asdf", "Asdf"));
    try std.testing.expectEqual(false, c.memEql("asdf", "Asdf"));
    try std.testing.expectEqual(3, c.indexOfScalarPos("asdff", 1, 'f'));
    try std.testing.expectEqual(4, c.lastIndexOfScalar("asdff", 'f'));
}

fn removeNonHex(comptime hex: []const u8) []const u8 {
    var res: [hex.len]u8 = undefined;
    var i: usize = 0;
    for (hex) |c| {
        if (std.ascii.isHex(c)) {
            res[i] = c;
            i += 1;
        }
    }
    return res[0..i];
}

/// For readable copy/pasting from hex viewers.
fn hexToBytes(comptime hex: []const u8) [removeNonHex(hex).len / 2]u8 {
    const hex2 = comptime removeNonHex(hex);
    comptime var res: [hex2.len / 2]u8 = undefined;
    _ = comptime std.fmt.hexToBytes(&res, hex2) catch unreachable;
    return res;
}

test hexToBytes {
    const hex =
        \\e3b0c442 98fc1c14 9afbf4c8 996fb924
        \\27ae41e4 649b934c a495991b 7852b855
    ;
    try std.testing.expectEqual(
        [_]u8{
            0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
            0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
            0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
            0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
        },
        hexToBytes(hex),
    );
}

const TestHash = std.crypto.hash.sha2.Sha256;
fn testKeypair() !KeyPair {
    const keypair_bytes = @embedFile("testdata/id_rsa.der");
    const kp = try KeyPair.fromDer(keypair_bytes);
    try std.testing.expectEqual(2048, kp.public.modulus.bits());
    return kp;
}

test "rsa PKCS1-v1_5 encrypt and decrypt" {
    const kp = try testKeypair();

    const msg = "rsa PKCS1-v1_5 encrypt and decrypt";
    var out: [max_modulus_len]u8 = undefined;
    const enc = try kp.public.encryptPkcsv1_5(msg, &out);

    var out2: [max_modulus_len]u8 = undefined;
    const dec = try kp.decryptPkcsv1_5(enc, &out2);

    try std.testing.expectEqualSlices(u8, msg, dec);
}

test "rsa OAEP encrypt and decrypt" {
    const kp = try testKeypair();

    const msg = "rsa OAEP encrypt and decrypt";
    const label = "";
    var out: [max_modulus_len]u8 = undefined;
    const enc = try kp.public.encryptOaep(TestHash, msg, label, &out);

    var out2: [max_modulus_len]u8 = undefined;
    const dec = try kp.decryptOaep(TestHash, enc, label, &out2);

    try std.testing.expectEqualSlices(u8, msg, dec);
}

test "rsa PKCS1-v1_5 signature" {
    const kp = try testKeypair();

    const msg = "rsa PKCS1-v1_5 signature";
    var out: [max_modulus_len]u8 = undefined;

    const signature = try kp.signPkcsv1_5(TestHash, msg, &out);
    try signature.verify(msg, kp.public);
}

test "rsa PSS signature" {
    const kp = try testKeypair();

    const msg = "rsa PSS signature";
    var out: [max_modulus_len]u8 = undefined;

    const salts = [_][]const u8{ "asdf", "" };
    for (salts) |salt| {
        const signature = try kp.signOaep(TestHash, msg, salt, &out);
        try signature.verify(msg, kp.public, salt.len);
    }

    const signature = try kp.signOaep(TestHash, msg, null, &out); // random salt
    try signature.verify(msg, kp.public, null);
}
