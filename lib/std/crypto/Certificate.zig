buffer: []const u8,
index: u32,

pub const Bundle = @import("Certificate/Bundle.zig");

pub const Algorithm = enum {
    sha1WithRSAEncryption,
    sha224WithRSAEncryption,
    sha256WithRSAEncryption,
    sha384WithRSAEncryption,
    sha512WithRSAEncryption,
    ecdsa_with_SHA224,
    ecdsa_with_SHA256,
    ecdsa_with_SHA384,
    ecdsa_with_SHA512,

    pub const map = std.ComptimeStringMap(Algorithm, .{
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x05 }, .sha1WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B }, .sha256WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0C }, .sha384WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0D }, .sha512WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0E }, .sha224WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x01 }, .ecdsa_with_SHA224 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02 }, .ecdsa_with_SHA256 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x03 }, .ecdsa_with_SHA384 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x04 }, .ecdsa_with_SHA512 },
    });

    pub fn Hash(comptime algorithm: Algorithm) type {
        return switch (algorithm) {
            .sha1WithRSAEncryption => crypto.hash.Sha1,
            .ecdsa_with_SHA224, .sha224WithRSAEncryption => crypto.hash.sha2.Sha224,
            .ecdsa_with_SHA256, .sha256WithRSAEncryption => crypto.hash.sha2.Sha256,
            .ecdsa_with_SHA384, .sha384WithRSAEncryption => crypto.hash.sha2.Sha384,
            .ecdsa_with_SHA512, .sha512WithRSAEncryption => crypto.hash.sha2.Sha512,
        };
    }
};

pub const AlgorithmCategory = enum {
    rsaEncryption,
    X9_62_id_ecPublicKey,

    pub const map = std.ComptimeStringMap(AlgorithmCategory, .{
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01 }, .rsaEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01 }, .X9_62_id_ecPublicKey },
    });
};

pub const Attribute = enum {
    commonName,
    serialNumber,
    countryName,
    localityName,
    stateOrProvinceName,
    organizationName,
    organizationalUnitName,
    organizationIdentifier,

    pub const map = std.ComptimeStringMap(Attribute, .{
        .{ &[_]u8{ 0x55, 0x04, 0x03 }, .commonName },
        .{ &[_]u8{ 0x55, 0x04, 0x05 }, .serialNumber },
        .{ &[_]u8{ 0x55, 0x04, 0x06 }, .countryName },
        .{ &[_]u8{ 0x55, 0x04, 0x07 }, .localityName },
        .{ &[_]u8{ 0x55, 0x04, 0x08 }, .stateOrProvinceName },
        .{ &[_]u8{ 0x55, 0x04, 0x0A }, .organizationName },
        .{ &[_]u8{ 0x55, 0x04, 0x0B }, .organizationalUnitName },
        .{ &[_]u8{ 0x55, 0x04, 0x61 }, .organizationIdentifier },
    });
};

pub const Parsed = struct {
    certificate: Certificate,
    issuer_slice: Slice,
    subject_slice: Slice,
    common_name_slice: Slice,
    signature_slice: Slice,
    signature_algorithm: Algorithm,
    pub_key_algo: AlgorithmCategory,
    pub_key_slice: Slice,
    message_slice: Slice,
    validity: Validity,

    pub const Validity = struct {
        not_before: u64,
        not_after: u64,
    };

    pub const Slice = der.Element.Slice;

    pub fn slice(p: Parsed, s: Slice) []const u8 {
        return p.certificate.buffer[s.start..s.end];
    }

    pub fn issuer(p: Parsed) []const u8 {
        return p.slice(p.issuer_slice);
    }

    pub fn subject(p: Parsed) []const u8 {
        return p.slice(p.subject_slice);
    }

    pub fn commonName(p: Parsed) []const u8 {
        return p.slice(p.common_name_slice);
    }

    pub fn signature(p: Parsed) []const u8 {
        return p.slice(p.signature_slice);
    }

    pub fn pubKey(p: Parsed) []const u8 {
        return p.slice(p.pub_key_slice);
    }

    pub fn message(p: Parsed) []const u8 {
        return p.slice(p.message_slice);
    }

    /// This function checks the time validity for the subject only. Checking
    /// the issuer's time validity is out of scope.
    pub fn verify(parsed_subject: Parsed, parsed_issuer: Parsed) !void {
        // Check that the subject's issuer name matches the issuer's
        // subject name.
        if (!mem.eql(u8, parsed_subject.issuer(), parsed_issuer.subject())) {
            return error.CertificateIssuerMismatch;
        }

        const now_sec = std.time.timestamp();
        if (now_sec < parsed_subject.validity.not_before)
            return error.CertificateNotYetValid;
        if (now_sec > parsed_subject.validity.not_after)
            return error.CertificateExpired;

        switch (parsed_subject.signature_algorithm) {
            inline .sha1WithRSAEncryption,
            .sha224WithRSAEncryption,
            .sha256WithRSAEncryption,
            .sha384WithRSAEncryption,
            .sha512WithRSAEncryption,
            => |algorithm| return verifyRsa(
                algorithm.Hash(),
                parsed_subject.message(),
                parsed_subject.signature(),
                parsed_issuer.pub_key_algo,
                parsed_issuer.pubKey(),
            ),
            .ecdsa_with_SHA224,
            .ecdsa_with_SHA256,
            .ecdsa_with_SHA384,
            .ecdsa_with_SHA512,
            => {
                return error.CertificateSignatureAlgorithmUnsupported;
            },
        }
    }
};

