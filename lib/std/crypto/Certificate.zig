//! RFC 5280: Internet X.509 Public Key Infrastructure (PKI) Certificate
//!
//! Certificate Revocation Lists (CRLs) currently unimplemented
//! because they need frequent updates and there is no standard
//! installation location.

version: Version,
/// The To Be Signed part of the certificate.
/// This is the start of serial number to end of extensions.
tbs_bytes: []const u8,
/// Unique for each certificate issued by a given CA
serial_number: []const u8,
issuer: Name,
validity: Validity,
subject: Name,
pub_key: PubKey,

// Extensions. These are still left unimplemented from RFC 5280:
//   - Authority key identifier
//   - Policy constraints
//   - Policy mappings
//   - Issuer alternative name
//   - Subject directory attributes
//   - Name constraints
//   - CRL distribution points
//   - Inhibit anyPolicy
//   - Freshest CRL
subject_key_identifier: ?[]const u8 = null,
key_usage: KeyUsage = .{},
basic_constraints: BasicConstraints = .{},
/// See `policiesIter`.
policies: ?[]const u8 = null,
key_usage_ext: KeyUsageExt = .{},
/// See `subjectAliasesIter`.
subject_aliases: ?[]const u8 = null,

/// Algorithm family and parameters.
/// Does NOT include signature's public key type.
signature_algo: Signature.Algorithm,
/// The type is not `Signature` because we cannot infer the type from the length becuase
/// different ECDSA curves have equal lengths.
signature: der.BitString,

pub const Flag = enum {
    ignore,
    set,
    set_or_null,

    pub fn verify(self: Flag, value: ?bool) bool {
        switch (self) {
            .ignore => {},
            .set => return value == true,
            .set_or_null => if (value) |v| return v,
        }
        return true;
    }
};

pub fn verifyHostName(sub: Cert, host_name: []const u8) !void {
    var iter = sub.subjectAliasesIter();
    if (iter.parser.bytes.len > 0) {
        while (try iter.next()) |alias| {
            if (checkHostName(host_name, alias)) return;
        }
    } else {
        if (checkHostName(host_name, sub.subject.common_name.data)) return;
    }

    return error.CertificateHostMismatch;
}

/// Check `host_name` matches `dns_name` with single-domain wildcard support
/// according to RFC 4952.
fn checkHostName(host_name: []const u8, dns_name: []const u8) bool {
    var it_host = std.mem.splitScalar(u8, host_name, '.');
    var it_dns = std.mem.splitScalar(u8, dns_name, '.');

    while (true) {
        const host = it_host.next();
        const dns = it_dns.next();
        // done?
        if (host == null and dns == null) return true;
        // len mismatch?
        if (host == null or dns == null) return false;
        // wildcard?
        if (std.mem.eql(u8, "*", dns.?)) continue;
        // match?
        if (!std.mem.eql(u8, host.?, dns.?)) return false;
    }
}

test checkHostName {
    try testing.expectEqual(true, checkHostName("foo.a.com", "*.a.com"));
    try testing.expectEqual(false, checkHostName("bar.foo.a.com", "*.a.com"));

    try testing.expectEqual(false, checkHostName("bar.com", "f*.com"));
    // rfc2818 says this should match, but rfc4952 disagrees.
    // since rfc4952 came later and CAs tend to follow it, prefer its rules
    try testing.expectEqual(false, checkHostName("foo.com", "f*.com"));
}

/// Creates references to `bytes` which must outlive returned `Cert`.
pub fn fromDer(bytes: []const u8) !Cert {
    var parser = der.Parser{ .bytes = bytes };
    var res = Cert{
        .version = undefined,
        .serial_number = undefined,
        .issuer = undefined,
        .validity = undefined,
        .subject = undefined,
        .pub_key = undefined,
        .tbs_bytes = undefined,
        .signature_algo = undefined,
        .signature = undefined,
    };

    {
        const cert = try parser.expectSequence();
        defer parser.seek(cert.slice.end);

        {
            const cert_tbs = try parser.expectSequence();
            defer parser.seek(cert_tbs.slice.end);
            res.tbs_bytes = parser.bytes[cert.slice.start..cert_tbs.slice.end];

            {
                const version_seq = try parser.expect(.context_specific, true, @enumFromInt(0));
                defer parser.seek(version_seq.slice.end);

                const version = try parser.expectInt(u8);
                res.version = @enumFromInt(version);
            }

            const serial_number = try parser.expectPrimitive(.integer);
            res.serial_number = parser.view(serial_number);
            res.signature_algo = try Signature.Algorithm.fromDer(&parser);

            res.issuer = try Name.fromDer(&parser);
            res.validity = try Validity.fromDer(&parser);
            res.subject = try Name.fromDer(&parser);
            res.pub_key = try PubKey.fromDer(&parser);

            while (parser.index != cert_tbs.slice.end) {
                const optional_ele = try parser.expect(.context_specific, null, null);
                defer parser.seek(optional_ele.slice.end);

                switch (@intFromEnum(optional_ele.identifier.tag)) {
                    1, 2 => {
                        // skip issuerUniqueID or subjectUniqueID
                        _ = try parser.expectBitstring();
                    },
                    3 => {
                        try parseExtensions(&res, &parser);
                    },
                    else => return error.InvalidOptionalField,
                }
            }
        }

        // this field MUST match the earlier `signature` field
        const sig_algo2 = try Signature.Algorithm.fromDer(&parser);
        if (!std.meta.eql(res.signature_algo, sig_algo2)) return error.SigAlgoMismatch;

        res.signature = try parser.expectBitstring();
    }

    return res;
}

