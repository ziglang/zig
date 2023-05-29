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
const Allocator = std.mem.Allocator;

const Section = @import("Section.zig");
const Module = @import("Module.zig");

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const IdResult = spec.IdResult;
const StorageClass = spec.StorageClass;

const Self = @This();

map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayListUnmanaged(u32) = .{},

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
    /// Pointer type in the CrossWorkgroup storage class
    /// data is child type
    type_ptr_generic,
    /// Pointer type in the CrossWorkgroup storage class
    /// data is child type
    type_ptr_crosswgp,
    /// Pointer type in the Function storage class
    /// data is child type
    type_ptr_function,
    /// Simple pointer type that does not have any decorations.
    /// data is SimplePointerType
    type_ptr_simple,

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

    const SimpleType = enum { void, bool };

    const VectorType = Key.VectorType;
    const ArrayType = Key.ArrayType;

    // Trailing:
    // - [param_len]Ref: parameter types
    const FunctionType = struct {
        param_len: u32,
        return_type: Ref,
    };

    const SimplePointerType = struct {
        storage_class: StorageClass,
        child_type: Ref,
    };

    const Float64 = struct {
        // Low-order 32 bits of the value.
        low: u32,
        // High-order 32 bits of the value.
        high: u32,

        fn encode(value: f64) Float64 {
            const bits = @bitCast(u64, value);
            return .{
                .low = @truncate(u32, bits),
                .high = @truncate(u32, bits >> 32),
            };
        }

        fn decode(self: Float64) f64 {
            const bits = @as(u64, self.low) | (@as(u64, self.high) << 32);
            return @bitCast(f64, bits);
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
                .low = @truncate(u32, value),
                .high = @truncate(u32, value >> 32),
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
                .low = @truncate(u32, @bitCast(u64, value)),
                .high = @truncate(u32, @bitCast(u64, value) >> 32),
            };
        }

        fn decode(self: Int64) i64 {
            return @bitCast(i64, @as(u64, self.low) | (@as(u64, self.high) << 32));
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

    // -- values
    int: Int,
    float: Float,

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
        // TODO: Decorations:
        // - Alignment
        // - ArrayStride,
        // - MaxByteOffset,
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
                .uint64 => |val| @intCast(u32, val),
                .int64 => |val| if (val < 0) @bitCast(u32, @intCast(i32, val)) else @intCast(u32, val),
            };
        }

        fn toBits64(self: Int) u64 {
            return switch (self.value) {
                .uint64 => |val| val,
                .int64 => |val| @bitCast(u64, val),
            };
        }

        fn to(self: Int, comptime T: type) T {
            return switch (self.value) {
                inline else => |val| @intCast(T, val),
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

    fn hash(self: Key) u32 {
        var hasher = std.hash.Wyhash.init(0);
        switch (self) {
            .float => |float| {
                std.hash.autoHash(&hasher, float.ty);
                switch (float.value) {
                    .float16 => |value| std.hash.autoHash(&hasher, @bitCast(u16, value)),
                    .float32 => |value| std.hash.autoHash(&hasher, @bitCast(u32, value)),
                    .float64 => |value| std.hash.autoHash(&hasher, @bitCast(u64, value)),
                }
            },
            .function_type => |func| {
                std.hash.autoHash(&hasher, func.return_type);
                for (func.parameters) |param_type| {
                    std.hash.autoHash(&hasher, param_type);
                }
            },
            inline else => |key| std.hash.autoHash(&hasher, key),
        }
        return @truncate(u32, hasher.final());
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
                const b_func = a.function_type;
                return a_func.return_type == b_func.return_type and
                    std.mem.eql(Ref, a_func.parameters, b_func.parameters);
            },
            // TODO: Unroll?
            else => std.meta.eql(a, b),
        };
    }

    pub const Adapter = struct {
        self: *const Self,

        pub fn eql(ctx: @This(), a: Key, b_void: void, b_index: usize) bool {
            _ = b_void;
            return ctx.self.lookup(@intToEnum(Ref, b_index)).eql(a);
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
};

pub fn deinit(self: *Self, spv: *const Module) void {
    self.map.deinit(spv.gpa);
    self.items.deinit(spv.gpa);
    self.extra.deinit(spv.gpa);
}

/// Actually materialize the database into spir-v instructions.
/// This function returns a spir-v section of (only) constant and type instructions.
/// Additionally, decorations, debug names, etc, are all directly emitted into the
/// `spv` module. The section is allocated with `spv.gpa`.
pub fn materialize(self: *const Self, spv: *Module) !Section {
    var section = Section{};
    errdefer section.deinit(spv.gpa);
    for (self.items.items(.result_id), 0..) |result_id, index| {
        try self.emit(spv, result_id, @intToEnum(Ref, index), &section);
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
            try spv.debugName(result_id, "void", .{});
        },
        .bool_type => {
            try section.emit(spv.gpa, .OpTypeBool, .{ .id_result = result_id });
            try spv.debugName(result_id, "bool", .{});
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
            try spv.debugName(result_id, "{s}{}", .{ ui, int.bits });
        },
        .float_type => |float| {
            try section.emit(spv.gpa, .OpTypeFloat, .{
                .id_result = result_id,
                .width = float.bits,
            });
            try spv.debugName(result_id, "f{}", .{float.bits});
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
                .float16 => |value| .{ .uint32 = @bitCast(u16, value) },
                .float32 => |value| .{ .float32 = value },
                .float64 => |value| .{ .float64 = value },
            };
            try section.emit(spv.gpa, .OpConstant, .{
                .id_result_type = ty_id,
                .id_result = result_id,
                .value = lit,
            });
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
        return @intToEnum(Ref, entry.index);
    }
    const result_id = spv.allocId();
    const item: Item = switch (key) {
        inline .void_type, .bool_type => .{
            .tag = .type_simple,
            .result_id = result_id,
            .data = @enumToInt(key.toSimpleType()),
        },
        .int_type => |int| blk: {
            const t: Tag = switch (int.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            break :blk .{
                .tag = t,
                .result_id = result_id,
                .data = int.bits,
            };
        },
        .float_type => |float| .{
            .tag = .type_float,
            .result_id = result_id,
            .data = float.bits,
        },
        .vector_type => |vector| .{
            .tag = .type_vector,
            .result_id = result_id,
            .data = try self.addExtra(spv, vector),
        },
        .array_type => |array| .{
            .tag = .type_array,
            .result_id = result_id,
            .data = try self.addExtra(spv, array),
        },
        .function_type => |function| blk: {
            const extra = try self.addExtra(spv, Tag.FunctionType{
                .param_len = @intCast(u32, function.parameters.len),
                .return_type = function.return_type,
            });
            try self.extra.appendSlice(spv.gpa, @ptrCast([]const u32, function.parameters));
            break :blk .{
                .tag = .type_function,
                .result_id = result_id,
                .data = extra,
            };
        },
        .ptr_type => |ptr| switch (ptr.storage_class) {
            .Generic => Item{
                .tag = .type_ptr_generic,
                .result_id = result_id,
                .data = @enumToInt(ptr.child_type),
            },
            .CrossWorkgroup => Item{
                .tag = .type_ptr_crosswgp,
                .result_id = result_id,
                .data = @enumToInt(ptr.child_type),
            },
            .Function => Item{
                .tag = .type_ptr_function,
                .result_id = result_id,
                .data = @enumToInt(ptr.child_type),
            },
            else => |storage_class| Item{
                .tag = .type_ptr_simple,
                .result_id = result_id,
                .data = try self.addExtra(spv, Tag.SimplePointerType{
                    .storage_class = storage_class,
                    .child_type = ptr.child_type,
                }),
            },
        },
        .int => |int| blk: {
            const int_type = self.lookup(int.ty).int_type;
            if (int_type.signedness == .unsigned and int_type.bits == 8) {
                break :blk .{
                    .tag = .uint8,
                    .result_id = result_id,
                    .data = int.to(u8),
                };
            } else if (int_type.signedness == .unsigned and int_type.bits == 32) {
                break :blk .{
                    .tag = .uint32,
                    .result_id = result_id,
                    .data = int.to(u32),
                };
            }

            switch (int.value) {
                inline else => |val| {
                    if (val >= 0 and val <= std.math.maxInt(u32)) {
                        break :blk .{
                            .tag = .uint_small,
                            .result_id = result_id,
                            .data = try self.addExtra(spv, Tag.UInt32{
                                .ty = int.ty,
                                .value = @intCast(u32, val),
                            }),
                        };
                    } else if (val >= std.math.minInt(i32) and val <= std.math.maxInt(i32)) {
                        break :blk .{
                            .tag = .int_small,
                            .result_id = result_id,
                            .data = try self.addExtra(spv, Tag.Int32{
                                .ty = int.ty,
                                .value = @intCast(i32, val),
                            }),
                        };
                    } else if (val < 0) {
                        break :blk .{
                            .tag = .int_large,
                            .result_id = result_id,
                            .data = try self.addExtra(spv, Tag.Int64.encode(int.ty, @intCast(i64, val))),
                        };
                    } else {
                        break :blk .{
                            .tag = .uint_large,
                            .result_id = result_id,
                            .data = try self.addExtra(spv, Tag.UInt64.encode(int.ty, @intCast(u64, val))),
                        };
                    }
                },
            }
        },
        .float => |float| switch (self.lookup(float.ty).float_type.bits) {
            16 => .{
                .tag = .float16,
                .result_id = result_id,
                .data = @bitCast(u16, float.value.float16),
            },
            32 => .{
                .tag = .float32,
                .result_id = result_id,
                .data = @bitCast(u32, float.value.float32),
            },
            64 => .{
                .tag = .float64,
                .result_id = result_id,
                .data = try self.addExtra(spv, Tag.Float64.encode(float.value.float64)),
            },
            else => unreachable,
        },
    };
    try self.items.append(spv.gpa, item);

    return @intToEnum(Ref, entry.index);
}

/// Turn a Ref back into a Key.
/// The Key is valid until the next call to resolve().
pub fn lookup(self: *const Self, ref: Ref) Key {
    const item = self.items.get(@enumToInt(ref));
    const data = item.data;
    return switch (item.tag) {
        .type_simple => switch (@intToEnum(Tag.SimpleType, data)) {
            .void => .void_type,
            .bool => .bool_type,
        },
        .type_int_signed => .{ .int_type = .{
            .signedness = .signed,
            .bits = @intCast(u16, data),
        } },
        .type_int_unsigned => .{ .int_type = .{
            .signedness = .unsigned,
            .bits = @intCast(u16, data),
        } },
        .type_float => .{ .float_type = .{
            .bits = @intCast(u16, data),
        } },
        .type_vector => .{ .vector_type = self.extraData(Tag.VectorType, data) },
        .type_array => .{ .array_type = self.extraData(Tag.ArrayType, data) },
        .type_function => {
            const payload = self.extraDataTrail(Tag.FunctionType, data);
            return .{
                .function_type = .{
                    .return_type = payload.data.return_type,
                    .parameters = @ptrCast([]const Ref, self.extra.items[payload.trail..][0..payload.data.param_len]),
                },
            };
        },
        .type_ptr_generic => .{
            .ptr_type = .{
                .storage_class = .Generic,
                .child_type = @intToEnum(Ref, data),
            },
        },
        .type_ptr_crosswgp => .{
            .ptr_type = .{
                .storage_class = .CrossWorkgroup,
                .child_type = @intToEnum(Ref, data),
            },
        },
        .type_ptr_function => .{
            .ptr_type = .{
                .storage_class = .Function,
                .child_type = @intToEnum(Ref, data),
            },
        },
        .type_ptr_simple => {
            const payload = self.extraData(Tag.SimplePointerType, data);
            return .{
                .ptr_type = .{
                    .storage_class = payload.storage_class,
                    .child_type = payload.child_type,
                },
            };
        },
        .float16 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 16 } }),
            .value = .{ .float16 = @bitCast(f16, @intCast(u16, data)) },
        } },
        .float32 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 32 } }),
            .value = .{ .float32 = @bitCast(f32, data) },
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
    };
}

