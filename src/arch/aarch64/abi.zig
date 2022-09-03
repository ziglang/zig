const std = @import("std");
const builtin = @import("builtin");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;

pub const Class = enum { memory, integer, none, float_array };

pub fn classifyType(ty: Type, target: std.Target) [2]Class {
    if (!ty.hasRuntimeBitsIgnoreComptime()) return .{ .none, .none };
    switch (ty.zigTypeTag()) {
        .Struct => {
            if (ty.containerLayout() == .Packed) return .{ .integer, .none };

            if (ty.structFieldCount() <= 4) {
                const fields = ty.structFields();
                var float_size: ?u64 = null;
                for (fields.values()) |field| {
                    if (field.ty.zigTypeTag() != .Float) break;
                    const field_size = field.ty.bitSize(target);
                    const prev_size = float_size orelse {
                        float_size = field_size;
                        continue;
                    };
                    if (field_size != prev_size) break;
                } else {
                    return .{ .float_array, .none };
                }
            }
            const bit_size = ty.bitSize(target);
            if (bit_size > 128) return .{ .memory, .none };
            if (bit_size > 64) return .{ .integer, .integer };
            return .{ .integer, .none };
        },
        .Union => {
            const bit_size = ty.bitSize(target);
            if (bit_size > 128) return .{ .memory, .none };
            if (bit_size > 64) return .{ .integer, .integer };
            return .{ .integer, .none };
        },
        .Int, .Enum, .ErrorSet, .Vector, .Float, .Bool => return .{ .integer, .none },
        .Array => return .{ .memory, .none },
        .Optional => {
            std.debug.assert(ty.isPtrLikeOptional());
            return .{ .integer, .none };
        },
        .Pointer => {
            std.debug.assert(!ty.isSlice());
            return .{ .integer, .none };
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
        .BoundFn,
        .Fn,
        .Opaque,
        .EnumLiteral,
        => unreachable,
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
