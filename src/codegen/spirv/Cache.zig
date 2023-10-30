//! This file implements an InternPool-like structure that caches
//! SPIR-V types and constants. Instead of generating type and
//! constant instructions directly, we first keep a representation
//! in a compressed database. This is then only later turned into
//! actual SPIR-V instructions.
//! Note: This cache is insertion-ordered. This means that we
//! can materialize the SPIR-V instructions in the proper order,
//! as SPIR-V requires that the type is emitted before use.
//! Note: According to SPIR-V spec section 2.8, Types and Variables,
//! non-pointer non-aggrerate types (which includes matrices and
//! vectors) must have a _unique_ representation in the final binary.

const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Section = @import("Section.zig");
const Module = @import("Module.zig");

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const IdResult = spec.IdResult;
const StorageClass = spec.StorageClass;

const InternPool = @import("../../InternPool.zig");

const Self = @This();

map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},

string_bytes: std.ArrayListUnmanaged(u8) = .{},
strings: std.AutoArrayHashMapUnmanaged(void, u32) = .{},

recursive_ptrs: std.AutoHashMapUnmanaged(Ref, void) = .{},

const Item = struct {
    tag: Tag,
    /// The result-id that this item uses.
    result_id: IdResult,
    /// The Tag determines how this should be interpreted.
    data: u32,
};

const Tag = enum {
    // -- Types
    /// Simple type that has no additional data.
    /// data is SimpleType.
    type_simple,
    /// Signed integer type
    /// data is number of bits
    type_int_signed,
    /// Unsigned integer type
    /// data is number of bits
    type_int_unsigned,
    /// Floating point type
    /// data is number of bits
    type_float,
    /// Vector type
    /// data is payload to VectorType
    type_vector,
    /// Array type
    /// data is payload to ArrayType
    type_array,
    /// Function (proto)type
    /// data is payload to FunctionType
    type_function,
    // /// Pointer type in the CrossWorkgroup storage class
    // /// data is child type
    // type_ptr_generic,
    // /// Pointer type in the CrossWorkgroup storage class
    // /// data is child type
    // type_ptr_crosswgp,
    // /// Pointer type in the Function storage class
    // /// data is child type
    // type_ptr_function,
    /// Simple pointer type that does not have any decorations.
    /// data is payload to SimplePointerType
    type_ptr_simple,
    /// A forward declaration for a pointer.
    /// data is ForwardPointerType
    type_fwd_ptr,
    /// Simple structure type that does not have any decorations.
    /// data is payload to SimpleStructType
    type_struct_simple,
    /// Simple structure type that does not have any decorations, but does
    /// have member names trailing.
    /// data is payload to SimpleStructType
    type_struct_simple_with_member_names,
    /// Opaque type.
    /// data is name string.
    type_opaque,

    // -- Values
    /// Value of type u8
    /// data is value
    uint8,
    /// Value of type u32
    /// data is value
    uint32,
    // TODO: More specialized tags here.
    /// Integer value for signed values that are smaller than 32 bits.
    /// data is pointer to Int32
    int_small,
    /// Integer value for unsigned values that are smaller than 32 bits.
    /// data is pointer to UInt32
    uint_small,
    /// Integer value for signed values that are beteen 32 and 64 bits.
    /// data is pointer to Int64
    int_large,
    /// Integer value for unsinged values that are beteen 32 and 64 bits.
    /// data is pointer to UInt64
    uint_large,
    /// Value of type f16
    /// data is value
    float16,
    /// Value of type f32
    /// data is value
    float32,
    /// Value of type f64
    /// data is payload to Float16
    float64,
    /// Undefined value
    /// data is type
    undef,
    /// Null value
    /// data is type
    null,
    /// Bool value that is true
    /// data is (bool) type
    bool_true,
    /// Bool value that is false
    /// data is (bool) type
    bool_false,

    const SimpleType = enum { void, bool };

    const VectorType = Key.VectorType;
    const ArrayType = Key.ArrayType;

    // Trailing:
    // - [param_len]Ref: parameter types.
    const FunctionType = struct {
        param_len: u32,
        return_type: Ref,
    };

    const SimplePointerType = struct {
        storage_class: StorageClass,
        child_type: Ref,
        fwd: Ref,
    };

    const ForwardPointerType = struct {
        storage_class: StorageClass,
        zig_child_type: InternPool.Index,
    };

    /// Trailing:
    /// - [members_len]Ref: Member types.
    /// - [members_len]String: Member names, -- ONLY if the tag is type_struct_simple_with_member_names
    const SimpleStructType = struct {
        /// (optional) The name of the struct.
        name: String,
        /// Number of members that this struct has.
        members_len: u32,
    };

    const Float64 = struct {
        // Low-order 32 bits of the value.
        low: u32,
        // High-order 32 bits of the value.
        high: u32,

        fn encode(value: f64) Float64 {
            const bits = @as(u64, @bitCast(value));
            return .{
                .low = @truncate(bits),
                .high = @truncate(bits >> 32),
            };
        }

        fn decode(self: Float64) f64 {
            const bits = @as(u64, self.low) | (@as(u64, self.high) << 32);
            return @bitCast(bits);
        }
    };

    const Int32 = struct {
        ty: Ref,
        value: i32,
    };

    const UInt32 = struct {
        ty: Ref,
        value: u32,
    };

    const UInt64 = struct {
        ty: Ref,
        low: u32,
        high: u32,

        fn encode(ty: Ref, value: u64) Int64 {
            return .{
                .ty = ty,
                .low = @truncate(value),
                .high = @truncate(value >> 32),
            };
        }

        fn decode(self: UInt64) u64 {
            return @as(u64, self.low) | (@as(u64, self.high) << 32);
        }
    };

    const Int64 = struct {
        ty: Ref,
        low: u32,
        high: u32,

        fn encode(ty: Ref, value: i64) Int64 {
            return .{
                .ty = ty,
                .low = @truncate(@as(u64, @bitCast(value))),
                .high = @truncate(@as(u64, @bitCast(value)) >> 32),
            };
        }

        fn decode(self: Int64) i64 {
            return @as(i64, @bitCast(@as(u64, self.low) | (@as(u64, self.high) << 32)));
        }
    };
};

