const std = @import("./std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;

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
    return switch (@clz(u8, ~first_byte)) {
        0 => 1,
        2 => 2,
        3 => 3,
        4 => 4,
        else => error.Utf8InvalidStartByte,
    };
}

/// Encodes the given codepoint into a UTF-8 byte sequence.
/// c: the codepoint.
/// out: the out buffer to write to. Must have a len >= utf8CodepointSequenceLength(c).
/// Errors: if c cannot be encoded in UTF-8.
/// Returns: the number of bytes written to out.
pub fn utf8Encode(c: u21, out: []u8) !u3 {
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
pub fn utf8Decode(bytes: []const u8) Utf8DecodeError!u21 {
    return switch (bytes.len) {
        1 => @as(u21, bytes[0]),
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
pub fn utf8Decode2(bytes: []const u8) Utf8Decode2Error!u21 {
    assert(bytes.len == 2);
    assert(bytes[0] & 0b11100000 == 0b11000000);
    var value: u21 = bytes[0] & 0b00011111;

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
pub fn utf8Decode3(bytes: []const u8) Utf8Decode3Error!u21 {
    assert(bytes.len == 3);
    assert(bytes[0] & 0b11110000 == 0b11100000);
    var value: u21 = bytes[0] & 0b00001111;

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
pub fn utf8Decode4(bytes: []const u8) Utf8Decode4Error!u21 {
    assert(bytes.len == 4);
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
///   std.debug.warn("got codepoint {}\n", .{codepoint});
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

    /// TODO: https://github.com/ziglang/zig/issues/425
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

        switch (slice.len) {
            1 => return @as(u21, slice[0]),
            2 => return utf8Decode2(slice) catch unreachable,
            3 => return utf8Decode3(slice) catch unreachable,
            4 => return utf8Decode4(slice) catch unreachable,
            else => unreachable,
        }
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

pub const Utf16LeIterator = struct {
    bytes: []const u8,
    i: usize,

    pub fn init(s: []const u16) Utf16LeIterator {
        return Utf16LeIterator{
            .bytes = mem.sliceAsBytes(s),
            .i = 0,
        };
    }

    pub fn nextCodepoint(it: *Utf16LeIterator) !?u21 {
        assert(it.i <= it.bytes.len);
        if (it.i == it.bytes.len) return null;
        const c0: u21 = mem.readIntLittle(u16, it.bytes[it.i..][0..2]);
        if (c0 & ~@as(u21, 0x03ff) == 0xd800) {
            // surrogate pair
            it.i += 2;
            if (it.i >= it.bytes.len) return error.DanglingSurrogateHalf;
            const c1: u21 = mem.readIntLittle(u16, it.bytes[it.i..][0..2]);
            if (c1 & ~@as(u21, 0x03ff) != 0xdc00) return error.ExpectedSecondSurrogateHalf;
            it.i += 2;
            return 0x10000 + (((c0 & 0x03ff) << 10) | (c1 & 0x03ff));
        } else if (c0 & ~@as(u21, 0x03ff) == 0xdc00) {
            return error.UnexpectedSecondSurrogateHalf;
        } else {
            it.i += 2;
            return c0;
        }
    }
};

pub fn utf8BlockForBytes(bytes: []u8) !Utf8Block {
    var codepoint = utf8Decode(bytes);
    return utf8BlockForCodepoint(codepoint);
}

test "utf8 encode" {
    comptime testUtf8Encode() catch unreachable;
    try testUtf8Encode();
}
fn testUtf8Encode() !void {
    // A few taken from wikipedia a few taken elsewhere
    var array: [4]u8 = undefined;
    testing.expect((try utf8Encode(try utf8Decode("€"), array[0..])) == 3);
    testing.expect(array[0] == 0b11100010);
    testing.expect(array[1] == 0b10000010);
    testing.expect(array[2] == 0b10101100);

    testing.expect((try utf8Encode(try utf8Decode("$"), array[0..])) == 1);
    testing.expect(array[0] == 0b00100100);

    testing.expect((try utf8Encode(try utf8Decode("¢"), array[0..])) == 2);
    testing.expect(array[0] == 0b11000010);
    testing.expect(array[1] == 0b10100010);

    testing.expect((try utf8Encode(try utf8Decode("𐍈"), array[0..])) == 4);
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
    testErrorEncode(0xd800, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    testErrorEncode(0xdfff, array[0..], error.Utf8CannotEncodeSurrogateHalf);
    testErrorEncode(0x110000, array[0..], error.CodepointTooLarge);
    testErrorEncode(0x1fffff, array[0..], error.CodepointTooLarge);
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

test "utf8 iterator peeking" {
    comptime testUtf8Peeking();
    testUtf8Peeking();
}

fn testUtf8Peeking() void {
    const s = Utf8View.initComptime("noël");
    var it = s.iterator();

    testing.expect(std.mem.eql(u8, "n", it.nextCodepointSlice().?));

    testing.expect(std.mem.eql(u8, "o", it.peek(1)));
    testing.expect(std.mem.eql(u8, "oë", it.peek(2)));
    testing.expect(std.mem.eql(u8, "oël", it.peek(3)));
    testing.expect(std.mem.eql(u8, "oël", it.peek(4)));
    testing.expect(std.mem.eql(u8, "oël", it.peek(10)));

    testing.expect(std.mem.eql(u8, "o", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "ë", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "l", it.nextCodepointSlice().?));
    testing.expect(it.nextCodepointSlice() == null);

    testing.expect(std.mem.eql(u8, &[_]u8{}, it.peek(1)));
}

fn testError(bytes: []const u8, expected_err: anyerror) void {
    testing.expectError(expected_err, testDecode(bytes));
}

fn testValid(bytes: []const u8, expected_codepoint: u21) void {
    testing.expect((testDecode(bytes) catch unreachable) == expected_codepoint);
}

fn testDecode(bytes: []const u8) !u21 {
    const length = try utf8ByteSequenceLength(bytes[0]);
    if (bytes.len < length) return error.UnexpectedEof;
    testing.expect(bytes.len == length);
    return utf8Decode(bytes);
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
        try result.resize(result.items.len + utf8_len);
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
    const utf16le_as_bytes = mem.sliceAsBytes(utf16le[0..]);

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 'A');
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 'a');
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "Aa"));
    }

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0x80);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xffff);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "\xc2\x80" ++ "\xef\xbf\xbf"));
    }

    {
        // the values just outside the surrogate half range
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xd7ff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xe000);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "\xed\x9f\xbf" ++ "\xee\x80\x80"));
    }

    {
        // smallest surrogate pair
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xd800);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdc00);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "\xf0\x90\x80\x80"));
    }

    {
        // largest surrogate pair
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xdbff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdfff);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xbf\xbf"));
    }

    {
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[0..], 0xdbff);
        mem.writeIntSliceLittle(u16, utf16le_as_bytes[2..], 0xdc00);
        const utf8 = try utf16leToUtf8Alloc(std.testing.allocator, &utf16le);
        defer std.testing.allocator.free(utf8);
        testing.expect(mem.eql(u8, utf8, "\xf4\x8f\xb0\x80"));
    }
}

