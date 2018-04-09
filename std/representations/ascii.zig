const std = @import("../index.zig");
const unicode = std.utf8;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const DebugAllocator = std.debug.global_allocator;
const locale = std.locale;

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

fn changeCase(view: &View, allocator: &mem.Allocator, lowercase: bool) MemoryErrors!View {
    assert(view.characters.len > 0);
    // Ascii so no need to do it 'right'
    var newArray : []u8 = try allocator.alloc(u8, @sizeOf(u8) * view.characters.len);
    var it = view.iterator();
    var char = it.nextCodePoint();
    var i : usize = 0;

    while (char) |v| {
        if (lowercase and Locale.isLowercaseLetter(v)) {
            newArray[i] = v + ('a' - 'A');
        } else if (!lowercase and Locale.isUppercaseLetter(v)) {
            newArray[i] = v - ('a' - 'A');
        } else {
            newArray[i] = v;
        }
        char = it.nextCodePoint();
        i += 1;
    }

    return View.initUnchecked(newArray);
}

fn changeCaseBuffer(view: &View, buffer: []u8, lowercase: bool) View {
    assert(view.characters.len > 0 and view.characters.len <= buffer.len);
    // Ascii so we can just write into the array directly without translating it back into bytes
    // For unicode you would have to run an encode.
    var it = view.iterator();
    var char = it.nextCodePoint();
    var i : usize = 0;

    while (char) |v| {
        if (lowercase and Locale.isLowercaseLetter(v)) {
            buffer[i] = v + ('a' - 'A');
        } else if (!lowercase and Locale.isUppercaseLetter(v)) {
            buffer[i] = v - ('a' - 'A');
        } else {
            buffer[i] = v;
        }
        char = it.nextCodePoint();
        i += 1;
    }
    return View.initUnchecked(buffer[0..i]);
}

fn toLower(view: &View, allocator: &mem.Allocator) MemoryErrors!View {
    return changeCase(view, allocator, true);
}

fn toUpper(view: &View, allocator: &mem.Allocator) MemoryErrors!View {
    return changeCase(view, allocator, false);
}

fn toUpperBuffer(view: &View, buffer: []u8) View {
    return changeCaseBuffer(view, buffer, false);
}

fn toLowerBuffer(view: &View, buffer: []u8) View {
    return changeCaseBuffer(view, buffer, true);
}

const Locale_Type = locale.CreateLocale(u8, View, Iterator);

pub const Locale = Locale_Type {
    .lowercaseLetters = View.initUnchecked("abcdefghijklmnopqrstuvwxyz"), .uppercaseLetters = View.initUnchecked("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    .whitespaceLetters = View.initUnchecked(" \t\r\n"), .numbers = View.initUnchecked("0123456789"), 
    .formatter = Locale_Type.FormatterType {
        .toLower = toLower, .toUpper = toUpper,
        .toLowerBuffer = toLowerBuffer, .toUpperBuffer = toUpperBuffer,
    }
};

test "Ascii Locale" {
    // To be split up later
    var views = [] View { Locale.lowercaseLetters, Locale.uppercaseLetters };
    var it = Locale.iterator(views[0..]);
    var i: usize = 0;
    var lower = "abcdefghijklmnopqrstuvwxyz";
    var higher = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    while (i < lower.len) {
        assert(?? it.nextCodePoint() == lower[i]);
        i += 1;
    }

    i = 0;
    while (i < higher.len) {
        assert(?? it.nextCodePoint() == higher[i]);
        i += 1;
    }
    
    var view = try View.init("A");
    view = try Locale.formatter.toLower(&view, DebugAllocator);
    assert(view.characters[0] == 'a');
    DebugAllocator.free(view.characters);
}