fn parseExtensions(res: *Cert, parser: *der.Parser) !void {
    // the extensions we parse are focused on client-side validation
    const ExtensionTag = enum {
        // RFC 5280 extensions
        /// Fingerprint to identify CA's public key.
        authority_key_identifier,
        /// Fingerprint to identify public key (unused).
        subject_key_identifier,
        /// Purpose of key (see `KeyUsage`).
        key_usage,
        /// Policies that cert was issued under (domain verification, etc.) (unused).
        certificate_policies,
        /// Map of issuing CA policy considered equivalent to subject policy (unused).
        policy_mappings,
        /// Alternative names besides specified `subject`. Usually DNS entries.
        subject_alt_name,
        /// Alternative names besides specified `issuer` (unused).
        /// S4.2.1.7 states: Issuer alternative names are not
        /// processed as part of the certification path validation algorithm in
        /// Section 6.
        issuer_alt_name,
        /// Nationality of subject
        subject_directory_attributes,
        /// Identify if is CA and maximum depth of valid cert paths including this cert.
        basic_constraints,
        /// For CA certificates, indicates a name space within which all subject names in
        /// subsequent certificates in a certification path MUST be located (unused).
        name_constraints,
        /// For CA certificates, can be used to prohibit policy mapping or require
        /// that each certificate in a path contain an acceptable policy
        /// identifier.
        policy_constraints,
        /// Purpose of key (see `KeyUsageExt`).
        key_usage_ext,
        /// Where to find Certificate Revocation List (unused).
        crl_distribution_points,
        /// For CA certificates, indicates that the special anyPolicy OID is NOT
        /// considered an explicit match for other certificate policies.
        inhibit_anypolicy,

        unknown,

        pub const oids = std.StaticStringMap(@This()).initComptime(.{
            .{ &comptimeOid("2.5.29.1"), .authority_key_identifier }, // deprecated
            .{ &comptimeOid("2.5.29.14"), .subject_key_identifier },
            .{ &comptimeOid("2.5.29.15"), .key_usage },
            .{ &comptimeOid("2.5.29.17"), .subject_alt_name },
            .{ &comptimeOid("2.5.29.18"), .issuer_alt_name },
            .{ &comptimeOid("2.5.29.19"), .basic_constraints },
            .{ &comptimeOid("2.5.29.25"), .crl_distribution_points }, // deprecated
            .{ &comptimeOid("2.5.29.29"), .subject_directory_attributes },
            .{ &comptimeOid("2.5.29.30"), .name_constraints },
            .{ &comptimeOid("2.5.29.31"), .crl_distribution_points },
            .{ &comptimeOid("2.5.29.32"), .certificate_policies },
            .{ &comptimeOid("2.5.29.33"), .policy_mappings },
            .{ &comptimeOid("2.5.29.34"), .policy_constraints },
            .{ &comptimeOid("2.5.29.35"), .authority_key_identifier },
            .{ &comptimeOid("2.5.29.37"), .key_usage_ext },
            .{ &comptimeOid("2.5.29.54"), .inhibit_anypolicy },
        });
    };
    const extensions_seq = try parser.expectSequence();
    defer parser.seek(extensions_seq.slice.end);

    while (parser.index != extensions_seq.slice.end) {
        const extension_seq = try parser.expectSequence();
        defer parser.seek(extension_seq.slice.end);

        const oid = try parser.expectOid();
        const tag = ExtensionTag.oids.get(oid) orelse .unknown;
        const critical = parser.expectBool() catch |err| switch (err) {
            error.UnexpectedElement => false,
            else => return err,
        };
        const doc = try parser.expectPrimitive(.octetstring);
        const doc_bytes = parser.view(doc);
        var doc_parser = der.Parser{ .bytes = doc_bytes };
        switch (tag) {
            .key_usage => {
                res.key_usage = try KeyUsage.fromDer(doc_bytes);
            },
            .key_usage_ext => {
                res.key_usage_ext = try KeyUsageExt.fromDer(doc_bytes);
            },
            .subject_alt_name => {
                const seq = try doc_parser.expectSequence();
                res.subject_aliases = doc_parser.view(seq);
            },
            .basic_constraints => {
                res.basic_constraints = try BasicConstraints.fromDer(doc_bytes);
            },
            .subject_key_identifier => {
                const string = try doc_parser.expectPrimitive(.octetstring);
                res.subject_key_identifier = doc_parser.view(string);
            },
            .certificate_policies => {
                const seq = try doc_parser.expectSequence();
                res.policies = doc_parser.view(seq);
            },
            .authority_key_identifier, .policy_mappings, .issuer_alt_name, .subject_directory_attributes, .name_constraints, .policy_constraints, .crl_distribution_points, .inhibit_anypolicy, .unknown => {
                var buffer: [256]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buffer);
                oid_mod.decode(oid, stream.writer()) catch {};

                if (critical) {
                    log.err("critical unknown extension {s}", .{stream.getWritten()});
                    return error.UnimplementedCriticalExtension;
                } else if (tag == .unknown) {
                    log.debug("skipping unknown extension {s}", .{stream.getWritten()});
                }
            },
        }
    }
}

/// Validates:
///   - Key usage matches basic constraints.
///   - Signature algorithm is secure.
///   - Time validity.
pub fn validate(self: Cert, now_sec: i64) !void {
    if (self.key_usage.key_cert_sign and !self.basic_constraints.is_ca) return error.KeySignAndNotCA;
    try self.signature_algo.validate();
    // This check should optimally be at the end so that `Bundle.parseCert` does not add
    // certs that may be valid in the future but fail the above checks.
    //
    // Such certs would fail all `PathValidator.validate` checks.
    try self.validity.validate(now_sec);
}

pub const SubjectAliasesIter = struct {
    parser: der.Parser,

    /// Next dnsName (RFC 5280 S4.2.1.6)
    pub fn next(it: *@This()) !?[]const u8 {
        while (true) {
            const ele = it.parser.expect(.context_specific, null, null) catch |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            };
            switch (@intFromEnum(ele.identifier.tag)) {
                2 => return it.parser.view(ele),
                else => {
                    // We don't support the rest of the spec here since we currently only care
                    // about verifying HTTPS.
                },
            }
        }
        return null;
    }
};

