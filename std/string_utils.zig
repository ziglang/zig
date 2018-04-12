const std = @import("index.zig");
const unicode = std.utf8;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const debug = std.debug;
const assert = debug.assert;
const ascii = std.ascii;
const utf8 = std.utf8;

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
pub fn hash_utf8(k: unicode.View) u32 {
    return hashStr(k.bytes);
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

        // This shouldn't be like this :)
        pub fn nextBytes(self: &Self) ?[]const baseType {
            // move to beginning of token
            var nextSlice = self.buffer_it.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(curSlice)) break;
                nextSlice = self.buffer_it.nextBytes();
            }

            if (nextSlice) |next| {
                // Go till we find another split
                const start = self.buffer_it.index - next.len;
                nextSlice = self.buffer_it.nextBytes();

                while (nextSlice) |cSlice| {
                    if (self.isSplitByte(cSlice)) break;
                    nextSlice = self.buffer_it.nextBytes();
                }

                if (nextSlice) |slice| self.buffer_it.index -= slice.len;

                const end = self.buffer_it.index;
                return self.buffer.sliceBytes(start, end);
            } else {
                return null;
            }
        }

        pub fn nextCodepoint(self: &Self) ?[]const codePoint {
            return utf8.decode(self.nextBytes());
        }

        /// Returns a slice of the remaining bytes. Does not affect iterator state.
        pub fn rest(self: &Self) ?viewType {
            // Note: I'm not 100% sure about doing an unchecked initialization
            // Because when we deal with code points there is a small chance that we could muck up
            // the slices, this WILL only occur when the user explicitly requires certain slices
            // or edits 'self.buffer_it.index' incorrectly :)
            return viewType.initUnchecked(self.restBytes());
        }

        pub fn restBytes(self: &Self) ?[]const baseType {
            // move to beginning of token
            var index = self.buffer_it.index;
            defer self.buffer_it.index = index;
            var nextSlice = self.buffer_it.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(curSlice)) break;
                nextSlice = self.buffer_it.nextBytes();
            }

            if (nextSlice) |slice| {
                const iterator = self.buffer_it.index - slice.len;
                return self.buffer.sliceBytesToEndFrom(iterator);
            } else {
                return null;
            }
        }

        fn isSplitByte(self: &Self, toCheck: []const baseType) bool {
            self.split_bytes_it.reset();
            var byte = self.split_bytes_it.nextBytes();
            
            while (byte) |split_byte| {
                if (mem.eql(baseType, split_byte, toCheck)) {
                    return true;
                }
                byte = self.split_bytes_it.nextBytes();
            }
            return false;
        }

        fn init(view: []const baseType, split_bytes: []const baseType) !Self {
            return Self { .buffer = try viewType.init(view), .split_bytes_it = (try viewType.init(split_bytes)).iterator(), .buffer_it = (try viewType.init(view)).iterator() };
        }
    };
}

test "string_utils.split.ascii" {
    var it = try asciiSplit("   abc def   ghi k ", " ");
    assert(mem.eql(u8, ?? it.nextBytes(), "abc"));
    assert(mem.eql(u8, ?? it.nextBytes(), "def"));
    assert(mem.eql(u8, ?? it.restBytes(), "ghi k "));
    assert(mem.eql(u8, ?? it.nextBytes(), "ghi"));
    assert(mem.eql(u8, ?? it.nextBytes(), "k"));
    assert(it.nextBytes() == null);
}

test "string_utils.split.unicode" {
    var it = try utf8Split("   abc ۩   g߶hi  ", " ");
    assert(mem.eql(u8, ?? it.nextBytes(), "abc"));
    assert(mem.eql(u8, ?? it.nextBytes(), "۩"));
    assert(mem.eql(u8, ?? it.restBytes(), "g߶hi  "));
    assert(mem.eql(u8, ?? it.nextBytes(), "g߶hi"));
    assert(it.nextBytes() == null);
}
              
pub const t_AsciiSplitIt = t_SplitIt(ascii.View, ascii.Iterator, u8, u8);

pub fn asciiSplit(a: []const u8, splitBytes: []const u8) !t_AsciiSplitIt {
    return try t_AsciiSplitIt.init(a, splitBytes);
}

pub const t_Utf8SplitIt = t_SplitIt(utf8.View, utf8.Iterator, u8, u32);

pub fn utf8Split(a: []const u8, splitBytes: []const u8) !t_Utf8SplitIt {
    return try t_Utf8SplitIt.init(a, splitBytes);
}

pub fn asciiJoin(allocator: &mem.Allocator, sep: []const u8, strings: ...) ![]u8 {
    return join(u8, allocator, sep, strings);
}

pub fn asciiJoinBuffer(buffer: []u8, sep: []const u8, strings: ...) []u8 {
    return joinBuffer(u8, buffer, sep, strings);
}

