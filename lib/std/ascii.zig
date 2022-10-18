//! The 7-bit [ASCII](https://en.wikipedia.org/wiki/ASCII) character encoding standard.
//!
//! This is not to be confused with the 8-bit [extended ASCII](https://en.wikipedia.org/wiki/Extended_ASCII) character encoding.
//!
//! Even though this module concerns itself with 7-bit ASCII,
//! functions use `u8` as the type instead of `u7` for convenience and compatibility.
//! Characters outside of the 7-bit range are gracefully handled (e.g. by returning `false`).
//!
//! See also: https://en.wikipedia.org/wiki/ASCII#Character_set

const std = @import("std");

// TODO: remove all decls marked as DEPRECATED after 0.10.0's release

/// The C0 control codes of the ASCII encoding.
///
/// See also: https://en.wikipedia.org/wiki/C0_and_C1_control_codes and `isControl`.
pub const control_code = struct {
    // DEPRECATED: use the lowercase variant
    pub const NUL = 0x00;
    // DEPRECATED: use the lowercase variant
    pub const SOH = 0x01;
    // DEPRECATED: use the lowercase variant
    pub const STX = 0x02;
    // DEPRECATED: use the lowercase variant
    pub const ETX = 0x03;
    // DEPRECATED: use the lowercase variant
    pub const EOT = 0x04;
    // DEPRECATED: use the lowercase variant
    pub const ENQ = 0x05;
    // DEPRECATED: use the lowercase variant
    pub const ACK = 0x06;
    // DEPRECATED: use the lowercase variant
    pub const BEL = 0x07;
    // DEPRECATED: use the lowercase variant
    pub const BS = 0x08;
    // DEPRECATED: use `ht`
    pub const TAB = 0x09;
    // DEPRECATED: use the lowercase variant
    pub const LF = 0x0A;
    // DEPRECATED: use the lowercase variant
    pub const VT = 0x0B;
    // DEPRECATED: use the lowercase variant
    pub const FF = 0x0C;
    // DEPRECATED: use the lowercase variant
    pub const CR = 0x0D;
    // DEPRECATED: use the lowercase variant
    pub const SO = 0x0E;
    // DEPRECATED: use the lowercase variant
    pub const SI = 0x0F;
    // DEPRECATED: use the lowercase variant
    pub const DLE = 0x10;
    // DEPRECATED: use the lowercase variant
    pub const DC1 = 0x11;
    // DEPRECATED: use the lowercase variant
    pub const DC2 = 0x12;
    // DEPRECATED: use the lowercase variant
    pub const DC3 = 0x13;
    // DEPRECATED: use the lowercase variant
    pub const DC4 = 0x14;
    // DEPRECATED: use the lowercase variant
    pub const NAK = 0x15;
    // DEPRECATED: use the lowercase variant
    pub const SYN = 0x16;
    // DEPRECATED: use the lowercase variant
    pub const ETB = 0x17;
    // DEPRECATED: use the lowercase variant
    pub const CAN = 0x18;
    // DEPRECATED: use the lowercase variant
    pub const EM = 0x19;
    // DEPRECATED: use the lowercase variant
    pub const SUB = 0x1A;
    // DEPRECATED: use the lowercase variant
    pub const ESC = 0x1B;
    // DEPRECATED: use the lowercase variant
    pub const FS = 0x1C;
    // DEPRECATED: use the lowercase variant
    pub const GS = 0x1D;
    // DEPRECATED: use the lowercase variant
    pub const RS = 0x1E;
    // DEPRECATED: use the lowercase variant
    pub const US = 0x1F;
    // DEPRECATED: use the lowercase variant
    pub const DEL = 0x7F;
    // DEPRECATED: use the lowercase variant
    pub const XON = 0x11;
    // DEPRECATED: use the lowercase variant
    pub const XOFF = 0x13;

    /// Null.
    pub const nul = 0x00;
    /// Start of Heading.
    pub const soh = 0x01;
    /// Start of Text.
    pub const stx = 0x02;
    /// End of Text.
    pub const etx = 0x03;
    /// End of Transmission.
    pub const eot = 0x04;
    /// Enquiry.
    pub const enq = 0x05;
    /// Acknowledge.
    pub const ack = 0x06;
    /// Bell, Alert.
    pub const bel = 0x07;
    /// Backspace.
    pub const bs = 0x08;
    /// Horizontal Tab, Tab ('\t').
    pub const ht = 0x09;
    /// Line Feed, Newline ('\n').
    pub const lf = 0x0A;
    /// Vertical Tab.
    pub const vt = 0x0B;
    /// Form Feed.
    pub const ff = 0x0C;
    /// Carriage Return ('\r').
    pub const cr = 0x0D;
    /// Shift Out.
    pub const so = 0x0E;
    /// Shift In.
    pub const si = 0x0F;
    /// Data Link Escape.
    pub const dle = 0x10;
    /// Device Control One (XON).
    pub const dc1 = 0x11;
    /// Device Control Two.
    pub const dc2 = 0x12;
    /// Device Control Three (XOFF).
    pub const dc3 = 0x13;
    /// Device Control Four.
    pub const dc4 = 0x14;
    /// Negative Acknowledge.
    pub const nak = 0x15;
    /// Synchronous Idle.
    pub const syn = 0x16;
    /// End of Transmission Block
    pub const etb = 0x17;
    /// Cancel.
    pub const can = 0x18;
    /// End of Medium.
    pub const em = 0x19;
    /// Substitute.
    pub const sub = 0x1A;
    /// Escape.
    pub const esc = 0x1B;
    /// File Separator.
    pub const fs = 0x1C;
    /// Group Separator.
    pub const gs = 0x1D;
    /// Record Separator.
    pub const rs = 0x1E;
    /// Unit Separator.
    pub const us = 0x1F;

    /// Delete.
    pub const del = 0x7F;

    /// An alias to `dc1`.
    pub const xon = dc1;
    /// An alias to `dc3`.
    pub const xoff = dc3;
};

