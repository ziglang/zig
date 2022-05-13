//! The 7-bit [ASCII](https://en.wikipedia.org/wiki/ASCII) character encoding standard.
//!
//! This is not to be confused with the 8-bit [Extended ASCII](https://en.wikipedia.org/wiki/Extended_ASCII).
//!
//! Even though this module concerns itself with 7-bit ASCII,
//! functions use `u8` as the type instead of `u7` for convenience and compatibility.
//! Characters outside of the 7-bit range are gracefully handled (e.g. by returning `false`).
//!
//! See also: https://en.wikipedia.org/wiki/ASCII#Character_set

const std = @import("std");
const testing = std.testing;

/// Contains constants for the C0 control codes of the ASCII encoding.
///
/// See also: https://en.wikipedia.org/wiki/C0_and_C1_control_codes and `is_control`
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

    /// An alias to `DC1`.
    pub const XON = 0x11;
    /// An alias to `DC3`.
    pub const XOFF = 0x13;
};

// These naive functions are used to generate the lookup table
// and they're used as fallbacks for if the lookup table isn't available.
//
// Note that some functions like for example `isDigit` don't use a table because it's slower.
// Using a table is generally only useful if not all `true` values in the table would be in one row.

fn isCntrlNaive(c: u8) bool {
    return c <= control_code.US or c == control_code.DEL;
}
fn isAlphaNaive(c: u8) bool {
    return isLower(c) or isUpper(c);
}
fn isXDigitNaive(c: u8) bool {
    return isDigit(c) or
        (c >= 'a' and c <= 'f') or
        (c >= 'A' and c <= 'F');
}
fn isAlNumNaive(c: u8) bool {
    return isDigit(c) or isAlphaNaive(c);
}
fn isPunctNaive(c: u8) bool {
    @setEvalBranchQuota(3000);
    return (c >= '!' and c <= '/') or
        (c >= '[' and c <= '`') or
        (c >= '{' and c <= '~') or
        (c >= ':' and c <= '@');
}
fn isSpaceNaive(c: u8) bool {
    @setEvalBranchQuota(5000);
    return std.mem.indexOfScalar(u8, &spaces, c) != null;
}

/// A lookup table.
const CombinedTable = struct {
    table: [256]u8,

    const Index = enum {
        control,
        alphabetic,
        hexadecimal,
        alphanumeric,
        punct,
        spaces,
    };

    /// Generates a table which is filled with the results of the given function for all characters.
    fn getBoolTable(comptime condition: fn (u8) bool) [128]bool {
        @setEvalBranchQuota(2000);
        comptime var table: [128]bool = undefined;
        comptime var index = 0;
        while (index < 128) : (index += 1) {
            table[index] = condition(index);
        }
        return table;
    }

    fn init() CombinedTable {
        comptime var table: [256]u8 = undefined;

        const control_table = comptime getBoolTable(isCntrlNaive);
        const alpha_table = comptime getBoolTable(isAlphaNaive);
        const hex_table = comptime getBoolTable(isXDigitNaive);
        const alphanumeric_table = comptime getBoolTable(isAlNumNaive);
        const punct_table = comptime getBoolTable(isPunctNaive);
        const whitespace_table = comptime getBoolTable(isSpaceNaive);

        comptime var i = 0;
        inline while (i < 128) : (i += 1) {
            table[i] =
                @boolToInt(control_table[i]) << @enumToInt(Index.control) |
                @boolToInt(alpha_table[i]) << @enumToInt(Index.alphabetic) |
                @boolToInt(hex_table[i]) << @enumToInt(Index.hexadecimal) |
                @boolToInt(alphanumeric_table[i]) << @enumToInt(Index.alphanumeric) |
                @boolToInt(punct_table[i]) << @enumToInt(Index.punct) |
                @boolToInt(whitespace_table[i]) << @enumToInt(Index.spaces);
        }

        std.mem.set(u8, table[128..256], 0);

        return .{ .table = table };
    }

    fn contains(self: CombinedTable, c: u8, index: Index) bool {
        return (self.table[c] & (@as(u8, 1) << @enumToInt(index))) != 0;
    }
};

/// The combined table for fast lookup.
///
/// This is not used in `ReleaseSmall` to save 256 bytes at the cost of
/// a small decrease in performance.
const combined_table: ?CombinedTable = if (@import("builtin").mode == .ReleaseSmall)
    null
else
    CombinedTable.init();

/// Returns whether the character is alphanumeric. This is case-insensitive.
pub fn isAlNum(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .alphanumeric)
    else
        return isAlNumNaive(c);
}

/// Returns whether the character is alphabetic. This is case-insensitive.
pub fn isAlpha(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .alphabetic)
    else
        return isAlphaNaive(c);
}

/// Returns whether the character is a control character.
///
/// See also: `control`
pub fn isCntrl(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .control)
    else
        return isCntrlNaive(c);
}

pub fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

pub fn isGraph(c: u8) bool {
    return isPrint(c) and c != ' ';
}

pub fn isLower(c: u8) bool {
    return c >= 'a' and c <= 'z';
}

/// Returns whether the character has some graphical representation and can be printed.
pub fn isPrint(c: u8) bool {
    return c >= ' ' and c <= '~';
}

