const std = @import("std");
const assert = std.debug.assert;
const Order = std.math.Order;

const InternPool = @import("InternPool.zig");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const Sema = @import("Sema.zig");
const Zcu = @import("Zcu.zig");
const LazySrcLoc = Zcu.LazySrcLoc;

const RangeSet = @This();

ranges: std.ArrayList(Range),

pub const Range = struct {
    first: InternPool.Index,
    last: InternPool.Index,
    src: LazySrcLoc,
};

pub fn init(allocator: std.mem.Allocator) RangeSet {
    return .{ .ranges = std.ArrayList(Range).init(allocator) };
}

pub fn deinit(self: *RangeSet) void {
    self.ranges.deinit();
}

pub fn add(
    self: *RangeSet,
    first: InternPool.Index,
    last: InternPool.Index,
    src: LazySrcLoc,
    sema: *Sema,
) !?LazySrcLoc {
    const pt = sema.pt;
    for (self.ranges.items) |range| {
        if (try Value.compareHeteroSema(.fromInterned(last), .gte, .fromInterned(range.first), pt) and
            try Value.compareHeteroSema(.fromInterned(first), .lte, .fromInterned(range.last), pt))
        {
            return range.src; // They overlap.
        }
    }

    try self.ranges.append(.{
        .first = first,
        .last = last,
        .src = src,
    });
    return null;
}

/// Assumes a and b do not overlap
fn lessThan(pt: Zcu.PerThread, a: Range, b: Range) bool {
    return Value.compareHeteroSema(.fromInterned(a.first), .lt, .fromInterned(b.first), pt) catch unreachable;
}

pub fn spans(self: *RangeSet, first: InternPool.Index, last: InternPool.Index, sema: *Sema) !bool {
    const pt = sema.pt;

    if (self.ranges.items.len == 0)
        return false;

    std.mem.sort(Range, self.ranges.items, pt, lessThan);

    const ranges_start = self.ranges.items[0].first;
    const ranges_end = self.ranges.items[self.ranges.items.len - 1].last;

    if (try Value.compareHeteroSema(.fromInterned(ranges_start), .neq, .fromInterned(first), pt) or
        try Value.compareHeteroSema(.fromInterned(ranges_end), .neq, .fromInterned(last), pt))
    {
        return false;
    }

    // Iterate over ranges
    var space: Value.BigIntSpace = undefined;

    var counter = try std.math.big.int.Managed.init(self.ranges.allocator);
    defer counter.deinit();

    // Look for gaps
    for (self.ranges.items[1..], 0..) |cur, i| {
        // i starts counting from the second item.
        const prev = self.ranges.items[i];

        // prev.last + 1 == cur.first
        try counter.copy(try Value.fromInterned(prev.last).toBigIntSema(&space, pt));
        try counter.addScalar(&counter, 1);

        const cur_start_int = try Value.fromInterned(cur.first).toBigIntSema(&space, pt);
        if (!cur_start_int.eql(counter.toConst())) {
            return false;
        }
    }

    return true;
}
