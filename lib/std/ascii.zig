// Does NOT look at the locale the way C89's toupper(3), isspace() et cetera does.
// I could have taken only a u7 to make this clear, but it would be slower
// It is my opinion that encodings other than UTF-8 should not be supported.
//
// (and 128 bytes is not much to pay).
// Also does not handle Unicode character classes.
//
// https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/USASCII_code_chart.png/1200px-USASCII_code_chart.png

const std = @import("std");

/// Contains constants for the C0 control codes of the ASCII encoding.
/// https://en.wikipedia.org/wiki/C0_and_C1_control_codes
pub const control_code = struct {
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
    /// File separator.
    pub const fs = 0x1C;
    /// Group Separator.
    pub const gs = 0x1D;
    /// Record Separator.
    pub const rs = 0x1E;
    /// Unit separator.
    pub const us = 0x1F;
    /// Delete.
    pub const del = 0x7F;

    /// An alias to `dc1`.
    pub const xon = dc1;
    /// An alias to `dc3`.
    pub const xff = dc3;
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

pub fn isAlNum(c: u8) bool {
    return (combinedTable[c] & ((@as(u8, 1) << @enumToInt(tIndex.Alpha)) |
        @as(u8, 1) << @enumToInt(tIndex.Digit))) != 0;
}

pub fn isAlpha(c: u8) bool {
    return inTable(c, tIndex.Alpha);
}

pub fn isCntrl(c: u8) bool {
    return c <= control_code.us or c == control_code.del;
}

pub fn isDigit(c: u8) bool {
    return inTable(c, tIndex.Digit);
}

/// DEPRECATED: use `isPrint(c) and c != ' '` instead
pub fn isGraph(c: u8) bool {
    return inTable(c, tIndex.Graph);
}

pub fn isLower(c: u8) bool {
    return inTable(c, tIndex.Lower);
}

pub fn isPrint(c: u8) bool {
    return inTable(c, tIndex.Graph) or c == ' ';
}

pub fn isPunct(c: u8) bool {
    return inTable(c, tIndex.Punct);
}

pub fn isSpace(c: u8) bool {
    return inTable(c, tIndex.Space);
}

/// All the values for which isSpace() returns true. This may be used with
/// e.g. std.mem.trim() to trim whiteSpace.
pub const spaces = [_]u8{ ' ', '\t', '\n', '\r', control_code.VT, control_code.FF };

test "spaces" {
    const testing = std.testing;
    for (spaces) |space| try testing.expect(isSpace(space));

    var i: u8 = 0;
    while (isASCII(i)) : (i += 1) {
        if (isSpace(i)) try testing.expect(std.mem.indexOfScalar(u8, &spaces, i) != null);
    }
}

pub fn isUpper(c: u8) bool {
    return inTable(c, tIndex.Upper);
}

pub fn isXDigit(c: u8) bool {
    return inTable(c, tIndex.Hex);
}

pub fn isASCII(c: u8) bool {
    return c < 128;
}

/// DEPRECATED: use `c == ' ' or c == '\x09'` or try `isWhitespace`
pub fn isBlank(c: u8) bool {
    return (c == ' ') or (c == '\x09');
}

pub fn toUpper(c: u8) u8 {
    if (isLower(c)) {
        return c & 0b11011111;
    } else {
        return c;
    }
}

pub fn toLower(c: u8) u8 {
    if (isUpper(c)) {
        return c | 0b00100000;
    } else {
        return c;
    }
}

test "ascii character classes" {
    const testing = std.testing;

    try testing.expect('C' == toUpper('c'));
    try testing.expect(':' == toUpper(':'));
    try testing.expect('\xab' == toUpper('\xab'));
    try testing.expect('c' == toLower('C'));
    try testing.expect(isAlpha('c'));
    try testing.expect(!isAlpha('5'));
    try testing.expect(isSpace(' '));
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

/// Compares strings `a` and `b` case insensitively and returns whether they are equal.
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

/// Finds `substr` in `container`, ignoring case, starting at `start_index`.
/// TODO boyer-moore algorithm
pub fn indexOfIgnoreCasePos(container: []const u8, start_index: usize, substr: []const u8) ?usize {
    if (substr.len > container.len) return null;

    var i: usize = start_index;
    const end = container.len - substr.len;
    while (i <= end) : (i += 1) {
        if (eqlIgnoreCase(container[i .. i + substr.len], substr)) return i;
    }
    return null;
}

/// Finds `substr` in `container`, ignoring case, starting at index 0.
pub fn indexOfIgnoreCase(container: []const u8, substr: []const u8) ?usize {
    return indexOfIgnoreCasePos(container, 0, substr);
}

test "indexOfIgnoreCase" {
    try std.testing.expect(indexOfIgnoreCase("one Two Three Four", "foUr").? == 14);
    try std.testing.expect(indexOfIgnoreCase("one two three FouR", "gOur") == null);
    try std.testing.expect(indexOfIgnoreCase("foO", "Foo").? == 0);
    try std.testing.expect(indexOfIgnoreCase("foo", "fool") == null);

    try std.testing.expect(indexOfIgnoreCase("FOO foo", "fOo").? == 0);
}

/// Compares two slices of numbers lexicographically. O(n).
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

/// Returns true if lhs < rhs, false otherwise
/// TODO rename "IgnoreCase" to "Insensitive" in this entire file.
pub fn lessThanIgnoreCase(lhs: []const u8, rhs: []const u8) bool {
    return orderIgnoreCase(lhs, rhs) == .lt;
}
