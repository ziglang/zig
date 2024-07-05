const std = @import("std");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../Type.zig");
const InternPool = @import("../../InternPool.zig");
const Zcu = @import("../../Zcu.zig");
const assert = std.debug.assert;

pub const Class = enum { memory, byval, integer, double_integer, fields };

pub fn classifyType(ty: Type, pt: Zcu.PerThread) Class {
    const target = pt.zcu.getTarget();
    std.debug.assert(ty.hasRuntimeBitsIgnoreComptime(pt));

    const max_byval_size = target.ptrBitWidth() * 2;
    switch (ty.zigTypeTag(pt.zcu)) {
        .Struct => {
            const bit_size = ty.bitSize(pt);
            if (ty.containerLayout(pt.zcu) == .@"packed") {
                if (bit_size > max_byval_size) return .memory;
                return .byval;
            }

            if (std.Target.riscv.featureSetHas(target.cpu.features, .d)) fields: {
                var any_fp = false;
                var field_count: usize = 0;
                for (0..ty.structFieldCount(pt.zcu)) |field_index| {
                    const field_ty = ty.structFieldType(field_index, pt.zcu);
                    if (!field_ty.hasRuntimeBitsIgnoreComptime(pt)) continue;
                    if (field_ty.isRuntimeFloat())
                        any_fp = true
                    else if (!field_ty.isAbiInt(pt.zcu))
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
            const bit_size = ty.bitSize(pt);
            if (ty.containerLayout(pt.zcu) == .@"packed") {
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
            const bit_size = ty.bitSize(pt);
            if (bit_size > max_byval_size) return .memory;
            return .byval;
        },
        .Vector => {
            const bit_size = ty.bitSize(pt);
            if (bit_size > max_byval_size) return .memory;
            return .integer;
        },
        .Optional => {
            std.debug.assert(ty.isPtrLikeOptional(pt.zcu));
            return .byval;
        },
        .Pointer => {
            std.debug.assert(!ty.isSlice(pt.zcu));
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

pub const SystemClass = enum { integer, float, memory, none };

/// There are a maximum of 8 possible return slots. Returned values are in
/// the beginning of the array; unused slots are filled with .none.
pub fn classifySystem(ty: Type, pt: Zcu.PerThread) [8]SystemClass {
    const zcu = pt.zcu;
    var result = [1]SystemClass{.none} ** 8;
    const memory_class = [_]SystemClass{
        .memory, .none, .none, .none,
        .none,   .none, .none, .none,
    };
    switch (ty.zigTypeTag(pt.zcu)) {
        .Bool, .Void, .NoReturn => {
            result[0] = .integer;
            return result;
        },
        .Pointer => switch (ty.ptrSize(pt.zcu)) {
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
            if (ty.isPtrLikeOptional(pt.zcu)) {
                result[0] = .integer;
                return result;
            }
            result[0] = .integer;
            if (ty.optionalChild(zcu).abiSize(pt) == 0) return result;
            result[1] = .integer;
            return result;
        },
        .Int, .Enum, .ErrorSet => {
            const int_bits = ty.intInfo(pt.zcu).bits;
            if (int_bits <= 64) {
                result[0] = .integer;
                return result;
            }
            if (int_bits <= 128) {
                result[0] = .integer;
                result[1] = .integer;
                return result;
            }
            unreachable; // support > 128 bit int arguments
        },
        .Float => {
            const target = zcu.getTarget();
            const features = target.cpu.features;

            const float_bits = ty.floatBits(zcu.getTarget());
            const float_reg_size: u32 = if (std.Target.riscv.featureSetHas(features, .d)) 64 else 32;
            if (float_bits <= float_reg_size) {
                result[0] = .float;
                return result;
            }
            unreachable; // support split float args
        },
        .ErrorUnion => {
            const payload_ty = ty.errorUnionPayload(pt.zcu);
            const payload_bits = payload_ty.bitSize(pt);

            // the error union itself
            result[0] = .integer;

            // anyerror!void can fit into one register
            if (payload_bits == 0) return result;

            return memory_class;
        },
        .Struct => {
            const layout = ty.containerLayout(pt.zcu);
            const ty_size = ty.abiSize(pt);

            if (layout == .@"packed") {
                assert(ty_size <= 16);
                result[0] = .integer;
                if (ty_size > 8) result[1] = .integer;
                return result;
            }

            return memory_class;
        },
        .Array => {
            const ty_size = ty.abiSize(pt);
            if (ty_size <= 8) {
                result[0] = .integer;
                return result;
            }
            if (ty_size <= 16) {
                result[0] = .integer;
                result[1] = .integer;
                return result;
            }
            return memory_class;
        },
        .Vector => {
            // we pass vectors through integer registers if they are small enough to fit.
            const vec_bits = ty.totalVectorBits(pt);
            if (vec_bits <= 64) {
                result[0] = .integer;
                return result;
            }
            // we should pass vector registers of size <= 128 through 2 integer registers
            // but we haven't implemented seperating vector registers into register_pairs
            return memory_class;
        },
        else => |bad_ty| std.debug.panic("classifySystem {s}", .{@tagName(bad_ty)}),
    }
}

fn classifyStruct(
    result: *[8]Class,
    byte_offset: *u64,
    loaded_struct: InternPool.LoadedStructType,
    zcu: *Zcu,
) void {
    const ip = &zcu.intern_pool;
    var field_it = loaded_struct.iterateRuntimeOrder(ip);

    while (field_it.next()) |field_index| {
        const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
        const field_align = loaded_struct.fieldAlign(ip, field_index);
        byte_offset.* = std.mem.alignForward(
            u64,
            byte_offset.*,
            field_align.toByteUnits() orelse field_ty.abiAlignment(zcu).toByteUnits().?,
        );
        if (zcu.typeToStruct(field_ty)) |field_loaded_struct| {
            if (field_loaded_struct.layout != .@"packed") {
                classifyStruct(result, byte_offset, field_loaded_struct, zcu);
                continue;
            }
        }
        const field_class = std.mem.sliceTo(&classifySystem(field_ty, zcu), .none);
        const field_size = field_ty.abiSize(zcu);

        combine: {
            const result_class = &result[@intCast(byte_offset.* / 8)];
            if (result_class.* == field_class[0]) {
                break :combine;
            }

            if (result_class.* == .none) {
                result_class.* = field_class[0];
                break :combine;
            }
            assert(field_class[0] != .none);

            // "If one of the classes is MEMORY, the result is the MEMORY class."
            if (result_class.* == .memory or field_class[0] == .memory) {
                result_class.* = .memory;
                break :combine;
            }

            // "If one of the classes is INTEGER, the result is the INTEGER."
            if (result_class.* == .integer or field_class[0] == .integer) {
                result_class.* = .integer;
                break :combine;
            }

            result_class.* = .integer;
        }
        @memcpy(result[@intCast(byte_offset.* / 8 + 1)..][0 .. field_class.len - 1], field_class[1..]);
        byte_offset.* += field_size;
    }
}

const allocatable_registers = Registers.Integer.all_regs ++ Registers.Float.all_regs ++ Registers.Vector.all_regs;
pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &allocatable_registers);

const RegisterBitSet = RegisterManager.RegisterBitSet;

pub const RegisterClass = enum {
    int,
    float,
    vector,
};

pub const Registers = struct {
    pub const all_preserved = Integer.callee_preserved_regs ++ Float.callee_preserved_regs;

    pub const Integer = struct {
        // zig fmt: off
        pub const general_purpose = initRegBitSet(0,                                                 callee_preserved_regs.len);
        pub const function_arg    = initRegBitSet(callee_preserved_regs.len,                         function_arg_regs.len);
        pub const function_ret    = initRegBitSet(callee_preserved_regs.len,                         function_ret_regs.len);
        pub const temporary       = initRegBitSet(callee_preserved_regs.len + function_arg_regs.len, temporary_regs.len);
        // zig fmt: on

        pub const callee_preserved_regs = [_]Register{
            // .s0 is omitted to be used as the frame pointer register
            .s1, .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
        };

        pub const function_arg_regs = [_]Register{
            .a0, .a1, .a2, .a3, .a4, .a5, .a6, .a7,
        };

        pub const function_ret_regs = [_]Register{
            .a0, .a1,
        };

        pub const temporary_regs = [_]Register{
            .t0, .t1, .t2, .t3, .t4, .t5, .t6,
        };

        pub const all_regs = callee_preserved_regs ++ function_arg_regs ++ temporary_regs;
    };

    pub const Float = struct {
        // zig fmt: off
        pub const general_purpose = initRegBitSet(Integer.all_regs.len,                                                     callee_preserved_regs.len);
        pub const function_arg    = initRegBitSet(Integer.all_regs.len + callee_preserved_regs.len,                         function_arg_regs.len);
        pub const function_ret    = initRegBitSet(Integer.all_regs.len + callee_preserved_regs.len,                         function_ret_regs.len);
        pub const temporary       = initRegBitSet(Integer.all_regs.len + callee_preserved_regs.len + function_arg_regs.len, temporary_regs.len);
        // zig fmt: on

        pub const callee_preserved_regs = [_]Register{
            .fs0, .fs1, .fs2, .fs3, .fs4, .fs5, .fs6, .fs7, .fs8, .fs9, .fs10, .fs11,
        };

        pub const function_arg_regs = [_]Register{
            .fa0, .fa1, .fa2, .fa3, .fa4, .fa5, .fa6, .fa7,
        };

        pub const function_ret_regs = [_]Register{
            .fa0, .fa1,
        };

        pub const temporary_regs = [_]Register{
            .ft0, .ft1, .ft2, .ft3, .ft4, .ft5, .ft6, .ft7, .ft8, .ft9, .ft10, .ft11,
        };

        pub const all_regs = callee_preserved_regs ++ function_arg_regs ++ temporary_regs;
    };

    pub const Vector = struct {
        pub const general_purpose = initRegBitSet(Integer.all_regs.len + Float.all_regs.len, all_regs.len);

        // zig fmt: off
        pub const all_regs = [_]Register{
            .v0,  .v1,  .v2,  .v3,  .v4,  .v5,  .v6,  .v7,
            .v8,  .v9,  .v10, .v11, .v12, .v13, .v14, .v15,
            .v16, .v17, .v18, .v19, .v20, .v21, .v22, .v23,
            .v24, .v25, .v26, .v27, .v28, .v29, .v30, .v31,
        };
        // zig fmt: on
    };
};

fn initRegBitSet(start: usize, length: usize) RegisterBitSet {
    var set = RegisterBitSet.initEmpty();
    set.setRangeValue(.{
        .start = start,
        .end = start + length,
    }, true);
    return set;
}