pub const Ref = enum(u32) { _ };

/// This union represents something that can be interned. This includes
/// types and constants. This structure is used for interfacing with the
/// database: Values described for this structure are ephemeral and stored
/// in a more memory-efficient manner internally.
pub const Key = union(enum) {
    // -- Types
    void_type,
    bool_type,
    int_type: IntType,
    float_type: FloatType,
    vector_type: VectorType,
    array_type: ArrayType,
    function_type: FunctionType,
    ptr_type: PointerType,
    fwd_ptr_type: ForwardPointerType,
    struct_type: StructType,
    opaque_type: OpaqueType,

    // -- values
    int: Int,
    float: Float,
    undef: Undef,
    null: Null,
    bool: Bool,

    pub const IntType = std.builtin.Type.Int;
    pub const FloatType = std.builtin.Type.Float;

    pub const VectorType = struct {
        component_type: Ref,
        component_count: u32,
    };

    pub const ArrayType = struct {
        /// Child type of this array.
        element_type: Ref,
        /// Reference to a constant.
        length: Ref,
        /// Type has the 'ArrayStride' decoration.
        /// If zero, no stride is present.
        stride: u32 = 0,
    };

    pub const FunctionType = struct {
        return_type: Ref,
        parameters: []const Ref,
    };

    pub const PointerType = struct {
        storage_class: StorageClass,
        child_type: Ref,
        fwd: Ref,
        // TODO: Decorations:
        // - Alignment
        // - ArrayStride,
        // - MaxByteOffset,
    };

    pub const ForwardPointerType = struct {
        zig_child_type: InternPool.Index,
        storage_class: StorageClass,
    };

    pub const StructType = struct {
        // TODO: Decorations.
        /// The name of the structure. Can be `.none`.
        name: String = .none,
        /// The type of each member.
        member_types: []const Ref,
        /// Name for each member. May be omitted.
        member_names: ?[]const String = null,

        fn memberNames(self: @This()) []const String {
            return if (self.member_names) |member_names| member_names else &.{};
        }
    };

    pub const OpaqueType = struct {
        name: String = .none,
    };

    pub const Int = struct {
        /// The type: any bitness integer.
        ty: Ref,
        /// The actual value. Only uint64 and int64 types
        /// are available here: Smaller types should use these
        /// fields.
        value: Value,

        pub const Value = union(enum) {
            uint64: u64,
            int64: i64,
        };

        /// Turns this value into the corresponding 32-bit literal, 2s complement signed.
        fn toBits32(self: Int) u32 {
            return switch (self.value) {
                .uint64 => |val| @intCast(val),
                .int64 => |val| if (val < 0) @bitCast(@as(i32, @intCast(val))) else @intCast(val),
            };
        }

        fn toBits64(self: Int) u64 {
            return switch (self.value) {
                .uint64 => |val| val,
                .int64 => |val| @bitCast(val),
            };
        }

        fn to(self: Int, comptime T: type) T {
            return switch (self.value) {
                inline else => |val| @intCast(val),
            };
        }
    };

    /// Represents a numberic value of some type.
    pub const Float = struct {
        /// The type: 16, 32, or 64-bit float.
        ty: Ref,
        /// The actual value.
        value: Value,

        pub const Value = union(enum) {
            float16: f16,
            float32: f32,
            float64: f64,
        };
    };

    pub const Undef = struct {
        ty: Ref,
    };

    pub const Null = struct {
        ty: Ref,
    };

    pub const Bool = struct {
        ty: Ref,
        value: bool,
    };

    fn hash(self: Key) u32 {
        var hasher = std.hash.Wyhash.init(0);
        switch (self) {
            .float => |float| {
                std.hash.autoHash(&hasher, float.ty);
                switch (float.value) {
                    .float16 => |value| std.hash.autoHash(&hasher, @as(u16, @bitCast(value))),
                    .float32 => |value| std.hash.autoHash(&hasher, @as(u32, @bitCast(value))),
                    .float64 => |value| std.hash.autoHash(&hasher, @as(u64, @bitCast(value))),
                }
            },
            .function_type => |func| {
                std.hash.autoHash(&hasher, func.return_type);
                for (func.parameters) |param_type| {
                    std.hash.autoHash(&hasher, param_type);
                }
            },
            .struct_type => |struct_type| {
                std.hash.autoHash(&hasher, struct_type.name);
                for (struct_type.member_types) |member_type| {
                    std.hash.autoHash(&hasher, member_type);
                }
                for (struct_type.memberNames()) |member_name| {
                    std.hash.autoHash(&hasher, member_name);
                }
            },
            inline else => |key| std.hash.autoHash(&hasher, key),
        }
        return @truncate(hasher.final());
    }

    fn eql(a: Key, b: Key) bool {
        const KeyTag = @typeInfo(Key).Union.tag_type.?;
        const a_tag: KeyTag = a;
        const b_tag: KeyTag = b;
        if (a_tag != b_tag) {
            return false;
        }
        return switch (a) {
            .function_type => |a_func| {
                const b_func = b.function_type;
                return a_func.return_type == b_func.return_type and
                    std.mem.eql(Ref, a_func.parameters, b_func.parameters);
            },
            .struct_type => |a_struct| {
                const b_struct = b.struct_type;
                return a_struct.name == b_struct.name and
                    std.mem.eql(Ref, a_struct.member_types, b_struct.member_types) and
                    std.mem.eql(String, a_struct.memberNames(), b_struct.memberNames());
            },
            // TODO: Unroll?
            else => std.meta.eql(a, b),
        };
    }

    pub const Adapter = struct {
        self: *const Self,

        pub fn eql(ctx: @This(), a: Key, b_void: void, b_index: usize) bool {
            _ = b_void;
            return ctx.self.lookup(@enumFromInt(b_index)).eql(a);
        }

        pub fn hash(ctx: @This(), a: Key) u32 {
            _ = ctx;
            return a.hash();
        }
    };

    fn toSimpleType(self: Key) Tag.SimpleType {
        return switch (self) {
            .void_type => .void,
            .bool_type => .bool,
            else => unreachable,
        };
    }

    pub fn isNumericalType(self: Key) bool {
        return switch (self) {
            .int_type, .float_type => true,
            else => false,
        };
    }
};

