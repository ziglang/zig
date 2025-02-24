const std = @import("std");
const crypto = std.crypto;
const tls = crypto.tls;
const hkdfExpandLabel = tls.hkdfExpandLabel;

const Sha256 = crypto.hash.sha2.Sha256;
const Sha384 = crypto.hash.sha2.Sha384;
const Sha512 = crypto.hash.sha2.Sha512;

const HashTag = @import("cipher.zig").CipherSuite.HashTag;

// Transcript holds hash of all handshake message.
//
// Until the server hello is parsed we don't know which hash (sha256, sha384,
// sha512) will be used so we update all of them. Handshake process will set
// `selected` field once cipher suite is known. Other function will use that
// selected hash. We continue to calculate all hashes because client certificate
// message could use different hash than the other part of the handshake.
// Handshake hash is dictated by the server selected cipher. Client certificate
// hash is dictated by the private key used.
//
// Most of the functions are inlined because they are returning pointers.
//
pub const Transcript = struct {
    sha256: Type(.sha256) = .{ .hash = Sha256.init(.{}) },
    sha384: Type(.sha384) = .{ .hash = Sha384.init(.{}) },
    sha512: Type(.sha512) = .{ .hash = Sha512.init(.{}) },

    tag: HashTag = .sha256,

    pub const max_mac_length = Type(.sha512).mac_length;

    // Transcript Type from hash tag
    fn Type(h: HashTag) type {
        return switch (h) {
            .sha256 => TranscriptT(Sha256),
            .sha384 => TranscriptT(Sha384),
            .sha512 => TranscriptT(Sha512),
        };
    }

    /// Set hash to use in all following function calls.
    pub fn use(t: *Transcript, tag: HashTag) void {
        t.tag = tag;
    }

    pub fn update(t: *Transcript, buf: []const u8) void {
        t.sha256.hash.update(buf);
        t.sha384.hash.update(buf);
        t.sha512.hash.update(buf);
    }

    // tls 1.2 handshake specific

    pub inline fn masterSecret(
        t: *Transcript,
        pre_master_secret: []const u8,
        client_random: [32]u8,
        server_random: [32]u8,
    ) []const u8 {
        return switch (t.tag) {
            inline else => |h| &@field(t, @tagName(h)).masterSecret(
                pre_master_secret,
                client_random,
                server_random,
            ),
        };
    }

    pub inline fn keyMaterial(
        t: *Transcript,
        master_secret: []const u8,
        client_random: [32]u8,
        server_random: [32]u8,
    ) []const u8 {
        return switch (t.tag) {
            inline else => |h| &@field(t, @tagName(h)).keyExpansion(
                master_secret,
                client_random,
                server_random,
            ),
        };
    }

    pub fn clientFinishedTls12(t: *Transcript, master_secret: []const u8) [12]u8 {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).clientFinishedTls12(master_secret),
        };
    }

    pub fn serverFinishedTls12(t: *Transcript, master_secret: []const u8) [12]u8 {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).serverFinishedTls12(master_secret),
        };
    }

    // tls 1.3 handshake specific

    pub inline fn serverCertificateVerify(t: *Transcript) []const u8 {
        return switch (t.tag) {
            inline else => |h| &@field(t, @tagName(h)).serverCertificateVerify(),
        };
    }

    pub inline fn clientCertificateVerify(t: *Transcript) []const u8 {
        return switch (t.tag) {
            inline else => |h| &@field(t, @tagName(h)).clientCertificateVerify(),
        };
    }

    pub fn serverFinishedTls13(t: *Transcript, buf: []u8) []const u8 {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).serverFinishedTls13(buf),
        };
    }

    pub fn clientFinishedTls13(t: *Transcript, buf: []u8) []const u8 {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).clientFinishedTls13(buf),
        };
    }

    pub const Secret = struct {
        client: []const u8,
        server: []const u8,
    };

    pub inline fn handshakeSecret(t: *Transcript, shared_key: []const u8) Secret {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).handshakeSecret(shared_key),
        };
    }

    pub inline fn applicationSecret(t: *Transcript) Secret {
        return switch (t.tag) {
            inline else => |h| @field(t, @tagName(h)).applicationSecret(),
        };
    }

    // other

    pub fn Hkdf(h: HashTag) type {
        return Type(h).Hkdf;
    }

    /// Copy of the current hash value
    pub inline fn hash(t: *Transcript, comptime Hash: type) Hash {
        return switch (Hash) {
            Sha256 => t.sha256.hash,
            Sha384 => t.sha384.hash,
            Sha512 => t.sha512.hash,
            else => @compileError("unimplemented"),
        };
    }
};