pub fn subjectAliasesIter(c: Cert) SubjectAliasesIter {
    const bytes = if (c.subject_aliases) |b| b else "";
    return SubjectAliasesIter{ .parser = der.Parser{ .bytes = bytes } };
}

pub const Policy = struct {
    oid: []const u8,
    /// This field allows reporting to the user what qualifiers have been accepted.
    /// See `qualifiersIter`.
    qualifiers: ?[]const u8 = null,

    pub const any = Policy{ .oid = &comptimeOid("2.5.29.32.0") };

    pub const Qualifier = union(enum) {
        uri: DisplayText,
        notice: Notice,

        pub const Notice = struct {
            ref: ?[]const u8,
            text: ?[]const u8,
        };

        pub fn fromDer(parser: *der.Parser) !Qualifier {
            const tag = try parser.expectEnum(Tag);
            switch (tag) {
                .uri => {
                    const uri = try parser.expect(.universal, false, .string_ia5);
                    return .{ .uri = uri };
                },
                .notice => {
                    const seq = try parser.expectSequence();
                    defer parser.seek(seq.slice.end);

                    const next = try parser.expect(null, null, null);
                    switch (next.identifier.tag) {
                        .sequence => {},
                        .string_ia5,
                        .string_visible,
                        .string_bmp,
                        .string_utf8,
                        => {
                            const uri = try DisplayText.fromDer(parser);
                            return .{ .uri = uri };
                        },
                        else => return error.InvalidNotice,
                    }
                },
            }
        }

        const Tag = enum {
            uri,
            notice,

            pub const oids = std.StaticStringMap(@This()).initComptime(.{
                .{ &comptimeOid("1.3.6.1.5.5.7.2.1"), .uri },
                .{ &comptimeOid("1.3.6.1.5.5.7.2.2"), .notice },
            });
        };
    };

    pub const QualifiersIter = struct {
        parser: der.Parser,

        /// Next dnsName (RFC 5280 S4.2.1.6)
        pub fn next(it: *@This()) !?Qualifier {
            while (true) {
                const ele = it.parser.expect(.context_specific, null, null) catch |err| switch (err) {
                    error.EndOfStream => return null,
                    else => return err,
                };
                switch (@intFromEnum(ele.identifier.tag)) {
                    2 => return it.parser.view(ele),
                    else => {
                        // We don't support the rest of the spec here since we currently only care
                        // about verifying HTTPS.
                    },
                }
            }
            return null;
        }
    };

    pub fn qualifiersIter(self: Policy) QualifiersIter {
        const bytes = if (self.qualifiers) |b| b else "";
        return PoliciesIter{ .parser = der.Parser{ .bytes = bytes } };
    }

    pub fn fromDer(parser: *der.Parser) !Policy {
        const seq = try parser.expectSequence();
        defer parser.seek(seq.slice.end);

        const oid = try parser.expectOid();
        var qualifiers: ?[]const u8 = null;
        if (parser.index != seq.slice.end) {
            const seq2 = try parser.expectSequence();
            qualifiers = parser.view(seq2);
        }

        return Policy{ .oid = oid, .qualifiers = qualifiers };
    }
};

pub const PoliciesIter = struct {
    parser: der.Parser,

    pub fn next(it: *@This()) !?Policy {
        while (true) {
            return Policy.fromDer(&it.parser) catch |err| switch (err) {
                error.EndOfStream => return null,
                else => return err,
            };
        }
        return null;
    }
};

pub fn policiesIter(c: Cert) PoliciesIter {
    const bytes = if (c.policies) |b| b else "";
    return PoliciesIter{ .parser = der.Parser{ .bytes = bytes } };
}

inline fn fmtCert(cert: Cert) []const u8 {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    cert.print(writer) catch {};

    return stream.getWritten();
}

pub fn print(self: Cert, writer: anytype) !void {
    try writer.writeAll("Cert{ ");

    // Name + serial number = unique certificate.
    try writer.writeAll(" Issuer{ ");
    try self.issuer.print(writer);
    try writer.writeAll(" }");

    // spec says up to 20 bytes.
    try writer.writeAll(", SN: ");
    for (0..@min(20, self.serial_number.len)) |i| {
        try writer.print("{x:0>2}", .{self.serial_number[i]});
    }

    // Finally, this is useful for debugging.
    try writer.print(", Time: {d} to {d}", .{ self.validity.not_before, self.validity.not_after });

    try writer.writeAll(", Subject{ ");
    try self.subject.print(writer);
    // These fields are useful for tracking down the certificate on aggregators.
    if (self.subject_key_identifier) |s| {
        try writer.writeAll(", SKI: ");
        for (s) |c| {
            try writer.print("{x:0>2}", .{c});
        }
    }
    try writer.writeAll(" }");
    try writer.writeAll(" }");
}

const PubKeyTag = enum {
    rsa2048,
    rsa3072,
    rsa4096,
    ecdsa_p256,
    ecdsa_p384,
    ecdsa_secp256,
    ed25519,
};

