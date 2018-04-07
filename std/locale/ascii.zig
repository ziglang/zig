const std = @import("../index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const DebugAllocator = std.debug.global_allocator;
const locale = std.locale;

pub const AsciiIterator = struct {
    raw: []const u8,
    index: usize,

    pub fn reset(it: &AsciiIterator) void {
        it.index = 0;
    }

    pub fn nextBytes(it: &AsciiIterator)?[]const u8 {
        if (it.index >= it.raw.len) {
            return null;
        }

        // It wants an array not a singular character
        var x = it.raw[it.index..it.index+1];
        it.index += 1;
        return x;
    }

    pub fn nextCodePoint(it: &AsciiIterator)?u8 {
        var x = it.nextBytes();
        return if (x) |y| y[0] else null;
    }
};

pub const AsciiView = struct {
    characters: []const u8,

    pub fn init(s: []const u8) !AsciiView {
        for (s) |char| {
            if (char > 127) return error.InvalidCharacter;
        }

        return initUnchecked(s);
    }

    pub fn eql(self: &const AsciiView, other: &const AsciiView) bool {
        return mem.eql(u8, self.characters, other.characters);
    }

    pub fn sliceCodepoint(self: &const AsciiView, start: usize, end: usize) []const u8 {
        return self.characters[start..end];
    }

    pub fn sliceCodepointToEndFrom(self: &const AsciiView, start: usize) []const u8 {
        return self.characters[start..];
    }

    pub fn sliceBytes(self: &const AsciiView, start: usize, end: usize) []const u8 {
        return self.characters[start..end];
    }

    pub fn sliceBytesToEndFrom(self: &const AsciiView, start: usize) []const u8 {
        return self.characters[start..];
    }

    pub fn byteAt(self: &const AsciiView, index: usize) u8 {
        return self.characters[index];
    }

    pub fn codePointAt(self: &const AsciiView, index: usize) u8 {
        return self.characters[index];
    }

    pub fn initUnchecked(s: []const u8) AsciiView {
        return AsciiView {
            .characters = s
        };
    }

    pub fn iterator(self: &const AsciiView) AsciiIterator {
        return AsciiIterator { .index = 0, .raw = self.characters };
    }
};

fn Ascii_toLower(view: &AsciiView, allocator: &mem.Allocator)FormatterErrors!AsciiView {
    if (view.characters.len == 0) return error.InvalidView;
    // Ascii so no need to do it 'right'
    var newArray : []u8 = try allocator.alloc(u8, @sizeOf(u8) * view.characters.len);
    var it = view.iterator();
    var i: usize = 0;
    while (i < newArray.len) {
        var char = it.nextCodePoint();
        if (char) |v| {
            if (Ascii_isUpper(v)) {
                newArray[i] = v + ('a' - 'A');
            } else {
                newArray[i] = v;
            }
        } else {
            return error.InvalidCodePoint;
        }
        i += 1;
    }
    return AsciiView.init(newArray);
}

fn Ascii_toUpper(view: &AsciiView, allocator: &mem.Allocator)FormatterErrors!AsciiView {
    if (view.characters.len == 0) return error.InvalidView;
    // Ascii so no need to do it 'right'
    var newArray : []u8 = try allocator.alloc(u8, @sizeOf(u8) * view.characters.len);
    var it = view.iterator();
    var i: usize = 0;
    while (i < newArray.len) {
        var char = it.nextCodePoint();
        if (char) |v| {
            if (Ascii_isLower(v)) {
                newArray[i] = v - ('a' - 'A');
            } else {
                newArray[i] = v;
            }
        } else {
            return error.InvalidCodePoint;
        }
        i += 1;
    }
    return AsciiView.init(newArray);
}

pub const Ascii_Locale_Type = CreateLocale(u8, AsciiView, AsciiIterator);
pub const Ascii_Locale = Ascii_Locale_Type { 
    .lowercaseLetters = AsciiView.initUnchecked("abcdefghijklmnopqrstuvwxyz"), .uppercaseLetters = AsciiView.initUnchecked("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    .whitespaceLetters = AsciiView.initUnchecked(" \t\r\n"), .numbers = AsciiView.initUnchecked("0123456789"), 
    .formatter = Ascii_Locale_Type.FormatterType {
        .toLower = Ascii_toLower, .toUpper = Ascii_toUpper
    }
};

test "Ascii Locale" {
    // To be split up later
    var views = [] AsciiView { Ascii_Locale.lowercaseLetters, Ascii_Locale.uppercaseLetters };
    var it = Ascii_Locale.iterator(views[0..]);
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
    
    var view = try AsciiView.init("A");
    view = try Ascii_Locale.formatter.toLower(&view, DebugAllocator);
    assert(view.characters[0] == 'a');
    DebugAllocator.free(view.characters);
}