const std = @import("std");

/// Create an interval of type T.
/// See https://en.wikipedia.org/wiki/Interval_(mathematics) for more info.
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

        pub const Endpoint = struct {
            n: ?T,
            open: bool,
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
            if (self.from.n) |_| {} else {
                if (self.to.n) |_| {} else {
                    // handle (-inf, +inf)
                    return true;
                }
                // handle (-inf,
                const to = self.to.n orelse max;
                const right = if (self.to.open) x < to else x <= to;
                return right;
            }
            if (self.to.n) |_| {} else {
                // handle +inf)
                const from = self.from.n orelse min;
                const left = if (self.from.open) x > from else x >= from;
                return left;
            }
            const from = self.from.n orelse min;
            const to = self.to.n orelse max;
            const left = if (self.from.open) x > from else x >= from;
            const right = if (self.to.open) x < to else x <= to;
            return left and right;
        }
    };
}

fn runTest(comptime T: type, from: ?T, to: ?T, left: bool, right: bool) !void {
    var x = Interval(T){
        .from = .{ .n = from, .open = left },
        .to = .{ .n = to, .open = right },
    };
    const inf_left = if (x.from.n) |_| false else true;
    const inf_right = if (x.to.n) |_| false else true;

    try std.testing.expect(x.contains(0) == (inf_left));
    try std.testing.expect(x.contains(1) == (inf_left or !x.from.open));
    try std.testing.expect(x.contains(2) == (true));
    try std.testing.expect(x.contains(3) == (inf_right or !x.to.open));
    try std.testing.expect(x.contains(4) == (inf_right));
}

fn runTestMatrix(left: bool, right: bool) !void {
    inline for (.{ usize, isize, f32, f64 }) |T| {
        try runTest(T, 1, 3, left, right);
        try runTest(T, null, 3, left, right);
        try runTest(T, 1, null, left, right);
        try runTest(T, null, null, left, right);
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