pub const PubKey = union(PubKeyTag) {
    rsa2048: Rsa2048.PublicKey,
    rsa3072: Rsa3072.PublicKey,
    rsa4096: Rsa4096.PublicKey,
    ecdsa_p256: EcdsaP256.PublicKey,
    ecdsa_p384: EcdsaP384.PublicKey,
    ecdsa_secp256: EcdsaSecP256.PublicKey,
    ed25519: Ed25519.PublicKey,

    const Algo = enum {
        rsa,
        ecdsa,
        ed25519,

        pub const oids = std.StaticStringMap(Algo).initComptime(.{
            .{ &comptimeOid("1.2.840.113549.1.1.1"), .rsa },
            .{ &comptimeOid("1.2.840.10045.2.1"), .ecdsa },
            .{ &comptimeOid("1.3.101.112"), .ed25519 },
        });
    };

    pub fn fromDer(parser: *der.Parser) !PubKey {
        const seq = try parser.expectSequence();
        defer parser.seek(seq.slice.end);
        const seq2 = try parser.expectSequence();
        defer parser.seek(seq2.slice.end);

        const tag = try parser.expectEnum(Algo);
        switch (tag) {
            .rsa => {
                _ = try parser.expectPrimitive(.null);
                const bitstring = try parser.expectBitstring();
                if (bitstring.right_padding != 0) return error.InvalidKeyLength;

                var parser2 = der.Parser{ .bytes = bitstring.bytes };
                _ = try parser2.expectSequence();

                const mod = try rsa.parseModulus(&parser2);
                const elem = try parser2.expectPrimitive(.integer);
                const pub_exp = parser2.view(elem);
                return switch (mod.len * 8) {
                    2048 => return .{ .rsa2048 = try Rsa2048.PublicKey.fromBytes(mod, pub_exp) },
                    3072 => return .{ .rsa3072 = try Rsa3072.PublicKey.fromBytes(mod, pub_exp) },
                    4096 => return .{ .rsa4096 = try Rsa4096.PublicKey.fromBytes(mod, pub_exp) },
                    else => return error.InvalidRsaLength,
                };
            },
            .ecdsa => {
                const curve = try parser.expectEnum(NamedCurve);
                const bitstring = try parser.expectBitstring();
                if (bitstring.right_padding != 0) return error.InvalidKeyLength;

                return switch (curve) {
                    .prime256v1 => .{ .ecdsa_p256 = try EcdsaP256.PublicKey.fromSec1(bitstring.bytes) },
                    .secp384r1 => .{ .ecdsa_p384 = try EcdsaP384.PublicKey.fromSec1(bitstring.bytes) },
                    .secp521r1 => return error.CurveUnsupported,
                    .secp256k1 => .{ .ecdsa_secp256 = try EcdsaSecP256.PublicKey.fromSec1(bitstring.bytes) },
                };
            },
            .ed25519 => {
                _ = try parser.expectPrimitive(.null);
                const bitstring = try parser.expectBitstring();
                if (bitstring.right_padding != 0) return error.InvalidKeyLength;
                const expected_len = Ed25519.PublicKey.encoded_length;
                if (bitstring.bytes.len != expected_len) return error.InvalidKeyLength;
                const key = try Ed25519.PublicKey.fromBytes(bitstring.bytes[0..expected_len].*);

                return .{ .ed25519 = key };
            },
        }
    }
};

pub const Validity = struct {
    not_before: i64,
    not_after: i64,

    pub fn fromDer(parser: *der.Parser) !Validity {
        const seq = try parser.expectSequence();
        defer parser.seek(seq.slice.end);

        var res: Validity = undefined;
        res.not_before = try parser.expectDateTime();
        res.not_after = try parser.expectDateTime();
        return res;
    }

    pub fn validate(self: Validity, sec: i64) !void {
        if (sec < self.not_before) return error.CertificateNotYetValid;
        if (sec > self.not_after) return error.CertificateExpired;
    }
};

pub const Name = struct {
    // must implement
    country: DirectoryString = empty,
    organization: DirectoryString = empty,
    organizational_unit: DirectoryString = empty,
    distinguished_name: DirectoryString = empty,
    state_or_province: DirectoryString = empty,
    common_name: DirectoryString = empty,
    serial_number: DirectoryString = empty,
    domain_component: []const u8 = "",

    // may implement
    locality: DirectoryString = empty,
    title: DirectoryString = empty,
    surname: DirectoryString = empty,
    given_name: DirectoryString = empty,
    initials: DirectoryString = empty,
    pseudonym: DirectoryString = empty,
    generation_qualifier: DirectoryString = empty,

    // not in RFC but found in real CA certs
    organization_id: DirectoryString = empty,
    /// deprecated in favor of altName extension
    email_address: []const u8 = "",

    /// for unknown fields. holds opaque sequence.
    kvs: KVs = [_][]const u8{""} ** unknown_len,
    kvs_len: u8 = 0,

    const empty = DirectoryString.empty;
    const unknown_len = 7;

    pub const KVs = [unknown_len][]const u8;

    pub fn fromDer(parser: *der.Parser) !Name {
        var res = Name{};
        const seq = try parser.expectSequence();

        while (parser.index != seq.slice.end) {
            const kv = try parser.expectSequenceOf();
            defer parser.index = kv.slice.end;

            const seq2 = try parser.expectSequence();
            const key = parser.expectEnum(Attribute) catch |err| switch (err) {
                error.UnknownObjectId => {
                    if (res.kvs_len < res.kvs.len) {
                        res.kvs_len += 1;
                        res.kvs[res.kvs_len] = parser.view(seq2);
                        continue;
                    } else {
                        return error.NameAttributeOverflow;
                    }
                },
                else => return err,
            };
            switch (key) {
                inline .domain_component, .email_address => |t| {
                    const ele = try parser.expect(.universal, false, null);
                    if (ele.identifier.tag != .string_ia5) return error.InvalidDomainComponent;
                    @field(res, @tagName(t)) = parser.view(ele);
                },
                inline else => |t| {
                    @field(res, @tagName(t)) = try DirectoryString.fromDer(parser);
                },
            }
        }

        return res;
    }

    // match field names for easy `inline else`
    const Attribute = enum {
        country,
        organization,
        organizational_unit,
        distinguished_name,
        state_or_province,
        common_name,
        serial_number,
        domain_component,
        locality,
        title,
        surname,
        given_name,
        initials,
        pseudonym,
        generation_qualifier,
        organization_id,
        email_address,

        pub const oids = std.StaticStringMap(Attribute).initComptime(.{
            .{ &comptimeOid("0.9.2342.19200300.100.1.25"), .domain_component },
            .{ &comptimeOid("1.2.840.113549.1.9.1"), .email_address },
            .{ &comptimeOid("2.5.4.3"), .common_name },
            .{ &comptimeOid("2.5.4.4"), .surname },
            .{ &comptimeOid("2.5.4.5"), .serial_number },
            .{ &comptimeOid("2.5.4.6"), .country },
            .{ &comptimeOid("2.5.4.7"), .locality },
            .{ &comptimeOid("2.5.4.8"), .state_or_province },
            .{ &comptimeOid("2.5.4.10"), .organization },
            .{ &comptimeOid("2.5.4.11"), .organizational_unit },
            .{ &comptimeOid("2.5.4.12"), .title },
            .{ &comptimeOid("2.5.4.42"), .given_name },
            .{ &comptimeOid("2.5.4.43"), .initials },
            .{ &comptimeOid("2.5.4.44"), .generation_qualifier },
            .{ &comptimeOid("2.5.4.49"), .distinguished_name },
            .{ &comptimeOid("2.5.4.65"), .pseudonym },
            .{ &comptimeOid("2.5.4.97"), .organization_id },
        });

        comptime {
            std.debug.assert(std.meta.fields(@This()).len == oids.kvs.len);
        }
    };

    /// TODO: Use unicode mapping, lowering, and normalization in section 7.1.
    /// Will require unicode mapping tables from RFC 4818 and RFC 3454.
    ///
    /// This version is stricter but less internationalized.
    pub fn eql(self: Name, other: Name) bool {
        inline for (@typeInfo(Name).Struct.fields) |field| {
            const v1 = @field(self, field.name);
            const v2 = @field(other, field.name);
            if (field.type == DirectoryString) {
                if (!v1.cmp(v2)) return false;
            } else if (field.type == []const u8) {
                if (!mem.eql(u8, v1, v2)) return false;
            } else if (field.type == u8) {
                if (v1 != v2) return false;
            } else if (field.type == [7][]const u8) {
                for (v1, v2) |s1, s2| {
                    if (!mem.eql(u8, s1, s2)) return false;
                }
            } else {
                @compileError("add else if for " ++ @typeName(field.type));
            }
        }
        return true;
    }

    pub fn print(name: Name, writer: anytype) !void {
        if (name.organization.data.len > 0) try writer.print("O: {s}, ", .{name.organization.data});
        if (name.country.data.len > 0) try writer.print("C: {s}, ", .{name.country.data});
        if (name.common_name.data.len > 0) try writer.print("CN: {s} ", .{name.common_name.data});
    }
};