pub fn utf8ToUtf16LeWithNull(allocator: *mem.Allocator, utf8: []const u8) ![:0]u16 {
    var result = std.ArrayList(u16).init(allocator);
    // optimistically guess that it will not require surrogate pairs
    try result.ensureCapacity(utf8.len + 1);

    const view = try Utf8View.init(utf8);
    var it = view.iterator();
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            const short = @intCast(u16, codepoint);
            try result.append(mem.nativeToLittle(u16, short));
        } else {
            const high = @intCast(u16, (codepoint - 0x10000) >> 10) + 0xD800;
            const low = @intCast(u16, codepoint & 0x3FF) + 0xDC00;
            var out: [2]u16 = undefined;
            out[0] = mem.nativeToLittle(u16, high);
            out[1] = mem.nativeToLittle(u16, low);
            try result.appendSlice(out[0..]);
        }
    }

    const len = result.items.len;
    try result.append(0);
    return result.toOwnedSlice()[0..len :0];
}

/// Returns index of next character. If exact fit, returned index equals output slice length.
/// Assumes there is enough space for the output.
pub fn utf8ToUtf16Le(utf16le: []u16, utf8: []const u8) !usize {
    var dest_i: usize = 0;
    var src_i: usize = 0;
    while (src_i < utf8.len) {
        const n = utf8ByteSequenceLength(utf8[src_i]) catch return error.InvalidUtf8;
        const next_src_i = src_i + n;
        const codepoint = utf8Decode(utf8[src_i..next_src_i]) catch return error.InvalidUtf8;
        if (codepoint < 0x10000) {
            const short = @intCast(u16, codepoint);
            utf16le[dest_i] = mem.nativeToLittle(u16, short);
            dest_i += 1;
        } else {
            const high = @intCast(u16, (codepoint - 0x10000) >> 10) + 0xD800;
            const low = @intCast(u16, codepoint & 0x3FF) + 0xDC00;
            utf16le[dest_i] = mem.nativeToLittle(u16, high);
            utf16le[dest_i + 1] = mem.nativeToLittle(u16, low);
            dest_i += 2;
        }
        src_i = next_src_i;
    }
    return dest_i;
}

test "utf8ToUtf16Le" {
    var utf16le: [2]u16 = [_]u16{0} ** 2;
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "𐐷");
        testing.expectEqual(@as(usize, 2), length);
        testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16le[0..]));
    }
    {
        const length = try utf8ToUtf16Le(utf16le[0..], "\u{10FFFF}");
        testing.expectEqual(@as(usize, 2), length);
        testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16le[0..]));
    }
}

