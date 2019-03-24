const std = @import("std");//("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const fmt = std.fmt;
const unicode = std.unicode;

pub const ParseEscapeError = std.unicode.UnicodeError || error{
    ExpectXDigit,
    ExpectLCurly,
    ExpectRCurly,
};
inline fn parseEscape(escape_sequence: []const u8, ret_len: *u4) ParseEscapeError!u21 {
    var ret: u21 = undefined;
    var it = mem.byteIterator(escape_sequence);
    errdefer ret_len.* = @intCast(u4, it.i);
    got_escape: { switch (it.n()) {
    'x' => {
        var hi = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        var lo = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        ret_len.* = 3;
        return u21(((hi << 4) | lo));
    },
    'u' => {
        if (it.n() != '{') return error.ExpectLCurly;
        var hi = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        var lo = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        ret_len.* = 4;
        ret = (u21(hi) << 4) | u21(lo);
        hi = fmt.charToDigit(it.n(), 16) catch {
            if (it.n() != '}') return error.ExpectRCurly;
            ret_len.* = 5;
            break :got_escape;
        };
        lo = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        ret_len.* = 6;
        ret |= ((u21(hi) << 4) | u21(lo)) << 8;
        hi = fmt.charToDigit(it.n(), 16) catch {
            if (it.n() != '}') return error.ExpectRCurly;
            ret_len.* = 7;
            break :got_escape;
        };
        lo = fmt.charToDigit(it.n(), 16) catch return error.ExpectXDigit;
        ret_len.* = 8;
        ret |= ((u21(hi) << 4) | u21(lo)) << 16;
        if (it.n() != '}') return error.ExpectRCurly;
        ret_len.* = 9;
    },
    else => unreachable,
    }}
    unicode.isValidUnicode(ret) catch |err| return err;
    return ret;
}

pub const ParseCharLiteralError = ParseEscapeError || unicode.Utf8Error || error{
    ExpectSQuote,
};
pub fn parseCharLiteral(char_token: []const u8) ParseCharLiteralError!u21 {
    var char: u21 = undefined;
    if (char_token[1] == '\\') {
        var len: u4 = undefined;
        char = switch (char_token[2]) {
        'x', 'u' => try parseEscape(char_token[2..], &len),
        'n' => '\n',
        'r' => '\r',
        '\\' => '\\',
        '\t' => '\t',
        '\'' => '\'',
        '\"' => '\"',
        else => unreachable,
        };
        if (char_token[2 + len] != '}') return error.ExpectRCurly;
    }
    var len = try unicode.utf8Decode(char_token[1..], @ptrCast(*u32, &char)); // TODO: will this cast fail on Big-Endian?
    if (char_token[1 + len] != '\'') return error.ExpectSQuote;

    return char;
}

test "zig.parseCharLiteral" {
    const expect = std.testing.expect;
    expect(parseCharLiteral("\'0\'") catch unreachable == '0');
    expect(parseCharLiteral("\'\x20\'") catch unreachable == ' ');
}

const State = enum {
    Start,
    Backslash,
};

pub const ParseStringLiteralError = ParseEscapeError || error{
    OutOfMemory,
};

/// caller owns returned memory
pub fn parseStringLiteral(
    allocator: *std.mem.Allocator,
    bytes: []const u8,
    bad_index: *usize, // populated if error.InvalidCharacter is returned
) ParseStringLiteralError![]u8 {
    const first_index = if (bytes[0] == 'c') usize(2) else usize(1);
    assert(bytes[bytes.len - 1] == '"');

    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();

    const slice = bytes[first_index..];
    try list.ensureCapacity(slice.len - 1);

    var state = State.Start;
    var index: usize = 0;
    while (index < slice.len) : (index += 1) {
        var b = slice[index];
        switch (state) {
            State.Start => switch (b) {
                '\\' => state = State.Backslash,
                '\n' => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
                '"' => return list.toOwnedSlice(),
                else => try list.append(b),
            },
            State.Backslash => switch (b) {
                'x', 'u' => {
                    var encoded: [4]u8 = undefined;
                    var len: u3 = undefined;
                    bad_index.* = index;
                    len = unicode.utf8Encode(try parseEscape(bytes[2..], &len), encoded[0..]) catch unreachable;
                    try list.appendSlice(encoded[0..len]);
                    index += len;
                    state = State.Start;
                },
                'n' => {
                    try list.append('\n');
                    state = State.Start;
                },
                'r' => {
                    try list.append('\r');
                    state = State.Start;
                },
                '\\' => {
                    try list.append('\\');
                    state = State.Start;
                },
                't' => {
                    try list.append('\t');
                    state = State.Start;
                },
                '"' => {
                    try list.append('"');
                    state = State.Start;
                },
                '\'' => {
                    try list.append('\'');
                    state = State.Start;
                },
                else => {
                    bad_index.* = index;
                    return error.InvalidCharacter;
                },
            },
            else => unreachable,
        }
    }
    unreachable;
}
