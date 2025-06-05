//! ASN.1 types for public consumption.
const std = @import("std");
pub const der = @import("./asn1/der.zig");
pub const Oid = @import("./asn1/Oid.zig");

pub const Index = u32;

pub const Tag = struct {
    number: Number,
    /// Whether this ASN.1 type contains other ASN.1 types.
    constructed: bool,
    class: Class,

    /// These values apply to class == .universal.
    pub const Number = enum(u16) {
        // 0 is reserved by spec
        boolean = 1,
        integer = 2,
        bitstring = 3,
        octetstring = 4,
        null = 5,
        oid = 6,
        object_descriptor = 7,
        real = 9,
        enumerated = 10,
        embedded = 11,
        string_utf8 = 12,
        oid_relative = 13,
        time = 14,
        // 15 is reserved to mean that the tag is >= 32
        sequence = 16,
        /// Elements may appear in any order.
        sequence_of = 17,
        string_numeric = 18,
        string_printable = 19,
        string_teletex = 20,
        string_videotex = 21,
        string_ia5 = 22,
        utc_time = 23,
        generalized_time = 24,
        string_graphic = 25,
        string_visible = 26,
        string_general = 27,
        string_universal = 28,
        string_char = 29,
        string_bmp = 30,
        date = 31,
        time_of_day = 32,
        date_time = 33,
        duration = 34,
        /// IRI = Internationalized Resource Identifier
        oid_iri = 35,
        oid_iri_relative = 36,
        _,
    };

    pub const Class = enum(u2) {
        universal,
        application,
        context_specific,
        private,
    };

    pub fn init(number: Tag.Number, constructed: bool, class: Tag.Class) Tag {
        return .{ .number = number, .constructed = constructed, .class = class };
    }

    pub fn universal(number: Tag.Number, constructed: bool) Tag {
        return .{ .number = number, .constructed = constructed, .class = .universal };
    }

    pub fn decode(reader: anytype) !Tag {
        const tag1: FirstTag = @bitCast(try reader.readByte());
        var number: u14 = tag1.number;

        if (tag1.number == 15) {
            const tag2: NextTag = @bitCast(try reader.readByte());
            number = tag2.number;
            if (tag2.continues) {
                const tag3: NextTag = @bitCast(try reader.readByte());
                number = (number << 7) + tag3.number;
                if (tag3.continues) return error.InvalidLength;
            }
        }

        return Tag{
            .number = @enumFromInt(number),
            .constructed = tag1.constructed,
            .class = tag1.class,
        };
    }

    pub fn encode(self: Tag, writer: anytype) @TypeOf(writer).Error!void {
        var tag1 = FirstTag{
            .number = undefined,
            .constructed = self.constructed,
            .class = self.class,
        };

        var buffer: [3]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        var writer2 = stream.writer();

        switch (@intFromEnum(self.number)) {
            0...std.math.maxInt(u5) => |n| {
                tag1.number = @intCast(n);
                writer2.writeByte(@bitCast(tag1)) catch unreachable;
            },
            std.math.maxInt(u5) + 1...std.math.maxInt(u7) => |n| {
                tag1.number = 15;
                const tag2 = NextTag{ .number = @intCast(n), .continues = false };
                writer2.writeByte(@bitCast(tag1)) catch unreachable;
                writer2.writeByte(@bitCast(tag2)) catch unreachable;
            },
            else => |n| {
                tag1.number = 15;
                const tag2 = NextTag{ .number = @intCast(n >> 7), .continues = true };
                const tag3 = NextTag{ .number = @truncate(n), .continues = false };
                writer2.writeByte(@bitCast(tag1)) catch unreachable;
                writer2.writeByte(@bitCast(tag2)) catch unreachable;
                writer2.writeByte(@bitCast(tag3)) catch unreachable;
            },
        }

        _ = try writer.write(stream.getWritten());
    }

    const FirstTag = packed struct(u8) { number: u5, constructed: bool, class: Tag.Class };
    const NextTag = packed struct(u8) { number: u7, continues: bool };

    pub fn toExpected(self: Tag) ExpectedTag {
        return ExpectedTag{
            .number = self.number,
            .constructed = self.constructed,
            .class = self.class,
        };
    }

    pub fn fromZig(comptime T: type) Tag {
        switch (@typeInfo(T)) {
            .@"struct", .@"enum", .@"union" => {
                if (@hasDecl(T, "asn1_tag")) return T.asn1_tag;
            },
            else => {},
        }

        switch (@typeInfo(T)) {
            .@"struct", .@"union" => return universal(.sequence, true),
            .bool => return universal(.boolean, false),
            .int => return universal(.integer, false),
            .@"enum" => |e| {
                if (@hasDecl(T, "oids")) return Oid.asn1_tag;
                return universal(if (e.is_exhaustive) .enumerated else .integer, false);
            },
            .optional => |o| return fromZig(o.child),
            .null => return universal(.null, false),
            else => @compileError("cannot map Zig type to asn1_tag " ++ @typeName(T)),
        }
    }
};