pub const Version = enum(u8) {
    v1 = 0,
    v2 = 1,
    v3 = 2,
};

const NamedCurve = enum {
    prime256v1,
    secp256k1,
    secp384r1,
    secp521r1,

    pub const oids = std.StaticStringMap(@This()).initComptime(.{
        .{ &comptimeOid("1.2.840.10045.3.1.7"), .prime256v1 },
        .{ &comptimeOid("1.3.132.0.10"), .secp256k1 },
        .{ &comptimeOid("1.3.132.0.34"), .secp384r1 },
        .{ &comptimeOid("1.3.132.0.35"), .secp521r1 },
    });
};

const AlgorithmTag = enum {
    rsa_pkcs_sha1,
    rsa_pkcs_sha224,
    rsa_pkcs_sha256,
    rsa_pkcs_sha384,
    rsa_pkcs_sha512,
    rsa_pss,
    ecdsa_sha224,
    ecdsa_sha256,
    ecdsa_sha384,
    ecdsa_sha512,
    ed25519,

    pub const oids = std.StaticStringMap(AlgorithmTag).initComptime(.{
        .{ &comptimeOid("1.2.840.113549.1.1.5"), .rsa_pkcs_sha1 },
        .{ &comptimeOid("1.2.840.113549.1.1.10"), .rsa_pss },
        .{ &comptimeOid("1.2.840.113549.1.1.11"), .rsa_pkcs_sha256 },
        .{ &comptimeOid("1.2.840.113549.1.1.12"), .rsa_pkcs_sha384 },
        .{ &comptimeOid("1.2.840.113549.1.1.13"), .rsa_pkcs_sha512 },
        .{ &comptimeOid("1.2.840.113549.1.1.14"), .rsa_pkcs_sha224 },
        .{ &comptimeOid("1.2.840.10045.4.3.1"), .ecdsa_sha224 },
        .{ &comptimeOid("1.2.840.10045.4.3.2"), .ecdsa_sha256 },
        .{ &comptimeOid("1.2.840.10045.4.3.3"), .ecdsa_sha384 },
        .{ &comptimeOid("1.2.840.10045.4.3.4"), .ecdsa_sha512 },
        .{ &comptimeOid("1.3.101.112"), .ed25519 },
    });
};

const HashTag = enum {
    sha1,
    sha224,
    sha256,
    sha384,
    sha512,

    pub const oids = std.StaticStringMap(@This()).initComptime(.{
        .{ &comptimeOid("1.3.14.3.2.26"), .sha1 },
        .{ &comptimeOid("2.16.840.1.101.3.4.2.1"), .sha256 },
        .{ &comptimeOid("2.16.840.1.101.3.4.2.2"), .sha384 },
        .{ &comptimeOid("2.16.840.1.101.3.4.2.3"), .sha512 },
        .{ &comptimeOid("2.16.840.1.101.3.4.2.4"), .sha224 },
    });

    pub fn Hash(comptime self: HashTag) type {
        return switch (self) {
            .sha1 => return crypto.hash.Sha1,
            .sha224 => return crypto.hash.sha2.Sha224,
            .sha256 => return crypto.hash.sha2.Sha256,
            .sha384 => return crypto.hash.sha2.Sha384,
            .sha512 => return crypto.hash.sha2.Sha512,
        };
    }

    pub fn verify(self: HashTag) !void {
        switch (self) {
            .sha1 => return error.InsecureHash,
            .sha224, .sha256, .sha384, .sha512 => {},
        }
    }
};

