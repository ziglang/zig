const std = @import("std");
const Type = @import("../../type.zig").Type;
const Target = std.Target;
const assert = std.debug.assert;
const Register = @import("bits.zig").Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;

pub const Class = enum { integer, sse, sseup, x87, x87up, complex_x87, memory, none };

pub fn classifyWindows(ty: Type, target: Target) Class {
    // https://docs.microsoft.com/en-gb/cpp/build/x64-calling-convention?view=vs-2017
    // "There's a strict one-to-one correspondence between a function call's arguments
    // and the registers used for those arguments. Any argument that doesn't fit in 8
    // bytes, or isn't 1, 2, 4, or 8 bytes, must be passed by reference. A single argument
    // is never spread across multiple registers."
    // "All floating point operations are done using the 16 XMM registers."
    // "Structs and unions of size 8, 16, 32, or 64 bits, and __m64 types, are passed
    // as if they were integers of the same size."
    switch (ty.zigTypeTag()) {
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
        => switch (ty.abiSize(target)) {
            0 => unreachable,
            1, 2, 4, 8 => return .integer,
            else => return .memory,
        },

        .Float, .Vector => return .sse,

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

/// There are a maximum of 8 possible return slots. Returned values are in
/// the beginning of the array; unused slots are filled with .none.
pub fn classifySystemV(ty: Type, target: Target) [8]Class {
    const memory_class = [_]Class{
        .memory, .none, .none, .none,
        .none,   .none, .none, .none,
    };
    var result = [1]Class{.none} ** 8;
    switch (ty.zigTypeTag()) {
        .Pointer => switch (ty.ptrSize()) {
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
            const bits = ty.intInfo(target).bits;
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
            16, 32, 64 => {
                result[0] = .sse;
                return result;
            },
            128 => {
                // "Arguments of types__float128, _Decimal128 and__m128 are
                // split into two halves.  The least significant ones belong
                // to class SSE, the most significant one to class SSEUP."
                result[0] = .sse;
                result[1] = .sseup;
                return result;
            },
            else => {
                // "The 64-bit mantissa of arguments of type long double
                // belongs to classX87, the 16-bit exponent plus 6 bytes
                // of padding belongs to class X87UP."
                result[0] = .x87;
                result[1] = .x87up;
                return result;
            },
        },
        .Vector => {
            const elem_ty = ty.childType();
            const bits = elem_ty.bitSize(target) * ty.arrayLen();
            if (bits <= 64) return .{
                .sse,  .none, .none, .none,
                .none, .none, .none, .none,
            };
            if (bits <= 128) return .{
                .sse,  .sseup, .none, .none,
                .none, .none,  .none, .none,
            };
            if (bits <= 192) return .{
                .sse,  .sseup, .sseup, .none,
                .none, .none,  .none,  .none,
            };
            if (bits <= 256) return .{
                .sse,  .sseup, .sseup, .sseup,
                .none, .none,  .none,  .none,
            };
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
            if (bits <= 512) return .{
                .sse,   .sseup, .sseup, .sseup,
                .sseup, .sseup, .sseup, .sseup,
            };
            return memory_class;
        },
        .Optional => {
            if (ty.isPtrLikeOptional()) {
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
            const ty_size = ty.abiSize(target);
            if (ty_size > 64)
                return memory_class;

            var result_i: usize = 0; // out of 8
            var byte_i: usize = 0; // out of 8
            const fields = ty.structFields();
            for (fields.values()) |field| {
                if (field.abi_align != 0) {
                    if (field.abi_align < field.ty.abiAlignment(target)) {
                        return memory_class;
                    }
                }
                const field_size = field.ty.abiSize(target);
                const field_class_array = classifySystemV(field.ty, target);
                const field_class = std.mem.sliceTo(&field_class_array, .none);
                if (byte_i + field_size <= 8) {
                    // Combine this field with the previous one.
                    combine: {
                        // "If both classes are equal, this is the resulting class."
                        if (result[result_i] == field_class[0]) {
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
                    byte_i += @intCast(usize, field_size);
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
                    std.mem.copy(Class, result[result_i..], field_class);
                    result_i += field_class.len;
                    // If there are any bytes leftover, we have to try to combine
                    // the next field with them.
                    byte_i = @intCast(usize, field_size % 8);
                    if (byte_i != 0) result_i -= 1;
                }
            }

            // Post-merger cleanup

            // "If one of the classes is MEMORY, the whole argument is passed in memory"
            // "If X87UP is not preceded by X87, the whole argument is passed in memory."
            var found_sseup = false;
            for (result) |item, i| switch (item) {
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
            for (result) |*item, i| {
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
            const ty_size = ty.abiSize(target);
            if (ty_size > 64)
                return memory_class;

            const fields = ty.unionFields();
            for (fields.values()) |field| {
                if (field.abi_align != 0) {
                    if (field.abi_align < field.ty.abiAlignment(target)) {
                        return memory_class;
                    }
                }
                // Combine this field with the previous one.
                const field_class = classifySystemV(field.ty, target);
                for (result) |*result_item, i| {
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
            for (result) |item, i| switch (item) {
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
            for (result) |*item, i| {
                if (item.* == .sseup) switch (result[i - 1]) {
                    .sse, .sseup => continue,
                    else => item.* = .sse,
                };
            }
            return result;
        },
        else => unreachable,
    }
}

/// Note that .rsp and .rbp also belong to this set, however, we never expect to use them
/// for anything else but stack offset tracking therefore we exclude them from this set.
pub const callee_preserved_regs = [_]Register{ .rbx, .r12, .r13, .r14, .r15 };
/// These registers need to be preserved (saved on the stack) and restored by the caller before
/// the caller relinquishes control to a subroutine via call instruction (or similar).
/// In other words, these registers are free to use by the callee.
pub const caller_preserved_regs = [_]Register{ .rax, .rcx, .rdx, .rsi, .rdi, .r8, .r9, .r10, .r11 };

pub const c_abi_int_param_regs = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
pub const c_abi_int_return_regs = [_]Register{ .rax, .rdx };

const sse_avx_regs = [_]Register{
    .ymm0, .ymm1, .ymm2,  .ymm3,  .ymm4,  .ymm5,  .ymm6,  .ymm7,
    .ymm8, .ymm9, .ymm10, .ymm11, .ymm12, .ymm13, .ymm14, .ymm15,
};
const allocatable_registers = callee_preserved_regs ++ caller_preserved_regs ++ sse_avx_regs;
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
    pub const sse: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = caller_preserved_regs.len + callee_preserved_regs.len,
            .end = allocatable_registers.len,
        }, true);
        break :blk set;
    };
};