pub fn parse(cert: Certificate) !Parsed {
    const cert_bytes = cert.buffer;
    const certificate = try der.parseElement(cert_bytes, cert.index);
    const tbs_certificate = try der.parseElement(cert_bytes, certificate.slice.start);
    const version = try der.parseElement(cert_bytes, tbs_certificate.slice.start);
    try checkVersion(cert_bytes, version);
    const serial_number = try der.parseElement(cert_bytes, version.slice.end);
    // RFC 5280, section 4.1.2.3:
    // "This field MUST contain the same algorithm identifier as
    // the signatureAlgorithm field in the sequence Certificate."
    const tbs_signature = try der.parseElement(cert_bytes, serial_number.slice.end);
    const issuer = try der.parseElement(cert_bytes, tbs_signature.slice.end);
    const validity = try der.parseElement(cert_bytes, issuer.slice.end);
    const not_before = try der.parseElement(cert_bytes, validity.slice.start);
    const not_before_utc = try parseTime(cert, not_before);
    const not_after = try der.parseElement(cert_bytes, not_before.slice.end);
    const not_after_utc = try parseTime(cert, not_after);
    const subject = try der.parseElement(cert_bytes, validity.slice.end);

    const pub_key_info = try der.parseElement(cert_bytes, subject.slice.end);
    const pub_key_signature_algorithm = try der.parseElement(cert_bytes, pub_key_info.slice.start);
    const pub_key_algo_elem = try der.parseElement(cert_bytes, pub_key_signature_algorithm.slice.start);
    const pub_key_algo = try parseAlgorithmCategory(cert_bytes, pub_key_algo_elem);
    const pub_key_elem = try der.parseElement(cert_bytes, pub_key_signature_algorithm.slice.end);
    const pub_key = try parseBitString(cert, pub_key_elem);

    const rdn = try der.parseElement(cert_bytes, subject.slice.start);
    const atav = try der.parseElement(cert_bytes, rdn.slice.start);

    var common_name = der.Element.Slice.empty;
    var atav_i = atav.slice.start;
    while (atav_i < atav.slice.end) {
        const ty_elem = try der.parseElement(cert_bytes, atav_i);
        const ty = try parseAttribute(cert_bytes, ty_elem);
        const val = try der.parseElement(cert_bytes, ty_elem.slice.end);
        switch (ty) {
            .commonName => common_name = val.slice,
            else => {},
        }
        atav_i = val.slice.end;
    }

    const sig_algo = try der.parseElement(cert_bytes, tbs_certificate.slice.end);
    const algo_elem = try der.parseElement(cert_bytes, sig_algo.slice.start);
    const signature_algorithm = try parseAlgorithm(cert_bytes, algo_elem);
    const sig_elem = try der.parseElement(cert_bytes, sig_algo.slice.end);
    const signature = try parseBitString(cert, sig_elem);

    return .{
        .certificate = cert,
        .common_name_slice = common_name,
        .issuer_slice = issuer.slice,
        .subject_slice = subject.slice,
        .signature_slice = signature,
        .signature_algorithm = signature_algorithm,
        .message_slice = .{ .start = certificate.slice.start, .end = tbs_certificate.slice.end },
        .pub_key_algo = pub_key_algo,
        .pub_key_slice = pub_key,
        .validity = .{
            .not_before = not_before_utc,
            .not_after = not_after_utc,
        },
    };
}

