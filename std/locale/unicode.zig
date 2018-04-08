const std = @import("../index.zig");
const debug = std.debug;
const mem = std.mem;
const assert = debug.assert;

/// Given the first byte of a UTF-8 codepoint,
/// returns a number 1-4 indicating the total length of the codepoint in bytes.
/// If this byte does not match the form of a UTF-8 start byte, returns Utf8InvalidStartByte.
pub fn utf8ByteSequenceLength(first_byte: u8) !u3 {
    if (first_byte < 0b10000000) return u3(1);
    if (first_byte & 0b11100000 == 0b11000000) return u3(2);
    if (first_byte & 0b11110000 == 0b11100000) return u3(3);
    if (first_byte & 0b11111000 == 0b11110000) return u3(4);
    return error.Utf8InvalidStartByte;
}

pub fn utf8CodepointSequenceLength(c: u32) !u4 {
    if (c < 0x80) return 1;
    if (c < 0x800) return 2;
    if (c -% 0xd800 < 0x800) return error.InvalidCodepoint;
    if (c < 0x10000) return 3;
    if (c < 0x110000) return 4;
    return error.Utf8CodepointTooLarge;
}

/// Encodes a code point back into utf8
/// c: the code point
/// out: the out buffer to write to
/// Notes: out has to have a len big enough for the code point
///        however this limit is dependent on the code point
///        but giving it a minimum of 4 will ensure it will work
///        for all code points :).
/// Errors: Will return an error if the code point is invalid.
pub fn utf8Encode(c: u32, out: []u8) !usize {
    if (utf8CodepointSequenceLength(c)) |length| {
        debug.assert(out.len >= length);
        switch (length) {
            1 => out[0] = u8(c), // Can just add a '0' and code point, thus output 'c'
            2 => {
                // 64 to convert the characters into their segments
                out[0] = u8(0b11000000 + c / 64);
                out[1] = u8(0b10000000 + c % 64);
            },
            3 => {
                // Again using 64 as a conversion into their segments
                // But using C / 4096 (64 * 64) as the first, (C/64) % 64 as the second, and just C % 64 as the last
                out[0] = u8(0b11100000 + c / 4096);
                out[1] = u8(0b10000000 + (c / 64) % 64);
                out[2] = u8(0b10000000 + c % 64);
            },
            4 => {
                // Same as previously but now its C / 64^3 (262144), (C / 4096) % 64, (C / 64) % 64 and C % 64
                out[0] = u8(0b11110000 + c / 262144);
                out[1] = u8(0b10000000 + (c / 4096) % 64);
                out[2] = u8(0b10000000 + (c / 64) % 64);
                out[3] = u8(0b10000000 + c % 64);
            },
            else => unreachable,
        }
    } else |err| {
        return err;
    }
}

/// Decodes the UTF-8 codepoint encoded in the given slice of bytes.
/// bytes.len must be equal to utf8ByteSequenceLength(bytes[0]) catch unreachable.
/// If you already know the length at comptime, you can call one of
/// utf8Decode2,utf8Decode3,utf8Decode4 directly instead of this function.
pub fn utf8Decode(bytes: []const u8) !u32 {
    return switch (bytes.len) {
        1 => u32(bytes[0]),
        2 => utf8Decode2(bytes),
        3 => utf8Decode3(bytes),
        4 => utf8Decode4(bytes),
        else => unreachable,
    };
}

pub fn utf8Decode2(bytes: []const u8) !u32 {
    debug.assert(bytes.len == 2);
    debug.assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u32 = bytes[0] & 0b00011111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (value < 0x80) return error.Utf8OverlongEncoding;

    return value;
}

