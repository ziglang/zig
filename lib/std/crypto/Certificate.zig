buffer: []const u8,
index: u32,

pub const Bundle = @import("Certificate/Bundle.zig");

pub const Version = enum { v1, v2, v3 };

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
    md2WithRSAEncryption,
    md5WithRSAEncryption,
    curveEd25519,

    pub const map = std.StaticStringMap(Algorithm).initComptime(.{
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x05 }, .sha1WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B }, .sha256WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0C }, .sha384WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0D }, .sha512WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0E }, .sha224WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x01 }, .ecdsa_with_SHA224 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02 }, .ecdsa_with_SHA256 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x03 }, .ecdsa_with_SHA384 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x04 }, .ecdsa_with_SHA512 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x02 }, .md2WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x04 }, .md5WithRSAEncryption },
        .{ &[_]u8{ 0x2B, 0x65, 0x70 }, .curveEd25519 },
    });

    pub fn Hash(comptime algorithm: Algorithm) type {
        return switch (algorithm) {
            .sha1WithRSAEncryption => crypto.hash.Sha1,
            .ecdsa_with_SHA224, .sha224WithRSAEncryption => crypto.hash.sha2.Sha224,
            .ecdsa_with_SHA256, .sha256WithRSAEncryption => crypto.hash.sha2.Sha256,
            .ecdsa_with_SHA384, .sha384WithRSAEncryption => crypto.hash.sha2.Sha384,
            .ecdsa_with_SHA512, .sha512WithRSAEncryption, .curveEd25519 => crypto.hash.sha2.Sha512,
            .md2WithRSAEncryption => @compileError("unimplemented"),
            .md5WithRSAEncryption => crypto.hash.Md5,
        };
    }
};

pub const AlgorithmCategory = enum {
    rsaEncryption,
    X9_62_id_ecPublicKey,
    curveEd25519,

    pub const map = std.StaticStringMap(AlgorithmCategory).initComptime(.{
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01 }, .rsaEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01 }, .X9_62_id_ecPublicKey },
        .{ &[_]u8{ 0x2B, 0x65, 0x70 }, .curveEd25519 },
    });
};

pub const Attribute = enum {
    commonName,
    serialNumber,
    countryName,
    localityName,
    stateOrProvinceName,
    streetAddress,
    organizationName,
    organizationalUnitName,
    postalCode,
    organizationIdentifier,
    pkcs9_emailAddress,
    domainComponent,

    pub const map = std.StaticStringMap(Attribute).initComptime(.{
        .{ &[_]u8{ 0x55, 0x04, 0x03 }, .commonName },
        .{ &[_]u8{ 0x55, 0x04, 0x05 }, .serialNumber },
        .{ &[_]u8{ 0x55, 0x04, 0x06 }, .countryName },
        .{ &[_]u8{ 0x55, 0x04, 0x07 }, .localityName },
        .{ &[_]u8{ 0x55, 0x04, 0x08 }, .stateOrProvinceName },
        .{ &[_]u8{ 0x55, 0x04, 0x09 }, .streetAddress },
        .{ &[_]u8{ 0x55, 0x04, 0x0A }, .organizationName },
        .{ &[_]u8{ 0x55, 0x04, 0x0B }, .organizationalUnitName },
        .{ &[_]u8{ 0x55, 0x04, 0x11 }, .postalCode },
        .{ &[_]u8{ 0x55, 0x04, 0x61 }, .organizationIdentifier },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01 }, .pkcs9_emailAddress },
        .{ &[_]u8{ 0x09, 0x92, 0x26, 0x89, 0x93, 0xF2, 0x2C, 0x64, 0x01, 0x19 }, .domainComponent },
    });
};

pub const NamedCurve = enum {
    secp384r1,
    secp521r1,
    X9_62_prime256v1,

    pub const map = std.StaticStringMap(NamedCurve).initComptime(.{
        .{ &[_]u8{ 0x2B, 0x81, 0x04, 0x00, 0x22 }, .secp384r1 },
        .{ &[_]u8{ 0x2B, 0x81, 0x04, 0x00, 0x23 }, .secp521r1 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07 }, .X9_62_prime256v1 },
    });

    pub fn Curve(comptime curve: NamedCurve) type {
        return switch (curve) {
            .X9_62_prime256v1 => crypto.ecc.P256,
            .secp384r1 => crypto.ecc.P384,
            .secp521r1 => @compileError("unimplemented"),
        };
    }
};

