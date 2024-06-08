pub const Class = enum {
    integer,
    sse,
    sseup,
    x87,
    x87up,
    complex_x87,
    memory,
    none,
    win_i128,
    float,
    float_combine,
    integer_per_element,

    fn isX87(class: Class) bool {
        return switch (class) {
            .x87, .x87up, .complex_x87 => true,
            else => false,
        };
    }

    /// Combine a field class with the prev one.
    fn combineSystemV(prev_class: Class, next_class: Class) Class {
        // "If both classes are equal, this is the resulting class."
        if (prev_class == next_class)
            return if (prev_class == .float) .float_combine else prev_class;

        // "If one of the classes is NO_CLASS, the resulting class
        // is the other class."
        if (prev_class == .none) return next_class;

        // "If one of the classes is MEMORY, the result is the MEMORY class."
        if (prev_class == .memory or next_class == .memory) return .memory;

        // "If one of the classes is INTEGER, the result is the INTEGER."
        if (prev_class == .integer or next_class == .integer) return .integer;

        // "If one of the classes is X87, X87UP, COMPLEX_X87 class,
        // MEMORY is used as class."
        if (prev_class.isX87() or next_class.isX87()) return .memory;

        // "Otherwise class SSE is used."
        return .sse;
    }
};

pub fn classifyWindows(ty: Type, zcu: *Zcu) Class {
    // https://docs.microsoft.com/en-gb/cpp/build/x64-calling-convention?view=vs-2017
    // "There's a strict one-to-one correspondence between a function call's arguments
    // and the registers used for those arguments. Any argument that doesn't fit in 8
    // bytes, or isn't 1, 2, 4, or 8 bytes, must be passed by reference. A single argument
    // is never spread across multiple registers."
    // "All floating point operations are done using the 16 XMM registers."
    // "Structs and unions of size 8, 16, 32, or 64 bits, and __m64 types, are passed
    // as if they were integers of the same size."
    switch (ty.zigTypeTag(zcu)) {
        .Pointer,
        .Int,
        .Bool,
        .Enum,
        .Void,
        .NoReturn,
        .ErrorSet,
        .Struct,
        .Union,
        .Optional,
        .Array,
        .ErrorUnion,
        .AnyFrame,
        .Frame,
        => switch (ty.abiSize(zcu)) {
            0 => unreachable,
            1, 2, 4, 8 => return .integer,
            else => switch (ty.zigTypeTag(zcu)) {
                .Int => return .win_i128,
                .Struct, .Union => if (ty.containerLayout(zcu) == .@"packed") {
                    return .win_i128;
                } else {
                    return .memory;
                },
                else => return .memory,
            },
        },

        .Float, .Vector => return .sse,

        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .Opaque,
        .EnumLiteral,
        => unreachable,
    }
}

pub const Context = enum { ret, arg, field, other };

