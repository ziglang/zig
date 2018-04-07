const std = @import("index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const locale = std.locale;
const ascii = std.ascii;
const allocator = std.debug.debug_allocator;

// Handles a series of string utilities that are focused around handling and manipulating strings

// Hash code for a string
pub fn hashStr(k: []const u8) u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

pub fn strEql(a: []const u8, b: []const u8)bool {
    return mem.eql(u8, a, b);
}

// Just directs you to the standard string handler
pub fn hash_unicode(k: unicode.Utf8View) u32 {
    return hashStr(k.bytes);
}

pub fn findStr(a: []const u8, target: []const u8, start: usize, end: usize, highest: bool) ?usize {
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

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the bytes in `split_bytes`.
/// split("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
/// This one is intended for use with strings
pub fn t_SplitIt(comptime viewType: type, comptime iterator_type: type, comptime baseType: type, comptime codePoint: type) type {
    return struct {
        /// A buffer 
        buffer: viewType,
        buffer_it: iterator_type,
        split_bytes_it: iterator_type,

        const Self = this;

        // Returns the next thing as a view
        // You can obtain the data through the '.bytes' item.
        pub fn next(self: &Self) ?viewType {
            return viewType.initUnchecked(self.nextBytes());
        }

        // This shouldn't be like this :)
        pub fn nextBytes(self: &Self) ?baseType {
            // move to beginning of token
            var nextSlice = self.buffer_it.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(&(viewType.initUnchecked(curSlice)))) break;
                nextSlice = self.buffer_it.nextBytes();
            }

            if (nextSlice) |_| {
                // Go till we find another split
                const start = self.buffer_it.index - 1;
                nextSlice = self.buffer_it.nextBytes();
                while (nextSlice) |cSlice| {
                    if (self.isSplitByte(&(viewType.initUnchecked(cSlice)))) break;
                    nextSlice = self.buffer_it.nextBytes();
                }
                const end = if (nextSlice != null) self.buffer_it.index - 1 else self.buffer_it.index;
                return self.buffer.sliceBytes(start, end);
            } else {
                return null;
            }
        }

        pub fn nextCodepoint(self: &Self) ?[]const codePoint {
            return self.next().sliceCodepointToEndFrom(0);
        }

        /// Returns a slice of the remaining bytes. Does not affect iterator state.
        pub fn rest(self: &Self) ?viewType {
            // Note: I'm not 100% sure about doing an unchecked initialization
            // Because when we deal with code points there is a small chance that we could muck up
            // the slices, this WILL only occur when the user explicitly requires certain slices
            // or edits 'self.buffer_it.index' incorrectly :)
            return viewType.initUnchecked(self.restBytes());
        }

        pub fn restBytes(self: &Self) ?baseType {
            // move to beginning of token
            var index = self.buffer_it.index;
            defer self.buffer_it.index = index;
            var nextSlice = self.buffer_it.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(&(viewType.initUnchecked(curSlice)))) break;
                nextSlice = self.buffer_it.nextBytes();
            }

            if (nextSlice != null) {
                const iterator = self.buffer_it.index - 1;
                return self.buffer.sliceBytesToEndFrom(iterator);
            } else {
                return null;
            }
        }

        fn isSplitByte(self: &Self, toCheck: &viewType) bool {
            self.split_bytes_it.reset();
            var byte = self.split_bytes_it.nextBytes();
            
            while (byte) |split_byte| {
                var viewByte = viewType.initUnchecked(split_byte);
                if (toCheck.eql(viewByte)) {
                    return true;
                }
                byte = self.split_bytes_it.nextBytes();
            }
            return false;
        }

        fn init(view: baseType, split_bytes: baseType) !Self {
            return Self { .buffer = try viewType.init(view), .split_bytes_it = (try viewType.init(split_bytes)).iterator(), .buffer_it = (try viewType.init(view)).iterator() };
        }
    };
}

test "string_utils.split" {
    var it = try asciiSplit("   abc def   ghi  ", " ");
    assert(eql(u8, ?? it.nextBytes(), "abc"));
    assert(eql(u8, ?? it.nextBytes(), "def"));
    assert(eql(u8, ?? it.restBytes(), "ghi  "));
    assert(eql(u8, ?? it.nextBytes(), "ghi"));
    assert(it.nextBytes() == null);
}
              
pub const t_AsciiSplitIt = t_SplitIt(ascii.AsciiView, ascii.AsciiIterator, []const u8, u8);

pub fn asciiSplit(a: []const u8, splitBytes: []const u8) !t_AsciiSplitIt {
    return try t_AsciiSplitIt.init(a, splitBytes);
}

pub const t_Utf8SplitIt = t_SplitIt(unicode.Utf8View, unicode.Utf8Iterator, []const u8, u32);

pub fn utf8Split(a: []const u8, splitBytes: []const u8) !t_Utf8SplitIt {
    return try t_Utf8SplitIt.init(a, splitBytes);
}