test "utf8ToUtf16LeWithNull" {
    {
        const utf16 = try utf8ToUtf16LeWithNull(testing.allocator, "𐐷");
        defer testing.allocator.free(utf16);
        testing.expectEqualSlices(u8, "\x01\xd8\x37\xdc", mem.sliceAsBytes(utf16[0..]));
        testing.expect(utf16[2] == 0);
    }
    {
        const utf16 = try utf8ToUtf16LeWithNull(testing.allocator, "\u{10FFFF}");
        defer testing.allocator.free(utf16);
        testing.expectEqualSlices(u8, "\xff\xdb\xff\xdf", mem.sliceAsBytes(utf16[0..]));
        testing.expect(utf16[2] == 0);
    }
}

/// Converts a UTF-8 string literal into a UTF-16LE string literal.
pub fn utf8ToUtf16LeStringLiteral(comptime utf8: []const u8) *const [calcUtf16LeLen(utf8):0]u16 {
    comptime {
        const len: usize = calcUtf16LeLen(utf8);
        var utf16le: [len:0]u16 = [_:0]u16{0} ** len;
        const utf16le_len = utf8ToUtf16Le(&utf16le, utf8[0..]) catch |err| @compileError(err);
        assert(len == utf16le_len);
        return &utf16le;
    }
}

/// Returns length of a supplied UTF-8 string literal. Asserts that the data is valid UTF-8.
fn calcUtf16LeLen(utf8: []const u8) usize {
    var src_i: usize = 0;
    var dest_len: usize = 0;
    while (src_i < utf8.len) {
        const n = utf8ByteSequenceLength(utf8[src_i]) catch unreachable;
        const next_src_i = src_i + n;
        const codepoint = utf8Decode(utf8[src_i..next_src_i]) catch unreachable;
        if (codepoint < 0x10000) {
            dest_len += 1;
        } else {
            dest_len += 2;
        }
        src_i = next_src_i;
    }
    return dest_len;
}

test "utf8ToUtf16LeStringLiteral" {
    // https://github.com/ziglang/zig/issues/5127
    if (std.Target.current.cpu.arch == .mips) return error.SkipZigTest;

    {
        const bytes = [_:0]u16{0x41};
        const utf16 = utf8ToUtf16LeStringLiteral("A");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{ 0xD801, 0xDC37 };
        const utf16 = utf8ToUtf16LeStringLiteral("𐐷");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[2] == 0);
    }
    {
        const bytes = [_:0]u16{0x02FF};
        const utf16 = utf8ToUtf16LeStringLiteral("\u{02FF}");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{0x7FF};
        const utf16 = utf8ToUtf16LeStringLiteral("\u{7FF}");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{0x801};
        const utf16 = utf8ToUtf16LeStringLiteral("\u{801}");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[1] == 0);
    }
    {
        const bytes = [_:0]u16{ 0xDBFF, 0xDFFF };
        const utf16 = utf8ToUtf16LeStringLiteral("\u{10FFFF}");
        testing.expectEqualSlices(u16, &bytes, utf16);
        testing.expect(utf16[2] == 0);
    }
}