const tIndex = enum(u3) {
    Alpha,
    Hex,
    Space,
    Digit,
    Lower,
    Upper,
    // Ctrl, < 0x20 || == DEL
    // Print, = Graph || == ' '. NOT '\t' et cetera
    Punct,
    Graph,
    //ASCII, | ~0b01111111
    //isBlank, == ' ' || == '\x09'
};

const combinedTable = init: {
    comptime var table: [256]u8 = undefined;

    const mem = std.mem;

    const alpha = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
    };
    const lower = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
    };
    const upper = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const digit = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,

        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const hex = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0,

        0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const space = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const punct = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,

        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0,
    };
    const graph = [_]u1{
        //  0, 1, 2, 3, 4, 5, 6, 7 ,8, 9,10,11,12,13,14,15
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,

        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    };

    comptime var i = 0;
    inline while (i < 128) : (i += 1) {
        table[i] =
            @as(u8, alpha[i]) << @enumToInt(tIndex.Alpha) |
            @as(u8, hex[i]) << @enumToInt(tIndex.Hex) |
            @as(u8, space[i]) << @enumToInt(tIndex.Space) |
            @as(u8, digit[i]) << @enumToInt(tIndex.Digit) |
            @as(u8, lower[i]) << @enumToInt(tIndex.Lower) |
            @as(u8, upper[i]) << @enumToInt(tIndex.Upper) |
            @as(u8, punct[i]) << @enumToInt(tIndex.Punct) |
            @as(u8, graph[i]) << @enumToInt(tIndex.Graph);
    }
    mem.set(u8, table[128..256], 0);
    break :init table;
};

fn inTable(c: u8, t: tIndex) bool {
    return (combinedTable[c] & (@as(u8, 1) << @enumToInt(t))) != 0;
}

