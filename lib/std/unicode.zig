const std = @import("./std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const native_endian = builtin.cpu.arch.endian();

/// Use this to replace an unknown, unrecognized, or unrepresentable character.
///
/// See also: https://en.wikipedia.org/wiki/Specials_(Unicode_block)#Replacement_character
pub const replacement_character: u21 = 0xFFFD;

/// Returns how many bytes the UTF-8 representation would require
/// for the given codepoint.
pub fn utf8CodepointSequenceLength(c: u21) !u3 {
    if (c < 0x80) return @as(u3, 1);
    if (c < 0x800) return @as(u3, 2);
    if (c < 0x10000) return @as(u3, 3);
    if (c < 0x110000) return @as(u3, 4);
    return error.CodepointTooLarge;
}

/// Given the first byte of a UTF-8 codepoint,
/// returns a number 1-4 indicating the total length of the codepoint in bytes.
/// If this byte does not match the form of a UTF-8 start byte, returns Utf8InvalidStartByte.
pub fn utf8ByteSequenceLength(first_byte: u8) !u3 {
    // The switch is optimized much better than a "smart" approach using @clz
    return switch (first_byte) {
        0b0000_0000...0b0111_1111 => 1,
        0b1100_0000...0b1101_1111 => 2,
        0b1110_0000...0b1110_1111 => 3,
        0b1111_0000...0b1111_0111 => 4,
        else => error.Utf8InvalidStartByte,
    };
}

/// Encodes the given codepoint into a UTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in UTF-8.
/// Returns: the number of bytes written to out.
pub fn utf8Encode(c: u21, out: []u8) error{ Utf8CannotEncodeSurrogateHalf, CodepointTooLarge }!u3 {
    return utf8EncodeImpl(c, out, .cannot_encode_surrogate_half);
}

const Surrogates = enum {
    cannot_encode_surrogate_half,
    can_encode_surrogate_half,
};

fn utf8EncodeImpl(c: u21, out: []u8, comptime surrogates: Surrogates) !u3 {
    const length = try utf8CodepointSequenceLength(c);
    assert(out.len >= length);
    switch (length) {
        // The pattern for each is the same
        // - Increasing the initial shift by 6 each time
        // - Each time after the first shorten the shifted
        //   value to a max of 0b111111 (63)
        1 => out[0] = @as(u8, @intCast(c)), // Can just do 0 + codepoint for initial range
        2 => {
            out[0] = @as(u8, @intCast(0b11000000 | (c >> 6)));
            out[1] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        3 => {
            if (surrogates == .cannot_encode_surrogate_half and isSurrogateCodepoint(c)) {
                return error.Utf8CannotEncodeSurrogateHalf;
            }
            out[0] = @as(u8, @intCast(0b11100000 | (c >> 12)));
            out[1] = @as(u8, @intCast(0b10000000 | ((c >> 6) & 0b111111)));
            out[2] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        4 => {
            out[0] = @as(u8, @intCast(0b11110000 | (c >> 18)));
            out[1] = @as(u8, @intCast(0b10000000 | ((c >> 12) & 0b111111)));
            out[2] = @as(u8, @intCast(0b10000000 | ((c >> 6) & 0b111111)));
            out[3] = @as(u8, @intCast(0b10000000 | (c & 0b111111)));
        },
        else => unreachable,
    }
    return length;
}

pub inline fn utf8EncodeComptime(comptime c: u21) [
    utf8CodepointSequenceLength(c) catch |err|
        @compileError(@errorName(err))
]u8 {
    comptime var result: [
        utf8CodepointSequenceLength(c) catch
            unreachable
    ]u8 = undefined;
    comptime assert((utf8Encode(c, &result) catch |err|
        @compileError(@errorName(err))) == result.len);
    return result;
}

const Utf8DecodeError = Utf8Decode2Error || Utf8Decode3Error || Utf8Decode4Error;

/// Deprecated. This function has an awkward API that is too easy to use incorrectly.
pub fn utf8Decode(bytes: []const u8) Utf8DecodeError!u21 {
    return switch (bytes.len) {
        1 => bytes[0],
        2 => utf8Decode2(bytes[0..2].*),
        3 => utf8Decode3(bytes[0..3].*),
        4 => utf8Decode4(bytes[0..4].*),
        else => unreachable,
    };
}

const Utf8Decode2Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
};
pub fn utf8Decode2(bytes: [2]u8) Utf8Decode2Error!u21 {
    assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u21 = bytes[0] & 0b00011111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (value < 0x80) return error.Utf8OverlongEncoding;

    return value;
}

const Utf8Decode3Error = Utf8Decode3AllowSurrogateHalfError || error{
    Utf8EncodesSurrogateHalf,
};
pub fn utf8Decode3(bytes: [3]u8) Utf8Decode3Error!u21 {
    const value = try utf8Decode3AllowSurrogateHalf(bytes);

    if (0xd800 <= value and value <= 0xdfff) return error.Utf8EncodesSurrogateHalf;

    return value;
}

const Utf8Decode3AllowSurrogateHalfError = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
};
pub fn utf8Decode3AllowSurrogateHalf(bytes: [3]u8) Utf8Decode3AllowSurrogateHalfError!u21 {
    assert(bytes[0] & 0b11110000 == 0b11100000);
    var value: u21 = bytes[0] & 0b00001111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (bytes[2] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (value < 0x800) return error.Utf8OverlongEncoding;

    return value;
}

const Utf8Decode4Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8CodepointTooLarge,
};
pub fn utf8Decode4(bytes: [4]u8) Utf8Decode4Error!u21 {
    assert(bytes[0] & 0b11111000 == 0b11110000);
    var value: u21 = bytes[0] & 0b00000111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (bytes[2] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (bytes[3] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[3] & 0b00111111;

    if (value < 0x10000) return error.Utf8OverlongEncoding;
    if (value > 0x10FFFF) return error.Utf8CodepointTooLarge;

    return value;
}

/// Returns true if the given unicode codepoint can be encoded in UTF-8.
pub fn utf8ValidCodepoint(value: u21) bool {
    return switch (value) {
        0xD800...0xDFFF => false, // Surrogates range
        0x110000...0x1FFFFF => false, // Above the maximum codepoint value
        else => true,
    };
}

/// Returns the length of a supplied UTF-8 string literal in terms of unicode
/// codepoints.
pub fn utf8CountCodepoints(s: []const u8) !usize {
    var len: usize = 0;

    const N = @sizeOf(usize);
    const MASK = 0x80 * (std.math.maxInt(usize) / 0xff);

    var i: usize = 0;
    while (i < s.len) {
        // Fast path for ASCII sequences
        while (i + N <= s.len) : (i += N) {
            const v = mem.readInt(usize, s[i..][0..N], native_endian);
            if (v & MASK != 0) break;
            len += N;
        }

        if (i < s.len) {
            const n = try utf8ByteSequenceLength(s[i]);
            if (i + n > s.len) return error.TruncatedInput;

            switch (n) {
                1 => {}, // ASCII, no validation needed
                else => _ = try utf8Decode(s[i..][0..n]),
            }

            i += n;
            len += 1;
        }
    }

    return len;
}

/// Returns true if the input consists entirely of UTF-8 codepoints
pub fn utf8ValidateSlice(input: []const u8) bool {
    return utf8ValidateSliceImpl(input, .cannot_encode_surrogate_half);
}

fn utf8ValidateSliceImpl(input: []const u8, comptime surrogates: Surrogates) bool {
    var remaining = input;

    if (std.simd.suggestVectorLength(u8)) |chunk_len| {
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and skip ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII byte
                break;
            }
            remaining = remaining[chunk_len..];
        }
    }

    // default lowest and highest continuation byte
    const lo_cb = 0b10000000;
    const hi_cb = 0b10111111;

    const min_non_ascii_codepoint = 0x80;

    // The first nibble is used to identify the continuation byte range to
    // accept. The second nibble is the size.
    const xx = 0xF1; // invalid: size 1
    const as = 0xF0; // ASCII: size 1
    const s1 = 0x02; // accept 0, size 2
    const s2 = switch (surrogates) {
        .cannot_encode_surrogate_half => 0x13, // accept 1, size 3
        .can_encode_surrogate_half => 0x03, // accept 0, size 3
    };
    const s3 = 0x03; // accept 0, size 3
    const s4 = switch (surrogates) {
        .cannot_encode_surrogate_half => 0x23, // accept 2, size 3
        .can_encode_surrogate_half => 0x03, // accept 0, size 3
    };
    const s5 = 0x34; // accept 3, size 4
    const s6 = 0x04; // accept 0, size 4
    const s7 = 0x44; // accept 4, size 4

    // Information about the first byte in a UTF-8 sequence.
    const first = comptime ([_]u8{as} ** 128) ++ ([_]u8{xx} ** 64) ++ [_]u8{
        xx, xx, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
        s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1, s1,
        s2, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s3, s4, s3, s3,
        s5, s6, s6, s6, s7, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx, xx,
    };

    const n = remaining.len;
    var i: usize = 0;
    while (i < n) {
        const first_byte = remaining[i];
        if (first_byte < min_non_ascii_codepoint) {
            i += 1;
            continue;
        }

        const info = first[first_byte];
        if (info == xx) {
            return false; // Illegal starter byte.
        }

        const size = info & 7;
        if (i + size > n) {
            return false; // Short or invalid.
        }

        // Figure out the acceptable low and high continuation bytes, starting
        // with our defaults.
        var accept_lo: u8 = lo_cb;
        var accept_hi: u8 = hi_cb;

        switch (info >> 4) {
            0 => {},
            1 => accept_lo = 0xA0,
            2 => accept_hi = 0x9F,
            3 => accept_lo = 0x90,
            4 => accept_hi = 0x8F,
            else => unreachable,
        }

        const c1 = remaining[i + 1];
        if (c1 < accept_lo or accept_hi < c1) {
            return false;
        }

        switch (size) {
            2 => i += 2,
            3 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return false;
                }
                i += 3;
            },
            4 => {
                const c2 = remaining[i + 2];
                if (c2 < lo_cb or hi_cb < c2) {
                    return false;
                }
                const c3 = remaining[i + 3];
                if (c3 < lo_cb or hi_cb < c3) {
                    return false;
                }
                i += 4;
            },
            else => unreachable,
        }
    }

    return true;
}

/// Utf8View iterates the code points of a utf-8 encoded string.
///
/// ```
/// var utf8 = (try std.unicode.Utf8View.init("hi there")).iterator();
/// while (utf8.nextCodepointSlice()) |codepoint| {
///   std.debug.print("got codepoint {s}\n", .{codepoint});
/// }
/// ```
pub const Utf8View = struct {
    bytes: []const u8,

    pub fn init(s: []const u8) !Utf8View {
        if (!utf8ValidateSlice(s)) {
            return error.InvalidUtf8;
        }

        return initUnchecked(s);
    }

    pub fn initUnchecked(s: []const u8) Utf8View {
        return Utf8View{ .bytes = s };
    }

    pub inline fn initComptime(comptime s: []const u8) Utf8View {
        return comptime if (init(s)) |r| r else |err| switch (err) {
            error.InvalidUtf8 => {
                @compileError("invalid utf8");
            },
        };
    }

    pub fn iterator(s: Utf8View) Utf8Iterator {
        return Utf8Iterator{
            .bytes = s.bytes,
            .i = 0,
        };
    }
};