pub const Utf8Block = enum {
    BasicLatin,
    Latin1Supplement,
    LatinExtendedA,
    LatinExtendedB,
    IPAExtensions,
    SpacingModifierLetters,
    CombiningDiacriticalMarks,
    GreekAndCoptic,
    Cyrillic,
    CyrillicSupplement,
    Armenian,
    Hebrew,
    Arabic,
    Syriac,
    ArabicSupplement,
    Thaana,
    NKo,
    Samaritan,
    Mandaic,
    SyriacSupplement,
    ArabicExtendedA,
    Devanagari,
    Bengali,
    Gurmukhi,
    Gujarati,
    Oriya,
    Tamil,
    Telugu,
    Kannada,
    Malayalam,
    Sinhala,
    Thai,
    Lao,
    Tibetan,
    Myanmar,
    Georgian,
    HangulJamo,
    Ethiopic,
    EthiopicSupplement,
    Cherokee,
    UnifiedCanadianAboriginalSyllabics,
    Ogham,
    Runic,
    Tagalog,
    Hanunoo,
    Buhid,
    Tagbanwa,
    Khmer,
    Mongolian,
    UnifiedCanadianAboriginalSyllabicsExtended,
    Limbu,
    TaiLe,
    NewTaiLue,
    KhmerSymbols,
    Buginese,
    TaiTham,
    CombiningDiacriticalMarksExtended,
    Balinese,
    Sundanese,
    Batak,
    Lepcha,
    OlChiki,
    CyrillicExtendedC,
    GeorgianExtended,
    SundaneseSupplement,
    VedicExtensions,
    PhoneticExtensions,
    PhoneticExtensionsSupplement,
    CombiningDiacriticalMarksSupplement,
    LatinExtendedAdditional,
    GreekExtended,
    GeneralPunctuation,
    SuperscriptsAndSubscripts,
    CurrencySymbols,
    CombiningDiacriticalMarksForSymbols,
    LetterlikeSymbols,
    NumberForms,
    Arrows,
    MathematicalOperators,
    MiscellaneousTechnical,
    ControlPictures,
    OpticalCharacterRecognition,
    EnclosedAlphanumerics,
    BoxDrawing,
    BlockElements,
    GeometricShapes,
    MiscellaneousSymbols,
    Dingbats,
    MiscellaneousMathematicalSymbolsA,
    SupplementalArrowsA,
    BraillePatterns,
    SupplementalArrowsB,
    MiscellaneousMathematicalSymbolsB,
    SupplementalMathematicalOperators,
    MiscellaneousSymbolsAndArrows,
    Glagolitic,
    LatinExtendedC,
    Coptic,
    GeorgianSupplement,
    Tifinagh,
    EthiopicExtended,
    CyrillicExtendedA,
    SupplementalPunctuation,
    CJKRadicalsSupplement,
    KangxiRadicals,
    IdeographicDescriptionCharacters,
    CJKSymbolsAndPunctuation,
    Hiragana,
    Katakana,
    Bopomofo,
    HangulCompatibilityJamo,
    Kanbun,
    BopomofoExtended,
    CJKStrokes,
    KatakanaPhoneticExtensions,
    EnclosedCJKLettersAndMonths,
    CJKCompatibility,
    CJKUnifiedIdeographsExtensionA,
    YijingHexagramSymbols,
    CJKUnifiedIdeographs,
    YiSyllables,
    YiRadicals,
    Lisu,
    Vai,
    CyrillicExtendedB,
    Bamum,
    ModifierToneLetters,
    LatinExtendedD,
    SylotiNagri,
    CommonIndicNumberForms,
    Phagspa,
    Saurashtra,
    DevanagariExtended,
    KayahLi,
    Rejang,
    HangulJamoExtendedA,
    Javanese,
    MyanmarExtendedB,
    Cham,
    MyanmarExtendedA,
    TaiViet,
    MeeteiMayekExtensions,
    EthiopicExtendedA,
    LatinExtendedE,
    CherokeeSupplement,
    MeeteiMayek,
    HangulSyllables,
    HangulJamoExtendedB,
    HighSurrogates,
    HighPrivateUseSurrogates,
    LowSurrogates,
    PrivateUseArea,
    CJKCompatibilityIdeographs,
    AlphabeticPresentationForms,
    ArabicPresentationFormsA,
    VariationSelectors,
    VerticalForms,
    CombiningHalfMarks,
    CJKCompatibilityForms,
    SmallFormVariants,
    ArabicPresentationFormsB,
    HalfwidthAndFullwidthForms,
    Specials,
    LinearBSyllabary,
    LinearBIdeograms,
    AegeanNumbers,
    AncientGreekNumbers,
    AncientSymbols,
    PhaistosDisc,
    Lycian,
    Carian,
    CopticEpactNumbers,
    OldItalic,
    Gothic,
    OldPermic,
    Ugaritic,
    OldPersian,
    Deseret,
    Shavian,
    Osmanya,
    Osage,
    Elbasan,
    CaucasianAlbanian,
    LinearA,
    CypriotSyllabary,
    ImperialAramaic,
    Palmyrene,
    Nabataean,
    Hatran,
    Phoenician,
    Lydian,
    MeroiticHieroglyphs,
    MeroiticCursive,
    Kharoshthi,
    OldSouthArabian,
    OldNorthArabian,
    Manichaean,
    Avestan,
    InscriptionalParthian,
    InscriptionalPahlavi,
    PsalterPahlavi,
    OldTurkic,
    OldHungarian,
    HanifiRohingya,
    RumiNumeralSymbols,
    OldSogdian,
    Sogdian,
    Elymaic,
    Brahmi,
    Kaithi,
    SoraSompeng,
    Chakma,
    Mahajani,
    Sharada,
    SinhalaArchaicNumbers,
    Khojki,
    Multani,
    Khudawadi,
    Grantha,
    Newa,
    Tirhuta,
    Siddham,
    Modi,
    MongolianSupplement,
    Takri,
    Ahom,
    Dogra,
    WarangCiti,
    Nandinagari,
    ZanabazarSquare,
    Soyombo,
    PauCinHau,
    Bhaiksuki,
    Marchen,
    MasaramGondi,
    GunjalaGondi,
    Makasar,
    TamilSupplement,
    Cuneiform,
    CuneiformNumbersAndPunctuation,
    EarlyDynasticCuneiform,
    EgyptianHieroglyphs,
    EgyptianHieroglyphFormatControls,
    AnatolianHieroglyphs,
    BamumSupplement,
    Mro,
    BassaVah,
    PahawhHmong,
    Medefaidrin,
    Miao,
    IdeographicSymbolsAndPunctuation,
    Tangut,
    TangutComponents,
    KanaSupplement,
    KanaExtendedA,
    SmallKanaExtension,
    Nushu,
    Duployan,
    ShorthandFormatControls,
    ByzantineMusicalSymbols,
    MusicalSymbols,
    AncientGreekMusicalNotation,
    MayanNumerals,
    TaiXuanJingSymbols,
    CountingRodNumerals,
    MathematicalAlphanumericSymbols,
    SuttonSignWriting,
    GlagoliticSupplement,
    NyiakengPuachueHmong,
    Wancho,
    MendeKikakui,
    Adlam,
    IndicSiyaqNumbers,
    OttomanSiyaqNumbers,
    ArabicMathematicalAlphabeticSymbols,
    MahjongTiles,
    DominoTiles,
    PlayingCards,
    EnclosedAlphanumericSupplement,
    EnclosedIdeographicSupplement,
    MiscellaneousSymbolsAndPictographs,
    Emoticons,
    OrnamentalDingbats,
    TransportAndMapSymbols,
    AlchemicalSymbols,
    GeometricShapesExtended,
    SupplementalArrowsC,
    SupplementalSymbolsAndPictographs,
    ChessSymbols,
    SymbolsAndPictographsExtendedA,
    CJKUnifiedIdeographsExtensionB,
    CJKUnifiedIdeographsExtensionC,
    CJKUnifiedIdeographsExtensionD,
    CJKUnifiedIdeographsExtensionE,
    CJKUnifiedIdeographsExtensionF,
    CJKCompatibilityIdeographsSupplement,
    Tags,
    VariationSelectorsSupplement,
    SupplementaryPrivateUseAreaA,
    SupplementaryPrivateUseAreaB,
};

