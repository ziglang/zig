const std = @import("../index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const DebugAllocator = std.debug.global_allocator;

const FormatterErrors = error {
    InvalidCodePoint, InvalidView, OutOfMemory, InvalidCharacter
};

fn CreateLocale(comptime T: type, comptime View: type, comptime Iterator: type) type {
    return struct {
        // Represents all the characters counted as lowercase letters
        // Stored as uf8, convertible through the various functions
        lowercaseLetters: View,
        // Uppercase
        uppercaseLetters: View,
        // Whitespace
        whitespaceLetters: View,
        // Numbers
        numbers: View,

        formatter: FormatterType,

        const FormatterType = struct {
            toUpper: fn(&View, &mem.Allocator) FormatterErrors!View,
            toLower: fn(&View, &mem.Allocator) FormatterErrors!View,
            isNum: fn(T)bool,
            isUpper: fn(T)bool,
            isLower: fn(T)bool,
        };

        const Self = this;

        const ViewIterator = struct {
            i: usize,
            locale: &const Self,
            views: []View,
            iterator: Iterator,

            pub fn reset(it: &ViewIterator)void {
                it.i = 0;
                it.iterator = it.views[0].iterator();
            }

            pub fn nextBytes(it: &ViewIterator) ?[]const T {
                var x : ?[]T = it.iterator.nextBytes();
                if (x == null) {
                    if (it.i > it.views.len) {
                        return null;
                    } else {
                        it.i += 1;
                        it.iterator = it.views[it.i].iterator();
                        return it.nextBytes();
                    }
                }
            }

            pub fn nextCodePoint(it: &ViewIterator) ?T {
                var x : ?T = it.iterator.nextCodePoint();
                if (x == null) {
                    if (it.i > it.views.len) {
                        return null;
                    } else {
                        it.i += 1;
                        it.iterator = it.views[it.i].iterator();
                        return it.nextCodePoint();
                    }
                } else {
                    return x;
                }
            }
        };

        fn iterator(self: &const Self, views: []View) ViewIterator {
            assert(views.len > 0);
            return ViewIterator { .i = 0, .locale = self, .views = views, .iterator = views[0].iterator() };
        }
    };
}

pub const AsciiIterator = struct {
    characters: []const u8,
    index: usize,

    pub fn reset(it: &AsciiIterator) void {
        it.index = 0;
    }

    pub fn nextBytes(it: &AsciiIterator)?[]const u8 {
        if (it.index >= it.characters.len) {
            return null;
        }

        // It wants an array not a singular character
        var x = it.characters[it.index..it.index+1];
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

    pub fn slice(self: &const AsciiView, start: usize, end: usize) !AsciiView {
        return AsciiView.init(self.characters[start..end]);
    }

    pub fn sliceToEndFrom(self: &const AsciiView, start: usize) !AsciiView {
        return AsciiView.init(self.characters[start..]);
    }

    pub fn initUnchecked(s: []const u8) AsciiView {
        return AsciiView {
            .characters = s
        };
    }

    pub fn iterator(self: &const AsciiView) AsciiIterator {
        return AsciiIterator { .index = 0, .characters = self.characters };
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

fn Ascii_isLower(char: u8)bool {
    return char >= 'a' and char <= 'z';
}

fn Ascii_isUpper(char: u8)bool {
    return char >= 'A' and char <= 'Z';
}

fn Ascii_isNum(char: u8)bool {
    return char >= '0' and char <= '9';
}

pub const Ascii_Locale_Type = CreateLocale(u8, AsciiView, AsciiIterator);
pub const Ascii_Locale = Ascii_Locale_Type { 
    .lowercaseLetters = AsciiView.initUnchecked("abcdefghijklmnopqrstuvwxyz"), .uppercaseLetters = AsciiView.initUnchecked("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    .whitespaceLetters = AsciiView.initUnchecked(" \t\r\n"), .numbers = AsciiView.initUnchecked("0123456789"), 
    .formatter = Ascii_Locale_Type.FormatterType {
        .isNum = Ascii_isNum, .isUpper = Ascii_isUpper, .isLower = Ascii_isLower,
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