pub const ExtensionId = enum {
    subject_key_identifier,
    key_usage,
    private_key_usage_period,
    subject_alt_name,
    issuer_alt_name,
    basic_constraints,
    crl_number,
    certificate_policies,
    authority_key_identifier,
    msCertsrvCAVersion,
    commonName,
    ext_key_usage,
    crl_distribution_points,
    info_access,
    entrustVersInfo,
    enroll_certtype,
    pe_logotype,
    netscape_cert_type,
    netscape_comment,

    pub const map = std.StaticStringMap(ExtensionId).initComptime(.{
        .{ &[_]u8{ 0x55, 0x04, 0x03 }, .commonName },
        .{ &[_]u8{ 0x55, 0x1D, 0x01 }, .authority_key_identifier },
        .{ &[_]u8{ 0x55, 0x1D, 0x07 }, .subject_alt_name },
        .{ &[_]u8{ 0x55, 0x1D, 0x0E }, .subject_key_identifier },
        .{ &[_]u8{ 0x55, 0x1D, 0x0F }, .key_usage },
        .{ &[_]u8{ 0x55, 0x1D, 0x0A }, .basic_constraints },
        .{ &[_]u8{ 0x55, 0x1D, 0x10 }, .private_key_usage_period },
        .{ &[_]u8{ 0x55, 0x1D, 0x11 }, .subject_alt_name },
        .{ &[_]u8{ 0x55, 0x1D, 0x12 }, .issuer_alt_name },
        .{ &[_]u8{ 0x55, 0x1D, 0x13 }, .basic_constraints },
        .{ &[_]u8{ 0x55, 0x1D, 0x14 }, .crl_number },
        .{ &[_]u8{ 0x55, 0x1D, 0x1F }, .crl_distribution_points },
        .{ &[_]u8{ 0x55, 0x1D, 0x20 }, .certificate_policies },
        .{ &[_]u8{ 0x55, 0x1D, 0x23 }, .authority_key_identifier },
        .{ &[_]u8{ 0x55, 0x1D, 0x25 }, .ext_key_usage },
        .{ &[_]u8{ 0x2B, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x15, 0x01 }, .msCertsrvCAVersion },
        .{ &[_]u8{ 0x2B, 0x06, 0x01, 0x05, 0x05, 0x07, 0x01, 0x01 }, .info_access },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF6, 0x7D, 0x07, 0x41, 0x00 }, .entrustVersInfo },
        .{ &[_]u8{ 0x2b, 0x06, 0x01, 0x04, 0x01, 0x82, 0x37, 0x14, 0x02 }, .enroll_certtype },
        .{ &[_]u8{ 0x2b, 0x06, 0x01, 0x05, 0x05, 0x07, 0x01, 0x0c }, .pe_logotype },
        .{ &[_]u8{ 0x60, 0x86, 0x48, 0x01, 0x86, 0xf8, 0x42, 0x01, 0x01 }, .netscape_cert_type },
        .{ &[_]u8{ 0x60, 0x86, 0x48, 0x01, 0x86, 0xf8, 0x42, 0x01, 0x0d }, .netscape_comment },
    });
};

pub const GeneralNameTag = enum(u5) {
    otherName = 0,
    rfc822Name = 1,
    dNSName = 2,
    x400Address = 3,
    directoryName = 4,
    ediPartyName = 5,
    uniformResourceIdentifier = 6,
    iPAddress = 7,
    registeredID = 8,
    _,
};

