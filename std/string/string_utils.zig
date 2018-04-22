const std = @import("../index.zig");
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const debug = std.debug;
const assert = debug.assert;
const ascii = std.string.ascii;
const utf8 = std.string.utf8;

/// Returns an iterator that iterates over the slices of `buffer` that are not
/// any of the code points in `split_bytes`.
/// split("   abc def    ghi  ", " ")
/// Will return slices for "abc", "def", "ghi", null, in that order.
/// This one is intended for use with strings
pub fn SplitIt(comptime ViewType: type, comptime IteratorType: type, comptime BaseType: type, comptime CodepointType: type) type {
    return struct {
        buffer: ViewType,
        bufferIt: IteratorType,
        splitBytesIt: IteratorType,

        const Self = this;

        /// Returns the next set of bytes
        pub fn nextBytes(self: &Self) ?[]const BaseType {
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
        pub fn nextCodepoint(self: &Self) ?[]const CodepointType {
            return utf8.decode(self.nextBytes());
        }

        /// Returns the rest of the bytes.
        pub fn restBytes(self: &Self) ?[]const BaseType {
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
        fn isSplitByte(self: &Self, toCheck: []const BaseType) bool {
            self.splitBytesIt.reset();
            var byte = self.splitBytesIt.nextBytes();
            
            while (byte) |splitByte| {
                if (mem.eql(BaseType, splitByte, toCheck)) {
                    return true;
                }
                byte = self.splitBytesIt.nextBytes();
            }
            return false;
        }

        /// Initialises the string split iterator.
        fn init(view: []const BaseType, splitBytes: []const BaseType) !Self {
            return Self { .buffer = try ViewType.init(view), .splitBytesIt = (try ViewType.init(splitBytes)).iterator(), .bufferIt = (try ViewType.init(view)).iterator() };
        }
    };
}

pub fn joinViewsBuffer(comptime BaseType: type, sep: []const BaseType, strings: [][]const BaseType, totalLength: usize, buffer: []BaseType) []BaseType {
    assert(totalLength <= buffer.len);
    var buffer_i: usize = 0;
    for (strings) |string| {
        // Write to buffer
        mem.copy(BaseType, buffer[buffer_i..], string);
        buffer_i += string.len;
        // As to not print the last one
        if (buffer_i >= totalLength) break;
        if (buffer_i < sep.len or !mem.eql(BaseType, buffer[buffer_i - sep.len..buffer_i], sep)) {
            mem.copy(BaseType, buffer[buffer_i..], sep);
            buffer_i += sep.len;
        }
    }
    return buffer[0..buffer_i];
}

const Side = std.string.Side;

/// Trim a provided string.
/// Note: you have to provide both a View and a BaseType
/// but don't have to supply an iterator, however `View.iterator` has to exist.
pub fn trim(comptime View: type, comptime BaseType: type, string: &View, trimCharacters: &View, side: Side) []const BaseType {
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
