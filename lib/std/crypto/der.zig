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
    null = 5,
    object_identifier = 6,
    sequence = 16,
    sequence_of = 17,
    utc_time = 23,
    generalized_time = 24,
    _,
};

pub const Oid = enum {
    rsadsi,
    pkcs,
    rsaEncryption,
    md2WithRSAEncryption,
    md5WithRSAEncryption,
    sha1WithRSAEncryption,
    sha256WithRSAEncryption,
    sha384WithRSAEncryption,
    sha512WithRSAEncryption,
    sha224WithRSAEncryption,
    pbeWithMD2AndDES_CBC,
    pbeWithMD5AndDES_CBC,
    pkcs9_emailAddress,
    md2,
    md5,
    rc4,
    ecdsa_with_Recommended,
    ecdsa_with_Specified,
    ecdsa_with_SHA224,
    ecdsa_with_SHA256,
    ecdsa_with_SHA384,
    ecdsa_with_SHA512,
    X500,
    X509,
    commonName,
    serialNumber,
    countryName,
    localityName,
    stateOrProvinceName,
    organizationName,
    organizationalUnitName,
    organizationIdentifier,

    pub const map = std.ComptimeStringMap(Oid, .{
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D }, .rsadsi },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01 }, .pkcs },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01 }, .rsaEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x02 }, .md2WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x04 }, .md5WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x05 }, .sha1WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B }, .sha256WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0C }, .sha384WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0D }, .sha512WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0E }, .sha224WithRSAEncryption },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x05, 0x01 }, .pbeWithMD2AndDES_CBC },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x05, 0x03 }, .pbeWithMD5AndDES_CBC },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x09, 0x01 }, .pkcs9_emailAddress },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02, 0x02 }, .md2 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x02, 0x05 }, .md5 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x03, 0x04 }, .rc4 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x02 }, .ecdsa_with_Recommended },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03 }, .ecdsa_with_Specified },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x01 }, .ecdsa_with_SHA224 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02 }, .ecdsa_with_SHA256 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x03 }, .ecdsa_with_SHA384 },
        .{ &[_]u8{ 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x04 }, .ecdsa_with_SHA512 },
        .{ &[_]u8{0x55}, .X500 },
        .{ &[_]u8{ 0x55, 0x04 }, .X509 },
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

pub const Element = struct {
    identifier: Identifier,
    slice: Slice,

    pub const Slice = struct {
        start: u32,
        end: u32,

        pub const empty: Slice = .{ .start = 0, .end = 0 };
    };
};

pub const ParseElementError = error{CertificateFieldHasInvalidLength};

pub fn parseElement(bytes: []const u8, index: u32) ParseElementError!Element {
    var i = index;
    const identifier = @bitCast(Identifier, bytes[i]);
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

    const len_size = @truncate(u7, size_byte);
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

pub const ParseObjectIdError = error{
    CertificateHasUnrecognizedObjectId,
    CertificateFieldHasWrongDataType,
} || ParseElementError;

pub fn parseObjectId(bytes: []const u8, element: Element) ParseObjectIdError!Oid {
    if (element.identifier.tag != .object_identifier)
        return error.CertificateFieldHasWrongDataType;
    return Oid.map.get(bytes[element.slice.start..element.slice.end]) orelse
        return error.CertificateHasUnrecognizedObjectId;
}

const std = @import("../std.zig");
const der = @This();