pub const Parsed = struct {
    certificate: Certificate,
    issuer_slice: Slice,
    subject_slice: Slice,
    common_name_slice: Slice,
    signature_slice: Slice,
    signature_algorithm: Algorithm,
    pub_key_algo: PubKeyAlgo,
    pub_key_slice: Slice,
    message_slice: Slice,
    subject_alt_name_slice: Slice,
    validity: Validity,
    version: Version,

    pub const PubKeyAlgo = union(AlgorithmCategory) {
        rsaEncryption: void,
        X9_62_id_ecPublicKey: NamedCurve,
        curveEd25519: void,
    };

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

    pub fn pubKeySigAlgo(p: Parsed) []const u8 {
        return p.slice(p.pub_key_signature_algorithm_slice);
    }

    pub fn message(p: Parsed) []const u8 {
        return p.slice(p.message_slice);
    }

    pub fn subjectAltName(p: Parsed) []const u8 {
        return p.slice(p.subject_alt_name_slice);
    }

    pub const VerifyError = error{
        CertificateIssuerMismatch,
        CertificateNotYetValid,
        CertificateExpired,
        CertificateSignatureAlgorithmUnsupported,
        CertificateSignatureAlgorithmMismatch,
        CertificateFieldHasInvalidLength,
        CertificateFieldHasWrongDataType,
        CertificatePublicKeyInvalid,
        CertificateSignatureInvalidLength,
        CertificateSignatureInvalid,
        CertificateSignatureUnsupportedBitCount,
        CertificateSignatureNamedCurveUnsupported,
    };

    /// This function verifies:
    ///  * That the subject's issuer is indeed the provided issuer.
    ///  * The time validity of the subject.
    ///  * The signature.
    pub fn verify(parsed_subject: Parsed, parsed_issuer: Parsed, now_sec: i64) VerifyError!void {
        // Check that the subject's issuer name matches the issuer's
        // subject name.
        if (!mem.eql(u8, parsed_subject.issuer(), parsed_issuer.subject())) {
            return error.CertificateIssuerMismatch;
        }

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

            inline .ecdsa_with_SHA224,
            .ecdsa_with_SHA256,
            .ecdsa_with_SHA384,
            .ecdsa_with_SHA512,
            => |algorithm| return verify_ecdsa(
                algorithm.Hash(),
                parsed_subject.message(),
                parsed_subject.signature(),
                parsed_issuer.pub_key_algo,
                parsed_issuer.pubKey(),
            ),

            .md2WithRSAEncryption, .md5WithRSAEncryption => {
                return error.CertificateSignatureAlgorithmUnsupported;
            },

            .curveEd25519 => return verifyEd25519(
                parsed_subject.message(),
                parsed_subject.signature(),
                parsed_issuer.pub_key_algo,
                parsed_issuer.pubKey(),
            ),
        }
    }

    pub const VerifyHostNameError = error{
        CertificateHostMismatch,
        CertificateFieldHasInvalidLength,
    };

    pub fn verifyHostName(parsed_subject: Parsed, host_name: []const u8) VerifyHostNameError!void {
        // If the Subject Alternative Names extension is present, this is
        // what to check. Otherwise, only the common name is checked.
        const subject_alt_name = parsed_subject.subjectAltName();
        if (subject_alt_name.len == 0) {
            if (checkHostName(host_name, parsed_subject.commonName())) {
                return;
            } else {
                return error.CertificateHostMismatch;
            }
        }

        const general_names = try der.Element.parse(subject_alt_name, 0);
        var name_i = general_names.slice.start;
        while (name_i < general_names.slice.end) {
            const general_name = try der.Element.parse(subject_alt_name, name_i);
            name_i = general_name.slice.end;
            switch (@as(GeneralNameTag, @enumFromInt(@intFromEnum(general_name.identifier.tag)))) {
                .dNSName => {
                    const dns_name = subject_alt_name[general_name.slice.start..general_name.slice.end];
                    if (checkHostName(host_name, dns_name)) return;
                },
                else => {},
            }
        }

        return error.CertificateHostMismatch;
    }

    // Check hostname according to RFC2818 specification:
    //
    // If more than one identity of a given type is present in
    // the certificate (e.g., more than one DNSName name, a match in any one
    // of the set is considered acceptable.) Names may contain the wildcard
    // character * which is considered to match any single domain name
    // component or component fragment. E.g., *.a.com matches foo.a.com but
    // not bar.foo.a.com. f*.com matches foo.com but not bar.com.
    fn checkHostName(host_name: []const u8, dns_name: []const u8) bool {
        if (std.ascii.eqlIgnoreCase(dns_name, host_name)) {
            return true; // exact match
        }

        var it_host = std.mem.splitScalar(u8, host_name, '.');
        var it_dns = std.mem.splitScalar(u8, dns_name, '.');

        const len_match = while (true) {
            const host = it_host.next();
            const dns = it_dns.next();

            if (host == null or dns == null) {
                break host == null and dns == null;
            }

            // If not a wildcard and they dont
            // match then there is no match.
            if (mem.eql(u8, dns.?, "*") == false and std.ascii.eqlIgnoreCase(dns.?, host.?) == false) {
                return false;
            }
        };

        // If the components are not the same
        // length then there is no match.
        return len_match;
    }
};

