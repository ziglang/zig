/// The index points into `value_map_values`.
value_map: std.AutoArrayHashMapUnmanaged(Zir.Inst.Index, void) = .{},
value_map_values: std.MultiArrayList(Value) = .{},

// The following fields are used by the untagged union of Value:

/// Corresponds to `Value.Index`
value_list: std.MultiArrayList(Value) = .{},
/// Corresponds to `Slice.Index`
slice_list: std.ArrayListUnmanaged(Slice) = .{},
/// Corresponds to `Bytes.Index`
bytes_list: std.ArrayListUnmanaged(Bytes) = .{},
/// Corresponds to `Aggregate.Index`
aggregate_list: std.ArrayListUnmanaged(Aggregate) = .{},
/// Corresponds to `Union.Index`
union_list: std.ArrayListUnmanaged(Union) = .{},

pub const Value = @import("ComptimeMemory/Value.zig");

pub const Bytes = struct {
    /// The full slice of data owned by the allocation backing this value.
    memory_island: []u8,
    start: usize,
    /// Includes the sentinel, if any.
    len: usize,

    pub const Index = enum(u32) { _ };
};

pub const Slice = struct {
    ptr: Value,
    len: Value,

    pub const Index = enum(u32) { _ };
};

pub const Aggregate = struct {
    start: Value.Index,
    len: u32,

    pub const Index = enum(u32) { _ };
};

pub const Union = struct {
    /// none means undefined tag.
    tag: Value.OptionalIndex,
    val: Value,

    pub const Index = enum(u32) { _ };
};

pub const RuntimeIndex = enum(u32) {
    zero = 0,
    comptime_field_ptr = std.math.maxInt(u32),
    _,

    pub fn increment(ri: *RuntimeIndex) void {
        ri.* = @enumFromInt(@intFromEnum(ri.*) + 1);
    }
};

const std = @import("std");
const Zir = @import("../Zir.zig");
