const std = @import("std");
const Type = @import("type.zig").Type;
const log2 = std.math.log2;
const assert = std.debug.assert;

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// It's important for this struct to be small.
/// This union takes advantage of the fact that the first page of memory
/// is unmapped, giving us 4096 possible enum tags that have no payload.
pub const Value = extern union {
    /// If the tag value is less than Tag.no_payload_count, then no pointer
    /// dereference is needed.
    tag_if_small_enough: usize,
    ptr_otherwise: *Payload,

    pub const Tag = enum {
        // The first section of this enum are tags that require no payload.
        void_type,
        noreturn_type,
        bool_type,
        usize_type,
        void_value,
        noreturn_value,
        bool_true,
        bool_false,
        // Bump this when adding items above.
        pub const last_no_payload_tag = Tag.bool_false;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
        // After this, the tag requires a payload.

        ty,
        int_u64,
        int_i64,
        function,
        ref,
        bytes,
    };

    pub fn initTag(comptime tag: Tag) Value {
        comptime assert(@enumToInt(tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = @enumToInt(tag) };
    }

    pub fn initPayload(payload: *Payload) Value {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Value) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(self.tag_if_small_enough);
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    /// This type is not copyable since it may contain pointers to its inner data.
    pub const Payload = struct {
        tag: Tag,

        pub const Int_u64 = struct {
            base: Payload = Payload{ .tag = .int_u64 },
            int: u64,
        };

        pub const Int_i64 = struct {
            base: Payload = Payload{ .tag = .int_i64 },
            int: i64,
        };

        pub const Function = struct {
            base: Payload = Payload{ .tag = .function },
        };

        pub const ArraySentinel0_u8_Type = struct {
            base: Payload = Payload{ .tag = .array_sentinel_0_u8_type },
            len: u64,
        };

        pub const SingleConstPtrType = struct {
            base: Payload = Payload{ .tag = .single_const_ptr_type },
            elem_type: *Type,
        };

        pub const Ref = struct {
            base: Payload = Payload{ .tag = .ref },
            pointee: *MemoryCell,
        };

        pub const Bytes = struct {
            base: Payload = Payload{ .tag = .bytes },
            data: []u8,
        };

        pub const Ty = struct {
            base: Payload = Payload{ .tag = .fully_qualified_type },
            ptr: *Type,
        };
    };
};

/// This is the heart of resource management of the Zig compiler. The Zig compiler uses
/// stop-the-world mark-and-sweep garbage collection during compilation to manage the resources
/// associated with evaluating compile-time code and semantic analysis. Each `MemoryCell` represents
/// a root.
pub const MemoryCell = struct {
    parent: Parent,
    contents: Value,

    pub const Parent = union(enum) {
        none,
        struct_field: struct {
            struct_base: *MemoryCell,
            field_index: usize,
        },
        array_elem: struct {
            array_base: *MemoryCell,
            elem_index: usize,
        },
        union_field: *MemoryCell,
        err_union_code: *MemoryCell,
        err_union_payload: *MemoryCell,
        optional_payload: *MemoryCell,
        optional_flag: *MemoryCell,
    };
};
