const std = @import("./index.zig");
const debug = std.debug;

/// Returns how many bytes the UTF-8 representation would require
/// for the given codepoint.
pub fn utf8CodepointSequenceLength(c: u32) !u3 {
    if (c < 0x80) return u3(1);
    if (c < 0x800) return u3(2);
    if (c < 0x10000) return u3(3);
    if (c < 0x110000) return u3(4);
    return error.CodepointTooLarge;
}

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

/// Encodes the given codepoint into a UTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in UTF-8.
/// Returns: the number of bytes written to out.
pub fn utf8Encode(c: u32, out: []u8) !u3 {
    const length = try utf8CodepointSequenceLength(c);
    debug.assert(out.len >= length);
    switch (length) {
        // The pattern for each is the same
        // - Increasing the initial shift by 6 each time
        // - Each time after the first shorten the shifted
        //   value to a max of 0b111111 (63)
        1 => out[0] = @intCast(u8, c), // Can just do 0 + codepoint for initial range
        2 => {
            out[0] = @intCast(u8, 0b11000000 | (c >> 6));
            out[1] = @intCast(u8, 0b10000000 | (c & 0b111111));
        },
        3 => {
            if (0xd800 <= c and c <= 0xdfff) return error.Utf8CannotEncodeSurrogateHalf;
            out[0] = @intCast(u8, 0b11100000 | (c >> 12));
            out[1] = @intCast(u8, 0b10000000 | ((c >> 6) & 0b111111));
            out[2] = @intCast(u8, 0b10000000 | (c & 0b111111));
        },
        4 => {
            out[0] = @intCast(u8, 0b11110000 | (c >> 18));
            out[1] = @intCast(u8, 0b10000000 | ((c >> 12) & 0b111111));
            out[2] = @intCast(u8, 0b10000000 | ((c >> 6) & 0b111111));
            out[3] = @intCast(u8, 0b10000000 | (c & 0b111111));
        },
        else => unreachable,
    }
    return length;
}

const Utf8DecodeError = Utf8Decode2Error || Utf8Decode3Error || Utf8Decode4Error;

/// Decodes the UTF-8 codepoint encoded in the given slice of bytes.
/// bytes.len must be equal to utf8ByteSequenceLength(bytes[0]) catch unreachable.
/// If you already know the length at comptime, you can call one of
/// utf8Decode2,utf8Decode3,utf8Decode4 directly instead of this function.
pub fn utf8Decode(bytes: []const u8) Utf8DecodeError!u32 {
    return switch (bytes.len) {
        1 => u32(bytes[0]),
        2 => utf8Decode2(bytes),
        3 => utf8Decode3(bytes),
        4 => utf8Decode4(bytes),
        else => unreachable,
    };
}

const Utf8Decode2Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
};
pub fn utf8Decode2(bytes: []const u8) Utf8Decode2Error!u32 {
    debug.assert(bytes.len == 2);
    debug.assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u32 = bytes[0] & 0b00011111;

    if (bytes[1] & 0b11000000 != 0b10000000) return error.Utf8ExpectedContinuation;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (value < 0x80) return error.Utf8OverlongEncoding;

    return value;
}

const Utf8Decode3Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8EncodesSurrogateHalf,
};
pub fn utf8Decode3(bytes: []const u8) Utf8Decode3Error!u32 {
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

const Utf8Decode4Error = error{
    Utf8ExpectedContinuation,
    Utf8OverlongEncoding,
    Utf8CodepointTooLarge,
};
pub fn utf8Decode4(bytes: []const u8) Utf8Decode4Error!u32 {
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

            if (utf8Decode(s[i .. i + cp_len])) |_| {} else |_| {
                return false;
            }
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
        return Utf8View{ .bytes = s };
    }

    pub fn initComptime(comptime s: []const u8) Utf8View {
        if (comptime init(s)) |r| {
            return r;
        } else |err| switch (err) {
            error.InvalidUtf8 => {
                @compileError("invalid utf8");
                unreachable;
            },
        }
    }

    pub fn iterator(s: *const Utf8View) Utf8Iterator {
        return Utf8Iterator{
            .bytes = s.bytes,
            .i = 0,
        };
    }
};

const Utf8Iterator = struct {
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

    pub fn nextCodepoint(it: *Utf8Iterator) ?u32 {
        const slice = it.nextCodepointSlice() orelse return null;

        switch (slice.len) {
            1 => return u32(slice[0]),
            2 => return utf8Decode2(slice) catch unreachable,
            3 => return utf8Decode3(slice) catch unreachable,
            4 => return utf8Decode4(slice) catch unreachable,
            else => unreachable,
        }
    }
};