pub const Utf8Iterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn nextCodepointSlice(it: *Utf8Iterator) ?[]const u8 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        const cp_len = utf8ByteSequenceLength(it.bytes[it.i]) catch unreachable;
        it.i += cp_len;
        return it.bytes[it.i - cp_len .. it.i];
    }

    pub fn nextCodepoint(it: *Utf8Iterator) ?u21 {
        const slice = it.nextCodepointSlice() orelse return null;
        return utf8Decode(slice) catch unreachable;
    }

    /// Look ahead at the next n codepoints without advancing the iterator.
    /// If fewer than n codepoints are available, then return the remainder of the string.
    pub fn peek(it: *Utf8Iterator, n: usize) []const u8 {
        const original_i = it.i;
        defer it.i = original_i;

        var end_ix = original_i;
        var found: usize = 0;
        while (found < n) : (found += 1) {
            const next_codepoint = it.nextCodepointSlice() orelse return it.bytes[original_i..];
            end_ix += next_codepoint.len;
        }

        return it.bytes[original_i..end_ix];
    }
};

pub fn utf16IsHighSurrogate(c: u16) bool {
    return c & ~@as(u16, 0x03ff) == 0xd800;
}

pub fn utf16IsLowSurrogate(c: u16) bool {
    return c & ~@as(u16, 0x03ff) == 0xdc00;
}

/// Returns how many code units the UTF-16 representation would require
/// for the given codepoint.
pub fn utf16CodepointSequenceLength(c: u21) !u2 {
    if (c <= 0xFFFF) return 1;
    if (c <= 0x10FFFF) return 2;
    return error.CodepointTooLarge;
}

test utf16CodepointSequenceLength {
    try testing.expectEqual(@as(u2, 1), try utf16CodepointSequenceLength('a'));
    try testing.expectEqual(@as(u2, 1), try utf16CodepointSequenceLength(0xFFFF));
    try testing.expectEqual(@as(u2, 2), try utf16CodepointSequenceLength(0x10000));
    try testing.expectEqual(@as(u2, 2), try utf16CodepointSequenceLength(0x10FFFF));
    try testing.expectError(error.CodepointTooLarge, utf16CodepointSequenceLength(0x110000));
}

/// Given the first code unit of a UTF-16 codepoint, returns a number 1-2
/// indicating the total length of the codepoint in UTF-16 code units.
/// If this code unit does not match the form of a UTF-16 start code unit, returns Utf16InvalidStartCodeUnit.
pub fn utf16CodeUnitSequenceLength(first_code_unit: u16) !u2 {
    if (utf16IsHighSurrogate(first_code_unit)) return 2;
    if (utf16IsLowSurrogate(first_code_unit)) return error.Utf16InvalidStartCodeUnit;
    return 1;
}

test utf16CodeUnitSequenceLength {
    try testing.expectEqual(@as(u2, 1), try utf16CodeUnitSequenceLength('a'));
    try testing.expectEqual(@as(u2, 1), try utf16CodeUnitSequenceLength(0xFFFF));
    try testing.expectEqual(@as(u2, 2), try utf16CodeUnitSequenceLength(0xDBFF));
    try testing.expectError(error.Utf16InvalidStartCodeUnit, utf16CodeUnitSequenceLength(0xDFFF));
}

/// Decodes the codepoint encoded in the given pair of UTF-16 code units.
/// Asserts that `surrogate_pair.len >= 2` and that the first code unit is a high surrogate.
/// If the second code unit is not a low surrogate, error.ExpectedSecondSurrogateHalf is returned.
pub fn utf16DecodeSurrogatePair(surrogate_pair: []const u16) !u21 {
    assert(surrogate_pair.len >= 2);
    assert(utf16IsHighSurrogate(surrogate_pair[0]));
    const high_half: u21 = surrogate_pair[0];
    const low_half = surrogate_pair[1];
    if (!utf16IsLowSurrogate(low_half)) return error.ExpectedSecondSurrogateHalf;
    return 0x10000 + ((high_half & 0x03ff) << 10) | (low_half & 0x03ff);
}

pub const Utf16LeIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(s: []const u16) Utf16LeIterator {
        return Utf16LeIterator{
            .bytes = mem.sliceAsBytes(s),
            .i = 0,
        };
    }

    pub const NextCodepointError = error{ DanglingSurrogateHalf, ExpectedSecondSurrogateHalf, UnexpectedSecondSurrogateHalf };

    pub fn nextCodepoint(it: *Utf16LeIterator) NextCodepointError!?u21 {
        assert(it.i <= it.bytes.len);
        if (it.i == it.bytes.len) return null;
        var code_units: [2]u16 = undefined;
        code_units[0] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
        it.i += 2;
        if (utf16IsHighSurrogate(code_units[0])) {
            // surrogate pair
            if (it.i >= it.bytes.len) return error.DanglingSurrogateHalf;
            code_units[1] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
            const codepoint = try utf16DecodeSurrogatePair(&code_units);
            it.i += 2;
            return codepoint;
        } else if (utf16IsLowSurrogate(code_units[0])) {
            return error.UnexpectedSecondSurrogateHalf;
        } else {
            return code_units[0];
        }
    }
};

/// Returns the length of a supplied UTF-16 string literal in terms of unicode
/// codepoints.
pub fn utf16CountCodepoints(utf16le: []const u16) !usize {
    var len: usize = 0;
    var it = Utf16LeIterator.init(utf16le);
    while (try it.nextCodepoint()) |_| len += 1;
    return len;
}

fn testUtf16CountCodepoints() !void {
    try testing.expectEqual(
        @as(usize, 1),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("a")),
    );
    try testing.expectEqual(
        @as(usize, 10),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("abcdefghij")),
    );
    try testing.expectEqual(
        @as(usize, 10),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("äåéëþüúíóö")),
    );
    try testing.expectEqual(
        @as(usize, 5),
        try utf16CountCodepoints(utf8ToUtf16LeStringLiteral("こんにちは")),
    );
}

test "utf16 count codepoints" {
    @setEvalBranchQuota(2000);
    try testUtf16CountCodepoints();
    try comptime testUtf16CountCodepoints();
}

test "utf8 encode" {
    try comptime testUtf8Encode();
    try testUtf8Encode();
}
fn testUtf8Encode() !void {
    // A few taken from wikipedia a few taken elsewhere
    var array: [4]u8 = undefined;
    try testing.expect((try utf8Encode(try utf8Decode("€"), array[0..])) == 3);
    try testing.expect(array[0] == 0b11100010);
    try testing.expect(array[1] == 0b10000010);
    try testing.expect(array[2] == 0b10101100);

    try testing.expect((try utf8Encode(try utf8Decode("$"), array[0..])) == 1);
    try testing.expect(array[0] == 0b00100100);

    try testing.expect((try utf8Encode(try utf8Decode("¢"), array[0..])) == 2);
    try testing.expect(array[0] == 0b11000010);
    try testing.expect(array[1] == 0b10100010);

    try testing.expect((try utf8Encode(try utf8Decode("𐍈"), array[0..])) == 4);
    try testing.expect(array[0] == 0b11110000);
    try testing.expect(array[1] == 0b10010000);
    try testing.expect(array[2] == 0b10001101);
    try testing.expect(array[3] == 0b10001000);
}

test "utf8 encode comptime" {
    try testing.expectEqualSlices(u8, "€", &utf8EncodeComptime('€'));
    try testing.expectEqualSlices(u8, "$", &utf8EncodeComptime('$'));
    try testing.expectEqualSlices(u8, "¢", &utf8EncodeComptime('¢'));
    try testing.expectEqualSlices(u8, "𐍈", &utf8EncodeComptime('𐍈'));
}