test Tag {
    const buf = [_]u8{0xa3};
    var stream = std.io.fixedBufferStream(&buf);
    const t = Tag.decode(stream.reader());
    try std.testing.expectEqual(Tag.init(@enumFromInt(3), true, .context_specific), t);
}

/// A decoded view.
pub const Element = struct {
    tag: Tag,
    slice: Slice,

    pub const Slice = struct {
        start: Index,
        end: Index,

        pub fn len(self: Slice) Index {
            return self.end - self.start;
        }

        pub fn view(self: Slice, bytes: []const u8) []const u8 {
            return bytes[self.start..self.end];
        }
    };

    pub const DecodeError = error{ InvalidLength, EndOfStream };

    /// Safely decode a DER/BER/CER element at `index`:
    /// - Ensures length uses shortest form
    /// - Ensures length is within `bytes`
    /// - Ensures length is less than `std.math.maxInt(Index)`
    pub fn decode(bytes: []const u8, index: Index) DecodeError!Element {
        var stream = std.io.fixedBufferStream(bytes[index..]);
        var reader = stream.reader();

        const tag = try Tag.decode(reader);
        const size_or_len_size = try reader.readByte();

        var start = index + 2;
        var end = start + size_or_len_size;
        // short form between 0-127
        if (size_or_len_size < 128) {
            if (end > bytes.len) return error.InvalidLength;
        } else {
            // long form between 0 and std.math.maxInt(u1024)
            const len_size: u7 = @truncate(size_or_len_size);
            start += len_size;
            if (len_size > @sizeOf(Index)) return error.InvalidLength;

            const len = try reader.readVarInt(Index, .big, len_size);
            if (len < 128) return error.InvalidLength; // should have used short form

            end = std.math.add(Index, start, len) catch return error.InvalidLength;
            if (end > bytes.len) return error.InvalidLength;
        }

        return Element{ .tag = tag, .slice = Slice{ .start = start, .end = end } };
    }
};

test Element {
    const short_form = [_]u8{ 0x30, 0x03, 0x02, 0x01, 0x09 };
    try std.testing.expectEqual(Element{
        .tag = Tag.universal(.sequence, true),
        .slice = Element.Slice{ .start = 2, .end = short_form.len },
    }, Element.decode(&short_form, 0));

    const long_form = [_]u8{ 0x30, 129, 129 } ++ [_]u8{0} ** 129;
    try std.testing.expectEqual(Element{
        .tag = Tag.universal(.sequence, true),
        .slice = Element.Slice{ .start = 3, .end = long_form.len },
    }, Element.decode(&long_form, 0));
}

