//! A set of certificates. Typically pre-installed on every operating system,
//! these are "Certificate Authorities" used to validate SSL certificates.
//! This data structure stores certificates in DER-encoded form, all of them
//! concatenated together in the `bytes` array. The `map` field contains an
//! index from the DER-encoded subject name to the index of the containing
//! certificate within `bytes`.

map: std.HashMapUnmanaged(Key, u32, MapContext, std.hash_map.default_max_load_percentage) = .{},
bytes: std.ArrayListUnmanaged(u8) = .{},

pub const Key = struct {
    subject_start: u32,
    subject_end: u32,
};

/// The returned bytes become invalid after calling any of the rescan functions
/// or add functions.
pub fn find(cb: CertificateBundle, subject_name: []const u8) ?u32 {
    const Adapter = struct {
        cb: CertificateBundle,

        pub fn hash(ctx: @This(), k: []const u8) u64 {
            _ = ctx;
            return std.hash_map.hashString(k);
        }

        pub fn eql(ctx: @This(), a: []const u8, b_key: Key) bool {
            const b = ctx.cb.bytes.items[b_key.subject_start..b_key.subject_end];
            return mem.eql(u8, a, b);
        }
    };
    return cb.map.getAdapted(subject_name, Adapter{ .cb = cb });
}

pub fn deinit(cb: *CertificateBundle, gpa: Allocator) void {
    cb.map.deinit(gpa);
    cb.bytes.deinit(gpa);
    cb.* = undefined;
}

/// Empties the set of certificates and then scans the host operating system
/// file system standard locations for certificates.
pub fn rescan(cb: *CertificateBundle, gpa: Allocator) !void {
    switch (builtin.os.tag) {
        .linux => return rescanLinux(cb, gpa),
        else => @compileError("it is unknown where the root CA certificates live on this OS"),
    }
}

pub fn rescanLinux(cb: *CertificateBundle, gpa: Allocator) !void {
    var dir = fs.openIterableDirAbsolute("/etc/ssl/certs", .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => |e| return e,
    };
    defer dir.close();

    cb.bytes.clearRetainingCapacity();
    cb.map.clearRetainingCapacity();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .File, .SymLink => {},
            else => continue,
        }

        try addCertsFromFile(cb, gpa, dir.dir, entry.name);
    }

    cb.bytes.shrinkAndFree(gpa, cb.bytes.items.len);
}

pub fn addCertsFromFile(
    cb: *CertificateBundle,
    gpa: Allocator,
    dir: fs.Dir,
    sub_file_path: []const u8,
) !void {
    var file = try dir.openFile(sub_file_path, .{});
    defer file.close();

    const size = try file.getEndPos();

    // We borrow `bytes` as a temporary buffer for the base64-encoded data.
    // This is possible by computing the decoded length and reserving the space
    // for the decoded bytes first.
    const decoded_size_upper_bound = size / 4 * 3;
    try cb.bytes.ensureUnusedCapacity(gpa, decoded_size_upper_bound + size);
    const end_reserved = cb.bytes.items.len + decoded_size_upper_bound;
    const buffer = cb.bytes.allocatedSlice()[end_reserved..];
    const end_index = try file.readAll(buffer);
    const encoded_bytes = buffer[0..end_index];

    const begin_marker = "-----BEGIN CERTIFICATE-----";
    const end_marker = "-----END CERTIFICATE-----";

    var start_index: usize = 0;
    while (mem.indexOfPos(u8, encoded_bytes, start_index, begin_marker)) |begin_marker_start| {
        const cert_start = begin_marker_start + begin_marker.len;
        const cert_end = mem.indexOfPos(u8, encoded_bytes, cert_start, end_marker) orelse
            return error.MissingEndCertificateMarker;
        start_index = cert_end + end_marker.len;
        const encoded_cert = mem.trim(u8, encoded_bytes[cert_start..cert_end], " \t\r\n");
        const decoded_start = @intCast(u32, cb.bytes.items.len);
        const dest_buf = cb.bytes.allocatedSlice()[decoded_start..];
        cb.bytes.items.len += try base64.decode(dest_buf, encoded_cert);
        const k = try cb.key(decoded_start);
        const gop = try cb.map.getOrPutContext(gpa, k, .{ .cb = cb });
        if (gop.found_existing) {
            cb.bytes.items.len = decoded_start;
        } else {
            gop.value_ptr.* = decoded_start;
        }
    }
}

