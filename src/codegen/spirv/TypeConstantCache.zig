//! This file implements an InternPool-like structure that caches
//! SPIR-V types and constants.
//! In the case of SPIR-V, the type- and constant instructions
//! describe the type and constant fully. This means we can save
//! memory by representing these items directly in spir-v code,
//! and decoding that when required.
//! This does not work for OpDecorate instructions though, and for
//! those we keep some additional metadata.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Section = @import("section.zig");
const Module = @import("Module.zig");

const spec = @import("spec.zig");
const Opcode = spec.Opcode;
const IdResult = spec.IdResult;

const Self = @This();

map: std.AutoArrayHashMapUnmanaged(void, void) = .{},
items: std.MultiArrayList(Item) = .{},
extra: std.ArrayHashMapUnmanaged(u32) = .{},

const Item = struct {
    tag: Tag,
    /// The result-id that this item uses.
    result_id: IdResult,
    /// The Tag determines how this should be interpreted.
    data: u32,
};

const Tag = enum {
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
    /// data is payload to Key.VectorType
    type_vector,

    const SimpleType = enum {
        void,
        bool,
    };
};

pub const Ref = enum(u32) { _ };

/// This union represents something that can be interned. This includes
/// types and constants. This structure is used for interfacing with the
/// database: Values described for this structure are ephemeral and stored
/// in a more memory-efficient manner internally.
pub const Key = union(enum) {
    void_ty,
    bool_ty,
    int_ty: IntType,
    float_ty: FloatType,
    vector_ty: VectorType,

    pub const IntType = std.builtin.Type.Int;
    pub const FloatType = std.builtin.Type.Float;

    pub const VectorType = struct {
        component_type: Ref,
        component_count: u32,
    };

    fn hash(self: Key) u32 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, self);
        return @truncate(u32, hasher.final());
    }

    fn eql(a: Key, b: Key) u32 {
        return std.meta.eql(a, b);
    }

    pub const Adapter = struct {
        self: *const Self,

        pub fn eql(ctx: @This(), a: Key, b_void: void, b_map_index: u32) bool {
            _ = b_void;
            return ctx.self.lookup(@intToEnum(Ref, b_map_index)).eql(a);
        }

        pub fn hash(ctx: @This(), a: Key) u32 {
            return ctx.self.hash(a);
        }
    };

    fn toSimpleType(self: Key) Tag.SimpleType {
        return switch (self) {
            .void_ty => .void,
            .bool_ty => .bool,
            else => unreachable,
        };
    }
};

pub fn deinit(self: *Self, spv: Module) void {
    self.map.deinit(spv.gpa);
    self.items.deinit(spv.gpa);
    self.extra.deinit(spv.gpa);
}

/// Actually materialize the database into spir-v instructions.
// TODO: This should generate decorations as well as regular instructions.
// Important is that these are generated in-order, but that should be fine.
pub fn finalize(self: *Self, spv: *Module) !void {
    // This function should really be the only one that modifies spv.types_and_constants.
    // TODO: Make this function return the section instead.
    std.debug.assert(spv.sections.types_and_constants.instructions.items.len == 0);

    for (self.items.items(.result_id), 0..) |result_id, index| {
        try self.emit(spv, result_id, @intToEnum(Ref, index));
    }
}

fn emit(
    self: *Self,
    spv: *Module,
    result_id: IdResult,
    ref: Ref,
) !void {
    const tc = &spv.sections.types_and_constants;
    const key = self.lookup(ref);
    switch (key) {
        .void_ty => {
            try tc.emit(spv.gpa, .OpTypeVoid, .{ .id_result = result_id });
            try spv.debugName(result_id, "void", .{});
        },
        .bool_ty => {
            try tc.emit(spv.gpa, .OpTypeBool, .{ .id_result = result_id });
            try spv.debugName(result_id, "bool", .{});
        },
        .int_ty => |int| {
            try tc.emit(spv.gpa, .OpTypeInt, .{
                .id_result = result_id,
                .width = int.bits,
                .signedness = switch (int.signedness) {
                    .unsigned => 0,
                    .signed => 1,
                },
            });
            const ui: []const u8 = switch (int.signedness) {
                0 => "u",
                1 => "i",
                else => unreachable,
            };
            try spv.debugName(result_id, "{s}{}", .{ ui, int.bits });
        },
        .float_ty => |float| {
            try tc.emit(spv.gpa, .OpTypeFloat, .{
                .id_result = result_id,
                .width = float.bits,
            });
            try spv.debugName(result_id, "f{}", .{float.bits});
        },
        .vector_ty => |vector| {
            try tc.emit(spv.gpa, .OpTypeVector, .{
                .id_result = result_id,
                .component_type = self.resultId(vector.component_type),
                .component_count = vector.component_count,
            });
        },
    }
}

/// Add a key to this cache. Returns a reference to the key that
/// was added. The corresponding result-id can be queried using
/// self.resultId with the result.
pub fn add(self: *Self, spv: *Module, key: Key) !Ref {
    const adapter: Key.Adapter = .{ .self = self };
    const entry = try self.map.getOrPutAdapted(spv.gpa, key, adapter);
    if (entry.found_existing) {
        return @intToEnum(Ref, entry.index);
    }
    const result_id = spv.allocId();
    try self.items.ensureUnusedCapacity(spv.gpa, 1);
    switch (key) {
        inline .void_ty, .bool_ty => {
            self.items.appendAssumeCapacity(.{
                .tag = .type_simple,
                .result_id = result_id,
                .data = @enumToInt(key.toSimpleType()),
            });
        },
        .int_ty => |int| {
            const t: Tag = switch (int.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            self.items.appendAssumeCapacity(.{
                .tag = t,
                .result_id = result_id,
                .data = int.bits,
            });
        },
        .float_ty => |float| {
            self.items.appendAssumeCapacity(.{
                .tag = .type_float,
                .result_id = result_id,
                .data = float.bits,
            });
        },
        .vector_ty => |vec| {
            const payload = try self.addExtra(vec);
            self.items.appendAssumeCapacity(.{
                .tag = .type_vector,
                .result_id = result_id,
                .data = payload,
            });
        },
    }

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
            .void => .void_ty,
            .bool => .bool_ty,
        },
        .type_int_signed => .{ .int_ty = .{
            .signedness = .signed,
            .bits = @intCast(u16, data),
        } },
        .type_int_unsigned => .{ .int_ty = .{
            .signedness = .unsigned,
            .bits = @intCast(u16, data),
        } },
        .type_float => .{ .float_ty = .{
            .bits = @intCast(u16, data),
        } },
        .type_vector => .{
            .vector_ty = self.extraData(Key.VectorType, data),
        },
    };
}

fn addExtra(self: *Self, gpa: Allocator, extra: anytype) !u32 {
    const fields = @typeInfo(@TypeOf(extra)).Struct.fields;
    try self.extra.ensureUnusedCapacity(gpa, fields.len);
    try self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Self, extra: anytype) !u32 {
    const payload_offset = @intCast(u32, self.extra.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields) |field| {
        const field_val = @field(field, field.name);
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
    var result: T = undefined;
    inline for (@typeInfo(T).Struct.fields, 0..) |field, i| {
        const word = self.extra.items[offset + i];
        @field(result, field.name) = switch (field.type) {
            u32 => word,
            Ref => @intToEnum(Ref, word),
            else => @compileError("Invalid type: " ++ @typeName(field.type)),
        };
    }
    return result;
}