pub const Signature = struct {
    algo: Algorithm,
    value: Value,

    pub const Algorithm = union(enum) {
        rsa_pkcs: HashTag,
        rsa_pss: RsaPss,
        ecdsa: Ecdsa,
        ed25519: void,

        // RFC 4055 S3.1
        const RsaPss = struct {
            hash: HashTag,
            mask_gen: MaskGen = .{ .tag = .mgf1, .hash = .sha256 },
            salt_len: u8 = 32,

            pub fn fromDer(parser: *der.Parser) !RsaPss {
                const body = try parser.expectSequence();
                defer parser.seek(body.slice.end);

                const hash = brk: {
                    const seq = try parser.expectSequence();
                    defer parser.seek(seq.slice.end);
                    const hash = try parser.expectEnum(HashTag);
                    _ = try parser.expectPrimitive(.null);
                    break :brk hash;
                };

                const mask_gen = try MaskGen.fromDer(parser);
                const salt_len = try parser.expectInt(i8);
                if (salt_len < 0) return error.InvalidSaltLength;

                return .{ .hash = hash, .mask_gen = mask_gen, .salt_len = @bitCast(salt_len) };
            }

            const MaskGen = struct {
                tag: Tag,
                hash: HashTag,

                pub fn fromDer(parser: *der.Parser) !MaskGen {
                    const seq = try parser.expectSequence();
                    defer parser.seek(seq.slice.end);

                    const tag = try parser.expectEnum(Tag);
                    const hash = try parser.expectEnum(HashTag);
                    return .{ .tag = tag, .hash = hash };
                }

                const Tag = enum {
                    mgf1,

                    pub const oids = std.StaticStringMap(@This()).initComptime(.{
                        .{ &comptimeOid("1.2.840.113549.1.1.8"), .mgf1 },
                    });
                };
            };
        };

        const Ecdsa = struct {
            hash: HashTag,
            curve: ?NamedCurve,
        };

        fn fromDer(parser: *der.Parser) !Algorithm {
            const seq = try parser.expectSequence();
            defer parser.seek(seq.slice.end);

            const algo = try parser.expectEnum(AlgorithmTag);
            switch (algo) {
                inline .rsa_pkcs_sha1,
                .rsa_pkcs_sha224,
                .rsa_pkcs_sha256,
                .rsa_pkcs_sha384,
                .rsa_pkcs_sha512,
                => |t| {
                    _ = try parser.expectPrimitive(.null);
                    const hash = std.meta.stringToEnum(HashTag, @tagName(t)["rsa_pkcs_".len..]).?;
                    return .{ .rsa_pkcs = hash };
                },
                .rsa_pss => return .{ .rsa_pss = try RsaPss.fromDer(parser) },
                inline .ecdsa_sha224,
                .ecdsa_sha256,
                .ecdsa_sha384,
                .ecdsa_sha512,
                => |t| {
                    const curve = if (parser.index != seq.slice.end) try parser.expectEnum(NamedCurve) else null;
                    return .{ .ecdsa = Ecdsa{
                        .hash = std.meta.stringToEnum(HashTag, @tagName(t)["ecdsa_".len..]).?,
                        .curve = curve,
                    } };
                },
                .ed25519 => return .{ .ed25519 = {} },
            }
        }

        pub fn validate(self: @This()) !void {
            switch (self) {
                .rsa_pkcs => |h| try h.verify(),
                .rsa_pss => |info| try info.hash.verify(),
                .ecdsa => |info| try info.hash.verify(),
                .ed25519 => {},
            }
        }
    };

    pub const Value = union(PubKeyTag) {
        rsa2048: Rsa2048.Signature,
        rsa3072: Rsa3072.Signature,
        rsa4096: Rsa4096.Signature,
        ecdsa_p256: EcdsaP256.Signature,
        ecdsa_p384: EcdsaP384.Signature,
        ecdsa_secp256: EcdsaSecP256.Signature,
        ed25519: Ed25519.Signature,

        pub fn fromBitString(tag: PubKeyTag, bitstring: der.BitString) !Value {
            if (bitstring.right_padding != 0) return error.InvalidSignature;

            switch (tag) {
                inline else => |t| {
                    const T = std.meta.FieldType(@This(), t);
                    const value = try T.fromDer(bitstring.bytes);
                    return @unionInit(Value, @tagName(t), value);
                },
            }
        }
    };

    /// Verifies that this signature matches from `message` signed by `pub_key`
    pub fn verify(self: Signature, message: []const u8, pub_key: PubKey) !void {
        if (std.meta.activeTag(pub_key) != std.meta.activeTag(self.value)) return error.PublicKeyMismatch;

        switch (self.value) {
            inline .rsa2048, .rsa3072, .rsa4096 => |sig, t| {
                const pk = @field(pub_key, @tagName(t));
                switch (self.algo) {
                    .rsa_pkcs => |hash| {
                        switch (hash) {
                            inline else => |h| {
                                try sig.pkcsv1_5(h.Hash()).verify(message, pk);
                            },
                        }
                    },
                    .rsa_pss => |opts| {
                        if (opts.mask_gen.tag != .mgf1 or opts.mask_gen.hash != .sha256) {
                            return error.UnsupportedMaskGenerationFunction;
                        }
                        switch (opts.hash) {
                            inline else => |h| {
                                try sig.pss(h.Hash()).verify(message, pk, opts.salt_len);
                            },
                        }
                    },
                    else => return error.AlgorithmMismatch,
                }
            },
            inline .ecdsa_p256, .ecdsa_p384, .ecdsa_secp256 => |sig, t| {
                const pk = @field(pub_key, @tagName(t));
                switch (self.algo) {
                    .ecdsa => |opts| {
                        switch (opts.hash) {
                            inline else => |h| {
                                try sig.verify(h.Hash(), message, pk);
                            },
                        }
                    },
                    else => return error.AlgorithmMismatch,
                }
            },
            .ed25519 => |sig| {
                switch (self.algo) {
                    .ed25519 => try sig.verify(message, pub_key.ed25519),
                    else => return error.AlgorithmMismatch,
                }
            },
        }
    }

    const sha2 = crypto.hash.sha2;
};

