const std = @import("std");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;

pub const Class = enum { memory, byval, integer, double_integer };

pub fn classifyType(ty: Type, target: std.Target) Class {
    std.debug.assert(ty.hasRuntimeBitsIgnoreComptime());

    const max_byval_size = target.cpu.arch.ptrBitWidth() * 2;
    switch (ty.zigTypeTag()) {
        .Struct => {
            const bit_size = ty.bitSize(target);
            if (ty.containerLayout() == .Packed) {
                if (bit_size > max_byval_size) return .memory;
                return .byval;
            }
            // TODO this doesn't exactly match what clang produces but its better than nothing
            if (bit_size > max_byval_size) return .memory;
            if (bit_size > max_byval_size / 2) return .double_integer;
            return .integer;
        },
        .Union => {
            const bit_size = ty.bitSize(target);
            if (ty.containerLayout() == .Packed) {
                if (bit_size > max_byval_size) return .memory;
                return .byval;
            }
            // TODO this doesn't exactly match what clang produces but its better than nothing
            if (bit_size > max_byval_size) return .memory;
            if (bit_size > max_byval_size / 2) return .double_integer;
            return .integer;
        },
        .Bool => return .integer,
        .Float => return .byval,
        .Int, .Enum, .ErrorSet => {
            const bit_size = ty.bitSize(target);
            if (bit_size > max_byval_size) return .memory;
            return .byval;
        },
        .Vector => {
            const bit_size = ty.bitSize(target);
            if (bit_size > max_byval_size) return .memory;
            return .integer;
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

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};

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