test "utf8 encode error" {
    try comptime testUtf8EncodeError();
    try testUtf8EncodeError();
}
fn testUtf8EncodeError() !void {
    var array: [4]u8 = undefined;
    try testErrorEncode(0xd800, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    try testErrorEncode(0xdfff, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    try testErrorEncode(0x110000, array[0..], error.CodepointTooLarge);
    try testErrorEncode(0x1fffff, array[0..], error.CodepointTooLarge);
}

fn testErrorEncode(codePoint: u21, array: []u8, expectedErr: anyerror) !void {
    try testing.expectError(expectedErr, utf8Encode(codePoint, array));
}

test "utf8 iterator on ascii" {
    try comptime testUtf8IteratorOnAscii();
    try testUtf8IteratorOnAscii();
}
fn testUtf8IteratorOnAscii() !void {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    try testing.expect(mem.eql(u8, "a", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "b", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "c", it1.nextCodepointSlice().?));
    try testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    try testing.expect(it2.nextCodepoint().? == 'a');
    try testing.expect(it2.nextCodepoint().? == 'b');
    try testing.expect(it2.nextCodepoint().? == 'c');
    try testing.expect(it2.nextCodepoint() == null);
}

test "utf8 view bad" {
    try comptime testUtf8ViewBad();
    try testUtf8ViewBad();
}
fn testUtf8ViewBad() !void {
    // Compile-time error.
    // const s3 = Utf8View.initComptime("\xfe\xf2");
    try testing.expectError(error.InvalidUtf8, Utf8View.init("hel\xadlo"));
}

test "utf8 view ok" {
    try comptime testUtf8ViewOk();
    try testUtf8ViewOk();
}
fn testUtf8ViewOk() !void {
    const s = Utf8View.initComptime("東京市");

    var it1 = s.iterator();
    try testing.expect(mem.eql(u8, "東", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "京", it1.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "市", it1.nextCodepointSlice().?));
    try testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    try testing.expect(it2.nextCodepoint().? == 0x6771);
    try testing.expect(it2.nextCodepoint().? == 0x4eac);
    try testing.expect(it2.nextCodepoint().? == 0x5e02);
    try testing.expect(it2.nextCodepoint() == null);
}

test "validate slice" {
    try comptime testValidateSlice();
    try testValidateSlice();

    // We skip a variable (based on recommended vector size) chunks of
    // ASCII characters. Let's make sure we're chunking correctly.
    const str = [_]u8{'a'} ** 550 ++ "\xc0";
    for (0..str.len - 3) |i| {
        try testing.expect(!utf8ValidateSlice(str[i..]));
    }
}
fn testValidateSlice() !void {
    try testing.expect(utf8ValidateSlice("abc"));
    try testing.expect(utf8ValidateSlice("abc\xdf\xbf"));
    try testing.expect(utf8ValidateSlice(""));
    try testing.expect(utf8ValidateSlice("a"));
    try testing.expect(utf8ValidateSlice("abc"));
    try testing.expect(utf8ValidateSlice("Ж"));
    try testing.expect(utf8ValidateSlice("ЖЖ"));
    try testing.expect(utf8ValidateSlice("брэд-ЛГТМ"));
    try testing.expect(utf8ValidateSlice("☺☻☹"));
    try testing.expect(utf8ValidateSlice("a\u{fffdb}"));
    try testing.expect(utf8ValidateSlice("\xf4\x8f\xbf\xbf"));
    try testing.expect(utf8ValidateSlice("abc\xdf\xbf"));

    try testing.expect(!utf8ValidateSlice("abc\xc0"));
    try testing.expect(!utf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!utf8ValidateSlice("aa\xe2"));
    try testing.expect(!utf8ValidateSlice("\x42\xfa"));
    try testing.expect(!utf8ValidateSlice("\x42\xfa\x43"));
    try testing.expect(!utf8ValidateSlice("abc\xc0"));
    try testing.expect(!utf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!utf8ValidateSlice("\xf4\x90\x80\x80"));
    try testing.expect(!utf8ValidateSlice("\xf7\xbf\xbf\xbf"));
    try testing.expect(!utf8ValidateSlice("\xfb\xbf\xbf\xbf\xbf"));
    try testing.expect(!utf8ValidateSlice("\xc0\x80"));
    try testing.expect(!utf8ValidateSlice("\xed\xa0\x80"));
    try testing.expect(!utf8ValidateSlice("\xed\xbf\xbf"));
}

test "valid utf8" {
    try comptime testValidUtf8();
    try testValidUtf8();
}
fn testValidUtf8() !void {
    try testValid("\x00", 0x0);
    try testValid("\x20", 0x20);
    try testValid("\x7f", 0x7f);
    try testValid("\xc2\x80", 0x80);
    try testValid("\xdf\xbf", 0x7ff);
    try testValid("\xe0\xa0\x80", 0x800);
    try testValid("\xe1\x80\x80", 0x1000);
    try testValid("\xef\xbf\xbf", 0xffff);
    try testValid("\xf0\x90\x80\x80", 0x10000);
    try testValid("\xf1\x80\x80\x80", 0x40000);
    try testValid("\xf3\xbf\xbf\xbf", 0xfffff);
    try testValid("\xf4\x8f\xbf\xbf", 0x10ffff);
}

test "invalid utf8 continuation bytes" {
    try comptime testInvalidUtf8ContinuationBytes();
    try testInvalidUtf8ContinuationBytes();
}
fn testInvalidUtf8ContinuationBytes() !void {
    // unexpected continuation
    try testError("\x80", error.Utf8InvalidStartByte);
    try testError("\xbf", error.Utf8InvalidStartByte);
    // too many leading 1's
    try testError("\xf8", error.Utf8InvalidStartByte);
    try testError("\xff", error.Utf8InvalidStartByte);
    // expected continuation for 2 byte sequences
    try testError("\xc2", error.UnexpectedEof);
    try testError("\xc2\x00", error.Utf8ExpectedContinuation);
    try testError("\xc2\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 3 byte sequences
    try testError("\xe0", error.UnexpectedEof);
    try testError("\xe0\x00", error.UnexpectedEof);
    try testError("\xe0\xc0", error.UnexpectedEof);
    try testError("\xe0\xa0", error.UnexpectedEof);
    try testError("\xe0\xa0\x00", error.Utf8ExpectedContinuation);
    try testError("\xe0\xa0\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 4 byte sequences
    try testError("\xf0", error.UnexpectedEof);
    try testError("\xf0\x00", error.UnexpectedEof);
    try testError("\xf0\xc0", error.UnexpectedEof);
    try testError("\xf0\x90\x00", error.UnexpectedEof);
    try testError("\xf0\x90\xc0", error.UnexpectedEof);
    try testError("\xf0\x90\x80\x00", error.Utf8ExpectedContinuation);
    try testError("\xf0\x90\x80\xc0", error.Utf8ExpectedContinuation);
}

test "overlong utf8 codepoint" {
    try comptime testOverlongUtf8Codepoint();
    try testOverlongUtf8Codepoint();
}
fn testOverlongUtf8Codepoint() !void {
    try testError("\xc0\x80", error.Utf8OverlongEncoding);
    try testError("\xc1\xbf", error.Utf8OverlongEncoding);
    try testError("\xe0\x80\x80", error.Utf8OverlongEncoding);
    try testError("\xe0\x9f\xbf", error.Utf8OverlongEncoding);
    try testError("\xf0\x80\x80\x80", error.Utf8OverlongEncoding);
    try testError("\xf0\x8f\xbf\xbf", error.Utf8OverlongEncoding);
}

test "misc invalid utf8" {
    try comptime testMiscInvalidUtf8();
    try testMiscInvalidUtf8();
}
fn testMiscInvalidUtf8() !void {
    // codepoint out of bounds
    try testError("\xf4\x90\x80\x80", error.Utf8CodepointTooLarge);
    try testError("\xf7\xbf\xbf\xbf", error.Utf8CodepointTooLarge);
    // surrogate halves
    try testValid("\xed\x9f\xbf", 0xd7ff);
    try testError("\xed\xa0\x80", error.Utf8EncodesSurrogateHalf);
    try testError("\xed\xbf\xbf", error.Utf8EncodesSurrogateHalf);
    try testValid("\xee\x80\x80", 0xe000);
}

test "utf8 iterator peeking" {
    try comptime testUtf8Peeking();
    try testUtf8Peeking();
}

fn testUtf8Peeking() !void {
    const s = Utf8View.initComptime("noël");
    var it = s.iterator();

    try testing.expect(mem.eql(u8, "n", it.nextCodepointSlice().?));

    try testing.expect(mem.eql(u8, "o", it.peek(1)));
    try testing.expect(mem.eql(u8, "oë", it.peek(2)));
    try testing.expect(mem.eql(u8, "oël", it.peek(3)));
    try testing.expect(mem.eql(u8, "oël", it.peek(4)));
    try testing.expect(mem.eql(u8, "oël", it.peek(10)));

    try testing.expect(mem.eql(u8, "o", it.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "ë", it.nextCodepointSlice().?));
    try testing.expect(mem.eql(u8, "l", it.nextCodepointSlice().?));
    try testing.expect(it.nextCodepointSlice() == null);

    try testing.expect(mem.eql(u8, &[_]u8{}, it.peek(1)));
}

fn testError(bytes: []const u8, expected_err: anyerror) !void {
    try testing.expectError(expected_err, testDecode(bytes));
}

fn testValid(bytes: []const u8, expected_codepoint: u21) !void {
    try testing.expect((testDecode(bytes) catch unreachable) == expected_codepoint);
}

fn testDecode(bytes: []const u8) !u21 {
    const length = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < length) return error.UnexpectedEof;
    try testing.expect(bytes.len == length);
    return utf8Decode(bytes);
}

/// Print the given `utf8` string, encoded as UTF-8 bytes.
/// Ill-formed UTF-8 byte sequences are replaced by the replacement character (U+FFFD)
/// according to "U+FFFD Substitution of Maximal Subparts" from Chapter 3 of
/// the Unicode standard, and as specified by https://encoding.spec.whatwg.org/#utf-8-decoder
fn formatUtf8(
    utf8: []const u8,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var buf: [300]u8 = undefined; // just an arbitrary size
    var u8len: usize = 0;

    // This implementation is based on this specification:
    // https://encoding.spec.whatwg.org/#utf-8-decoder
    var codepoint: u21 = 0;
    var cont_bytes_seen: u3 = 0;
    var cont_bytes_needed: u3 = 0;
    var lower_boundary: u8 = 0x80;
    var upper_boundary: u8 = 0xBF;

    var i: usize = 0;
    while (i < utf8.len) {
        const byte = utf8[i];
        if (cont_bytes_needed == 0) {
            switch (byte) {
                0x00...0x7F => {
                    buf[u8len] = byte;
                    u8len += 1;
                },
                0xC2...0xDF => {
                    cont_bytes_needed = 1;
                    codepoint = byte & 0b00011111;
                },
                0xE0...0xEF => {
                    if (byte == 0xE0) lower_boundary = 0xA0;
                    if (byte == 0xED) upper_boundary = 0x9F;
                    cont_bytes_needed = 2;
                    codepoint = byte & 0b00001111;
                },
                0xF0...0xF4 => {
                    if (byte == 0xF0) lower_boundary = 0x90;
                    if (byte == 0xF4) upper_boundary = 0x8F;
                    cont_bytes_needed = 3;
                    codepoint = byte & 0b00000111;
                },
                else => {
                    u8len += utf8Encode(replacement_character, buf[u8len..]) catch unreachable;
                },
            }
            // consume the byte
            i += 1;
        } else if (byte < lower_boundary or byte > upper_boundary) {
            codepoint = 0;
            cont_bytes_needed = 0;
            cont_bytes_seen = 0;
            lower_boundary = 0x80;
            upper_boundary = 0xBF;
            u8len += utf8Encode(replacement_character, buf[u8len..]) catch unreachable;
            // do not consume the current byte, it should now be treated as a possible start byte
        } else {
            lower_boundary = 0x80;
            upper_boundary = 0xBF;
            codepoint <<= 6;
            codepoint |= byte & 0b00111111;
            cont_bytes_seen += 1;
            // consume the byte
            i += 1;

            if (cont_bytes_seen == cont_bytes_needed) {
                const codepoint_len = cont_bytes_seen + 1;
                const codepoint_start_i = i - codepoint_len;
                @memcpy(buf[u8len..][0..codepoint_len], utf8[codepoint_start_i..][0..codepoint_len]);
                u8len += codepoint_len;

                codepoint = 0;
                cont_bytes_needed = 0;
                cont_bytes_seen = 0;
            }
        }
        // make sure there's always enough room for another maximum length UTF-8 codepoint
        if (u8len + 4 > buf.len) {
            try writer.writeAll(buf[0..u8len]);
            u8len = 0;
        }
    }
    if (cont_bytes_needed != 0) {
        // we know there's enough room because we always flush
        // if there's less than 4 bytes remaining in the buffer.
        u8len += utf8Encode(replacement_character, buf[u8len..]) catch unreachable;
    }
    try writer.writeAll(buf[0..u8len]);
}

/// Return a Formatter for a (potentially ill-formed) UTF-8 string.
/// Ill-formed UTF-8 byte sequences are replaced by the replacement character (U+FFFD)
/// according to "U+FFFD Substitution of Maximal Subparts" from Chapter 3 of
/// the Unicode standard, and as specified by https://encoding.spec.whatwg.org/#utf-8-decoder
pub fn fmtUtf8(utf8: []const u8) std.fmt.Formatter(formatUtf8) {
    return .{ .data = utf8 };
}

test fmtUtf8 {
    const expectFmt = testing.expectFmt;
    try expectFmt("", "{}", .{fmtUtf8("")});
    try expectFmt("foo", "{}", .{fmtUtf8("foo")});
    try expectFmt("𐐷", "{}", .{fmtUtf8("𐐷")});

    // Table 3-8. U+FFFD for Non-Shortest Form Sequences
    try expectFmt("��������A", "{}", .{fmtUtf8("\xC0\xAF\xE0\x80\xBF\xF0\x81\x82A")});

    // Table 3-9. U+FFFD for Ill-Formed Sequences for Surrogates
    try expectFmt("��������A", "{}", .{fmtUtf8("\xED\xA0\x80\xED\xBF\xBF\xED\xAFA")});

    // Table 3-10. U+FFFD for Other Ill-Formed Sequences
    try expectFmt("�����A��B", "{}", .{fmtUtf8("\xF4\x91\x92\x93\xFFA\x80\xBFB")});

    // Table 3-11. U+FFFD for Truncated Sequences
    try expectFmt("����A", "{}", .{fmtUtf8("\xE1\x80\xE2\xF0\x91\x92\xF1\xBFA")});
}

fn utf16LeToUtf8ArrayListImpl(
    result: *std.ArrayList(u8),
    utf16le: []const u16,
    comptime surrogates: Surrogates,
) (switch (surrogates) {
    .cannot_encode_surrogate_half => Utf16LeToUtf8AllocError,
    .can_encode_surrogate_half => mem.Allocator.Error,
})!void {
    assert(result.unusedCapacitySlice().len >= utf16le.len);

    var remaining = utf16le;
    vectorized: {
        const chunk_len = std.simd.suggestVectorLength(u16) orelse break :vectorized;
        const Chunk = @Vector(chunk_len, u16);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(mem.nativeToLittle(u16, 0x7F));
            if (@reduce(.Or, chunk | mask != mask)) {
                // found a non ASCII code unit
                break;
            }
            const ascii_chunk: @Vector(chunk_len, u8) = @truncate(mem.nativeToLittle(Chunk, chunk));
            // We allocated enough space to encode every UTF-16 code unit
            // as ASCII, so if the entire string is ASCII then we are
            // guaranteed to have enough space allocated
            result.addManyAsArrayAssumeCapacity(chunk_len).* = ascii_chunk;
            remaining = remaining[chunk_len..];
        }
    }

    switch (surrogates) {
        .cannot_encode_surrogate_half => {
            var it = Utf16LeIterator.init(remaining);
            while (try it.nextCodepoint()) |codepoint| {
                const utf8_len = utf8CodepointSequenceLength(codepoint) catch unreachable;
                assert((utf8Encode(codepoint, try result.addManyAsSlice(utf8_len)) catch unreachable) == utf8_len);
            }
        },
        .can_encode_surrogate_half => {
            var it = Wtf16LeIterator.init(remaining);
            while (it.nextCodepoint()) |codepoint| {
                const utf8_len = utf8CodepointSequenceLength(codepoint) catch unreachable;
                assert((wtf8Encode(codepoint, try result.addManyAsSlice(utf8_len)) catch unreachable) == utf8_len);
            }
        },
    }
}

pub const Utf16LeToUtf8AllocError = mem.Allocator.Error || Utf16LeToUtf8Error;

pub fn utf16LeToUtf8ArrayList(result: *std.ArrayList(u8), utf16le: []const u16) Utf16LeToUtf8AllocError!void {
    try result.ensureUnusedCapacity(utf16le.len);
    return utf16LeToUtf8ArrayListImpl(result, utf16le, .cannot_encode_surrogate_half);
}

pub const utf16leToUtf8Alloc = @compileError("deprecated; renamed to utf16LeToUtf8Alloc");

/// Caller must free returned memory.
pub fn utf16LeToUtf8Alloc(allocator: mem.Allocator, utf16le: []const u16) Utf16LeToUtf8AllocError![]u8 {
    // optimistically guess that it will all be ascii.
    var result = try std.ArrayList(u8).initCapacity(allocator, utf16le.len);
    errdefer result.deinit();

    try utf16LeToUtf8ArrayListImpl(&result, utf16le, .cannot_encode_surrogate_half);
    return result.toOwnedSlice();
}

pub const utf16leToUtf8AllocZ = @compileError("deprecated; renamed to utf16LeToUtf8AllocZ");

/// Caller must free returned memory.
pub fn utf16LeToUtf8AllocZ(allocator: mem.Allocator, utf16le: []const u16) Utf16LeToUtf8AllocError![:0]u8 {
    // optimistically guess that it will all be ascii (and allocate space for the null terminator)
    var result = try std.ArrayList(u8).initCapacity(allocator, utf16le.len + 1);
    errdefer result.deinit();

    try utf16LeToUtf8ArrayListImpl(&result, utf16le, .cannot_encode_surrogate_half);
    return result.toOwnedSliceSentinel(0);
}

pub const Utf16LeToUtf8Error = Utf16LeIterator.NextCodepointError;

/// Asserts that the output buffer is big enough.
/// Returns end byte index into utf8.
fn utf16LeToUtf8Impl(utf8: []u8, utf16le: []const u16, comptime surrogates: Surrogates) (switch (surrogates) {
    .cannot_encode_surrogate_half => Utf16LeToUtf8Error,
    .can_encode_surrogate_half => error{},
})!usize {
    var dest_index: usize = 0;

    var remaining = utf16le;
    vectorized: {
        const chunk_len = std.simd.suggestVectorLength(u16) orelse break :vectorized;
        const Chunk = @Vector(chunk_len, u16);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(mem.nativeToLittle(u16, 0x7F));
            if (@reduce(.Or, chunk | mask != mask)) {
                // found a non ASCII code unit
                break;
            }
            const ascii_chunk: @Vector(chunk_len, u8) = @truncate(mem.nativeToLittle(Chunk, chunk));
            utf8[dest_index..][0..chunk_len].* = ascii_chunk;
            dest_index += chunk_len;
            remaining = remaining[chunk_len..];
        }
    }

    switch (surrogates) {
        .cannot_encode_surrogate_half => {
            var it = Utf16LeIterator.init(remaining);
            while (try it.nextCodepoint()) |codepoint| {
                dest_index += utf8Encode(codepoint, utf8[dest_index..]) catch |err| switch (err) {
                    // The maximum possible codepoint encoded by UTF-16 is U+10FFFF,
                    // which is within the valid codepoint range.
                    error.CodepointTooLarge => unreachable,
                    // We know the codepoint was valid in UTF-16, meaning it is not
                    // an unpaired surrogate codepoint.
                    error.Utf8CannotEncodeSurrogateHalf => unreachable,
                };
            }
        },
        .can_encode_surrogate_half => {
            var it = Wtf16LeIterator.init(remaining);
            while (it.nextCodepoint()) |codepoint| {
                dest_index += wtf8Encode(codepoint, utf8[dest_index..]) catch |err| switch (err) {
                    // The maximum possible codepoint encoded by UTF-16 is U+10FFFF,
                    // which is within the valid codepoint range.
                    error.CodepointTooLarge => unreachable,
                };
            }
        },
    }
    return dest_index;
}

pub const utf16leToUtf8 = @compileError("deprecated; renamed to utf16LeToUtf8");

pub fn utf16LeToUtf8(utf8: []u8, utf16le: []const u16) Utf16LeToUtf8Error!usize {
    return utf16LeToUtf8Impl(utf8, utf16le, .cannot_encode_surrogate_half);
}

test utf16LeToUtf8 {
    var utf16le: [2]u16 = undefined;
    const utf16le_as_bytes = mem.sliceAsBytes(utf16le[0..]);

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 'A', .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 'a', .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "Aa"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0x80, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xffff, .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xc2\x80" ++ "\xef\xbf\xbf"));
    }

    {
        // the values just outside the surrogate half range
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xd7ff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xe000, .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xed\x9f\xbf" ++ "\xee\x80\x80"));
    }

    {
        // smallest surrogate pair
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xd800, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdc00, .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf0\x90\x80\x80"));
    }

    {
        // largest surrogate pair
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdbff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdfff, .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xbf\xbf"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdbff, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdc00, .little);
        const utf8 = try utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        defer testing.allocator.free(utf8);
        try testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xb0\x80"));
    }

    {
        mem.writeInt(u16, utf16le_as_bytes[0..2], 0xdcdc, .little);
        mem.writeInt(u16, utf16le_as_bytes[2..4], 0xdcdc, .little);
        const result = utf16LeToUtf8Alloc(testing.allocator, &utf16le);
        try testing.expectError(error.UnexpectedSecondSurrogateHalf, result);
    }
}