pub fn verify(subject: Certificate, issuer: Certificate) !void {
    const parsed_subject = try subject.parse();
    const parsed_issuer = try issuer.parse();
    return parsed_subject.verify(parsed_issuer);
}

pub fn contents(cert: Certificate, elem: der.Element) []const u8 {
    return cert.buffer[elem.slice.start..elem.slice.end];
}

pub fn parseBitString(cert: Certificate, elem: der.Element) !der.Element.Slice {
    if (elem.identifier.tag != .bitstring) return error.CertificateFieldHasWrongDataType;
    if (cert.buffer[elem.slice.start] != 0) return error.CertificateHasInvalidBitString;
    return .{ .start = elem.slice.start + 1, .end = elem.slice.end };
}

/// Returns number of seconds since epoch.
pub fn parseTime(cert: Certificate, elem: der.Element) !u64 {
    const bytes = cert.contents(elem);
    switch (elem.identifier.tag) {
        .utc_time => {
            // Example: "YYMMDD000000Z"
            if (bytes.len != 13)
                return error.CertificateTimeInvalid;
            if (bytes[12] != 'Z')
                return error.CertificateTimeInvalid;

            return Date.toSeconds(.{
                .year = @as(u16, 2000) + try parseTimeDigits(bytes[0..2].*, 0, 99),
                .month = try parseTimeDigits(bytes[2..4].*, 1, 12),
                .day = try parseTimeDigits(bytes[4..6].*, 1, 31),
                .hour = try parseTimeDigits(bytes[6..8].*, 0, 23),
                .minute = try parseTimeDigits(bytes[8..10].*, 0, 59),
                .second = try parseTimeDigits(bytes[10..12].*, 0, 59),
            });
        },
        .generalized_time => {
            // Examples:
            // "19920521000000Z"
            // "19920622123421Z"
            // "19920722132100.3Z"
            if (bytes.len < 15)
                return error.CertificateTimeInvalid;
            return Date.toSeconds(.{
                .year = try parseYear4(bytes[0..4]),
                .month = try parseTimeDigits(bytes[4..6].*, 1, 12),
                .day = try parseTimeDigits(bytes[6..8].*, 1, 31),
                .hour = try parseTimeDigits(bytes[8..10].*, 0, 23),
                .minute = try parseTimeDigits(bytes[10..12].*, 0, 59),
                .second = try parseTimeDigits(bytes[12..14].*, 0, 59),
            });
        },
        else => return error.CertificateFieldHasWrongDataType,
    }
}

const Date = struct {
    /// example: 1999
    year: u16,
    /// range: 1 to 12
    month: u8,
    /// range: 1 to 31
    day: u8,
    /// range: 0 to 59
    hour: u8,
    /// range: 0 to 59
    minute: u8,
    /// range: 0 to 59
    second: u8,

    /// Convert to number of seconds since epoch.
    pub fn toSeconds(date: Date) u64 {
        var sec: u64 = 0;

        {
            var year: u16 = 1970;
            while (year < date.year) : (year += 1) {
                const days: u64 = std.time.epoch.getDaysInYear(year);
                sec += days * std.time.epoch.secs_per_day;
            }
        }

        {
            const is_leap = std.time.epoch.isLeapYear(date.year);
            var month: u4 = 1;
            while (month < date.month) : (month += 1) {
                const days: u64 = std.time.epoch.getDaysInMonth(
                    @intToEnum(std.time.epoch.YearLeapKind, @boolToInt(is_leap)),
                    @intToEnum(std.time.epoch.Month, month),
                );
                sec += days * std.time.epoch.secs_per_day;
            }
        }

        sec += (date.day - 1) * @as(u64, std.time.epoch.secs_per_day);
        sec += date.hour * @as(u64, 60 * 60);
        sec += date.minute * @as(u64, 60);
        sec += date.second;

        return sec;
    }
};

pub fn parseTimeDigits(nn: @Vector(2, u8), min: u8, max: u8) !u8 {
    const zero: @Vector(2, u8) = .{ '0', '0' };
    const mm: @Vector(2, u8) = .{ 10, 1 };
    const result = @reduce(.Add, (nn -% zero) *% mm);
    if (result < min) return error.CertificateTimeInvalid;
    if (result > max) return error.CertificateTimeInvalid;
    return result;
}

