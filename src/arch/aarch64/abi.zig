const std = @import("std");
const builtin = @import("builtin");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;

pub const Class = union(enum) {
    memory,
    byval,
    integer,
    double_integer,
    float_array: u8,
};

/// For `float_array` the second element will be the amount of floats.
pub fn classifyType(ty: Type, target: std.Target) Class {
    std.debug.assert(ty.hasRuntimeBitsIgnoreComptime());

    var maybe_float_bits: ?u16 = null;
    switch (ty.zigTypeTag()) {
        .Struct => {
            if (ty.containerLayout() == .Packed) return .byval;
            const float_count = countFloats(ty, target, &maybe_float_bits);
            if (float_count <= sret_float_count) return .{ .float_array = float_count };

            const bit_size = ty.bitSize(target);
            if (bit_size > 128) return .memory;
            if (bit_size > 64) return .double_integer;
            return .integer;
        },
        .Union => {
            if (ty.containerLayout() == .Packed) return .byval;
            const float_count = countFloats(ty, target, &maybe_float_bits);
            if (float_count <= sret_float_count) return .{ .float_array = float_count };

            const bit_size = ty.bitSize(target);
            if (bit_size > 128) return .memory;
            if (bit_size > 64) return .double_integer;
            return .integer;
        },
        .Int, .Enum, .ErrorSet, .Float, .Bool => return .byval,
        .Vector => {
            const bit_size = ty.bitSize(target);
            // TODO is this controlled by a cpu feature?
            if (bit_size > 128) return .memory;
            return .byval;
        },
        .Optional => {
            std.debug.assert(ty.isPtrLikeOptional());
            return .byval;
        },
        .Pointer => {
            std.debug.assert(!ty.isSlice());
            return .byval;
        },
        .ErrorUnion,
        .Frame,
        .AnyFrame,
        .NoReturn,
        .Void,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Opaque,
        .EnumLiteral,
        .Array,
        => unreachable,
    }
}

const sret_float_count = 4;
fn countFloats(ty: Type, target: std.Target, maybe_float_bits: *?u16) u8 {
    const invalid = std.math.maxInt(u8);
    switch (ty.zigTypeTag()) {
        .Union => {
            const fields = ty.unionFields();
            var max_count: u8 = 0;
            for (fields.values()) |field| {
                const field_count = countFloats(field.ty, target, maybe_float_bits);
                if (field_count == invalid) return invalid;
                if (field_count > max_count) max_count = field_count;
                if (max_count > sret_float_count) return invalid;
            }
            return max_count;
        },
        .Struct => {
            const fields_len = ty.structFieldCount();
            var count: u8 = 0;
            var i: u32 = 0;
            while (i < fields_len) : (i += 1) {
                const field_ty = ty.structFieldType(i);
                const field_count = countFloats(field_ty, target, maybe_float_bits);
                if (field_count == invalid) return invalid;
                count += field_count;
                if (count > sret_float_count) return invalid;
            }
            return count;
        },
        .Float => {
            const float_bits = maybe_float_bits.* orelse {
                maybe_float_bits.* = ty.floatBits(target);
                return 1;
            };
            if (ty.floatBits(target) == float_bits) return 1;
            return invalid;
        },
        .Void => return 0,
        else => return invalid,
    }
}

pub fn getFloatArrayType(ty: Type) ?Type {
    switch (ty.zigTypeTag()) {
        .Union => {
            const fields = ty.unionFields();
            for (fields.values()) |field| {
                if (getFloatArrayType(field.ty)) |some| return some;
            }
            return null;
        },
        .Struct => {
            const fields_len = ty.structFieldCount();
            var i: u32 = 0;
            while (i < fields_len) : (i += 1) {
                const field_ty = ty.structFieldType(i);
                if (getFloatArrayType(field_ty)) |some| return some;
            }
            return null;
        },
        .Float => return ty,
        else => return null,
    }
}

const callee_preserved_regs_impl = if (builtin.os.tag.isDarwin()) struct {
    pub const callee_preserved_regs = [_]Register{
        .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27,
        .x28,
    };
} else struct {
    pub const callee_preserved_regs = [_]Register{
        .x19, .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27, .x28,
    };
};
pub const callee_preserved_regs = callee_preserved_regs_impl.callee_preserved_regs;

pub const c_abi_int_param_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
pub const c_abi_int_return_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };

const allocatable_registers = callee_preserved_regs;
pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &allocatable_registers);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
pub const RegisterClass = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = callee_preserved_regs.len,
        }, true);
        break :blk set;
    };
};
