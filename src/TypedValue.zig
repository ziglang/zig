const std = @import("std");
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const Allocator = std.mem.Allocator;
const TypedValue = @This();

ty: Type,
val: Value,

/// Memory management for TypedValue. The main purpose of this type
/// is to be small and have a deinit() function to free associated resources.
pub const Managed = struct {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    typed_value: TypedValue,
    /// If this is `null` then there is no memory management needed.
    arena: ?*std.heap.ArenaAllocator.State = null,

    pub fn deinit(self: *Managed, allocator: *Allocator) void {
        if (self.arena) |a| a.promote(allocator).deinit();
        self.* = undefined;
    }
};

/// Assumes arena allocation. Does a recursive copy.
pub fn copy(self: TypedValue, arena: *Allocator) error{OutOfMemory}!TypedValue {
    return TypedValue{
        .ty = try self.ty.copy(arena),
        .val = try self.val.copy(arena),
    };
}

pub fn eql(a: TypedValue, b: TypedValue) bool {
    if (!a.ty.eql(b.ty)) return false;
    return a.val.eql(b.val, a.ty);
}

pub fn hash(tv: TypedValue, hasher: *std.hash.Wyhash) void {
    return tv.val.hash(tv.ty, hasher);
}