/// There are a maximum of 8 possible return slots. Returned values are in
/// the beginning of the array; unused slots are filled with .none.
pub fn classifySystemV(ty: Type, zcu: *Zcu, target: std.Target, ctx: Context) [8]Class {
    const memory_class = [_]Class{
        .memory, .none, .none, .none,
        .none,   .none, .none, .none,
    };
    var result = [1]Class{.none} ** 8;
    switch (ty.zigTypeTag(zcu)) {
        .Pointer => switch (ty.ptrSize(zcu)) {
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
        .Int, .Enum, .ErrorSet => {
            const bits = ty.intInfo(zcu).bits;
            if (bits <= 64) {
                result[0] = .integer;
                return result;
            }
            if (bits <= 128) {
                result[0] = .integer;
                result[1] = .integer;
                return result;
            }
            if (bits <= 192) {
                result[0] = .integer;
                result[1] = .integer;
                result[2] = .integer;
                return result;
            }
            if (bits <= 256) {
                result[0] = .integer;
                result[1] = .integer;
                result[2] = .integer;
                result[3] = .integer;
                return result;
            }
            return memory_class;
        },
        .Bool, .Void, .NoReturn => {
            result[0] = .integer;
            return result;
        },
        .Float => switch (ty.floatBits(target)) {
            16 => {
                if (ctx == .field) {
                    result[0] = .memory;
                } else {
                    // TODO clang doesn't allow __fp16 as .ret or .arg
                    result[0] = .sse;
                }
                return result;
            },
            32 => {
                result[0] = .float;
                return result;
            },
            64 => {
                result[0] = .sse;
                return result;
            },
            128 => {
                // "Arguments of types __float128, _Decimal128 and __m128 are
                // split into two halves.  The least significant ones belong
                // to class SSE, the most significant one to class SSEUP."
                result[0] = .sse;
                result[1] = .sseup;
                return result;
            },
            80 => {
                // "The 64-bit mantissa of arguments of type long double
                // belongs to classX87, the 16-bit exponent plus 6 bytes
                // of padding belongs to class X87UP."
                result[0] = .x87;
                result[1] = .x87up;
                return result;
            },
            else => unreachable,
        },
        .Vector => {
            const elem_ty = ty.childType(zcu);
            const bits = elem_ty.bitSize(zcu) * ty.arrayLen(zcu);
            if (elem_ty.toIntern() == .bool_type) {
                if (bits <= 32) return .{
                    .integer, .none, .none, .none,
                    .none,    .none, .none, .none,
                };
                if (bits <= 64) return .{
                    .sse,  .none, .none, .none,
                    .none, .none, .none, .none,
                };
                if (ctx == .arg) {
                    if (bits <= 128) return .{
                        .integer_per_element, .none, .none, .none,
                        .none,                .none, .none, .none,
                    };
                    if (bits <= 256 and std.Target.x86.featureSetHas(target.cpu.features, .avx)) return .{
                        .integer_per_element, .none, .none, .none,
                        .none,                .none, .none, .none,
                    };
                    if (bits <= 512 and std.Target.x86.featureSetHas(target.cpu.features, .avx512f)) return .{
                        .integer_per_element, .none, .none, .none,
                        .none,                .none, .none, .none,
                    };
                }
                return memory_class;
            }
            if (bits <= 64) return .{
                .sse,  .none, .none, .none,
                .none, .none, .none, .none,
            };
            if (bits <= 128) return .{
                .sse,  .sseup, .none, .none,
                .none, .none,  .none, .none,
            };
            if (ctx == .arg and !std.Target.x86.featureSetHas(target.cpu.features, .avx)) return memory_class;
            if (bits <= 192) return .{
                .sse,  .sseup, .sseup, .none,
                .none, .none,  .none,  .none,
            };
            if (bits <= 256) return .{
                .sse,  .sseup, .sseup, .sseup,
                .none, .none,  .none,  .none,
            };
            if (ctx == .arg and !std.Target.x86.featureSetHas(target.cpu.features, .avx512f)) return memory_class;
            if (bits <= 320) return .{
                .sse,   .sseup, .sseup, .sseup,
                .sseup, .none,  .none,  .none,
            };
            if (bits <= 384) return .{
                .sse,   .sseup, .sseup, .sseup,
                .sseup, .sseup, .none,  .none,
            };
            if (bits <= 448) return .{
                .sse,   .sseup, .sseup, .sseup,
                .sseup, .sseup, .sseup, .none,
            };
            // LLVM always returns vectors byval
            if (bits <= 512 or ctx == .ret) return .{
                .sse,   .sseup, .sseup, .sseup,
                .sseup, .sseup, .sseup, .sseup,
            };
            return memory_class;
        },
        .Optional => {
            if (ty.isPtrLikeOptional(zcu)) {
                result[0] = .integer;
                return result;
            }
            return memory_class;
        },
        .Struct, .Union => {
            // "If the size of an object is larger than eight eightbytes, or
            // it contains unaligned fields, it has class MEMORY"
            // "If the size of the aggregate exceeds a single eightbyte, each is classified
            // separately.".
            const ty_size = ty.abiSize(zcu);
            switch (ty.containerLayout(zcu)) {
                .auto, .@"extern" => {},
                .@"packed" => {
                    assert(ty_size <= 16);
                    result[0] = .integer;
                    if (ty_size > 8) result[1] = .integer;
                    return result;
                },
            }
            if (ty_size > 64)
                return memory_class;

            _ = if (zcu.typeToStruct(ty)) |loaded_struct|
                classifySystemVStruct(&result, 0, loaded_struct, zcu, target)
            else if (zcu.typeToUnion(ty)) |loaded_union|
                classifySystemVUnion(&result, 0, loaded_union, zcu, target)
            else
                unreachable;

            // Post-merger cleanup

            // "If one of the classes is MEMORY, the whole argument is passed in memory"
            // "If X87UP is not preceded by X87, the whole argument is passed in memory."
            for (result, 0..) |class, i| switch (class) {
                .memory => return memory_class,
                .x87up => if (i == 0 or result[i - 1] != .x87) return memory_class,
                else => continue,
            };
            // "If the size of the aggregate exceeds two eightbytes and the first eight-
            // byte isn’t SSE or any other eightbyte isn’t SSEUP, the whole argument
            // is passed in memory."
            if (ty_size > 16 and (result[0] != .sse or
                std.mem.indexOfNone(Class, result[1..], &.{ .sseup, .none }) != null)) return memory_class;

            // "If SSEUP is not preceded by SSE or SSEUP, it is converted to SSE."
            for (&result, 0..) |*item, i| {
                if (item.* == .sseup) switch (result[i - 1]) {
                    .sse, .sseup => continue,
                    else => item.* = .sse,
                };
            }
            return result;
        },
        .Array => {
            const ty_size = ty.abiSize(zcu);
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
        else => unreachable,
    }
}

fn classifySystemVStruct(
    result: *[8]Class,
    starting_byte_offset: u64,
    loaded_struct: InternPool.LoadedStructType,
    zcu: *Zcu,
    target: std.Target,
) u64 {
    const ip = &zcu.intern_pool;
    var byte_offset = starting_byte_offset;
    var field_it = loaded_struct.iterateRuntimeOrder(ip);
    while (field_it.next()) |field_index| {
        const field_ty = Type.fromInterned(loaded_struct.field_types.get(ip)[field_index]);
        const field_align = loaded_struct.fieldAlign(ip, field_index);
        byte_offset = std.mem.alignForward(
            u64,
            byte_offset,
            field_align.toByteUnits() orelse field_ty.abiAlignment(zcu).toByteUnits().?,
        );
        if (zcu.typeToStruct(field_ty)) |field_loaded_struct| {
            switch (field_loaded_struct.layout) {
                .auto, .@"extern" => {
                    byte_offset = classifySystemVStruct(result, byte_offset, field_loaded_struct, zcu, target);
                    continue;
                },
                .@"packed" => {},
            }
        } else if (zcu.typeToUnion(field_ty)) |field_loaded_union| {
            switch (field_loaded_union.getLayout(ip)) {
                .auto, .@"extern" => {
                    byte_offset = classifySystemVUnion(result, byte_offset, field_loaded_union, zcu, target);
                    continue;
                },
                .@"packed" => {},
            }
        }
        const field_classes = std.mem.sliceTo(&classifySystemV(field_ty, zcu, target, .field), .none);
        for (result[@intCast(byte_offset / 8)..][0..field_classes.len], field_classes) |*result_class, field_class|
            result_class.* = result_class.combineSystemV(field_class);
        byte_offset += field_ty.abiSize(zcu);
    }
    const final_byte_offset = starting_byte_offset + loaded_struct.size(ip).*;
    std.debug.assert(final_byte_offset == std.mem.alignForward(
        u64,
        byte_offset,
        loaded_struct.flagsPtr(ip).alignment.toByteUnits().?,
    ));
    return final_byte_offset;
}

fn classifySystemVUnion(
    result: *[8]Class,
    starting_byte_offset: u64,
    loaded_union: InternPool.LoadedUnionType,
    zcu: *Zcu,
    target: std.Target,
) u64 {
    const ip = &zcu.intern_pool;
    for (0..loaded_union.field_types.len) |field_index| {
        const field_ty = Type.fromInterned(loaded_union.field_types.get(ip)[field_index]);
        if (zcu.typeToStruct(field_ty)) |field_loaded_struct| {
            switch (field_loaded_struct.layout) {
                .auto, .@"extern" => {
                    _ = classifySystemVStruct(result, starting_byte_offset, field_loaded_struct, zcu, target);
                    continue;
                },
                .@"packed" => {},
            }
        } else if (zcu.typeToUnion(field_ty)) |field_loaded_union| {
            switch (field_loaded_union.getLayout(ip)) {
                .auto, .@"extern" => {
                    _ = classifySystemVUnion(result, starting_byte_offset, field_loaded_union, zcu, target);
                    continue;
                },
                .@"packed" => {},
            }
        }
        const field_classes = std.mem.sliceTo(&classifySystemV(field_ty, zcu, target, .field), .none);
        for (result[@intCast(starting_byte_offset / 8)..][0..field_classes.len], field_classes) |*result_class, field_class|
            result_class.* = result_class.combineSystemV(field_class);
    }
    return starting_byte_offset + loaded_union.size(ip).*;
}

pub const SysV = struct {
    /// Note that .rsp and .rbp also belong to this set, however, we never expect to use them
    /// for anything else but stack offset tracking therefore we exclude them from this set.
    pub const callee_preserved_regs = [_]Register{ .rbx, .r12, .r13, .r14, .r15 };
    /// These registers need to be preserved (saved on the stack) and restored by the caller before
    /// the caller relinquishes control to a subroutine via call instruction (or similar).
    /// In other words, these registers are free to use by the callee.
    pub const caller_preserved_regs = [_]Register{ .rax, .rcx, .rdx, .rsi, .rdi, .r8, .r9, .r10, .r11 } ++ x87_regs ++ sse_avx_regs;

    pub const c_abi_int_param_regs = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
    pub const c_abi_sse_param_regs = sse_avx_regs[0..8].*;
    pub const c_abi_int_return_regs = [_]Register{ .rax, .rdx };
    pub const c_abi_sse_return_regs = sse_avx_regs[0..2].*;
};

pub const Win64 = struct {
    /// Note that .rsp and .rbp also belong to this set, however, we never expect to use them
    /// for anything else but stack offset tracking therefore we exclude them from this set.
    pub const callee_preserved_regs = [_]Register{ .rbx, .rsi, .rdi, .r12, .r13, .r14, .r15 };
    /// These registers need to be preserved (saved on the stack) and restored by the caller before
    /// the caller relinquishes control to a subroutine via call instruction (or similar).
    /// In other words, these registers are free to use by the callee.
    pub const caller_preserved_regs = [_]Register{ .rax, .rcx, .rdx, .r8, .r9, .r10, .r11 } ++ x87_regs ++ sse_avx_regs;

    pub const c_abi_int_param_regs = [_]Register{ .rcx, .rdx, .r8, .r9 };
    pub const c_abi_sse_param_regs = sse_avx_regs[0..4].*;
    pub const c_abi_int_return_regs = [_]Register{.rax};
    pub const c_abi_sse_return_regs = sse_avx_regs[0..1].*;
};

pub fn resolveCallingConvention(
    cc: std.builtin.CallingConvention,
    target: std.Target,
) std.builtin.CallingConvention {
    return switch (cc) {
        .Unspecified, .C => switch (target.os.tag) {
            else => .SysV,
            .windows => .Win64,
        },
        else => cc,
    };
}

pub fn getCalleePreservedRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.callee_preserved_regs,
        .Win64 => &Win64.callee_preserved_regs,
        else => unreachable,
    };
}