pub fn utf8BlockForCodepoint(c: u21) !Utf8Block {
    return switch (c) {
        0x0000...0x007F => .BasicLatin,
        0x0080...0x00FF => .Latin1Supplement,
        0x0100...0x017F => .LatinExtendedA,
        0x0180...0x024F => .LatinExtendedB,
        0x0250...0x02AF => .IPAExtensions,
        0x02B0...0x02FF => .SpacingModifierLetters,
        0x0300...0x036F => .CombiningDiacriticalMarks,
        0x0370...0x03FF => .GreekAndCoptic,
        0x0400...0x04FF => .Cyrillic,
        0x0500...0x052F => .CyrillicSupplement,
        0x0530...0x058F => .Armenian,
        0x0590...0x05FF => .Hebrew,
        0x0600...0x06FF => .Arabic,
        0x0700...0x074F => .Syriac,
        0x0750...0x077F => .ArabicSupplement,
        0x0780...0x07BF => .Thaana,
        0x07C0...0x07FF => .NKo,
        0x0800...0x083F => .Samaritan,
        0x0840...0x085F => .Mandaic,
        0x0860...0x086F => .SyriacSupplement,
        0x08A0...0x08FF => .ArabicExtendedA,
        0x0900...0x097F => .Devanagari,
        0x0980...0x09FF => .Bengali,
        0x0A00...0x0A7F => .Gurmukhi,
        0x0A80...0x0AFF => .Gujarati,
        0x0B00...0x0B7F => .Oriya,
        0x0B80...0x0BFF => .Tamil,
        0x0C00...0x0C7F => .Telugu,
        0x0C80...0x0CFF => .Kannada,
        0x0D00...0x0D7F => .Malayalam,
        0x0D80...0x0DFF => .Sinhala,
        0x0E00...0x0E7F => .Thai,
        0x0E80...0x0EFF => .Lao,
        0x0F00...0x0FFF => .Tibetan,
        0x1000...0x109F => .Myanmar,
        0x10A0...0x10FF => .Georgian,
        0x1100...0x11FF => .HangulJamo,
        0x1200...0x137F => .Ethiopic,
        0x1380...0x139F => .EthiopicSupplement,
        0x13A0...0x13FF => .Cherokee,
        0x1400...0x167F => .UnifiedCanadianAboriginalSyllabics,
        0x1680...0x169F => .Ogham,
        0x16A0...0x16FF => .Runic,
        0x1700...0x171F => .Tagalog,
        0x1720...0x173F => .Hanunoo,
        0x1740...0x175F => .Buhid,
        0x1760...0x177F => .Tagbanwa,
        0x1780...0x17FF => .Khmer,
        0x1800...0x18AF => .Mongolian,
        0x18B0...0x18FF => .UnifiedCanadianAboriginalSyllabicsExtended,
        0x1900...0x194F => .Limbu,
        0x1950...0x197F => .TaiLe,
        0x1980...0x19DF => .NewTaiLue,
        0x19E0...0x19FF => .KhmerSymbols,
        0x1A00...0x1A1F => .Buginese,
        0x1A20...0x1AAF => .TaiTham,
        0x1AB0...0x1AFF => .CombiningDiacriticalMarksExtended,
        0x1B00...0x1B7F => .Balinese,
        0x1B80...0x1BBF => .Sundanese,
        0x1BC0...0x1BFF => .Batak,
        0x1C00...0x1C4F => .Lepcha,
        0x1C50...0x1C7F => .OlChiki,
        0x1C80...0x1C8F => .CyrillicExtendedC,
        0x1C90...0x1CBF => .GeorgianExtended,
        0x1CC0...0x1CCF => .SundaneseSupplement,
        0x1CD0...0x1CFF => .VedicExtensions,
        0x1D00...0x1D7F => .PhoneticExtensions,
        0x1D80...0x1DBF => .PhoneticExtensionsSupplement,
        0x1DC0...0x1DFF => .CombiningDiacriticalMarksSupplement,
        0x1E00...0x1EFF => .LatinExtendedAdditional,
        0x1F00...0x1FFF => .GreekExtended,
        0x2000...0x206F => .GeneralPunctuation,
        0x2070...0x209F => .SuperscriptsAndSubscripts,
        0x20A0...0x20CF => .CurrencySymbols,
        0x20D0...0x20FF => .CombiningDiacriticalMarksForSymbols,
        0x2100...0x214F => .LetterlikeSymbols,
        0x2150...0x218F => .NumberForms,
        0x2190...0x21FF => .Arrows,
        0x2200...0x22FF => .MathematicalOperators,
        0x2300...0x23FF => .MiscellaneousTechnical,
        0x2400...0x243F => .ControlPictures,
        0x2440...0x245F => .OpticalCharacterRecognition,
        0x2460...0x24FF => .EnclosedAlphanumerics,
        0x2500...0x257F => .BoxDrawing,
        0x2580...0x259F => .BlockElements,
        0x25A0...0x25FF => .GeometricShapes,
        0x2600...0x26FF => .MiscellaneousSymbols,
        0x2700...0x27BF => .Dingbats,
        0x27C0...0x27EF => .MiscellaneousMathematicalSymbolsA,
        0x27F0...0x27FF => .SupplementalArrowsA,
        0x2800...0x28FF => .BraillePatterns,
        0x2900...0x297F => .SupplementalArrowsB,
        0x2980...0x29FF => .MiscellaneousMathematicalSymbolsB,
        0x2A00...0x2AFF => .SupplementalMathematicalOperators,
        0x2B00...0x2BFF => .MiscellaneousSymbolsAndArrows,
        0x2C00...0x2C5F => .Glagolitic,
        0x2C60...0x2C7F => .LatinExtendedC,
        0x2C80...0x2CFF => .Coptic,
        0x2D00...0x2D2F => .GeorgianSupplement,
        0x2D30...0x2D7F => .Tifinagh,
        0x2D80...0x2DDF => .EthiopicExtended,
        0x2DE0...0x2DFF => .CyrillicExtendedA,
        0x2E00...0x2E7F => .SupplementalPunctuation,
        0x2E80...0x2EFF => .CJKRadicalsSupplement,
        0x2F00...0x2FDF => .KangxiRadicals,
        0x2FF0...0x2FFF => .IdeographicDescriptionCharacters,
        0x3000...0x303F => .CJKSymbolsAndPunctuation,
        0x3040...0x309F => .Hiragana,
        0x30A0...0x30FF => .Katakana,
        0x3100...0x312F => .Bopomofo,
        0x3130...0x318F => .HangulCompatibilityJamo,
        0x3190...0x319F => .Kanbun,
        0x31A0...0x31BF => .BopomofoExtended,
        0x31C0...0x31EF => .CJKStrokes,
        0x31F0...0x31FF => .KatakanaPhoneticExtensions,
        0x3200...0x32FF => .EnclosedCJKLettersAndMonths,
        0x3300...0x33FF => .CJKCompatibility,
        0x3400...0x4DBF => .CJKUnifiedIdeographsExtensionA,
        0x4DC0...0x4DFF => .YijingHexagramSymbols,
        0x4E00...0x9FFF => .CJKUnifiedIdeographs,
        0xA000...0xA48F => .YiSyllables,
        0xA490...0xA4CF => .YiRadicals,
        0xA4D0...0xA4FF => .Lisu,
        0xA500...0xA63F => .Vai,
        0xA640...0xA69F => .CyrillicExtendedB,
        0xA6A0...0xA6FF => .Bamum,
        0xA700...0xA71F => .ModifierToneLetters,
        0xA720...0xA7FF => .LatinExtendedD,
        0xA800...0xA82F => .SylotiNagri,
        0xA830...0xA83F => .CommonIndicNumberForms,
        0xA840...0xA87F => .Phagspa,
        0xA880...0xA8DF => .Saurashtra,
        0xA8E0...0xA8FF => .DevanagariExtended,
        0xA900...0xA92F => .KayahLi,
        0xA930...0xA95F => .Rejang,
        0xA960...0xA97F => .HangulJamoExtendedA,
        0xA980...0xA9DF => .Javanese,
        0xA9E0...0xA9FF => .MyanmarExtendedB,
        0xAA00...0xAA5F => .Cham,
        0xAA60...0xAA7F => .MyanmarExtendedA,
        0xAA80...0xAADF => .TaiViet,
        0xAAE0...0xAAFF => .MeeteiMayekExtensions,
        0xAB00...0xAB2F => .EthiopicExtendedA,
        0xAB30...0xAB6F => .LatinExtendedE,
        0xAB70...0xABBF => .CherokeeSupplement,
        0xABC0...0xABFF => .MeeteiMayek,
        0xAC00...0xD7AF => .HangulSyllables,
        0xD7B0...0xD7FF => .HangulJamoExtendedB,
        0xD800...0xDB7F => .HighSurrogates,
        0xDB80...0xDBFF => .HighPrivateUseSurrogates,
        0xDC00...0xDFFF => .LowSurrogates,
        0xE000...0xF8FF => .PrivateUseArea,
        0xF900...0xFAFF => .CJKCompatibilityIdeographs,
        0xFB00...0xFB4F => .AlphabeticPresentationForms,
        0xFB50...0xFDFF => .ArabicPresentationFormsA,
        0xFE00...0xFE0F => .VariationSelectors,
        0xFE10...0xFE1F => .VerticalForms,
        0xFE20...0xFE2F => .CombiningHalfMarks,
        0xFE30...0xFE4F => .CJKCompatibilityForms,
        0xFE50...0xFE6F => .SmallFormVariants,
        0xFE70...0xFEFF => .ArabicPresentationFormsB,
        0xFF00...0xFFEF => .HalfwidthAndFullwidthForms,
        0xFFF0...0xFFFF => .Specials,
        0x10000...0x1007F => .LinearBSyllabary,
        0x10080...0x100FF => .LinearBIdeograms,
        0x10100...0x1013F => .AegeanNumbers,
        0x10140...0x1018F => .AncientGreekNumbers,
        0x10190...0x101CF => .AncientSymbols,
        0x101D0...0x101FF => .PhaistosDisc,
        0x10280...0x1029F => .Lycian,
        0x102A0...0x102DF => .Carian,
        0x102E0...0x102FF => .CopticEpactNumbers,
        0x10300...0x1032F => .OldItalic,
        0x10330...0x1034F => .Gothic,
        0x10350...0x1037F => .OldPermic,
        0x10380...0x1039F => .Ugaritic,
        0x103A0...0x103DF => .OldPersian,
        0x10400...0x1044F => .Deseret,
        0x10450...0x1047F => .Shavian,
        0x10480...0x104AF => .Osmanya,
        0x104B0...0x104FF => .Osage,
        0x10500...0x1052F => .Elbasan,
        0x10530...0x1056F => .CaucasianAlbanian,
        0x10600...0x1077F => .LinearA,
        0x10800...0x1083F => .CypriotSyllabary,
        0x10840...0x1085F => .ImperialAramaic,
        0x10860...0x1087F => .Palmyrene,
        0x10880...0x108AF => .Nabataean,
        0x108E0...0x108FF => .Hatran,
        0x10900...0x1091F => .Phoenician,
        0x10920...0x1093F => .Lydian,
        0x10980...0x1099F => .MeroiticHieroglyphs,
        0x109A0...0x109FF => .MeroiticCursive,
        0x10A00...0x10A5F => .Kharoshthi,
        0x10A60...0x10A7F => .OldSouthArabian,
        0x10A80...0x10A9F => .OldNorthArabian,
        0x10AC0...0x10AFF => .Manichaean,
        0x10B00...0x10B3F => .Avestan,
        0x10B40...0x10B5F => .InscriptionalParthian,
        0x10B60...0x10B7F => .InscriptionalPahlavi,
        0x10B80...0x10BAF => .PsalterPahlavi,
        0x10C00...0x10C4F => .OldTurkic,
        0x10C80...0x10CFF => .OldHungarian,
        0x10D00...0x10D3F => .HanifiRohingya,
        0x10E60...0x10E7F => .RumiNumeralSymbols,
        0x10F00...0x10F2F => .OldSogdian,
        0x10F30...0x10F6F => .Sogdian,
        0x10FE0...0x10FFF => .Elymaic,
        0x11000...0x1107F => .Brahmi,
        0x11080...0x110CF => .Kaithi,
        0x110D0...0x110FF => .SoraSompeng,
        0x11100...0x1114F => .Chakma,
        0x11150...0x1117F => .Mahajani,
        0x11180...0x111DF => .Sharada,
        0x111E0...0x111FF => .SinhalaArchaicNumbers,
        0x11200...0x1124F => .Khojki,
        0x11280...0x112AF => .Multani,
        0x112B0...0x112FF => .Khudawadi,
        0x11300...0x1137F => .Grantha,
        0x11400...0x1147F => .Newa,
        0x11480...0x114DF => .Tirhuta,
        0x11580...0x115FF => .Siddham,
        0x11600...0x1165F => .Modi,
        0x11660...0x1167F => .MongolianSupplement,
        0x11680...0x116CF => .Takri,
        0x11700...0x1173F => .Ahom,
        0x11800...0x1184F => .Dogra,
        0x118A0...0x118FF => .WarangCiti,
        0x119A0...0x119FF => .Nandinagari,
        0x11A00...0x11A4F => .ZanabazarSquare,
        0x11A50...0x11AAF => .Soyombo,
        0x11AC0...0x11AFF => .PauCinHau,
        0x11C00...0x11C6F => .Bhaiksuki,
        0x11C70...0x11CBF => .Marchen,
        0x11D00...0x11D5F => .MasaramGondi,
        0x11D60...0x11DAF => .GunjalaGondi,
        0x11EE0...0x11EFF => .Makasar,
        0x11FC0...0x11FFF => .TamilSupplement,
        0x12000...0x123FF => .Cuneiform,
        0x12400...0x1247F => .CuneiformNumbersAndPunctuation,
        0x12480...0x1254F => .EarlyDynasticCuneiform,
        0x13000...0x1342F => .EgyptianHieroglyphs,
        0x13430...0x1343F => .EgyptianHieroglyphFormatControls,
        0x14400...0x1467F => .AnatolianHieroglyphs,
        0x16800...0x16A3F => .BamumSupplement,
        0x16A40...0x16A6F => .Mro,
        0x16AD0...0x16AFF => .BassaVah,
        0x16B00...0x16B8F => .PahawhHmong,
        0x16E40...0x16E9F => .Medefaidrin,
        0x16F00...0x16F9F => .Miao,
        0x16FE0...0x16FFF => .IdeographicSymbolsAndPunctuation,
        0x17000...0x187FF => .Tangut,
        0x18800...0x18AFF => .TangutComponents,
        0x1B000...0x1B0FF => .KanaSupplement,
        0x1B100...0x1B12F => .KanaExtendedA,
        0x1B130...0x1B16F => .SmallKanaExtension,
        0x1B170...0x1B2FF => .Nushu,
        0x1BC00...0x1BC9F => .Duployan,
        0x1BCA0...0x1BCAF => .ShorthandFormatControls,
        0x1D000...0x1D0FF => .ByzantineMusicalSymbols,
        0x1D100...0x1D1FF => .MusicalSymbols,
        0x1D200...0x1D24F => .AncientGreekMusicalNotation,
        0x1D2E0...0x1D2FF => .MayanNumerals,
        0x1D300...0x1D35F => .TaiXuanJingSymbols,
        0x1D360...0x1D37F => .CountingRodNumerals,
        0x1D400...0x1D7FF => .MathematicalAlphanumericSymbols,
        0x1D800...0x1DAAF => .SuttonSignWriting,
        0x1E000...0x1E02F => .GlagoliticSupplement,
        0x1E100...0x1E14F => .NyiakengPuachueHmong,
        0x1E2C0...0x1E2FF => .Wancho,
        0x1E800...0x1E8DF => .MendeKikakui,
        0x1E900...0x1E95F => .Adlam,
        0x1EC70...0x1ECBF => .IndicSiyaqNumbers,
        0x1ED00...0x1ED4F => .OttomanSiyaqNumbers,
        0x1EE00...0x1EEFF => .ArabicMathematicalAlphabeticSymbols,
        0x1F000...0x1F02F => .MahjongTiles,
        0x1F030...0x1F09F => .DominoTiles,
        0x1F0A0...0x1F0FF => .PlayingCards,
        0x1F100...0x1F1FF => .EnclosedAlphanumericSupplement,
        0x1F200...0x1F2FF => .EnclosedIdeographicSupplement,
        0x1F300...0x1F5FF => .MiscellaneousSymbolsAndPictographs,
        0x1F600...0x1F64F => .Emoticons,
        0x1F650...0x1F67F => .OrnamentalDingbats,
        0x1F680...0x1F6FF => .TransportAndMapSymbols,
        0x1F700...0x1F77F => .AlchemicalSymbols,
        0x1F780...0x1F7FF => .GeometricShapesExtended,
        0x1F800...0x1F8FF => .SupplementalArrowsC,
        0x1F900...0x1F9FF => .SupplementalSymbolsAndPictographs,
        0x1FA00...0x1FA6F => .ChessSymbols,
        0x1FA70...0x1FAFF => .SymbolsAndPictographsExtendedA,
        0x20000...0x2A6DF => .CJKUnifiedIdeographsExtensionB,
        0x2A700...0x2B73F => .CJKUnifiedIdeographsExtensionC,
        0x2B740...0x2B81F => .CJKUnifiedIdeographsExtensionD,
        0x2B820...0x2CEAF => .CJKUnifiedIdeographsExtensionE,
        0x2CEB0...0x2EBEF => .CJKUnifiedIdeographsExtensionF,
        0x2F800...0x2FA1F => .CJKCompatibilityIdeographsSupplement,
        0xE0000...0xE007F => .Tags,
        0xE0100...0xE01EF => .VariationSelectorsSupplement,
        0xF0000...0xFFFFF => .SupplementaryPrivateUseAreaA,
        0x100000...0x10FFFF => .SupplementaryPrivateUseAreaB,
        else => error.InvalidUtf8
    };
}

// TODO: More complete tests
test "codepoint to utf-8 block" {
    comptime try testCodePointToUtf8Block();
    try testCodePointToUtf8Block();
}

fn testCodePointToUtf8Block() !void {
    // Basic Latin block
    assert((try utf8BlockForCodepoint('%')) == .BasicLatin);
    assert((try utf8BlockForCodepoint('^')) == .BasicLatin);
    assert((try utf8BlockForCodepoint(' ')) == .BasicLatin);

    // Emoticons block
    assert((try utf8BlockForCodepoint('😀')) == .Emoticons);

    // Supplemental Symbols and Pictographs block
    assert((try utf8BlockForCodepoint('🦎')) == .SupplementalSymbolsAndPictographs);
}