fn utf8ToUtf16LeArrayListImpl(result: *std.ArrayList(u16), utf8: []const u8, comptime surrogates: Surrogates) !void {
    assert(result.unusedCapacitySlice().len >= utf8.len);

    var remaining = utf8;
    vectorized: {
        const chunk_len = std.simd.suggestVectorLength(u16) orelse break :vectorized;
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII code unit
                break;
            }
            const utf16_chunk = mem.nativeToLittle(@Vector(chunk_len, u16), chunk);
            result.addManyAsArrayAssumeCapacity(chunk_len).* = utf16_chunk;
            remaining = remaining[chunk_len..];
        }
    }

    const view = switch (surrogates) {
        .cannot_encode_surrogate_half => try Utf8View.init(remaining),
        .can_encode_surrogate_half => try Wtf8View.init(remaining),
    };
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            try result.append(mem.nativeToLittle(u16, @intCast(codepoint)));
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            try result.appendSlice(&.{ mem.nativeToLittle(u16, high), mem.nativeToLittle(u16, low) });
        }
    }
}

pub fn utf8ToUtf16LeArrayList(result: *std.ArrayList(u16), utf8: []const u8) error{ InvalidUtf8, OutOfMemory }!void {
    try result.ensureUnusedCapacity(utf8.len);
    return utf8ToUtf16LeArrayListImpl(result, utf8, .cannot_encode_surrogate_half);
}

pub fn utf8ToUtf16LeAlloc(allocator: mem.Allocator, utf8: []const u8) error{ InvalidUtf8, OutOfMemory }![]u16 {
    // optimistically guess that it will not require surrogate pairs
    var result = try std.ArrayList(u16).initCapacity(allocator, utf8.len);
    errdefer result.deinit();

    try utf8ToUtf16LeArrayListImpl(&result, utf8, .cannot_encode_surrogate_half);
    return result.toOwnedSlice();
}

pub const utf8ToUtf16LeWithNull = @compileError("deprecated; renamed to utf8ToUtf16LeAllocZ");

pub fn utf8ToUtf16LeAllocZ(allocator: mem.Allocator, utf8: []const u8) error{ InvalidUtf8, OutOfMemory }![:0]u16 {
    // optimistically guess that it will not require surrogate pairs
    var result = try std.ArrayList(u16).initCapacity(allocator, utf8.len + 1);
    errdefer result.deinit();

    try utf8ToUtf16LeArrayListImpl(&result, utf8, .cannot_encode_surrogate_half);
    return result.toOwnedSliceSentinel(0);
}

/// Returns index of next character. If exact fit, returned index equals output slice length.
/// Assumes there is enough space for the output.
pub fn utf8ToUtf16Le(utf16le: []u16, utf8: []const u8) error{InvalidUtf8}!usize {
    return utf8ToUtf16LeImpl(utf16le, utf8, .cannot_encode_surrogate_half);
}