pub fn getCallerPreservedRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.caller_preserved_regs,
        .Win64 => &Win64.caller_preserved_regs,
        else => unreachable,
    };
}

pub fn getCAbiIntParamRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.c_abi_int_param_regs,
        .Win64 => &Win64.c_abi_int_param_regs,
        else => unreachable,
    };
}

pub fn getCAbiSseParamRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.c_abi_sse_param_regs,
        .Win64 => &Win64.c_abi_sse_param_regs,
        else => unreachable,
    };
}

pub fn getCAbiIntReturnRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.c_abi_int_return_regs,
        .Win64 => &Win64.c_abi_int_return_regs,
        else => unreachable,
    };
}

pub fn getCAbiSseReturnRegs(cc: std.builtin.CallingConvention) []const Register {
    return switch (cc) {
        .SysV => &SysV.c_abi_sse_return_regs,
        .Win64 => &Win64.c_abi_sse_return_regs,
        else => unreachable,
    };
}

const gp_regs = [_]Register{
    .rax, .rcx, .rdx, .rbx, .rsi, .rdi, .r8, .r9, .r10, .r11, .r12, .r13, .r14, .r15,
};
const x87_regs = [_]Register{
    .st0, .st1, .st2, .st3, .st4, .st5, .st6, .st7,
};
const sse_avx_regs = [_]Register{
    .ymm0, .ymm1, .ymm2,  .ymm3,  .ymm4,  .ymm5,  .ymm6,  .ymm7,
    .ymm8, .ymm9, .ymm10, .ymm11, .ymm12, .ymm13, .ymm14, .ymm15,
};
const allocatable_regs = gp_regs ++ x87_regs[0 .. x87_regs.len - 1] ++ sse_avx_regs;
pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, allocatable_regs);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
pub const RegisterClass = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (allocatable_regs, 0..) |reg, index| if (reg.class() == .general_purpose) set.set(index);
        break :blk set;
    };
    pub const x87: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (allocatable_regs, 0..) |reg, index| if (reg.class() == .x87) set.set(index);
        break :blk set;
    };
    pub const sse: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        for (allocatable_regs, 0..) |reg, index| if (reg.class() == .sse) set.set(index);
        break :blk set;
    };
};

const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const InternPool = @import("../../InternPool.zig");
const Register = @import("bits.zig").Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;
const Value = @import("../../Value.zig");
const Zcu = @import("../../Module.zig");