pub fn deinit(self: *Self, spv: *const Module) void {
    self.map.deinit(spv.gpa);
    self.items.deinit(spv.gpa);
    self.extra.deinit(spv.gpa);
    self.string_bytes.deinit(spv.gpa);
    self.strings.deinit(spv.gpa);
    self.recursive_ptrs.deinit(spv.gpa);
}

/// Actually materialize the database into spir-v instructions.
/// This function returns a spir-v section of (only) constant and type instructions.
/// Additionally, decorations, debug names, etc, are all directly emitted into the
/// `spv` module. The section is allocated with `spv.gpa`.
pub fn materialize(self: *const Self, spv: *Module) !Section {
    var section = Section{};
    errdefer section.deinit(spv.gpa);
    for (self.items.items(.result_id), 0..) |result_id, index| {
        try self.emit(spv, result_id, @enumFromInt(index), &section);
    }
    return section;
}

fn emit(
    self: *const Self,
    spv: *Module,
    result_id: IdResult,
    ref: Ref,
    section: *Section,
) !void {
    const key = self.lookup(ref);
    const Lit = spec.LiteralContextDependentNumber;
    switch (key) {
        .void_type => {
            try section.emit(spv.gpa, .OpTypeVoid, .{ .id_result = result_id });
            try spv.debugName(result_id, "void");
        },
        .bool_type => {
            try section.emit(spv.gpa, .OpTypeBool, .{ .id_result = result_id });
            try spv.debugName(result_id, "bool");
        },
        .int_type => |int| {
            try section.emit(spv.gpa, .OpTypeInt, .{
                .id_result = result_id,
                .width = int.bits,
                .signedness = switch (int.signedness) {
                    .unsigned => @as(spec.Word, 0),
                    .signed => 1,
                },
            });
            const ui: []const u8 = switch (int.signedness) {
                .unsigned => "u",
                .signed => "i",
            };
            try spv.debugNameFmt(result_id, "{s}{}", .{ ui, int.bits });
        },
        .float_type => |float| {
            try section.emit(spv.gpa, .OpTypeFloat, .{
                .id_result = result_id,
                .width = float.bits,
            });
            try spv.debugNameFmt(result_id, "f{}", .{float.bits});
        },
        .vector_type => |vector| {
            try section.emit(spv.gpa, .OpTypeVector, .{
                .id_result = result_id,
                .component_type = self.resultId(vector.component_type),
                .component_count = vector.component_count,
            });
        },
        .array_type => |array| {
            try section.emit(spv.gpa, .OpTypeArray, .{
                .id_result = result_id,
                .element_type = self.resultId(array.element_type),
                .length = self.resultId(array.length),
            });
            if (array.stride != 0) {
                try spv.decorate(result_id, .{ .ArrayStride = .{ .array_stride = array.stride } });
            }
        },
        .function_type => |function| {
            try section.emitRaw(spv.gpa, .OpTypeFunction, 2 + function.parameters.len);
            section.writeOperand(IdResult, result_id);
            section.writeOperand(IdResult, self.resultId(function.return_type));
            for (function.parameters) |param_type| {
                section.writeOperand(IdResult, self.resultId(param_type));
            }
        },
        .ptr_type => |ptr| {
            try section.emit(spv.gpa, .OpTypePointer, .{
                .id_result = result_id,
                .storage_class = ptr.storage_class,
                .type = self.resultId(ptr.child_type),
            });
            // TODO: Decorations?
        },
        .fwd_ptr_type => |fwd| {
            // Only emit the OpTypeForwardPointer if its actually required.
            if (self.recursive_ptrs.contains(ref)) {
                try section.emit(spv.gpa, .OpTypeForwardPointer, .{
                    .pointer_type = result_id,
                    .storage_class = fwd.storage_class,
                });
            }
        },
        .struct_type => |struct_type| {
            try section.emitRaw(spv.gpa, .OpTypeStruct, 1 + struct_type.member_types.len);
            section.writeOperand(IdResult, result_id);
            for (struct_type.member_types) |member_type| {
                section.writeOperand(IdResult, self.resultId(member_type));
            }
            if (self.getString(struct_type.name)) |name| {
                try spv.debugName(result_id, name);
            }
            for (struct_type.memberNames(), 0..) |member_name, i| {
                if (self.getString(member_name)) |name| {
                    try spv.memberDebugName(result_id, @intCast(i), name);
                }
            }
            // TODO: Decorations?
        },
        .opaque_type => |opaque_type| {
            const name = if (self.getString(opaque_type.name)) |name| name else "";
            try section.emit(spv.gpa, .OpTypeOpaque, .{
                .id_result = result_id,
                .literal_string = name,
            });
        },
        .int => |int| {
            const int_type = self.lookup(int.ty).int_type;
            const ty_id = self.resultId(int.ty);
            const lit: Lit = switch (int_type.bits) {
                1...32 => .{ .uint32 = int.toBits32() },
                33...64 => .{ .uint64 = int.toBits64() },
                else => unreachable,
            };

            try section.emit(spv.gpa, .OpConstant, .{
                .id_result_type = ty_id,
                .id_result = result_id,
                .value = lit,
            });
        },
        .float => |float| {
            const ty_id = self.resultId(float.ty);
            const lit: Lit = switch (float.value) {
                .float16 => |value| .{ .uint32 = @as(u16, @bitCast(value)) },
                .float32 => |value| .{ .float32 = value },
                .float64 => |value| .{ .float64 = value },
            };
            try section.emit(spv.gpa, .OpConstant, .{
                .id_result_type = ty_id,
                .id_result = result_id,
                .value = lit,
            });
        },
        .undef => |undef| {
            try section.emit(spv.gpa, .OpUndef, .{
                .id_result_type = self.resultId(undef.ty),
                .id_result = result_id,
            });
        },
        .null => |null_info| {
            try section.emit(spv.gpa, .OpConstantNull, .{
                .id_result_type = self.resultId(null_info.ty),
                .id_result = result_id,
            });
        },
        .bool => |bool_info| switch (bool_info.value) {
            true => {
                try section.emit(spv.gpa, .OpConstantTrue, .{
                    .id_result_type = self.resultId(bool_info.ty),
                    .id_result = result_id,
                });
            },
            false => {
                try section.emit(spv.gpa, .OpConstantFalse, .{
                    .id_result_type = self.resultId(bool_info.ty),
                    .id_result = result_id,
                });
            },
        },
    }
}

