//! RFC8017: Public Key Cryptography Standards #1 v2.2 (PKCS1)
const std = @import("../std.zig");
const der = @import("der.zig");

/// Recommend pairing with Sha256.
pub const Rsa2048 = Rsa(2048);
/// Recommend pairing with Sha384.
pub const Rsa3072 = Rsa(3072);
/// Recommend pairing with Sha512.
pub const Rsa4096 = Rsa(4096);

pub fn Rsa(comptime modulus_bits: usize) type {
    // To keep implementation simpler. May be lifted in the future.
    if (modulus_bits & 8 != 0) @compileError("modulus_bits must be divisible by 8");
    return struct {
        const Modulus = std.crypto.ff.Modulus(modulus_bits);
        const Fe = Modulus.Fe;
        pub const modulus_len = std.math.divCeil(usize, modulus_bits, 8) catch unreachable;

        pub const PublicKey = struct {
            /// `n`
            modulus: Modulus,
            /// `e`
            public_exponent: Fe,

            pub fn fromBytes(mod: []const u8, exp: []const u8) !PublicKey {
                if (mod.len != modulus_len) return error.InvalidModulus;
                const modulus = try Modulus.fromBytes(mod, .big);
                const public_exponent = try Fe.fromBytes(modulus, exp, .big);

                if (std.debug.runtime_safety) {
                    // > RSA modulus n is a product of u distinct odd primes
                    // > r_i, i = 1, 2, ..., u, where u >= 2
                    if (!modulus.v.isOdd()) return error.InvalidModulus;

                    // > the RSA public exponent e is an integer between 3 and n - 1 satisfying
                    // > GCD(e,\lambda(n)) = 1, where \lambda(n) = LCM(r_1 - 1, ..., r_u - 1)
                    const e_v = public_exponent.toPrimitive(u32) catch return error.InvalidExponent;
                    if (!public_exponent.isOdd()) return error.InvalidExponent;
                    if (e_v < 3) return error.InvalidExponent;
                    if (modulus.v.compare(public_exponent.v) == .lt) return error.InvalidExponent;
                }

                return .{ .modulus = modulus, .public_exponent = public_exponent };
            }

            pub fn fromDer(parser: *der.Parser) !PublicKey {
                const seq = try parser.expectSequence();
                defer parser.seekEnd(seq.slice.end);

                const modulus = try parseModulus(&parser);
                const pub_exp = try parseInteger(&parser);

                return try fromBytes(modulus, pub_exp);
            }

            /// Encrypt a short message using RSAES-PKCS1-v1_5.
            /// The use of this scheme for encrypting an arbitrary message, as opposed to a
            /// randomly generated key, is NOT RECOMMENDED.
            pub fn encrypt(pk: PublicKey, msg: []const u8) ![modulus_len]u8 {
                // align variable names with spec
                const k = modulus_len;
                if (msg.len > k - 11) return error.MessageTooLong;

                var em: [k]u8 = [_]u8{ 0, 2 } ++ [_]u8{0} ** (k - 2);

                const ps = em[2..][0 .. k - msg.len - 3];
                std.crypto.random.bytes(ps);

                @memcpy(em[em.len - msg.len ..], msg);

                const m = Fe.fromBytes(pk.modulus, &em, .big) catch unreachable;
                const e = pk.modulus.powPublic(m, pk.public_exponent) catch unreachable;
                e.toBytes(&em, .big) catch unreachable;
                return em;
            }

            /// Encrypt a short message using Optimal Asymmetric Encryption Padding (RSAES-OAEP).
            pub fn encrypt2(pk: PublicKey, comptime Hash: type, msg: []const u8, label: []const u8) ![modulus_len]u8 {
                // align variable names with spec
                const k = modulus_len;
                const lHash = labelHash(Hash, label);
                const hLen = Hash.digest_length;

                if (msg.len > k - 2 * hLen - 2) return error.MessageTooLong;

                var db = [_]u8{0} ** (k - hLen - 1);
                @memcpy(db[0..lHash.len], &lHash);
                db[db.len - msg.len - 1] = 1;
                @memcpy(db[db.len - msg.len ..], msg);

                var seed: [Hash.digest_length]u8 = undefined;
                std.crypto.random.bytes(&seed);

                const db_mask = mgf1(Hash, &seed, db.len);
                for (&db, db_mask) |*v, m| v.* ^= m;

                const seed_mask = mgf1(Hash, &db, hLen);
                for (&seed, seed_mask) |*v, m| v.* ^= m;

                var em = [_]u8{0} ++ seed ++ db;

                const m = Fe.fromBytes(pk.modulus, &em, .big) catch unreachable;
                const e = pk.modulus.powPublic(m, pk.public_exponent) catch unreachable;
                e.toBytes(&em, .big) catch unreachable;
                return em;
            }
        };

        pub const SecretKey = struct {
            /// `d`
            private_exponent: Fe,

            pub fn fromBytes(n: Modulus, exp: []const u8) !SecretKey {
                const d = try Fe.fromBytes(n, exp, .big);
                if (std.debug.runtime_safety) {
                    // > The RSA private exponent d is a positive integer less than n
                    // > satisfying e * d == 1 (mod \lambda(n)),
                    if (!d.isOdd()) return error.InvalidExponent;
                    if (d.v.compare(n.v) != .lt) return error.InvalidExponent;
                }

                return .{ .private_exponent = d };
            }
        };

        pub const KeyPair = struct {
            public: PublicKey,
            secret: SecretKey,

            pub fn fromDer(parser: *der.Parser) !KeyPair {
                // We're just interested in the first few fields which don't vary by version
                _ = try parser.expectSequence();
                const version = try parser.expectPrimitive(.integer);
                _ = version;

                const mod = try parseModulus(parser);
                const pub_exp = try parseInteger(parser);
                const sec_exp = try parseInteger(parser);
                // Skip unused private key fields

                const public = try PublicKey.fromBytes(mod, pub_exp);
                const secret = try SecretKey.fromBytes(public.modulus, sec_exp);

                // TODO: make this work (FeUnit multiplication?)
                if (std.debug.runtime_safety) {
                    // const prime1 = try parseInteger(&parser);
                    // const prime2 = try parseInteger(&parser);
                    // const p = try Fe.fromBytes(public.modulus, prime1, .big);
                    // const q = try Fe.fromBytes(public.modulus, prime2, .big);

                    // // check that n = p * q
                    // const n_expected = p.v.mul(q.v); // can't mul these :(
                    // if (n_expected.v.compare(public.n.v) != .eq) return error.KeyMismatch;

                    // // check that d * e is one mod p-1 and mod q-1. Note d and e were bound
                    // const de = secret.d.mul(public.e); // can't mul these :(
                    // const one = public.n.one();

                    // if (public.n.mul(de, p.sub(one)).compare(one) != .eq) return error.KeyMismatch;
                    // if (public.n.mul(de, q.sub(one)).compare(one) != .eq) return error.KeyMismatch;
                }

                return .{ .public = public, .secret = secret };
            }

            /// Decrypt a short message using RSAES-PKCS1-v1_5.
            pub fn decrypt(kp: KeyPair, ciphertext: [modulus_len]u8, out: *[modulus_len]u8) ![]u8 {
                const m = Fe.fromBytes(kp.public.modulus, &ciphertext, .big) catch return error.MessageTooLong;
                const e = kp.public.modulus.pow(m, kp.secret.private_exponent) catch unreachable;
                try e.toBytes(out, .big);

                const msg_start = std.mem.lastIndexOfScalar(u8, out, 0);
                // Care shall be taken to ensure that an opponent cannot
                // distinguish these error conditions, whether by error
                // message or timing.
                if (msg_start) |i| {
                    const ps_len = out.len - i;
                    if (out[0] != 0 or out[1] != 2 or ps_len < 8) return error.DecryptionError;

                    return out[i + 1 ..];
                }
                return error.DecryptionError;
            }

            /// Decrypt a short message using RSAES-OAEP
            pub fn decrypt2(
                kp: KeyPair,
                comptime Hash: type,
                ciphertext: [modulus_len]u8,
                label: []const u8,
                out: *[modulus_len]u8,
            ) ![]u8 {
                const mod = Fe.fromBytes(kp.public.modulus, &ciphertext, .big) catch return error.MessageTooLong;
                const exp = kp.public.modulus.pow(mod, kp.secret.private_exponent) catch unreachable;
                try exp.toBytes(out, .big);

                // align variable names with spec
                const hLen = Hash.digest_length;

                const y = out[0];
                const seed = out[1..][0..hLen];
                const db = out[1 + hLen ..];

                const seed_mask = mgf1(Hash, db, hLen);
                for (seed, seed_mask) |*v, m| v.* ^= m;
                const db_mask = mgf1(Hash, seed, db.len);
                for (db, db_mask) |*v, m| v.* ^= m;

                const expected_hash = labelHash(Hash, label);
                const actual_hash = db[0..expected_hash.len];
                const msg_start = std.mem.indexOfScalarPos(u8, out, expected_hash.len + 1, 1);
                if (msg_start) |i| {
                    // Care shall be taken to ensure that an opponent cannot
                    // distinguish these error conditions, whether by error
                    // message or timing.
                    if (!std.mem.eql(u8, &expected_hash, actual_hash) or y != 0) return error.DecryptionError;

                    return out[i + 1 ..];
                }
                return error.DecryptionError;
            }

            /// Uses PKCS1-v1_5 (RSASSA-PKCS1-v1_5).
            pub fn sign(kp: KeyPair, comptime Hash: type, msg: []const u8) !PKCS1v1_5(Hash).Signature {
                var st = try kp.signer(Hash);
                st.update(msg);
                return st.finalize();
            }

            /// Uses PKCS1-v1_5 (RSASSA-PKCS1-v1_5).
            pub fn signer(kp: KeyPair, comptime Hash: type) !PKCS1v1_5(Hash).Signer {
                return PKCS1v1_5(Hash).Signer.init(kp);
            }

            /// Uses Probabilistic Signature Scheme (RSASSA-PSS).
            pub fn sign2(kp: KeyPair, comptime Hash: type, msg: []const u8, salt: ?[]const u8) !PSS(Hash).Signature {
                var st = try kp.signer2(Hash, salt);
                st.update(msg);
                return st.finalize();
            }

            /// Uses Probabilistic Signature Scheme (RSASSA-PSS).
            ///
            /// Salt must outlive returned `PSS.Signer`.
            pub fn signer2(kp: KeyPair, comptime Hash: type, salt: ?[]const u8) !PSS(Hash).Signer {
                return PSS(Hash).Signer.init(kp, salt);
            }

            /// Encrypt short plaintext with secret key.
            pub fn encrypt(kp: KeyPair, plaintext: []const u8, out: *[modulus_len]u8) !void {
                if (plaintext.len > modulus_len) return error.MessageTooLong;
                const n = kp.public.modulus;
                const msg_as_int = try Fe.fromBytes(n, plaintext, .big);
                const enc_as_int = try n.pow(msg_as_int, kp.secret.private_exponent);
                try enc_as_int.toBytes(out, .big);
            }
        };

        pub const Signature = struct {
            bytes: [modulus_len]u8,

            pub const encoded_length = modulus_len;

            pub fn fromBytes(bytes: [modulus_len]u8) Signature {
                return .{ .bytes = bytes };
            }

            pub fn fromDer(bytes: []const u8) !Signature {
                if (bytes.len != modulus_len) return error.InvalidLength;
                return .{ .bytes = bytes[0..modulus_len].* };
            }

            pub fn pss(self: @This(), comptime Hash: type) PSS(Hash).Signature {
                return PSS(Hash).Signature{ .bytes = self.bytes };
            }

            pub fn pkcsv1_5(self: @This(), comptime Hash: type) PKCS1v1_5(Hash).Signature {
                return PKCS1v1_5(Hash).Signature{ .bytes = self.bytes };
            }
        };

        /// Signature Scheme with Appendix v1.5 (RSASSA-PKCS1-v1_5)
        ///
        /// This standard has been superceded by PSS which is formally proven secure.
        /// This is not formally proven secure nor insecure as of 2024.
        pub fn PKCS1v1_5(comptime Hash: type) type {
            return struct {
                const PkcsT = @This();
                pub const Signature = struct {
                    bytes: [modulus_len]u8,

                    const Self = @This();

                    pub const encoded_length = modulus_len;

                    pub fn fromBytes(msg: [modulus_len]u8) Self {
                        return .{ .signature = msg };
                    }

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

                    pub fn finalize(self: *Signer) !PkcsT.Signature {
                        var hash: [Hash.digest_length]u8 = undefined;
                        self.h.final(&hash);

                        var em = try emsaEncode(hash);
                        self.key_pair.encrypt(&em, &em) catch unreachable;
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
                        const s = Fe.fromBytes(pk.modulus, &self.sig.bytes, .big) catch unreachable;
                        const emm = pk.modulus.powPublic(s, pk.public_exponent) catch unreachable;

                        var em: [modulus_len]u8 = undefined;
                        emm.toBytes(&em, .big) catch unreachable;

                        var hash: [Hash.digest_length]u8 = undefined;
                        self.h.final(&hash);

                        const expected = try emsaEncode(hash);

                        if (!std.mem.eql(u8, &expected, &em)) return error.Inconsistent;
                    }
                };

                /// Encrypted Message Signature Appendix
                fn emsaEncode(hash: [Hash.digest_length]u8) ![modulus_len]u8 {
                    const digest_header = digestHeader();
                    const tLen = digest_header.len + Hash.digest_length;
                    const emLen = modulus_len;
                    if (emLen < tLen + 11) return error.ModulusTooShort;

                    var res: [modulus_len]u8 = undefined;
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
                fn digestHeader() []const u8 {
                    const sha2 = std.crypto.hash.sha2;
                    // Section 9.2 Notes 1.
                    return switch (Hash) {
                        std.crypto.hash.Sha1 => &[_]u8{ 0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14 },
                        sha2.Sha224 => &[_]u8{
                            0x30, 0x2d, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                            0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x04, 0x05,
                            0x00, 0x04, 0x1c,
                        },
                        sha2.Sha256 => &[_]u8{
                            0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                            0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
                            0x00, 0x04, 0x20,
                        },
                        sha2.Sha384 => &[_]u8{
                            0x30, 0x41, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                            0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02, 0x05,
                            0x00, 0x04, 0x30,
                        },
                        sha2.Sha512 => &[_]u8{
                            0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                            0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05,
                            0x00, 0x04, 0x40,
                        },
                        else => @compileError("unknown Hash " ++ @typeName(Hash)),
                    };
                }
            };
        }

        /// Probabilistic Signature Scheme (RSASSA-PSS)
        pub fn PSS(comptime Hash: type) type {
            return struct {
                // RFC 4055 S3.1
                pub const default_salt_len = 32;

                pub const Signature = struct {
                    bytes: [modulus_len]u8,

                    const Self = @This();

                    pub const encoded_length = modulus_len;

                    pub fn fromBytes(msg: [modulus_len]u8) Self {
                        return .{ .signature = msg };
                    }

                    pub fn toBytes(self: Self) [encoded_length]u8 {
                        return self.bytes;
                    }

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

                    pub fn finalize(self: *Signer) !PssT.Signature {
                        var hashed: [Hash.digest_length]u8 = undefined;
                        self.h.final(&hashed);

                        const salt = if (self.salt) |s| s else brk: {
                            var res: [default_salt_len]u8 = undefined;
                            std.crypto.random.bytes(&res);
                            break :brk &res;
                        };

                        var em = try encode(hashed, salt);
                        self.key_pair.encrypt(&em, &em) catch unreachable;
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
                        const s = Fe.fromBytes(pk.modulus, &self.sig.bytes, .big) catch unreachable;
                        const emm = pk.modulus.powPublic(s, pk.public_exponent) catch unreachable;

                        var em: [modulus_len]u8 = undefined;
                        emm.toBytes(&em, .big) catch unreachable;

                        if (modulus_len < Hash.digest_length + self.salt_len + 2) return error.Inconsistent;
                        if (em[em.len - 1] != 0xbc) return error.Inconsistent;

                        const db = em[0 .. modulus_len - Hash.digest_length - 1];
                        const expected_hash = em[db.len..][0..Hash.digest_length];
                        const db_mask = mgf1(Hash, expected_hash, db.len);
                        for (db, db_mask) |*v, m| v.* ^= m;
                        // Set leftmost bit to zero to prevent encoded message being greater than modulus
                        db[0] &= 0b01111111;

                        for (0..db.len - self.salt_len - 1) |i| {
                            if (db[i] != 0) return error.Inconsistent;
                        }
                        if (db[db.len - self.salt_len - 1] != 1) return error.Inconsistent;
                        const salt = db[db.len - self.salt_len ..];
                        var mp_buf: [modulus_len]u8 = undefined;
                        var mp = mp_buf[0 .. 8 + Hash.digest_length + self.salt_len];
                        @memset(mp[0..8], 0);
                        self.h.final(mp[8..][0..Hash.digest_length]);
                        @memcpy(mp[8 + Hash.digest_length ..][0..salt.len], salt);

                        var actual_hash: [Hash.digest_length]u8 = undefined;
                        Hash.hash(mp, &actual_hash, .{});

                        if (!std.mem.eql(u8, expected_hash, &actual_hash)) return error.Inconsistent;
                    }
                };

                fn encode(hashed: [Hash.digest_length]u8, salt: []const u8) ![modulus_len]u8 {
                    var res = [_]u8{0} ** modulus_len;

                    if (modulus_len < Hash.digest_length + salt.len + 2) return error.Encoding;

                    var mp: [modulus_len]u8 = undefined;
                    const mp_len = 8 + Hash.digest_length + salt.len;
                    @memset(mp[0..8], 0);
                    @memcpy(mp[8..][0..Hash.digest_length], &hashed);
                    @memcpy(mp[8 + Hash.digest_length ..][0..salt.len], salt);

                    var hashed2: [Hash.digest_length]u8 = undefined;
                    Hash.hash(mp[0..mp_len], &hashed2, .{});

                    var db = res[0 .. modulus_len - Hash.digest_length - 1];
                    db[db.len - salt.len - 1] = 1;
                    @memcpy(db[db.len - salt.len ..], salt);

                    const db_mask = mgf1(Hash, &hashed2, db.len);
                    for (db, db_mask) |*v, m| v.* ^= m;

                    // Set leftmost bit to zero to prevent encoded message being greater than modulus
                    db[0] &= 0x7f;

                    @memcpy(res[res.len - hashed2.len - 1 ..][0..hashed2.len], &hashed2);
                    res[res.len - 1] = 0xbc;

                    return res;
                }
            };
        }

        /// Mask generation function. Currently the only one defined.
        fn mgf1(comptime Hash: type, seed: []const u8, comptime len: usize) [len]u8 {
            var res: [len]u8 = undefined;
            const n = std.math.divCeil(usize, len, Hash.digest_length) catch unreachable;
            for (0..n - 1) |i| {
                var hasher = Hash.init(.{});
                hasher.update(seed);
                var c = [_]u8{
                    @intCast((i >> 24) & 0xFF),
                    @intCast((i >> 16) & 0xFF),
                    @intCast((i >> 8) & 0xFF),
                    @intCast(i & 0xFF),
                };
                hasher.update(&c);

                hasher.final(res[i * Hash.digest_length ..][0..Hash.digest_length]);
            }

            return res;
        }

        /// For OAEP.
        inline fn labelHash(comptime Hash: type, label: []const u8) [Hash.digest_length]u8 {
            if (label.len == 0) {
                // magic constants from NIST
                const sha2 = std.crypto.hash.sha2;
                switch (Hash) {
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
    };
}

pub fn parseModulus(parser: *der.Parser) ![]const u8 {
    const elem = try parser.expectPrimitive(.integer);
    const modulus_raw = parser.view(elem);
    // Skip over meaningless zeroes in the modulus.
    const modulus_offset = std.mem.indexOfNone(u8, modulus_raw, &[_]u8{0}) orelse modulus_raw.len;
    return modulus_raw[modulus_offset..];
}

fn parseInteger(parser: *der.Parser) ![]const u8 {
    const elem = try parser.expectPrimitive(.integer);
    return parser.view(elem);
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

const TestScheme = Rsa2048;
const TestHash = std.crypto.hash.sha2.Sha256;
fn testKeypair() !TestScheme.KeyPair {
    const keypair_bytes = @embedFile("testdata/id_rsa.der");
    var parser = der.Parser{ .bytes = keypair_bytes };
    return try TestScheme.KeyPair.fromDer(&parser);
}

test "rsa PKCS1-v1_5 encrypt and decrypt" {
    const kp = try testKeypair();

    const msg = "zig zag";
    const enc = try kp.public.encrypt(msg);
    var out: [TestScheme.modulus_len]u8 = undefined;
    const dec = try kp.decrypt(enc, &out);

    try std.testing.expectEqualSlices(u8, msg, dec);
}

test "rsa OAEP encrypt and decrypt" {
    const kp = try testKeypair();

    const msg = "zig zag";
    const label = "";
    const enc = try kp.public.encrypt2(TestHash, msg, label);
    var out: [TestScheme.modulus_len]u8 = undefined;
    const dec = try kp.decrypt2(TestHash, enc, label, &out);

    try std.testing.expectEqualSlices(u8, msg, dec);
}

test "rsa PKCS1-v1_5 signature" {
    const kp = try testKeypair();

    const msg = "zig zag";

    const signature = try kp.sign(TestHash, msg);
    try signature.verify(msg, kp.public);
}

test "rsa PSS signature" {
    const kp = try testKeypair();

    const msg = "zig zag";

    const salts = [_][]const u8{ "asdf", "" };
    for (salts) |salt| {
        const signature = try kp.sign2(TestHash, msg, salt);
        try signature.verify(msg, kp.public, salt.len);
    }

    const signature = try kp.sign2(TestHash, msg, null); // random salt
    try signature.verify(msg, kp.public, null);
}
