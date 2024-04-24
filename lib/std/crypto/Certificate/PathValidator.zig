//! RFC 5280 Section 6

subject: Cert,
policy: Cert.Policy,
path_len: PathLen,
options: Options,

pub const Options = struct {
    issuer: Validator = .{
        .key_usage = .{ .key_cert_sign = .set_or_null },
    },
    subject: Validator = .{
        .key_usage = .{ .digital_signature = .set_or_null },
        .key_usage_ext = .{ .client_auth = .set_or_null },
    },
    /// Trusted Certificate Authorities.
    bundle: Bundle,
    // Unix epoch seconds.
    time: i64,
    max_path_len: PathLen = 20,

    pub const Validator = struct {
        key_usage: KeyUsage.Validator = .{},
        key_usage_ext: KeyUsageExt.Validator = .{},
    };
};
const Self = @This();

pub fn init(subject: Cert, policy: Cert.Policy, options: Options, host_name: ?[]const u8) !Self {
    if (host_name) |h| try subject.verifyHostName(h);
    return Self{ .subject = subject, .policy = policy, .path_len = 1, .options = options };
}

/// Check that `subject` is trusted by a CA in `options.bundle`.
pub fn validateCA(self: *Self, subject: Cert) !void {
    const ca = self.options.bundle.issuers.get(subject.issuer) orelse return error.CANotFound;
    if (!ca.basic_constraints.is_ca) return error.InvalidCA; // bundle should not contain this...
    try self.validate(ca);
}

/// Check `self.subject` is trusted by `issuer` by validating:
/// * `subject.issuer == issuer.subject`
/// * `subject` and `issuer` contain valid combinations of fields according to RFC 5280. SHA1
///   signature hashing algorithms are considered invalid.
/// * The time validity of the subject and issuer.
/// * `issuer.basic_constraints` are met.
/// * Subject and issuer key usage and extended key usage flags match those specified in options.
/// * If present, the issuer has at least one policy compatible with the subject's policy.
/// * `issuer.signature` is valid for `subject.tbs_bytes`. Valid algorithms are those listed in
///   Mozilla's Certificate policy [1], except for SHA1.
///
/// [1] https://www.mozilla.org/en-US/about/governance/policies/security-group/certs/policy/#5-certificates
pub fn validate(self: *Self, issuer: Cert) !void {
    const subject = self.subject;
    if (!subject.issuer.eql(issuer.subject)) return error.CertificateIssuerMismatch;

    try subject.validate(self.options.time);
    try issuer.validate(self.options.time);

    try subject.key_usage.validate(self.options.subject.key_usage);
    try issuer.key_usage.validate(self.options.issuer.key_usage);
    try subject.key_usage_ext.validate(self.options.subject.key_usage_ext);
    try issuer.key_usage_ext.validate(self.options.issuer.key_usage_ext);

    const is_self_signed = issuer.subject.eql(issuer.issuer);
    if (!is_self_signed) self.path_len += 1;
    if (self.path_len > self.options.max_path_len) return error.MaxPathLenExceeded;
    try issuer.basic_constraints.validate(self.path_len);

    // TODO: make this stricter and follow RFC 5280.
    var issuer_policies = issuer.policiesIter();
    const anyPolicy = comptimeOid("2.5.29.32.0");
    while (try issuer_policies.next()) |ip| brk: {
        if (std.mem.eql(u8, ip.oid, &anyPolicy)) break;

        var subject_policies = subject.policiesIter();
        while (try subject_policies.next()) |sp| {
            if (std.mem.eql(u8, ip.oid, sp.oid)) break :brk;
        }
        return error.IssuerPolicyNotMet;
    }

    const signature = Signature{
        .algo = subject.signature_algo,
        .value = try Signature.Value.fromBitString(issuer.pub_key, subject.signature),
    };
    try signature.verify(subject.tbs_bytes, issuer.pub_key);

    self.subject = issuer;
}

pub const Validated = struct {
    ca: Cert,
    policy: Policy,
    path_len: PathLen,
};

test validateCA {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    var bundle: Bundle = .{};
    defer bundle.deinit(allocator);
    try bundle.addCertsFromPem(allocator, @embedFile("../testdata/ca_bundle.pem"));

    const cert_bytes = @embedFile("../testdata/cert_lets_encrypt_r3.der");
    const cert = try Cert.fromDer(cert_bytes);

    var validator = try Self.init(
        cert,
        Cert.Policy.any,
        .{ .time = 1713312664, .bundle = bundle },
        null,
    );
    try validator.validateCA(cert);
}

const std = @import("std");
const builtin = @import("builtin");
const der = @import("../der.zig");
const oid_mod = @import("../oid.zig");
const Cert = std.crypto.Certificate;
const KeyUsage = Cert.KeyUsage;
const KeyUsageExt = Cert.KeyUsageExt;
const Signature = Cert.Signature;
const PathLen = Cert.PathLen;
const Policy = Cert.Policy;
const Bundle = Cert.Bundle;
const comptimeOid = oid_mod.encodeComptime;