/// Add a key to this cache. Returns a reference to the key that
/// was added. The corresponding result-id can be queried using
/// self.resultId with the result.
pub fn resolve(self: *Self, spv: *Module, key: Key) !Ref {
    const adapter: Key.Adapter = .{ .self = self };
    const entry = try self.map.getOrPutAdapted(spv.gpa, key, adapter);
    if (entry.found_existing) {
        return @enumFromInt(entry.index);
    }
    const item: Item = switch (key) {
        inline .void_type, .bool_type => .{
            .tag = .type_simple,
            .result_id = spv.allocId(),
            .data = @intFromEnum(key.toSimpleType()),
        },
        .int_type => |int| blk: {
            const t: Tag = switch (int.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            break :blk .{
                .tag = t,
                .result_id = spv.allocId(),
                .data = int.bits,
            };
        },
        .float_type => |float| .{
            .tag = .type_float,
            .result_id = spv.allocId(),
            .data = float.bits,
        },
        .vector_type => |vector| .{
            .tag = .type_vector,
            .result_id = spv.allocId(),
            .data = try self.addExtra(spv, vector),
        },
        .array_type => |array| .{
            .tag = .type_array,
            .result_id = spv.allocId(),
            .data = try self.addExtra(spv, array),
        },
        .function_type => |function| blk: {
            const extra = try self.addExtra(spv, Tag.FunctionType{
                .param_len = @intCast(function.parameters.len),
                .return_type = function.return_type,
            });
            try self.extra.appendSlice(spv.gpa, @ptrCast(function.parameters));
            break :blk .{
                .tag = .type_function,
                .result_id = spv.allocId(),
                .data = extra,
            };
        },
        // .ptr_type => |ptr| switch (ptr.storage_class) {
        //     .Generic => Item{
        //         .tag = .type_ptr_generic,
        //         .result_id = spv.allocId(),
        //         .data = @intFromEnum(ptr.child_type),
        //     },
        //     .CrossWorkgroup => Item{
        //         .tag = .type_ptr_crosswgp,
        //         .result_id = spv.allocId(),
        //         .data = @intFromEnum(ptr.child_type),
        //     },
        //     .Function => Item{
        //         .tag = .type_ptr_function,
        //         .result_id = spv.allocId(),
        //         .data = @intFromEnum(ptr.child_type),
        //     },
        //     else => |storage_class| Item{
        //         .tag = .type_ptr_simple,
        //         .result_id = spv.allocId(),
        //         .data = try self.addExtra(spv, Tag.SimplePointerType{
        //             .storage_class = storage_class,
        //             .child_type = ptr.child_type,
        //         }),
        //     },
        // },
        .ptr_type => |ptr| Item{
            .tag = .type_ptr_simple,
            .result_id = self.resultId(ptr.fwd),
            .data = try self.addExtra(spv, Tag.SimplePointerType{
                .storage_class = ptr.storage_class,
                .child_type = ptr.child_type,
                .fwd = ptr.fwd,
            }),
        },
        .fwd_ptr_type => |fwd| Item{
            .tag = .type_fwd_ptr,
            .result_id = spv.allocId(),
            .data = try self.addExtra(spv, Tag.ForwardPointerType{
                .zig_child_type = fwd.zig_child_type,
                .storage_class = fwd.storage_class,
            }),
        },
        .struct_type => |struct_type| blk: {
            const extra = try self.addExtra(spv, Tag.SimpleStructType{
                .name = struct_type.name,
                .members_len = @intCast(struct_type.member_types.len),
            });
            try self.extra.appendSlice(spv.gpa, @ptrCast(struct_type.member_types));

            if (struct_type.member_names) |member_names| {
                try self.extra.appendSlice(spv.gpa, @ptrCast(member_names));
                break :blk Item{
                    .tag = .type_struct_simple_with_member_names,
                    .result_id = spv.allocId(),
                    .data = extra,
                };
            } else {
                break :blk Item{
                    .tag = .type_struct_simple,
                    .result_id = spv.allocId(),
                    .data = extra,
                };
            }
        },
        .opaque_type => |opaque_type| Item{
            .tag = .type_opaque,
            .result_id = spv.allocId(),
            .data = @intFromEnum(opaque_type.name),
        },
        .int => |int| blk: {
            const int_type = self.lookup(int.ty).int_type;
            if (int_type.signedness == .unsigned and int_type.bits == 8) {
                break :blk .{
                    .tag = .uint8,
                    .result_id = spv.allocId(),
                    .data = int.to(u8),
                };
            } else if (int_type.signedness == .unsigned and int_type.bits == 32) {
                break :blk .{
                    .tag = .uint32,
                    .result_id = spv.allocId(),
                    .data = int.to(u32),
                };
            }

            switch (int.value) {
                inline else => |val| {
                    if (val >= 0 and val <= std.math.maxInt(u32)) {
                        break :blk .{
                            .tag = .uint_small,
                            .result_id = spv.allocId(),
                            .data = try self.addExtra(spv, Tag.UInt32{
                                .ty = int.ty,
                                .value = @intCast(val),
                            }),
                        };
                    } else if (val >= std.math.minInt(i32) and val <= std.math.maxInt(i32)) {
                        break :blk .{
                            .tag = .int_small,
                            .result_id = spv.allocId(),
                            .data = try self.addExtra(spv, Tag.Int32{
                                .ty = int.ty,
                                .value = @intCast(val),
                            }),
                        };
                    } else if (val < 0) {
                        break :blk .{
                            .tag = .int_large,
                            .result_id = spv.allocId(),
                            .data = try self.addExtra(spv, Tag.Int64.encode(int.ty, @intCast(val))),
                        };
                    } else {
                        break :blk .{
                            .tag = .uint_large,
                            .result_id = spv.allocId(),
                            .data = try self.addExtra(spv, Tag.UInt64.encode(int.ty, @intCast(val))),
                        };
                    }
                },
            }
        },
        .float => |float| switch (self.lookup(float.ty).float_type.bits) {
            16 => .{
                .tag = .float16,
                .result_id = spv.allocId(),
                .data = @as(u16, @bitCast(float.value.float16)),
            },
            32 => .{
                .tag = .float32,
                .result_id = spv.allocId(),
                .data = @as(u32, @bitCast(float.value.float32)),
            },
            64 => .{
                .tag = .float64,
                .result_id = spv.allocId(),
                .data = try self.addExtra(spv, Tag.Float64.encode(float.value.float64)),
            },
            else => unreachable,
        },
        .undef => |undef| .{
            .tag = .undef,
            .result_id = spv.allocId(),
            .data = @intFromEnum(undef.ty),
        },
        .null => |null_info| .{
            .tag = .null,
            .result_id = spv.allocId(),
            .data = @intFromEnum(null_info.ty),
        },
        .bool => |bool_info| .{
            .tag = switch (bool_info.value) {
                true => Tag.bool_true,
                false => Tag.bool_false,
            },
            .result_id = spv.allocId(),
            .data = @intFromEnum(bool_info.ty),
        },
    };
    try self.items.append(spv.gpa, item);

    return @enumFromInt(entry.index);
}

/// Turn a Ref back into a Key.
/// The Key is valid until the next call to resolve().
pub fn lookup(self: *const Self, ref: Ref) Key {
    const item = self.items.get(@intFromEnum(ref));
    const data = item.data;
    return switch (item.tag) {
        .type_simple => switch (@as(Tag.SimpleType, @enumFromInt(data))) {
            .void => .void_type,
            .bool => .bool_type,
        },
        .type_int_signed => .{ .int_type = .{
            .signedness = .signed,
            .bits = @intCast(data),
        } },
        .type_int_unsigned => .{ .int_type = .{
            .signedness = .unsigned,
            .bits = @intCast(data),
        } },
        .type_float => .{ .float_type = .{
            .bits = @intCast(data),
        } },
        .type_vector => .{ .vector_type = self.extraData(Tag.VectorType, data) },
        .type_array => .{ .array_type = self.extraData(Tag.ArrayType, data) },
        .type_function => {
            const payload = self.extraDataTrail(Tag.FunctionType, data);
            return .{
                .function_type = .{
                    .return_type = payload.data.return_type,
                    .parameters = @ptrCast(self.extra.items[payload.trail..][0..payload.data.param_len]),
                },
            };
        },
        // .type_ptr_generic => .{
        //     .ptr_type = .{
        //         .storage_class = .Generic,
        //         .child_type = @enumFromInt(data),
        //     },
        // },
        // .type_ptr_crosswgp => .{
        //     .ptr_type = .{
        //         .storage_class = .CrossWorkgroup,
        //         .child_type = @enumFromInt(data),
        //     },
        // },
        // .type_ptr_function => .{
        //     .ptr_type = .{
        //         .storage_class = .Function,
        //         .child_type = @enumFromInt(data),
        //     },
        // },
        .type_ptr_simple => {
            const payload = self.extraData(Tag.SimplePointerType, data);
            return .{
                .ptr_type = .{
                    .storage_class = payload.storage_class,
                    .child_type = payload.child_type,
                    .fwd = payload.fwd,
                },
            };
        },
        .type_fwd_ptr => {
            const payload = self.extraData(Tag.ForwardPointerType, data);
            return .{
                .fwd_ptr_type = .{
                    .zig_child_type = payload.zig_child_type,
                    .storage_class = payload.storage_class,
                },
            };
        },
        .type_struct_simple => {
            const payload = self.extraDataTrail(Tag.SimpleStructType, data);
            const member_types: []const Ref = @ptrCast(self.extra.items[payload.trail..][0..payload.data.members_len]);
            return .{
                .struct_type = .{
                    .name = payload.data.name,
                    .member_types = member_types,
                    .member_names = null,
                },
            };
        },
        .type_struct_simple_with_member_names => {
            const payload = self.extraDataTrail(Tag.SimpleStructType, data);
            const trailing = self.extra.items[payload.trail..];
            const member_types: []const Ref = @ptrCast(trailing[0..payload.data.members_len]);
            const member_names: []const String = @ptrCast(trailing[payload.data.members_len..][0..payload.data.members_len]);
            return .{
                .struct_type = .{
                    .name = payload.data.name,
                    .member_types = member_types,
                    .member_names = member_names,
                },
            };
        },
        .type_opaque => .{
            .opaque_type = .{
                .name = @enumFromInt(data),
            },
        },
        .float16 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 16 } }),
            .value = .{ .float16 = @bitCast(@as(u16, @intCast(data))) },
        } },
        .float32 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 32 } }),
            .value = .{ .float32 = @bitCast(data) },
        } },
        .float64 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 64 } }),
            .value = .{ .float64 = self.extraData(Tag.Float64, data).decode() },
        } },
        .uint8 => .{ .int = .{
            .ty = self.get(.{ .int_type = .{ .signedness = .unsigned, .bits = 8 } }),
            .value = .{ .uint64 = data },
        } },
        .uint32 => .{ .int = .{
            .ty = self.get(.{ .int_type = .{ .signedness = .unsigned, .bits = 32 } }),
            .value = .{ .uint64 = data },
        } },
        .int_small => {
            const payload = self.extraData(Tag.Int32, data);
            return .{ .int = .{
                .ty = payload.ty,
                .value = .{ .int64 = payload.value },
            } };
        },
        .uint_small => {
            const payload = self.extraData(Tag.UInt32, data);
            return .{ .int = .{
                .ty = payload.ty,
                .value = .{ .uint64 = payload.value },
            } };
        },
        .int_large => {
            const payload = self.extraData(Tag.Int64, data);
            return .{ .int = .{
                .ty = payload.ty,
                .value = .{ .int64 = payload.decode() },
            } };
        },
        .uint_large => {
            const payload = self.extraData(Tag.UInt64, data);
            return .{ .int = .{
                .ty = payload.ty,
                .value = .{ .uint64 = payload.decode() },
            } };
        },
        .undef => .{ .undef = .{
            .ty = @enumFromInt(data),
        } },
        .null => .{ .null = .{
            .ty = @enumFromInt(data),
        } },
        .bool_true => .{ .bool = .{
            .ty = @enumFromInt(data),
            .value = true,
        } },
        .bool_false => .{ .bool = .{
            .ty = @enumFromInt(data),
            .value = false,
        } },
    };
}

