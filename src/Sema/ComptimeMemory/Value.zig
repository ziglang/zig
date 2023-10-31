ty: InternPool.Index,
tag: Tag,
repr: Repr,

comptime {
    switch (builtin.mode) {
        .ReleaseFast, .ReleaseSmall => {
            assert(@sizeOf(InternPool.Index) == 4);
            assert(@sizeOf(Repr) == 4);
            assert(@sizeOf(Tag) == 1);
        },
        .Debug, .ReleaseSafe => {},
    }
}

pub const Tag = enum(u8) {
    /// Represents an value stored in `InternPool`.
    interned,
    /// Represents an error union value that is not an error.
    /// The value is the payload value.
    eu_payload,
    /// Represents an optional value that is not null.
    /// The value is the payload value.
    opt_payload,
    /// The type must be an array, vector, or tuple. The element is this sub
    /// value repeated according to the length provided by the type.
    repeated,
    /// The type must be a slice pointer type.
    slice,
    /// The value is index into ComptimeMemory buffers array.
    bytes,
    /// An instance of a struct, array, or vector.
    /// Each element/field stored as a `Value`.
    /// In the case of sentinel-terminated arrays, the sentinel value *is* stored,
    /// so the slice length will be one more than the type's array length.
    aggregate,
    /// An instance of a union.
    @"union",
};

pub const Repr = union {
    ip_index: InternPool.Index,
    eu_payload: Index,
    opt_payload: Index,
    repeated: Index,
    slice: ComptimeMemory.Slice.Index,
    bytes: ComptimeMemory.Bytes.Index,
    aggregate: ComptimeMemory.Aggregate.Index,
    @"union": ComptimeMemory.Union.Index,
};

pub const Index = enum(u32) { _ };

pub const OptionalIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,
};

const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const Value = @This();
const ConstValue = @import("../../Value.zig");

const InternPool = @import("../../InternPool.zig");
const ComptimeMemory = @import("../ComptimeMemory.zig");