/// Look op the result-id that corresponds to a particular
/// ref.
pub fn resultId(self: Self, ref: Ref) IdResult {
    return self.items.items(.result_id)[@enumToInt(ref)];
}

/// Get the ref for a key that has already been added to the cache.
fn get(self: *const Self, key: Key) Ref {
    const adapter: Key.Adapter = .{ .self = self };
    const index = self.map.getIndexAdapted(key, adapter).?;
    return @intToEnum(Ref, index);
}

fn addExtra(self: *Self, spv: *Module, extra: anytype) !u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    try self.extra.ensureUnusedCapacity(spv.gpa, fields.len);
    return try self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Self, extra: anytype) !u32 {
    const payload_offset = @intCast(u32, self.extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const field_val = @field(extra, field.name);
        const word = switch (field.type) {
            u32 => field_val,
            i32 => @bitCast(u32, field_val),
            Ref => @enumToInt(field_val),
            StorageClass => @enumToInt(field_val),
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
            i32 => @bitCast(i32, word),
            Ref => @intToEnum(Ref, word),
            StorageClass => @intToEnum(StorageClass, word),
            else => @compileError("Invalid type: " ++ @typeName(field.type)),
        };
    }
    return .{
        .data = result,
        .trail = offset + @intCast(u32, fields.len),
    };
}