/// Look op the result-id that corresponds to a particular
/// ref.
pub fn resultId(self: Self, ref: Ref) IdResult {
    return self.items.items(.result_id)[@intFromEnum(ref)];
}

/// Get the ref for a key that has already been added to the cache.
fn get(self: *const Self, key: Key) Ref {
    const adapter: Key.Adapter = .{ .self = self };
    const index = self.map.getIndexAdapted(key, adapter).?;
    return @enumFromInt(index);
}

fn addExtra(self: *Self, spv: *Module, extra: anytype) !u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    try self.extra.ensureUnusedCapacity(spv.gpa, fields.len);
    return try self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Self, extra: anytype) !u32 {
    const payload_offset: u32 = @intCast(self.extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const field_val = @field(extra, field.name);
        const word: u32 = switch (field.type) {
            u32 => field_val,
            i32 => @bitCast(field_val),
            Ref => @intFromEnum(field_val),
            StorageClass => @intFromEnum(field_val),
            String => @intFromEnum(field_val),
            InternPool.Index => @intFromEnum(field_val),
            else => @compileError("Invalid type: " ++ @typeName(field.type)),
        };
        self.extra.appendAssumeCapacity(word);
    }
    return payload_offset;
}

fn extraData(self: Self, comptime T: type, offset: u32) T {
    return self.extraDataTrail(T, offset).data;
}