/// DEPRECATED: use `isAlphanumeric`
pub const isAlNum = isAlphanumeric;
/// DEPRECATED: use `isAlpha`
pub const isAlpha = isAlphabetic;
/// DEPRECATED: use `isAlpha`
pub const isCntrl = isControl;
/// DEPRECATED: use `isWhitespace`.
pub const isSpace = isWhitespace;
/// DEPRECATED: use `whitespace`.
pub const spaces = whitespace;
/// DEPRECATED: use `isHex`.
pub const isXDigit = isHex;

/// Returns whether the character is alphanumeric.
pub fn isAlphanumeric(c: u8) bool {
    return (combinedTable[c] & ((@as(u8, 1) << @enumToInt(tIndex.Alpha)) |
        @as(u8, 1) << @enumToInt(tIndex.Digit))) != 0;
}

/// Returns whether the character is alphabetic.
pub fn isAlphabetic(c: u8) bool {
    return inTable(c, tIndex.Alpha);
}

/// Returns whether the character is a control character.
/// This is the same as `!isPrint(c)`.
///
/// See also: `control_code`.
pub fn isControl(c: u8) bool {
    return c <= control_code.us or c == control_code.del;
}

/// Returns whether the character is a digit.
pub fn isDigit(c: u8) bool {
    return inTable(c, tIndex.Digit);
}

/// DEPRECATED: use `isPrint(c) and c != ' '` instead
pub fn isGraph(c: u8) bool {
    return inTable(c, tIndex.Graph);
}

/// Returns whether the character is a lowercased letter.
pub fn isLower(c: u8) bool {
    return inTable(c, tIndex.Lower);
}

/// Returns whether the character has some graphical representation and can be printed.
/// This also returns `true` for the space character.
/// This is the same as `!isControl(c)`.
pub fn isPrint(c: u8) bool {
    return inTable(c, tIndex.Graph) or c == ' ';
}

/// DEPRECATED: create your own function based on your needs and what you want to do.
pub fn isPunct(c: u8) bool {
    return inTable(c, tIndex.Punct);
}

/// Returns whether this character is included in `whitespace`.
pub fn isWhitespace(c: u8) bool {
    return inTable(c, tIndex.Space);
}

/// Whitespace for general use.
/// This may be used with e.g. `std.mem.trim` to trim whitespace.
///
/// See also: `isWhitespace`.
pub const whitespace = [_]u8{ ' ', '\t', '\n', '\r', control_code.vt, control_code.ff };

test "whitespace" {
    for (whitespace) |char| try std.testing.expect(isWhitespace(char));

    var i: u8 = 0;
    while (isASCII(i)) : (i += 1) {
        if (isWhitespace(i)) try std.testing.expect(std.mem.indexOfScalar(u8, &whitespace, i) != null);
    }
}

/// Returns whether the character is an uppercased letter.
pub fn isUpper(c: u8) bool {
    return inTable(c, tIndex.Upper);
}

/// Returns whether the character is a hexadecimal digit. This is case-insensitive.
pub fn isHex(c: u8) bool {
    return inTable(c, tIndex.Hex);
}

/// Returns whether the character is a 7-bit ASCII character.
pub fn isASCII(c: u8) bool {
    return c < 128;
}

/// DEPRECATED: use `c == ' ' or c == '\t'` or try `isWhitespace`
pub fn isBlank(c: u8) bool {
    return (c == ' ') or (c == '\x09');
}

/// Uppercases the character and returns it as-is if it's already uppercased or not a letter.
pub fn toUpper(c: u8) u8 {
    if (isLower(c)) {
        return c & 0b11011111;
    } else {
        return c;
    }
}

/// Lowercases the character and returns it as-is if it's already lowercased or not a letter.
pub fn toLower(c: u8) u8 {
    if (isUpper(c)) {
        return c | 0b00100000;
    } else {
        return c;
    }
}