pub fn utf8ToUtf16LeImpl(utf16le: []u16, utf8: []const u8, comptime surrogates: Surrogates) !usize {
    var dest_index: usize = 0;

    var remaining = utf8;
    vectorized: {
        const chunk_len = std.simd.suggestVectorLength(u16) orelse break :vectorized;
        const Chunk = @Vector(chunk_len, u8);

        // Fast path. Check for and encode ASCII characters at the start of the input.
        while (remaining.len >= chunk_len) {
            const chunk: Chunk = remaining[0..chunk_len].*;
            const mask: Chunk = @splat(0x80);
            if (@reduce(.Or, chunk & mask == mask)) {
                // found a non ASCII code unit
                break;
            }
            const utf16_chunk = mem.nativeToLittle(@Vector(chunk_len, u16), chunk);
            utf16le[dest_index..][0..chunk_len].* = utf16_chunk;
            dest_index += chunk_len;
            remaining = remaining[chunk_len..];
        }
    }

    const view = switch (surrogates) {
        .cannot_encode_surrogate_half => try Utf8View.init(remaining),
        .can_encode_surrogate_half => try Wtf8View.init(remaining),
    };
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            utf16le[dest_index] = mem.nativeToLittle(u16, @intCast(codepoint));
            dest_index += 1;
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            utf16le[dest_index..][0..2].* = .{ mem.nativeToLittle(u16, high), mem.nativeToLittle(u16, low) };
            dest_index += 2;
        }
    }
    return dest_index;
}

test utf8ToUtf16Le {
    var utf16le: [128]u16 = undefined;
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "𐐷");
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16le[0..length]));
    }
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "\u{10FFFF}");
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16le[0..length]));
    }
    {
        const result = utf8ToUtf16Le(utf16le[0..], "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "This string has been designed to test the vectorized implementat" ++
            "ion by beginning with one hundred twenty-seven ASCII characters¡");
        try testing.expectEqualSlices(u8, &.{
            'T', 0, 'h', 0, 'i', 0, 's', 0, ' ', 0, 's', 0, 't', 0, 'r', 0, 'i', 0, 'n', 0, 'g', 0, ' ', 0, 'h', 0, 'a', 0, 's', 0, ' ',  0,
            'b', 0, 'e', 0, 'e', 0, 'n', 0, ' ', 0, 'd', 0, 'e', 0, 's', 0, 'i', 0, 'g', 0, 'n', 0, 'e', 0, 'd', 0, ' ', 0, 't', 0, 'o',  0,
            ' ', 0, 't', 0, 'e', 0, 's', 0, 't', 0, ' ', 0, 't', 0, 'h', 0, 'e', 0, ' ', 0, 'v', 0, 'e', 0, 'c', 0, 't', 0, 'o', 0, 'r',  0,
            'i', 0, 'z', 0, 'e', 0, 'd', 0, ' ', 0, 'i', 0, 'm', 0, 'p', 0, 'l', 0, 'e', 0, 'm', 0, 'e', 0, 'n', 0, 't', 0, 'a', 0, 't',  0,
            'i', 0, 'o', 0, 'n', 0, ' ', 0, 'b', 0, 'y', 0, ' ', 0, 'b', 0, 'e', 0, 'g', 0, 'i', 0, 'n', 0, 'n', 0, 'i', 0, 'n', 0, 'g',  0,
            ' ', 0, 'w', 0, 'i', 0, 't', 0, 'h', 0, ' ', 0, 'o', 0, 'n', 0, 'e', 0, ' ', 0, 'h', 0, 'u', 0, 'n', 0, 'd', 0, 'r', 0, 'e',  0,
            'd', 0, ' ', 0, 't', 0, 'w', 0, 'e', 0, 'n', 0, 't', 0, 'y', 0, '-', 0, 's', 0, 'e', 0, 'v', 0, 'e', 0, 'n', 0, ' ', 0, 'A',  0,
            'S', 0, 'C', 0, 'I', 0, 'I', 0, ' ', 0, 'c', 0, 'h', 0, 'a', 0, 'r', 0, 'a', 0, 'c', 0, 't', 0, 'e', 0, 'r', 0, 's', 0, '¡', 0,
        }, mem.sliceAsBytes(utf16le[0..length]));
    }
}

test utf8ToUtf16LeArrayList {
    {
        var list = std.ArrayList(u16).init(testing.allocator);
        defer list.deinit();
        try utf8ToUtf16LeArrayList(&list, "𐐷");
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(list.items));
    }
    {
        var list = std.ArrayList(u16).init(testing.allocator);
        defer list.deinit();
        try utf8ToUtf16LeArrayList(&list, "\u{10FFFF}");
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(list.items));
    }
    {
        var list = std.ArrayList(u16).init(testing.allocator);
        defer list.deinit();
        const result = utf8ToUtf16LeArrayList(&list, "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
}

test utf8ToUtf16LeAlloc {
    {
        const utf16 = try utf8ToUtf16LeAlloc(testing.allocator, "𐐷");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16[0..]));
    }
    {
        const utf16 = try utf8ToUtf16LeAlloc(testing.allocator, "\u{10FFFF}");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16[0..]));
    }
    {
        const result = utf8ToUtf16LeAlloc(testing.allocator, "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
}

test utf8ToUtf16LeAllocZ {
    {
        const utf16 = try utf8ToUtf16LeAllocZ(testing.allocator, "𐐷");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16));
        try testing.expect(utf16[2] == 0);
    }
    {
        const utf16 = try utf8ToUtf16LeAllocZ(testing.allocator, "\u{10FFFF}");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16));
        try testing.expect(utf16[2] == 0);
    }
    {
        const result = utf8ToUtf16LeAllocZ(testing.allocator, "\xf4\x90\x80\x80");
        try testing.expectError(error.InvalidUtf8, result);
    }
    {
        const utf16 = try utf8ToUtf16LeAllocZ(testing.allocator, "This string has been designed to test the vectorized implementat" ++
            "ion by beginning with one hundred twenty-seven ASCII characters¡");
        defer testing.allocator.free(utf16);
        try testing.expectEqualSlices(u8, &.{
            'T', 0, 'h', 0, 'i', 0, 's', 0, ' ', 0, 's', 0, 't', 0, 'r', 0, 'i', 0, 'n', 0, 'g', 0, ' ', 0, 'h', 0, 'a', 0, 's', 0, ' ',  0,
            'b', 0, 'e', 0, 'e', 0, 'n', 0, ' ', 0, 'd', 0, 'e', 0, 's', 0, 'i', 0, 'g', 0, 'n', 0, 'e', 0, 'd', 0, ' ', 0, 't', 0, 'o',  0,
            ' ', 0, 't', 0, 'e', 0, 's', 0, 't', 0, ' ', 0, 't', 0, 'h', 0, 'e', 0, ' ', 0, 'v', 0, 'e', 0, 'c', 0, 't', 0, 'o', 0, 'r',  0,
            'i', 0, 'z', 0, 'e', 0, 'd', 0, ' ', 0, 'i', 0, 'm', 0, 'p', 0, 'l', 0, 'e', 0, 'm', 0, 'e', 0, 'n', 0, 't', 0, 'a', 0, 't',  0,
            'i', 0, 'o', 0, 'n', 0, ' ', 0, 'b', 0, 'y', 0, ' ', 0, 'b', 0, 'e', 0, 'g', 0, 'i', 0, 'n', 0, 'n', 0, 'i', 0, 'n', 0, 'g',  0,
            ' ', 0, 'w', 0, 'i', 0, 't', 0, 'h', 0, ' ', 0, 'o', 0, 'n', 0, 'e', 0, ' ', 0, 'h', 0, 'u', 0, 'n', 0, 'd', 0, 'r', 0, 'e',  0,
            'd', 0, ' ', 0, 't', 0, 'w', 0, 'e', 0, 'n', 0, 't', 0, 'y', 0, '-', 0, 's', 0, 'e', 0, 'v', 0, 'e', 0, 'n', 0, ' ', 0, 'A',  0,
            'S', 0, 'C', 0, 'I', 0, 'I', 0, ' ', 0, 'c', 0, 'h', 0, 'a', 0, 'r', 0, 'a', 0, 'c', 0, 't', 0, 'e', 0, 'r', 0, 's', 0, '¡', 0,
        }, mem.sliceAsBytes(utf16));
    }
}

test "ArrayList functions on a re-used list" {
    // utf8ToUtf16LeArrayList
    {
        var list = std.ArrayList(u16).init(testing.allocator);
        defer list.deinit();

        const init_slice = utf8ToUtf16LeStringLiteral("abcdefg");
        try list.ensureTotalCapacityPrecise(init_slice.len);
        list.appendSliceAssumeCapacity(init_slice);

        try utf8ToUtf16LeArrayList(&list, "hijklmnopqrstuvwyxz");

        try testing.expectEqualSlices(u16, utf8ToUtf16LeStringLiteral("abcdefghijklmnopqrstuvwyxz"), list.items);
    }

    // utf16LeToUtf8ArrayList
    {
        var list = std.ArrayList(u8).init(testing.allocator);
        defer list.deinit();

        const init_slice = "abcdefg";
        try list.ensureTotalCapacityPrecise(init_slice.len);
        list.appendSliceAssumeCapacity(init_slice);

        try utf16LeToUtf8ArrayList(&list, utf8ToUtf16LeStringLiteral("hijklmnopqrstuvwyxz"));

        try testing.expectEqualStrings("abcdefghijklmnopqrstuvwyxz", list.items);
    }

    // wtf8ToWtf16LeArrayList
    {
        var list = std.ArrayList(u16).init(testing.allocator);
        defer list.deinit();

        const init_slice = utf8ToUtf16LeStringLiteral("abcdefg");
        try list.ensureTotalCapacityPrecise(init_slice.len);
        list.appendSliceAssumeCapacity(init_slice);

        try wtf8ToWtf16LeArrayList(&list, "hijklmnopqrstuvwyxz");

        try testing.expectEqualSlices(u16, utf8ToUtf16LeStringLiteral("abcdefghijklmnopqrstuvwyxz"), list.items);
    }

    // wtf16LeToWtf8ArrayList
    {
        var list = std.ArrayList(u8).init(testing.allocator);
        defer list.deinit();

        const init_slice = "abcdefg";
        try list.ensureTotalCapacityPrecise(init_slice.len);
        list.appendSliceAssumeCapacity(init_slice);

        try wtf16LeToWtf8ArrayList(&list, utf8ToUtf16LeStringLiteral("hijklmnopqrstuvwyxz"));

        try testing.expectEqualStrings("abcdefghijklmnopqrstuvwyxz", list.items);
    }
}

fn utf8ToUtf16LeStringLiteralImpl(comptime utf8: []const u8, comptime surrogates: Surrogates) *const [calcUtf16LeLenImpl(utf8, surrogates) catch |err| @compileError(err):0]u16 {
    return comptime blk: {
        const len: usize = calcUtf16LeLenImpl(utf8, surrogates) catch unreachable;
        var utf16le: [len:0]u16 = [_:0]u16{0} ** len;
        const utf16le_len = utf8ToUtf16LeImpl(&utf16le, utf8[0..], surrogates) catch |err| @compileError(err);
        assert(len == utf16le_len);
        const final = utf16le;
        break :blk &final;
    };
}

/// Converts a UTF-8 string literal into a UTF-16LE string literal.
pub fn utf8ToUtf16LeStringLiteral(comptime utf8: []const u8) *const [calcUtf16LeLen(utf8) catch |err| @compileError(err):0]u16 {
    return utf8ToUtf16LeStringLiteralImpl(utf8, .cannot_encode_surrogate_half);
}

/// Converts a WTF-8 string literal into a WTF-16LE string literal.
pub fn wtf8ToWtf16LeStringLiteral(comptime wtf8: []const u8) *const [calcWtf16LeLen(wtf8) catch |err| @compileError(err):0]u16 {
    return utf8ToUtf16LeStringLiteralImpl(wtf8, .can_encode_surrogate_half);
}

