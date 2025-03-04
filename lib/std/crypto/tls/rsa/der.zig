//! An encoding of ASN.1.
//!
//! Distinguised Encoding Rules as defined in X.690 and X.691.
//!
//! A version of Basic Encoding Rules (BER) where there is exactly ONE way to
//! represent non-constructed elements. This is useful for cryptographic signatures.
//!
//! Currently an implementation detail of the standard library not fit for public
//! use since it's missing an encoder.

const std = @import("std");
const builtin = @import("builtin");

pub const Index = usize;
const log = std.log.scoped(.der);

/// A secure DER parser that:
/// - Does NOT read memory outside `bytes`.
/// - Does NOT return elements with slices outside `bytes`.
/// - Errors on values that do NOT follow DER rules.
///     - Lengths that could be represented in a shorter form.
///     - Booleans that are not 0xff or 0x00.
pub const Parser = struct {
    bytes: []const u8,
    index: Index = 0,

    pub const Error = Element.Error || error{
        UnexpectedElement,
        InvalidIntegerEncoding,
        Overflow,
        NonCanonical,
    };

    pub fn expectBool(self: *Parser) Error!bool {
        const ele = try self.expect(.universal, false, .boolean);
        if (ele.slice.len() != 1) return error.InvalidBool;

        return switch (self.view(ele)[0]) {
            0x00 => false,
            0xff => true,
            else => error.InvalidBool,
        };
    }

    pub fn expectBitstring(self: *Parser) Error!BitString {
        const ele = try self.expect(.universal, false, .bitstring);
        const bytes = self.view(ele);
        const right_padding = bytes[0];
        if (right_padding >= 8) return error.InvalidBitString;
        return .{
            .bytes = bytes[1..],
            .right_padding = @intCast(right_padding),
        };
    }

    // TODO: return high resolution date time type instead of epoch seconds
    pub fn expectDateTime(self: *Parser) Error!i64 {
        const ele = try self.expect(.universal, false, null);
        const bytes = self.view(ele);
        switch (ele.identifier.tag) {
            .utc_time => {
                // Example: "YYMMDD000000Z"
                if (bytes.len != 13)
                    return error.InvalidDateTime;
                if (bytes[12] != 'Z')
                    return error.InvalidDateTime;

                var date: Date = undefined;
                date.year = try parseTimeDigits(bytes[0..2], 0, 99);
                date.year += if (date.year >= 50) 1900 else 2000;
                date.month = try parseTimeDigits(bytes[2..4], 1, 12);
                date.day = try parseTimeDigits(bytes[4..6], 1, 31);
                const time = try parseTime(bytes[6..12]);

                return date.toEpochSeconds() + time.toSec();
            },
            .generalized_time => {
                // Examples:
                // "19920622123421Z"
                // "19920722132100.3Z"
                if (bytes.len < 15)
                    return error.InvalidDateTime;

                var date: Date = undefined;
                date.year = try parseYear4(bytes[0..4]);
                date.month = try parseTimeDigits(bytes[4..6], 1, 12);
                date.day = try parseTimeDigits(bytes[6..8], 1, 31);
                const time = try parseTime(bytes[8..14]);

                return date.toEpochSeconds() + time.toSec();
            },
            else => return error.InvalidDateTime,
        }
    }

    pub fn expectOid(self: *Parser) Error![]const u8 {
        const oid = try self.expect(.universal, false, .object_identifier);
        return self.view(oid);
    }

    pub fn expectEnum(self: *Parser, comptime Enum: type) Error!Enum {
        const oid = try self.expectOid();
        return Enum.oids.get(oid) orelse {
            if (builtin.mode == .Debug) {
                var buf: [256]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                try @import("./oid.zig").decode(oid, stream.writer());
                log.warn("unknown oid {s} for enum {s}\n", .{ stream.getWritten(), @typeName(Enum) });
            }
            return error.UnknownObjectId;
        };
    }

    pub fn expectInt(self: *Parser, comptime T: type) Error!T {
        const ele = try self.expectPrimitive(.integer);
        const bytes = self.view(ele);

        const info = @typeInfo(T);
        if (info != .int) @compileError(@typeName(T) ++ " is not an int type");
        const Shift = std.math.Log2Int(u8);

        var result: std.meta.Int(.unsigned, info.int.bits) = 0;
        for (bytes, 0..) |b, index| {
            const shifted = @shlWithOverflow(b, @as(Shift, @intCast(index * 8)));
            if (shifted[1] == 1) return error.Overflow;

            result |= shifted[0];
        }

        return @bitCast(result);
    }

    pub fn expectString(self: *Parser, allowed: std.EnumSet(String.Tag)) Error!String {
        const ele = try self.expect(.universal, false, null);
        switch (ele.identifier.tag) {
            inline .string_utf8,
            .string_numeric,
            .string_printable,
            .string_teletex,
            .string_videotex,
            .string_ia5,
            .string_visible,
            .string_universal,
            .string_bmp,
            => |t| {
                const tagname = @tagName(t)["string_".len..];
                const tag = std.meta.stringToEnum(String.Tag, tagname) orelse unreachable;
                if (allowed.contains(tag)) {
                    return String{ .tag = tag, .data = self.view(ele) };
                }
            },
            else => {},
        }
        return error.UnexpectedElement;
    }

    pub fn expectPrimitive(self: *Parser, tag: ?Identifier.Tag) Error!Element {
        var elem = try self.expect(.universal, false, tag);
        if (tag == .integer and elem.slice.len() > 0) {
            if (self.view(elem)[0] == 0) elem.slice.start += 1;
            if (elem.slice.len() > 0 and self.view(elem)[0] == 0) return error.InvalidIntegerEncoding;
        }
        return elem;
    }

    /// Remember to call `expectEnd`
    pub fn expectSequence(self: *Parser) Error!Element {
        return try self.expect(.universal, true, .sequence);
    }

    /// Remember to call `expectEnd`
    pub fn expectSequenceOf(self: *Parser) Error!Element {
        return try self.expect(.universal, true, .sequence_of);
    }

    pub fn expectEnd(self: *Parser, val: usize) Error!void {
        if (self.index != val) return error.NonCanonical; // either forgot to parse end OR an attacker
    }

    pub fn expect(
        self: *Parser,
        class: ?Identifier.Class,
        constructed: ?bool,
        tag: ?Identifier.Tag,
    ) Error!Element {
        if (self.index >= self.bytes.len) return error.EndOfStream;

        const res = try Element.init(self.bytes, self.index);
        if (tag) |e| {
            if (res.identifier.tag != e) return error.UnexpectedElement;
        }
        if (constructed) |e| {
            if (res.identifier.constructed != e) return error.UnexpectedElement;
        }
        if (class) |e| {
            if (res.identifier.class != e) return error.UnexpectedElement;
        }
        self.index = if (res.identifier.constructed) res.slice.start else res.slice.end;
        return res;
    }

    pub fn view(self: Parser, elem: Element) []const u8 {
        return elem.slice.view(self.bytes);
    }

    pub fn seek(self: *Parser, index: usize) void {
        self.index = index;
    }

    pub fn eof(self: *Parser) bool {
        return self.index == self.bytes.len;
    }
};

