// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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
    pub const NUL = 0x00;
    pub const SOH = 0x01;
    pub const STX = 0x02;
    pub const ETX = 0x03;
    pub const EOT = 0x04;
    pub const ENQ = 0x05;
    pub const ACK = 0x06;
    pub const BEL = 0x07;
    pub const BS = 0x08;
    pub const TAB = 0x09;
    pub const LF = 0x0A;
    pub const VT = 0x0B;
    pub const FF = 0x0C;
    pub const CR = 0x0D;
    pub const SO = 0x0E;
    pub const SI = 0x0F;
    pub const DLE = 0x10;
    pub const DC1 = 0x11;
    pub const DC2 = 0x12;
    pub const DC3 = 0x13;
    pub const DC4 = 0x14;
    pub const NAK = 0x15;
    pub const SYN = 0x16;
    pub const ETB = 0x17;
    pub const CAN = 0x18;
    pub const EM = 0x19;
    pub const SUB = 0x1A;
    pub const ESC = 0x1B;
    pub const FS = 0x1C;
    pub const GS = 0x1D;
    pub const RS = 0x1E;
    pub const US = 0x1F;

    pub const DEL = 0x7F;

    pub const XON = 0x11;
    pub const XOFF = 0x13;
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
    return c < 0x20 or c == 127; //DEL
}

pub fn isDigit(c: u8) bool {
    return inTable(c, tIndex.Digit);
}

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
    for (spaces) |space| testing.expect(isSpace(space));

    var i: u8 = 0;
    while (isASCII(i)) : (i += 1) {
        if (isSpace(i)) testing.expect(std.mem.indexOfScalar(u8, &spaces, i) != null);
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

    testing.expect('C' == toUpper('c'));
    testing.expect(':' == toUpper(':'));
    testing.expect('\xab' == toUpper('\xab'));
    testing.expect('c' == toLower('C'));
    testing.expect(isAlpha('c'));
    testing.expect(!isAlpha('5'));
    testing.expect(isSpace(' '));
}

/// Allocates a lower case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocLowerString(allocator: *std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    for (result) |*c, i| {
        c.* = toLower(ascii_string[i]);
    }
    return result;
}

test "allocLowerString" {
    const result = try allocLowerString(std.testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer std.testing.allocator.free(result);
    std.testing.expect(std.mem.eql(u8, "abcdefghijklmnopqrst0234+💩!", result));
}

/// Allocates an upper case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocUpperString(allocator: *std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    for (result) |*c, i| {
        c.* = toUpper(ascii_string[i]);
    }
    return result;
}

test "allocUpperString" {
    const result = try allocUpperString(std.testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer std.testing.allocator.free(result);
    std.testing.expect(std.mem.eql(u8, "ABCDEFGHIJKLMNOPQRST0234+💩!", result));
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
    std.testing.expect(eqlIgnoreCase("HEl💩Lo!", "hel💩lo!"));
    std.testing.expect(!eqlIgnoreCase("hElLo!", "hello! "));
    std.testing.expect(!eqlIgnoreCase("hElLo!", "helro!"));
}

pub fn startsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[0..needle.len], needle);
}

test "ascii.startsWithIgnoreCase" {
    std.testing.expect(startsWithIgnoreCase("boB", "Bo"));
    std.testing.expect(!startsWithIgnoreCase("Needle in hAyStAcK", "haystack"));
}

pub fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[haystack.len - needle.len ..], needle);
}

test "ascii.endsWithIgnoreCase" {
    std.testing.expect(endsWithIgnoreCase("Needle in HaYsTaCk", "haystack"));
    std.testing.expect(!endsWithIgnoreCase("BoB", "Bo"));
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
    std.testing.expect(indexOfIgnoreCase("one Two Three Four", "foUr").? == 14);
    std.testing.expect(indexOfIgnoreCase("one two three FouR", "gOur") == null);
    std.testing.expect(indexOfIgnoreCase("foO", "Foo").? == 0);
    std.testing.expect(indexOfIgnoreCase("foo", "fool") == null);

    std.testing.expect(indexOfIgnoreCase("FOO foo", "fOo").? == 0);
}