pub const PathLen = u16;
/// Extension specifying if certificate is a CA and maximum number
/// of non self-issued intermediate certificates that may follow this
/// Certificate in a valid certification path.
pub const BasicConstraints = struct {
    is_ca: bool = false,
    /// MUST NOT include unless `is_ca`.
    max_path_len: ?PathLen = null,

    pub fn fromDer(bytes: []const u8) !BasicConstraints {
        var res: BasicConstraints = .{};

        var parser = der.Parser{ .bytes = bytes };
        _ = try parser.expectSequence();
        if (!parser.eof()) {
            res.is_ca = try parser.expectBool();
            if (!parser.eof()) {
                res.max_path_len = try parser.expectInt(PathLen);
                if (!res.is_ca) return error.NotCA;
            }
        }

        return res;
    }

    pub fn validate(self: BasicConstraints, path_len: u16) !void {
        if (self.is_ca) {
            if (self.max_path_len) |l| {
                if (path_len > l) return error.MaxPathLenExceeded;
            }
        }
    }
};

fn MakeValidator(comptime T: type) type {
    // map each field to a flag
    const to_copy = std.meta.fields(T);
    var fields: [to_copy.len]std.builtin.Type.StructField = undefined;
    for (&fields, to_copy) |*f, f2| {
        f.* = f2;
        f.type = Flag;
        f.default_value = @ptrCast(&Flag.ignore);
    }
    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

/// How `pub_key` may be used.
pub const KeyUsage = packed struct {
    // fields are in reverse bit order because of how zig packs structs
    encipher_only: bool = false,
    crl_sign: bool = false,
    // MUST be false when basic_constraints.is_ca == false
    key_cert_sign: bool = false,
    key_agreement: bool = false,
    data_encipherment: bool = false,
    key_encipherment: bool = false,
    content_commitment: bool = false,
    digital_signature: bool = false,

    decipher_only: bool = false,

    pub fn fromDer(bytes: []const u8) !KeyUsage {
        var parser = der.Parser{ .bytes = bytes };
        const key_usage = try parser.expectBitstring();
        if (key_usage.bytes.len > @sizeOf(KeyUsage)) return error.InvalidKeyUsage;

        var res = KeyUsage{};
        var res_bytes = mem.asBytes(&res);
        @memcpy(res_bytes[0..key_usage.bytes.len], key_usage.bytes);

        return res;
    }

    pub const Validator = MakeValidator(KeyUsage);
    pub fn validate(self: KeyUsage, validator: Validator) !void {
        inline for (std.meta.fields(KeyUsage)) |f| {
            const expected = @field(validator, f.name);
            const actual = @field(self, f.name);
            if (!expected.verify(actual)) return error.InvalidKeyUsage;
        }
    }
};

/// Further specifies how `pub_key` may be used.
pub const KeyUsageExt = packed struct {
    server_auth: bool = false,
    client_auth: bool = false,
    code_signing: bool = false,
    email_protection: bool = false,
    time_stamping: bool = false,
    ocsp_signing: bool = false,

    pub const Tag = enum {
        server_auth,
        client_auth,
        code_signing,
        email_protection,
        time_stamping,
        ocsp_signing,

        pub const oids = std.StaticStringMap(Tag).initComptime(.{
            .{ &comptimeOid("1.3.6.1.5.5.7.3.1"), .server_auth },
            .{ &comptimeOid("1.3.6.1.5.5.7.3.2"), .client_auth },
            .{ &comptimeOid("1.3.6.1.5.5.7.3.3"), .code_signing },
            .{ &comptimeOid("1.3.6.1.5.5.7.3.4"), .email_protection },
            .{ &comptimeOid("1.3.6.1.5.5.7.3.8"), .time_stamping },
            .{ &comptimeOid("1.3.6.1.5.5.7.3.9"), .ocsp_signing },
        });
    };

    pub fn fromDer(bytes: []const u8) !KeyUsageExt {
        var res: KeyUsageExt = .{};

        var parser = der.Parser{ .bytes = bytes };
        const seq = try parser.expectSequence();
        defer parser.seek(seq.slice.end);
        while (parser.index != parser.bytes.len) {
            const tag = parser.expectEnum(KeyUsageExt.Tag) catch |err| switch (err) {
                error.UnknownObjectId => continue,
                else => return err,
            };
            switch (tag) {
                .server_auth => res.server_auth = true,
                .client_auth => res.client_auth = true,
                .code_signing => res.code_signing = true,
                .email_protection => res.email_protection = true,
                .time_stamping => res.time_stamping = true,
                .ocsp_signing => res.ocsp_signing = true,
            }
        }

        return res;
    }

    pub const Validator = MakeValidator(KeyUsageExt);
    pub fn validate(self: KeyUsageExt, validator: Validator) !void {
        inline for (std.meta.fields(KeyUsageExt)) |f| {
            const expected = @field(validator, f.name);
            const actual = @field(self, f.name);
            if (!expected.verify(actual)) return error.InvalidKeyUsage;
        }
    }
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

pub const DirectoryString = struct {
    tag: der.String.Tag,
    data: []const u8,

    const Self = @This();

    pub fn fromDer(parser: *der.Parser) !Self {
        const string = try parser.expectString(std.EnumSet(der.String.Tag).initMany(&[_]der.String.Tag{
            .teletex,
            .printable,
            .universal,
            .utf8,
            .bmp,
        }));

        return .{ .tag = string.tag, .data = string.data };
    }

    /// TODO: use RFC 5280 S7.2 for better internationalization
    pub fn cmp(self: Self, other: Self) bool {
        return std.mem.eql(u8, self.data, other.data);
    }

    const empty = Self{ .tag = .utf8, .data = "" };
};

pub const DisplayText = struct {
    tag: der.String.Tag,
    data: []const u8,

    const Self = @This();

    pub fn fromDer(parser: *der.Parser) !Self {
        const string = try parser.expectString(std.EnumSet(der.String.Tag).initMany(&[_]der.String.Tag{
            .ia5,
            .visible,
            .bmp,
            .utf8,
        }));

        return .{ .tag = string.tag, .data = string.data };
    }
};

const std = @import("../std.zig");
const der = @import("der.zig");
const rsa = @import("rsa.zig");
const oid_mod = @import("oid.zig");
pub const Bundle = @import("Certificate/Bundle.zig");
pub const PathValidator = @import("Certificate/PathValidator.zig");

const crypto = std.crypto;
const mem = std.mem;
const Cert = @This();
const comptimeOid = oid_mod.encodeComptime;
const ecdsa = crypto.sign.ecdsa;
const sha2 = crypto.hash.sha2;
const testing = std.testing;
const Rsa2048 = rsa.Rsa2048;
const Rsa3072 = rsa.Rsa3072;
const Rsa4096 = rsa.Rsa4096;
const EcdsaP256 = ecdsa.Ecdsa(crypto.ecc.P256);
const EcdsaP384 = ecdsa.Ecdsa(crypto.ecc.P384);
const EcdsaSecP256 = ecdsa.Ecdsa(crypto.ecc.Secp256k1);
const Ed25519 = crypto.sign.Ed25519;
const log = std.log.scoped(.certificate);

test {
    _ = Bundle;
    _ = PathValidator;
    _ = der;
}

/// Strictly for testing
inline fn hexToBytes(comptime hex: []const u8) []u8 {
    var res: [hex.len]u8 = undefined;
    return std.fmt.hexToBytes(&res, hex) catch unreachable;
}

fn expectEqualName(n1: Name, n2: Name) !void {
    inline for (std.meta.fields(Name)) |f| {
        const v1 = @field(n1, f.name);
        const v2 = @field(n2, f.name);
        if (f.type == DirectoryString) {
            try testing.expectEqual(v1.tag, v2.tag);
            try testing.expectEqualStrings(v1.data, v2.data);
        } else if (f.type == []const u8) {
            try testing.expectEqualStrings(v1, v2);
        } else if (f.type == u8) {
            try testing.expectEqual(v1, v2);
        } else if (f.type == Name.KVs) {
            for (v1, v2) |s1, s2| {
                try testing.expectEqualStrings(s1, s2);
            }
        } else {
            @compileError("implement type " ++ @typeName(f.type));
        }
    }
}

test "certificate fromDer rsa2048" {
    // fake cert from https://tls13.xargs.org/certificate.html
    // can also view with:
    // $ openssl x509 -inform der -noout -text -in ./testdata/cert_rsa2048.der
    const cert_bytes = @embedFile("testdata/cert_rsa2048.der");
    const cert = try Cert.fromDer(cert_bytes);

    try testing.expectEqual(Version.v3, cert.version);
    try testing.expectEqualSlices(u8, hexToBytes("155a92adc2048f90"), cert.serial_number);
    try expectEqualName(Name{
        .country = DirectoryString{ .tag = .printable, .data = "US" },
        .organization = DirectoryString{ .tag = .printable, .data = "Example CA" },
    }, cert.issuer);
    try testing.expectEqual(1538703497, cert.validity.not_before);
    try testing.expectEqual(1570239497, cert.validity.not_after);
    try expectEqualName(Name{
        .country = DirectoryString{ .tag = .printable, .data = "US" },
        .common_name = DirectoryString{ .tag = .printable, .data = "example.ulfheim.net" },
    }, cert.subject);
    try testing.expectEqual(PubKey.rsa2048, std.meta.activeTag(cert.pub_key));
    try testing.expectEqual(@as(usize, 65537), try cert.pub_key.rsa2048.public_exponent.toPrimitive(usize));
    // extensions
    try testing.expectEqual(KeyUsage{ .digital_signature = true, .key_encipherment = true }, cert.key_usage);
    try testing.expectEqual(KeyUsageExt{ .client_auth = true, .server_auth = true }, cert.key_usage_ext);
    // sig
    try testing.expectEqual(Signature.Algorithm{ .rsa_pkcs = .sha256 }, cert.signature_algo);
    try testing.expectEqualSlices(u8, cert_bytes[549..], cert.signature.bytes);
}

test "certificate fromDer ecc256" {
    // real cert from https://ecc256.badssl.com circa 2024-04
    // $ true | openssl s_client -connect ecc256.badssl.com:443 2>/dev/null | openssl x509 -inform pem -outform der > ./testdata/cert_ecc256.der
    const cert_bytes = @embedFile("testdata/cert_ecc256.der");
    const cert = try Cert.fromDer(cert_bytes);

    try testing.expectEqual(Version.v3, cert.version);
    try testing.expectEqualSlices(u8, hexToBytes("03e727237862e5ac970afbd1f2cd25584f79"), cert.serial_number);
    try expectEqualName(Name{
        .country = .{ .tag = .printable, .data = "US" },
        .organization = .{ .tag = .printable, .data = "Let's Encrypt" },
        .common_name = .{ .tag = .printable, .data = "R3" },
    }, cert.issuer);
    try testing.expectEqual(1708547232, cert.validity.not_before);
    try testing.expectEqual(1716323231, cert.validity.not_after);
    try expectEqualName(Name{
        .common_name = .{ .tag = .utf8, .data = "*.badssl.com" },
    }, cert.subject);
    try testing.expectEqual(PubKey.ecdsa_p256, std.meta.activeTag(cert.pub_key));
    // extensions
    try testing.expectEqual(KeyUsage{ .digital_signature = true }, cert.key_usage);
    try testing.expectEqual(KeyUsageExt{ .client_auth = true, .server_auth = true }, cert.key_usage_ext);
    try testing.expectEqual(BasicConstraints{}, cert.basic_constraints);
    var iter = cert.subjectAliasesIter();
    try testing.expectEqualStrings("*.badssl.com", (try iter.next()).?);
    try testing.expectEqualStrings("badssl.com", (try iter.next()).?);
    try testing.expectEqual(null, try iter.next());
    // sig
    try testing.expectEqual(Signature.Algorithm{ .rsa_pkcs = .sha256 }, cert.signature_algo);
    try testing.expectEqualSlices(u8, cert_bytes[808..], cert.signature.bytes);
}