fn TranscriptT(comptime Hash: type) type {
    return struct {
        const Hmac = crypto.auth.hmac.Hmac(Hash);
        const Hkdf = crypto.kdf.hkdf.Hkdf(Hmac);
        const mac_length = Hmac.mac_length;

        hash: Hash,
        handshake_secret: [Hmac.mac_length]u8 = undefined,
        server_finished_key: [Hmac.key_length]u8 = undefined,
        client_finished_key: [Hmac.key_length]u8 = undefined,

        const Self = @This();

        fn init(transcript: Hash) Self {
            return .{ .transcript = transcript };
        }

        fn serverCertificateVerify(c: *Self) [64 + 34 + Hash.digest_length]u8 {
            return ([1]u8{0x20} ** 64) ++
                "TLS 1.3, server CertificateVerify\x00".* ++
                c.hash.peek();
        }

        // ref: https://www.rfc-editor.org/rfc/rfc8446#section-4.4.3
        fn clientCertificateVerify(c: *Self) [64 + 34 + Hash.digest_length]u8 {
            return ([1]u8{0x20} ** 64) ++
                "TLS 1.3, client CertificateVerify\x00".* ++
                c.hash.peek();
        }

        fn masterSecret(
            _: *Self,
            pre_master_secret: []const u8,
            client_random: [32]u8,
            server_random: [32]u8,
        ) [mac_length * 2]u8 {
            const seed = "master secret" ++ client_random ++ server_random;

            var a1: [mac_length]u8 = undefined;
            var a2: [mac_length]u8 = undefined;
            Hmac.create(&a1, seed, pre_master_secret);
            Hmac.create(&a2, &a1, pre_master_secret);

            var p1: [mac_length]u8 = undefined;
            var p2: [mac_length]u8 = undefined;
            Hmac.create(&p1, a1 ++ seed, pre_master_secret);
            Hmac.create(&p2, a2 ++ seed, pre_master_secret);

            return p1 ++ p2;
        }

        fn keyExpansion(
            _: *Self,
            master_secret: []const u8,
            client_random: [32]u8,
            server_random: [32]u8,
        ) [mac_length * 4]u8 {
            const seed = "key expansion" ++ server_random ++ client_random;

            const a0 = seed;
            var a1: [mac_length]u8 = undefined;
            var a2: [mac_length]u8 = undefined;
            var a3: [mac_length]u8 = undefined;
            var a4: [mac_length]u8 = undefined;
            Hmac.create(&a1, a0, master_secret);
            Hmac.create(&a2, &a1, master_secret);
            Hmac.create(&a3, &a2, master_secret);
            Hmac.create(&a4, &a3, master_secret);

            var key_material: [mac_length * 4]u8 = undefined;
            Hmac.create(key_material[0..mac_length], a1 ++ seed, master_secret);
            Hmac.create(key_material[mac_length .. mac_length * 2], a2 ++ seed, master_secret);
            Hmac.create(key_material[mac_length * 2 .. mac_length * 3], a3 ++ seed, master_secret);
            Hmac.create(key_material[mac_length * 3 ..], a4 ++ seed, master_secret);
            return key_material;
        }

        fn clientFinishedTls12(self: *Self, master_secret: []const u8) [12]u8 {
            const seed = "client finished" ++ self.hash.peek();
            var a1: [mac_length]u8 = undefined;
            var p1: [mac_length]u8 = undefined;
            Hmac.create(&a1, seed, master_secret);
            Hmac.create(&p1, a1 ++ seed, master_secret);
            return p1[0..12].*;
        }

        fn serverFinishedTls12(self: *Self, master_secret: []const u8) [12]u8 {
            const seed = "server finished" ++ self.hash.peek();
            var a1: [mac_length]u8 = undefined;
            var p1: [mac_length]u8 = undefined;
            Hmac.create(&a1, seed, master_secret);
            Hmac.create(&p1, a1 ++ seed, master_secret);
            return p1[0..12].*;
        }

        // tls 1.3

        inline fn handshakeSecret(self: *Self, shared_key: []const u8) Transcript.Secret {
            const hello_hash = self.hash.peek();

            const zeroes = [1]u8{0} ** Hash.digest_length;
            const early_secret = Hkdf.extract(&[1]u8{0}, &zeroes);
            const empty_hash = tls.emptyHash(Hash);
            const hs_derived_secret = hkdfExpandLabel(Hkdf, early_secret, "derived", &empty_hash, Hash.digest_length);

            self.handshake_secret = Hkdf.extract(&hs_derived_secret, shared_key);
            const client_secret = hkdfExpandLabel(Hkdf, self.handshake_secret, "c hs traffic", &hello_hash, Hash.digest_length);
            const server_secret = hkdfExpandLabel(Hkdf, self.handshake_secret, "s hs traffic", &hello_hash, Hash.digest_length);

            self.server_finished_key = hkdfExpandLabel(Hkdf, server_secret, "finished", "", Hmac.key_length);
            self.client_finished_key = hkdfExpandLabel(Hkdf, client_secret, "finished", "", Hmac.key_length);

            return .{ .client = &client_secret, .server = &server_secret };
        }

        inline fn applicationSecret(self: *Self) Transcript.Secret {
            const handshake_hash = self.hash.peek();

            const empty_hash = tls.emptyHash(Hash);
            const zeroes = [1]u8{0} ** Hash.digest_length;
            const ap_derived_secret = hkdfExpandLabel(Hkdf, self.handshake_secret, "derived", &empty_hash, Hash.digest_length);
            const master_secret = Hkdf.extract(&ap_derived_secret, &zeroes);

            const client_secret = hkdfExpandLabel(Hkdf, master_secret, "c ap traffic", &handshake_hash, Hash.digest_length);
            const server_secret = hkdfExpandLabel(Hkdf, master_secret, "s ap traffic", &handshake_hash, Hash.digest_length);

            return .{ .client = &client_secret, .server = &server_secret };
        }

        fn serverFinishedTls13(self: *Self, buf: []u8) []const u8 {
            Hmac.create(buf[0..mac_length], &self.hash.peek(), &self.server_finished_key);
            return buf[0..mac_length];
        }

        // client finished message with header
        fn clientFinishedTls13(self: *Self, buf: []u8) []const u8 {
            Hmac.create(buf[0..mac_length], &self.hash.peek(), &self.client_finished_key);
            return buf[0..mac_length];
        }
    };
}
