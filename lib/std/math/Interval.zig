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
    };
}

fn runTest(comptime T: type, from: Interval(T).Endpoint, to: Interval(T).Endpoint) !void {
    var x = Interval(T){ .from = from, .to = to };

    try std.testing.expect(x.contains(0) == (x.from == .Infinity));
    try std.testing.expect(x.contains(1) == (x.from != .Open));
    try std.testing.expect(x.contains(2) == (true));
    try std.testing.expect(x.contains(3) == (x.to != .Open));
    try std.testing.expect(x.contains(4) == (x.to == .Infinity));
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

test "closed closed" {
    try runTestMatrix(false, false);
}

test "open closed" {
    try runTestMatrix(true, false);
}

test "closed open" {
    try runTestMatrix(false, true);
}

test "open open" {
    try runTestMatrix(true, true);
}
