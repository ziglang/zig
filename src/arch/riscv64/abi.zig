const std = @import("std");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;
const Module = @import("../../Module.zig");

pub const Class = enum { memory, byval, integer, double_integer, fields, none };

pub fn classifyType(ty: Type, mod: *Module) Class {
    const target = mod.getTarget();
    std.debug.assert(ty.hasRuntimeBitsIgnoreComptime(mod));

    const max_byval_size = target.ptrBitWidth() * 2;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            const bit_size = ty.bitSize(mod);
            if (ty.containerLayout(mod) == .@"packed") {
                if (bit_size > max_byval_size) return .memory;
                return .byval;
            }

            if (std.Target.riscv.featureSetHas(target.cpu.features, .d)) fields: {
                var any_fp = false;
                var field_count: usize = 0;
                for (0..ty.structFieldCount(mod)) |field_index| {
                    const field_ty = ty.structFieldType(field_index, mod);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;
                    if (field_ty.isRuntimeFloat())
                        any_fp = true
                    else if (!field_ty.isAbiInt(mod))
                        break :fields;
                    field_count += 1;
                    if (field_count > 2) break :fields;
                }
                std.debug.assert(field_count > 0 and field_count <= 2);
                if (any_fp) return .fields;
            }

            // TODO this doesn't exactly match what clang produces but its better than nothing
            if (bit_size > max_byval_size) return .memory;
            if (bit_size > max_byval_size / 2) return .double_integer;
            return .integer;
        },
        .Union => {
            const bit_size = ty.bitSize(mod);
            if (ty.containerLayout(mod) == .@"packed") {
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
            const bit_size = ty.bitSize(mod);
            if (bit_size > max_byval_size) return .memory;
            return .byval;
        },
        .Vector => {
            const bit_size = ty.bitSize(mod);
            if (bit_size > max_byval_size) return .memory;
            return .integer;
        },
        .Optional => {
            std.debug.assert(ty.isPtrLikeOptional(mod));
            return .byval;
        },
        .Pointer => {
            std.debug.assert(!ty.isSlice(mod));
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

/// There are a maximum of 8 possible return slots. Returned values are in
/// the beginning of the array; unused slots are filled with .none.
pub fn classifySystemV(ty: Type, mod: *Module) [8]Class {
    const memory_class = [_]Class{
        .memory, .none, .none, .none,
        .none,   .none, .none, .none,
    };
    var result = [1]Class{.none} ** 8;
    switch (ty.zigTypeTag(mod)) {
        .Pointer => switch (ty.ptrSize(mod)) {
            .Slice => {
                result[0] = .integer;
                result[1] = .integer;
                return result;
            },
            else => {
                result[0] = .integer;
                return result;
            },
        },
        .Optional => {
            if (ty.isPtrLikeOptional(mod)) {
                result[0] = .integer;
                return result;
            }
            return memory_class;
        },
        else => return result,
    }
}

pub const callee_preserved_regs = [_]Register{
    .s0, .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
};

pub const function_arg_regs = [_]Register{
    .a0, .a1, .a2, .a3, .a4, .a5, .a6, .a7,
};

pub const temporary_regs = [_]Register{
    .t0, .t1, .t2, .t3, .t4, .t5, .t6,
};

const allocatable_registers = callee_preserved_regs ++ function_arg_regs ++ temporary_regs;
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

    pub const fa: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = callee_preserved_regs.len,
            .end = callee_preserved_regs.len + function_arg_regs.len,
        }, true);
        break :blk set;
    };

    pub const tp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = callee_preserved_regs.len + function_arg_regs.len,
            .end = callee_preserved_regs.len + function_arg_regs.len + temporary_regs.len,
        }, true);
        break :blk set;
    };
};
