const std = @import("./index.zig");
const debug = std.debug;

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

pub fn utf8Encode(c: u32, out: &[]const u8) !void {
    if (c < 0x80) {
        // Is made up of one byte
        // Can just add a '0' and then the code point
        // Thus can just output 'c'
        var result: [1]u8 = undefined;
        // This won't cause weird issues
        result[0] = u8(c);
        *out = result;
    } else if (c < 0x0800) {
        // Two bytes
        var result: [2]u8 = undefined;
        // 64 to convert the characters into their segments
        result[0] = u8(0b11000000 + c / 64);
        result[1] = u8(0b10000000 + c % 64);
        *out = result;
    } else if (c - 0xd800 < 0x800) {
        return error.InvalidCodepoint;
    } else if (c < 0x10000) {
        // Three code points
        var result: [3]u8 = undefined;
        // Again using 64 as a conversion into their segments
        // But using C / 4096 (64 * 64) as the first, (C/64) % 64 as the second, and just C % 64 as the last
        result[0] = u8(0b11100000 + c / 4096);
        result[1] = u8(0b10000000 + (c / 64) % 64);
        result[2] = u8(0b10000000 + c % 64);
        *out = result;
    } else if (c < 0x110000) {
        // Four code points
        var result: [4]u8 = undefined;
        // Same as previously but now its C / 64^3 (262144), (C / 4096) % 64, (C / 64) % 64 and C % 64
        result[0] = u8(0b11110000 + c / 262144);
        result[1] = u8(0b10000000 + (c / 4096) % 64);
        result[2] = u8(0b10000000 + (c / 64) % 64);
        result[3] = u8(0b10000000 + c % 64);
        *out = result;
    } else {
        return error.InvalidCodepoint;
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
            .bytes = s.bytes,
            .i = 0,
        };
    }
};

const Utf8Iterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn nextCodepointSlice(it: &Utf8Iterator) ?[]const u8 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        const cp_len = utf8ByteSequenceLength(it.bytes[it.i]) catch unreachable;

        it.i += cp_len;
        return it.bytes[it.i-cp_len..it.i];
    }

    pub fn nextCodepoint(it: &Utf8Iterator) ?u32 {
        const slice = it.nextCodepointSlice() ?? return null;

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

test "utf8 encode" {
    // A few taken from wikipedia a few taken elsewhere
    var array: []const u8 = undefined;
    try utf8Encode(try utf8Decode("$"), &array);
    debug.assert(array.len == 1);
    debug.assert(array[0] == 0b00100100);

    try utf8Encode(try utf8Decode("¢", &array);
    debug.assert(array.len == 2);
    debug.assert(array[0] == 0b11000010);
    debug.assert(array[1] == 0b10100010);

    try utf8Encode(try utf8Decode("€", &array));
    debug.assert(array.len == 3);
    debug.assert(array[0] == 0b11100010);
    debug.assert(array[1] == 0b10000010);
    debug.assert(array[2] == 0b10101100);

    try utf8Encode(try utf8Decode("𐍈", &array));
    debug.assert(array.len == 4);
    debug.assert(array[0] == 0b11110000);
    debug.assert(array[1] == 0b10010000);
    debug.assert(array[2] == 0b10001101);
    debug.assert(array[3] == 0b10001000);
}

test "uf8 encode error" {
    // Fit errors here
    // if (testDecode(bytes)) |_| {
    //     unreachable;
    // } else |err| {
    //     debug.assert(err == expected_err);
    // }
}

test "utf8 iterator on ascii" {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    debug.assert(std.mem.eql(u8, "a", ??it1.nextCodepointSlice()));
    debug.assert(std.mem.eql(u8, "b", ??it1.nextCodepointSlice()));
    debug.assert(std.mem.eql(u8, "c", ??it1.nextCodepointSlice()));
    debug.assert(it1.nextCodepointSlice() == null);

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
    debug.assert(std.mem.eql(u8, "東", ??it1.nextCodepointSlice()));
    debug.assert(std.mem.eql(u8, "京", ??it1.nextCodepointSlice()));
    debug.assert(std.mem.eql(u8, "市", ??it1.nextCodepointSlice()));
    debug.assert(it1.nextCodepointSlice() == null);

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