/// For decoding.
pub const ExpectedTag = struct {
    number: ?Tag.Number = null,
    constructed: ?bool = null,
    class: ?Tag.Class = null,

    pub fn init(number: ?Tag.Number, constructed: ?bool, class: ?Tag.Class) ExpectedTag {
        return .{ .number = number, .constructed = constructed, .class = class };
    }

    pub fn primitive(number: ?Tag.Number) ExpectedTag {
        return .{ .number = number, .constructed = false, .class = .universal };
    }

    pub fn match(self: ExpectedTag, tag: Tag) bool {
        if (self.number) |e| {
            if (tag.number != e) return false;
        }
        if (self.constructed) |e| {
            if (tag.constructed != e) return false;
        }
        if (self.class) |e| {
            if (tag.class != e) return false;
        }
        return true;
    }
};

pub const FieldTag = struct {
    number: std.meta.Tag(Tag.Number),
    class: Tag.Class,
    explicit: bool = true,

    pub fn initExplicit(number: std.meta.Tag(Tag.Number), class: Tag.Class) FieldTag {
        return .{ .number = number, .class = class, .explicit = true };
    }

    pub fn initImplicit(number: std.meta.Tag(Tag.Number), class: Tag.Class) FieldTag {
        return .{ .number = number, .class = class, .explicit = false };
    }

    pub fn fromContainer(comptime Container: type, comptime field_name: []const u8) ?FieldTag {
        if (@hasDecl(Container, "asn1_tags") and @hasField(@TypeOf(Container.asn1_tags), field_name)) {
            return @field(Container.asn1_tags, field_name);
        }

        return null;
    }

    pub fn toTag(self: FieldTag) Tag {
        return Tag.init(@enumFromInt(self.number), self.explicit, self.class);
    }
};

pub const BitString = struct {
    /// Number of bits in rightmost byte that are unused.
    right_padding: u3 = 0,
    bytes: []const u8,

    pub fn bitLen(self: BitString) usize {
        return self.bytes.len * 8 - self.right_padding;
    }

    const asn1_tag = Tag.universal(.bitstring, false);

    pub fn decodeDer(decoder: *der.Decoder) !BitString {
        const ele = try decoder.element(asn1_tag.toExpected());
        const bytes = decoder.view(ele);

        if (bytes.len < 1) return error.InvalidBitString;
        const padding = bytes[0];
        if (padding >= 8) return error.InvalidBitString;
        const right_padding: u3 = @intCast(padding);

        // DER requires that unused bits be zero.
        if (@ctz(bytes[bytes.len - 1]) < right_padding) return error.InvalidBitString;

        return BitString{ .bytes = bytes[1..], .right_padding = right_padding };
    }

    pub fn encodeDer(self: BitString, encoder: *der.Encoder) !void {
        try encoder.writer().writeAll(self.bytes);
        try encoder.writer().writeByte(self.right_padding);
        try encoder.length(self.bytes.len + 1);
        try encoder.tag(asn1_tag);
    }
};

pub fn Opaque(comptime tag: Tag) type {
    return struct {
        bytes: []const u8,

        pub fn decodeDer(decoder: *der.Decoder) !@This() {
            const ele = try decoder.element(tag.toExpected());
            if (tag.constructed) decoder.index = ele.slice.end;
            return .{ .bytes = decoder.view(ele) };
        }

        pub fn encodeDer(self: @This(), encoder: *der.Encoder) !void {
            try encoder.tagBytes(tag, self.bytes);
        }
    };
}

/// Use sparingly.
pub const Any = struct {
    tag: Tag,
    bytes: []const u8,

    pub fn decodeDer(decoder: *der.Decoder) !@This() {
        const ele = try decoder.element(ExpectedTag{});
        return .{ .tag = ele.tag, .bytes = decoder.view(ele) };
    }

    pub fn encodeDer(self: @This(), encoder: *der.Encoder) !void {
        try encoder.tagBytes(self.tag, self.bytes);
    }
};

test {
    _ = der;
    _ = Oid;
    _ = @import("asn1/test.zig");
}
