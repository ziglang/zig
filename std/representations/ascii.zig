const std = @import("../index.zig");
const unicode = std.utf8;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const DebugAllocator = std.debug.global_allocator;

pub const Errors = error {
    InvalidCharacter,
    OutOfMemory,
};

pub const MemoryErrors = error {
    OutOfMemory,
};

pub const Iterator = struct {
    raw: []const u8,
    index: usize,

    pub fn reset(it: &Iterator) void {
        it.index = 0;
    }

    pub fn nextBytes(it: &Iterator)?[]const u8 {
        if (it.index >= it.raw.len) {
            return null;
        }

        // It wants an array not a singular character
        var x = it.raw[it.index..it.index+1];
        it.index += 1;
        return x;
    }

    pub fn nextCodePoint(it: &Iterator)?u8 {
        var x = it.nextBytes();
        return if (x) |y| y[0] else null;
    }
};

pub const View = struct {
    characters: []const u8,

    pub fn init(s: []const u8) !View {
        for (s) |char| {
            if (char > 127) return error.InvalidCharacter;
        }

        return initUnchecked(s);
    }

    pub fn initComptime(comptime s: []const u8) View {
        if (comptime init(s)) |view| {
            return view;
        } else |err| {
            // @Refactor: add on more information when converting enums to strings
            //            become a thing in the language
            @compileError("Invalid bytes");
        }
    }

    pub fn eql(self: &const View, other: &const View) bool {
        return mem.eql(u8, self.characters, other.characters);
    }

    pub fn sliceCodepoint(self: &const View, start: usize, end: usize) []const u8 {
        return self.characters[start..end];
    }

    pub fn sliceCodepointToEndFrom(self: &const View, start: usize) []const u8 {
        return self.characters[start..];
    }

    pub fn byteLen(self: &const View) usize {
        return self.characters.len;
    }

    pub fn getBytes(self: &const View) []const u8 {
        return self.characters;
    }

    pub fn sliceBytes(self: &const View, start: usize, end: usize) []const u8 {
        return self.characters[start..end];
    }

    pub fn sliceBytesToEndFrom(self: &const View, start: usize) []const u8 {
        return self.characters[start..];
    }

    pub fn byteAt(self: &const View, index: usize) u8 {
        return self.characters[index];
    }

    pub fn byteFromEndAt(self: &const View, index: usize) u8 {
        return self.characters[self.characters.len - 1 - index];
    }

    pub fn codePointAt(self: &const View, index: usize) u8 {
        return self.characters[index];
    }

    pub fn codePointFromEndAt(self: &const View, index: usize) u8 {
        return self.characters[self.characters.len - 1 - index];
    }

    pub fn initUnchecked(s: []const u8) View {
        return View {
            .characters = s
        };
    }

    pub fn iterator(self: &const View) Iterator {
        return Iterator { .index = 0, .raw = self.characters };
    }
};