test "Parsed.checkHostName" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(true, Parsed.checkHostName("ziglang.org", "ziglang.org"));
    try expectEqual(true, Parsed.checkHostName("bar.ziglang.org", "*.ziglang.org"));
    try expectEqual(false, Parsed.checkHostName("foo.bar.ziglang.org", "*.ziglang.org"));
    try expectEqual(false, Parsed.checkHostName("ziglang.org", "zig*.org"));
    try expectEqual(false, Parsed.checkHostName("lang.org", "zig*.org"));
    // host name check should be case insensitive
    try expectEqual(true, Parsed.checkHostName("ziglang.org", "Ziglang.org"));
    try expectEqual(true, Parsed.checkHostName("bar.ziglang.org", "*.Ziglang.ORG"));
}

pub const ParseError = der.Element.ParseElementError || ParseVersionError || ParseTimeError || ParseEnumError || ParseBitStringError;

pub fn parse(cert: Certificate) ParseError!Parsed {
    const cert_bytes = cert.buffer;
    const certificate = try der.Element.parse(cert_bytes, cert.index);
    const tbs_certificate = try der.Element.parse(cert_bytes, certificate.slice.start);
    const version_elem = try der.Element.parse(cert_bytes, tbs_certificate.slice.start);
    const version = try parseVersion(cert_bytes, version_elem);
    const serial_number = if (@as(u8, @bitCast(version_elem.identifier)) == 0xa0)
        try der.Element.parse(cert_bytes, version_elem.slice.end)
    else
        version_elem;
    // RFC 5280, section 4.1.2.3:
    // "This field MUST contain the same algorithm identifier as
    // the signatureAlgorithm field in the sequence Certificate."
    const tbs_signature = try der.Element.parse(cert_bytes, serial_number.slice.end);
    const issuer = try der.Element.parse(cert_bytes, tbs_signature.slice.end);
    const validity = try der.Element.parse(cert_bytes, issuer.slice.end);
    const not_before = try der.Element.parse(cert_bytes, validity.slice.start);
    const not_before_utc = try parseTime(cert, not_before);
    const not_after = try der.Element.parse(cert_bytes, not_before.slice.end);
    const not_after_utc = try parseTime(cert, not_after);
    const subject = try der.Element.parse(cert_bytes, validity.slice.end);

    const pub_key_info = try der.Element.parse(cert_bytes, subject.slice.end);
    const pub_key_signature_algorithm = try der.Element.parse(cert_bytes, pub_key_info.slice.start);
    const pub_key_algo_elem = try der.Element.parse(cert_bytes, pub_key_signature_algorithm.slice.start);
    const pub_key_algo_tag = try parseAlgorithmCategory(cert_bytes, pub_key_algo_elem);
    var pub_key_algo: Parsed.PubKeyAlgo = undefined;
    switch (pub_key_algo_tag) {
        .rsaEncryption => {
            pub_key_algo = .{ .rsaEncryption = {} };
        },
        .X9_62_id_ecPublicKey => {
            // RFC 5480 Section 2.1.1.1 Named Curve
            // ECParameters ::= CHOICE {
            //   namedCurve         OBJECT IDENTIFIER
            //   -- implicitCurve   NULL
            //   -- specifiedCurve  SpecifiedECDomain
            // }
            const params_elem = try der.Element.parse(cert_bytes, pub_key_algo_elem.slice.end);
            const named_curve = try parseNamedCurve(cert_bytes, params_elem);
            pub_key_algo = .{ .X9_62_id_ecPublicKey = named_curve };
        },
        .curveEd25519 => {
            pub_key_algo = .{ .curveEd25519 = {} };
        },
    }
    const pub_key_elem = try der.Element.parse(cert_bytes, pub_key_signature_algorithm.slice.end);
    const pub_key = try parseBitString(cert, pub_key_elem);

    var common_name = der.Element.Slice.empty;
    var name_i = subject.slice.start;
    while (name_i < subject.slice.end) {
        const rdn = try der.Element.parse(cert_bytes, name_i);
        var rdn_i = rdn.slice.start;
        while (rdn_i < rdn.slice.end) {
            const atav = try der.Element.parse(cert_bytes, rdn_i);
            var atav_i = atav.slice.start;
            while (atav_i < atav.slice.end) {
                const ty_elem = try der.Element.parse(cert_bytes, atav_i);
                const val = try der.Element.parse(cert_bytes, ty_elem.slice.end);
                atav_i = val.slice.end;
                const ty = parseAttribute(cert_bytes, ty_elem) catch |err| switch (err) {
                    error.CertificateHasUnrecognizedObjectId => continue,
                    else => |e| return e,
                };
                switch (ty) {
                    .commonName => common_name = val.slice,
                    else => {},
                }
            }
            rdn_i = atav.slice.end;
        }
        name_i = rdn.slice.end;
    }

    const sig_algo = try der.Element.parse(cert_bytes, tbs_certificate.slice.end);
    const algo_elem = try der.Element.parse(cert_bytes, sig_algo.slice.start);
    const signature_algorithm = try parseAlgorithm(cert_bytes, algo_elem);
    const sig_elem = try der.Element.parse(cert_bytes, sig_algo.slice.end);
    const signature = try parseBitString(cert, sig_elem);

    // Extensions
    var subject_alt_name_slice = der.Element.Slice.empty;
    ext: {
        if (version == .v1)
            break :ext;

        if (pub_key_info.slice.end >= tbs_certificate.slice.end)
            break :ext;

        const outer_extensions = try der.Element.parse(cert_bytes, pub_key_info.slice.end);
        if (outer_extensions.identifier.tag != .bitstring)
            break :ext;

        const extensions = try der.Element.parse(cert_bytes, outer_extensions.slice.start);

        var ext_i = extensions.slice.start;
        while (ext_i < extensions.slice.end) {
            const extension = try der.Element.parse(cert_bytes, ext_i);
            ext_i = extension.slice.end;
            const oid_elem = try der.Element.parse(cert_bytes, extension.slice.start);
            const ext_id = parseExtensionId(cert_bytes, oid_elem) catch |err| switch (err) {
                error.CertificateHasUnrecognizedObjectId => continue,
                else => |e| return e,
            };
            const critical_elem = try der.Element.parse(cert_bytes, oid_elem.slice.end);
            const ext_bytes_elem = if (critical_elem.identifier.tag != .boolean)
                critical_elem
            else
                try der.Element.parse(cert_bytes, critical_elem.slice.end);
            switch (ext_id) {
                .subject_alt_name => subject_alt_name_slice = ext_bytes_elem.slice,
                else => continue,
            }
        }
    }

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
        .subject_alt_name_slice = subject_alt_name_slice,
        .version = version,
    };
}

