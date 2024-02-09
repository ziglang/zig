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
};

pub fn classifyWindows(ty: Type, mod: *Module) Class {
    // https://docs.microsoft.com/en-gb/cpp/build/x64-calling-convention?view=vs-2017
    // "There's a strict one-to-one correspondence between a function call's arguments
    // and the registers used for those arguments. Any argument that doesn't fit in 8
    // bytes, or isn't 1, 2, 4, or 8 bytes, must be passed by reference. A single argument
    // is never spread across multiple registers."
    // "All floating point operations are done using the 16 XMM registers."
    // "Structs and unions of size 8, 16, 32, or 64 bits, and __m64 types, are passed
    // as if they were integers of the same size."
    switch (ty.zigTypeTag(mod)) {
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
        => switch (ty.abiSize(mod)) {
            0 => unreachable,
            1, 2, 4, 8 => return .integer,
            else => switch (ty.zigTypeTag(mod)) {
                .Int => return .win_i128,
                .Struct, .Union => if (ty.containerLayout(mod) == .Packed) {
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
pub fn classifySystemV(ty: Type, mod: *Module, ctx: Context) [8]Class {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
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
        .Int, .Enum, .ErrorSet => {
            const bits = ty.intInfo(mod).bits;
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
                if (ctx == .field) {
                    result[0] = .memory;
                    return result;
                }
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
            const elem_ty = ty.childType(mod);
            const bits = elem_ty.bitSize(mod) * ty.arrayLen(mod);
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
            if (ty.isPtrLikeOptional(mod)) {
                result[0] = .integer;
                return result;
            }
            return memory_class;
        },
        .Struct => {
            // "If the size of an object is larger than eight eightbytes, or
            // it contains unaligned fields, it has class MEMORY"
            // "If the size of the aggregate exceeds a single eightbyte, each is classified
            // separately.".
            const struct_type = mod.typeToStruct(ty).?;
            const ty_size = ty.abiSize(mod);
            if (struct_type.layout == .Packed) {
                assert(ty_size <= 16);
                result[0] = .integer;
                if (ty_size > 8) result[1] = .integer;
                return result;
            }
            if (ty_size > 64)
                return memory_class;

            var result_i: usize = 0; // out of 8
            var byte_i: usize = 0; // out of 8
            for (struct_type.field_types.get(ip), 0..) |field_ty_ip, i| {
                const field_ty = Type.fromInterned(field_ty_ip);
                const field_align = struct_type.fieldAlign(ip, i);
                if (field_align != .none and field_align.compare(.lt, field_ty.abiAlignment(mod)))
                    return memory_class;
                const field_size = field_ty.abiSize(mod);
                const field_class_array = classifySystemV(field_ty, mod, .field);
                const field_class = std.mem.sliceTo(&field_class_array, .none);
                if (byte_i + field_size <= 8) {
                    // Combine this field with the previous one.
                    combine: {
                        // "If both classes are equal, this is the resulting class."
                        if (result[result_i] == field_class[0]) {
                            if (result[result_i] == .float) {
                                result[result_i] = .float_combine;
                            }
                            break :combine;
                        }

                        // "If one of the classes is NO_CLASS, the resulting class
                        // is the other class."
                        if (result[result_i] == .none) {
                            result[result_i] = field_class[0];
                            break :combine;
                        }
                        assert(field_class[0] != .none);

                        // "If one of the classes is MEMORY, the result is the MEMORY class."
                        if (result[result_i] == .memory or field_class[0] == .memory) {
                            result[result_i] = .memory;
                            break :combine;
                        }

                        // "If one of the classes is INTEGER, the result is the INTEGER."
                        if (result[result_i] == .integer or field_class[0] == .integer) {
                            result[result_i] = .integer;
                            break :combine;
                        }

                        // "If one of the classes is X87, X87UP, COMPLEX_X87 class,
                        // MEMORY is used as class."
                        if (result[result_i] == .x87 or
                            result[result_i] == .x87up or
                            result[result_i] == .complex_x87 or
                            field_class[0] == .x87 or
                            field_class[0] == .x87up or
                            field_class[0] == .complex_x87)
                        {
                            result[result_i] = .memory;
                            break :combine;
                        }

                        // "Otherwise class SSE is used."
                        result[result_i] = .sse;
                    }
                    byte_i += @as(usize, @intCast(field_size));
                    if (byte_i == 8) {
                        byte_i = 0;
                        result_i += 1;
                    }
                } else {
                    // Cannot combine this field with the previous one.
                    if (byte_i != 0) {
                        byte_i = 0;
                        result_i += 1;
                    }
                    @memcpy(result[result_i..][0..field_class.len], field_class);
                    result_i += field_class.len;
                    // If there are any bytes leftover, we have to try to combine
                    // the next field with them.
                    byte_i = @as(usize, @intCast(field_size % 8));
                    if (byte_i != 0) result_i -= 1;
                }
            }

            // Post-merger cleanup

            // "If one of the classes is MEMORY, the whole argument is passed in memory"
            // "If X87UP is not preceded by X87, the whole argument is passed in memory."
            var found_sseup = false;
            for (result, 0..) |item, i| switch (item) {
                .memory => return memory_class,
                .x87up => if (i == 0 or result[i - 1] != .x87) return memory_class,
                .sseup => found_sseup = true,
                else => continue,
            };
            // "If the size of the aggregate exceeds two eightbytes and the first eight-
            // byte isn’t SSE or any other eightbyte isn’t SSEUP, the whole argument
            // is passed in memory."
            if (ty_size > 16 and (result[0] != .sse or !found_sseup)) return memory_class;

            // "If SSEUP is not preceded by SSE or SSEUP, it is converted to SSE."
            for (&result, 0..) |*item, i| {
                if (item.* == .sseup) switch (result[i - 1]) {
                    .sse, .sseup => continue,
                    else => item.* = .sse,
                };
            }
            return result;
        },
        .Union => {
            // "If the size of an object is larger than eight eightbytes, or
            // it contains unaligned fields, it has class MEMORY"
            // "If the size of the aggregate exceeds a single eightbyte, each is classified
            // separately.".
            const union_obj = mod.typeToUnion(ty).?;
            const ty_size = mod.unionAbiSize(union_obj);
            if (union_obj.getLayout(ip) == .Packed) {
                assert(ty_size <= 16);
                result[0] = .integer;
                if (ty_size > 8) result[1] = .integer;
                return result;
            }
            if (ty_size > 64)
                return memory_class;

            for (union_obj.field_types.get(ip), 0..) |field_ty, field_index| {
                const field_align = union_obj.fieldAlign(ip, @intCast(field_index));
                if (field_align != .none and
                    field_align.compare(.lt, Type.fromInterned(field_ty).abiAlignment(mod)))
                {
                    return memory_class;
                }
                // Combine this field with the previous one.
                const field_class = classifySystemV(Type.fromInterned(field_ty), mod, .field);
                for (&result, 0..) |*result_item, i| {
                    const field_item = field_class[i];
                    // "If both classes are equal, this is the resulting class."
                    if (result_item.* == field_item) {
                        continue;
                    }

                    // "If one of the classes is NO_CLASS, the resulting class
                    // is the other class."
                    if (result_item.* == .none) {
                        result_item.* = field_item;
                        continue;
                    }
                    if (field_item == .none) {
                        continue;
                    }

                    // "If one of the classes is MEMORY, the result is the MEMORY class."
                    if (result_item.* == .memory or field_item == .memory) {
                        result_item.* = .memory;
                        continue;
                    }

                    // "If one of the classes is INTEGER, the result is the INTEGER."
                    if (result_item.* == .integer or field_item == .integer) {
                        result_item.* = .integer;
                        continue;
                    }

                    // "If one of the classes is X87, X87UP, COMPLEX_X87 class,
                    // MEMORY is used as class."
                    if (result_item.* == .x87 or
                        result_item.* == .x87up or
                        result_item.* == .complex_x87 or
                        field_item == .x87 or
                        field_item == .x87up or
                        field_item == .complex_x87)
                    {
                        result_item.* = .memory;
                        continue;
                    }

                    // "Otherwise class SSE is used."
                    result_item.* = .sse;
                }
            }

            // Post-merger cleanup

            // "If one of the classes is MEMORY, the whole argument is passed in memory"
            // "If X87UP is not preceded by X87, the whole argument is passed in memory."
            var found_sseup = false;
            for (result, 0..) |item, i| switch (item) {
                .memory => return memory_class,
                .x87up => if (i == 0 or result[i - 1] != .x87) return memory_class,
                .sseup => found_sseup = true,
                else => continue,
            };
            // "If the size of the aggregate exceeds two eightbytes and the first eight-
            // byte isn’t SSE or any other eightbyte isn’t SSEUP, the whole argument
            // is passed in memory."
            if (ty_size > 16 and (result[0] != .sse or !found_sseup)) return memory_class;

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
            const ty_size = ty.abiSize(mod);
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

const Module = @import("../../Module.zig");
const Register = @import("bits.zig").Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../type.zig").Type;
const Value = @import("../../Value.zig");