test "utf8 encode" {
    comptime testUtf8Encode() catch unreachable;
    try testUtf8Encode();
}
fn testUtf8Encode() !void {
    // A few taken from wikipedia a few taken elsewhere
    var array: [4]u8 = undefined;
    debug.assert((try utf8Encode(try utf8Decode("€"), array[0..])) == 3);
    debug.assert(array[0] == 0b11100010);
    debug.assert(array[1] == 0b10000010);
    debug.assert(array[2] == 0b10101100);

    debug.assert((try utf8Encode(try utf8Decode("$"), array[0..])) == 1);
    debug.assert(array[0] == 0b00100100);

    debug.assert((try utf8Encode(try utf8Decode("¢"), array[0..])) == 2);
    debug.assert(array[0] == 0b11000010);
    debug.assert(array[1] == 0b10100010);

    debug.assert((try utf8Encode(try utf8Decode("𐍈"), array[0..])) == 4);
    debug.assert(array[0] == 0b11110000);
    debug.assert(array[1] == 0b10010000);
    debug.assert(array[2] == 0b10001101);
    debug.assert(array[3] == 0b10001000);
}

test "utf8 encode error" {
    comptime testUtf8EncodeError();
    testUtf8EncodeError();
}
fn testUtf8EncodeError() void {
    var array: [4]u8 = undefined;
    testErrorEncode(0xd800, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    testErrorEncode(0xdfff, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    testErrorEncode(0x110000, array[0..], error.CodepointTooLarge);
    testErrorEncode(0xffffffff, array[0..], error.CodepointTooLarge);
}

fn testErrorEncode(codePoint: u32, array: []u8, expectedErr: error) void {
    if (utf8Encode(codePoint, array)) |_| {
        unreachable;
    } else |err| {
        debug.assert(err == expectedErr);
    }
}

test "utf8 iterator on ascii" {
    comptime testUtf8IteratorOnAscii();
    testUtf8IteratorOnAscii();
}
fn testUtf8IteratorOnAscii() void {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    debug.assert(std.mem.eql(u8, "a", it1.nextCodepointSlice().?));
    debug.assert(std.mem.eql(u8, "b", it1.nextCodepointSlice().?));
    debug.assert(std.mem.eql(u8, "c", it1.nextCodepointSlice().?));
    debug.assert(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    debug.assert(it2.nextCodepoint().? == 'a');
    debug.assert(it2.nextCodepoint().? == 'b');
    debug.assert(it2.nextCodepoint().? == 'c');
    debug.assert(it2.nextCodepoint() == null);
}

test "utf8 view bad" {
    comptime testUtf8ViewBad();
    testUtf8ViewBad();
}
fn testUtf8ViewBad() void {
    // Compile-time error.
    // const s3 = Utf8View.initComptime("\xfe\xf2");
    const s = Utf8View.init("hel\xadlo");
    if (s) |_| {
        unreachable;
    } else |err| {
        debug.assert(err == error.InvalidUtf8);
    }
}

test "utf8 view ok" {
    comptime testUtf8ViewOk();
    testUtf8ViewOk();
}
fn testUtf8ViewOk() void {
    const s = Utf8View.initComptime("東京市");

    var it1 = s.iterator();
    debug.assert(std.mem.eql(u8, "東", it1.nextCodepointSlice().?));
    debug.assert(std.mem.eql(u8, "京", it1.nextCodepointSlice().?));
    debug.assert(std.mem.eql(u8, "市", it1.nextCodepointSlice().?));
    debug.assert(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    debug.assert(it2.nextCodepoint().? == 0x6771);
    debug.assert(it2.nextCodepoint().? == 0x4eac);
    debug.assert(it2.nextCodepoint().? == 0x5e02);
    debug.assert(it2.nextCodepoint() == null);
}

test "bad utf8 slice" {
    comptime testBadUtf8Slice();
    testBadUtf8Slice();
}
fn testBadUtf8Slice() void {
    debug.assert(utf8ValidateSlice("abc"));
    debug.assert(!utf8ValidateSlice("abc\xc0"));
    debug.assert(!utf8ValidateSlice("abc\xc0abc"));
    debug.assert(utf8ValidateSlice("abc\xdf\xbf"));
}

test "valid utf8" {
    comptime testValidUtf8();
    testValidUtf8();
}
fn testValidUtf8() void {
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
    comptime testInvalidUtf8ContinuationBytes();
    testInvalidUtf8ContinuationBytes();
}
fn testInvalidUtf8ContinuationBytes() void {
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
    comptime testOverlongUtf8Codepoint();
    testOverlongUtf8Codepoint();
}
fn testOverlongUtf8Codepoint() void {
    testError("\xc0\x80", error.Utf8OverlongEncoding);
    testError("\xc1\xbf", error.Utf8OverlongEncoding);
    testError("\xe0\x80\x80", error.Utf8OverlongEncoding);
    testError("\xe0\x9f\xbf", error.Utf8OverlongEncoding);
    testError("\xf0\x80\x80\x80", error.Utf8OverlongEncoding);
    testError("\xf0\x8f\xbf\xbf", error.Utf8OverlongEncoding);
}

test "misc invalid utf8" {
    comptime testMiscInvalidUtf8();
    testMiscInvalidUtf8();
}
fn testMiscInvalidUtf8() void {
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
