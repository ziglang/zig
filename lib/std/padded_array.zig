const std = @import("std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

/// A structure that implements an array where the length is terminated by a sentinel value.
/// This is useful for wrapping external string types or arrays which have an implicit length.
/// The array contains a maximum of `length` elements of type `T`. The length is determined by
/// the first appearance of the `sentinel` value.
///
/// The returned structure type is `extern` so it can be used inside other extern data types
/// to replace arrays at the ABI boundary.
///
/// **WARNING:** This structure does not necessarily preserve the `sentinel` value. This is due to
///              C code usually not guaranteeing a sentinel either, so a `char[33]` might be
///              32 chars + 1 sentinel NUL or 33 chars with NUL padding, so additional checking
///              might be required when a sentinel is expected.
pub fn PaddedArray(comptime T: type, comptime length: usize, comptime sentinel: T) type {
    return extern struct {
        const Self = @This();

        fn Span(comptime Inner: type) type {
            return switch (Inner) {
                *const [length]T => []const T,
                *[length]T => []T,
                else => unreachable,
            };
        }

        items: [length]T = [1]T{sentinel} ** length,

        /// Copy the content of an existing slice.
        pub fn init(m: []const T) error{Overflow}!Self {
            if (m.len > length)
                return error.Overflow;
            var list: Self = .{};
            std.mem.copy(T, &list.items, m);
            return list;
        }

        /// The maximum number of items in this array.
        pub const capacity = length;

        /// Returns the number of items in the array before the sentinel appears.
        /// If no sentinel is present, the length of the array is returned.
        pub fn len(self: Self) usize {
            return std.mem.indexOfScalar(T, &self.items, sentinel) orelse length;
        }

        /// View the internal array as a slice whose size was previously set.
        pub fn slice(self: anytype) Span(@TypeOf(&self.items)) {
            return self.items[0..self.len()];
        }
    };
}

test "PaddedArray" {
    const String = PaddedArray(u8, 10, 0);

    var string = String{};
    try std.testing.expectEqual(@as(usize, 0), string.len());
    try std.testing.expectEqual(@as(usize, 10), @TypeOf(string).capacity);
    try std.testing.expectEqualStrings("", string.slice());

    try std.testing.expectError(error.Overflow, String.init("HelloHello!"));

    string = try String.init("Hello");
    try std.testing.expectEqual(@as(usize, 5), string.len());
    try std.testing.expectEqual(@as(usize, 10), @TypeOf(string).capacity);
    try std.testing.expectEqualStrings("Hello", string.slice());

    string = try String.init("HelloHello");
    try std.testing.expectEqual(@as(usize, 10), string.len());
    try std.testing.expectEqual(@as(usize, 10), @TypeOf(string).capacity);
    try std.testing.expectEqualStrings("HelloHello", string.slice());
}

test "PaddedArray.constSlice" {
    const String = PaddedArray(u8, 10, 0);

    // ensure that `.slice()` works on both const and mutable objects
    const string = try String.init("Hello");
    try std.testing.expectEqualStrings("Hello", string.slice());
}

test "Extern PaddedArray" {
    _ = extern struct { name: PaddedArray(u8, 33, 0) };

    comptime {
        std.debug.assert(@sizeOf(PaddedArray(u8, 33, 0)) == 33);
        std.debug.assert(@alignOf(PaddedArray(u8, 33, 0)) == 1);
        std.debug.assert(@sizeOf(PaddedArray(u16, 11, 99)) == 22);
        std.debug.assert(@alignOf(PaddedArray(u16, 11, 99)) == 2);
    }
}