pub fn calcUtf16LeLenImpl(utf8: []const u8, comptime surrogates: Surrogates) !usize {
    const utf8DecodeImpl = switch (surrogates) {
        .cannot_encode_surrogate_half => utf8Decode,
        .can_encode_surrogate_half => wtf8Decode,
    };
    var src_i: usize = 0;
    var dest_len: usize = 0;
    while (src_i < utf8.len) {
        const n = try utf8ByteSequenceLength(utf8[src_i]);
        const next_src_i = src_i + n;
        const codepoint = try utf8DecodeImpl(utf8[src_i..next_src_i]);
        if (codepoint < 0x10000) {
            dest_len += 1;
        } else {
            dest_len += 2;
        }
        src_i = next_src_i;
    }
    return dest_len;
}

const CalcUtf16LeLenError = Utf8DecodeError || error{Utf8InvalidStartByte};

/// Returns length in UTF-16LE of UTF-8 slice as length of []u16.
/// Length in []u8 is 2*len16.
pub fn calcUtf16LeLen(utf8: []const u8) CalcUtf16LeLenError!usize {
    return calcUtf16LeLenImpl(utf8, .cannot_encode_surrogate_half);
}

const CalcWtf16LeLenError = Wtf8DecodeError || error{Utf8InvalidStartByte};

/// Returns length in WTF-16LE of WTF-8 slice as length of []u16.
/// Length in []u8 is 2*len16.
pub fn calcWtf16LeLen(wtf8: []const u8) CalcWtf16LeLenError!usize {
    return calcUtf16LeLenImpl(wtf8, .can_encode_surrogate_half);
}

fn testCalcUtf16LeLenImpl(calcUtf16LeLenImpl_: anytype) !void {
    try testing.expectEqual(@as(usize, 1), try calcUtf16LeLenImpl_("a"));
    try testing.expectEqual(@as(usize, 10), try calcUtf16LeLenImpl_("abcdefghij"));
    try testing.expectEqual(@as(usize, 10), try calcUtf16LeLenImpl_("äåéëþüúíóö"));
    try testing.expectEqual(@as(usize, 5), try calcUtf16LeLenImpl_("こんにちは"));
}

test calcUtf16LeLen {
    try testCalcUtf16LeLenImpl(calcUtf16LeLen);
    try comptime testCalcUtf16LeLenImpl(calcUtf16LeLen);
}

test calcWtf16LeLen {
    try testCalcUtf16LeLenImpl(calcWtf16LeLen);
    try comptime testCalcUtf16LeLenImpl(calcWtf16LeLen);
}

/// Print the given `utf16le` string, encoded as UTF-8 bytes.
/// Unpaired surrogates are replaced by the replacement character (U+FFFD).
fn formatUtf16Le(
    utf16le: []const u16,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;
    var buf: [300]u8 = undefined; // just an arbitrary size
    var it = Utf16LeIterator.init(utf16le);
    var u8len: usize = 0;
    while (it.nextCodepoint() catch replacement_character) |codepoint| {
        u8len += utf8Encode(codepoint, buf[u8len..]) catch
            utf8Encode(replacement_character, buf[u8len..]) catch unreachable;
        // make sure there's always enough room for another maximum length UTF-8 codepoint
        if (u8len + 4 > buf.len) {
            try writer.writeAll(buf[0..u8len]);
            u8len = 0;
        }
    }
    try writer.writeAll(buf[0..u8len]);
}

pub const fmtUtf16le = @compileError("deprecated; renamed to fmtUtf16Le");

/// Return a Formatter for a (potentially ill-formed) UTF-16 LE string,
/// which will be converted to UTF-8 during formatting.
/// Unpaired surrogates are replaced by the replacement character (U+FFFD).
pub fn fmtUtf16Le(utf16le: []const u16) std.fmt.Formatter(formatUtf16Le) {
    return .{ .data = utf16le };
}

test fmtUtf16Le {
    const expectFmt = testing.expectFmt;
    try expectFmt("", "{}", .{fmtUtf16Le(utf8ToUtf16LeStringLiteral(""))});
    try expectFmt("", "{}", .{fmtUtf16Le(wtf8ToWtf16LeStringLiteral(""))});
    try expectFmt("foo", "{}", .{fmtUtf16Le(utf8ToUtf16LeStringLiteral("foo"))});
    try expectFmt("foo", "{}", .{fmtUtf16Le(wtf8ToWtf16LeStringLiteral("foo"))});
    try expectFmt("𐐷", "{}", .{fmtUtf16Le(wtf8ToWtf16LeStringLiteral("𐐷"))});
    try expectFmt("퟿", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\xff\xd7", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\x00\xd8", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\xff\xdb", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\x00\xdc", native_endian)})});
    try expectFmt("�", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\xff\xdf", native_endian)})});
    try expectFmt("", "{}", .{fmtUtf16Le(&[_]u16{mem.readInt(u16, "\x00\xe0", native_endian)})});
}

fn testUtf8ToUtf16LeStringLiteral(utf8ToUtf16LeStringLiteral_: anytype) !void {
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x41),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("A");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0xD801),
            mem.nativeToLittle(u16, 0xDC37),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("𐐷");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[2] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x02FF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("\u{02FF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x7FF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("\u{7FF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0x801),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("\u{801}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{
            mem.nativeToLittle(u16, 0xDBFF),
            mem.nativeToLittle(u16, 0xDFFF),
        };
        const utf16 = utf8ToUtf16LeStringLiteral_("\u{10FFFF}");
        try testing.expectEqualSlices(u16, &bytes, utf16);
        try testing.expect(utf16[2] == 0);
    }
}

test utf8ToUtf16LeStringLiteral {
    try testUtf8ToUtf16LeStringLiteral(utf8ToUtf16LeStringLiteral);
}

test wtf8ToWtf16LeStringLiteral {
    try testUtf8ToUtf16LeStringLiteral(wtf8ToWtf16LeStringLiteral);
}

fn testUtf8CountCodepoints() !void {
    try testing.expectEqual(@as(usize, 10), try utf8CountCodepoints("abcdefghij"));
    try testing.expectEqual(@as(usize, 10), try utf8CountCodepoints("äåéëþüúíóö"));
    try testing.expectEqual(@as(usize, 5), try utf8CountCodepoints("こんにちは"));
    // testing.expectError(error.Utf8EncodesSurrogateHalf, utf8CountCodepoints("\xED\xA0\x80"));
}

test "utf8 count codepoints" {
    try testUtf8CountCodepoints();
    try comptime testUtf8CountCodepoints();
}

fn testUtf8ValidCodepoint() !void {
    try testing.expect(utf8ValidCodepoint('e'));
    try testing.expect(utf8ValidCodepoint('ë'));
    try testing.expect(utf8ValidCodepoint('は'));
    try testing.expect(utf8ValidCodepoint(0xe000));
    try testing.expect(utf8ValidCodepoint(0x10ffff));
    try testing.expect(!utf8ValidCodepoint(0xd800));
    try testing.expect(!utf8ValidCodepoint(0xdfff));
    try testing.expect(!utf8ValidCodepoint(0x110000));
}

test "utf8 valid codepoint" {
    try testUtf8ValidCodepoint();
    try comptime testUtf8ValidCodepoint();
}

/// Returns true if the codepoint is a surrogate (U+DC00 to U+DFFF)
pub fn isSurrogateCodepoint(c: u21) bool {
    return switch (c) {
        0xD800...0xDFFF => true,
        else => false,
    };
}

/// Encodes the given codepoint into a WTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in WTF-8.
/// Returns: the number of bytes written to out.
pub fn wtf8Encode(c: u21, out: []u8) error{CodepointTooLarge}!u3 {
    return utf8EncodeImpl(c, out, .can_encode_surrogate_half);
}

const Wtf8DecodeError = Utf8Decode2Error || Utf8Decode3AllowSurrogateHalfError || Utf8Decode4Error;

/// Deprecated. This function has an awkward API that is too easy to use incorrectly.
pub fn wtf8Decode(bytes: []const u8) Wtf8DecodeError!u21 {
    return switch (bytes.len) {
        1 => bytes[0],
        2 => utf8Decode2(bytes[0..2].*),
        3 => utf8Decode3AllowSurrogateHalf(bytes[0..3].*),
        4 => utf8Decode4(bytes[0..4].*),
        else => unreachable,
    };
}

/// Returns true if the input consists entirely of WTF-8 codepoints
/// (all the same restrictions as UTF-8, but allows surrogate codepoints
/// U+D800 to U+DFFF).
/// Does not check for well-formed WTF-8, meaning that this function
/// does not check that all surrogate halves are unpaired.
pub fn wtf8ValidateSlice(input: []const u8) bool {
    return utf8ValidateSliceImpl(input, .can_encode_surrogate_half);
}

test "validate WTF-8 slice" {
    try testValidateWtf8Slice();
    try comptime testValidateWtf8Slice();

    // We skip a variable (based on recommended vector size) chunks of
    // ASCII characters. Let's make sure we're chunking correctly.
    const str = [_]u8{'a'} ** 550 ++ "\xc0";
    for (0..str.len - 3) |i| {
        try testing.expect(!wtf8ValidateSlice(str[i..]));
    }
}
fn testValidateWtf8Slice() !void {
    // These are valid/invalid under both UTF-8 and WTF-8 rules.
    try testing.expect(wtf8ValidateSlice("abc"));
    try testing.expect(wtf8ValidateSlice("abc\xdf\xbf"));
    try testing.expect(wtf8ValidateSlice(""));
    try testing.expect(wtf8ValidateSlice("a"));
    try testing.expect(wtf8ValidateSlice("abc"));
    try testing.expect(wtf8ValidateSlice("Ж"));
    try testing.expect(wtf8ValidateSlice("ЖЖ"));
    try testing.expect(wtf8ValidateSlice("брэд-ЛГТМ"));
    try testing.expect(wtf8ValidateSlice("☺☻☹"));
    try testing.expect(wtf8ValidateSlice("a\u{fffdb}"));
    try testing.expect(wtf8ValidateSlice("\xf4\x8f\xbf\xbf"));
    try testing.expect(wtf8ValidateSlice("abc\xdf\xbf"));

    try testing.expect(!wtf8ValidateSlice("abc\xc0"));
    try testing.expect(!wtf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!wtf8ValidateSlice("aa\xe2"));
    try testing.expect(!wtf8ValidateSlice("\x42\xfa"));
    try testing.expect(!wtf8ValidateSlice("\x42\xfa\x43"));
    try testing.expect(!wtf8ValidateSlice("abc\xc0"));
    try testing.expect(!wtf8ValidateSlice("abc\xc0abc"));
    try testing.expect(!wtf8ValidateSlice("\xf4\x90\x80\x80"));
    try testing.expect(!wtf8ValidateSlice("\xf7\xbf\xbf\xbf"));
    try testing.expect(!wtf8ValidateSlice("\xfb\xbf\xbf\xbf\xbf"));
    try testing.expect(!wtf8ValidateSlice("\xc0\x80"));

    // But surrogate codepoints are only valid in WTF-8.
    try testing.expect(wtf8ValidateSlice("\xed\xa0\x80"));
    try testing.expect(wtf8ValidateSlice("\xed\xbf\xbf"));
}