pub fn key(cb: CertificateBundle, bytes_index: u32) !Key {
    const bytes = cb.bytes.items;
    const certificate = try Der.parseElement(bytes, bytes_index);
    const tbs_certificate = try Der.parseElement(bytes, certificate.start);
    const version = try Der.parseElement(bytes, tbs_certificate.start);
    try checkVersion(bytes, version);

    const serial_number = try Der.parseElement(bytes, version.end);

    // RFC 5280, section 4.1.2.3:
    // "This field MUST contain the same algorithm identifier as
    // the signatureAlgorithm field in the sequence Certificate."
    const signature = try Der.parseElement(bytes, serial_number.end);
    const issuer = try Der.parseElement(bytes, signature.end);
    const validity = try Der.parseElement(bytes, issuer.end);
    const subject = try Der.parseElement(bytes, validity.end);
    //const subject_pub_key = try Der.parseElement(bytes, subject.end);
    //const extensions = try Der.parseElement(bytes, subject_pub_key.end);

    return .{
        .subject_start = subject.start,
        .subject_end = subject.end,
    };
}

pub const Certificate = struct {
    buffer: []const u8,
    index: u32,

    pub fn verify(subject: Certificate, issuer: Certificate) !void {
        const subject_certificate = try Der.parseElement(subject.buffer, subject.index);
        const subject_tbs_certificate = try Der.parseElement(subject.buffer, subject_certificate.start);
        const subject_version = try Der.parseElement(subject.buffer, subject_tbs_certificate.start);
        try checkVersion(subject.buffer, subject_version);
        const subject_serial_number = try Der.parseElement(subject.buffer, subject_version.end);
        // RFC 5280, section 4.1.2.3:
        // "This field MUST contain the same algorithm identifier as
        // the signatureAlgorithm field in the sequence Certificate."
        const subject_signature = try Der.parseElement(subject.buffer, subject_serial_number.end);
        const subject_issuer = try Der.parseElement(subject.buffer, subject_signature.end);
        const subject_validity = try Der.parseElement(subject.buffer, subject_issuer.end);
        //const subject_name = try Der.parseElement(subject.buffer, subject_validity.end);

        const subject_sig_algo = try Der.parseElement(subject.buffer, subject_tbs_certificate.end);
        const subject_algo_elem = try Der.parseElement(subject.buffer, subject_sig_algo.start);
        const subject_algo = try Der.parseObjectId(subject.buffer, subject_algo_elem);
        const subject_sig_elem = try Der.parseElement(subject.buffer, subject_sig_algo.end);
        const subject_sig = try parseBitString(subject, subject_sig_elem);

        const issuer_certificate = try Der.parseElement(issuer.buffer, issuer.index);
        const issuer_tbs_certificate = try Der.parseElement(issuer.buffer, issuer_certificate.start);
        const issuer_version = try Der.parseElement(issuer.buffer, issuer_tbs_certificate.start);
        try checkVersion(issuer.buffer, issuer_version);
        const issuer_serial_number = try Der.parseElement(issuer.buffer, issuer_version.end);
        // RFC 5280, section 4.1.2.3:
        // "This field MUST contain the same algorithm identifier as
        // the signatureAlgorithm field in the sequence Certificate."
        const issuer_signature = try Der.parseElement(issuer.buffer, issuer_serial_number.end);
        const issuer_issuer = try Der.parseElement(issuer.buffer, issuer_signature.end);
        const issuer_validity = try Der.parseElement(issuer.buffer, issuer_issuer.end);
        const issuer_name = try Der.parseElement(issuer.buffer, issuer_validity.end);
        const issuer_pub_key_info = try Der.parseElement(issuer.buffer, issuer_name.end);
        const issuer_pub_key_signature_algorithm = try Der.parseElement(issuer.buffer, issuer_pub_key_info.start);
        const issuer_pub_key_algo_elem = try Der.parseElement(issuer.buffer, issuer_pub_key_signature_algorithm.start);
        const issuer_pub_key_algo = try Der.parseObjectId(issuer.buffer, issuer_pub_key_algo_elem);
        const issuer_pub_key_elem = try Der.parseElement(issuer.buffer, issuer_pub_key_signature_algorithm.end);
        const issuer_pub_key = try parseBitString(issuer, issuer_pub_key_elem);

        // Check that the subject's issuer name matches the issuer's subject
        // name.
        if (!mem.eql(u8, subject.contents(subject_issuer), issuer.contents(issuer_name))) {
            return error.CertificateIssuerMismatch;
        }

        // TODO check the time validity for the subject
        _ = subject_validity;
        // TODO check the time validity for the issuer

        const message = subject.buffer[subject_certificate.start..subject_tbs_certificate.end];
        //std.debug.print("issuer algo: {any} subject algo: {any}\n", .{ issuer_pub_key_algo, subject_algo });
        switch (subject_algo) {
            // zig fmt: off
              .sha1WithRSAEncryption => return verifyRsa(crypto.hash.Sha1,        message, subject_sig, issuer_pub_key_algo, issuer_pub_key),
            .sha224WithRSAEncryption => return verifyRsa(crypto.hash.sha2.Sha224, message, subject_sig, issuer_pub_key_algo, issuer_pub_key),
            .sha256WithRSAEncryption => return verifyRsa(crypto.hash.sha2.Sha256, message, subject_sig, issuer_pub_key_algo, issuer_pub_key),
            .sha384WithRSAEncryption => return verifyRsa(crypto.hash.sha2.Sha384, message, subject_sig, issuer_pub_key_algo, issuer_pub_key),
            .sha512WithRSAEncryption => return verifyRsa(crypto.hash.sha2.Sha512, message, subject_sig, issuer_pub_key_algo, issuer_pub_key),
            // zig fmt: on
            else => {
                std.debug.print("unhandled algorithm: {any}\n", .{subject_algo});
                return error.UnsupportedCertificateSignatureAlgorithm;
            },
        }
    }

    pub fn contents(cert: Certificate, elem: Der.Element) []const u8 {
        return cert.buffer[elem.start..elem.end];
    }

    pub fn parseBitString(cert: Certificate, elem: Der.Element) ![]const u8 {
        if (elem.identifier.tag != .bitstring) return error.CertificateFieldHasWrongDataType;
        if (cert.buffer[elem.start] != 0) return error.CertificateHasInvalidBitString;
        return cert.buffer[elem.start + 1 .. elem.end];
    }

    fn verifyRsa(comptime Hash: type, message: []const u8, sig: []const u8, pub_key_algo: Der.Oid, pub_key: []const u8) !void {
        if (pub_key_algo != .rsaEncryption) return error.CertificateSignatureAlgorithmMismatch;
        const pub_key_seq = try Der.parseElement(pub_key, 0);
        if (pub_key_seq.identifier.tag != .sequence) return error.CertificateFieldHasWrongDataType;
        const modulus_elem = try Der.parseElement(pub_key, pub_key_seq.start);
        if (modulus_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
        const exponent_elem = try Der.parseElement(pub_key, modulus_elem.end);
        if (exponent_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
        // Skip over meaningless zeroes in the modulus.
        const modulus_raw = pub_key[modulus_elem.start..modulus_elem.end];
        const modulus_offset = for (modulus_raw) |byte, i| {
            if (byte != 0) break i;
        } else modulus_raw.len;
        const modulus = modulus_raw[modulus_offset..];
        const exponent = pub_key[exponent_elem.start..exponent_elem.end];
        if (exponent.len > modulus.len) return error.CertificatePublicKeyInvalid;
        if (sig.len != modulus.len) return error.CertificateSignatureInvalidLength;

        const hash_der = switch (Hash) {
            crypto.hash.Sha1 => [_]u8{
                0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e,
                0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14,
            },
            crypto.hash.sha2.Sha224 => [_]u8{
                0x30, 0x2d, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x04, 0x05,
                0x00, 0x04, 0x1c,
            },
            crypto.hash.sha2.Sha256 => [_]u8{
                0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
                0x00, 0x04, 0x20,
            },
            crypto.hash.sha2.Sha384 => [_]u8{
                0x30, 0x41, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02, 0x05,
                0x00, 0x04, 0x30,
            },
            crypto.hash.sha2.Sha512 => [_]u8{
                0x30, 0x51, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
                0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03, 0x05,
                0x00, 0x04, 0x40,
            },
            else => @compileError("unreachable"),
        };

        var msg_hashed: [Hash.digest_length]u8 = undefined;
        Hash.hash(message, &msg_hashed, .{});

        switch (modulus.len) {
            inline 128, 256, 512 => |modulus_len| {
                const ps_len = modulus_len - (hash_der.len + msg_hashed.len) - 3;
                const em: [modulus_len]u8 =
                    [2]u8{ 0, 1 } ++
                    ([1]u8{0xff} ** ps_len) ++
                    [1]u8{0} ++
                    hash_der ++
                    msg_hashed;

                const public_key = try rsa.PublicKey.fromBytes(exponent, modulus, rsa.poop);
                const em_dec = try rsa.encrypt(modulus_len, sig[0..modulus_len].*, public_key, rsa.poop);

                if (!mem.eql(u8, &em, &em_dec)) {
                    try std.testing.expectEqualSlices(u8, &em, &em_dec);
                    return error.CertificateSignatureInvalid;
                }
            },
            else => {
                return error.CertificateSignatureUnsupportedBitCount;
            },
        }
    }
};

fn checkVersion(bytes: []const u8, version: Der.Element) !void {
    if (@bitCast(u8, version.identifier) != 0xa0 or
        !mem.eql(u8, bytes[version.start..version.end], "\x02\x01\x02"))
    {
        return error.UnsupportedCertificateVersion;
    }
}

const builtin = @import("builtin");
const std = @import("../std.zig");
const fs = std.fs;
const mem = std.mem;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const Der = std.crypto.Der;
const CertificateBundle = @This();

const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

const MapContext = struct {
    cb: *const CertificateBundle,

    pub fn hash(ctx: MapContext, k: Key) u64 {
        return std.hash_map.hashString(ctx.cb.bytes.items[k.subject_start..k.subject_end]);
    }

    pub fn eql(ctx: MapContext, a: Key, b: Key) bool {
        const bytes = ctx.cb.bytes.items;
        return mem.eql(
            u8,
            bytes[a.subject_start..a.subject_end],
            bytes[b.subject_start..b.subject_end],
        );
    }
};

test {
    var bundle: CertificateBundle = .{};
    defer bundle.deinit(std.testing.allocator);

    try bundle.rescan(std.testing.allocator);
}

/// TODO: replace this with Frank's upcoming RSA implementation. the verify
/// function won't have the possibility of failure - it will either identify a
/// valid signature or an invalid signature.
/// This code is borrowed from https://github.com/shiguredo/tls13-zig
/// which is licensed under the Apache License Version 2.0, January 2004
/// http://www.apache.org/licenses/
/// The code has been modified.
const rsa = struct {
    const BigInt = std.math.big.int.Managed;

    const PublicKey = struct {
        n: BigInt,
        e: BigInt,

        pub fn deinit(self: *PublicKey) void {
            self.n.deinit();
            self.e.deinit();
        }

        pub fn fromBytes(pub_bytes: []const u8, modulus_bytes: []const u8, allocator: std.mem.Allocator) !PublicKey {
            var _n = try BigInt.init(allocator);
            errdefer _n.deinit();
            try setBytes(&_n, modulus_bytes, allocator);

            var _e = try BigInt.init(allocator);
            errdefer _e.deinit();
            try setBytes(&_e, pub_bytes, allocator);

            return .{
                .n = _n,
                .e = _e,
            };
        }
    };

    fn encrypt(comptime modulus_len: usize, msg: [modulus_len]u8, public_key: PublicKey, allocator: std.mem.Allocator) ![modulus_len]u8 {
        var m = try BigInt.init(allocator);
        defer m.deinit();

        try setBytes(&m, &msg, allocator);

        if (m.order(public_key.n) != .lt) {
            return error.MessageTooLong;
        }

        var e = try BigInt.init(allocator);
        defer e.deinit();

        try pow_montgomery(&e, &m, &public_key.e, &public_key.n, allocator);

        var res: [modulus_len]u8 = undefined;

        try toBytes(&res, &e, allocator);

        return res;
    }

    fn setBytes(r: *BigInt, bytes: []const u8, allcator: std.mem.Allocator) !void {
        try r.set(0);
        var tmp = try BigInt.init(allcator);
        defer tmp.deinit();
        for (bytes) |b| {
            try r.shiftLeft(r, 8);
            try tmp.set(b);
            try r.add(r, &tmp);
        }
    }

    fn pow_montgomery(r: *BigInt, a: *const BigInt, x: *const BigInt, n: *const BigInt, allocator: std.mem.Allocator) !void {
        var bin_raw: [512]u8 = undefined;
        try toBytes(&bin_raw, x, allocator);

        var i: usize = 0;
        while (bin_raw[i] == 0x00) : (i += 1) {}
        const bin = bin_raw[i..];

        try r.set(1);
        var r1 = try BigInt.init(allocator);
        defer r1.deinit();
        try BigInt.copy(&r1, a.toConst());
        i = 0;
        while (i < bin.len * 8) : (i += 1) {
            if (((bin[i / 8] >> @intCast(u3, (7 - (i % 8)))) & 0x1) == 0) {
                try BigInt.mul(&r1, r, &r1);
                try mod(&r1, &r1, n, allocator);
                try BigInt.sqr(r, r);
                try mod(r, r, n, allocator);
            } else {
                try BigInt.mul(r, r, &r1);
                try mod(r, r, n, allocator);
                try BigInt.sqr(&r1, &r1);
                try mod(&r1, &r1, n, allocator);
            }
        }
    }

    fn toBytes(out: []u8, a: *const BigInt, allocator: std.mem.Allocator) !void {
        const Error = error{
            BufferTooSmall,
        };

        var mask = try BigInt.initSet(allocator, 0xFF);
        defer mask.deinit();
        var tmp = try BigInt.init(allocator);
        defer tmp.deinit();

        var a_copy = try BigInt.init(allocator);
        defer a_copy.deinit();
        try a_copy.copy(a.toConst());

        // Encoding into big-endian bytes
        var i: usize = 0;
        while (i < out.len) : (i += 1) {
            try tmp.bitAnd(&a_copy, &mask);
            const b = try tmp.to(u8);
            out[out.len - i - 1] = b;
            try a_copy.shiftRight(&a_copy, 8);
        }

        if (!a_copy.eqZero()) {
            return Error.BufferTooSmall;
        }
    }

    fn mod(rem: *BigInt, a: *const BigInt, n: *const BigInt, allocator: std.mem.Allocator) !void {
        var q = try BigInt.init(allocator);
        defer q.deinit();

        try BigInt.divFloor(&q, rem, a, n);
    }

    // TODO: flush the toilet
    const poop = std.heap.page_allocator;
};