pub const Element = struct {
    identifier: Identifier,
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

    pub const Error = error{ InvalidLength, EndOfStream };

    pub fn init(bytes: []const u8, index: Index) Error!Element {
        var stream = std.io.fixedBufferStream(bytes[index..]);
        var reader = stream.reader();

        const identifier = @as(Identifier, @bitCast(try reader.readByte()));
        const size_or_len_size = try reader.readByte();

        var start = index + 2;
        // short form between 0-127
        if (size_or_len_size < 128) {
            const end = start + size_or_len_size;
            if (end > bytes.len) return error.InvalidLength;

            return .{ .identifier = identifier, .slice = .{ .start = start, .end = end } };
        }

        // long form between 0 and std.math.maxInt(u1024)
        const len_size: u7 = @truncate(size_or_len_size);
        start += len_size;
        if (len_size > @sizeOf(Index)) return error.InvalidLength;
        const len = try reader.readVarInt(Index, .big, len_size);
        if (len < 128) return error.InvalidLength; // should have used short form

        const end = std.math.add(Index, start, len) catch return error.InvalidLength;
        if (end > bytes.len) return error.InvalidLength;

        return .{ .identifier = identifier, .slice = .{ .start = start, .end = end } };
    }
};

test Element {
    const short_form = [_]u8{ 0x30, 0x03, 0x02, 0x01, 0x09 };
    try std.testing.expectEqual(Element{
        .identifier = Identifier{ .tag = .sequence, .constructed = true, .class = .universal },
        .slice = .{ .start = 2, .end = short_form.len },
    }, Element.init(&short_form, 0));

    const long_form = [_]u8{ 0x30, 129, 129 } ++ [_]u8{0} ** 129;
    try std.testing.expectEqual(Element{
        .identifier = Identifier{ .tag = .sequence, .constructed = true, .class = .universal },
        .slice = .{ .start = 3, .end = long_form.len },
    }, Element.init(&long_form, 0));
}

test "parser.expectInt" {
    const one = [_]u8{ 2, 1, 1 };
    var parser = Parser{ .bytes = &one };
    try std.testing.expectEqual(@as(u8, 1), try parser.expectInt(u8));
}

pub const Identifier = packed struct(u8) {
    tag: Tag,
    constructed: bool,
    class: Class,

    pub const Class = enum(u2) {
        universal,
        application,
        context_specific,
        private,
    };

    // https://www.oss.com/asn1/resources/asn1-made-simple/asn1-quick-reference/asn1-tags.html
    pub const Tag = enum(u5) {
        boolean = 1,
        integer = 2,
        bitstring = 3,
        octetstring = 4,
        null = 5,
        object_identifier = 6,
        real = 9,
        enumerated = 10,
        string_utf8 = 12,
        sequence = 16,
        sequence_of = 17,
        string_numeric = 18,
        string_printable = 19,
        string_teletex = 20,
        string_videotex = 21,
        string_ia5 = 22,
        utc_time = 23,
        generalized_time = 24,
        string_visible = 26,
        string_universal = 28,
        string_bmp = 30,
        _,
    };
};