test "ascii character classes" {
    const testing = std.testing;

    try testing.expect(!isControl('a'));
    try testing.expect(!isControl('z'));
    try testing.expect(isControl(control_code.nul));
    try testing.expect(isControl(control_code.ff));
    try testing.expect(isControl(control_code.us));

    try testing.expect('C' == toUpper('c'));
    try testing.expect(':' == toUpper(':'));
    try testing.expect('\xab' == toUpper('\xab'));
    try testing.expect(!isUpper('z'));

    try testing.expect('c' == toLower('C'));
    try testing.expect(':' == toLower(':'));
    try testing.expect('\xab' == toLower('\xab'));
    try testing.expect(!isLower('Z'));

    try testing.expect(isAlphanumeric('Z'));
    try testing.expect(isAlphanumeric('z'));
    try testing.expect(isAlphanumeric('5'));
    try testing.expect(isAlphanumeric('5'));
    try testing.expect(!isAlphanumeric('!'));

    try testing.expect(!isAlpha('5'));
    try testing.expect(isAlpha('c'));
    try testing.expect(!isAlpha('5'));

    try testing.expect(isWhitespace(' '));
    try testing.expect(isWhitespace('\t'));
    try testing.expect(isWhitespace('\r'));
    try testing.expect(isWhitespace('\n'));
    try testing.expect(!isWhitespace('.'));

    try testing.expect(!isHex('g'));
    try testing.expect(isHex('b'));
    try testing.expect(isHex('9'));

    try testing.expect(!isDigit('~'));
    try testing.expect(isDigit('0'));
    try testing.expect(isDigit('9'));

    try testing.expect(isPrint(' '));
    try testing.expect(isPrint('@'));
    try testing.expect(isPrint('~'));
    try testing.expect(!isPrint(control_code.esc));
}

/// Writes a lower case copy of `ascii_string` to `output`.
/// Asserts `output.len >= ascii_string.len`.
pub fn lowerString(output: []u8, ascii_string: []const u8) []u8 {
    std.debug.assert(output.len >= ascii_string.len);
    for (ascii_string) |c, i| {
        output[i] = toLower(c);
    }
    return output[0..ascii_string.len];
}

test "lowerString" {
    var buf: [1024]u8 = undefined;
    const result = lowerString(&buf, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    try std.testing.expectEqualStrings("abcdefghijklmnopqrst0234+💩!", result);
}

/// Allocates a lower case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocLowerString(allocator: std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    return lowerString(result, ascii_string);
}

test "allocLowerString" {
    const result = try allocLowerString(std.testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("abcdefghijklmnopqrst0234+💩!", result);
}

/// Writes an upper case copy of `ascii_string` to `output`.
/// Asserts `output.len >= ascii_string.len`.
pub fn upperString(output: []u8, ascii_string: []const u8) []u8 {
    std.debug.assert(output.len >= ascii_string.len);
    for (ascii_string) |c, i| {
        output[i] = toUpper(c);
    }
    return output[0..ascii_string.len];
}

test "upperString" {
    var buf: [1024]u8 = undefined;
    const result = upperString(&buf, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRST0234+💩!", result);
}

/// Allocates an upper case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocUpperString(allocator: std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    return upperString(result, ascii_string);
}

test "allocUpperString" {
    const result = try allocUpperString(std.testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRST0234+💩!", result);
}

/// Compares strings `a` and `b` case-insensitively and returns whether they are equal.
pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a) |a_c, i| {
        if (toLower(a_c) != toLower(b[i])) return false;
    }
    return true;
}

test "eqlIgnoreCase" {
    try std.testing.expect(eqlIgnoreCase("HEl💩Lo!", "hel💩lo!"));
    try std.testing.expect(!eqlIgnoreCase("hElLo!", "hello! "));
    try std.testing.expect(!eqlIgnoreCase("hElLo!", "helro!"));
}

pub fn startsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[0..needle.len], needle);
}

