const std = @import("std");
const Order = std.math.Order;
const Value = @import("value.zig").Value;
const RangeSet = @This();

ranges: std.ArrayList(Range),

pub const Range = struct {
    start: Value,
    end: Value,
    src: usize,
};

pub fn init(allocator: *std.mem.Allocator) RangeSet {
    return .{
        .ranges = std.ArrayList(Range).init(allocator),
    };
}

pub fn deinit(self: *RangeSet) void {
    self.ranges.deinit();
}

pub fn add(self: *RangeSet, start: Value, end: Value, src: usize) !?usize {
    for (self.ranges.items) |range| {
        if ((start.compare(.gte, range.start) and start.compare(.lte, range.end)) or
            (end.compare(.gte, range.start) and end.compare(.lte, range.end)))
        {
            // ranges overlap
            return range.src;
        }
    }
    try self.ranges.append(.{
        .start = start,
        .end = end,
        .src = src,
    });
    return null;
}

/// Assumes a and b do not overlap
fn lessThan(_: void, a: Range, b: Range) bool {
    return a.start.compare(.lt, b.start);
}

pub fn spans(self: *RangeSet, start: Value, end: Value) !bool {
    std.sort.sort(Range, self.ranges.items, {}, lessThan);

    if (!self.ranges.items[0].start.eql(start) or
        !self.ranges.items[self.ranges.items.len - 1].end.eql(end))
    {
        return false;
    }

    var space: Value.BigIntSpace = undefined;

    var counter = try std.math.big.int.Managed.init(self.ranges.allocator);
    defer counter.deinit();

    // look for gaps
    for (self.ranges.items[1..]) |cur, i| {
        // i starts counting from the second item.
        const prev = self.ranges.items[i];

        // prev.end + 1 == cur.start
        try counter.copy(prev.end.toBigInt(&space));
        try counter.addScalar(counter.toConst(), 1);

        const cur_start_int = cur.start.toBigInt(&space);
        if (!cur_start_int.eq(counter.toConst())) {
            return false;
        }
    }

    return true;
}
