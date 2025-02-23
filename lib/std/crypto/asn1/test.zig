const std = @import("std");
const asn1 = @import("../asn1.zig");

const der = asn1.der;
const Tag = asn1.Tag;
const FieldTag = asn1.FieldTag;

/// An example that uses all ASN1 types and available implementation features.
const AllTypes = struct {
    a: u8 = 0,
    b: asn1.BitString,
    c: C,
    d: asn1.Opaque(Tag.universal(.string_utf8, false)),
    e: asn1.Opaque(Tag.universal(.octetstring, false)),
    f: ?u16,
    g: ?Nested,
    h: asn1.Any,

    pub const asn1_tags = .{
        .a = FieldTag.initExplicit(0, .context_specific),
        .b = FieldTag.initExplicit(1, .context_specific),
        .c = FieldTag.initImplicit(2, .context_specific),
        .g = FieldTag.initImplicit(3, .context_specific),
    };

    const C = enum {
        a,
        b,

        pub const oids = asn1.Oid.StaticMap(@This()).initComptime(.{
            .a = "1.2.3.4",
            .b = "1.2.3.5",
        });
    };

    const Nested = struct {
        inner: Asn1T,
        sum: i16,

        const Asn1T = struct { a: u8, b: i16 };

        pub fn decodeDer(decoder: *der.Decoder) !Nested {
            const inner = try decoder.any(Asn1T);
            return Nested{ .inner = inner, .sum = inner.a + inner.b };
        }

        pub fn encodeDer(self: Nested, encoder: *der.Encoder) !void {
            try encoder.any(self.inner);
        }
    };
};

test AllTypes {
    const expected = AllTypes{
        .a = 2,
        .b = asn1.BitString{ .bytes = &[_]u8{ 0x04, 0xa0 } },
        .c = .a,
        .d = .{ .bytes = "asdf" },
        .e = .{ .bytes = "fdsa" },
        .f = (1 << 8) + 1,
        .g = .{ .inner = .{ .a = 4, .b = 5 }, .sum = 9 },
        .h = .{ .tag = Tag.init(.string_ia5, false, .universal), .bytes = "asdf" },
    };
    // https://lapo.it/asn1js/#MC-gAwIBAqEFAwMABKCCAyoDBAwEYXNkZgQEZmRzYQICAQGjBgIBBAIBBRYEYXNkZg
    const path = "./der/testdata/all_types.der";
    const encoded = @embedFile(path);
    const actual = try asn1.der.decode(AllTypes, encoded);
    try std.testing.expectEqualDeep(expected, actual);

    const allocator = std.testing.allocator;
    const buf = try asn1.der.encode(allocator, expected);
    defer allocator.free(buf);
    try std.testing.expectEqualSlices(u8, encoded, buf);

    // Use this to update test file.
    // const dir = try std.fs.cwd().openDir("lib/std/crypto/asn1", .{});
    // var file = try dir.createFile(path, .{});
    // defer file.close();
    // try file.writeAll(buf);
}
