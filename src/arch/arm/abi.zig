const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;
const Module = @import("../../Module.zig");

pub const Class = union(enum) {
    memory,
    byval,
    i32_array: u8,
    i64_array: u8,

    fn arrSize(total_size: u64, arr_size: u64) Class {
        const count = @as(u8, @intCast(std.mem.alignForward(u64, total_size, arr_size) / arr_size));
        if (arr_size == 32) {
            return .{ .i32_array = count };
        } else {
            return .{ .i64_array = count };
        }
    }
};

pub const Context = enum { ret, arg };

pub fn classifyType(ty: Type, mod: *Module, ctx: Context) Class {
    assert(ty.hasRuntimeBitsIgnoreComptime(mod));

    var maybe_float_bits: ?u16 = null;
    const max_byval_size = 512;
    const ip = &mod.intern_pool;
    switch (ty.zigTypeTag(mod)) {
        .Struct => {
            const bit_size = ty.bitSize(mod);
            if (ty.containerLayout(mod) == .@"packed") {
                if (bit_size > 64) return .memory;
                return .byval;
            }
            if (bit_size > max_byval_size) return .memory;
            const float_count = countFloats(ty, mod, &maybe_float_bits);
            if (float_count <= byval_float_count) return .byval;

            const fields = ty.structFieldCount(mod);
            var i: u32 = 0;
            while (i < fields) : (i += 1) {
                const field_ty = ty.structFieldType(i, mod);
                const field_alignment = ty.structFieldAlign(i, mod);
                const field_size = field_ty.bitSize(mod);
                if (field_size > 32 or field_alignment.compare(.gt, .@"32")) {
                    return Class.arrSize(bit_size, 64);
                }
            }
            return Class.arrSize(bit_size, 32);
        },
        .Union => {
            const bit_size = ty.bitSize(mod);
            const union_obj = mod.typeToUnion(ty).?;
            if (union_obj.getLayout(ip) == .@"packed") {
                if (bit_size > 64) return .memory;
                return .byval;
            }
            if (bit_size > max_byval_size) return .memory;
            const float_count = countFloats(ty, mod, &maybe_float_bits);
            if (float_count <= byval_float_count) return .byval;

            for (union_obj.field_types.get(ip), 0..) |field_ty, field_index| {
                if (Type.fromInterned(field_ty).bitSize(mod) > 32 or
                    mod.unionFieldNormalAlignment(union_obj, @intCast(field_index)).compare(.gt, .@"32"))
                {
                    return Class.arrSize(bit_size, 64);
                }
            }
            return Class.arrSize(bit_size, 32);
        },
        .Bool, .Float => return .byval,
        .Int => {
            // TODO this is incorrect for _BitInt(128) but implementing
            // this correctly makes implementing compiler-rt impossible.
            // const bit_size = ty.bitSize(mod);
            // if (bit_size > 64) return .memory;
            return .byval;
        },
        .Enum, .ErrorSet => {
            const bit_size = ty.bitSize(mod);
            if (bit_size > 64) return .memory;
            return .byval;
        },
        .Vector => {
            const bit_size = ty.bitSize(mod);
            // TODO is this controlled by a cpu feature?
            if (ctx == .ret and bit_size > 128) return .memory;
            if (bit_size > 512) return .memory;
            return .byval;
        },
        .Optional => {
            assert(ty.isPtrLikeOptional(mod));
            return .byval;
        },
        .Pointer => {
            assert(!ty.isSlice(mod));
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

const byval_float_count = 4;
fn countFloats(ty: Type, mod: *Module, maybe_float_bits: *?u16) u32 {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    const invalid = std.math.maxInt(u32);
    switch (ty.zigTypeTag(mod)) {
        .Union => {
            const union_obj = mod.typeToUnion(ty).?;
            var max_count: u32 = 0;
            for (union_obj.field_types.get(ip)) |field_ty| {
                const field_count = countFloats(Type.fromInterned(field_ty), mod, maybe_float_bits);
                if (field_count == invalid) return invalid;
                if (field_count > max_count) max_count = field_count;
                if (max_count > byval_float_count) return invalid;
            }
            return max_count;
        },
        .Struct => {
            const fields_len = ty.structFieldCount(mod);
            var count: u32 = 0;
            var i: u32 = 0;
            while (i < fields_len) : (i += 1) {
                const field_ty = ty.structFieldType(i, mod);
                const field_count = countFloats(field_ty, mod, maybe_float_bits);
                if (field_count == invalid) return invalid;
                count += field_count;
                if (count > byval_float_count) return invalid;
            }
            return count;
        },
        .Float => {
            const float_bits = maybe_float_bits.* orelse {
                const float_bits = ty.floatBits(target);
                if (float_bits != 32 and float_bits != 64) return invalid;
                maybe_float_bits.* = float_bits;
                return 1;
            };
            if (ty.floatBits(target) == float_bits) return 1;
            return invalid;
        },
        .Void => return 0,
        else => return invalid,
    }
}

pub const callee_preserved_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r10 };
pub const caller_preserved_regs = [_]Register{ .r0, .r1, .r2, .r3 };

pub const c_abi_int_param_regs = [_]Register{ .r0, .r1, .r2, .r3 };
pub const c_abi_int_return_regs = [_]Register{ .r0, .r1 };

const allocatable_registers = callee_preserved_regs ++ caller_preserved_regs;
pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &allocatable_registers);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
pub const RegisterClass = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = caller_preserved_regs.len + callee_preserved_regs.len,
        }, true);
        break :blk set;
    };
};
