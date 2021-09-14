const std = @import("std");
const Order = std.math.Order;
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const RangeSet = @This();
const SwitchProngSrc = @import("Module.zig").SwitchProngSrc;

ranges: std.ArrayList(Range),

pub const Range = struct {
    first: Value,
    last: Value,
    src: SwitchProngSrc,
};

pub fn init(allocator: *std.mem.Allocator) RangeSet {
    return .{
        .ranges = std.ArrayList(Range).init(allocator),
    };
}

pub fn deinit(self: *RangeSet) void {
    self.ranges.deinit();
}

pub fn add(
    self: *RangeSet,
    first: Value,
    last: Value,
    ty: Type,
    src: SwitchProngSrc,
) !?SwitchProngSrc {
    for (self.ranges.items) |range| {
        if (last.compare(.gte, range.first, ty) and first.compare(.lte, range.last, ty)) {
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
fn lessThan(ty: Type, a: Range, b: Range) bool {
    return a.first.compare(.lt, b.first, ty);
}

pub fn spans(self: *RangeSet, first: Value, last: Value, ty: Type) !bool {
    if (self.ranges.items.len == 0)
        return false;

    std.sort.sort(Range, self.ranges.items, ty, lessThan);

    if (!self.ranges.items[0].first.eql(first, ty) or
        !self.ranges.items[self.ranges.items.len - 1].last.eql(last, ty))
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

        // prev.last + 1 == cur.first
        try counter.copy(prev.last.toBigInt(&space));
        try counter.addScalar(counter.toConst(), 1);

        const cur_start_int = cur.first.toBigInt(&space);
        if (!cur_start_int.eq(counter.toConst())) {
            return false;
        }
    }

    return true;
}