test parseTimeDigits {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(u8, 0), try parseTimeDigits("00".*, 0, 99));
    try expectEqual(@as(u8, 99), try parseTimeDigits("99".*, 0, 99));
    try expectEqual(@as(u8, 42), try parseTimeDigits("42".*, 0, 99));

    const expectError = std.testing.expectError;
    try expectError(error.CertificateTimeInvalid, parseTimeDigits("13".*, 1, 12));
    try expectError(error.CertificateTimeInvalid, parseTimeDigits("00".*, 1, 12));
}

pub fn parseYear4(text: *const [4]u8) !u16 {
    const nnnn: @Vector(4, u16) = .{ text[0], text[1], text[2], text[3] };
    const zero: @Vector(4, u16) = .{ '0', '0', '0', '0' };
    const mmmm: @Vector(4, u16) = .{ 1000, 100, 10, 1 };
    const result = @reduce(.Add, (nnnn -% zero) *% mmmm);
    if (result > 9999) return error.CertificateTimeInvalid;
    return result;
}

test parseYear4 {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(u16, 0), try parseYear4("0000"));
    try expectEqual(@as(u16, 9999), try parseYear4("9999"));
    try expectEqual(@as(u16, 1988), try parseYear4("1988"));

    const expectError = std.testing.expectError;
    try expectError(error.CertificateTimeInvalid, parseYear4("999b"));
    try expectError(error.CertificateTimeInvalid, parseYear4("crap"));
}

pub fn parseAlgorithm(bytes: []const u8, element: der.Element) !Algorithm {
    if (element.identifier.tag != .object_identifier)
        return error.CertificateFieldHasWrongDataType;
    const oid_bytes = bytes[element.slice.start..element.slice.end];
    return Algorithm.map.get(oid_bytes) orelse {
        //std.debug.print("oid bytes: {}\n", .{std.fmt.fmtSliceHexLower(oid_bytes)});
        return error.CertificateHasUnrecognizedAlgorithm;
    };
}

pub fn parseAlgorithmCategory(bytes: []const u8, element: der.Element) !AlgorithmCategory {
    if (element.identifier.tag != .object_identifier)
        return error.CertificateFieldHasWrongDataType;
    return AlgorithmCategory.map.get(bytes[element.slice.start..element.slice.end]) orelse
        return error.CertificateHasUnrecognizedAlgorithmCategory;
}

pub fn parseAttribute(bytes: []const u8, element: der.Element) !Attribute {
    if (element.identifier.tag != .object_identifier)
        return error.CertificateFieldHasWrongDataType;
    return Attribute.map.get(bytes[element.slice.start..element.slice.end]) orelse
        return error.CertificateHasUnrecognizedAlgorithm;
}

fn verifyRsa(
    comptime Hash: type,
    message: []const u8,
    sig: []const u8,
    pub_key_algo: AlgorithmCategory,
    pub_key: []const u8,
) !void {
    if (pub_key_algo != .rsaEncryption) return error.CertificateSignatureAlgorithmMismatch;
    const pub_key_seq = try der.parseElement(pub_key, 0);
    if (pub_key_seq.identifier.tag != .sequence) return error.CertificateFieldHasWrongDataType;
    const modulus_elem = try der.parseElement(pub_key, pub_key_seq.slice.start);
    if (modulus_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
    const exponent_elem = try der.parseElement(pub_key, modulus_elem.slice.end);
    if (exponent_elem.identifier.tag != .integer) return error.CertificateFieldHasWrongDataType;
    // Skip over meaningless zeroes in the modulus.
    const modulus_raw = pub_key[modulus_elem.slice.start..modulus_elem.slice.end];
    const modulus_offset = for (modulus_raw) |byte, i| {
        if (byte != 0) break i;
    } else modulus_raw.len;
    const modulus = modulus_raw[modulus_offset..];
    const exponent = pub_key[exponent_elem.slice.start..exponent_elem.slice.end];
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

pub fn checkVersion(bytes: []const u8, version: der.Element) !void {
    if (@bitCast(u8, version.identifier) != 0xa0 or
        !mem.eql(u8, bytes[version.slice.start..version.slice.end], "\x02\x01\x02"))
    {
        return error.UnsupportedCertificateVersion;
    }
}

const std = @import("../std.zig");
const crypto = std.crypto;
const mem = std.mem;
const der = std.crypto.der;
const Certificate = @This();

test {
    _ = Bundle;
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
