const std = @import("../std.zig");

/// Create an interval of type T.
/// See https://en.wikipedia.org/wiki/Interval_(mathematics) for more info.
/// Initializer is responsible for ensuring from <= to
pub fn Interval(comptime T: type) type {
    comptime std.debug.assert(std.meta.trait.isNumber(T)); // Interval must be instantiated with a number type.
    return struct {
        /// The left hand side of the Interval.
        /// n as null here represents infinity.
        /// open determines if the interval should be open (exclusive) or closed (inclusive). 
        from: Endpoint,
        /// The right hand side of the Interval.
        /// n as null here represent infinity.
        /// open determines if the interval should be open (exclusive) or closed (inclusive). 
        to: Endpoint,

        pub const Endpoint = union(enum) {
            Infinity,
            Closed: T,
            Open: T,

            pub fn n(self: Endpoint) ?T {
                return switch (self) {
                    .Infinity => null,
                    .Closed => |x| x,
                    .Open => |x| x,
                };
            }

            pub fn eql(self: Endpoint, other: Endpoint) bool {
                if (self == .Infinity and other == .Infinity) {
                    return true;
                }
                if (self == .Closed and other == .Closed) {
                    return self.Closed == other.Closed;
                }
                if (self == .Open and other == .Open) {
                    return self.Open == other.Open;
                }
                return false;
            }
        };

        pub const Self = @This();

        // TODO: comptime_int and comptime_float support wants self parameter to have the comptime keyword
        pub fn contains(self: Self, x: T) bool {
            const min = switch (@typeInfo(T)) {
                .Int => std.math.minInt(T),
                // .ComptimeInt => x - 2,
                .Float => -std.math.inf(T),
                // .ComptimeFloat => x - 2,
                else => unreachable,
            };
            const max = switch (@typeInfo(T)) {
                .Int => std.math.maxInt(T),
                // .ComptimeInt => x + 2,
                .Float => std.math.inf(T),
                // .ComptimeFloat => x + 2,
                else => unreachable,
            };
            if (self.from == .Infinity) {
                if (self.to == .Infinity) {
                    // handle (-inf, +inf)
                    return true;
                }
                // handle (-inf,
                const to = self.to.n() orelse max;
                const right = if (self.to == .Open) x < to else x <= to;
                return right;
            }
            if (self.to == .Infinity) {
                // handle +inf)
                const from = self.from.n() orelse min;
                const left = if (self.from == .Open) x > from else x >= from;
                return left;
            }
            const from = self.from.n() orelse min;
            const to = self.to.n() orelse max;
            const left = if (self.from == .Open) x > from else x >= from;
            const right = if (self.to == .Open) x < to else x <= to;
            return left and right;
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.from.eql(other.from) and self.to.eql(other.to);
        }
    };
}

fn runTest(comptime T: type, from: Interval(T).Endpoint, to: Interval(T).Endpoint) !void {
    var x = Interval(T){ .from = from, .to = to };

    try std.testing.expectEqual(x.contains(0), x.from == .Infinity);
    try std.testing.expectEqual(x.contains(1), x.from != .Open);
    try std.testing.expectEqual(x.contains(2), true);
    try std.testing.expectEqual(x.contains(3), x.to != .Open);
    try std.testing.expectEqual(x.contains(4), x.to == .Infinity);
}

fn runTestMatrix(left: bool, right: bool) !void {
    inline for (.{ usize, isize, f32, f64 }) |T| {
        const l: Interval(T).Endpoint = if (left) .{ .Open = 1 } else .{ .Closed = 1 };
        const r: Interval(T).Endpoint = if (right) .{ .Open = 3 } else .{ .Closed = 3 };
        const i: Interval(T).Endpoint = .{ .Infinity = {} };
        try runTest(T, l, r);
        try runTest(T, i, r);
        try runTest(T, l, i);
        try runTest(T, i, i);
    }
}

test "contains: closed closed" {
    try runTestMatrix(false, false);
}

test "contains: open closed" {
    try runTestMatrix(true, false);
}

