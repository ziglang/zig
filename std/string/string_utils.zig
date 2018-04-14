const std = @import("../index.zig");
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const debug = std.debug;
const assert = debug.assert;
const ascii = std.string.ascii;
const utf8 = std.string.utf8;

// Handles a series of string utilities that are focused around handling and manipulating strings

/// Returns a hash for a string
pub fn hashStr(k: []const u8) u32 {
    // FNV 32-bit hash
    var h: u32 = 2166136261;
    for (k) |b| {
        h = (h ^ b) *% 16777619;
    }
    return h;
}

/// Returns if two strings are equal.
/// Note: just maps to mem.eql, this is mainly
///       for use in structures like in buf_map.
pub fn strEql(a: []const u8, b: []const u8)bool {
    return mem.eql(u8, a, b);
}

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the bytes in `split_bytes`.
/// split("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
/// This one is intended for use with strings
pub fn SplitIt(comptime viewType: type, comptime iteratorType: type, comptime baseType: type, comptime codePoint: type) type {
    return struct {
        buffer: viewType,
        bufferIt: iteratorType,
        splitBytesIt: iteratorType,

        const Self = this;

        /// Returns the next set of bytes
        pub fn nextBytes(self: &Self) ?[]const baseType {
            // move to beginning of token
            var nextSlice = self.bufferIt.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(curSlice)) break;
                nextSlice = self.bufferIt.nextBytes();
            }

            if (nextSlice) |next| {
                // Go till we find another split
                const start = self.bufferIt.index - next.len;
                nextSlice = self.bufferIt.nextBytes();

                while (nextSlice) |cSlice| {
                    if (self.isSplitByte(cSlice)) break;
                    nextSlice = self.bufferIt.nextBytes();
                }

                if (nextSlice) |slice| self.bufferIt.index -= slice.len;

                const end = self.bufferIt.index;
                return self.buffer.sliceBytes(start, end);
            } else {
                return null;
            }
        }

        /// Decodes the next set of bytes.
        pub fn nextCodepoint(self: &Self) ?[]const codePoint {
            return utf8.decode(self.nextBytes());
        }

        /// Returns the rest of the bytes.
        pub fn restBytes(self: &Self) ?[]const baseType {
            // move to beginning of token
            var index = self.bufferIt.index;
            defer self.bufferIt.index = index;
            var nextSlice = self.bufferIt.nextBytes();

            while (nextSlice) |curSlice| {
                if (!self.isSplitByte(curSlice)) break;
                nextSlice = self.bufferIt.nextBytes();
            }

            if (nextSlice) |slice| {
                const iterator = self.bufferIt.index - slice.len;
                return self.buffer.sliceBytesToEndFrom(iterator);
            } else {
                return null;
            }
        }

        /// Returns if a split byte matches the bytes given.
        fn isSplitByte(self: &Self, toCheck: []const baseType) bool {
            self.splitBytesIt.reset();
            var byte = self.splitBytesIt.nextBytes();
            
            while (byte) |splitByte| {
                if (mem.eql(baseType, splitByte, toCheck)) {
                    return true;
                }
                byte = self.splitBytesIt.nextBytes();
            }
            return false;
        }

        /// Initialises the string split iterator.
        fn init(view: []const baseType, splitBytes: []const baseType) !Self {
            return Self { .buffer = try viewType.init(view), .splitBytesIt = (try viewType.init(splitBytes)).iterator(), .bufferIt = (try viewType.init(view)).iterator() };
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

const AsciiSplitIt = SplitIt(ascii.View, ascii.Iterator, u8, u8);

/// Splits a string (ascii set).
/// It will split it at ANY of the split bytes.
/// i.e. splitting at "\n " means '\n' AND/OR ' '.
pub fn asciiSplit(a: []const u8, splitBytes: []const u8) !AsciiSplitIt {
    return try AsciiSplitIt.init(a, splitBytes);
}

const Utf8SplitIt = SplitIt(utf8.View, utf8.Iterator, u8, u32);

/// Splits a string (utf8 set).
/// It will split it at ANY of the split bytes.
/// i.e. splitting at "\n " means '\n' AND/OR ' '.
pub fn utf8Split(a: []const u8, splitBytes: []const u8) !Utf8SplitIt {
    return try Utf8SplitIt.init(a, splitBytes);
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

/// Joins strings together with a seperator.
/// Error: The allocator could fail.
pub fn join(comptime baseType: type, allocator: &mem.Allocator, sep: []const baseType, strings: ...) ![]baseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(baseType, sep, views[0..], strings);
    const buf = try allocator.alloc(baseType, totalLength);
    return joinViewsBuffer(baseType, sep, views[0..], totalLength, buf);
}

/// Similar version as join but uses a buffer instead of an allocator.
pub fn joinBuffer(comptime baseType: type,  buffer: []baseType, sep: []const baseType, strings: ...) []baseType {
    var views: [strings.len][]const u8 = undefined;
    const totalLength = calculateLength(baseType, sep, views[0..], strings);
    return joinViewsBuffer(baseType, sep, views[0..], totalLength, buffer);
}

fn joinViewsBuffer(comptime baseType: type, sep: []const baseType, strings: [][]const baseType, totalLength: usize, buffer: []baseType) []baseType {
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
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ", ", "a", "߶", "۩", "°"), "a, ߶, ۩, °"));
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ",", "۩"), "۩"));
}

test "stringUtils.utf8.joinBuffer" {
    var buf: [100]u8 = undefined;
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ", ", "a", "b", "c"), "a, b, c"));
    assert(mem.eql(u8, joinBuffer(u8, buf[0..], ",", "a"), "a"));
}

/// Trim an ascii string from either/both sides.
pub fn asciiTrim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return trim(ascii.View, u8, &ascii.View.initUnchecked(string), &ascii.View.initUnchecked(trimChars), side);
}

/// Trim an utf8 string from either/both sides.
pub fn utf8Trim(string: []const u8, trimChars: []const u8, side: Side)[]const u8 {
    return trim(utf8.View, u8, &utf8.View.initUnchecked(string), &utf8.View.initUnchecked(trimChars), side);
}

/// To choose what sides.
pub const Side = enum { LEFT = 1, RIGHT = 2, BOTH = 3, };

/// Trim a provided string.
/// Note: you have to provide both a View and a BaseType
/// but don't have to supply an iterator, however `View.iterator` has to exist.
pub fn trim(comptime View: type, comptime BaseType: type, string: &View, trimCharacters: &View, side: Side) []const BaseType {
    assert(side == Side.LEFT or side == Side.RIGHT or side == Side.BOTH);
    var initialIndex : usize = 0;
    var endIndex : usize = string.byteLen();
    var it = string.iterator();

    if (side == Side.LEFT or side == Side.BOTH) {
        while (it.nextBytes()) |bytes| {
            var trimIt = trimCharacters.iterator();
            var found = false;
            while (trimIt.nextBytes()) |trimBytes| {
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
            var trimIt = trimCharacters.iterator();
            var found = false;
            while (trimIt.nextBytes()) |trimBytes| {
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