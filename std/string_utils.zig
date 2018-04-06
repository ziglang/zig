const std = @import("index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const locale = std.locale;
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

pub const split_it = mem.split(locale.AsciiView, locale.AsciiIterator, []const u8);

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