const std = @import("std");
const mem = std.mem;
const panic = std.debug.panic;

fn AssertionsForType(comptime T: type) type {
    const info = @typeInfo(T);

    return switch (info) {
        .Void,
        .Bool,
            => void,

        .Type
            => ComptimeIdentityAssertions(type),

        .ComptimeInt,
        .ComptimeFloat
            => ComptimeComparisonAssertions(T),

        .Enum
            => IdentityAssertions(T),

        .Int,
        .Float
            => ComparisonAssertions(T),

        .Array
            => SliceAssertions(info.Array.child),

        .Pointer
            => switch (info.Pointer.size) {
                .One => AssertionsForType(info.Pointer.child),
                .Slice => SliceAssertions(info.Pointer.child),
                else => @compileError("unsupported pointer type " ++ @tagName(info.Pointer.size) ++ " for type " ++ @typeName(T)),
            },

        else
            => @compileError("unsupported type " ++ @typeName(T) ++ " in assertions"),
    };
}

/// This function is intended to be used only in tests. When `actual` is false, the test fails.
/// A message is printed to stderr and then abort is called.
///
/// If a value other than a `bool` is given, an assertions object is created for
/// the type of the given value with assertion functions accepting an expected
/// value.
pub fn expect(actual: var) ret: {
    // TODO: Find a better way to fix the following error on `AssertionsForType(@TypeOf(actual))`:
    // error: evaluation exceeded 1002 backwards branches
    @setEvalBranchQuota(2000);

    break :ret AssertionsForType(@TypeOf(actual));
} {
    const T = @TypeOf(actual);
    const info = @typeInfo(T);

    switch (info) {
        .Void,
        .NoReturn
            => {},

        .Bool
            => {
                if (!actual) {
                    @panic("test failure");
                }
            },

        .Type
            => return ComptimeIdentityAssertions(type).init(actual),

        .ComptimeInt,
        .ComptimeFloat
            => return ComptimeComparisonAssertions(T).init(actual),

        .Enum
            => return IdentityAssertions(T).init(actual),

        .Int,
        .Float
            => return ComparisonAssertions(T).init(actual),

        .Array
            => return SliceAssertions(info.Array.child).init(actual[0..]),

        .Pointer
            => return switch (info.Pointer.size) {
                .One => expect(actual.*),
                .Slice => SliceAssertions(info.Pointer.child).init(actual),
                else => unreachable,
            },

        else
            => unreachable,
    }
}

/// Object for identity assertions at compile time.
pub fn ComptimeIdentityAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,

        inline fn init(comptime actual: T) Self {
            return .{ .actual = actual, };
        }

        /// Asserts that the actual value is equal to the expected value.
        pub fn toBe(comptime self: Self, comptime expected: T) void {
            if (expected != self.actual) {
                panic("expected {} to be {}", .{ self.actual, expected });
            }
        }

        /// Asserts that the actual value is not equal to the expected value.
        pub fn toNotBe(comptime self: Self, comptime unexpected: T) void {
            if (unexpected == self.actual) {
                panic("expected {} to not be {}", .{ self.actual, unexpected });
            }
        }
    };
}

/// Object for comparison assertions at compile time.
pub fn ComptimeComparisonAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,
        identity: ComptimeIdentityAssertions(T),

        inline fn init(comptime actual: T) Self {
            return .{
                .actual = actual,
                .identity = ComptimeIdentityAssertions(T).init(actual),
            };
        }

        /// See ComptimeIdentityAssertions
        pub inline fn toBe(comptime self: Self, comptime expected: T) void {
            self.identity.toBe(expected);
        }

        /// See ComptimeIdentityAssertions
        pub inline fn toNotBe(comptime self: Self, comptime unexpected: T) void {
            self.identity.toNotBe(unexpected);
        }

        /// Asserts that the actual value is around an expected value with a margin of error.
        pub fn toBeAround(comptime self: Self, comptime expected: T, comptime delta: T) void {
            const abs_delta = if (delta < 0) -delta else delta;

            if (self.actual < expected - abs_delta or self.actual > expected + abs_delta) {
                panic("expected {} to be around {} with delta {}", .{ self.actual, expected, abs_delta });
            }
        }

        /// Asserts that the actual value is not around an expected value with a margin of error.
        pub fn toNotBeAround(comptime self: Self, comptime unexpected: T, comptime delta: T) void {
            const abs_delta = if (delta < 0) -delta else delta;

            if (self.actual >= unexpected - abs_delta and self.actual <= unexpected + abs_delta) {
                panic("expected {} to not be around {} with delta {}", .{ self.actual, expected, abs_delta });
            }
        }
    };
}

