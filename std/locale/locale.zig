const std = @import("../index.zig");
const unicode = std.unicode;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const allocator = std.debug.debug_allocator;

fn CreateLocale(comptime T: type, comptime View: type, comptime Iterator: type) type {
    return struct {
        // Represents all the characters counted as lowercase letters
        // Stored as uf8, convertible through the various functions
        lowercaseLetters: View,
        // Uppercase
        uppercaseLetters: View,

        const Self = this;

        const LetterIterator = struct {
            changed: bool,
            locale: &Self,
            view: &View,
            iterator: Iterator,

            pub fn reset(it: &LetterIterator)void {
                changed = false;
                view = &locale.lowercaseLetters;
                iterator = view.iterator();
            }

            pub fn nextBytes(it: &LetterIterator) ?[]const T {
                var x : ?[]T = it.iterator.nextBytes();
                if (x == null) {
                    if (it.changed) {
                        return null;
                    } else {
                        it.view = &it.locale.uppercaseLetters;
                        it.iterator = it.view.iterator();
                        it.changed = true;
                        return it.nextBytes();
                    }
                }
            }

            pub fn nextCodePoint(it: &LetterIterator) ?T {
                var x : ?T = it.iterator.nextCodePoint();
                if (x == null) {
                    if (it.changed) {
                        return null;
                    } else {
                        it.view = &it.locale.uppercaseLetters;
                        it.iterator = it.view.iterator();
                        it.changed = true;
                        return it.nextCodePoint();
                    }
                } else {
                    return x;
                }
            }
        };

        fn AllLetters(self: &Self) LetterIterator {
            return LetterIterator { .changed = false, .locale = self, .view = &self.lowercaseLetters, .iterator = self.lowercaseLetters.iterator() };
        }
    };
}

const ascii_lower : []const u8 = "abcdefghijklmnopqrstuvwxyz";
const ascii_higher : []const u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

pub const AsciiIterator = struct {
    characters: []const u8,
    i: usize,

    pub fn reset(it: &AsciiIterator) void {
        it.i = 0;
    }

    pub fn nextBytes(it: &AsciiIterator)?[]const u8 {
        if (it.i >= it.characters.len) return null;

        // It wants an array not a singular character
        var x = it.characters[it.i..it.i+1];
        it.i += 1;
        return x;
    }

    pub fn nextCodePoint(it: &AsciiIterator)?u8 {
        var x = it.nextBytes();
        return if (x) |y| y[0] else null;
    }
};

pub const AsciiView = struct {
    characters: []const u8,

    pub fn init(s: []const u8) AsciiView {
        return AsciiView {
            .characters = s
        };
    }

    pub fn iterator(self: &const AsciiView) AsciiIterator {
        return AsciiIterator { .i = 0, .characters = self.characters };
    }
};

pub const Ascii_Locale = CreateLocale(u8, AsciiView, AsciiIterator);

test "Congregation of tests" {
    // To be split up later
    var it = (Ascii_Locale { .lowercaseLetters = AsciiView.init(ascii_lower), .uppercaseLetters = AsciiView.init(ascii_higher) }).AllLetters();
    var i: usize = 0;
    while (i < ascii_lower.len) {
        assert(?? it.nextCodePoint() == ascii_lower[i]);
        i += 1;
    }

    i = 0;
    while (i < ascii_higher.len) {
        assert(?? it.nextCodePoint() == ascii_higher[i]);
        i += 1;
    }
}