pub const BitString = struct {
    bytes: []const u8,
    right_padding: u3,

    pub fn bitLen(self: BitString) usize {
        return self.bytes.len * 8 + self.right_padding;
    }
};

pub const String = struct {
    tag: Tag,
    data: []const u8,

    pub const Tag = enum {
        /// Blessed.
        utf8,
        /// us-ascii ([-][0-9][eE][.])*
        numeric,
        /// us-ascii ([A-Z][a-z][0-9][.?!,][ \t])*
        printable,
        /// iso-8859-1 with escaping into different character sets.
        /// Cursed.
        teletex,
        /// iso-8859-1
        videotex,
        /// us-ascii first 128 characters.
        ia5,
        /// us-ascii without control characters.
        visible,
        /// utf-32-be
        universal,
        /// utf-16-be
        bmp,
    };

    pub const all = [_]Tag{
        .utf8,
        .numeric,
        .printable,
        .teletex,
        .videotex,
        .ia5,
        .visible,
        .universal,
        .bmp,
    };
};

const Date = struct {
    year: Year,
    month: u8,
    day: u8,

    const Year = std.time.epoch.Year;

    fn toEpochSeconds(date: Date) i64 {
        // Euclidean Affine Transform by Cassio and Neri.
        // Shift and correction constants for 1970-01-01.
        const s = 82;
        const K = 719468 + 146097 * s;
        const L = 400 * s;

        const Y_G: u32 = date.year;
        const M_G: u32 = date.month;
        const D_G: u32 = date.day;
        // Map to computational calendar.
        const J: u32 = if (M_G <= 2) 1 else 0;
        const Y: u32 = Y_G + L - J;
        const M: u32 = if (J != 0) M_G + 12 else M_G;
        const D: u32 = D_G - 1;
        const C: u32 = Y / 100;

        // Rata die.
        const y_star: u32 = 1461 * Y / 4 - C + C / 4;
        const m_star: u32 = (979 * M - 2919) / 32;
        const N: u32 = y_star + m_star + D;
        const days: i32 = @intCast(N - K);

        return @as(i64, days) * std.time.epoch.secs_per_day;
    }
};

const Time = struct {
    hour: std.math.IntFittingRange(0, 24),
    minute: std.math.IntFittingRange(0, 60),
    second: std.math.IntFittingRange(0, 60),

    fn toSec(t: Time) i64 {
        var sec: i64 = 0;
        sec += @as(i64, t.hour) * 60 * 60;
        sec += @as(i64, t.minute) * 60;
        sec += t.second;
        return sec;
    }
};

fn parseTimeDigits(
    text: *const [2]u8,
    min: comptime_int,
    max: comptime_int,
) !std.math.IntFittingRange(min, max) {
    const result = std.fmt.parseInt(std.math.IntFittingRange(min, max), text, 10) catch
        return error.InvalidTime;
    if (result < min) return error.InvalidTime;
    if (result > max) return error.InvalidTime;
    return result;
}

test parseTimeDigits {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(u8, 0), try parseTimeDigits("00", 0, 99));
    try expectEqual(@as(u8, 99), try parseTimeDigits("99", 0, 99));
    try expectEqual(@as(u8, 42), try parseTimeDigits("42", 0, 99));

    const expectError = std.testing.expectError;
    try expectError(error.InvalidTime, parseTimeDigits("13", 1, 12));
    try expectError(error.InvalidTime, parseTimeDigits("00", 1, 12));
    try expectError(error.InvalidTime, parseTimeDigits("Di", 0, 99));
}

fn parseYear4(text: *const [4]u8) !Date.Year {
    const result = std.fmt.parseInt(Date.Year, text, 10) catch return error.InvalidYear;
    if (result > 9999) return error.InvalidYear;
    return result;
}

test parseYear4 {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(Date.Year, 0), try parseYear4("0000"));
    try expectEqual(@as(Date.Year, 9999), try parseYear4("9999"));
    try expectEqual(@as(Date.Year, 1988), try parseYear4("1988"));

    const expectError = std.testing.expectError;
    try expectError(error.InvalidYear, parseYear4("999b"));
    try expectError(error.InvalidYear, parseYear4("crap"));
    try expectError(error.InvalidYear, parseYear4("r:bQ"));
}

fn parseTime(bytes: *const [6]u8) !Time {
    return .{
        .hour = try parseTimeDigits(bytes[0..2], 0, 23),
        .minute = try parseTimeDigits(bytes[2..4], 0, 59),
        .second = try parseTimeDigits(bytes[4..6], 0, 59),
    };
}