/// Object for identity assertions.
pub fn IdentityAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,

        inline fn init(actual: T) Self {
            return .{ .actual = actual, };
        }

        /// Asserts that the actual value is equal to the expected value.
        pub fn toBe(self: Self, expected: T) void {
            if (expected != self.actual) {
                panic("expected {} to be {}", .{ self.actual, expected });
            }
        }

        /// Asserts that the actual value is not equal to the expected value.
        pub fn toNotBe(self: Self, unexpected: T) void {
            if (self.actual == unexpected) {
                panic("expected {} to not be {}", .{ self.actual, unexpected });
            }
        }
    };
}

/// Object for comparison assertions
pub fn ComparisonAssertions(comptime T: type) type {
    return struct {
        const Self = @This();

        actual: T,
        identity: IdentityAssertions(T),

        inline fn init(actual: T) Self {
            return .{
                .actual = actual,
                .identity = IdentityAssertions(T).init(actual),
            };
        }

        /// See IdentityAssertions
        pub inline fn toBe(self: Self, expected: T) void {
            return self.identity.toBe(expected);
        }

        /// See IdentityAssertions
        pub inline fn toNotBe(self: Self, unexpected: T) void {
            return self.identity.toNotBe(unexpected);
        }

        /// Asserts that the actual value is around an expected value with a margin of error.
        pub fn toBeAround(self: Self, expected: T, delta: T) void {
            const abs_delta = if (delta < 0) -delta else delta;

            if (self.actual < expected - abs_delta or self.actual > expected + abs_delta) {
                panic("expected {} to be around {} with delta {}", .{ self.actual, expected, abs_delta });
            }
        }

        /// Asserts that the actual value is not around an expected value with a margin of error.
        pub fn toNotBeAround(self: Self, unexpected: T, delta: T) void {
            const abs_delta = if (delta < 0) -delta else delta;

            if (self.actual >= unexpected - abs_delta and self.actual <= unexpected + abs_delta) {
                panic("expected {} to not be around {} with delta {}", .{ self.actual, unexpected, abs_delta });
            }
        }
    };
}

/// Object for slice assertions.
pub fn SliceAssertions(comptime Element: type) type {
    return struct {
        const Self = @This();

        actual: []const Element,

        inline fn init(actual: []const Element) Self {
            return .{ .actual = actual, };
        }

        /// Asserts that 2 slices hold the same values in the same order.
        pub fn toBe(self: Self, expected: []const Element) void {
            if (!mem.eql(Element, expected, self.actual)) {
                panic("expected `{}` to be `{}`", .{ self.actual, expected });
            }
        }

        /// Asserts that 2 slices do not hold the same values in the same order.
        pub fn toNotBe(self: Self, unexpected: []const Element) void {
            if (mem.eql(Element, unexpected, self.actual)) {
                panic("expected `{}` to not be `{}`", .{ self.actual, unexpected });
            }
        }

        /// Asserts that a slice has the given length.
        pub fn toHaveLength(self: Self, length: usize) void {
            if (self.actual.len != length) {
                panic("expected `{}` to have a length of {}", .{ self.actual, length });
            }
        }

        /// Asserts that the given needle can be found in the slice.
        pub fn toContainSlice(self: Self, needle: []const Element) void {
            if (mem.indexOf(Element, self.actual, needle) == null) {
                panic("expected `{}` to contain subslice `{}`", .{ self.actual, needle });
            }
        }
    };
}

test "backward compatible expect" {
    expect(true);
    expect(@TypeOf(expect(true))).toBe(void);
}

test "comptime identity assertions" {
    expect(u8).toBe(u8);
    expect(std.ArrayList([]const u8)).toNotBe([]const u8);
}

test "comptime comparison assertions" {
    expect(42).toBe(42);
    expect(33.3).toNotBe(30);

    expect(33.3).toBeAround(33, 0.5);
    expect(10).toNotBeAround(5, 2);
}

test "identity assertions" {
    const Animal = enum {
        Dog,
        Cat,
        Bird,
    };

    expect(Animal.Dog).toBe(.Dog);
    expect(Animal.Cat).toNotBe(.Bird);
}

test "comparison assertions" {
    expect(@intCast(i32, -3)).toBeAround(-2, 2);
    expect(@floatCast(f32, 3.33333)).toBeAround(3.33, 0.005);

    expect(@intCast(i32, -3)).toNotBeAround(0, 1);
}

test "slice assertions" {
    expect("zig").toBe("zig");
    expect("zag").toNotBe("zig");

    expect("andrew").toHaveLength(6);

    var zig_utf32 = [_:0]u32{ 0x7a, 0x69, 0x67 };
    expect(zig_utf32).toBe(&[_]u32{ 0x7a, 0x69, 0x67 });
}
