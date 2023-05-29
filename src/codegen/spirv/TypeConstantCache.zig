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

    // -- Values
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

    // -- values
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
            inline else => |key| std.hash.autoHash(&hasher, key),
        }
        return @truncate(u32, hasher.final());
    }

    fn eql(a: Key, b: Key) bool {
        return std.meta.eql(a, b);
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
        .float => |float| {
            const ty_id = self.resultId(float.ty);
            const lit: spec.LiteralContextDependentNumber = switch (float.value) {
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

/// Get the ref for a key that has already been added to the cache.
fn get(self: *const Self, key: Key) Ref {
    const adapter: Key.Adapter = .{ .self = self };
    const index = self.map.getIndexAdapted(key, adapter).?;
    return @intToEnum(Ref, index);
}

/// Get the result-id for a key that has already been added to the cache.
fn getId(self: *const Self, key: Key) IdResult {
    return self.resultId(self.get(key));
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

/// Look op the result-id that corresponds to a particular
/// ref.
pub fn resultId(self: Self, ref: Ref) IdResult {
    return self.items.items(.result_id)[@enumToInt(ref)];
}

/// Turn a Ref back into a Key.
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
        .float16 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 16 } }),
            .value = .{ .float16 = @bitCast(f16, @intCast(u16, data)) },
        } },
        .float32 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 32 } }),
            .value = .{ .float32 = @bitCast(f32, data) },
        } },
        .float64 => .{ .float = .{
            .ty = self.get(.{ .float_type = .{ .bits = 32 } }),
            .value = .{ .float64 = self.extraData(Tag.Float64, data).decode() },
        } },
    };
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
            Ref => @enumToInt(field_val),
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
            Ref => @intToEnum(Ref, word),
            else => @compileError("Invalid type: " ++ @typeName(field.type)),
        };
    }
    return .{
        .data = result,
        .trail = offset + @intCast(u32, fields.len),
    };
}