/// Wtf8View iterates the code points of a WTF-8 encoded string,
/// including surrogate halves.
///
/// ```
/// var wtf8 = (try std.unicode.Wtf8View.init("hi there")).iterator();
/// while (wtf8.nextCodepointSlice()) |codepoint| {
///   // note: codepoint could be a surrogate half which is invalid
///   // UTF-8, avoid printing or otherwise sending/emitting this directly
/// }
/// ```
pub const Wtf8View = struct {
    bytes: []const u8,

    pub fn init(s: []const u8) error{InvalidWtf8}!Wtf8View {
        if (!wtf8ValidateSlice(s)) {
            return error.InvalidWtf8;
        }

        return initUnchecked(s);
    }

    pub fn initUnchecked(s: []const u8) Wtf8View {
        return Wtf8View{ .bytes = s };
    }

    pub inline fn initComptime(comptime s: []const u8) Wtf8View {
        return comptime if (init(s)) |r| r else |err| switch (err) {
            error.InvalidWtf8 => {
                @compileError("invalid wtf8");
            },
        };
    }

    pub fn iterator(s: Wtf8View) Wtf8Iterator {
        return Wtf8Iterator{
            .bytes = s.bytes,
            .i = 0,
        };
    }
};

/// Asserts that `bytes` is valid WTF-8
pub const Wtf8Iterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn nextCodepointSlice(it: *Wtf8Iterator) ?[]const u8 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        const cp_len = utf8ByteSequenceLength(it.bytes[it.i]) catch unreachable;
        it.i += cp_len;
        return it.bytes[it.i - cp_len .. it.i];
    }

    pub fn nextCodepoint(it: *Wtf8Iterator) ?u21 {
        const slice = it.nextCodepointSlice() orelse return null;
        return wtf8Decode(slice) catch unreachable;
    }

    /// Look ahead at the next n codepoints without advancing the iterator.
    /// If fewer than n codepoints are available, then return the remainder of the string.
    pub fn peek(it: *Wtf8Iterator, n: usize) []const u8 {
        const original_i = it.i;
        defer it.i = original_i;

        var end_ix = original_i;
        var found: usize = 0;
        while (found < n) : (found += 1) {
            const next_codepoint = it.nextCodepointSlice() orelse return it.bytes[original_i..];
            end_ix += next_codepoint.len;
        }

        return it.bytes[original_i..end_ix];
    }
};

pub fn wtf16LeToWtf8ArrayList(result: *std.ArrayList(u8), utf16le: []const u16) mem.Allocator.Error!void {
    try result.ensureUnusedCapacity(utf16le.len);
    return utf16LeToUtf8ArrayListImpl(result, utf16le, .can_encode_surrogate_half);
}

/// Caller must free returned memory.
pub fn wtf16LeToWtf8Alloc(allocator: mem.Allocator, wtf16le: []const u16) mem.Allocator.Error![]u8 {
    // optimistically guess that it will all be ascii.
    var result = try std.ArrayList(u8).initCapacity(allocator, wtf16le.len);
    errdefer result.deinit();

    try utf16LeToUtf8ArrayListImpl(&result, wtf16le, .can_encode_surrogate_half);
    return result.toOwnedSlice();
}

/// Caller must free returned memory.
pub fn wtf16LeToWtf8AllocZ(allocator: mem.Allocator, wtf16le: []const u16) mem.Allocator.Error![:0]u8 {
    // optimistically guess that it will all be ascii (and allocate space for the null terminator)
    var result = try std.ArrayList(u8).initCapacity(allocator, wtf16le.len + 1);
    errdefer result.deinit();

    try utf16LeToUtf8ArrayListImpl(&result, wtf16le, .can_encode_surrogate_half);
    return result.toOwnedSliceSentinel(0);
}

pub fn wtf16LeToWtf8(wtf8: []u8, wtf16le: []const u16) usize {
    return utf16LeToUtf8Impl(wtf8, wtf16le, .can_encode_surrogate_half) catch |err| switch (err) {};
}

pub fn wtf8ToWtf16LeArrayList(result: *std.ArrayList(u16), wtf8: []const u8) error{ InvalidWtf8, OutOfMemory }!void {
    try result.ensureUnusedCapacity(wtf8.len);
    return utf8ToUtf16LeArrayListImpl(result, wtf8, .can_encode_surrogate_half);
}

pub fn wtf8ToWtf16LeAlloc(allocator: mem.Allocator, wtf8: []const u8) error{ InvalidWtf8, OutOfMemory }![]u16 {
    // optimistically guess that it will not require surrogate pairs
    var result = try std.ArrayList(u16).initCapacity(allocator, wtf8.len);
    errdefer result.deinit();

    try utf8ToUtf16LeArrayListImpl(&result, wtf8, .can_encode_surrogate_half);
    return result.toOwnedSlice();
}

pub fn wtf8ToWtf16LeAllocZ(allocator: mem.Allocator, wtf8: []const u8) error{ InvalidWtf8, OutOfMemory }![:0]u16 {
    // optimistically guess that it will not require surrogate pairs
    var result = try std.ArrayList(u16).initCapacity(allocator, wtf8.len + 1);
    errdefer result.deinit();

    try utf8ToUtf16LeArrayListImpl(&result, wtf8, .can_encode_surrogate_half);
    return result.toOwnedSliceSentinel(0);
}

/// Returns index of next character. If exact fit, returned index equals output slice length.
/// Assumes there is enough space for the output.
pub fn wtf8ToWtf16Le(wtf16le: []u16, wtf8: []const u8) error{InvalidWtf8}!usize {
    return utf8ToUtf16LeImpl(wtf16le, wtf8, .can_encode_surrogate_half);
}

fn checkUtf8ToUtf16LeOverflowImpl(utf8: []const u8, utf16le: []const u16, comptime surrogates: Surrogates) !bool {
    // Each u8 in UTF-8/WTF-8 correlates to at most one u16 in UTF-16LE/WTF-16LE.
    if (utf16le.len >= utf8.len) return false;
    const utf16_len = calcUtf16LeLenImpl(utf8, surrogates) catch {
        return switch (surrogates) {
            .cannot_encode_surrogate_half => error.InvalidUtf8,
            .can_encode_surrogate_half => error.InvalidWtf8,
        };
    };
    return utf16_len > utf16le.len;
}

/// Checks if calling `utf8ToUtf16Le` would overflow. Might fail if utf8 is not
/// valid UTF-8.
pub fn checkUtf8ToUtf16LeOverflow(utf8: []const u8, utf16le: []const u16) error{InvalidUtf8}!bool {
    return checkUtf8ToUtf16LeOverflowImpl(utf8, utf16le, .cannot_encode_surrogate_half);
}

/// Checks if calling `utf8ToUtf16Le` would overflow. Might fail if wtf8 is not
/// valid WTF-8.
pub fn checkWtf8ToWtf16LeOverflow(wtf8: []const u8, wtf16le: []const u16) error{InvalidWtf8}!bool {
    return checkUtf8ToUtf16LeOverflowImpl(wtf8, wtf16le, .can_encode_surrogate_half);
}

/// Surrogate codepoints (U+D800 to U+DFFF) are replaced by the Unicode replacement
/// character (U+FFFD).
/// All surrogate codepoints and the replacement character are encoded as three
/// bytes, meaning the input and output slices will always be the same length.
/// In-place conversion is supported when `utf8` and `wtf8` refer to the same slice.
/// Note: If `wtf8` is entirely composed of well-formed UTF-8, then no conversion is necessary.
///       `utf8ValidateSlice` can be used to check if lossy conversion is worthwhile.
/// If `wtf8` is not valid WTF-8, then `error.InvalidWtf8` is returned.
pub fn wtf8ToUtf8Lossy(utf8: []u8, wtf8: []const u8) error{InvalidWtf8}!void {
    assert(utf8.len >= wtf8.len);

    const in_place = utf8.ptr == wtf8.ptr;
    const replacement_char_bytes = comptime blk: {
        var buf: [3]u8 = undefined;
        assert((utf8Encode(replacement_character, &buf) catch unreachable) == 3);
        break :blk buf;
    };

    var dest_i: usize = 0;
    const view = try Wtf8View.init(wtf8);
    var it = view.iterator();
    while (it.nextCodepointSlice()) |codepoint_slice| {
        // All surrogate codepoints are encoded as 3 bytes
        if (codepoint_slice.len == 3) {
            const codepoint = wtf8Decode(codepoint_slice) catch unreachable;
            if (isSurrogateCodepoint(codepoint)) {
                @memcpy(utf8[dest_i..][0..replacement_char_bytes.len], &replacement_char_bytes);
                dest_i += replacement_char_bytes.len;
                continue;
            }
        }
        if (!in_place) {
            @memcpy(utf8[dest_i..][0..codepoint_slice.len], codepoint_slice);
        }
        dest_i += codepoint_slice.len;
    }
}

pub fn wtf8ToUtf8LossyAlloc(allocator: mem.Allocator, wtf8: []const u8) error{ InvalidWtf8, OutOfMemory }![]u8 {
    const utf8 = try allocator.alloc(u8, wtf8.len);
    errdefer allocator.free(utf8);

    try wtf8ToUtf8Lossy(utf8, wtf8);

    return utf8;
}

pub fn wtf8ToUtf8LossyAllocZ(allocator: mem.Allocator, wtf8: []const u8) error{ InvalidWtf8, OutOfMemory }![:0]u8 {
    const utf8 = try allocator.allocSentinel(u8, wtf8.len, 0);
    errdefer allocator.free(utf8);

    try wtf8ToUtf8Lossy(utf8, wtf8);

    return utf8;
}

test wtf8ToUtf8Lossy {
    var buf: [32]u8 = undefined;

    const invalid_utf8 = "\xff";
    try testing.expectError(error.InvalidWtf8, wtf8ToUtf8Lossy(&buf, invalid_utf8));

    const ascii = "abcd";
    try wtf8ToUtf8Lossy(&buf, ascii);
    try testing.expectEqualStrings("abcd", buf[0..ascii.len]);

    const high_surrogate_half = "ab\xed\xa0\xbdcd";
    try wtf8ToUtf8Lossy(&buf, high_surrogate_half);
    try testing.expectEqualStrings("ab\u{FFFD}cd", buf[0..high_surrogate_half.len]);

    const low_surrogate_half = "ab\xed\xb2\xa9cd";
    try wtf8ToUtf8Lossy(&buf, low_surrogate_half);
    try testing.expectEqualStrings("ab\u{FFFD}cd", buf[0..low_surrogate_half.len]);

    // If the WTF-8 is not well-formed, each surrogate half is converted into a separate
    // replacement character instead of being interpreted as a surrogate pair.
    const encoded_surrogate_pair = "ab\xed\xa0\xbd\xed\xb2\xa9cd";
    try wtf8ToUtf8Lossy(&buf, encoded_surrogate_pair);
    try testing.expectEqualStrings("ab\u{FFFD}\u{FFFD}cd", buf[0..encoded_surrogate_pair.len]);

    // in place
    @memcpy(buf[0..low_surrogate_half.len], low_surrogate_half);
    const slice = buf[0..low_surrogate_half.len];
    try wtf8ToUtf8Lossy(slice, slice);
    try testing.expectEqualStrings("ab\u{FFFD}cd", slice);
}

