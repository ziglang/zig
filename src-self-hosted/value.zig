const std = @import("std");

/// This is the raw data, with no bookkeeping, no memory awareness,
/// no de-duplication, and no type system awareness.
/// It's important for this struct to be small.
/// It is not copyable since it may contain references to its inner data.
pub const Value = struct {
    tag: Tag,

    pub const Tag = enum {
        void_type,
        noreturn_type,
        bool_type,
        usize_type,

        void_value,
        noreturn_value,
        bool_true,
        bool_false,

        array_sentinel_0_u8_type,
        single_const_ptr_type,

        int_u64,
        int_i64,
        function,
        ref,
        bytes,
    };

    pub const Int_u64 = struct {
        base: Value = Value{ .tag = .int_u64 },
        int: u64,
    };

    pub const Int_i64 = struct {
        base: Value = Value{ .tag = .int_i64 },
        int: i64,
    };

    pub const Function = struct {
        base: Value = Value{ .tag = .function },
    };

    pub const ArraySentinel0_u8_Type = struct {
        base: Value = Value{ .tag = .array_sentinel_0_u8_type },
        len: u64,
    };

    pub const SingleConstPtrType = struct {
        base: Value = Value{ .tag = .single_const_ptr_type },
        elem_type: *Value,
    };

    pub const Ref = struct {
        base: Value = Value{ .tag = .ref },
        pointee: *MemoryCell,
    };

    pub const Bytes = struct {
        base: Value = Value{ .tag = .bytes },
        data: []u8,
    };
};

pub const MemoryCell = struct {
    parent: Parent,
    contents: *Value,

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
