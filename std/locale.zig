const std = @import("index.zig");
const unicode = std.utf8;
const mem = std.mem;
const math = std.math;
const Set = std.BufSet;
const assert = std.debug.assert;
const warn = std.debug.warn;
const DebugAllocator = std.debug.global_allocator;

const Errors = error {
    OutOfMemory,
};

pub fn CreateLocale(comptime CodePoint: type, comptime View: type, comptime Iterator: type) type {
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

        pub fn isInView(view: &const View, codePoint: CodePoint) bool {
            return codePoint >= view.codePointAt(0) and codePoint <= view.codePointFromEndAt(0);
        }

        pub fn isNum(self: &const Self, codePoint: CodePoint) bool {
            return isInView(&self.numbers, codePoint);
        }

        pub fn isLowercaseLetter(self: &const Self, codePoint: CodePoint) bool {
            return isInView(&self.lowercaseLetters, codePoint);
        }

        pub fn isUppercaseLetter(self: &const Self, codePoint: CodePoint) bool {
            return isInView(&self.uppercaseLetters, codePoint);
        }

        pub fn isLetter(self: &const Self, codePoint: CodePoint) bool {
            return self.isUppercaseLetter(codePoint) or self.isLowercaseLetter(codePoint);
        }

        pub fn isWhitespace(self: &const Self, codePoint: CodePoint) bool {
            return isInView(&self.whitespaceLetters, codePoint);
        }

        const FormatterType = struct {
            toUpper: fn(&View, &mem.Allocator) Errors!View,
            toLower: fn(&View, &mem.Allocator) Errors!View,
            toUpperBuffer: fn(&View, []CodePoint) View,
            toLowerBuffer: fn(&View, []CodePoint) View,
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

            pub fn nextBytes(it: &ViewIterator) ?[]const CodePoint {
                var x : ?[]CodePoint = it.iterator.nextBytes();
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

            pub fn nextCodePoint(it: &ViewIterator) ?CodePoint {
                var x : ?CodePoint = it.iterator.nextCodePoint();
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