pub fn utf8Join(allocator: &mem.Allocator, sep: []const u8, strings: ...) ![]u8 {
    return join(u8, allocator, sep, strings);
}

pub fn utf8JoinBuffer(buffer: []u8, sep: []const u8, strings: ...) []u8 {
    return joinBuffer(u8, buffer, sep, strings);
}

fn calculateLength(comptime baseType: type,  sep: []const baseType, views: [][]const baseType, strings: ...) usize {
    var totalLength: usize = 0;
    comptime var string_i = 0;
    inline while (string_i < strings.len) : (string_i += 1) {
        const arg = ([]const baseType)(strings[string_i]);
        totalLength += arg.len;
        if (string_i < strings.len - 1 and (arg.len < sep.len or !mem.eql(baseType, arg[arg.len - sep.len..], sep))) {
            totalLength += sep.len;
        }
        views[string_i] = arg;
    }
    return totalLength;
}

// The allocator could fail.
pub fn join(comptime baseType: type, allocator: &mem.Allocator, sep: []const baseType, strings: ...) ![]baseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(baseType, sep, views[0..], strings);
    const buf = try allocator.alloc(baseType, totalLength);
    return joinViewsBuffer(baseType, sep, views[0..], totalLength, buf);
}

// You could give us invalid utf8 for example or even invalid ascii
pub fn joinBuffer(comptime baseType: type,  buffer: []baseType, sep: []const baseType, strings: ...) []baseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(baseType, sep, views[0..], strings);
    return joinViewsBuffer(baseType, sep, views[0..], totalLength, buffer);
}

pub fn joinViewsBuffer(comptime baseType: type, sep: []const baseType, strings: [][]const baseType, totalLength: usize, buffer: []baseType) []baseType {
    assert(totalLength <= buffer.len);
    var buffer_i: usize = 0;
    for (strings) |string| {
        // Write to buffer
        mem.copy(baseType, buffer[buffer_i..], string);
        buffer_i += string.len;
        // As to not print the last one
        if (buffer_i >= totalLength) break;
        if (buffer_i < sep.len or !mem.eql(baseType, buffer[buffer_i - sep.len..buffer_i], sep)) {
            mem.copy(baseType, buffer[buffer_i..], sep);
            buffer_i += sep.len;
        }
    }
    return buffer[0..buffer_i];
}

test "stringUtils.ascii.joinBuffer" {
    var buf: [100]u8 = undefined;
    assert(mem.eql(u8, asciiJoinBuffer(buf[0..], ", ", "a", "b", "c"), "a, b, c"));
    assert(mem.eql(u8, asciiJoinBuffer(buf[0..], ",", "a"), "a"));
}

pub fn asciiTrim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return trim(ascii.View, u8, &ascii.View.initUnchecked(string), &ascii.View.initUnchecked(trimChars), side);
}

pub fn utf8Trim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return trim(utf8.View, u8, &utf8.View.initUnchecked(string), &utf8.View.initUnchecked(trimChars), side);
}

pub const Side = enum { LEFT = 1, RIGHT = 2, BOTH = 3, };

pub fn trim(comptime View: type, comptime BaseType: type, string: &View, trimCharacters: &View, side: Side) []const BaseType {
    assert(side == Side.LEFT or side == Side.RIGHT or side == Side.BOTH);
    var initialIndex : usize = 0;
    var endIndex : usize = string.byteLen();
    var it = string.iterator();

    if (side == Side.LEFT or side == Side.BOTH) {
        while (it.nextBytes()) |bytes| {
            var trim_it = trimCharacters.iterator();
            var found = false;
            while (trim_it.nextBytes()) |trimBytes| {
                if (mem.eql(BaseType, trimBytes, bytes)) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                initialIndex = it.index - bytes.len;
                break;
            }
        }
    }

    if (side == Side.RIGHT or side == Side.BOTH) {
        // Continue from where it started off but keep going till we hit the end keeping in track
        // The length of the code points
        var codePointLength : usize = 0;
        while (it.nextBytes()) |bytes| {
            var trim_it = trimCharacters.iterator();
            var found = false;
            while (trim_it.nextBytes()) |trimBytes| {
                if (mem.eql(BaseType, trimBytes, bytes)) {
                    found = true;
                    break;
                }
            }

            if (found) {
                codePointLength += bytes.len;
            } else {
                codePointLength = 0;
            }
        }

        endIndex -= codePointLength;
    }

    return string.sliceBytes(initialIndex, endIndex);
}

test "stringUtils.ascii.trim" {
    // Copied from mem.trim
    assert(mem.eql(u8, asciiTrim(" foo\n ", " \n", Side.BOTH), "foo"));
    assert(mem.eql(u8, asciiTrim("foo", " \n", Side.BOTH), "foo"));
    assert(mem.eql(u8, asciiTrim(" foo ", " ", Side.LEFT), "foo "));
}