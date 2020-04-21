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
        bool_false, // See last_no_payload_tag below.
        // After this, the tag requires a payload.

        ty,
        int_u64,
        int_i64,
        function,
        ref,
        bytes,

        pub const last_no_payload_tag = Tag.bool_false;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;
    };

    pub fn initTag(comptime small_tag: Tag) Value {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = @enumToInt(small_tag) };
    }

    pub fn initPayload(payload: *Payload) Value {
        assert(@enumToInt(payload.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = payload };
    }

    pub fn tag(self: Value) Tag {
        if (self.tag_if_small_enough < Tag.no_payload_count) {
            return @intToEnum(Tag, @intCast(@TagType(Tag), self.tag_if_small_enough));
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn cast(self: Value, comptime T: type) ?*T {
        if (self.tag_if_small_enough < Tag.no_payload_count)
            return null;

        const expected_tag = std.meta.fieldInfo(T, "base").default_value.?.tag;
        if (self.ptr_otherwise.tag != expected_tag)
            return null;

        return @fieldParentPtr(T, "base", self.ptr_otherwise);
    }

    pub fn format(
        self: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        comptime assert(fmt.len == 0);
        switch (self.tag()) {
            .void_type => return out_stream.writeAll("void"),
            .noreturn_type => return out_stream.writeAll("noreturn"),
            .bool_type => return out_stream.writeAll("bool"),
            .usize_type => return out_stream.writeAll("usize"),
            .void_value => return out_stream.writeAll("{}"),
            .noreturn_value => return out_stream.writeAll("unreachable"),
            .bool_true => return out_stream.writeAll("true"),
            .bool_false => return out_stream.writeAll("false"),
            .ty => return self.cast(Payload.Ty).?.ty.format("", options, out_stream),
            .int_u64 => return std.fmt.formatIntValue(self.cast(Payload.Int_u64).?.int, "", options, out_stream),
            .int_i64 => return std.fmt.formatIntValue(self.cast(Payload.Int_i64).?.int, "", options, out_stream),
            .function => return out_stream.writeAll("(function)"),
            .ref => return out_stream.writeAll("(ref)"),
            .bytes => return std.zig.renderStringLiteral(self.cast(Payload.Bytes).?.data, out_stream),
        }
    }

    /// Asserts that the value is representable as an array of bytes.
    /// Copies the value into a freshly allocated slice of memory, which is owned by the caller.
    pub fn toAllocatedBytes(self: Value, allocator: *std.mem.Allocator) error{OutOfMemory}![]u8 {
        if (self.cast(Payload.Bytes)) |bytes| {
            return std.mem.dupe(allocator, u8, bytes.data);
        }
        unreachable;
    }

    /// Asserts that the value is representable as a type.
    pub fn toType(self: Value) Type {
        return switch (self.tag()) {
            .ty => self.cast(Payload.Ty).?.ty,

            .void_type => Type.initTag(.@"void"),
            .noreturn_type => Type.initTag(.@"noreturn"),
            .bool_type => Type.initTag(.@"bool"),
            .usize_type => Type.initTag(.@"usize"),

            .void_value,
            .noreturn_value,
            .bool_true,
            .bool_false,
            .int_u64,
            .int_i64,
            .function,
            .ref,
            .bytes,
            => unreachable,
        };
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
            /// Index into the `fns` array of the `ir.Module`
            index: usize,
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
            data: []const u8,
        };

        pub const Ty = struct {
            base: Payload = Payload{ .tag = .ty },
            ty: Type,
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
