const std = @import("index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const allocator = std.debug.debug_allocator;

// Handles a series of string utilities that are focused around handling and manipulating strings

// Hash code for a string
pub fn hash_str(k: []const u8) u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

// Just directs you to the standard string handler
pub fn hash_unicode(k: unicode.Utf8View) u32 {
    return hash_str(k.bytes);
}

pub fn find_str(a: []const u8, target: []const u8, start: usize, end: usize, highest: bool) ?usize {
    var array = a[start..end];
    var i : usize = 0;
    var index : ?usize = null;

    while (i < array.len) {
        // If there is no possible way we could fit the string early return
        if (array.len - i < target.len) return index;

        if (array[i] == target[0]) {
            var equal = true;
            var j : usize = 1;

            while (j < target.len) {
                if (array[i + j] != target[j]) {
                    equal = false;

                    // Reduce amount of comparisons
                    i += j - 1;
                    break;
                }
                j += 1;
            }

            if (equal) {
                index = i;
                if (!highest) {
                    return index;
                } else {
                    i += j - 1;
                }
            }
        }
        i += 1;
    }

    return index;
}

pub const Side = enum {
    LEFT,
    RIGHT,
    BOTH,
};

pub fn strip_whitespace(a: []const u8, sides: Side)[]const u8 {
    // Just a placeholder replace later with proper locale whitespace
    return strip(a, " \t\n\r", sides);
}

fn impl_strip_side(a: []const u8, characters: []const u8, start: usize, change: usize, decrement: bool) usize {
    var moved = true;
    var index = start;

    while (moved) {
        moved = false;
        for (characters) |char| {
            if (char == a[index]) {
                moved = true;
                if (decrement) index -= change else index += change;
                break;
            }
        }
    }
    return index;
}

// If max is 0 then it'll do forever
pub fn split(a: []const u8, sep: u8, out: &[][]const u8)void {
    var actualCount: usize = 0;
    var previousIndex: usize = 0;

    for (a) |char, i| {
        if (char == sep) {
            if (i - previousIndex == 0) {
                (*out)[actualCount] = "";
            } else {
                (*out)[actualCount] = a[previousIndex..i];
            }

            previousIndex = i + 1;
            actualCount += 1;

            if (actualCount == out.len) break;
        }
    }

    (*out)[actualCount] = a[previousIndex..];
    actualCount += 1;
    *out = (*out)[0..actualCount];
}

// Note: characters is an array of u8 not a string!
// So passing in "abc" doesn't strip abc it strips a, b, and c
pub fn strip(a: []const u8, characters: []const u8, sides: Side)[]const u8 {
    var start: usize = 0;
    var end: usize = a.len - 1;
    if (sides == Side.LEFT or sides == Side.BOTH) {
        // Trim left
        start = impl_strip_side(a, characters, start, 1, false);
    }

    if (sides == Side.RIGHT or sides == Side.BOTH) {
        // Trim right
        end = impl_strip_side(a, characters, end, 1, true);
    }

    // +1 to convert to 1-index
    return a[start..end + 1];
}

pub fn starts_with(a: []const u8, target: []const u8) bool {
    // Because we are 0-indexing it not 1-indexing it
    if (a.len < target.len) return false;
    var i : usize = 0;

    while (i < target.len) {
        if (a[i] != target[i]) return false;
        i += 1;
    }
    return true;
}

pub fn ends_with(a: []const u8, target: []const u8) bool {
    if (a.len < target.len) return false;
    var diff : usize = a.len - target.len;
    var i : usize = a.len - 1;

    while (i >= target.len) {
        if (a[i] != target[i - diff]) return false;
        i -= 1;
    }
    return true;
}

pub fn str_eql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

pub fn is_num(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

pub fn to_upper(byte: u8) u8 {
    return if(is_ascii_lower(byte)) byte - 32 else byte;
}

pub fn to_lower(byte: u8) u8 {
    return if(is_ascii_higher(byte)) byte + 32 else byte;
}

pub fn is_ascii_letter(byte: u8) bool {
    return is_ascii_lower(byte) or is_ascii_higher(byte);
}

pub fn is_ascii_lower(byte: u8) bool {
    return byte >= 'a' and byte <= 'z';
}

pub fn is_ascii_higher(byte: u8) bool {
    return byte >= 'A' and byte <= 'Z';
}

test "String_Utils" {
    assert(is_ascii_letter('C'));
    assert(is_ascii_letter('e'));
    assert(!is_ascii_letter('2'));
    assert(!is_ascii_higher('a'));
    assert(is_ascii_higher('B'));
    assert(!is_ascii_higher('5'));
    assert(is_ascii_lower('a'));
    assert(!is_ascii_lower('K'));
    assert(!is_ascii_lower('-'));

    assert(is_num('0'));
    assert(!is_num('a'));

    assert(str_eql("HOPE", "HOPE"));
    assert(!str_eql("Piece", "Peace"));

    assert(ends_with("Hopie", "pie"));
    assert(!ends_with("Cat", "ta"));

    assert(starts_with("bat", "ba"));
    assert(!starts_with("late", "ma"));

    assert(?? find_str("boo", "o", 0, 3, true) == 2);
    assert(?? find_str("nookies", "ook", 0, 7, false) == 1);
    assert(find_str("answer to the universe", "42", 0, 22, false) == null);

    assert(str_eql(strip_whitespace("    a    ", Side.BOTH), "a"));
    assert(str_eql(strip_whitespace(" a ", Side.LEFT), "a "));
    assert(str_eql(strip_whitespace(" a ", Side.RIGHT), " a"));
    
    assert(str_eql(strip("mississippi", "ipz", Side.BOTH), "mississ"));

    var splits : [3][]const u8 = undefined;
    split("Cat,Bat,Mat", ',', &splits[0..]);
    var expected = [][3]u8 { "Cat", "Bat", "Mat" };

    assert(expected.len == splits.len);
    for (expected) |str, i| {
        assert(str_eql(splits[i], str));
    }
}