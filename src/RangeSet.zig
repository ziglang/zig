const std = @import("std");
const assert = std.debug.assert;
const Order = std.math.Order;

const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");
const Module = @import("Module.zig");
const RangeSet = @This();
const SwitchProngSrc = @import("Module.zig").SwitchProngSrc;

ranges: std.ArrayList(Range),
module: *Module,

pub const Range = struct {
    first: InternPool.Index,
    last: InternPool.Index,
    src: SwitchProngSrc,
};

pub fn init(allocator: std.mem.Allocator, module: *Module) RangeSet {
    return .{
        .ranges = std.ArrayList(Range).init(allocator),
        .module = module,
    };
}

pub fn deinit(self: *RangeSet) void {
    self.ranges.deinit();
}

pub fn add(
    self: *RangeSet,
    first: InternPool.Index,
    last: InternPool.Index,
    src: SwitchProngSrc,
) !?SwitchProngSrc {
    const mod = self.module;
    const ip = &mod.intern_pool;

    const ty = ip.typeOf(first);
    assert(ty == ip.typeOf(last));

    for (self.ranges.items) |range| {
        assert(ty == ip.typeOf(range.first));
        assert(ty == ip.typeOf(range.last));

        if (Value.fromInterned(last).compareScalar(.gte, Value.fromInterned(range.first), Type.fromInterned(ty), mod) and
            Value.fromInterned(first).compareScalar(.lte, Value.fromInterned(range.last), Type.fromInterned(ty), mod))
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
fn lessThan(mod: *Module, a: Range, b: Range) bool {
    const ty = Type.fromInterned(mod.intern_pool.typeOf(a.first));
    return Value.fromInterned(a.first).compareScalar(.lt, Value.fromInterned(b.first), ty, mod);
}

pub fn spans(self: *RangeSet, first: InternPool.Index, last: InternPool.Index) !bool {
    const mod = self.module;
    const ip = &mod.intern_pool;
    assert(ip.typeOf(first) == ip.typeOf(last));

    if (self.ranges.items.len == 0)
        return false;

    std.mem.sort(Range, self.ranges.items, mod, lessThan);

    if (self.ranges.items[0].first != first or
        self.ranges.items[self.ranges.items.len - 1].last != last)
    {
        return false;
    }

    var space: InternPool.Key.Int.Storage.BigIntSpace = undefined;

    var counter = try std.math.big.int.Managed.init(self.ranges.allocator);
    defer counter.deinit();

    // look for gaps
    for (self.ranges.items[1..], 0..) |cur, i| {
        // i starts counting from the second item.
        const prev = self.ranges.items[i];

        // prev.last + 1 == cur.first
        try counter.copy(Value.fromInterned(prev.last).toBigInt(&space, mod));
        try counter.addScalar(&counter, 1);

        const cur_start_int = Value.fromInterned(cur.first).toBigInt(&space, mod);
        if (!cur_start_int.eql(counter.toConst())) {
            return false;
        }
    }

    return true;
}
