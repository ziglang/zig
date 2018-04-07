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

        pub fn isNum(self: &const Self, view: &View) bool {
            return numbers
        }

        const FormatterType = struct {
            toUpper: fn(&View, &mem.Allocator) FormatterErrors!View,
            toLower: fn(&View, &mem.Allocator) FormatterErrors!View,
            toUpperImplact: fn(&View) FormatterErrors!View,
            toUpperImplact: fn(&View) FormatterErrors!View,
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