pub fn isPunct(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .punct)
    else
        return isPunctNaive(c);
}

pub fn isSpace(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .spaces)
    else
        return isSpaceNaive(c);
}

/// All the values for which `isSpace()` returns `true`.
/// This may be used with e.g. `std.mem.trim()` to trim spaces.
pub const spaces = [_]u8{ ' ', '\t', '\n', '\r', control_code.VT, control_code.FF };

test "spaces" {
    for (spaces) |space| try testing.expect(isSpace(space));

    var i: u8 = 0;
    while (isASCII(i)) : (i += 1) {
        if (isSpace(i)) try testing.expect(std.mem.indexOfScalar(u8, &spaces, i) != null);
    }
}

pub fn isUpper(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}

/// Returns whether the character is a hexadecimal digit. This is case-insensitive.
pub fn isXDigit(c: u8) bool {
    if (combined_table) |table|
        return table.contains(c, .hexadecimal)
    else
        return isXDigitNaive(c);
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
    try testing.expect(!isCntrl('a'));
    try testing.expect(!isCntrl('z'));
    try testing.expect(isCntrl(control_code.NUL));
    try testing.expect(isCntrl(control_code.FF));
    try testing.expect(isCntrl(control_code.US));

    try testing.expect('C' == toUpper('c'));
    try testing.expect(':' == toUpper(':'));
    try testing.expect('\xab' == toUpper('\xab'));
    try testing.expect(!isUpper('z'));

    try testing.expect('c' == toLower('C'));
    try testing.expect(':' == toLower(':'));
    try testing.expect('\xab' == toLower('\xab'));
    try testing.expect(!isLower('Z'));

    try testing.expect(isAlNum('Z'));
    try testing.expect(isAlNum('z'));
    try testing.expect(isAlNum('5'));
    try testing.expect(isAlNum('5'));
    try testing.expect(!isAlNum('!'));

    try testing.expect(!isAlpha('5'));
    try testing.expect(isAlpha('c'));
    try testing.expect(!isAlpha('5'));

    try testing.expect(isSpace(' '));
    try testing.expect(isSpace('\t'));
    try testing.expect(isSpace('\r'));
    try testing.expect(isSpace('\n'));
    try testing.expect(!isSpace('.'));

    try testing.expect(!isXDigit('g'));
    try testing.expect(isXDigit('b'));
    try testing.expect(isXDigit('9'));

    try testing.expect(!isDigit('~'));
    try testing.expect(isDigit('0'));
    try testing.expect(isDigit('9'));

    try testing.expect(isPrint(' '));
    try testing.expect(isPrint('@'));
    try testing.expect(isPrint('~'));
    try testing.expect(!isPrint(control_code.ESC));
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
    try testing.expectEqualStrings("abcdefghijklmnopqrst0234+💩!", result);
}

/// Allocates a lower case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocLowerString(allocator: std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    return lowerString(result, ascii_string);
}

test "allocLowerString" {
    const result = try allocLowerString(testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("abcdefghijklmnopqrst0234+💩!", result);
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
    try testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRST0234+💩!", result);
}

/// Allocates an upper case copy of `ascii_string`.
/// Caller owns returned string and must free with `allocator`.
pub fn allocUpperString(allocator: std.mem.Allocator, ascii_string: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, ascii_string.len);
    return upperString(result, ascii_string);
}

test "allocUpperString" {
    const result = try allocUpperString(testing.allocator, "aBcDeFgHiJkLmNOPqrst0234+💩!");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ABCDEFGHIJKLMNOPQRST0234+💩!", result);
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
    try testing.expect(eqlIgnoreCase("HEl💩Lo!", "hel💩lo!"));
    try testing.expect(!eqlIgnoreCase("hElLo!", "hello! "));
    try testing.expect(!eqlIgnoreCase("hElLo!", "helro!"));
}

pub fn startsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[0..needle.len], needle);
}

test "ascii.startsWithIgnoreCase" {
    try testing.expect(startsWithIgnoreCase("boB", "Bo"));
    try testing.expect(!startsWithIgnoreCase("Needle in hAyStAcK", "haystack"));
}

pub fn endsWithIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else eqlIgnoreCase(haystack[haystack.len - needle.len ..], needle);
}

test "ascii.endsWithIgnoreCase" {
    try testing.expect(endsWithIgnoreCase("Needle in HaYsTaCk", "haystack"));
    try testing.expect(!endsWithIgnoreCase("BoB", "Bo"));
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
    try testing.expect(indexOfIgnoreCase("one Two Three Four", "foUr").? == 14);
    try testing.expect(indexOfIgnoreCase("one two three FouR", "gOur") == null);
    try testing.expect(indexOfIgnoreCase("foO", "Foo").? == 0);
    try testing.expect(indexOfIgnoreCase("foo", "fool") == null);
    try testing.expect(indexOfIgnoreCase("FOO foo", "fOo").? == 0);
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

/// Returns whether lhs < rhs.
pub fn lessThanIgnoreCase(lhs: []const u8, rhs: []const u8) bool {
    return orderIgnoreCase(lhs, rhs) == .lt;
}