fn extraDataTrail(self: Self, comptime T: type, offset: u32) struct { data: T, trail: u32 } {
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, 0..) |field, i| {
        const word = self.extra.items[offset + i];
        @field(result, field.name) = switch (field.type) {
            u32 => word,
            i32 => @bitCast(word),
            Ref => @enumFromInt(word),
            StorageClass => @enumFromInt(word),
            String => @enumFromInt(word),
            InternPool.Index => @enumFromInt(word),
            else => @compileError("Invalid type: " ++ @typeName(field.type)),
        };
    }
    return .{
        .data = result,
        .trail = offset + @as(u32, @intCast(fields.len)),
    };
}

/// Represents a reference to some null-terminated string.
pub const String = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub const Adapter = struct {
        self: *const Self,

        pub fn eql(ctx: @This(), a: []const u8, _: void, b_index: usize) bool {
            const offset = ctx.self.strings.values()[b_index];
            const b = std.mem.sliceTo(ctx.self.string_bytes.items[offset..], 0);
            return std.mem.eql(u8, a, b);
        }

        pub fn hash(ctx: @This(), a: []const u8) u32 {
            _ = ctx;
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(a);
            return @truncate(hasher.final());
        }
    };
};

/// Add a string to the cache. Must not contain any 0 values.
pub fn addString(self: *Self, spv: *Module, str: []const u8) !String {
    assert(std.mem.indexOfScalar(u8, str, 0) == null);
    const adapter = String.Adapter{ .self = self };
    const entry = try self.strings.getOrPutAdapted(spv.gpa, str, adapter);
    if (!entry.found_existing) {
        const offset = self.string_bytes.items.len;
        try self.string_bytes.ensureUnusedCapacity(spv.gpa, 1 + str.len);
        self.string_bytes.appendSliceAssumeCapacity(str);
        self.string_bytes.appendAssumeCapacity(0);
        entry.value_ptr.* = @intCast(offset);
    }

    return @enumFromInt(entry.index);
}

pub fn getString(self: *const Self, ref: String) ?[]const u8 {
    return switch (ref) {
        .none => null,
        else => std.mem.sliceTo(self.string_bytes.items[self.strings.values()[@intFromEnum(ref)]..], 0),
    };
}