pub fn utf8Decode3(bytes: []const u8) !u32 {
    debug.assert(bytes.len == 3);
    debug.assert(bytes[0] & 0b11110000 == 0b11100000);
    var value: u32 = bytes[0] & 0b00001111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (bytes[2] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (value < 0x800) return error.Utf8OverlongEncoding;
    if (0xd800 <= value and value <= 0xdfff) return error.Utf8EncodesSurrogateHalf;

    return value;
}

pub fn utf8Decode4(bytes: []const u8) !u32 {
    debug.assert(bytes.len == 4);
    debug.assert(bytes[0] & 0b11111000 == 0b11110000);
    var value: u32 = bytes[0] & 0b00000111;

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

pub fn utf8ValidateSlice(s: []const u8) bool {
    var i: usize = 0;
    while (i < s.len) {
        if (utf8ByteSequenceLength(s[i])) |cp_len| {
            if (i + cp_len > s.len) {
                return false;
            }

            if (utf8Decode(s[i..i+cp_len])) |_| {} else |_| { return false; }
            i += cp_len;
        } else |err| {
            return false;
        }
    }
    return true;
}

/// Utf8View iterates the code points of a utf-8 encoded string.
///
/// ```
/// var utf8 = (try std.unicode.Utf8View.init("hi there")).iterator();
/// while (utf8.nextCodepointSlice()) |codepoint| {
///   std.debug.warn("got codepoint {}\n", codepoint);
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

    pub fn eql(self: &const Utf8View, other: &const Utf8View) bool {
        return mem.eql(u8, self.bytes, other.bytes);
    }

    pub fn sliceBytes(self: &const Utf8View, start: usize, end: usize) []const u8 {
        return self.bytes[start..end];
    }

    pub fn sliceBytesToEndFrom(self: &const Utf8View, start: usize) []const u8 {
        return self.bytes[start..];
    }

    fn convertCodepointIndexToRaw(self: &const Utf8View, initialPoint: usize, codepointIndex: usize) !usize {
        var i: usize = initialPoint;
        var rawIndex: usize = i;

        while (i != codepointIndex) {
            if (rawIndex >= self.bytes.len) return error.IndexOutOfBounds;
            rawIndex += utf8ByteSequenceLength(self.bytes[rawIndex]);
            i += 1;
        }
        return rawIndex;
    }

    // Slices using two code point indexes
    // Will return an error if out of bounds.
    pub fn sliceCodepoint(self: &const Utf8View, start: usize, end: usize) ![]const u8 {
        // Grab first code point length and keep going till i == start
        const rawStart: usize = try self.convertCodepointIndexToRaw(start, true);
        const rawEnd: usize = try self.convertCodepointIndexToRaw(end, false);

        return self.sliceBytes(rawStart, rawEnd);
    }

    pub fn sliceCodepointToEndFrom(self: &const Utf8View, start: usize) ![]const u8 {
        return self.sliceBytesToEndFrom(try self.convertCodepointIndexToRaw(start, true));
    }

    pub fn byteAt(self: &const Utf8View, index: usize) u8 {
        return self.bytes[index];
    }

    pub fn byteFromEndAt(self: &const Utf8View, index: usize) u8 {
        return self.bytes[self.bytes.len - 1 - index];
    }

    /// Returns the code point at the position asked for
    /// Note: the index refers to code point indexes not raw indexes.
    ///       also that this is meant for when code point is in lower half
    ///       use codePointFromEndAt for when you know it is in upper half.
    pub fn codePointAt(self: &const Utf8View, index: usize) !u32 {
        const rawIndex: usize = try self.convertCodepointIndexToRaw(index, true);
        const length: usize = utf8ByteSequenceLength(self.bytes[rawIndex]);

        switch (length) {
            1 => return u32(self.bytes[rawIndex]),
            2 => return try utf8Decode2(self.bytes[rawIndex..rawIndex+2]),
            3 => return try utf8Decode3(self.bytes[rawIndex..rawIndex+3]),
            4 => return try utf8Decode4(self.bytes[rawIndex..rawIndex+4]),
            else => unreachable,
        }
    }

    /// Returns the code point at the position asked for FROM the end
    /// i.e. codePointFromEndAt(2) returns two code points from end code point
    ///      codePointFromEndAt(0) returns the last code point
    /// Note: the index refers to code point indexes not raw indexes.
    ///       also that this is meant for when code point is in lower half
    ///       use codePointFromEndAt for when you know it is in upper half.
    pub fn codePointFromEndAt(self: &const Utf8View, index: usize) !u32 {
        // Going back to front is a little more convuluted
        // If we do (c & 0xC0) == 0x80 then we know we can skip it due to nature of Utf8
        // Therefore we can iterate backwards, once we reach a point where it is no longer true
        // We know how many we have gone backwards and therefore can just raw ptr respectively
        // @Refactoring: We can have a length field that resets on i += 1, and just increment it
        //               as you decrement raw index :).  I don't think it'll provide enough benefit
        //               to implement but it is a possibility.
        var i: usize = 0; // -1 as a index of 0 is the last code point
        var rawIndex: usize = self.bytes.len - 1;

        // Effectively simulates a '-1' value on i
        while (i <= index) {
            if (rawIndex < 0) return error.IndexOutOfBounds;

            if (self.bytes[rawIndex] & 0xC0 == 0x80) {
                // We can skip over this
                rawIndex -= 1;
            } else {
                // This is valid
                i += 1;
            }
        }

        const length: usize = utf8ByteSequenceLength(self.bytes[rawIndex]);

        switch (length) {
            1 => return u32(self.bytes[rawIndex]),
            2 => return try utf8Decode2(self.bytes[rawIndex..rawIndex+2]),
            3 => return try utf8Decode3(self.bytes[rawIndex..rawIndex+3]),
            4 => return try utf8Decode4(self.bytes[rawIndex..rawIndex+4]),
            else => unreachable,
        }
    }

    pub fn initUnchecked(s: []const u8) Utf8View {
        return Utf8View {
            .bytes = s,
        };
    }

    pub fn initComptime(comptime s: []const u8) Utf8View {
        if (comptime init(s)) |r| {
            return r;
        } else |err| switch (err) {
            error.InvalidUtf8 => {
                @compileError("invalid utf8");
                unreachable;
            }
        }
    }

    pub fn iterator(s: &const Utf8View) Utf8Iterator {
        return Utf8Iterator {
            .raw = s.bytes,
            .index = 0,
        };
    }
};

pub const Utf8Iterator = struct {
    raw: []const u8,
    index: usize,

    pub fn reset(it: &Utf8Iterator) void {
        it.index = 0;
    }

    pub fn next(it: &Utf8Iterator) ?[]const u {
        return it.nextCodepointSlice();
    }

    pub fn nextBytes(it: &Utf8Iterator) ?[]const u8 {
        if (it.index >= it.raw.len) {
            return null;
        }

        const cp_len = utf8ByteSequenceLength(it.raw[it.index]) catch unreachable;

        it.index+= cp_len;
        return it.raw[it.index-cp_len..it.index];
    }

    pub fn nextCodepoint(it: &Utf8Iterator) ?u32 {
        const slice = it.nextBytes() ?? return null;

        const r = switch (slice.len) {
            1 => u32(slice[0]),
            2 => utf8Decode2(slice),
            3 => utf8Decode3(slice),
            4 => utf8Decode4(slice),
            else => unreachable,
        };

        return r catch unreachable;
    }
};

fn utf8_changeCase(view: &Utf8View, allocator: &mem.Allocator, lowercase: bool) Utf8View {
    assert(view.bytes.len > 0);
    // Note: The unicode alphabet is currently just the english one
    // I'll later have it as all the alphabets but for simplicity now it'll just be english
    // Thus we can presume the byte length is the same.
    var newArray : []u8 = try allocator.alloc(u8, @sizeOf(u8) * view.bytes.len);
    var it = view.iterator();
    var codepoint = it.nextCodepoint();
    var i : usize = 0;

    while (bytes) |v| {
        var bytes = utf8Encode(v);
        if (lowercase and Utf8_Locale.isLowercaseLetter(v)) {
            for (view.buffer.bytes[i..i + bytes.len]) |byte| {
                newArray[i] = v + ('a' - 'A');
            }
        } else if (!lowercase and Utf8_Locale.isUppercaseLetter(v)) {
            for (view.buffer.bytes[i..i + bytes.len]) |byte| {
                newArray[i] = v - ('a' - 'A');
            }
        } else {
            for (view.buffer.bytes[i..i + bytes.len]) |byte| {
                newArray[i] = v;
            }
        }
        char = it.nextCodePoint();
        i += bytes.len;
    }

    return Utf8View.initUnchecked(newArray);
}

fn utf8_changeCaseBuffer(view: &Utf8View, buffer: []u8, lowercase: bool) Utf8View {
    assert(view.bytes.len > 0 and view.bytes.len <= buffer.len);
    var it = view.iterator();
    var codepoint = it.nextCodepoint();
    var i: usize = 0;
    const diff: usize = comptime utf8Decode('a') - utf8Decode('A');

    while (bytes) |v| {
        // Forcing a safety check, we can't count how many
        // codepoints prior sadly.
        assert(buffer.len > i);

        if (lowercase and Utf8_Locale.isLowercaseLetter(v)) {
            buffer[i] = v + diff;
        } else if (!lowercase and Utf8_Locale.isUppercaseLetter(v)) {
            buffer[i] = v - diff;
        } else {
            buffer[i] = v;
        }
        char = it.nextCodePoint();
        i += 1;
    }

    return Utf8View.initUnchecked(buffer[0..i]);
}

fn utf8_toLower(view: &Utf8View, allocator: &mem.Allocator) Utf8View {
    return try changeCase(view, allocator, true);
}

fn utf8_toUpper(view: &Utf8View, allocator: &mem.Allocator) Utf8View {
    return try changeCase(view, allocator, false);
}

fn utf8_toUpperBuffer(view: &Utf8View, buffer: []u32) Utf8View {
    return try changeCaseBuffer(view, buffer, false);
}

fn utf8_toLowerBuffer(view: &Utf8View, buffer: []u32) Utf8View {
    return try changeCaseBuffer(view, buffer, true);
}

pub const Utf8_Locale_Type = locale.CreateLocale(u8, Utf8View, Utf8Iterator);
pub const Utf8_Locale = Locale_Type {
    .lowercaseLetters = Utf8View.initUnchecked("abcdefghijklmnopqrstuvwxyz"), .uppercaseLetters = Utf8View.initUnchecked("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    .whitespaceLetters = Utf8View.initUnchecked(" \t\r\n"), .numbers = Utf8View.initUnchecked("0123456789"), 
    .formatter = Locale_Type.FormatterType {
        .toLower = utf8_toLower, .toUpper = utf8_toUpper,
        .toLowerBuffer = utf8_toLowerBuffer, .toUpperBuffer = utf8_toUpperBuffer,
    }
};

test "utf8 encode" {
    // A few taken from wikipedia a few taken elsewhere
    var array: [4]u8 = undefined;
    debug.assert(?? utf8Encode(try utf8Decode("€"), array[0..]) == 3);
    debug.assert(array[0] == 0b11100010);
    debug.assert(array[1] == 0b10000010);
    debug.assert(array[2] == 0b10101100);

    debug.assert(?? utf8Encode(try utf8Decode("$"), array[0..]) == 1);
    debug.assert(array[0] == 0b00100100);

    debug.assert(?? utf8Encode(try utf8Decode("¢"), array[0..]) == 2);
    debug.assert(array[0] == 0b11000010);
    debug.assert(array[1] == 0b10100010);

    debug.assert(?? utf8Encode(try utf8Decode("𐍈"), array[0..]) == 4);
    debug.assert(array[0] == 0b11110000);
    debug.assert(array[1] == 0b10010000);
    debug.assert(array[2] == 0b10001101);
    debug.assert(array[3] == 0b10001000);
}

test "uf8 encode error" {
    var array: [4]u8 = undefined;
    testErrorEncode(0x10FFFF, array[0..], error.Utf8CodepointTooLarge);
    testErrorEncode(0xd900, array[0..], error.InvalidCodepoint);
}

fn testErrorEncode(codePoint: u32, array: []u8, expectedErr: error) void {
    if (utf8Encode(codePoint, array)) |_| {
        unreachable;
    } else |err| {
        assert(err == expected_err);
    }
}

test "utf8 iterator on ascii" {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    debug.assert(std.mem.eql(u8, "a", ??it1.nextBytes()));
    debug.assert(std.mem.eql(u8, "b", ??it1.nextBytes()));
    debug.assert(std.mem.eql(u8, "c", ??it1.nextBytes()));
    debug.assert(it1.nextBytes() == null);

    var it2 = s.iterator();
    debug.assert(??it2.nextCodepoint() == 'a');
    debug.assert(??it2.nextCodepoint() == 'b');
    debug.assert(??it2.nextCodepoint() == 'c');
    debug.assert(it2.nextCodepoint() == null);
}

test "utf8 view bad" {
    // Compile-time error.
    // const s3 = Utf8View.initComptime("\xfe\xf2");

    const s = Utf8View.init("hel\xadlo");
    if (s) |_| { unreachable; } else |err| { debug.assert(err == error.InvalidUtf8); }
}

test "utf8 view ok" {
    const s = Utf8View.initComptime("東京市");

    var it1 = s.iterator();
    debug.assert(std.mem.eql(u8, "東", ??it1.nextBytes()));
    debug.assert(std.mem.eql(u8, "京", ??it1.nextBytes()));
    debug.assert(std.mem.eql(u8, "市", ??it1.nextBytes()));
    debug.assert(it1.nextBytes() == null);

    var it2 = s.iterator();
    debug.assert(??it2.nextCodepoint() == 0x6771);
    debug.assert(??it2.nextCodepoint() == 0x4eac);
    debug.assert(??it2.nextCodepoint() == 0x5e02);
    debug.assert(it2.nextCodepoint() == null);
}

test "bad utf8 slice" {
    debug.assert(utf8ValidateSlice("abc"));
    debug.assert(!utf8ValidateSlice("abc\xc0"));
    debug.assert(!utf8ValidateSlice("abc\xc0abc"));
    debug.assert(utf8ValidateSlice("abc\xdf\xbf"));
}

test "valid utf8" {
    testValid("\x00", 0x0);
    testValid("\x20", 0x20);
    testValid("\x7f", 0x7f);
    testValid("\xc2\x80", 0x80);
    testValid("\xdf\xbf", 0x7ff);
    testValid("\xe0\xa0\x80", 0x800);
    testValid("\xe1\x80\x80", 0x1000);
    testValid("\xef\xbf\xbf", 0xffff);
    testValid("\xf0\x90\x80\x80", 0x10000);
    testValid("\xf1\x80\x80\x80", 0x40000);
    testValid("\xf3\xbf\xbf\xbf", 0xfffff);
    testValid("\xf4\x8f\xbf\xbf", 0x10ffff);
}

test "invalid utf8 continuation bytes" {
    // unexpected continuation
    testError("\x80", error.Utf8InvalidStartByte);
    testError("\xbf", error.Utf8InvalidStartByte);
    // too many leading 1's
    testError("\xf8", error.Utf8InvalidStartByte);
    testError("\xff", error.Utf8InvalidStartByte);
    // expected continuation for 2 byte sequences
    testError("\xc2", error.UnexpectedEof);
    testError("\xc2\x00", error.Utf8ExpectedContinuation);
    testError("\xc2\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 3 byte sequences
    testError("\xe0", error.UnexpectedEof);
    testError("\xe0\x00", error.UnexpectedEof);
    testError("\xe0\xc0", error.UnexpectedEof);
    testError("\xe0\xa0", error.UnexpectedEof);
    testError("\xe0\xa0\x00", error.Utf8ExpectedContinuation);
    testError("\xe0\xa0\xc0", error.Utf8ExpectedContinuation);
    // expected continuation for 4 byte sequences
    testError("\xf0", error.UnexpectedEof);
    testError("\xf0\x00", error.UnexpectedEof);
    testError("\xf0\xc0", error.UnexpectedEof);
    testError("\xf0\x90\x00", error.UnexpectedEof);
    testError("\xf0\x90\xc0", error.UnexpectedEof);
    testError("\xf0\x90\x80\x00", error.Utf8ExpectedContinuation);
    testError("\xf0\x90\x80\xc0", error.Utf8ExpectedContinuation);
}

test "overlong utf8 codepoint" {
    testError("\xc0\x80", error.Utf8OverlongEncoding);
    testError("\xc1\xbf", error.Utf8OverlongEncoding);
    testError("\xe0\x80\x80", error.Utf8OverlongEncoding);
    testError("\xe0\x9f\xbf", error.Utf8OverlongEncoding);
    testError("\xf0\x80\x80\x80", error.Utf8OverlongEncoding);
    testError("\xf0\x8f\xbf\xbf", error.Utf8OverlongEncoding);
}

test "misc invalid utf8" {
    // codepoint out of bounds
    testError("\xf4\x90\x80\x80", error.Utf8CodepointTooLarge);
    testError("\xf7\xbf\xbf\xbf", error.Utf8CodepointTooLarge);
    // surrogate halves
    testValid("\xed\x9f\xbf", 0xd7ff);
    testError("\xed\xa0\x80", error.Utf8EncodesSurrogateHalf);
    testError("\xed\xbf\xbf", error.Utf8EncodesSurrogateHalf);
    testValid("\xee\x80\x80", 0xe000);
}

fn testError(bytes: []const u8, expected_err: error) void {
    if (testDecode(bytes)) |_| {
        unreachable;
    } else |err| {
        debug.assert(err == expected_err);
    }
}

fn testValid(bytes: []const u8, expected_codepoint: u32) void {
    debug.assert((testDecode(bytes) catch unreachable) == expected_codepoint);
}

fn testDecode(bytes: []const u8) !u32 {
    const length = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < length) return error.UnexpectedEof;
    debug.assert(bytes.len == length);
    return utf8Decode(bytes);
}
