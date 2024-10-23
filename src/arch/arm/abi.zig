const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");

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

pub fn classifyType(ty: Type, zcu: *Zcu, ctx: Context) Class {
    assert(ty.hasRuntimeBitsIgnoreComptime(zcu));

    var maybe_float_bits: ?u16 = null;
    const max_byval_size = 512;
    const ip = &zcu.intern_pool;
    switch (ty.zigTypeTag(zcu)) {
        .@"struct" => {
            const bit_size = ty.bitSize(zcu);
            if (ty.containerLayout(zcu) == .@"packed") {
                if (bit_size > 64) return .memory;
                return .byval;
            }
            if (bit_size > max_byval_size) return .memory;
            const float_count = countFloats(ty, zcu, &maybe_float_bits);
            if (float_count <= byval_float_count) return .byval;

            const fields = ty.structFieldCount(zcu);
            var i: u32 = 0;
            while (i < fields) : (i += 1) {
                const field_ty = ty.fieldType(i, zcu);
                const field_alignment = ty.fieldAlignment(i, zcu);
                const field_size = field_ty.bitSize(zcu);
                if (field_size > 32 or field_alignment.compare(.gt, .@"32")) {
                    return Class.arrSize(bit_size, 64);
                }
            }
            return Class.arrSize(bit_size, 32);
        },
        .@"union" => {
            const bit_size = ty.bitSize(zcu);
            const union_obj = zcu.typeToUnion(ty).?;
            if (union_obj.flagsUnordered(ip).layout == .@"packed") {
                if (bit_size > 64) return .memory;
                return .byval;
            }
            if (bit_size > max_byval_size) return .memory;
            const float_count = countFloats(ty, zcu, &maybe_float_bits);
            if (float_count <= byval_float_count) return .byval;

            for (union_obj.field_types.get(ip), 0..) |field_ty, field_index| {
                if (Type.fromInterned(field_ty).bitSize(zcu) > 32 or
                    ty.fieldAlignment(field_index, zcu).compare(.gt, .@"32"))
                {
                    return Class.arrSize(bit_size, 64);
                }
            }
            return Class.arrSize(bit_size, 32);
        },
        .bool, .float => return .byval,
        .int => {
            // TODO this is incorrect for _BitInt(128) but implementing
            // this correctly makes implementing compiler-rt impossible.
            // const bit_size = ty.bitSize(zcu);
            // if (bit_size > 64) return .memory;
            return .byval;
        },
        .@"enum", .error_set => {
            const bit_size = ty.bitSize(zcu);
            if (bit_size > 64) return .memory;
            return .byval;
        },
        .vector => {
            const bit_size = ty.bitSize(zcu);
            // TODO is this controlled by a cpu feature?
            if (ctx == .ret and bit_size > 128) return .memory;
            if (bit_size > 512) return .memory;
            return .byval;
        },
        .optional => {
            assert(ty.isPtrLikeOptional(zcu));
            return .byval;
        },
        .pointer => {
            assert(!ty.isSlice(zcu));
            return .byval;
        },
        .error_union,
        .frame,
        .@"anyframe",
        .noreturn,
        .void,
        .type,
        .comptime_float,
        .comptime_int,
        .undefined,
        .null,
        .@"fn",
        .@"opaque",
        .enum_literal,
        .array,
        => unreachable,
    }
}

const byval_float_count = 4;
fn countFloats(ty: Type, zcu: *Zcu, maybe_float_bits: *?u16) u32 {
    const ip = &zcu.intern_pool;
    const target = zcu.getTarget();
    const invalid = std.math.maxInt(u32);
    switch (ty.zigTypeTag(zcu)) {
        .@"union" => {
            const union_obj = zcu.typeToUnion(ty).?;
            var max_count: u32 = 0;
            for (union_obj.field_types.get(ip)) |field_ty| {
                const field_count = countFloats(Type.fromInterned(field_ty), zcu, maybe_float_bits);
                if (field_count == invalid) return invalid;
                if (field_count > max_count) max_count = field_count;
                if (max_count > byval_float_count) return invalid;
            }
            return max_count;
        },
        .@"struct" => {
            const fields_len = ty.structFieldCount(zcu);
            var count: u32 = 0;
            var i: u32 = 0;
            while (i < fields_len) : (i += 1) {
                const field_ty = ty.fieldType(i, zcu);
                const field_count = countFloats(field_ty, zcu, maybe_float_bits);
                if (field_count == invalid) return invalid;
                count += field_count;
                if (count > byval_float_count) return invalid;
            }
            return count;
        },
        .float => {
            const float_bits = maybe_float_bits.* orelse {
                const float_bits = ty.floatBits(target);
                if (float_bits != 32 and float_bits != 64) return invalid;
                maybe_float_bits.* = float_bits;
                return 1;
            };
            if (ty.floatBits(target) == float_bits) return 1;
            return invalid;
        },
        .void => return 0,
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
