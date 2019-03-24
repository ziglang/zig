const std = @import("./std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;

pub const Utf8Error = UnicodeError || error{
    Utf8ShortChar,
    Utf8OverlongEncoding,
    Utf8InvalidStartByte,
};

pub const UnicodeError = error{
    UnicodeSurrogateHalf,
    UnicodeCodepointTooLarge,
};

// http://www.unicode.org/versions/Unicode6.0.0/ch03.pdf - page 94
//
// Table 3-7. Well-Formed UTF-8 Byte Sequences
//
// +--------------------+------------+-------------+------------+-------------+
// | Code Points        | First Byte | Second Byte | Third Byte | Fourth Byte |
// +--------------------+------------+-------------+------------+-------------+
// | U+0000..U+007F     | 00..7F     |             |            |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+0080..U+07FF     | C2..DF     | 80..BF      |            |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+0800..U+0FFF     | E0         | A0..BF      | 80..BF     |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+1000..U+CFFF     | E1..EC     | 80..BF      | 80..BF     |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+D000..U+D7FF     | ED         | 80..9F      | 80..BF     |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+E000..U+FFFF     | EE..EF     | 80..BF      | 80..BF     |             |
// +--------------------+------------+-------------+------------+-------------+
// | U+10000..U+3FFFF   | F0         | 90..BF      | 80..BF     | 80..BF      |
// +--------------------+------------+-------------+------------+-------------+
// | U+40000..U+FFFFF   | F1..F3     | 80..BF      | 80..BF     | 80..BF      |
// +--------------------+------------+-------------+------------+-------------+
// | U+100000..U+10FFFF | F4         | 80..8F      | 80..BF     | 80..BF      |
// +--------------------+------------+-------------+------------+-------------+

// This accepts u32 instead of u21 on purpose
pub fn isValidUnicode(c: u32) UnicodeError!void {
    switch (c) {
    0x0000...0xd7ff => {},
    0xd800...0xdfff => return error.UnicodeSurrogateHalf,
    0xe000...0x10ffff => {},
    0x110000...0xffffffff => return error.UnicodeCodepointTooLarge,
    }
}

/// Returns how many bytes the UTF-8 representation would require
/// for the given codepoint.
pub fn utf8CodepointSequenceLength(c: u32) Utf8Error!u3 {
    if (c < 0x80) return u3(1);
    if (c < 0x800) return u3(2);
    if (c < 0x10000) return u3(3);
    if (c < 0x110000) return u3(4);
    return error.UnicodeCodepointTooLarge;
}

/// Given the first byte of a UTF-8 codepoint,
/// returns a number 1-4 indicating the total length of the codepoint in bytes.
/// If this byte does not match the form of a UTF-8 start byte, returns Utf8InvalidStartByte.
pub fn utf8ByteSequenceLength(first_byte: u8) Utf8Error!u3 {
    const INVALID = 0;
    const swtch = []u8{1, INVALID, 2, 3, 4, INVALID, INVALID, INVALID, INVALID};
    var len = swtch[@clz(~first_byte)];
    if (len == INVALID) {
        return error.Utf8InvalidStartByte;
    }
    return @intCast(u3, len);
}

/// Encodes the given codepoint into a UTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in UTF-8.
/// Returns: the number of bytes written to out.
pub fn utf8Encode(c: u32, out: []u8) Utf8Error!u3 {
    const length = try utf8CodepointSequenceLength(c);
    assert(out.len >= length);
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
            if (0xd800 <= c and c <= 0xdfff) return error.UnicodeSurrogateHalf;
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

/// Decodes the UTF-8 codepoint encoded in the given slice of bytes and returns
/// then length of the character decoded.
///
/// Guaranteed to not read bytes past this character.
///
/// "ret" cannot be *u21 because when casting to *u32 it would have differn't
/// behavior on Little-Endian and Big-Endian machines, which is too much to ask
/// of our callers.
/// https://github.com/ziglang/zig/issues/2136
pub fn utf8Decode(bytes: []const u8, ret: *align(4) u32) Utf8Error!u3 {
    var len = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < len) {
        return error.Utf8ShortChar;
    }
    ret.* = switch (len) {
        1 => u32(bytes[0]),
        2 => try utf8Decode2(bytes[0..2]),
        3 => try utf8Decode3(bytes[0..3]),
        4 => try utf8Decode4(bytes[0..4]),
        else => unreachable,
    };
    return len;
}

pub fn utf8Decode2(bytes: []const u8) Utf8Error!u32 {
    assert(bytes.len == 2);
    assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u32 = bytes[0] & 0b00011111;

    if (@clz(~bytes[1]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (value < 0x80) return error.Utf8OverlongEncoding;

    return value;
}

pub fn utf8Decode3(bytes: []const u8) Utf8Error!u32 {
    assert(bytes.len == 3);
    assert(bytes[0] & 0b11110000 == 0b11100000);
    var value: u32 = bytes[0] & 0b00001111;

    if (@clz(~bytes[1]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (@clz(~bytes[2]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (value < 0x800) return error.Utf8OverlongEncoding;
    if (0xd800 <= value and value <= 0xdfff) return error.UnicodeSurrogateHalf;

    return value;
}

pub fn utf8Decode4(bytes: []const u8) Utf8Error!u32 {
    assert(bytes.len == 4);
    assert(bytes[0] & 0b11111000 == 0b11110000);
    var value: u32 = bytes[0] & 0b00000111;

    if (@clz(~bytes[2]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    if (@clz(~bytes[2]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[2] & 0b00111111;

    if (@clz(~bytes[2]) != 1) return error.Utf8ShortChar;
    value <<= 6;
    value |= bytes[3] & 0b00111111;

    if (value < 0x10000) return error.Utf8OverlongEncoding;
    if (value > 0x10FFFF) return error.UnicodeCodepointTooLarge;

    return value;
}

// TODO replace with something faster:
// https://github.com/cyb70289/utf8/
// https://lemire.me/blog/2018/10/19/validating-utf-8-bytes-using-only-0-45-cycles-per-byte-avx-edition/
pub fn utf8ValidateSliceWithLoc(s: []const u8, ret_invalid_maybe: ?*usize) Utf8Error!void {
    var i: usize = 0;
    while (i < s.len) {
        var c: u32 = undefined;
        i += utf8Decode(s[i..], &c) catch |err| {
            if (ret_invalid_maybe) |ret_invalid| {
                ret_invalid.* = i;
            }
            return err;
        };
    }
    return;
}

pub fn utf8ValidateSlice(s: []const u8) bool {
    utf8ValidateSliceWithLoc(s, null) catch return false;
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
        if (utf8ValidateSlice(s)) {
            return initUnchecked(s);
        } else return error.InvalidUtf8;
    }

    pub fn initUnchecked(s: []const u8) Utf8View {
        return Utf8View{ .bytes = s };
    }

    /// TODO: https://github.com/ziglang/zig/issues/425
    pub fn initComptime(comptime s: []const u8) Utf8View {
        if (comptime init(s)) |r| {
            return r;
        } else |err| {
            @compileError("invalid utf8");
            unreachable;
        }
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

        const cp_len = utf8ByteSequenceLength(it.bytes[it.i]) catch null;
        it.i += cp_len;
        return it.bytes[it.i - cp_len .. it.i];
    }

    pub fn nextCodepoint(it: *Utf8Iterator) ?u21 {
        if (it.i >= it.bytes.len) {
            return null;
        }

        var c: u32 = undefined;
        it.i += utf8Decode(it.bytes[it.i..], &c) catch return null;
        return @intCast(u21, c);
    }
};

pub const Utf16LeIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(s: []const u16) Utf16LeIterator {
        return Utf16LeIterator{
            .bytes = @sliceToBytes(s),
            .i = 0,
        };
    }

    pub fn nextCodepoint(it: *Utf16LeIterator) !?u21 {
        assert(it.i <= it.bytes.len);
        if (it.i == it.bytes.len) return null;
        const c0: u32 = mem.readIntSliceLittle(u16, it.bytes[it.i .. it.i + 2]);
        if (c0 & ~u32(0x03ff) == 0xd800) {
            // surrogate pair
            it.i += 2;
            if (it.i >= it.bytes.len) return error.DanglingSurrogateHalf;
            const c1: u32 = mem.readIntSliceLittle(u16, it.bytes[it.i .. it.i + 2]);
            if (c1 & ~u32(0x03ff) != 0xdc00) return error.ExpectedSecondSurrogateHalf;
            it.i += 2;
            return @truncate(u21, 0x10000 + (((c0 & 0x03ff) << 10) | (c1 & 0x03ff)));
        } else if (c0 & ~u32(0x03ff) == 0xdc00) {
            return error.UnexpectedSecondSurrogateHalf;
        } else {
            it.i += 2;
            return @truncate(u21, c0);
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
    testing.expect((try utf8Encode('€', array[0..])) == 3);
    testing.expect(array[0] == 0b11100010);
    testing.expect(array[1] == 0b10000010);
    testing.expect(array[2] == 0b10101100);

    testing.expect((try utf8Encode('$', array[0..])) == 1);
    testing.expect(array[0] == 0b00100100);

    testing.expect((try utf8Encode('¢', array[0..])) == 2);
    testing.expect(array[0] == 0b11000010);
    testing.expect(array[1] == 0b10100010);

    testing.expect((try utf8Encode('𐍈', array[0..])) == 4);
    testing.expect(array[0] == 0b11110000);
    testing.expect(array[1] == 0b10010000);
    testing.expect(array[2] == 0b10001101);
    testing.expect(array[3] == 0b10001000);
}

test "utf8 encode error" {
    comptime testUtf8EncodeError();
    testUtf8EncodeError();
}
fn testUtf8EncodeError() void {
    var array: [4]u8 = undefined;
    testErrorEncode(0xd800, array[0..], error.UnicodeSurrogateHalf);
    testErrorEncode(0xdfff, array[0..], error.UnicodeSurrogateHalf);
    testErrorEncode(0x110000, array[0..], error.UnicodeCodepointTooLarge);
}

fn testErrorEncode(codePoint: u21, array: []u8, expectedErr: anyerror) void {
    testing.expectError(expectedErr, utf8Encode(codePoint, array));
}

test "utf8 iterator on ascii" {
    comptime testUtf8IteratorOnAscii();
    testUtf8IteratorOnAscii();
}
fn testUtf8IteratorOnAscii() void {
    const s = Utf8View.initComptime("abc");

    var it1 = s.iterator();
    testing.expect(std.mem.eql(u8, "a", it1.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "b", it1.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "c", it1.nextCodepointSlice().?));
    testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    testing.expect(it2.nextCodepoint().? == 'a');
    testing.expect(it2.nextCodepoint().? == 'b');
    testing.expect(it2.nextCodepoint().? == 'c');
    testing.expect(it2.nextCodepoint() == null);
}

test "utf8 view bad" {
    comptime testUtf8ViewBad();
    testUtf8ViewBad();
}
fn testUtf8ViewBad() void {
    // Compile-time error.
    // const s3 = Utf8View.initComptime("\xfe\xf2");
    testing.expectError(error.InvalidUtf8, Utf8View.init("hel\xadlo"));
}

test "utf8 view ok" {
    comptime testUtf8ViewOk();
    testUtf8ViewOk();
}
fn testUtf8ViewOk() void {
    const s = Utf8View.initComptime("東京市");

    var it1 = s.iterator();
    testing.expect(std.mem.eql(u8, "東", it1.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "京", it1.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "市", it1.nextCodepointSlice().?));
    testing.expect(it1.nextCodepointSlice() == null);

    var it2 = s.iterator();
    testing.expect(it2.nextCodepoint().? == 0x6771);
    testing.expect(it2.nextCodepoint().? == 0x4eac);
    testing.expect(it2.nextCodepoint().? == 0x5e02);
    testing.expect(it2.nextCodepoint() == null);
}

test "bad utf8 slice" {
    comptime testBadUtf8Slice();
    testBadUtf8Slice();
}
fn testBadUtf8Slice() void {
    testing.expect(utf8ValidateSlice("abc"));
    testing.expect(!utf8ValidateSlice("abc\xc0"));
    testing.expect(!utf8ValidateSlice("abc\xc0abc"));
    testing.expect(utf8ValidateSlice("abc\xdf\xbf"));
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
    testError("\xc2", error.Utf8ShortChar);
    testError("\xc2\x00", error.Utf8ShortChar);
    testError("\xc2\xc0", error.Utf8ShortChar);
    // expected continuation for 3 byte sequences
    testError("\xe0", error.Utf8ShortChar);
    testError("\xe0\x00", error.Utf8ShortChar);
    testError("\xe0\xc0", error.Utf8ShortChar);
    testError("\xe0\xa0", error.Utf8ShortChar);
    testError("\xe0\xa0\x00", error.Utf8ShortChar);
    testError("\xe0\xa0\xc0", error.Utf8ShortChar);
    // expected continuation for 4 byte sequences
    testError("\xf0", error.Utf8ShortChar);
    testError("\xf0\x00", error.Utf8ShortChar);
    testError("\xf0\xc0", error.Utf8ShortChar);
    testError("\xf0\x90\x00", error.Utf8ShortChar);
    testError("\xf0\x90\xc0", error.Utf8ShortChar);
    testError("\xf0\x90\x80\x00", error.Utf8ShortChar);
    testError("\xf0\x90\x80\xc0", error.Utf8ShortChar);
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
    testError("\xf4\x90\x80\x80", error.UnicodeCodepointTooLarge);
    testError("\xf7\xbf\xbf\xbf", error.UnicodeCodepointTooLarge);
    // surrogate halves
    testValid("\xed\x9f\xbf", 0xd7ff);
    testError("\xed\xa0\x80", error.UnicodeSurrogateHalf);
    testError("\xed\xbf\xbf", error.UnicodeSurrogateHalf);
    testValid("\xee\x80\x80", 0xe000);
}

fn testError(bytes: []const u8, expected_err: anyerror) void {
    testing.expectError(expected_err, testDecode(bytes));
}

fn testValid(bytes: []const u8, expected_codepoint: u32) void {
    testing.expect((testDecode(bytes) catch unreachable) == expected_codepoint);
}

fn testDecode(bytes: []const u8) !u32 {
    const length = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < length) return error.Utf8ShortChar;
    testing.expect(bytes.len == length);
    var c: u32 = undefined;
    _ = try utf8Decode(bytes, &c);
    return c;
}

/// Caller must free returned memory.
pub fn utf16leToUtf8Alloc(allocator: *mem.Allocator, utf16le: []const u16) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    // optimistically guess that it will all be ascii.
    try result.ensureCapacity(utf16le.len);
    var out_index: usize = 0;
    var it = Utf16LeIterator.init(utf16le);
    while (try it.nextCodepoint()) |codepoint| {
        const utf8_len = utf8CodepointSequenceLength(codepoint) catch unreachable;
        try result.resize(result.len + utf8_len);
        assert((utf8Encode(codepoint, result.items[out_index..]) catch unreachable) == utf8_len);
        out_index += utf8_len;
    }

    return result.toOwnedSlice();
}

/// Asserts that the output buffer is big enough.
/// Returns end byte index into utf8.
pub fn utf16leToUtf8(utf8: []u8, utf16le: []const u16) !usize {
    var end_index: usize = 0;
    var it = Utf16LeIterator.init(utf16le);
    while (try it.nextCodepoint()) |codepoint| {
        end_index += try utf8Encode(codepoint, utf8[end_index..]);
    }
    return end_index;
}

test "utf16leToUtf8" {
    var utf16le: [2]u16 = undefined;
    const utf16le_as_bytes = @sliceToBytes(utf16le[0..]);

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 'A');
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 'a');
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "Aa"));
    }

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0x80);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xffff);
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "\xc2\x80" ++ "\xef\xbf\xbf"));
    }

    {
        // the values just outside the surrogate half range
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xd7ff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xe000);
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "\xed\x9f\xbf" ++ "\xee\x80\x80"));
    }

    {
        // smallest surrogate pair
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xd800);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdc00);
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "\xf0\x90\x80\x80"));
    }

    {
        // largest surrogate pair
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xdbff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdfff);
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xbf\xbf"));
    }

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xdbff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdc00);
        const utf8 = try utf16leToUtf8Alloc(std.debug.global_allocator, utf16le);
        testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xb0\x80"));
    }
}

/// TODO support codepoints bigger than 16 bits
/// TODO type for null terminated pointer
pub fn utf8ToUtf16LeWithNull(allocator: *mem.Allocator, utf8: []const u8) ![]u16 {
    var result = std.ArrayList(u16).init(allocator);
    // optimistically guess that it will not require surrogate pairs
    try result.ensureCapacity(utf8.len + 1);

    const view = try Utf8View.init(utf8);
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        try result.append(@intCast(u16, codepoint)); // TODO surrogate pairs
    }

    try result.append(0);
    return result.toOwnedSlice();
}

/// Returns index of next character. If exact fit, returned index equals output slice length.
/// If ran out of room, returned index equals output slice length + 1.
/// TODO support codepoints bigger than 16 bits
pub fn utf8ToUtf16Le(utf16le: []u16, utf8: []const u8) !usize {
    const utf16le_as_bytes = @sliceToBytes(utf16le[0..]);
    var end_index: usize = 0;

    var it = (try Utf8View.init(utf8)).iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (end_index == utf16le_as_bytes.len) return (end_index / 2) + 1;
        // TODO surrogate pairs
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[end_index..], @intCast(u16, codepoint));
        end_index += 2;
    }
    return end_index / 2;
}