test "contains: closed open" {
    try runTestMatrix(false, true);
}

test "contains: open open" {
    try runTestMatrix(true, true);
}

test "contains: u8 edge" {
    const a = Interval(u8){ .from = .{ .Closed = 0 }, .to = .{ .Closed = 255 } };
    try std.testing.expect(a.contains(0));
    try std.testing.expect(a.contains(1));
    try std.testing.expect(a.contains(254));
    try std.testing.expect(a.contains(255));

    const b = Interval(u8){ .from = .{ .Open = 0 }, .to = .{ .Open = 255 } };
    try std.testing.expect(!b.contains(0));
    try std.testing.expect(b.contains(1));
    try std.testing.expect(b.contains(254));
    try std.testing.expect(!b.contains(255));
}

test "contains: i8 edge" {
    const a = Interval(i8){ .from = .{ .Closed = -128 }, .to = .{ .Closed = 127 } };
    try std.testing.expect(a.contains(-128));
    try std.testing.expect(a.contains(-127));
    try std.testing.expect(a.contains(126));
    try std.testing.expect(a.contains(127));

    const b = Interval(i8){ .from = .{ .Open = -128 }, .to = .{ .Open = 127 } };
    try std.testing.expect(!b.contains(-128));
    try std.testing.expect(b.contains(-127));
    try std.testing.expect(b.contains(126));
    try std.testing.expect(!b.contains(127));
}

test "contains: u0 edge" {
    const a = Interval(u0){ .from = .{ .Closed = 0 }, .to = .{ .Closed = 0 } };
    try std.testing.expect(a.contains(0));

    const b = Interval(u0){ .from = .{ .Open = 0 }, .to = .{ .Closed = 0 } };
    try std.testing.expect(!b.contains(0));

    const c = Interval(u0){ .from = .{ .Closed = 0 }, .to = .{ .Open = 0 } };
    try std.testing.expect(!c.contains(0));

    const d = Interval(u0){ .from = .{ .Open = 0 }, .to = .{ .Open = 0 } };
    try std.testing.expect(!d.contains(0));
}

test "contains: u1 edge" {
    const a = Interval(u1){ .from = .{ .Closed = 0 }, .to = .{ .Closed = 1 } };
    try std.testing.expect(a.contains(0));
    try std.testing.expect(a.contains(1));

    const b = Interval(u1){ .from = .{ .Open = 0 }, .to = .{ .Closed = 1 } };
    try std.testing.expect(!b.contains(0));
    try std.testing.expect(b.contains(1));

    const c = Interval(u1){ .from = .{ .Closed = 0 }, .to = .{ .Open = 1 } };
    try std.testing.expect(c.contains(0));
    try std.testing.expect(!c.contains(1));

    const d = Interval(u1){ .from = .{ .Open = 0 }, .to = .{ .Open = 1 } };
    try std.testing.expect(!d.contains(0));
    try std.testing.expect(!d.contains(1));
}

test "contains: i1 edge" {
    const a = Interval(i1){ .from = .{ .Closed = -1 }, .to = .{ .Closed = 0 } };
    try std.testing.expect(a.contains(-1));
    try std.testing.expect(a.contains(0));

    const b = Interval(i1){ .from = .{ .Open = -1 }, .to = .{ .Closed = 0 } };
    try std.testing.expect(!b.contains(-1));
    try std.testing.expect(b.contains(0));

    const c = Interval(i1){ .from = .{ .Closed = -1 }, .to = .{ .Open = 0 } };
    try std.testing.expect(c.contains(-1));
    try std.testing.expect(!c.contains(0));

    const d = Interval(i1){ .from = .{ .Open = -1 }, .to = .{ .Open = 0 } };
    try std.testing.expect(!d.contains(-1));
    try std.testing.expect(!d.contains(0));
}

test "eql" {
    const a = Interval(i1){ .from = .{ .Closed = -1 }, .to = .{ .Closed = 0 } };
    const b = Interval(i1){ .from = .{ .Closed = -1 }, .to = .{ .Closed = 0 } };

    try std.testing.expect(a.eql(b));
}