test wtf8ToUtf8LossyAlloc {
    const invalid_utf8 = "\xff";
    try testing.expectError(error.InvalidWtf8, wtf8ToUtf8LossyAlloc(testing.allocator, invalid_utf8));

    {
        const ascii = "abcd";
        const utf8 = try wtf8ToUtf8LossyAlloc(testing.allocator, ascii);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("abcd", utf8);
    }

    {
        const surrogate_half = "ab\xed\xa0\xbdcd";
        const utf8 = try wtf8ToUtf8LossyAlloc(testing.allocator, surrogate_half);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("ab\u{FFFD}cd", utf8);
    }

    {
        // If the WTF-8 is not well-formed, each surrogate half is converted into a separate
        // replacement character instead of being interpreted as a surrogate pair.
        const encoded_surrogate_pair = "ab\xed\xa0\xbd\xed\xb2\xa9cd";
        const utf8 = try wtf8ToUtf8LossyAlloc(testing.allocator, encoded_surrogate_pair);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("ab\u{FFFD}\u{FFFD}cd", utf8);
    }
}

test wtf8ToUtf8LossyAllocZ {
    const invalid_utf8 = "\xff";
    try testing.expectError(error.InvalidWtf8, wtf8ToUtf8LossyAllocZ(testing.allocator, invalid_utf8));

    {
        const ascii = "abcd";
        const utf8 = try wtf8ToUtf8LossyAllocZ(testing.allocator, ascii);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("abcd", utf8);
    }

    {
        const surrogate_half = "ab\xed\xa0\xbdcd";
        const utf8 = try wtf8ToUtf8LossyAllocZ(testing.allocator, surrogate_half);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("ab\u{FFFD}cd", utf8);
    }

    {
        // If the WTF-8 is not well-formed, each surrogate half is converted into a separate
        // replacement character instead of being interpreted as a surrogate pair.
        const encoded_surrogate_pair = "ab\xed\xa0\xbd\xed\xb2\xa9cd";
        const utf8 = try wtf8ToUtf8LossyAllocZ(testing.allocator, encoded_surrogate_pair);
        defer testing.allocator.free(utf8);
        try testing.expectEqualStrings("ab\u{FFFD}\u{FFFD}cd", utf8);
    }
}

pub const Wtf16LeIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(s: []const u16) Wtf16LeIterator {
        return Wtf16LeIterator{
            .bytes = mem.sliceAsBytes(s),
            .i = 0,
        };
    }

    /// If the next codepoint is encoded by a surrogate pair, returns the
    /// codepoint that the surrogate pair represents.
    /// If the next codepoint is an unpaired surrogate, returns the codepoint
    /// of the unpaired surrogate.
    pub fn nextCodepoint(it: *Wtf16LeIterator) ?u21 {
        assert(it.i <= it.bytes.len);
        if (it.i == it.bytes.len) return null;
        var code_units: [2]u16 = undefined;
        code_units[0] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
        it.i += 2;
        surrogate_pair: {
            if (utf16IsHighSurrogate(code_units[0])) {
                if (it.i >= it.bytes.len) break :surrogate_pair;
                code_units[1] = mem.readInt(u16, it.bytes[it.i..][0..2], .little);
                const codepoint = utf16DecodeSurrogatePair(&code_units) catch break :surrogate_pair;
                it.i += 2;
                return codepoint;
            }
        }
        return code_units[0];
    }
};

test "non-well-formed WTF-8 does not roundtrip" {
    // This encodes the surrogate pair U+D83D U+DCA9.
    // The well-formed version of this would be U+1F4A9 which is \xF0\x9F\x92\xA9.
    const non_well_formed_wtf8 = "\xed\xa0\xbd\xed\xb2\xa9";

    var wtf16_buf: [2]u16 = undefined;
    const wtf16_len = try wtf8ToWtf16Le(&wtf16_buf, non_well_formed_wtf8);
    const wtf16 = wtf16_buf[0..wtf16_len];

    try testing.expectEqualSlices(u16, &[_]u16{
        mem.nativeToLittle(u16, 0xD83D), // high surrogate
        mem.nativeToLittle(u16, 0xDCA9), // low surrogate
    }, wtf16);

    var wtf8_buf: [4]u8 = undefined;
    const wtf8_len = wtf16LeToWtf8(&wtf8_buf, wtf16);
    const wtf8 = wtf8_buf[0..wtf8_len];

    // Converting to WTF-16 and back results in well-formed WTF-8,
    // but it does not match the input WTF-8
    try testing.expectEqualSlices(u8, "\xf0\x9f\x92\xa9", wtf8);
}

fn testRoundtripWtf8(wtf8: []const u8) !void {
    // Buffer
    {
        var wtf16_buf: [32]u16 = undefined;
        const wtf16_len = try wtf8ToWtf16Le(&wtf16_buf, wtf8);
        try testing.expectEqual(wtf16_len, calcWtf16LeLen(wtf8));
        try testing.expectEqual(false, checkWtf8ToWtf16LeOverflow(wtf8, &wtf16_buf));
        const wtf16 = wtf16_buf[0..wtf16_len];

        var roundtripped_buf: [32]u8 = undefined;
        const roundtripped_len = wtf16LeToWtf8(&roundtripped_buf, wtf16);
        const roundtripped = roundtripped_buf[0..roundtripped_len];

        try testing.expectEqualSlices(u8, wtf8, roundtripped);
    }
    // Alloc
    {
        const wtf16 = try wtf8ToWtf16LeAlloc(testing.allocator, wtf8);
        defer testing.allocator.free(wtf16);

        const roundtripped = try wtf16LeToWtf8Alloc(testing.allocator, wtf16);
        defer testing.allocator.free(roundtripped);

        try testing.expectEqualSlices(u8, wtf8, roundtripped);
    }
    // AllocZ
    {
        const wtf16 = try wtf8ToWtf16LeAllocZ(testing.allocator, wtf8);
        defer testing.allocator.free(wtf16);

        const roundtripped = try wtf16LeToWtf8AllocZ(testing.allocator, wtf16);
        defer testing.allocator.free(roundtripped);

        try testing.expectEqualSlices(u8, wtf8, roundtripped);
    }
}

test "well-formed WTF-8 roundtrips" {
    try testRoundtripWtf8("\xed\x9f\xbf"); // not a surrogate half
    try testRoundtripWtf8("\xed\xa0\xbd"); // high surrogate
    try testRoundtripWtf8("\xed\xb2\xa9"); // low surrogate
    try testRoundtripWtf8("\xed\xa0\xbd \xed\xb2\xa9"); // <high surrogate><space><low surrogate>
    try testRoundtripWtf8("\xed\xa0\x80\xed\xaf\xbf"); // <high surrogate><high surrogate>
    try testRoundtripWtf8("\xed\xa0\x80\xee\x80\x80"); // <high surrogate><not surrogate>
    try testRoundtripWtf8("\xed\x9f\xbf\xed\xb0\x80"); // <not surrogate><low surrogate>
    try testRoundtripWtf8("a\xed\xb0\x80"); // <not surrogate><low surrogate>
    try testRoundtripWtf8("\xf0\x9f\x92\xa9"); // U+1F4A9, encoded as a surrogate pair in WTF-16
}

fn testRoundtripWtf16(wtf16le: []const u16) !void {
    // Buffer
    {
        var wtf8_buf: [32]u8 = undefined;
        const wtf8_len = wtf16LeToWtf8(&wtf8_buf, wtf16le);
        const wtf8 = wtf8_buf[0..wtf8_len];

        var roundtripped_buf: [32]u16 = undefined;
        const roundtripped_len = try wtf8ToWtf16Le(&roundtripped_buf, wtf8);
        const roundtripped = roundtripped_buf[0..roundtripped_len];

        try testing.expectEqualSlices(u16, wtf16le, roundtripped);
    }
    // Alloc
    {
        const wtf8 = try wtf16LeToWtf8Alloc(testing.allocator, wtf16le);
        defer testing.allocator.free(wtf8);

        const roundtripped = try wtf8ToWtf16LeAlloc(testing.allocator, wtf8);
        defer testing.allocator.free(roundtripped);

        try testing.expectEqualSlices(u16, wtf16le, roundtripped);
    }
    // AllocZ
    {
        const wtf8 = try wtf16LeToWtf8AllocZ(testing.allocator, wtf16le);
        defer testing.allocator.free(wtf8);

        const roundtripped = try wtf8ToWtf16LeAllocZ(testing.allocator, wtf8);
        defer testing.allocator.free(roundtripped);

        try testing.expectEqualSlices(u16, wtf16le, roundtripped);
    }
}

test "well-formed WTF-16 roundtrips" {
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xD83D), // high surrogate
        mem.nativeToLittle(u16, 0xDCA9), // low surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xD83D), // high surrogate
        mem.nativeToLittle(u16, ' '), // not surrogate
        mem.nativeToLittle(u16, 0xDCA9), // low surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xD800), // high surrogate
        mem.nativeToLittle(u16, 0xDBFF), // high surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xD800), // high surrogate
        mem.nativeToLittle(u16, 0xE000), // not surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xD7FF), // not surrogate
        mem.nativeToLittle(u16, 0xDC00), // low surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0x61), // not surrogate
        mem.nativeToLittle(u16, 0xDC00), // low surrogate
    });
    try testRoundtripWtf16(&[_]u16{
        mem.nativeToLittle(u16, 0xDC00), // low surrogate
    });
}

/// Returns the length, in bytes, that would be necessary to encode the
/// given WTF-16 LE slice as WTF-8.
pub fn calcWtf8Len(wtf16le: []const u16) usize {
    var it = Wtf16LeIterator.init(wtf16le);
    var num_wtf8_bytes: usize = 0;
    while (it.nextCodepoint()) |codepoint| {
        // Note: If utf8CodepointSequenceLength is ever changed to error on surrogate
        // codepoints, then it would no longer be eligible to be used in this context.
        num_wtf8_bytes += utf8CodepointSequenceLength(codepoint) catch |err| switch (err) {
            error.CodepointTooLarge => unreachable,
        };
    }
    return num_wtf8_bytes;
}

fn testCalcWtf8Len() !void {
    const L = utf8ToUtf16LeStringLiteral;
    try testing.expectEqual(@as(usize, 1), calcWtf8Len(L("a")));
    try testing.expectEqual(@as(usize, 10), calcWtf8Len(L("abcdefghij")));
    // unpaired surrogate
    try testing.expectEqual(@as(usize, 3), calcWtf8Len(&[_]u16{
        mem.nativeToLittle(u16, 0xD800),
    }));
    try testing.expectEqual(@as(usize, 15), calcWtf8Len(L("こんにちは")));
    // First codepoints that are encoded as 1, 2, 3, and 4 bytes
    try testing.expectEqual(@as(usize, 1 + 2 + 3 + 4), calcWtf8Len(L("\u{0}\u{80}\u{800}\u{10000}")));
}

test "calculate wtf8 string length of given wtf16 string" {
    try testCalcWtf8Len();
    try comptime testCalcWtf8Len();
}