pub fn verify(subject: Certificate, issuer: Certificate, now_sec: i64) !void {
    const parsed_subject = try subject.parse();
    const parsed_issuer = try issuer.parse();
    return parsed_subject.verify(parsed_issuer, now_sec);
}

pub fn contents(cert: Certificate, elem: der.Element) []const u8 {
    return cert.buffer[elem.slice.start..elem.slice.end];
}

pub const ParseBitStringError = error{ CertificateFieldHasWrongDataType, CertificateHasInvalidBitString };

pub fn parseBitString(cert: Certificate, elem: der.Element) !der.Element.Slice {
    if (elem.identifier.tag != .bitstring) return error.CertificateFieldHasWrongDataType;
    if (cert.buffer[elem.slice.start] != 0) return error.CertificateHasInvalidBitString;
    return .{ .start = elem.slice.start + 1, .end = elem.slice.end };
}

pub const ParseTimeError = error{ CertificateTimeInvalid, CertificateFieldHasWrongDataType };

/// Returns number of seconds since epoch.
pub fn parseTime(cert: Certificate, elem: der.Element) ParseTimeError!u64 {
    const bytes = cert.contents(elem);
    switch (elem.identifier.tag) {
        .utc_time => {
            // Example: "YYMMDD000000Z"
            if (bytes.len != 13)
                return error.CertificateTimeInvalid;
            if (bytes[12] != 'Z')
                return error.CertificateTimeInvalid;

            return Date.toSeconds(.{
                .year = @as(u16, 2000) + try parseTimeDigits(bytes[0..2], 0, 99),
                .month = try parseTimeDigits(bytes[2..4], 1, 12),
                .day = try parseTimeDigits(bytes[4..6], 1, 31),
                .hour = try parseTimeDigits(bytes[6..8], 0, 23),
                .minute = try parseTimeDigits(bytes[8..10], 0, 59),
                .second = try parseTimeDigits(bytes[10..12], 0, 59),
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
                .month = try parseTimeDigits(bytes[4..6], 1, 12),
                .day = try parseTimeDigits(bytes[6..8], 1, 31),
                .hour = try parseTimeDigits(bytes[8..10], 0, 23),
                .minute = try parseTimeDigits(bytes[10..12], 0, 59),
                .second = try parseTimeDigits(bytes[12..14], 0, 59),
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
                    @as(std.time.epoch.YearLeapKind, @enumFromInt(@intFromBool(is_leap))),
                    @as(std.time.epoch.Month, @enumFromInt(month)),
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

pub fn parseTimeDigits(text: *const [2]u8, min: u8, max: u8) !u8 {
    const result = if (use_vectors) result: {
        const nn: @Vector(2, u16) = .{ text[0], text[1] };
        const zero: @Vector(2, u16) = .{ '0', '0' };
        const mm: @Vector(2, u16) = .{ 10, 1 };
        break :result @reduce(.Add, (nn -% zero) *% mm);
    } else std.fmt.parseInt(u8, text, 10) catch return error.CertificateTimeInvalid;
    if (result < min) return error.CertificateTimeInvalid;
    if (result > max) return error.CertificateTimeInvalid;
    return @truncate(result);
}

test parseTimeDigits {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(u8, 0), try parseTimeDigits("00", 0, 99));
    try expectEqual(@as(u8, 99), try parseTimeDigits("99", 0, 99));
    try expectEqual(@as(u8, 42), try parseTimeDigits("42", 0, 99));

    const expectError = std.testing.expectError;
    try expectError(error.CertificateTimeInvalid, parseTimeDigits("13", 1, 12));
    try expectError(error.CertificateTimeInvalid, parseTimeDigits("00", 1, 12));
    try expectError(error.CertificateTimeInvalid, parseTimeDigits("Di", 0, 99));
}

pub fn parseYear4(text: *const [4]u8) !u16 {
    const result = if (use_vectors) result: {
        const nnnn: @Vector(4, u32) = .{ text[0], text[1], text[2], text[3] };
        const zero: @Vector(4, u32) = .{ '0', '0', '0', '0' };
        const mmmm: @Vector(4, u32) = .{ 1000, 100, 10, 1 };
        break :result @reduce(.Add, (nnnn -% zero) *% mmmm);
    } else std.fmt.parseInt(u16, text, 10) catch return error.CertificateTimeInvalid;
    if (result > 9999) return error.CertificateTimeInvalid;
    return @truncate(result);
}

test parseYear4 {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(u16, 0), try parseYear4("0000"));
    try expectEqual(@as(u16, 9999), try parseYear4("9999"));
    try expectEqual(@as(u16, 1988), try parseYear4("1988"));

    const expectError = std.testing.expectError;
    try expectError(error.CertificateTimeInvalid, parseYear4("999b"));
    try expectError(error.CertificateTimeInvalid, parseYear4("crap"));
    try expectError(error.CertificateTimeInvalid, parseYear4("r:bQ"));
}

pub fn parseAlgorithm(bytes: []const u8, element: der.Element) ParseEnumError!Algorithm {
    return parseEnum(Algorithm, bytes, element);
}

pub fn parseAlgorithmCategory(bytes: []const u8, element: der.Element) ParseEnumError!AlgorithmCategory {
    return parseEnum(AlgorithmCategory, bytes, element);
}

pub fn parseAttribute(bytes: []const u8, element: der.Element) ParseEnumError!Attribute {
    return parseEnum(Attribute, bytes, element);
}

pub fn parseNamedCurve(bytes: []const u8, element: der.Element) ParseEnumError!NamedCurve {
    return parseEnum(NamedCurve, bytes, element);
}

pub fn parseExtensionId(bytes: []const u8, element: der.Element) ParseEnumError!ExtensionId {
    return parseEnum(ExtensionId, bytes, element);
}

pub const ParseEnumError = error{ CertificateFieldHasWrongDataType, CertificateHasUnrecognizedObjectId };

fn parseEnum(comptime E: type, bytes: []const u8, element: der.Element) ParseEnumError!E {
    if (element.identifier.tag != .object_identifier)
        return error.CertificateFieldHasWrongDataType;
    const oid_bytes = bytes[element.slice.start..element.slice.end];
    return E.map.get(oid_bytes) orelse return error.CertificateHasUnrecognizedObjectId;
}

pub const ParseVersionError = error{ UnsupportedCertificateVersion, CertificateFieldHasInvalidLength };

pub fn parseVersion(bytes: []const u8, version_elem: der.Element) ParseVersionError!Version {
    if (@as(u8, @bitCast(version_elem.identifier)) != 0xa0)
        return .v1;

    if (version_elem.slice.end - version_elem.slice.start != 3)
        return error.CertificateFieldHasInvalidLength;

    const encoded_version = bytes[version_elem.slice.start..version_elem.slice.end];

    if (mem.eql(u8, encoded_version, "\x02\x01\x02")) {
        return .v3;
    } else if (mem.eql(u8, encoded_version, "\x02\x01\x01")) {
        return .v2;
    } else if (mem.eql(u8, encoded_version, "\x02\x01\x00")) {
        return .v1;
    }

    return error.UnsupportedCertificateVersion;
}

fn verifyRsa(
    comptime Hash: type,
    message: []const u8,
    sig: []const u8,
    pub_key_algo: Parsed.PubKeyAlgo,
    pub_key: []const u8,
) !void {
    if (pub_key_algo != .rsaEncryption) return error.CertificateSignatureAlgorithmMismatch;
    const pk_components = try rsa.PublicKey.parseDer(pub_key);
    const exponent = pk_components.exponent;
    const modulus = pk_components.modulus;
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
        inline 128, 256, 384, 512 => |modulus_len| {
            const ps_len = modulus_len - (hash_der.len + msg_hashed.len) - 3;
            const em: [modulus_len]u8 =
                [2]u8{ 0, 1 } ++
                ([1]u8{0xff} ** ps_len) ++
                [1]u8{0} ++
                hash_der ++
                msg_hashed;

            const public_key = rsa.PublicKey.fromBytes(exponent, modulus) catch return error.CertificateSignatureInvalid;
            const em_dec = rsa.encrypt(modulus_len, sig[0..modulus_len].*, public_key) catch |err| switch (err) {
                error.MessageTooLong => unreachable,
            };

            if (!mem.eql(u8, &em, &em_dec)) {
                return error.CertificateSignatureInvalid;
            }
        },
        else => {
            return error.CertificateSignatureUnsupportedBitCount;
        },
    }
}

fn verify_ecdsa(
    comptime Hash: type,
    message: []const u8,
    encoded_sig: []const u8,
    pub_key_algo: Parsed.PubKeyAlgo,
    sec1_pub_key: []const u8,
) !void {
    const sig_named_curve = switch (pub_key_algo) {
        .X9_62_id_ecPublicKey => |named_curve| named_curve,
        else => return error.CertificateSignatureAlgorithmMismatch,
    };

    switch (sig_named_curve) {
        .secp521r1 => {
            return error.CertificateSignatureNamedCurveUnsupported;
        },
        inline .X9_62_prime256v1,
        .secp384r1,
        => |curve| {
            const Ecdsa = crypto.sign.ecdsa.Ecdsa(curve.Curve(), Hash);
            const sig = Ecdsa.Signature.fromDer(encoded_sig) catch |err| switch (err) {
                error.InvalidEncoding => return error.CertificateSignatureInvalid,
            };
            const pub_key = Ecdsa.PublicKey.fromSec1(sec1_pub_key) catch |err| switch (err) {
                error.InvalidEncoding => return error.CertificateSignatureInvalid,
                error.NonCanonical => return error.CertificateSignatureInvalid,
                error.NotSquare => return error.CertificateSignatureInvalid,
            };
            sig.verify(message, pub_key) catch |err| switch (err) {
                error.IdentityElement => return error.CertificateSignatureInvalid,
                error.NonCanonical => return error.CertificateSignatureInvalid,
                error.SignatureVerificationFailed => return error.CertificateSignatureInvalid,
            };
        },
    }
}

fn verifyEd25519(
    message: []const u8,
    encoded_sig: []const u8,
    pub_key_algo: Parsed.PubKeyAlgo,
    encoded_pub_key: []const u8,
) !void {
    if (pub_key_algo != .curveEd25519) return error.CertificateSignatureAlgorithmMismatch;
    const Ed25519 = crypto.sign.Ed25519;
    if (encoded_sig.len != Ed25519.Signature.encoded_length) return error.CertificateSignatureInvalid;
    const sig = Ed25519.Signature.fromBytes(encoded_sig[0..Ed25519.Signature.encoded_length].*);
    if (encoded_pub_key.len != Ed25519.PublicKey.encoded_length) return error.CertificateSignatureInvalid;
    const pub_key = Ed25519.PublicKey.fromBytes(encoded_pub_key[0..Ed25519.PublicKey.encoded_length].*) catch |err| switch (err) {
        error.NonCanonical => return error.CertificateSignatureInvalid,
    };
    sig.verify(message, pub_key) catch |err| switch (err) {
        error.IdentityElement => return error.CertificateSignatureInvalid,
        error.NonCanonical => return error.CertificateSignatureInvalid,
        error.SignatureVerificationFailed => return error.CertificateSignatureInvalid,
        error.InvalidEncoding => return error.CertificateSignatureInvalid,
        error.WeakPublicKey => return error.CertificateSignatureInvalid,
    };
}

const std = @import("../std.zig");
const crypto = std.crypto;
const mem = std.mem;
const Certificate = @This();

pub const der = struct {
    pub const Class = enum(u2) {
        universal,
        application,
        context_specific,
        private,
    };

    pub const PC = enum(u1) {
        primitive,
        constructed,
    };

    pub const Identifier = packed struct(u8) {
        tag: Tag,
        pc: PC,
        class: Class,
    };

    pub const Tag = enum(u5) {
        boolean = 1,
        integer = 2,
        bitstring = 3,
        octetstring = 4,
        null = 5,
        object_identifier = 6,
        sequence = 16,
        sequence_of = 17,
        utc_time = 23,
        generalized_time = 24,
        _,
    };

    pub const Element = struct {
        identifier: Identifier,
        slice: Slice,

        pub const Slice = struct {
            start: u32,
            end: u32,

            pub const empty: Slice = .{ .start = 0, .end = 0 };
        };

        pub const ParseElementError = error{CertificateFieldHasInvalidLength};

        pub fn parse(bytes: []const u8, index: u32) ParseElementError!Element {
            var i = index;
            const identifier = @as(Identifier, @bitCast(bytes[i]));
            i += 1;
            const size_byte = bytes[i];
            i += 1;
            if ((size_byte >> 7) == 0) {
                return .{
                    .identifier = identifier,
                    .slice = .{
                        .start = i,
                        .end = i + size_byte,
                    },
                };
            }

            const len_size = @as(u7, @truncate(size_byte));
            if (len_size > @sizeOf(u32)) {
                return error.CertificateFieldHasInvalidLength;
            }

            const end_i = i + len_size;
            var long_form_size: u32 = 0;
            while (i < end_i) : (i += 1) {
                long_form_size = (long_form_size << 8) | bytes[i];
            }

            return .{
                .identifier = identifier,
                .slice = .{
                    .start = i,
                    .end = i + long_form_size,
                },
            };
        }
    };
};

test {
    _ = Bundle;
}

pub const rsa = struct {
    const max_modulus_bits = 4096;
    const Uint = std.crypto.ff.Uint(max_modulus_bits);
    const Modulus = std.crypto.ff.Modulus(max_modulus_bits);
    const Fe = Modulus.Fe;

    pub const PSSSignature = struct {
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
            // Even then, this check is only there for paranoia. In the context of TLS certificates, emBit cannot exceed 4096.
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
};

const use_vectors = @import("builtin").zig_backend != .stage2_x86_64;