test "ascii.startsWithIgnoreCase" {
    try std.testing.expect(startsWithIgnoreCase("boB", "Bo"));
    try std.testing.expect(!startsWithIgnoreCase("Needle in hAyStAcK", "haystack"));
}

pub fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[haystack.len - needle.len ..], needle);
}

test "ascii.endsWithIgnoreCase" {
    try std.testing.expect(endsWithIgnoreCase("Needle in HaYsTaCk", "haystack"));
    try std.testing.expect(!endsWithIgnoreCase("BoB", "Bo"));
}

/// Finds `needle` in `haystack`, ignoring case, starting at index 0.
pub fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) ?usize {
    return indexOfIgnoreCasePos(haystack, 0, needle);
}

/// Finds `needle` in `haystack`, ignoring case, starting at `start_index`.
/// Uses Boyer-Moore-Horspool algorithm on large inputs; `indexOfIgnoreCasePosLinear` on small inputs.
pub fn indexOfIgnoreCasePos(haystack: []const u8, start_index: usize, needle: []const u8) ?usize {
    if (needle.len > haystack.len) return null;
    if (needle.len == 0) return start_index;

    if (haystack.len < 52 or needle.len <= 4)
        return indexOfIgnoreCasePosLinear(haystack, start_index, needle);

    var skip_table: [256]usize = undefined;
    boyerMooreHorspoolPreprocessIgnoreCase(needle, skip_table[0..]);

    var i: usize = start_index;
    while (i <= haystack.len - needle.len) {
        if (eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return i;
        i += skip_table[toLower(haystack[i + needle.len - 1])];
    }

    return null;
}

/// Consider using `indexOfIgnoreCasePos` instead of this, which will automatically use a
/// more sophisticated algorithm on larger inputs.
pub fn indexOfIgnoreCasePosLinear(haystack: []const u8, start_index: usize, needle: []const u8) ?usize {
    var i: usize = start_index;
    const end = haystack.len - needle.len;
    while (i <= end) : (i += 1) {
        if (eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}

fn boyerMooreHorspoolPreprocessIgnoreCase(pattern: []const u8, table: *[256]usize) void {
    for (table) |*c| {
        c.* = pattern.len;
    }

    var i: usize = 0;
    // The last item is intentionally ignored and the skip size will be pattern.len.
    // This is the standard way Boyer-Moore-Horspool is implemented.
    while (i < pattern.len - 1) : (i += 1) {
        table[toLower(pattern[i])] = pattern.len - 1 - i;
    }
}

test "indexOfIgnoreCase" {
    try std.testing.expect(indexOfIgnoreCase("one Two Three Four", "foUr").? == 14);
    try std.testing.expect(indexOfIgnoreCase("one two three FouR", "gOur") == null);
    try std.testing.expect(indexOfIgnoreCase("foO", "Foo").? == 0);
    try std.testing.expect(indexOfIgnoreCase("foo", "fool") == null);
    try std.testing.expect(indexOfIgnoreCase("FOO foo", "fOo").? == 0);

    try std.testing.expect(indexOfIgnoreCase("one two three four five six seven eight nine ten eleven", "ThReE fOUr").? == 8);
    try std.testing.expect(indexOfIgnoreCase("one two three four five six seven eight nine ten eleven", "Two tWo") == null);
}

/// Returns the lexicographical order of two slices. O(n).
pub fn orderIgnoreCase(lhs: []const u8, rhs: []const u8) std.math.Order {
    const n = std.math.min(lhs.len, rhs.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        switch (std.math.order(toLower(lhs[i]), toLower(rhs[i]))) {
            .eq => continue,
            .lt => return .lt,
            .gt => return .gt,
        }
    }
    return std.math.order(lhs.len, rhs.len);
}

/// Returns whether the lexicographical order of `lhs` is lower than `rhs`.
pub fn lessThanIgnoreCase(lhs: []const u8, rhs: []const u8) bool {
    return orderIgnoreCase(lhs, rhs) == .lt;
}
