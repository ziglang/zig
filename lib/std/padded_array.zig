const std = @import("std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;

/// A structure that implements an array where the length is terminated by a sentinel value.
/// This is useful for wrapping external string types or arrays which have an implicit length.
/// The array contains a maximum of `length` elements of type `T`. The length is determined by
/// the first appearance of the `sentinel` value.
pub fn PaddedArray(comptime T: type, comptime length: usize, comptime sentinel: T) type {
    return PaddedArrayExtra(T, length, sentinel, .Auto);
}

/// A structure that implements an array where the length is terminated by a sentinel value.
/// This is useful for wrapping external string types or arrays which have an implicit length.
/// The array contains a maximum of `length` elements of type `T`. The length is determined by
/// the first appearance of the `sentinel` value.
///
/// This variant can define the structure layout, so it can be used with external or packed variants.
pub fn PaddedArrayExtra(comptime T: type, comptime length: usize, comptime sentinel: T, comptime layout: std.builtin.Type.ContainerLayout) type {
    return switch (layout) {
        .Auto => struct {
            pub usingnamespace PaddedArrayImplementation(@This(), T, length, sentinel);
            items: [length]T = [1]T{sentinel} ** length,
        },
        .Packed => packed struct {
            pub usingnamespace PaddedArrayImplementation(@This(), T, length, sentinel);
            items: [length]T = [1]T{sentinel} ** length,
        },
        .Extern => extern struct {
            pub usingnamespace PaddedArrayImplementation(@This(), T, length, sentinel);
            items: [length]T = [1]T{sentinel} ** length,
        },
    };
}

fn PaddedArrayImplementation(comptime Self: type, comptime T: type, comptime length: usize, comptime sentinel: T) type {
    return struct {
        fn Span(comptime Inner: type) type {
            return switch (Inner) {
                *const [length]T => []const T,
                *[length]T => []T,
                else => unreachable,
            };
        }

        /// Returns the maximum number of items in this array.
        pub fn capacity(self: Self) usize {
            _ = self;
            return length;
        }

        /// Returns the number of items in the array before the sentinel appears.
        /// If no sentinel is present, the length of the array is returned.
        pub fn len(self: Self) usize {
            return std.mem.indexOfScalar(T, &self.items, sentinel) orelse length;
        }

        /// View the internal array as a slice whose size was previously set.
        pub fn slice(self: anytype) Span(@TypeOf(&self.items)) {
            return self.items[0..self.len()];
        }

        /// View the internal array as a constant slice whose size was previously set.
        pub fn constSlice(self: *const Self) []const T {
            return self.slice();
        }

        /// Copy the content of an existing slice.
        pub fn fromSlice(m: []const T) error{Overflow}!Self {
            if (m.len > length)
                return error.Overflow;
            var list: Self = .{};
            std.mem.copy(T, &list.items, m);
            return list;
        }

        /// Return the element at index `i` of the slice.
        pub fn get(self: Self, i: usize) T {
            return self.constSlice()[i];
        }

        /// Set the value of the element at index `i` of the slice.
        pub fn set(self: *Self, i: usize, item: T) void {
            self.slice()[i] = item;
        }
    };
}

test "PaddedArray" {
    const String = PaddedArray(u8, 10, 0);

    var string = String{};
    try std.testing.expectEqual(@as(usize, 0), string.len());
    try std.testing.expectEqual(@as(usize, 10), string.capacity());
    try std.testing.expectEqualStrings("", string.slice());
    try std.testing.expectEqualStrings("", string.constSlice());

    try std.testing.expectError(error.Overflow, String.fromSlice("HelloHello!"));

    string = try String.fromSlice("Hello");
    try std.testing.expectEqual(@as(usize, 5), string.len());
    try std.testing.expectEqual(@as(usize, 10), string.capacity());
    try std.testing.expectEqualStrings("Hello", string.slice());
    try std.testing.expectEqualStrings("Hello", string.constSlice());

    string = try String.fromSlice("HelloHello");
    try std.testing.expectEqual(@as(usize, 10), string.len());
    try std.testing.expectEqual(@as(usize, 10), string.capacity());
    try std.testing.expectEqualStrings("HelloHello", string.slice());
    try std.testing.expectEqualStrings("HelloHello", string.constSlice());
}

test "Extern PaddedArray" {
    _ = extern struct { name: PaddedArrayExtra(u8, 33, 0, .Extern) };

    comptime {
        std.debug.assert(@sizeOf(PaddedArrayExtra(u8, 33, 0, .Extern)) == 33);
        std.debug.assert(@alignOf(PaddedArrayExtra(u8, 33, 0, .Extern)) == 1);
        std.debug.assert(@sizeOf(PaddedArrayExtra(u16, 11, 99, .Extern)) == 22);
        std.debug.assert(@alignOf(PaddedArrayExtra(u16, 11, 99, .Extern)) == 2);
    }
}
