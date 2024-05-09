const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const testing = std.testing;
const leb = std.leb;
const mem = std.mem;
const wasm = std.wasm;
const log = std.log.scoped(.codegen);

const codegen = @import("../../codegen.zig");
const Module = @import("../../Module.zig");
const InternPool = @import("../../InternPool.zig");
const Decl = Module.Decl;
const Type = @import("../../type.zig").Type;
const Value = @import("../../Value.zig");
const Compilation = @import("../../Compilation.zig");
const LazySrcLoc = std.zig.LazySrcLoc;
const link = @import("../../link.zig");
const Air = @import("../../Air.zig");
const Liveness = @import("../../Liveness.zig");
const target_util = @import("../../target.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const abi = @import("abi.zig");
const Alignment = InternPool.Alignment;
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;
const errUnionErrorOffset = codegen.errUnionErrorOffset;

/// Wasm Value, created when generating an instruction
const WValue = union(enum) {
    /// `WValue` which has been freed and may no longer hold
    /// any references.
    dead: void,
    /// May be referenced but is unused
    none: void,
    /// The value lives on top of the stack
    stack: void,
    /// Index of the local
    local: struct {
        /// Contains the index to the local
        value: u32,
        /// The amount of instructions referencing this `WValue`
        references: u32,
    },
    /// An immediate 32bit value
    imm32: u32,
    /// An immediate 64bit value
    imm64: u64,
    /// Index into the list of simd128 immediates. This `WValue` is
    /// only possible in very rare cases, therefore it would be
    /// a waste of memory to store the value in a 128 bit integer.
    imm128: u32,
    /// A constant 32bit float value
    float32: f32,
    /// A constant 64bit float value
    float64: f64,
    /// A value that represents a pointer to the data section
    /// Note: The value contains the symbol index, rather than the actual address
    /// as we use this to perform the relocation.
    memory: u32,
    /// A value that represents a parent pointer and an offset
    /// from that pointer. i.e. when slicing with constant values.
    memory_offset: struct {
        /// The symbol of the parent pointer
        pointer: u32,
        /// Offset will be set as addend when relocating
        offset: u32,
    },
    /// Represents a function pointer
    /// In wasm function pointers are indexes into a function table,
    /// rather than an address in the data section.
    function_index: u32,
    /// Offset from the bottom of the virtual stack, with the offset
    /// pointing to where the value lives.
    stack_offset: struct {
        /// Contains the actual value of the offset
        value: u32,
        /// The amount of instructions referencing this `WValue`
        references: u32,
    },

    /// Returns the offset from the bottom of the stack. This is useful when
    /// we use the load or store instruction to ensure we retrieve the value
    /// from the correct position, rather than the value that lives at the
    /// bottom of the stack. For instances where `WValue` is not `stack_value`
    /// this will return 0, which allows us to simply call this function for all
    /// loads and stores without requiring checks everywhere.
    fn offset(value: WValue) u32 {
        switch (value) {
            .stack_offset => |stack_offset| return stack_offset.value,
            .dead => unreachable,
            else => return 0,
        }
    }

    /// Promotes a `WValue` to a local when given value is on top of the stack.
    /// When encountering a `local` or `stack_offset` this is essentially a no-op.
    /// All other tags are illegal.
    fn toLocal(value: WValue, gen: *CodeGen, ty: Type) InnerError!WValue {
        switch (value) {
            .stack => {
                const new_local = try gen.allocLocal(ty);
                try gen.addLabel(.local_set, new_local.local.value);
                return new_local;
            },
            .local, .stack_offset => return value,
            else => unreachable,
        }
    }

    /// Marks a local as no longer being referenced and essentially allows
    /// us to re-use it somewhere else within the function.
    /// The valtype of the local is deducted by using the index of the given `WValue`.
    fn free(value: *WValue, gen: *CodeGen) void {
        if (value.* != .local) return;
        const local_value = value.local.value;
        const reserved = gen.args.len + @intFromBool(gen.return_value != .none);
        if (local_value < reserved + 2) return; // reserved locals may never be re-used. Also accounts for 2 stack locals.

        const index = local_value - reserved;
        const valtype = @as(wasm.Valtype, @enumFromInt(gen.locals.items[index]));
        switch (valtype) {
            .i32 => gen.free_locals_i32.append(gen.gpa, local_value) catch return, // It's ok to fail any of those, a new local can be allocated instead
            .i64 => gen.free_locals_i64.append(gen.gpa, local_value) catch return,
            .f32 => gen.free_locals_f32.append(gen.gpa, local_value) catch return,
            .f64 => gen.free_locals_f64.append(gen.gpa, local_value) catch return,
            .v128 => gen.free_locals_v128.append(gen.gpa, local_value) catch return,
        }
        log.debug("freed local ({d}) of type {}", .{ local_value, valtype });
        value.* = .dead;
    }
};

/// Wasm ops, but without input/output/signedness information
/// Used for `buildOpcode`
const Op = enum {
    @"unreachable",
    nop,
    block,
    loop,
    @"if",
    @"else",
    end,
    br,
    br_if,
    br_table,
    @"return",
    call,
    call_indirect,
    drop,
    select,
    local_get,
    local_set,
    local_tee,
    global_get,
    global_set,
    load,
    store,
    memory_size,
    memory_grow,
    @"const",
    eqz,
    eq,
    ne,
    lt,
    gt,
    le,
    ge,
    clz,
    ctz,
    popcnt,
    add,
    sub,
    mul,
    div,
    rem,
    @"and",
    @"or",
    xor,
    shl,
    shr,
    rotl,
    rotr,
    abs,
    neg,
    ceil,
    floor,
    trunc,
    nearest,
    sqrt,
    min,
    max,
    copysign,
    wrap,
    convert,
    demote,
    promote,
    reinterpret,
    extend,
};

/// Contains the settings needed to create an `Opcode` using `buildOpcode`.
///
/// The fields correspond to the opcode name. Here is an example
///          i32_trunc_f32_s
///          ^   ^     ^   ^
///          |   |     |   |
///   valtype1   |     |   |
///     = .i32   |     |   |
///              |     |   |
///             op     |   |
///       = .trunc     |   |
///                    |   |
///             valtype2   |
///               = .f32   |
///                        |
///                width   |
///               = null   |
///                        |
///                   signed
///                   = true
///
/// There can be missing fields, here are some more examples:
///   i64_load8_u
///     --> .{ .valtype1 = .i64, .op = .load, .width = 8, signed = false }
///   i32_mul
///     --> .{ .valtype1 = .i32, .op = .trunc }
///   nop
///     --> .{ .op = .nop }
const OpcodeBuildArguments = struct {
    /// First valtype in the opcode (usually represents the type of the output)
    valtype1: ?wasm.Valtype = null,
    /// The operation (e.g. call, unreachable, div, min, sqrt, etc.)
    op: Op,
    /// Width of the operation (e.g. 8 for i32_load8_s, 16 for i64_extend16_i32_s)
    width: ?u8 = null,
    /// Second valtype in the opcode name (usually represents the type of the input)
    valtype2: ?wasm.Valtype = null,
    /// Signedness of the op
    signedness: ?std.builtin.Signedness = null,
};

/// Helper function that builds an Opcode given the arguments needed
fn buildOpcode(args: OpcodeBuildArguments) wasm.Opcode {
    switch (args.op) {
        .@"unreachable" => return .@"unreachable",
        .nop => return .nop,
        .block => return .block,
        .loop => return .loop,
        .@"if" => return .@"if",
        .@"else" => return .@"else",
        .end => return .end,
        .br => return .br,
        .br_if => return .br_if,
        .br_table => return .br_table,
        .@"return" => return .@"return",
        .call => return .call,
        .call_indirect => return .call_indirect,
        .drop => return .drop,
        .select => return .select,
        .local_get => return .local_get,
        .local_set => return .local_set,
        .local_tee => return .local_tee,
        .global_get => return .global_get,
        .global_set => return .global_set,

        .load => if (args.width) |width| switch (width) {
            8 => switch (args.valtype1.?) {
                .i32 => if (args.signedness.? == .signed) return .i32_load8_s else return .i32_load8_u,
                .i64 => if (args.signedness.? == .signed) return .i64_load8_s else return .i64_load8_u,
                .f32, .f64, .v128 => unreachable,
            },
            16 => switch (args.valtype1.?) {
                .i32 => if (args.signedness.? == .signed) return .i32_load16_s else return .i32_load16_u,
                .i64 => if (args.signedness.? == .signed) return .i64_load16_s else return .i64_load16_u,
                .f32, .f64, .v128 => unreachable,
            },
            32 => switch (args.valtype1.?) {
                .i64 => if (args.signedness.? == .signed) return .i64_load32_s else return .i64_load32_u,
                .i32 => return .i32_load,
                .f32 => return .f32_load,
                .f64, .v128 => unreachable,
            },
            64 => switch (args.valtype1.?) {
                .i64 => return .i64_load,
                .f64 => return .f64_load,
                else => unreachable,
            },
            else => unreachable,
        } else switch (args.valtype1.?) {
            .i32 => return .i32_load,
            .i64 => return .i64_load,
            .f32 => return .f32_load,
            .f64 => return .f64_load,
            .v128 => unreachable, // handled independently
        },
        .store => if (args.width) |width| {
            switch (width) {
                8 => switch (args.valtype1.?) {
                    .i32 => return .i32_store8,
                    .i64 => return .i64_store8,
                    .f32, .f64, .v128 => unreachable,
                },
                16 => switch (args.valtype1.?) {
                    .i32 => return .i32_store16,
                    .i64 => return .i64_store16,
                    .f32, .f64, .v128 => unreachable,
                },
                32 => switch (args.valtype1.?) {
                    .i64 => return .i64_store32,
                    .i32 => return .i32_store,
                    .f32 => return .f32_store,
                    .f64, .v128 => unreachable,
                },
                64 => switch (args.valtype1.?) {
                    .i64 => return .i64_store,
                    .f64 => return .f64_store,
                    else => unreachable,
                },
                else => unreachable,
            }
        } else {
            switch (args.valtype1.?) {
                .i32 => return .i32_store,
                .i64 => return .i64_store,
                .f32 => return .f32_store,
                .f64 => return .f64_store,
                .v128 => unreachable, // handled independently
            }
        },

        .memory_size => return .memory_size,
        .memory_grow => return .memory_grow,

        .@"const" => switch (args.valtype1.?) {
            .i32 => return .i32_const,
            .i64 => return .i64_const,
            .f32 => return .f32_const,
            .f64 => return .f64_const,
            .v128 => unreachable, // handled independently
        },

        .eqz => switch (args.valtype1.?) {
            .i32 => return .i32_eqz,
            .i64 => return .i64_eqz,
            .f32, .f64, .v128 => unreachable,
        },
        .eq => switch (args.valtype1.?) {
            .i32 => return .i32_eq,
            .i64 => return .i64_eq,
            .f32 => return .f32_eq,
            .f64 => return .f64_eq,
            .v128 => unreachable, // handled independently
        },
        .ne => switch (args.valtype1.?) {
            .i32 => return .i32_ne,
            .i64 => return .i64_ne,
            .f32 => return .f32_ne,
            .f64 => return .f64_ne,
            .v128 => unreachable, // handled independently
        },

        .lt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_lt_s else return .i32_lt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_lt_s else return .i64_lt_u,
            .f32 => return .f32_lt,
            .f64 => return .f64_lt,
            .v128 => unreachable, // handled independently
        },
        .gt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_gt_s else return .i32_gt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_gt_s else return .i64_gt_u,
            .f32 => return .f32_gt,
            .f64 => return .f64_gt,
            .v128 => unreachable, // handled independently
        },
        .le => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_le_s else return .i32_le_u,
            .i64 => if (args.signedness.? == .signed) return .i64_le_s else return .i64_le_u,
            .f32 => return .f32_le,
            .f64 => return .f64_le,
            .v128 => unreachable, // handled independently
        },
        .ge => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_ge_s else return .i32_ge_u,
            .i64 => if (args.signedness.? == .signed) return .i64_ge_s else return .i64_ge_u,
            .f32 => return .f32_ge,
            .f64 => return .f64_ge,
            .v128 => unreachable, // handled independently
        },

        .clz => switch (args.valtype1.?) {
            .i32 => return .i32_clz,
            .i64 => return .i64_clz,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .ctz => switch (args.valtype1.?) {
            .i32 => return .i32_ctz,
            .i64 => return .i64_ctz,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .popcnt => switch (args.valtype1.?) {
            .i32 => return .i32_popcnt,
            .i64 => return .i64_popcnt,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },

        .add => switch (args.valtype1.?) {
            .i32 => return .i32_add,
            .i64 => return .i64_add,
            .f32 => return .f32_add,
            .f64 => return .f64_add,
            .v128 => unreachable, // handled independently
        },
        .sub => switch (args.valtype1.?) {
            .i32 => return .i32_sub,
            .i64 => return .i64_sub,
            .f32 => return .f32_sub,
            .f64 => return .f64_sub,
            .v128 => unreachable, // handled independently
        },
        .mul => switch (args.valtype1.?) {
            .i32 => return .i32_mul,
            .i64 => return .i64_mul,
            .f32 => return .f32_mul,
            .f64 => return .f64_mul,
            .v128 => unreachable, // handled independently
        },

        .div => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_div_s else return .i32_div_u,
            .i64 => if (args.signedness.? == .signed) return .i64_div_s else return .i64_div_u,
            .f32 => return .f32_div,
            .f64 => return .f64_div,
            .v128 => unreachable, // handled independently
        },
        .rem => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_rem_s else return .i32_rem_u,
            .i64 => if (args.signedness.? == .signed) return .i64_rem_s else return .i64_rem_u,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },

        .@"and" => switch (args.valtype1.?) {
            .i32 => return .i32_and,
            .i64 => return .i64_and,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .@"or" => switch (args.valtype1.?) {
            .i32 => return .i32_or,
            .i64 => return .i64_or,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .xor => switch (args.valtype1.?) {
            .i32 => return .i32_xor,
            .i64 => return .i64_xor,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },

        .shl => switch (args.valtype1.?) {
            .i32 => return .i32_shl,
            .i64 => return .i64_shl,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .shr => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_shr_s else return .i32_shr_u,
            .i64 => if (args.signedness.? == .signed) return .i64_shr_s else return .i64_shr_u,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .rotl => switch (args.valtype1.?) {
            .i32 => return .i32_rotl,
            .i64 => return .i64_rotl,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .rotr => switch (args.valtype1.?) {
            .i32 => return .i32_rotr,
            .i64 => return .i64_rotr,
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },

        .abs => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_abs,
            .f64 => return .f64_abs,
            .v128 => unreachable, // handled independently
        },
        .neg => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_neg,
            .f64 => return .f64_neg,
            .v128 => unreachable, // handled independently
        },
        .ceil => switch (args.valtype1.?) {
            .i64 => unreachable,
            .i32 => return .f32_ceil, // when valtype is f16, we store it in i32.
            .f32 => return .f32_ceil,
            .f64 => return .f64_ceil,
            .v128 => unreachable, // handled independently
        },
        .floor => switch (args.valtype1.?) {
            .i64 => unreachable,
            .i32 => return .f32_floor, // when valtype is f16, we store it in i32.
            .f32 => return .f32_floor,
            .f64 => return .f64_floor,
            .v128 => unreachable, // handled independently
        },
        .trunc => switch (args.valtype1.?) {
            .i32 => if (args.valtype2) |valty| switch (valty) {
                .i32 => unreachable,
                .i64 => unreachable,
                .f32 => if (args.signedness.? == .signed) return .i32_trunc_f32_s else return .i32_trunc_f32_u,
                .f64 => if (args.signedness.? == .signed) return .i32_trunc_f64_s else return .i32_trunc_f64_u,
                .v128 => unreachable, // handled independently
            } else return .f32_trunc, // when no valtype2, it's an f16 instead which is stored in an i32.
            .i64 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => unreachable,
                .f32 => if (args.signedness.? == .signed) return .i64_trunc_f32_s else return .i64_trunc_f32_u,
                .f64 => if (args.signedness.? == .signed) return .i64_trunc_f64_s else return .i64_trunc_f64_u,
                .v128 => unreachable, // handled independently
            },
            .f32 => return .f32_trunc,
            .f64 => return .f64_trunc,
            .v128 => unreachable, // handled independently
        },
        .nearest => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_nearest,
            .f64 => return .f64_nearest,
            .v128 => unreachable, // handled independently
        },
        .sqrt => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_sqrt,
            .f64 => return .f64_sqrt,
            .v128 => unreachable, // handled independently
        },
        .min => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_min,
            .f64 => return .f64_min,
            .v128 => unreachable, // handled independently
        },
        .max => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_max,
            .f64 => return .f64_max,
            .v128 => unreachable, // handled independently
        },
        .copysign => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_copysign,
            .f64 => return .f64_copysign,
            .v128 => unreachable, // handled independently
        },

        .wrap => switch (args.valtype1.?) {
            .i32 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => return .i32_wrap_i64,
                .f32, .f64 => unreachable,
                .v128 => unreachable, // handled independently
            },
            .i64, .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
        .convert => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f32_convert_i32_s else return .f32_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f32_convert_i64_s else return .f32_convert_i64_u,
                .f32, .f64 => unreachable,
                .v128 => unreachable, // handled independently
            },
            .f64 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f64_convert_i32_s else return .f64_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f64_convert_i64_s else return .f64_convert_i64_u,
                .f32, .f64 => unreachable,
                .v128 => unreachable, // handled independently
            },
            .v128 => unreachable, // handled independently
        },
        .demote => if (args.valtype1.? == .f32 and args.valtype2.? == .f64) return .f32_demote_f64 else unreachable,
        .promote => if (args.valtype1.? == .f64 and args.valtype2.? == .f32) return .f64_promote_f32 else unreachable,
        .reinterpret => switch (args.valtype1.?) {
            .i32 => if (args.valtype2.? == .f32) return .i32_reinterpret_f32 else unreachable,
            .i64 => if (args.valtype2.? == .f64) return .i64_reinterpret_f64 else unreachable,
            .f32 => if (args.valtype2.? == .i32) return .f32_reinterpret_i32 else unreachable,
            .f64 => if (args.valtype2.? == .i64) return .f64_reinterpret_i64 else unreachable,
            .v128 => unreachable, // handled independently
        },
        .extend => switch (args.valtype1.?) {
            .i32 => switch (args.width.?) {
                8 => if (args.signedness.? == .signed) return .i32_extend8_s else unreachable,
                16 => if (args.signedness.? == .signed) return .i32_extend16_s else unreachable,
                else => unreachable,
            },
            .i64 => switch (args.width.?) {
                8 => if (args.signedness.? == .signed) return .i64_extend8_s else unreachable,
                16 => if (args.signedness.? == .signed) return .i64_extend16_s else unreachable,
                32 => if (args.signedness.? == .signed) return .i64_extend32_s else unreachable,
                else => unreachable,
            },
            .f32, .f64 => unreachable,
            .v128 => unreachable, // handled independently
        },
    }
}

test "Wasm - buildOpcode" {
    // Make sure buildOpcode is referenced, and test some examples
    const i32_const = buildOpcode(.{ .op = .@"const", .valtype1 = .i32 });
    const end = buildOpcode(.{ .op = .end });
    const local_get = buildOpcode(.{ .op = .local_get });
    const i64_extend32_s = buildOpcode(.{ .op = .extend, .valtype1 = .i64, .width = 32, .signedness = .signed });
    const f64_reinterpret_i64 = buildOpcode(.{ .op = .reinterpret, .valtype1 = .f64, .valtype2 = .i64 });

    try testing.expectEqual(@as(wasm.Opcode, .i32_const), i32_const);
    try testing.expectEqual(@as(wasm.Opcode, .end), end);
    try testing.expectEqual(@as(wasm.Opcode, .local_get), local_get);
    try testing.expectEqual(@as(wasm.Opcode, .i64_extend32_s), i64_extend32_s);
    try testing.expectEqual(@as(wasm.Opcode, .f64_reinterpret_i64), f64_reinterpret_i64);
}

/// Hashmap to store generated `WValue` for each `Air.Inst.Ref`
pub const ValueTable = std.AutoArrayHashMapUnmanaged(Air.Inst.Ref, WValue);

const CodeGen = @This();

/// Reference to the function declaration the code
/// section belongs to
decl: *Decl,
decl_index: InternPool.DeclIndex,
/// Current block depth. Used to calculate the relative difference between a break
/// and block
block_depth: u32 = 0,
air: Air,
liveness: Liveness,
gpa: mem.Allocator,
debug_output: codegen.DebugInfoOutput,
func_index: InternPool.Index,
/// Contains a list of current branches.
/// When we return from a branch, the branch will be popped from this list,
/// which means branches can only contain references from within its own branch,
/// or a branch higher (lower index) in the tree.
branches: std.ArrayListUnmanaged(Branch) = .{},
/// Table to save `WValue`'s generated by an `Air.Inst`
// values: ValueTable,
/// Mapping from Air.Inst.Index to block ids
blocks: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, struct {
    label: u32,
    value: WValue,
}) = .{},
/// `bytes` contains the wasm bytecode belonging to the 'code' section.
code: *ArrayList(u8),
/// The index the next local generated will have
/// NOTE: arguments share the index with locals therefore the first variable
/// will have the index that comes after the last argument's index
local_index: u32 = 0,
/// The index of the current argument.
/// Used to track which argument is being referenced in `airArg`.
arg_index: u32 = 0,
/// If codegen fails, an error messages will be allocated and saved in `err_msg`
err_msg: *Module.ErrorMsg,
/// List of all locals' types generated throughout this declaration
/// used to emit locals count at start of 'code' section.
locals: std.ArrayListUnmanaged(u8),
/// List of simd128 immediates. Each value is stored as an array of bytes.
/// This list will only be populated for 128bit-simd values when the target features
/// are enabled also.
simd_immediates: std.ArrayListUnmanaged([16]u8) = .{},
/// The Target we're emitting (used to call intInfo)
target: std.Target,
/// Represents the wasm binary file that is being linked.
bin_file: *link.File.Wasm,
/// List of MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// Contains extra data for MIR
mir_extra: std.ArrayListUnmanaged(u32) = .{},
/// When a function is executing, we store the the current stack pointer's value within this local.
/// This value is then used to restore the stack pointer to the original value at the return of the function.
initial_stack_value: WValue = .none,
/// The current stack pointer substracted with the stack size. From this value, we will calculate
/// all offsets of the stack values.
bottom_stack_value: WValue = .none,
/// Arguments of this function declaration
/// This will be set after `resolveCallingConventionValues`
args: []WValue = &.{},
/// This will only be `.none` if the function returns void, or returns an immediate.
/// When it returns a pointer to the stack, the `.local` tag will be active and must be populated
/// before this function returns its execution to the caller.
return_value: WValue = .none,
/// The size of the stack this function occupies. In the function prologue
/// we will move the stack pointer by this number, forward aligned with the `stack_alignment`.
stack_size: u32 = 0,
/// The stack alignment, which is 16 bytes by default. This is specified by the
/// tool-conventions: https://github.com/WebAssembly/tool-conventions/blob/main/BasicCABI.md
/// and also what the llvm backend will emit.
/// However, local variables or the usage of `@setAlignStack` can overwrite this default.
stack_alignment: Alignment = .@"16",

// For each individual Wasm valtype we store a seperate free list which
// allows us to re-use locals that are no longer used. e.g. a temporary local.
/// A list of indexes which represents a local of valtype `i32`.
/// It is illegal to store a non-i32 valtype in this list.
free_locals_i32: std.ArrayListUnmanaged(u32) = .{},
/// A list of indexes which represents a local of valtype `i64`.
/// It is illegal to store a non-i64 valtype in this list.
free_locals_i64: std.ArrayListUnmanaged(u32) = .{},
/// A list of indexes which represents a local of valtype `f32`.
/// It is illegal to store a non-f32 valtype in this list.
free_locals_f32: std.ArrayListUnmanaged(u32) = .{},
/// A list of indexes which represents a local of valtype `f64`.
/// It is illegal to store a non-f64 valtype in this list.
free_locals_f64: std.ArrayListUnmanaged(u32) = .{},
/// A list of indexes which represents a local of valtype `v127`.
/// It is illegal to store a non-v128 valtype in this list.
free_locals_v128: std.ArrayListUnmanaged(u32) = .{},

/// When in debug mode, this tracks if no `finishAir` was missed.
/// Forgetting to call `finishAir` will cause the result to not be
/// stored in our `values` map and therefore cause bugs.
air_bookkeeping: @TypeOf(bookkeeping_init) = bookkeeping_init,

const bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const InnerError = error{
    OutOfMemory,
    /// An error occurred when trying to lower AIR to MIR.
    CodegenFail,
    /// Compiler implementation could not handle a large integer.
    Overflow,
};

pub fn deinit(func: *CodeGen) void {
    // in case of an error and we still have branches
    for (func.branches.items) |*branch| {
        branch.deinit(func.gpa);
    }
    func.branches.deinit(func.gpa);
    func.blocks.deinit(func.gpa);
    func.locals.deinit(func.gpa);
    func.simd_immediates.deinit(func.gpa);
    func.mir_instructions.deinit(func.gpa);
    func.mir_extra.deinit(func.gpa);
    func.free_locals_i32.deinit(func.gpa);
    func.free_locals_i64.deinit(func.gpa);
    func.free_locals_f32.deinit(func.gpa);
    func.free_locals_f64.deinit(func.gpa);
    func.free_locals_v128.deinit(func.gpa);
    func.* = undefined;
}

/// Sets `err_msg` on `CodeGen` and returns `error.CodegenFail` which is caught in link/Wasm.zig
fn fail(func: *CodeGen, comptime fmt: []const u8, args: anytype) InnerError {
    const mod = func.bin_file.base.comp.module.?;
    const src_loc = func.decl.srcLoc(mod);
    func.err_msg = try Module.ErrorMsg.create(func.gpa, src_loc, fmt, args);
    return error.CodegenFail;
}

/// Resolves the `WValue` for the given instruction `inst`
/// When the given instruction has a `Value`, it returns a constant instead
fn resolveInst(func: *CodeGen, ref: Air.Inst.Ref) InnerError!WValue {
    var branch_index = func.branches.items.len;
    while (branch_index > 0) : (branch_index -= 1) {
        const branch = func.branches.items[branch_index - 1];
        if (branch.values.get(ref)) |value| {
            return value;
        }
    }

    // when we did not find an existing instruction, it
    // means we must generate it from a constant.
    // We always store constants in the most outer branch as they must never
    // be removed. The most outer branch is always at index 0.
    const gop = try func.branches.items[0].values.getOrPut(func.gpa, ref);
    assert(!gop.found_existing);

    const mod = func.bin_file.base.comp.module.?;
    const val = (try func.air.value(ref, mod)).?;
    const ty = func.typeOf(ref);
    if (!ty.hasRuntimeBitsIgnoreComptime(mod) and !ty.isInt(mod) and !ty.isError(mod)) {
        gop.value_ptr.* = WValue{ .none = {} };
        return gop.value_ptr.*;
    }

    // When we need to pass the value by reference (such as a struct), we will
    // leverage `generateSymbol` to lower the constant to bytes and emit it
    // to the 'rodata' section. We then return the index into the section as `WValue`.
    //
    // In the other cases, we will simply lower the constant to a value that fits
    // into a single local (such as a pointer, integer, bool, etc).
    const result = if (isByRef(ty, mod)) blk: {
        const sym_index = try func.bin_file.lowerUnnamedConst(val, func.decl_index);
        break :blk WValue{ .memory = sym_index };
    } else try func.lowerConstant(val, ty);

    gop.value_ptr.* = result;
    return result;
}

fn finishAir(func: *CodeGen, inst: Air.Inst.Index, result: WValue, operands: []const Air.Inst.Ref) void {
    assert(operands.len <= Liveness.bpi - 1);
    var tomb_bits = func.liveness.getTombBits(inst);
    for (operands) |operand| {
        const dies = @as(u1, @truncate(tomb_bits)) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        processDeath(func, operand);
    }

    // results of `none` can never be referenced.
    if (result != .none) {
        assert(result != .stack); // it's illegal to store a stack value as we cannot track its position
        const branch = func.currentBranch();
        branch.values.putAssumeCapacityNoClobber(inst.toRef(), result);
    }

    if (std.debug.runtime_safety) {
        func.air_bookkeeping += 1;
    }
}

const Branch = struct {
    values: ValueTable = .{},

    fn deinit(branch: *Branch, gpa: Allocator) void {
        branch.values.deinit(gpa);
        branch.* = undefined;
    }
};

inline fn currentBranch(func: *CodeGen) *Branch {
    return &func.branches.items[func.branches.items.len - 1];
}

const BigTomb = struct {
    gen: *CodeGen,
    inst: Air.Inst.Index,
    lbt: Liveness.BigTomb,

    fn feed(bt: *BigTomb, op_ref: Air.Inst.Ref) void {
        const dies = bt.lbt.feed();
        if (!dies) return;
        // This will be a nop for interned constants.
        processDeath(bt.gen, op_ref);
    }

    fn finishAir(bt: *BigTomb, result: WValue) void {
        assert(result != .stack);
        if (result != .none) {
            bt.gen.currentBranch().values.putAssumeCapacityNoClobber(bt.inst.toRef(), result);
        }

        if (std.debug.runtime_safety) {
            bt.gen.air_bookkeeping += 1;
        }
    }
};

fn iterateBigTomb(func: *CodeGen, inst: Air.Inst.Index, operand_count: usize) !BigTomb {
    try func.currentBranch().values.ensureUnusedCapacity(func.gpa, operand_count + 1);
    return BigTomb{
        .gen = func,
        .inst = inst,
        .lbt = func.liveness.iterateBigTomb(inst),
    };
}

fn processDeath(func: *CodeGen, ref: Air.Inst.Ref) void {
    if (ref.toIndex() == null) return;
    // Branches are currently only allowed to free locals allocated
    // within their own branch.
    // TODO: Upon branch consolidation free any locals if needed.
    const value = func.currentBranch().values.getPtr(ref) orelse return;
    if (value.* != .local) return;
    const reserved_indexes = func.args.len + @intFromBool(func.return_value != .none);
    if (value.local.value < reserved_indexes) {
        return; // function arguments can never be re-used
    }
    log.debug("Decreasing reference for ref: %{d}, using local '{d}'", .{ @intFromEnum(ref.toIndex().?), value.local.value });
    value.local.references -= 1; // if this panics, a call to `reuseOperand` was forgotten by the developer
    if (value.local.references == 0) {
        value.free(func);
    }
}

/// Appends a MIR instruction and returns its index within the list of instructions
fn addInst(func: *CodeGen, inst: Mir.Inst) error{OutOfMemory}!void {
    try func.mir_instructions.append(func.gpa, inst);
}

fn addTag(func: *CodeGen, tag: Mir.Inst.Tag) error{OutOfMemory}!void {
    try func.addInst(.{ .tag = tag, .data = .{ .tag = {} } });
}

fn addExtended(func: *CodeGen, opcode: wasm.MiscOpcode) error{OutOfMemory}!void {
    const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
    try func.mir_extra.append(func.gpa, @intFromEnum(opcode));
    try func.addInst(.{ .tag = .misc_prefix, .data = .{ .payload = extra_index } });
}

fn addLabel(func: *CodeGen, tag: Mir.Inst.Tag, label: u32) error{OutOfMemory}!void {
    try func.addInst(.{ .tag = tag, .data = .{ .label = label } });
}

fn addImm32(func: *CodeGen, imm: i32) error{OutOfMemory}!void {
    try func.addInst(.{ .tag = .i32_const, .data = .{ .imm32 = imm } });
}

/// Accepts an unsigned 64bit integer rather than a signed integer to
/// prevent us from having to bitcast multiple times as most values
/// within codegen are represented as unsigned rather than signed.
fn addImm64(func: *CodeGen, imm: u64) error{OutOfMemory}!void {
    const extra_index = try func.addExtra(Mir.Imm64.fromU64(imm));
    try func.addInst(.{ .tag = .i64_const, .data = .{ .payload = extra_index } });
}

/// Accepts the index into the list of 128bit-immediates
fn addImm128(func: *CodeGen, index: u32) error{OutOfMemory}!void {
    const simd_values = func.simd_immediates.items[index];
    const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
    // tag + 128bit value
    try func.mir_extra.ensureUnusedCapacity(func.gpa, 5);
    func.mir_extra.appendAssumeCapacity(std.wasm.simdOpcode(.v128_const));
    func.mir_extra.appendSliceAssumeCapacity(@alignCast(mem.bytesAsSlice(u32, &simd_values)));
    try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });
}

fn addFloat64(func: *CodeGen, float: f64) error{OutOfMemory}!void {
    const extra_index = try func.addExtra(Mir.Float64.fromFloat64(float));
    try func.addInst(.{ .tag = .f64_const, .data = .{ .payload = extra_index } });
}

/// Inserts an instruction to load/store from/to wasm's linear memory dependent on the given `tag`.
fn addMemArg(func: *CodeGen, tag: Mir.Inst.Tag, mem_arg: Mir.MemArg) error{OutOfMemory}!void {
    const extra_index = try func.addExtra(mem_arg);
    try func.addInst(.{ .tag = tag, .data = .{ .payload = extra_index } });
}

/// Inserts an instruction from the 'atomics' feature which accesses wasm's linear memory dependent on the
/// given `tag`.
fn addAtomicMemArg(func: *CodeGen, tag: wasm.AtomicsOpcode, mem_arg: Mir.MemArg) error{OutOfMemory}!void {
    const extra_index = try func.addExtra(@as(struct { val: u32 }, .{ .val = wasm.atomicsOpcode(tag) }));
    _ = try func.addExtra(mem_arg);
    try func.addInst(.{ .tag = .atomics_prefix, .data = .{ .payload = extra_index } });
}

/// Helper function to emit atomic mir opcodes.
fn addAtomicTag(func: *CodeGen, tag: wasm.AtomicsOpcode) error{OutOfMemory}!void {
    const extra_index = try func.addExtra(@as(struct { val: u32 }, .{ .val = wasm.atomicsOpcode(tag) }));
    try func.addInst(.{ .tag = .atomics_prefix, .data = .{ .payload = extra_index } });
}

/// Appends entries to `mir_extra` based on the type of `extra`.
/// Returns the index into `mir_extra`
fn addExtra(func: *CodeGen, extra: anytype) error{OutOfMemory}!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try func.mir_extra.ensureUnusedCapacity(func.gpa, fields.len);
    return func.addExtraAssumeCapacity(extra);
}

/// Appends entries to `mir_extra` based on the type of `extra`.
/// Returns the index into `mir_extra`
fn addExtraAssumeCapacity(func: *CodeGen, extra: anytype) error{OutOfMemory}!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @as(u32, @intCast(func.mir_extra.items.len));
    inline for (fields) |field| {
        func.mir_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => |field_type| @compileError("Unsupported field type " ++ @typeName(field_type)),
        });
    }
    return result;
}

/// Using a given `Type`, returns the corresponding type
fn typeToValtype(ty: Type, mod: *Module) wasm.Valtype {
    const target = mod.getTarget();
    const ip = &mod.intern_pool;
    return switch (ty.zigTypeTag(mod)) {
        .Float => switch (ty.floatBits(target)) {
            16 => wasm.Valtype.i32, // stored/loaded as u16
            32 => wasm.Valtype.f32,
            64 => wasm.Valtype.f64,
            80, 128 => wasm.Valtype.i64,
            else => unreachable,
        },
        .Int, .Enum => blk: {
            const info = ty.intInfo(mod);
            if (info.bits <= 32) break :blk wasm.Valtype.i32;
            if (info.bits > 32 and info.bits <= 128) break :blk wasm.Valtype.i64;
            break :blk wasm.Valtype.i32; // represented as pointer to stack
        },
        .Struct => {
            if (mod.typeToPackedStruct(ty)) |packed_struct| {
                return typeToValtype(Type.fromInterned(packed_struct.backingIntType(ip).*), mod);
            } else {
                return wasm.Valtype.i32;
            }
        },
        .Vector => switch (determineSimdStoreStrategy(ty, mod)) {
            .direct => wasm.Valtype.v128,
            .unrolled => wasm.Valtype.i32,
        },
        .Union => switch (ty.containerLayout(mod)) {
            .@"packed" => {
                const int_ty = mod.intType(.unsigned, @as(u16, @intCast(ty.bitSize(mod)))) catch @panic("out of memory");
                return typeToValtype(int_ty, mod);
            },
            else => wasm.Valtype.i32,
        },
        else => wasm.Valtype.i32, // all represented as reference/immediate
    };
}

/// Using a given `Type`, returns the byte representation of its wasm value type
fn genValtype(ty: Type, mod: *Module) u8 {
    return wasm.valtype(typeToValtype(ty, mod));
}

/// Using a given `Type`, returns the corresponding wasm value type
/// Differently from `genValtype` this also allows `void` to create a block
/// with no return type
fn genBlockType(ty: Type, mod: *Module) u8 {
    return switch (ty.ip_index) {
        .void_type, .noreturn_type => wasm.block_empty,
        else => genValtype(ty, mod),
    };
}

/// Writes the bytecode depending on the given `WValue` in `val`
fn emitWValue(func: *CodeGen, value: WValue) InnerError!void {
    switch (value) {
        .dead => unreachable, // reference to free'd `WValue` (missing reuseOperand?)
        .none, .stack => {}, // no-op
        .local => |idx| try func.addLabel(.local_get, idx.value),
        .imm32 => |val| try func.addImm32(@as(i32, @bitCast(val))),
        .imm64 => |val| try func.addImm64(val),
        .imm128 => |val| try func.addImm128(val),
        .float32 => |val| try func.addInst(.{ .tag = .f32_const, .data = .{ .float32 = val } }),
        .float64 => |val| try func.addFloat64(val),
        .memory => |ptr| {
            const extra_index = try func.addExtra(Mir.Memory{ .pointer = ptr, .offset = 0 });
            try func.addInst(.{ .tag = .memory_address, .data = .{ .payload = extra_index } });
        },
        .memory_offset => |mem_off| {
            const extra_index = try func.addExtra(Mir.Memory{ .pointer = mem_off.pointer, .offset = mem_off.offset });
            try func.addInst(.{ .tag = .memory_address, .data = .{ .payload = extra_index } });
        },
        .function_index => |index| try func.addLabel(.function_index, index), // write function index and generate relocation
        .stack_offset => try func.addLabel(.local_get, func.bottom_stack_value.local.value), // caller must ensure to address the offset
    }
}

/// If given a local or stack-offset, increases the reference count by 1.
/// The old `WValue` found at instruction `ref` is then replaced by the
/// modified `WValue` and returned. When given a non-local or non-stack-offset,
/// returns the given `operand` itfunc instead.
fn reuseOperand(func: *CodeGen, ref: Air.Inst.Ref, operand: WValue) WValue {
    if (operand != .local and operand != .stack_offset) return operand;
    var new_value = operand;
    switch (new_value) {
        .local => |*local| local.references += 1,
        .stack_offset => |*stack_offset| stack_offset.references += 1,
        else => unreachable,
    }
    const old_value = func.getResolvedInst(ref);
    old_value.* = new_value;
    return new_value;
}

/// From a reference, returns its resolved `WValue`.
/// It's illegal to provide a `Air.Inst.Ref` that hasn't been resolved yet.
fn getResolvedInst(func: *CodeGen, ref: Air.Inst.Ref) *WValue {
    var index = func.branches.items.len;
    while (index > 0) : (index -= 1) {
        const branch = func.branches.items[index - 1];
        if (branch.values.getPtr(ref)) |value| {
            return value;
        }
    }
    unreachable; // developer-error: This can only be called on resolved instructions. Use `resolveInst` instead.
}

/// Creates one locals for a given `Type`.
/// Returns a corresponding `Wvalue` with `local` as active tag
fn allocLocal(func: *CodeGen, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const valtype = typeToValtype(ty, mod);
    switch (valtype) {
        .i32 => if (func.free_locals_i32.popOrNull()) |index| {
            log.debug("reusing local ({d}) of type {}", .{ index, valtype });
            return WValue{ .local = .{ .value = index, .references = 1 } };
        },
        .i64 => if (func.free_locals_i64.popOrNull()) |index| {
            log.debug("reusing local ({d}) of type {}", .{ index, valtype });
            return WValue{ .local = .{ .value = index, .references = 1 } };
        },
        .f32 => if (func.free_locals_f32.popOrNull()) |index| {
            log.debug("reusing local ({d}) of type {}", .{ index, valtype });
            return WValue{ .local = .{ .value = index, .references = 1 } };
        },
        .f64 => if (func.free_locals_f64.popOrNull()) |index| {
            log.debug("reusing local ({d}) of type {}", .{ index, valtype });
            return WValue{ .local = .{ .value = index, .references = 1 } };
        },
        .v128 => if (func.free_locals_v128.popOrNull()) |index| {
            log.debug("reusing local ({d}) of type {}", .{ index, valtype });
            return WValue{ .local = .{ .value = index, .references = 1 } };
        },
    }
    log.debug("new local of type {}", .{valtype});
    // no local was free to be re-used, so allocate a new local instead
    return func.ensureAllocLocal(ty);
}

/// Ensures a new local will be created. This is useful when it's useful
/// to use a zero-initialized local.
fn ensureAllocLocal(func: *CodeGen, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    try func.locals.append(func.gpa, genValtype(ty, mod));
    const initial_index = func.local_index;
    func.local_index += 1;
    return WValue{ .local = .{ .value = initial_index, .references = 1 } };
}

/// Generates a `wasm.Type` from a given function type.
/// Memory is owned by the caller.
fn genFunctype(
    gpa: Allocator,
    cc: std.builtin.CallingConvention,
    params: []const InternPool.Index,
    return_type: Type,
    mod: *Module,
) !wasm.Type {
    var temp_params = std.ArrayList(wasm.Valtype).init(gpa);
    defer temp_params.deinit();
    var returns = std.ArrayList(wasm.Valtype).init(gpa);
    defer returns.deinit();

    if (firstParamSRet(cc, return_type, mod)) {
        try temp_params.append(.i32); // memory address is always a 32-bit handle
    } else if (return_type.hasRuntimeBitsIgnoreComptime(mod)) {
        if (cc == .C) {
            const res_classes = abi.classifyType(return_type, mod);
            assert(res_classes[0] == .direct and res_classes[1] == .none);
            const scalar_type = abi.scalarType(return_type, mod);
            try returns.append(typeToValtype(scalar_type, mod));
        } else {
            try returns.append(typeToValtype(return_type, mod));
        }
    } else if (return_type.isError(mod)) {
        try returns.append(.i32);
    }

    // param types
    for (params) |param_type_ip| {
        const param_type = Type.fromInterned(param_type_ip);
        if (!param_type.hasRuntimeBitsIgnoreComptime(mod)) continue;

        switch (cc) {
            .C => {
                const param_classes = abi.classifyType(param_type, mod);
                for (param_classes) |class| {
                    if (class == .none) continue;
                    if (class == .direct) {
                        const scalar_type = abi.scalarType(param_type, mod);
                        try temp_params.append(typeToValtype(scalar_type, mod));
                    } else {
                        try temp_params.append(typeToValtype(param_type, mod));
                    }
                }
            },
            else => if (isByRef(param_type, mod))
                try temp_params.append(.i32)
            else
                try temp_params.append(typeToValtype(param_type, mod)),
        }
    }

    return wasm.Type{
        .params = try temp_params.toOwnedSlice(),
        .returns = try returns.toOwnedSlice(),
    };
}

pub fn generate(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: codegen.DebugInfoOutput,
) codegen.CodeGenError!codegen.Result {
    _ = src_loc;
    const comp = bin_file.comp;
    const gpa = comp.gpa;
    const mod = comp.module.?;
    const func = mod.funcInfo(func_index);
    const decl = mod.declPtr(func.owner_decl);
    const namespace = mod.namespacePtr(decl.src_namespace);
    const target = namespace.file_scope.mod.resolved_target.result;
    var code_gen: CodeGen = .{
        .gpa = gpa,
        .air = air,
        .liveness = liveness,
        .code = code,
        .decl_index = func.owner_decl,
        .decl = decl,
        .err_msg = undefined,
        .locals = .{},
        .target = target,
        .bin_file = bin_file.cast(link.File.Wasm).?,
        .debug_output = debug_output,
        .func_index = func_index,
    };
    defer code_gen.deinit();

    genFunc(&code_gen) catch |err| switch (err) {
        error.CodegenFail => return codegen.Result{ .fail = code_gen.err_msg },
        else => |e| return e,
    };

    return codegen.Result.ok;
}

fn genFunc(func: *CodeGen) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const fn_info = mod.typeToFunc(func.decl.typeOf(mod)).?;
    var func_type = try genFunctype(func.gpa, fn_info.cc, fn_info.param_types.get(ip), Type.fromInterned(fn_info.return_type), mod);
    defer func_type.deinit(func.gpa);
    _ = try func.bin_file.storeDeclType(func.decl_index, func_type);

    var cc_result = try func.resolveCallingConventionValues(func.decl.typeOf(mod));
    defer cc_result.deinit(func.gpa);

    func.args = cc_result.args;
    func.return_value = cc_result.return_value;

    try func.addTag(.dbg_prologue_end);

    try func.branches.append(func.gpa, .{});
    // clean up outer branch
    defer {
        var outer_branch = func.branches.pop();
        outer_branch.deinit(func.gpa);
        assert(func.branches.items.len == 0); // missing branch merge
    }
    // Generate MIR for function body
    try func.genBody(func.air.getMainBody());

    // In case we have a return value, but the last instruction is a noreturn (such as a while loop)
    // we emit an unreachable instruction to tell the stack validator that part will never be reached.
    if (func_type.returns.len != 0 and func.air.instructions.len > 0) {
        const inst: Air.Inst.Index = @enumFromInt(func.air.instructions.len - 1);
        const last_inst_ty = func.typeOfIndex(inst);
        if (!last_inst_ty.hasRuntimeBitsIgnoreComptime(mod) or last_inst_ty.isNoReturn(mod)) {
            try func.addTag(.@"unreachable");
        }
    }
    // End of function body
    try func.addTag(.end);

    try func.addTag(.dbg_epilogue_begin);

    // check if we have to initialize and allocate anything into the stack frame.
    // If so, create enough stack space and insert the instructions at the front of the list.
    if (func.initial_stack_value != .none) {
        var prologue = std.ArrayList(Mir.Inst).init(func.gpa);
        defer prologue.deinit();

        const sp = @intFromEnum(func.bin_file.zigObjectPtr().?.stack_pointer_sym);
        // load stack pointer
        try prologue.append(.{ .tag = .global_get, .data = .{ .label = sp } });
        // store stack pointer so we can restore it when we return from the function
        try prologue.append(.{ .tag = .local_tee, .data = .{ .label = func.initial_stack_value.local.value } });
        // get the total stack size
        const aligned_stack = func.stack_alignment.forward(func.stack_size);
        try prologue.append(.{ .tag = .i32_const, .data = .{ .imm32 = @intCast(aligned_stack) } });
        // subtract it from the current stack pointer
        try prologue.append(.{ .tag = .i32_sub, .data = .{ .tag = {} } });
        // Get negative stack aligment
        try prologue.append(.{ .tag = .i32_const, .data = .{ .imm32 = @as(i32, @intCast(func.stack_alignment.toByteUnits().?)) * -1 } });
        // Bitwise-and the value to get the new stack pointer to ensure the pointers are aligned with the abi alignment
        try prologue.append(.{ .tag = .i32_and, .data = .{ .tag = {} } });
        // store the current stack pointer as the bottom, which will be used to calculate all stack pointer offsets
        try prologue.append(.{ .tag = .local_tee, .data = .{ .label = func.bottom_stack_value.local.value } });
        // Store the current stack pointer value into the global stack pointer so other function calls will
        // start from this value instead and not overwrite the current stack.
        try prologue.append(.{ .tag = .global_set, .data = .{ .label = sp } });

        // reserve space and insert all prologue instructions at the front of the instruction list
        // We insert them in reserve order as there is no insertSlice in multiArrayList.
        try func.mir_instructions.ensureUnusedCapacity(func.gpa, prologue.items.len);
        for (prologue.items, 0..) |_, index| {
            const inst = prologue.items[prologue.items.len - 1 - index];
            func.mir_instructions.insertAssumeCapacity(0, inst);
        }
    }

    var mir: Mir = .{
        .instructions = func.mir_instructions.toOwnedSlice(),
        .extra = try func.mir_extra.toOwnedSlice(func.gpa),
    };
    defer mir.deinit(func.gpa);

    var emit: Emit = .{
        .mir = mir,
        .bin_file = func.bin_file,
        .code = func.code,
        .locals = func.locals.items,
        .decl_index = func.decl_index,
        .dbg_output = func.debug_output,
        .prev_di_line = 0,
        .prev_di_column = 0,
        .prev_di_offset = 0,
    };

    emit.emitMir() catch |err| switch (err) {
        error.EmitFail => {
            func.err_msg = emit.error_msg.?;
            return error.CodegenFail;
        },
        else => |e| return e,
    };
}

const CallWValues = struct {
    args: []WValue,
    return_value: WValue,

    fn deinit(values: *CallWValues, gpa: Allocator) void {
        gpa.free(values.args);
        values.* = undefined;
    }
};

fn resolveCallingConventionValues(func: *CodeGen, fn_ty: Type) InnerError!CallWValues {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const fn_info = mod.typeToFunc(fn_ty).?;
    const cc = fn_info.cc;
    var result: CallWValues = .{
        .args = &.{},
        .return_value = .none,
    };
    if (cc == .Naked) return result;

    var args = std.ArrayList(WValue).init(func.gpa);
    defer args.deinit();

    // Check if we store the result as a pointer to the stack rather than
    // by value
    if (firstParamSRet(fn_info.cc, Type.fromInterned(fn_info.return_type), mod)) {
        // the sret arg will be passed as first argument, therefore we
        // set the `return_value` before allocating locals for regular args.
        result.return_value = .{ .local = .{ .value = func.local_index, .references = 1 } };
        func.local_index += 1;
    }

    switch (cc) {
        .Unspecified => {
            for (fn_info.param_types.get(ip)) |ty| {
                if (!Type.fromInterned(ty).hasRuntimeBitsIgnoreComptime(mod)) {
                    continue;
                }

                try args.append(.{ .local = .{ .value = func.local_index, .references = 1 } });
                func.local_index += 1;
            }
        },
        .C => {
            for (fn_info.param_types.get(ip)) |ty| {
                const ty_classes = abi.classifyType(Type.fromInterned(ty), mod);
                for (ty_classes) |class| {
                    if (class == .none) continue;
                    try args.append(.{ .local = .{ .value = func.local_index, .references = 1 } });
                    func.local_index += 1;
                }
            }
        },
        else => return func.fail("calling convention '{s}' not supported for Wasm", .{@tagName(cc)}),
    }
    result.args = try args.toOwnedSlice();
    return result;
}

fn firstParamSRet(cc: std.builtin.CallingConvention, return_type: Type, mod: *Module) bool {
    switch (cc) {
        .Unspecified, .Inline => return isByRef(return_type, mod),
        .C => {
            const ty_classes = abi.classifyType(return_type, mod);
            if (ty_classes[0] == .indirect) return true;
            if (ty_classes[0] == .direct and ty_classes[1] == .direct) return true;
            return false;
        },
        else => return false,
    }
}

/// Lowers a Zig type and its value based on a given calling convention to ensure
/// it matches the ABI.
fn lowerArg(func: *CodeGen, cc: std.builtin.CallingConvention, ty: Type, value: WValue) !void {
    if (cc != .C) {
        return func.lowerToStack(value);
    }

    const mod = func.bin_file.base.comp.module.?;
    const ty_classes = abi.classifyType(ty, mod);
    assert(ty_classes[0] != .none);
    switch (ty.zigTypeTag(mod)) {
        .Struct, .Union => {
            if (ty_classes[0] == .indirect) {
                return func.lowerToStack(value);
            }
            assert(ty_classes[0] == .direct);
            const scalar_type = abi.scalarType(ty, mod);
            switch (value) {
                .memory,
                .memory_offset,
                .stack_offset,
                => _ = try func.load(value, scalar_type, 0),
                .dead => unreachable,
                else => try func.emitWValue(value),
            }
        },
        .Int, .Float => {
            if (ty_classes[1] == .none) {
                return func.lowerToStack(value);
            }
            assert(ty_classes[0] == .direct and ty_classes[1] == .direct);
            assert(ty.abiSize(mod) == 16);
            // in this case we have an integer or float that must be lowered as 2 i64's.
            try func.emitWValue(value);
            try func.addMemArg(.i64_load, .{ .offset = value.offset(), .alignment = 8 });
            try func.emitWValue(value);
            try func.addMemArg(.i64_load, .{ .offset = value.offset() + 8, .alignment = 8 });
        },
        else => return func.lowerToStack(value),
    }
}

/// Lowers a `WValue` to the stack. This means when the `value` results in
/// `.stack_offset` we calculate the pointer of this offset and use that.
/// The value is left on the stack, and not stored in any temporary.
fn lowerToStack(func: *CodeGen, value: WValue) !void {
    switch (value) {
        .stack_offset => |offset| {
            try func.emitWValue(value);
            if (offset.value > 0) {
                switch (func.arch()) {
                    .wasm32 => {
                        try func.addImm32(@as(i32, @bitCast(offset.value)));
                        try func.addTag(.i32_add);
                    },
                    .wasm64 => {
                        try func.addImm64(offset.value);
                        try func.addTag(.i64_add);
                    },
                    else => unreachable,
                }
            }
        },
        else => try func.emitWValue(value),
    }
}

/// Creates a local for the initial stack value
/// Asserts `initial_stack_value` is `.none`
fn initializeStack(func: *CodeGen) !void {
    assert(func.initial_stack_value == .none);
    // Reserve a local to store the current stack pointer
    // We can later use this local to set the stack pointer back to the value
    // we have stored here.
    func.initial_stack_value = try func.ensureAllocLocal(Type.usize);
    // Also reserve a local to store the bottom stack value
    func.bottom_stack_value = try func.ensureAllocLocal(Type.usize);
}

/// Reads the stack pointer from `Context.initial_stack_value` and writes it
/// to the global stack pointer variable
fn restoreStackPointer(func: *CodeGen) !void {
    // only restore the pointer if it was initialized
    if (func.initial_stack_value == .none) return;
    // Get the original stack pointer's value
    try func.emitWValue(func.initial_stack_value);

    // save its value in the global stack pointer
    try func.addLabel(.global_set, @intFromEnum(func.bin_file.zigObjectPtr().?.stack_pointer_sym));
}

/// From a given type, will create space on the virtual stack to store the value of such type.
/// This returns a `WValue` with its active tag set to `local`, containing the index to the local
/// that points to the position on the virtual stack. This function should be used instead of
/// moveStack unless a local was already created to store the pointer.
///
/// Asserts Type has codegenbits
fn allocStack(func: *CodeGen, ty: Type) !WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(ty.hasRuntimeBitsIgnoreComptime(mod));
    if (func.initial_stack_value == .none) {
        try func.initializeStack();
    }

    const abi_size = std.math.cast(u32, ty.abiSize(mod)) orelse {
        return func.fail("Type {} with ABI size of {d} exceeds stack frame size", .{
            ty.fmt(mod), ty.abiSize(mod),
        });
    };
    const abi_align = ty.abiAlignment(mod);

    func.stack_alignment = func.stack_alignment.max(abi_align);

    const offset: u32 = @intCast(abi_align.forward(func.stack_size));
    defer func.stack_size = offset + abi_size;

    return WValue{ .stack_offset = .{ .value = offset, .references = 1 } };
}

/// From a given AIR instruction generates a pointer to the stack where
/// the value of its type will live.
/// This is different from allocStack where this will use the pointer's alignment
/// if it is set, to ensure the stack alignment will be set correctly.
fn allocStackPtr(func: *CodeGen, inst: Air.Inst.Index) !WValue {
    const mod = func.bin_file.base.comp.module.?;
    const ptr_ty = func.typeOfIndex(inst);
    const pointee_ty = ptr_ty.childType(mod);

    if (func.initial_stack_value == .none) {
        try func.initializeStack();
    }

    if (!pointee_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return func.allocStack(Type.usize); // create a value containing just the stack pointer.
    }

    const abi_alignment = ptr_ty.ptrAlignment(mod);
    const abi_size = std.math.cast(u32, pointee_ty.abiSize(mod)) orelse {
        return func.fail("Type {} with ABI size of {d} exceeds stack frame size", .{
            pointee_ty.fmt(mod), pointee_ty.abiSize(mod),
        });
    };
    func.stack_alignment = func.stack_alignment.max(abi_alignment);

    const offset: u32 = @intCast(abi_alignment.forward(func.stack_size));
    defer func.stack_size = offset + abi_size;

    return WValue{ .stack_offset = .{ .value = offset, .references = 1 } };
}

/// From given zig bitsize, returns the wasm bitsize
fn toWasmBits(bits: u16) ?u16 {
    return for ([_]u16{ 32, 64, 128 }) |wasm_bits| {
        if (bits <= wasm_bits) return wasm_bits;
    } else null;
}

/// Performs a copy of bytes for a given type. Copying all bytes
/// from rhs to lhs.
fn memcpy(func: *CodeGen, dst: WValue, src: WValue, len: WValue) !void {
    // When bulk_memory is enabled, we lower it to wasm's memcpy instruction.
    // If not, we lower it ourselves manually
    if (std.Target.wasm.featureSetHas(func.target.cpu.features, .bulk_memory)) {
        try func.lowerToStack(dst);
        try func.lowerToStack(src);
        try func.emitWValue(len);
        try func.addExtended(.memory_copy);
        return;
    }

    // when the length is comptime-known, rather than a runtime value, we can optimize the generated code by having
    // the loop during codegen, rather than inserting a runtime loop into the binary.
    switch (len) {
        .imm32, .imm64 => blk: {
            const length = switch (len) {
                .imm32 => |val| val,
                .imm64 => |val| val,
                else => unreachable,
            };
            // if the size (length) is more than 32 bytes, we use a runtime loop instead to prevent
            // binary size bloat.
            if (length > 32) break :blk;
            var offset: u32 = 0;
            const lhs_base = dst.offset();
            const rhs_base = src.offset();
            while (offset < length) : (offset += 1) {
                // get dst's address to store the result
                try func.emitWValue(dst);
                // load byte from src's address
                try func.emitWValue(src);
                switch (func.arch()) {
                    .wasm32 => {
                        try func.addMemArg(.i32_load8_u, .{ .offset = rhs_base + offset, .alignment = 1 });
                        try func.addMemArg(.i32_store8, .{ .offset = lhs_base + offset, .alignment = 1 });
                    },
                    .wasm64 => {
                        try func.addMemArg(.i64_load8_u, .{ .offset = rhs_base + offset, .alignment = 1 });
                        try func.addMemArg(.i64_store8, .{ .offset = lhs_base + offset, .alignment = 1 });
                    },
                    else => unreachable,
                }
            }
            return;
        },
        else => {},
    }

    // allocate a local for the offset, and set it to 0.
    // This to ensure that inside loops we correctly re-set the counter.
    var offset = try func.allocLocal(Type.usize); // local for counter
    defer offset.free(func);
    switch (func.arch()) {
        .wasm32 => try func.addImm32(0),
        .wasm64 => try func.addImm64(0),
        else => unreachable,
    }
    try func.addLabel(.local_set, offset.local.value);

    // outer block to jump to when loop is done
    try func.startBlock(.block, wasm.block_empty);
    try func.startBlock(.loop, wasm.block_empty);

    // loop condition (offset == length -> break)
    {
        try func.emitWValue(offset);
        try func.emitWValue(len);
        switch (func.arch()) {
            .wasm32 => try func.addTag(.i32_eq),
            .wasm64 => try func.addTag(.i64_eq),
            else => unreachable,
        }
        try func.addLabel(.br_if, 1); // jump out of loop into outer block (finished)
    }

    // get dst ptr
    {
        try func.emitWValue(dst);
        try func.emitWValue(offset);
        switch (func.arch()) {
            .wasm32 => try func.addTag(.i32_add),
            .wasm64 => try func.addTag(.i64_add),
            else => unreachable,
        }
    }

    // get src value and also store in dst
    {
        try func.emitWValue(src);
        try func.emitWValue(offset);
        switch (func.arch()) {
            .wasm32 => {
                try func.addTag(.i32_add);
                try func.addMemArg(.i32_load8_u, .{ .offset = src.offset(), .alignment = 1 });
                try func.addMemArg(.i32_store8, .{ .offset = dst.offset(), .alignment = 1 });
            },
            .wasm64 => {
                try func.addTag(.i64_add);
                try func.addMemArg(.i64_load8_u, .{ .offset = src.offset(), .alignment = 1 });
                try func.addMemArg(.i64_store8, .{ .offset = dst.offset(), .alignment = 1 });
            },
            else => unreachable,
        }
    }

    // increment loop counter
    {
        try func.emitWValue(offset);
        switch (func.arch()) {
            .wasm32 => {
                try func.addImm32(1);
                try func.addTag(.i32_add);
            },
            .wasm64 => {
                try func.addImm64(1);
                try func.addTag(.i64_add);
            },
            else => unreachable,
        }
        try func.addLabel(.local_set, offset.local.value);
        try func.addLabel(.br, 0); // jump to start of loop
    }
    try func.endBlock(); // close off loop block
    try func.endBlock(); // close off outer block
}

fn ptrSize(func: *const CodeGen) u16 {
    return @divExact(func.target.ptrBitWidth(), 8);
}

fn arch(func: *const CodeGen) std.Target.Cpu.Arch {
    return func.target.cpu.arch;
}

/// For a given `Type`, will return true when the type will be passed
/// by reference, rather than by value
fn isByRef(ty: Type, mod: *Module) bool {
    const ip = &mod.intern_pool;
    const target = mod.getTarget();
    switch (ty.zigTypeTag(mod)) {
        .Type,
        .ComptimeInt,
        .ComptimeFloat,
        .EnumLiteral,
        .Undefined,
        .Null,
        .Opaque,
        => unreachable,

        .NoReturn,
        .Void,
        .Bool,
        .ErrorSet,
        .Fn,
        .Enum,
        .AnyFrame,
        => return false,

        .Array,
        .Frame,
        => return ty.hasRuntimeBitsIgnoreComptime(mod),
        .Union => {
            if (mod.typeToUnion(ty)) |union_obj| {
                if (union_obj.getLayout(ip) == .@"packed") {
                    return ty.abiSize(mod) > 8;
                }
            }
            return ty.hasRuntimeBitsIgnoreComptime(mod);
        },
        .Struct => {
            if (mod.typeToPackedStruct(ty)) |packed_struct| {
                return isByRef(Type.fromInterned(packed_struct.backingIntType(ip).*), mod);
            }
            return ty.hasRuntimeBitsIgnoreComptime(mod);
        },
        .Vector => return determineSimdStoreStrategy(ty, mod) == .unrolled,
        .Int => return ty.intInfo(mod).bits > 64,
        .Float => return ty.floatBits(target) > 64,
        .ErrorUnion => {
            const pl_ty = ty.errorUnionPayload(mod);
            if (!pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                return false;
            }
            return true;
        },
        .Optional => {
            if (ty.isPtrLikeOptional(mod)) return false;
            const pl_type = ty.optionalChild(mod);
            if (pl_type.zigTypeTag(mod) == .ErrorSet) return false;
            return pl_type.hasRuntimeBitsIgnoreComptime(mod);
        },
        .Pointer => {
            // Slices act like struct and will be passed by reference
            if (ty.isSlice(mod)) return true;
            return false;
        },
    }
}

const SimdStoreStrategy = enum {
    direct,
    unrolled,
};

/// For a given vector type, returns the `SimdStoreStrategy`.
/// This means when a given type is 128 bits and either the simd128 or relaxed-simd
/// features are enabled, the function will return `.direct`. This would allow to store
/// it using a instruction, rather than an unrolled version.
fn determineSimdStoreStrategy(ty: Type, mod: *Module) SimdStoreStrategy {
    std.debug.assert(ty.zigTypeTag(mod) == .Vector);
    if (ty.bitSize(mod) != 128) return .unrolled;
    const hasFeature = std.Target.wasm.featureSetHas;
    const target = mod.getTarget();
    const features = target.cpu.features;
    if (hasFeature(features, .relaxed_simd) or hasFeature(features, .simd128)) {
        return .direct;
    }
    return .unrolled;
}

/// Creates a new local for a pointer that points to memory with given offset.
/// This can be used to get a pointer to a struct field, error payload, etc.
/// By providing `modify` as action, it will modify the given `ptr_value` instead of making a new
/// local value to store the pointer. This allows for local re-use and improves binary size.
fn buildPointerOffset(func: *CodeGen, ptr_value: WValue, offset: u64, action: enum { modify, new }) InnerError!WValue {
    // do not perform arithmetic when offset is 0.
    if (offset == 0 and ptr_value.offset() == 0 and action == .modify) return ptr_value;
    const result_ptr: WValue = switch (action) {
        .new => try func.ensureAllocLocal(Type.usize),
        .modify => ptr_value,
    };
    try func.emitWValue(ptr_value);
    if (offset + ptr_value.offset() > 0) {
        switch (func.arch()) {
            .wasm32 => {
                try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(offset + ptr_value.offset())))));
                try func.addTag(.i32_add);
            },
            .wasm64 => {
                try func.addImm64(offset + ptr_value.offset());
                try func.addTag(.i64_add);
            },
            else => unreachable,
        }
    }
    try func.addLabel(.local_set, result_ptr.local.value);
    return result_ptr;
}

fn genInst(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const air_tags = func.air.instructions.items(.tag);
    return switch (air_tags[@intFromEnum(inst)]) {
        .inferred_alloc, .inferred_alloc_comptime => unreachable,

        .add => func.airBinOp(inst, .add),
        .add_sat => func.airSatBinOp(inst, .add),
        .add_wrap => func.airWrapBinOp(inst, .add),
        .sub => func.airBinOp(inst, .sub),
        .sub_sat => func.airSatBinOp(inst, .sub),
        .sub_wrap => func.airWrapBinOp(inst, .sub),
        .mul => func.airBinOp(inst, .mul),
        .mul_wrap => func.airWrapBinOp(inst, .mul),
        .div_float, .div_exact => func.airDiv(inst),
        .div_trunc => func.airDivTrunc(inst),
        .div_floor => func.airDivFloor(inst),
        .bit_and => func.airBinOp(inst, .@"and"),
        .bit_or => func.airBinOp(inst, .@"or"),
        .bool_and => func.airBinOp(inst, .@"and"),
        .bool_or => func.airBinOp(inst, .@"or"),
        .rem => func.airBinOp(inst, .rem),
        .mod => func.airMod(inst),
        .shl => func.airWrapBinOp(inst, .shl),
        .shl_exact => func.airBinOp(inst, .shl),
        .shl_sat => func.airShlSat(inst),
        .shr, .shr_exact => func.airBinOp(inst, .shr),
        .xor => func.airBinOp(inst, .xor),
        .max => func.airMaxMin(inst, .max),
        .min => func.airMaxMin(inst, .min),
        .mul_add => func.airMulAdd(inst),

        .sqrt => func.airUnaryFloatOp(inst, .sqrt),
        .sin => func.airUnaryFloatOp(inst, .sin),
        .cos => func.airUnaryFloatOp(inst, .cos),
        .tan => func.airUnaryFloatOp(inst, .tan),
        .exp => func.airUnaryFloatOp(inst, .exp),
        .exp2 => func.airUnaryFloatOp(inst, .exp2),
        .log => func.airUnaryFloatOp(inst, .log),
        .log2 => func.airUnaryFloatOp(inst, .log2),
        .log10 => func.airUnaryFloatOp(inst, .log10),
        .floor => func.airUnaryFloatOp(inst, .floor),
        .ceil => func.airUnaryFloatOp(inst, .ceil),
        .round => func.airUnaryFloatOp(inst, .round),
        .trunc_float => func.airUnaryFloatOp(inst, .trunc),
        .neg => func.airUnaryFloatOp(inst, .neg),

        .abs => func.airAbs(inst),

        .add_with_overflow => func.airAddSubWithOverflow(inst, .add),
        .sub_with_overflow => func.airAddSubWithOverflow(inst, .sub),
        .shl_with_overflow => func.airShlWithOverflow(inst),
        .mul_with_overflow => func.airMulWithOverflow(inst),

        .clz => func.airClz(inst),
        .ctz => func.airCtz(inst),

        .cmp_eq => func.airCmp(inst, .eq),
        .cmp_gte => func.airCmp(inst, .gte),
        .cmp_gt => func.airCmp(inst, .gt),
        .cmp_lte => func.airCmp(inst, .lte),
        .cmp_lt => func.airCmp(inst, .lt),
        .cmp_neq => func.airCmp(inst, .neq),

        .cmp_vector => func.airCmpVector(inst),
        .cmp_lt_errors_len => func.airCmpLtErrorsLen(inst),

        .array_elem_val => func.airArrayElemVal(inst),
        .array_to_slice => func.airArrayToSlice(inst),
        .alloc => func.airAlloc(inst),
        .arg => func.airArg(inst),
        .bitcast => func.airBitcast(inst),
        .block => func.airBlock(inst),
        .trap => func.airTrap(inst),
        .breakpoint => func.airBreakpoint(inst),
        .br => func.airBr(inst),
        .int_from_bool => func.airIntFromBool(inst),
        .cond_br => func.airCondBr(inst),
        .intcast => func.airIntcast(inst),
        .fptrunc => func.airFptrunc(inst),
        .fpext => func.airFpext(inst),
        .int_from_float => func.airIntFromFloat(inst),
        .float_from_int => func.airFloatFromInt(inst),
        .get_union_tag => func.airGetUnionTag(inst),

        .@"try" => func.airTry(inst),
        .try_ptr => func.airTryPtr(inst),

        .dbg_stmt => func.airDbgStmt(inst),
        .dbg_inline_block => func.airDbgInlineBlock(inst),
        .dbg_var_ptr => func.airDbgVar(inst, true),
        .dbg_var_val => func.airDbgVar(inst, false),

        .call => func.airCall(inst, .auto),
        .call_always_tail => func.airCall(inst, .always_tail),
        .call_never_tail => func.airCall(inst, .never_tail),
        .call_never_inline => func.airCall(inst, .never_inline),

        .is_err => func.airIsErr(inst, .i32_ne),
        .is_non_err => func.airIsErr(inst, .i32_eq),

        .is_null => func.airIsNull(inst, .i32_eq, .value),
        .is_non_null => func.airIsNull(inst, .i32_ne, .value),
        .is_null_ptr => func.airIsNull(inst, .i32_eq, .ptr),
        .is_non_null_ptr => func.airIsNull(inst, .i32_ne, .ptr),

        .load => func.airLoad(inst),
        .loop => func.airLoop(inst),
        .memset => func.airMemset(inst, false),
        .memset_safe => func.airMemset(inst, true),
        .not => func.airNot(inst),
        .optional_payload => func.airOptionalPayload(inst),
        .optional_payload_ptr => func.airOptionalPayloadPtr(inst),
        .optional_payload_ptr_set => func.airOptionalPayloadPtrSet(inst),
        .ptr_add => func.airPtrBinOp(inst, .add),
        .ptr_sub => func.airPtrBinOp(inst, .sub),
        .ptr_elem_ptr => func.airPtrElemPtr(inst),
        .ptr_elem_val => func.airPtrElemVal(inst),
        .int_from_ptr => func.airIntFromPtr(inst),
        .ret => func.airRet(inst),
        .ret_safe => func.airRet(inst), // TODO
        .ret_ptr => func.airRetPtr(inst),
        .ret_load => func.airRetLoad(inst),
        .splat => func.airSplat(inst),
        .select => func.airSelect(inst),
        .shuffle => func.airShuffle(inst),
        .reduce => func.airReduce(inst),
        .aggregate_init => func.airAggregateInit(inst),
        .union_init => func.airUnionInit(inst),
        .prefetch => func.airPrefetch(inst),
        .popcount => func.airPopcount(inst),
        .byte_swap => func.airByteSwap(inst),

        .slice => func.airSlice(inst),
        .slice_len => func.airSliceLen(inst),
        .slice_elem_val => func.airSliceElemVal(inst),
        .slice_elem_ptr => func.airSliceElemPtr(inst),
        .slice_ptr => func.airSlicePtr(inst),
        .ptr_slice_len_ptr => func.airPtrSliceFieldPtr(inst, func.ptrSize()),
        .ptr_slice_ptr_ptr => func.airPtrSliceFieldPtr(inst, 0),
        .store => func.airStore(inst, false),
        .store_safe => func.airStore(inst, true),

        .set_union_tag => func.airSetUnionTag(inst),
        .struct_field_ptr => func.airStructFieldPtr(inst),
        .struct_field_ptr_index_0 => func.airStructFieldPtrIndex(inst, 0),
        .struct_field_ptr_index_1 => func.airStructFieldPtrIndex(inst, 1),
        .struct_field_ptr_index_2 => func.airStructFieldPtrIndex(inst, 2),
        .struct_field_ptr_index_3 => func.airStructFieldPtrIndex(inst, 3),
        .struct_field_val => func.airStructFieldVal(inst),
        .field_parent_ptr => func.airFieldParentPtr(inst),

        .switch_br => func.airSwitchBr(inst),
        .trunc => func.airTrunc(inst),
        .unreach => func.airUnreachable(inst),

        .wrap_optional => func.airWrapOptional(inst),
        .unwrap_errunion_payload => func.airUnwrapErrUnionPayload(inst, false),
        .unwrap_errunion_payload_ptr => func.airUnwrapErrUnionPayload(inst, true),
        .unwrap_errunion_err => func.airUnwrapErrUnionError(inst, false),
        .unwrap_errunion_err_ptr => func.airUnwrapErrUnionError(inst, true),
        .wrap_errunion_payload => func.airWrapErrUnionPayload(inst),
        .wrap_errunion_err => func.airWrapErrUnionErr(inst),
        .errunion_payload_ptr_set => func.airErrUnionPayloadPtrSet(inst),
        .error_name => func.airErrorName(inst),

        .wasm_memory_size => func.airWasmMemorySize(inst),
        .wasm_memory_grow => func.airWasmMemoryGrow(inst),

        .memcpy => func.airMemcpy(inst),

        .ret_addr => func.airRetAddr(inst),
        .tag_name => func.airTagName(inst),

        .error_set_has_value => func.airErrorSetHasValue(inst),
        .frame_addr => func.airFrameAddress(inst),

        .mul_sat,
        .assembly,
        .bit_reverse,
        .is_err_ptr,
        .is_non_err_ptr,

        .err_return_trace,
        .set_err_return_trace,
        .save_err_return_trace_index,
        .is_named_enum_value,
        .addrspace_cast,
        .vector_store_elem,
        .c_va_arg,
        .c_va_copy,
        .c_va_end,
        .c_va_start,
        => |tag| return func.fail("TODO: Implement wasm inst: {s}", .{@tagName(tag)}),

        .atomic_load => func.airAtomicLoad(inst),
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        // in WebAssembly, all atomic instructions are sequentially ordered.
        => func.airAtomicStore(inst),
        .atomic_rmw => func.airAtomicRmw(inst),
        .cmpxchg_weak => func.airCmpxchg(inst),
        .cmpxchg_strong => func.airCmpxchg(inst),
        .fence => func.airFence(inst),

        .add_optimized,
        .sub_optimized,
        .mul_optimized,
        .div_float_optimized,
        .div_trunc_optimized,
        .div_floor_optimized,
        .div_exact_optimized,
        .rem_optimized,
        .mod_optimized,
        .neg_optimized,
        .cmp_lt_optimized,
        .cmp_lte_optimized,
        .cmp_eq_optimized,
        .cmp_gte_optimized,
        .cmp_gt_optimized,
        .cmp_neq_optimized,
        .cmp_vector_optimized,
        .reduce_optimized,
        .int_from_float_optimized,
        => return func.fail("TODO implement optimized float mode", .{}),

        .add_safe,
        .sub_safe,
        .mul_safe,
        => return func.fail("TODO implement safety_checked_instructions", .{}),

        .work_item_id,
        .work_group_size,
        .work_group_id,
        => unreachable,
    };
}

fn genBody(func: *CodeGen, body: []const Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;

    for (body) |inst| {
        if (func.liveness.isUnused(inst) and !func.air.mustLower(inst, ip)) {
            continue;
        }
        const old_bookkeeping_value = func.air_bookkeeping;
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, Liveness.bpi);
        try func.genInst(inst);

        if (std.debug.runtime_safety and func.air_bookkeeping < old_bookkeeping_value + 1) {
            std.debug.panic("Missing call to `finishAir` in AIR instruction %{d} ('{}')", .{
                inst,
                func.air.instructions.items(.tag)[@intFromEnum(inst)],
            });
        }
    }
}

fn airRet(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const fn_info = mod.typeToFunc(func.decl.typeOf(mod)).?;
    const ret_ty = Type.fromInterned(fn_info.return_type);

    // result must be stored in the stack and we return a pointer
    // to the stack instead
    if (func.return_value != .none) {
        try func.store(func.return_value, operand, ret_ty, 0);
    } else if (fn_info.cc == .C and ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        switch (ret_ty.zigTypeTag(mod)) {
            // Aggregate types can be lowered as a singular value
            .Struct, .Union => {
                const scalar_type = abi.scalarType(ret_ty, mod);
                try func.emitWValue(operand);
                const opcode = buildOpcode(.{
                    .op = .load,
                    .width = @as(u8, @intCast(scalar_type.abiSize(mod) * 8)),
                    .signedness = if (scalar_type.isSignedInt(mod)) .signed else .unsigned,
                    .valtype1 = typeToValtype(scalar_type, mod),
                });
                try func.addMemArg(Mir.Inst.Tag.fromOpcode(opcode), .{
                    .offset = operand.offset(),
                    .alignment = @intCast(scalar_type.abiAlignment(mod).toByteUnits().?),
                });
            },
            else => try func.emitWValue(operand),
        }
    } else {
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod) and ret_ty.isError(mod)) {
            try func.addImm32(0);
        } else {
            try func.emitWValue(operand);
        }
    }
    try func.restoreStackPointer();
    try func.addTag(.@"return");

    func.finishAir(inst, .none, &.{un_op});
}

fn airRetPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const child_type = func.typeOfIndex(inst).childType(mod);

    const result = result: {
        if (!child_type.isFnOrHasRuntimeBitsIgnoreComptime(mod)) {
            break :result try func.allocStack(Type.usize); // create pointer to void
        }

        const fn_info = mod.typeToFunc(func.decl.typeOf(mod)).?;
        if (firstParamSRet(fn_info.cc, Type.fromInterned(fn_info.return_type), mod)) {
            break :result func.return_value;
        }

        break :result try func.allocStackPtr(inst);
    };

    func.finishAir(inst, result, &.{});
}

fn airRetLoad(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const ret_ty = func.typeOf(un_op).childType(mod);

    const fn_info = mod.typeToFunc(func.decl.typeOf(mod)).?;
    if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        if (ret_ty.isError(mod)) {
            try func.addImm32(0);
        }
    } else if (!firstParamSRet(fn_info.cc, Type.fromInterned(fn_info.return_type), mod)) {
        // leave on the stack
        _ = try func.load(operand, ret_ty, 0);
    }

    try func.restoreStackPointer();
    try func.addTag(.@"return");
    return func.finishAir(inst, .none, &.{un_op});
}

fn airCall(func: *CodeGen, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) InnerError!void {
    if (modifier == .always_tail) return func.fail("TODO implement tail calls for wasm", .{});
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = func.air.extraData(Air.Call, pl_op.payload);
    const args = @as([]const Air.Inst.Ref, @ptrCast(func.air.extra[extra.end..][0..extra.data.args_len]));
    const ty = func.typeOf(pl_op.operand);

    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const fn_ty = switch (ty.zigTypeTag(mod)) {
        .Fn => ty,
        .Pointer => ty.childType(mod),
        else => unreachable,
    };
    const ret_ty = fn_ty.fnReturnType(mod);
    const fn_info = mod.typeToFunc(fn_ty).?;
    const first_param_sret = firstParamSRet(fn_info.cc, Type.fromInterned(fn_info.return_type), mod);

    const callee: ?InternPool.DeclIndex = blk: {
        const func_val = (try func.air.value(pl_op.operand, mod)) orelse break :blk null;

        if (func_val.getFunction(mod)) |function| {
            _ = try func.bin_file.getOrCreateAtomForDecl(function.owner_decl);
            break :blk function.owner_decl;
        } else if (func_val.getExternFunc(mod)) |extern_func| {
            const ext_decl = mod.declPtr(extern_func.decl);
            const ext_info = mod.typeToFunc(ext_decl.typeOf(mod)).?;
            var func_type = try genFunctype(func.gpa, ext_info.cc, ext_info.param_types.get(ip), Type.fromInterned(ext_info.return_type), mod);
            defer func_type.deinit(func.gpa);
            const atom_index = try func.bin_file.getOrCreateAtomForDecl(extern_func.decl);
            const atom = func.bin_file.getAtomPtr(atom_index);
            const type_index = try func.bin_file.storeDeclType(extern_func.decl, func_type);
            try func.bin_file.addOrUpdateImport(
                ext_decl.name.toSlice(&mod.intern_pool),
                atom.sym_index,
                ext_decl.getOwnedExternFunc(mod).?.lib_name.toSlice(&mod.intern_pool),
                type_index,
            );
            break :blk extern_func.decl;
        } else switch (mod.intern_pool.indexToKey(func_val.ip_index)) {
            .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                .decl => |decl| {
                    _ = try func.bin_file.getOrCreateAtomForDecl(decl);
                    break :blk decl;
                },
                else => {},
            },
            else => {},
        }
        return func.fail("Expected a function, but instead found '{s}'", .{@tagName(ip.indexToKey(func_val.toIntern()))});
    };

    const sret = if (first_param_sret) blk: {
        const sret_local = try func.allocStack(ret_ty);
        try func.lowerToStack(sret_local);
        break :blk sret_local;
    } else WValue{ .none = {} };

    for (args) |arg| {
        const arg_val = try func.resolveInst(arg);

        const arg_ty = func.typeOf(arg);
        if (!arg_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

        try func.lowerArg(mod.typeToFunc(fn_ty).?.cc, arg_ty, arg_val);
    }

    if (callee) |direct| {
        const atom_index = func.bin_file.zigObjectPtr().?.decls_map.get(direct).?.atom;
        try func.addLabel(.call, @intFromEnum(func.bin_file.getAtom(atom_index).sym_index));
    } else {
        // in this case we call a function pointer
        // so load its value onto the stack
        std.debug.assert(ty.zigTypeTag(mod) == .Pointer);
        const operand = try func.resolveInst(pl_op.operand);
        try func.emitWValue(operand);

        var fn_type = try genFunctype(func.gpa, fn_info.cc, fn_info.param_types.get(ip), Type.fromInterned(fn_info.return_type), mod);
        defer fn_type.deinit(func.gpa);

        const fn_type_index = try func.bin_file.zigObjectPtr().?.putOrGetFuncType(func.gpa, fn_type);
        try func.addLabel(.call_indirect, fn_type_index);
    }

    const result_value = result_value: {
        if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod) and !ret_ty.isError(mod)) {
            break :result_value WValue{ .none = {} };
        } else if (ret_ty.isNoReturn(mod)) {
            try func.addTag(.@"unreachable");
            break :result_value WValue{ .none = {} };
        } else if (first_param_sret) {
            break :result_value sret;
            // TODO: Make this less fragile and optimize
        } else if (mod.typeToFunc(fn_ty).?.cc == .C and ret_ty.zigTypeTag(mod) == .Struct or ret_ty.zigTypeTag(mod) == .Union) {
            const result_local = try func.allocLocal(ret_ty);
            try func.addLabel(.local_set, result_local.local.value);
            const scalar_type = abi.scalarType(ret_ty, mod);
            const result = try func.allocStack(scalar_type);
            try func.store(result, result_local, scalar_type, 0);
            break :result_value result;
        } else {
            const result_local = try func.allocLocal(ret_ty);
            try func.addLabel(.local_set, result_local.local.value);
            break :result_value result_local;
        }
    };

    var bt = try func.iterateBigTomb(inst, 1 + args.len);
    bt.feed(pl_op.operand);
    for (args) |arg| bt.feed(arg);
    return bt.finishAir(result_value);
}

fn airAlloc(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const value = try func.allocStackPtr(inst);
    func.finishAir(inst, value, &.{});
}

fn airStore(func: *CodeGen, inst: Air.Inst.Index, safety: bool) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const ptr_ty = func.typeOf(bin_op.lhs);
    const ptr_info = ptr_ty.ptrInfo(mod);
    const ty = ptr_ty.childType(mod);

    if (ptr_info.packed_offset.host_size == 0) {
        try func.store(lhs, rhs, ty, 0);
    } else {
        // at this point we have a non-natural alignment, we must
        // load the value, and then shift+or the rhs into the result location.
        const int_elem_ty = try mod.intType(.unsigned, ptr_info.packed_offset.host_size * 8);

        if (isByRef(int_elem_ty, mod)) {
            return func.fail("TODO: airStore for pointers to bitfields with backing type larger than 64bits", .{});
        }

        var mask = @as(u64, @intCast((@as(u65, 1) << @as(u7, @intCast(ty.bitSize(mod)))) - 1));
        mask <<= @as(u6, @intCast(ptr_info.packed_offset.bit_offset));
        mask ^= ~@as(u64, 0);
        const shift_val = if (ptr_info.packed_offset.host_size <= 4)
            WValue{ .imm32 = ptr_info.packed_offset.bit_offset }
        else
            WValue{ .imm64 = ptr_info.packed_offset.bit_offset };
        const mask_val = if (ptr_info.packed_offset.host_size <= 4)
            WValue{ .imm32 = @as(u32, @truncate(mask)) }
        else
            WValue{ .imm64 = mask };

        try func.emitWValue(lhs);
        const loaded = try func.load(lhs, int_elem_ty, 0);
        const anded = try func.binOp(loaded, mask_val, int_elem_ty, .@"and");
        const extended_value = try func.intcast(rhs, ty, int_elem_ty);
        const shifted_value = if (ptr_info.packed_offset.bit_offset > 0) shifted: {
            break :shifted try func.binOp(extended_value, shift_val, int_elem_ty, .shl);
        } else extended_value;
        const result = try func.binOp(anded, shifted_value, int_elem_ty, .@"or");
        // lhs is still on the stack
        try func.store(.stack, result, int_elem_ty, lhs.offset());
    }

    func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
}

fn store(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, offset: u32) InnerError!void {
    assert(!(lhs != .stack and rhs == .stack));
    const mod = func.bin_file.base.comp.module.?;
    const abi_size = ty.abiSize(mod);
    switch (ty.zigTypeTag(mod)) {
        .ErrorUnion => {
            const pl_ty = ty.errorUnionPayload(mod);
            if (!pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                return func.store(lhs, rhs, Type.anyerror, 0);
            }

            const len = @as(u32, @intCast(abi_size));
            return func.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Optional => {
            if (ty.isPtrLikeOptional(mod)) {
                return func.store(lhs, rhs, Type.usize, 0);
            }
            const pl_ty = ty.optionalChild(mod);
            if (!pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                return func.store(lhs, rhs, Type.u8, 0);
            }
            if (pl_ty.zigTypeTag(mod) == .ErrorSet) {
                return func.store(lhs, rhs, Type.anyerror, 0);
            }

            const len = @as(u32, @intCast(abi_size));
            return func.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Struct, .Array, .Union => if (isByRef(ty, mod)) {
            const len = @as(u32, @intCast(abi_size));
            return func.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Vector => switch (determineSimdStoreStrategy(ty, mod)) {
            .unrolled => {
                const len: u32 = @intCast(abi_size);
                return func.memcpy(lhs, rhs, .{ .imm32 = len });
            },
            .direct => {
                try func.emitWValue(lhs);
                try func.lowerToStack(rhs);
                // TODO: Add helper functions for simd opcodes
                const extra_index: u32 = @intCast(func.mir_extra.items.len);
                // stores as := opcode, offset, alignment (opcode::memarg)
                try func.mir_extra.appendSlice(func.gpa, &[_]u32{
                    std.wasm.simdOpcode(.v128_store),
                    offset + lhs.offset(),
                    @intCast(ty.abiAlignment(mod).toByteUnits() orelse 0),
                });
                return func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });
            },
        },
        .Pointer => {
            if (ty.isSlice(mod)) {
                // store pointer first
                // lower it to the stack so we do not have to store rhs into a local first
                try func.emitWValue(lhs);
                const ptr_local = try func.load(rhs, Type.usize, 0);
                try func.store(.{ .stack = {} }, ptr_local, Type.usize, 0 + lhs.offset());

                // retrieve length from rhs, and store that alongside lhs as well
                try func.emitWValue(lhs);
                const len_local = try func.load(rhs, Type.usize, func.ptrSize());
                try func.store(.{ .stack = {} }, len_local, Type.usize, func.ptrSize() + lhs.offset());
                return;
            }
        },
        .Int, .Float => if (abi_size > 8 and abi_size <= 16) {
            try func.emitWValue(lhs);
            const lsb = try func.load(rhs, Type.u64, 0);
            try func.store(.{ .stack = {} }, lsb, Type.u64, 0 + lhs.offset());

            try func.emitWValue(lhs);
            const msb = try func.load(rhs, Type.u64, 8);
            try func.store(.{ .stack = {} }, msb, Type.u64, 8 + lhs.offset());
            return;
        } else if (abi_size > 16) {
            try func.memcpy(lhs, rhs, .{ .imm32 = @as(u32, @intCast(ty.abiSize(mod))) });
        },
        else => if (abi_size > 8) {
            return func.fail("TODO: `store` for type `{}` with abisize `{d}`", .{
                ty.fmt(func.bin_file.base.comp.module.?),
                abi_size,
            });
        },
    }
    try func.emitWValue(lhs);
    // In this case we're actually interested in storing the stack position
    // into lhs, so we calculate that and emit that instead
    try func.lowerToStack(rhs);

    const valtype = typeToValtype(ty, mod);
    const opcode = buildOpcode(.{
        .valtype1 = valtype,
        .width = @as(u8, @intCast(abi_size * 8)),
        .op = .store,
    });

    // store rhs value at stack pointer's location in memory
    try func.addMemArg(
        Mir.Inst.Tag.fromOpcode(opcode),
        .{
            .offset = offset + lhs.offset(),
            .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
        },
    );
}

fn airLoad(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    const ty = ty_op.ty.toType();
    const ptr_ty = func.typeOf(ty_op.operand);
    const ptr_info = ptr_ty.ptrInfo(mod);

    if (!ty.hasRuntimeBitsIgnoreComptime(mod)) return func.finishAir(inst, .none, &.{ty_op.operand});

    const result = result: {
        if (isByRef(ty, mod)) {
            const new_local = try func.allocStack(ty);
            try func.store(new_local, operand, ty, 0);
            break :result new_local;
        }

        if (ptr_info.packed_offset.host_size == 0) {
            const stack_loaded = try func.load(operand, ty, 0);
            break :result try stack_loaded.toLocal(func, ty);
        }

        // at this point we have a non-natural alignment, we must
        // shift the value to obtain the correct bit.
        const int_elem_ty = try mod.intType(.unsigned, ptr_info.packed_offset.host_size * 8);
        const shift_val = if (ptr_info.packed_offset.host_size <= 4)
            WValue{ .imm32 = ptr_info.packed_offset.bit_offset }
        else if (ptr_info.packed_offset.host_size <= 8)
            WValue{ .imm64 = ptr_info.packed_offset.bit_offset }
        else
            return func.fail("TODO: airLoad where ptr to bitfield exceeds 64 bits", .{});

        const stack_loaded = try func.load(operand, int_elem_ty, 0);
        const shifted = try func.binOp(stack_loaded, shift_val, int_elem_ty, .shr);
        const result = try func.trunc(shifted, ty, int_elem_ty);
        // const wrapped = try func.wrapOperand(shifted, ty);
        break :result try result.toLocal(func, ty);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

/// Loads an operand from the linear memory section.
/// NOTE: Leaves the value on the stack.
fn load(func: *CodeGen, operand: WValue, ty: Type, offset: u32) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    // load local's value from memory by its stack position
    try func.emitWValue(operand);

    if (ty.zigTypeTag(mod) == .Vector) {
        // TODO: Add helper functions for simd opcodes
        const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
        // stores as := opcode, offset, alignment (opcode::memarg)
        try func.mir_extra.appendSlice(func.gpa, &[_]u32{
            std.wasm.simdOpcode(.v128_load),
            offset + operand.offset(),
            @intCast(ty.abiAlignment(mod).toByteUnits().?),
        });
        try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });
        return WValue{ .stack = {} };
    }

    const abi_size: u8 = @intCast(ty.abiSize(mod));
    const opcode = buildOpcode(.{
        .valtype1 = typeToValtype(ty, mod),
        .width = abi_size * 8,
        .op = .load,
        .signedness = .unsigned,
    });

    try func.addMemArg(
        Mir.Inst.Tag.fromOpcode(opcode),
        .{
            .offset = offset + operand.offset(),
            .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
        },
    );

    return WValue{ .stack = {} };
}

fn airArg(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const arg_index = func.arg_index;
    const arg = func.args[arg_index];
    const cc = mod.typeToFunc(func.decl.typeOf(mod)).?.cc;
    const arg_ty = func.typeOfIndex(inst);
    if (cc == .C) {
        const arg_classes = abi.classifyType(arg_ty, mod);
        for (arg_classes) |class| {
            if (class != .none) {
                func.arg_index += 1;
            }
        }

        // When we have an argument that's passed using more than a single parameter,
        // we combine them into a single stack value
        if (arg_classes[0] == .direct and arg_classes[1] == .direct) {
            if (arg_ty.zigTypeTag(mod) != .Int and arg_ty.zigTypeTag(mod) != .Float) {
                return func.fail(
                    "TODO: Implement C-ABI argument for type '{}'",
                    .{arg_ty.fmt(func.bin_file.base.comp.module.?)},
                );
            }
            const result = try func.allocStack(arg_ty);
            try func.store(result, arg, Type.u64, 0);
            try func.store(result, func.args[arg_index + 1], Type.u64, 8);
            return func.finishAir(inst, result, &.{});
        }
    } else {
        func.arg_index += 1;
    }

    switch (func.debug_output) {
        .dwarf => |dwarf| {
            const src_index = func.air.instructions.items(.data)[@intFromEnum(inst)].arg.src_index;
            const name = mod.getParamName(func.func_index, src_index);
            try dwarf.genArgDbgInfo(name, arg_ty, mod.funcOwnerDeclIndex(func.func_index), .{
                .wasm_local = arg.local.value,
            });
        },
        else => {},
    }

    func.finishAir(inst, arg, &.{});
}

fn airBinOp(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const lhs_ty = func.typeOf(bin_op.lhs);
    const rhs_ty = func.typeOf(bin_op.rhs);

    // For certain operations, such as shifting, the types are different.
    // When converting this to a WebAssembly type, they *must* match to perform
    // an operation. For this reason we verify if the WebAssembly type is different, in which
    // case we first coerce the operands to the same type before performing the operation.
    // For big integers we can ignore this as we will call into compiler-rt which handles this.
    const result = switch (op) {
        .shr, .shl => res: {
            const lhs_wasm_bits = toWasmBits(@as(u16, @intCast(lhs_ty.bitSize(mod)))) orelse {
                return func.fail("TODO: implement '{s}' for types larger than 128 bits", .{@tagName(op)});
            };
            const rhs_wasm_bits = toWasmBits(@as(u16, @intCast(rhs_ty.bitSize(mod)))).?;
            const new_rhs = if (lhs_wasm_bits != rhs_wasm_bits and lhs_wasm_bits != 128) blk: {
                const tmp = try func.intcast(rhs, rhs_ty, lhs_ty);
                break :blk try tmp.toLocal(func, lhs_ty);
            } else rhs;
            const stack_result = try func.binOp(lhs, new_rhs, lhs_ty, op);
            break :res try stack_result.toLocal(func, lhs_ty);
        },
        else => res: {
            const stack_result = try func.binOp(lhs, rhs, lhs_ty, op);
            break :res try stack_result.toLocal(func, lhs_ty);
        },
    };

    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

/// Performs a binary operation on the given `WValue`'s
/// NOTE: THis leaves the value on top of the stack.
fn binOp(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, op: Op) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(!(lhs != .stack and rhs == .stack));

    if (ty.isAnyFloat()) {
        const float_op = FloatOp.fromOp(op);
        return func.floatOp(float_op, ty, &.{ lhs, rhs });
    }

    if (isByRef(ty, mod)) {
        if (ty.zigTypeTag(mod) == .Int) {
            return func.binOpBigInt(lhs, rhs, ty, op);
        } else {
            return func.fail(
                "TODO: Implement binary operation for type: {}",
                .{ty.fmt(func.bin_file.base.comp.module.?)},
            );
        }
    }

    const opcode: wasm.Opcode = buildOpcode(.{
        .op = op,
        .valtype1 = typeToValtype(ty, mod),
        .signedness = if (ty.isSignedInt(mod)) .signed else .unsigned,
    });
    try func.emitWValue(lhs);
    try func.emitWValue(rhs);

    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    return WValue{ .stack = {} };
}

fn binOpBigInt(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, op: Op) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const int_info = ty.intInfo(mod);
    if (int_info.bits > 128) {
        return func.fail("TODO: Implement binary operation for big integers larger than 128 bits", .{});
    }

    switch (op) {
        .mul => return func.callIntrinsic("__multi3", &.{ ty.toIntern(), ty.toIntern() }, ty, &.{ lhs, rhs }),
        .div => switch (int_info.signedness) {
            .signed => return func.callIntrinsic("__udivti3", &.{ ty.toIntern(), ty.toIntern() }, ty, &.{ lhs, rhs }),
            .unsigned => return func.callIntrinsic("__divti3", &.{ ty.toIntern(), ty.toIntern() }, ty, &.{ lhs, rhs }),
        },
        .rem => return func.callIntrinsic("__umodti3", &.{ ty.toIntern(), ty.toIntern() }, ty, &.{ lhs, rhs }),
        .shr => return func.callIntrinsic("__lshrti3", &.{ ty.toIntern(), .i32_type }, ty, &.{ lhs, rhs }),
        .shl => return func.callIntrinsic("__ashlti3", &.{ ty.toIntern(), .i32_type }, ty, &.{ lhs, rhs }),
        .@"and", .@"or", .xor => {
            const result = try func.allocStack(ty);
            try func.emitWValue(result);
            const lhs_high_bit = try func.load(lhs, Type.u64, 0);
            const rhs_high_bit = try func.load(rhs, Type.u64, 0);
            const op_high_bit = try func.binOp(lhs_high_bit, rhs_high_bit, Type.u64, op);
            try func.store(.stack, op_high_bit, Type.u64, result.offset());

            try func.emitWValue(result);
            const lhs_low_bit = try func.load(lhs, Type.u64, 8);
            const rhs_low_bit = try func.load(rhs, Type.u64, 8);
            const op_low_bit = try func.binOp(lhs_low_bit, rhs_low_bit, Type.u64, op);
            try func.store(.stack, op_low_bit, Type.u64, result.offset() + 8);
            return result;
        },
        .add, .sub => {
            const result = try func.allocStack(ty);
            var lhs_high_bit = try (try func.load(lhs, Type.u64, 0)).toLocal(func, Type.u64);
            defer lhs_high_bit.free(func);
            var rhs_high_bit = try (try func.load(rhs, Type.u64, 0)).toLocal(func, Type.u64);
            defer rhs_high_bit.free(func);
            var high_op_res = try (try func.binOp(lhs_high_bit, rhs_high_bit, Type.u64, op)).toLocal(func, Type.u64);
            defer high_op_res.free(func);

            const lhs_low_bit = try func.load(lhs, Type.u64, 8);
            const rhs_low_bit = try func.load(rhs, Type.u64, 8);
            const low_op_res = try func.binOp(lhs_low_bit, rhs_low_bit, Type.u64, op);

            const lt = if (op == .add) blk: {
                break :blk try func.cmp(high_op_res, rhs_high_bit, Type.u64, .lt);
            } else if (op == .sub) blk: {
                break :blk try func.cmp(lhs_high_bit, rhs_high_bit, Type.u64, .lt);
            } else unreachable;
            const tmp = try func.intcast(lt, Type.u32, Type.u64);
            var tmp_op = try (try func.binOp(low_op_res, tmp, Type.u64, op)).toLocal(func, Type.u64);
            defer tmp_op.free(func);

            try func.store(result, high_op_res, Type.u64, 0);
            try func.store(result, tmp_op, Type.u64, 8);
            return result;
        },
        else => return func.fail("TODO: Implement binary operation for big integers: '{s}'", .{@tagName(op)}),
    }
}

const FloatOp = enum {
    add,
    ceil,
    cos,
    div,
    exp,
    exp2,
    fabs,
    floor,
    fma,
    fmax,
    fmin,
    fmod,
    log,
    log10,
    log2,
    mul,
    neg,
    round,
    sin,
    sqrt,
    sub,
    tan,
    trunc,

    pub fn fromOp(op: Op) FloatOp {
        return switch (op) {
            .add => .add,
            .ceil => .ceil,
            .div => .div,
            .abs => .fabs,
            .floor => .floor,
            .max => .fmax,
            .min => .fmin,
            .mul => .mul,
            .neg => .neg,
            .nearest => .round,
            .sqrt => .sqrt,
            .sub => .sub,
            .trunc => .trunc,
            else => unreachable,
        };
    }

    pub fn toOp(float_op: FloatOp) ?Op {
        return switch (float_op) {
            .add => .add,
            .ceil => .ceil,
            .div => .div,
            .fabs => .abs,
            .floor => .floor,
            .fmax => .max,
            .fmin => .min,
            .mul => .mul,
            .neg => .neg,
            .round => .nearest,
            .sqrt => .sqrt,
            .sub => .sub,
            .trunc => .trunc,

            .cos,
            .exp,
            .exp2,
            .fma,
            .fmod,
            .log,
            .log10,
            .log2,
            .sin,
            .tan,
            => null,
        };
    }
};

fn airAbs(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    const ty = func.typeOf(ty_op.operand);
    const scalar_ty = ty.scalarType(mod);

    switch (scalar_ty.zigTypeTag(mod)) {
        .Int => if (ty.zigTypeTag(mod) == .Vector) {
            return func.fail("TODO implement airAbs for {}", .{ty.fmt(mod)});
        } else {
            const int_bits = ty.intInfo(mod).bits;
            const wasm_bits = toWasmBits(int_bits) orelse {
                return func.fail("TODO: airAbs for signed integers larger than '{d}' bits", .{int_bits});
            };

            const op = try operand.toLocal(func, ty);

            try func.emitWValue(op);
            switch (wasm_bits) {
                32 => {
                    if (wasm_bits != int_bits) {
                        try func.addImm32(wasm_bits - int_bits);
                        try func.addTag(.i32_shl);
                    }
                    try func.addImm32(31);
                    try func.addTag(.i32_shr_s);

                    const tmp = try func.allocLocal(ty);
                    try func.addLabel(.local_tee, tmp.local.value);

                    try func.emitWValue(op);
                    try func.addTag(.i32_xor);
                    try func.emitWValue(tmp);
                    try func.addTag(.i32_sub);

                    if (int_bits != wasm_bits) {
                        try func.emitWValue(WValue{ .imm32 = (@as(u32, 1) << @intCast(int_bits)) - 1 });
                        try func.addTag(.i32_and);
                    }
                },
                64 => {
                    if (wasm_bits != int_bits) {
                        try func.addImm64(wasm_bits - int_bits);
                        try func.addTag(.i64_shl);
                    }
                    try func.addImm64(63);
                    try func.addTag(.i64_shr_s);

                    const tmp = try func.allocLocal(ty);
                    try func.addLabel(.local_tee, tmp.local.value);

                    try func.emitWValue(op);
                    try func.addTag(.i64_xor);
                    try func.emitWValue(tmp);
                    try func.addTag(.i64_sub);

                    if (int_bits != wasm_bits) {
                        try func.emitWValue(WValue{ .imm64 = (@as(u64, 1) << @intCast(int_bits)) - 1 });
                        try func.addTag(.i64_and);
                    }
                },
                else => return func.fail("TODO: Implement airAbs for {}", .{ty.fmt(mod)}),
            }

            const result = try (WValue{ .stack = {} }).toLocal(func, ty);
            func.finishAir(inst, result, &.{ty_op.operand});
        },
        .Float => {
            const result = try (try func.floatOp(.fabs, ty, &.{operand})).toLocal(func, ty);
            func.finishAir(inst, result, &.{ty_op.operand});
        },
        else => unreachable,
    }
}

fn airUnaryFloatOp(func: *CodeGen, inst: Air.Inst.Index, op: FloatOp) InnerError!void {
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const ty = func.typeOf(un_op);

    const result = try (try func.floatOp(op, ty, &.{operand})).toLocal(func, ty);
    func.finishAir(inst, result, &.{un_op});
}

fn floatOp(func: *CodeGen, float_op: FloatOp, ty: Type, args: []const WValue) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement floatOps for vectors", .{});
    }

    const float_bits = ty.floatBits(func.target);

    if (float_op == .neg) {
        return func.floatNeg(ty, args[0]);
    }

    if (float_bits == 32 or float_bits == 64) {
        if (float_op.toOp()) |op| {
            for (args) |operand| {
                try func.emitWValue(operand);
            }
            const opcode = buildOpcode(.{ .op = op, .valtype1 = typeToValtype(ty, mod) });
            try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
            return .stack;
        }
    }

    var fn_name_buf: [64]u8 = undefined;
    const fn_name = switch (float_op) {
        .add,
        .sub,
        .div,
        .mul,
        => std.fmt.bufPrint(&fn_name_buf, "__{s}{s}f3", .{
            @tagName(float_op), target_util.compilerRtFloatAbbrev(float_bits),
        }) catch unreachable,

        .ceil,
        .cos,
        .exp,
        .exp2,
        .fabs,
        .floor,
        .fma,
        .fmax,
        .fmin,
        .fmod,
        .log,
        .log10,
        .log2,
        .round,
        .sin,
        .sqrt,
        .tan,
        .trunc,
        => std.fmt.bufPrint(&fn_name_buf, "{s}{s}{s}", .{
            target_util.libcFloatPrefix(float_bits), @tagName(float_op), target_util.libcFloatSuffix(float_bits),
        }) catch unreachable,
        .neg => unreachable, // handled above
    };

    // fma requires three operands
    var param_types_buffer: [3]InternPool.Index = .{ ty.ip_index, ty.ip_index, ty.ip_index };
    const param_types = param_types_buffer[0..args.len];
    return func.callIntrinsic(fn_name, param_types, ty, args);
}

/// NOTE: The result value remains on top of the stack.
fn floatNeg(func: *CodeGen, ty: Type, arg: WValue) InnerError!WValue {
    const float_bits = ty.floatBits(func.target);
    switch (float_bits) {
        16 => {
            try func.emitWValue(arg);
            try func.addImm32(std.math.minInt(i16));
            try func.addTag(.i32_xor);
            return .stack;
        },
        32, 64 => {
            try func.emitWValue(arg);
            const val_type: wasm.Valtype = if (float_bits == 32) .f32 else .f64;
            const opcode = buildOpcode(.{ .op = .neg, .valtype1 = val_type });
            try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
            return .stack;
        },
        80, 128 => {
            const result = try func.allocStack(ty);
            try func.emitWValue(result);
            try func.emitWValue(arg);
            try func.addMemArg(.i64_load, .{ .offset = 0 + arg.offset(), .alignment = 2 });
            try func.addMemArg(.i64_store, .{ .offset = 0 + result.offset(), .alignment = 2 });

            try func.emitWValue(result);
            try func.emitWValue(arg);
            try func.addMemArg(.i64_load, .{ .offset = 8 + arg.offset(), .alignment = 2 });

            if (float_bits == 80) {
                try func.addImm64(0x8000);
                try func.addTag(.i64_xor);
                try func.addMemArg(.i64_store16, .{ .offset = 8 + result.offset(), .alignment = 2 });
            } else {
                try func.addImm64(0x8000000000000000);
                try func.addTag(.i64_xor);
                try func.addMemArg(.i64_store, .{ .offset = 8 + result.offset(), .alignment = 2 });
            }
            return result;
        },
        else => unreachable,
    }
}

fn airWrapBinOp(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const lhs_ty = func.typeOf(bin_op.lhs);
    const rhs_ty = func.typeOf(bin_op.rhs);

    if (lhs_ty.zigTypeTag(mod) == .Vector or rhs_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement wrapping arithmetic for vectors", .{});
    }

    // For certain operations, such as shifting, the types are different.
    // When converting this to a WebAssembly type, they *must* match to perform
    // an operation. For this reason we verify if the WebAssembly type is different, in which
    // case we first coerce the operands to the same type before performing the operation.
    // For big integers we can ignore this as we will call into compiler-rt which handles this.
    const result = switch (op) {
        .shr, .shl => res: {
            const lhs_wasm_bits = toWasmBits(@as(u16, @intCast(lhs_ty.bitSize(mod)))) orelse {
                return func.fail("TODO: implement '{s}' for types larger than 128 bits", .{@tagName(op)});
            };
            const rhs_wasm_bits = toWasmBits(@as(u16, @intCast(rhs_ty.bitSize(mod)))).?;
            const new_rhs = if (lhs_wasm_bits != rhs_wasm_bits and lhs_wasm_bits != 128) blk: {
                const tmp = try func.intcast(rhs, rhs_ty, lhs_ty);
                break :blk try tmp.toLocal(func, lhs_ty);
            } else rhs;
            const stack_result = try func.wrapBinOp(lhs, new_rhs, lhs_ty, op);
            break :res try stack_result.toLocal(func, lhs_ty);
        },
        else => res: {
            const stack_result = try func.wrapBinOp(lhs, rhs, lhs_ty, op);
            break :res try stack_result.toLocal(func, lhs_ty);
        },
    };

    return func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

/// Performs a wrapping binary operation.
/// Asserts rhs is not a stack value when lhs also isn't.
/// NOTE: Leaves the result on the stack when its Type is <= 64 bits
fn wrapBinOp(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, op: Op) InnerError!WValue {
    const bin_local = try func.binOp(lhs, rhs, ty, op);
    return func.wrapOperand(bin_local, ty);
}

/// Wraps an operand based on a given type's bitsize.
/// Asserts `Type` is <= 128 bits.
/// NOTE: When the Type is <= 64 bits, leaves the value on top of the stack.
fn wrapOperand(func: *CodeGen, operand: WValue, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(ty.abiSize(mod) <= 16);
    const bitsize = @as(u16, @intCast(ty.bitSize(mod)));
    const wasm_bits = toWasmBits(bitsize) orelse {
        return func.fail("TODO: Implement wrapOperand for bitsize '{d}'", .{bitsize});
    };

    if (wasm_bits == bitsize) return operand;

    if (wasm_bits == 128) {
        assert(operand != .stack);
        const lsb = try func.load(operand, Type.u64, 8);

        const result_ptr = try func.allocStack(ty);
        try func.emitWValue(result_ptr);
        try func.store(.{ .stack = {} }, lsb, Type.u64, 8 + result_ptr.offset());
        const result = (@as(u64, 1) << @as(u6, @intCast(64 - (wasm_bits - bitsize)))) - 1;
        try func.emitWValue(result_ptr);
        _ = try func.load(operand, Type.u64, 0);
        try func.addImm64(result);
        try func.addTag(.i64_and);
        try func.addMemArg(.i64_store, .{ .offset = result_ptr.offset(), .alignment = 8 });
        return result_ptr;
    }

    const result = (@as(u64, 1) << @as(u6, @intCast(bitsize))) - 1;
    try func.emitWValue(operand);
    if (bitsize <= 32) {
        try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(result)))));
        try func.addTag(.i32_and);
    } else if (bitsize <= 64) {
        try func.addImm64(result);
        try func.addTag(.i64_and);
    } else unreachable;

    return WValue{ .stack = {} };
}

fn lowerPtr(func: *CodeGen, ptr_val: InternPool.Index, prev_offset: u64) InnerError!WValue {
    const zcu = func.bin_file.base.comp.module.?;
    const ptr = zcu.intern_pool.indexToKey(ptr_val).ptr;
    const offset: u64 = prev_offset + ptr.byte_offset;
    return switch (ptr.base_addr) {
        .decl => |decl| return func.lowerDeclRefValue(decl, @intCast(offset)),
        .anon_decl => |ad| return func.lowerAnonDeclRef(ad, @intCast(offset)),
        .int => return func.lowerConstant(try zcu.intValue(Type.usize, offset), Type.usize),
        .eu_payload => return func.fail("Wasm TODO: lower error union payload pointer", .{}),
        .opt_payload => |opt_ptr| return func.lowerPtr(opt_ptr, offset),
        .field => |field| {
            const base_ptr = Value.fromInterned(field.base);
            const base_ty = base_ptr.typeOf(zcu).childType(zcu);
            const field_off: u64 = switch (base_ty.zigTypeTag(zcu)) {
                .Pointer => off: {
                    assert(base_ty.isSlice(zcu));
                    break :off switch (field.index) {
                        Value.slice_ptr_index => 0,
                        Value.slice_len_index => @divExact(zcu.getTarget().ptrBitWidth(), 8),
                        else => unreachable,
                    };
                },
                .Struct => switch (base_ty.containerLayout(zcu)) {
                    .auto => base_ty.structFieldOffset(@intCast(field.index), zcu),
                    .@"extern", .@"packed" => unreachable,
                },
                .Union => switch (base_ty.containerLayout(zcu)) {
                    .auto => off: {
                        // Keep in sync with the `un` case of `generateSymbol`.
                        const layout = base_ty.unionGetLayout(zcu);
                        if (layout.payload_size == 0) break :off 0;
                        if (layout.tag_size == 0) break :off 0;
                        if (layout.tag_align.compare(.gte, layout.payload_align)) {
                            // Tag first.
                            break :off layout.tag_size;
                        } else {
                            // Payload first.
                            break :off 0;
                        }
                    },
                    .@"extern", .@"packed" => unreachable,
                },
                else => unreachable,
            };
            return func.lowerPtr(field.base, offset + field_off);
        },
        .arr_elem, .comptime_field, .comptime_alloc => unreachable,
    };
}

fn lowerAnonDeclRef(
    func: *CodeGen,
    anon_decl: InternPool.Key.Ptr.BaseAddr.AnonDecl,
    offset: u32,
) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const decl_val = anon_decl.val;
    const ty = Type.fromInterned(mod.intern_pool.typeOf(decl_val));

    const is_fn_body = ty.zigTypeTag(mod) == .Fn;
    if (!is_fn_body and !ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return WValue{ .imm32 = 0xaaaaaaaa };
    }

    const decl_align = mod.intern_pool.indexToKey(anon_decl.orig_ty).ptr_type.flags.alignment;
    const res = try func.bin_file.lowerAnonDecl(decl_val, decl_align, func.decl.srcLoc(mod));
    switch (res) {
        .ok => {},
        .fail => |em| {
            func.err_msg = em;
            return error.CodegenFail;
        },
    }
    const target_atom_index = func.bin_file.zigObjectPtr().?.anon_decls.get(decl_val).?;
    const target_sym_index = @intFromEnum(func.bin_file.getAtom(target_atom_index).sym_index);
    if (is_fn_body) {
        return WValue{ .function_index = target_sym_index };
    } else if (offset == 0) {
        return WValue{ .memory = target_sym_index };
    } else return WValue{ .memory_offset = .{ .pointer = target_sym_index, .offset = offset } };
}

fn lowerDeclRefValue(func: *CodeGen, decl_index: InternPool.DeclIndex, offset: u32) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;

    const decl = mod.declPtr(decl_index);
    // check if decl is an alias to a function, in which case we
    // want to lower the actual decl, rather than the alias itself.
    if (decl.val.getFunction(mod)) |func_val| {
        if (func_val.owner_decl != decl_index) {
            return func.lowerDeclRefValue(func_val.owner_decl, offset);
        }
    } else if (decl.val.getExternFunc(mod)) |func_val| {
        if (func_val.decl != decl_index) {
            return func.lowerDeclRefValue(func_val.decl, offset);
        }
    }
    const decl_ty = decl.typeOf(mod);
    if (decl_ty.zigTypeTag(mod) != .Fn and !decl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return WValue{ .imm32 = 0xaaaaaaaa };
    }

    const atom_index = try func.bin_file.getOrCreateAtomForDecl(decl_index);
    const atom = func.bin_file.getAtom(atom_index);

    const target_sym_index = @intFromEnum(atom.sym_index);
    if (decl_ty.zigTypeTag(mod) == .Fn) {
        return WValue{ .function_index = target_sym_index };
    } else if (offset == 0) {
        return WValue{ .memory = target_sym_index };
    } else return WValue{ .memory_offset = .{ .pointer = target_sym_index, .offset = offset } };
}

/// Converts a signed integer to its 2's complement form and returns
/// an unsigned integer instead.
/// Asserts bitsize <= 64
fn toTwosComplement(value: anytype, bits: u7) std.meta.Int(.unsigned, @typeInfo(@TypeOf(value)).Int.bits) {
    const T = @TypeOf(value);
    comptime assert(@typeInfo(T) == .Int);
    comptime assert(@typeInfo(T).Int.signedness == .signed);
    assert(bits <= 64);
    const WantedT = std.meta.Int(.unsigned, @typeInfo(T).Int.bits);
    if (value >= 0) return @as(WantedT, @bitCast(value));
    const max_value = @as(u64, @intCast((@as(u65, 1) << bits) - 1));
    const flipped = @as(T, @intCast((~-@as(i65, value)) + 1));
    const result = @as(WantedT, @bitCast(flipped)) & max_value;
    return @as(WantedT, @intCast(result));
}

/// This function is intended to assert that `isByRef` returns `false` for `ty`.
/// However such an assertion fails on the behavior tests currently.
fn lowerConstant(func: *CodeGen, val: Value, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    // TODO: enable this assertion
    //assert(!isByRef(ty, mod));
    const ip = &mod.intern_pool;
    if (val.isUndefDeep(mod)) return func.emitUndefined(ty);

    switch (ip.indexToKey(val.ip_index)) {
        .int_type,
        .ptr_type,
        .array_type,
        .vector_type,
        .opt_type,
        .anyframe_type,
        .error_union_type,
        .simple_type,
        .struct_type,
        .anon_struct_type,
        .union_type,
        .opaque_type,
        .enum_type,
        .func_type,
        .error_set_type,
        .inferred_error_set_type,
        => unreachable, // types, not values

        .undef => unreachable, // handled above
        .simple_value => |simple_value| switch (simple_value) {
            .undefined,
            .void,
            .null,
            .empty_struct,
            .@"unreachable",
            .generic_poison,
            => unreachable, // non-runtime values
            .false, .true => return WValue{ .imm32 = switch (simple_value) {
                .false => 0,
                .true => 1,
                else => unreachable,
            } },
        },
        .variable,
        .extern_func,
        .func,
        .enum_literal,
        .empty_enum_value,
        => unreachable, // non-runtime values
        .int => {
            const int_info = ty.intInfo(mod);
            switch (int_info.signedness) {
                .signed => switch (int_info.bits) {
                    0...32 => return WValue{ .imm32 = @as(u32, @intCast(toTwosComplement(
                        val.toSignedInt(mod),
                        @as(u6, @intCast(int_info.bits)),
                    ))) },
                    33...64 => return WValue{ .imm64 = toTwosComplement(
                        val.toSignedInt(mod),
                        @as(u7, @intCast(int_info.bits)),
                    ) },
                    else => unreachable,
                },
                .unsigned => switch (int_info.bits) {
                    0...32 => return WValue{ .imm32 = @as(u32, @intCast(val.toUnsignedInt(mod))) },
                    33...64 => return WValue{ .imm64 = val.toUnsignedInt(mod) },
                    else => unreachable,
                },
            }
        },
        .err => |err| {
            const int = try mod.getErrorValue(err.name);
            return WValue{ .imm32 = int };
        },
        .error_union => |error_union| {
            const err_int_ty = try mod.errorIntType();
            const err_ty, const err_val = switch (error_union.val) {
                .err_name => |err_name| .{
                    ty.errorUnionSet(mod),
                    Value.fromInterned((try mod.intern(.{ .err = .{
                        .ty = ty.errorUnionSet(mod).toIntern(),
                        .name = err_name,
                    } }))),
                },
                .payload => .{
                    err_int_ty,
                    try mod.intValue(err_int_ty, 0),
                },
            };
            const payload_type = ty.errorUnionPayload(mod);
            if (!payload_type.hasRuntimeBitsIgnoreComptime(mod)) {
                // We use the error type directly as the type.
                return func.lowerConstant(err_val, err_ty);
            }

            return func.fail("Wasm TODO: lowerConstant error union with non-zero-bit payload type", .{});
        },
        .enum_tag => |enum_tag| {
            const int_tag_ty = ip.typeOf(enum_tag.int);
            return func.lowerConstant(Value.fromInterned(enum_tag.int), Type.fromInterned(int_tag_ty));
        },
        .float => |float| switch (float.storage) {
            .f16 => |f16_val| return WValue{ .imm32 = @as(u16, @bitCast(f16_val)) },
            .f32 => |f32_val| return WValue{ .float32 = f32_val },
            .f64 => |f64_val| return WValue{ .float64 = f64_val },
            else => unreachable,
        },
        .slice => |slice| {
            var ptr = ip.indexToKey(slice.ptr).ptr;
            const owner_decl = while (true) switch (ptr.base_addr) {
                .decl => |decl| break decl,
                .int, .anon_decl => return func.fail("Wasm TODO: lower slice where ptr is not owned by decl", .{}),
                .opt_payload, .eu_payload => |base| ptr = ip.indexToKey(base).ptr,
                .field => |base_index| ptr = ip.indexToKey(base_index.base).ptr,
                .arr_elem, .comptime_field, .comptime_alloc => unreachable,
            };
            return .{ .memory = try func.bin_file.lowerUnnamedConst(val, owner_decl) };
        },
        .ptr => return func.lowerPtr(val.toIntern(), 0),
        .opt => if (ty.optionalReprIsPayload(mod)) {
            const pl_ty = ty.optionalChild(mod);
            if (val.optionalValue(mod)) |payload| {
                return func.lowerConstant(payload, pl_ty);
            } else {
                return WValue{ .imm32 = 0 };
            }
        } else {
            return WValue{ .imm32 = @intFromBool(!val.isNull(mod)) };
        },
        .aggregate => switch (ip.indexToKey(ty.ip_index)) {
            .array_type => return func.fail("Wasm TODO: LowerConstant for {}", .{ty.fmt(mod)}),
            .vector_type => {
                assert(determineSimdStoreStrategy(ty, mod) == .direct);
                var buf: [16]u8 = undefined;
                val.writeToMemory(ty, mod, &buf) catch unreachable;
                return func.storeSimdImmd(buf);
            },
            .struct_type => {
                const struct_type = ip.loadStructType(ty.toIntern());
                // non-packed structs are not handled in this function because they
                // are by-ref types.
                assert(struct_type.layout == .@"packed");
                var buf: [8]u8 = .{0} ** 8; // zero the buffer so we do not read 0xaa as integer
                val.writeToPackedMemory(ty, mod, &buf, 0) catch unreachable;
                const backing_int_ty = Type.fromInterned(struct_type.backingIntType(ip).*);
                const int_val = try mod.intValue(
                    backing_int_ty,
                    mem.readInt(u64, &buf, .little),
                );
                return func.lowerConstant(int_val, backing_int_ty);
            },
            else => unreachable,
        },
        .un => |un| {
            // in this case we have a packed union which will not be passed by reference.
            const constant_ty = if (un.tag == .none)
                try ty.unionBackingType(mod)
            else field_ty: {
                const union_obj = mod.typeToUnion(ty).?;
                const field_index = mod.unionTagFieldIndex(union_obj, Value.fromInterned(un.tag)).?;
                break :field_ty Type.fromInterned(union_obj.field_types.get(ip)[field_index]);
            };
            return func.lowerConstant(Value.fromInterned(un.val), constant_ty);
        },
        .memoized_call => unreachable,
    }
}

/// Stores the value as a 128bit-immediate value by storing it inside
/// the list and returning the index into this list as `WValue`.
fn storeSimdImmd(func: *CodeGen, value: [16]u8) !WValue {
    const index = @as(u32, @intCast(func.simd_immediates.items.len));
    try func.simd_immediates.append(func.gpa, value);
    return WValue{ .imm128 = index };
}

fn emitUndefined(func: *CodeGen, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    switch (ty.zigTypeTag(mod)) {
        .Bool, .ErrorSet => return WValue{ .imm32 = 0xaaaaaaaa },
        .Int, .Enum => switch (ty.intInfo(mod).bits) {
            0...32 => return WValue{ .imm32 = 0xaaaaaaaa },
            33...64 => return WValue{ .imm64 = 0xaaaaaaaaaaaaaaaa },
            else => unreachable,
        },
        .Float => switch (ty.floatBits(func.target)) {
            16 => return WValue{ .imm32 = 0xaaaaaaaa },
            32 => return WValue{ .float32 = @as(f32, @bitCast(@as(u32, 0xaaaaaaaa))) },
            64 => return WValue{ .float64 = @as(f64, @bitCast(@as(u64, 0xaaaaaaaaaaaaaaaa))) },
            else => unreachable,
        },
        .Pointer => switch (func.arch()) {
            .wasm32 => return WValue{ .imm32 = 0xaaaaaaaa },
            .wasm64 => return WValue{ .imm64 = 0xaaaaaaaaaaaaaaaa },
            else => unreachable,
        },
        .Optional => {
            const pl_ty = ty.optionalChild(mod);
            if (ty.optionalReprIsPayload(mod)) {
                return func.emitUndefined(pl_ty);
            }
            return WValue{ .imm32 = 0xaaaaaaaa };
        },
        .ErrorUnion => {
            return WValue{ .imm32 = 0xaaaaaaaa };
        },
        .Struct => {
            const packed_struct = mod.typeToPackedStruct(ty).?;
            return func.emitUndefined(Type.fromInterned(packed_struct.backingIntType(ip).*));
        },
        else => return func.fail("Wasm TODO: emitUndefined for type: {}\n", .{ty.zigTypeTag(mod)}),
    }
}

/// Returns a `Value` as a signed 32 bit value.
/// It's illegal to provide a value with a type that cannot be represented
/// as an integer value.
fn valueAsI32(func: *const CodeGen, val: Value, ty: Type) i32 {
    const mod = func.bin_file.base.comp.module.?;

    switch (val.ip_index) {
        .none => {},
        .bool_true => return 1,
        .bool_false => return 0,
        else => return switch (mod.intern_pool.indexToKey(val.ip_index)) {
            .enum_tag => |enum_tag| intIndexAsI32(&mod.intern_pool, enum_tag.int, mod),
            .int => |int| intStorageAsI32(int.storage, mod),
            .ptr => |ptr| {
                assert(ptr.base_addr == .int);
                return @intCast(ptr.byte_offset);
            },
            .err => |err| @as(i32, @bitCast(@as(Module.ErrorInt, @intCast(mod.global_error_set.getIndex(err.name).?)))),
            else => unreachable,
        },
    }

    return switch (ty.zigTypeTag(mod)) {
        .ErrorSet => @as(i32, @bitCast(val.getErrorInt(mod))),
        else => unreachable, // Programmer called this function for an illegal type
    };
}

fn intIndexAsI32(ip: *const InternPool, int: InternPool.Index, mod: *Module) i32 {
    return intStorageAsI32(ip.indexToKey(int).int.storage, mod);
}

fn intStorageAsI32(storage: InternPool.Key.Int.Storage, mod: *Module) i32 {
    return switch (storage) {
        .i64 => |x| @as(i32, @intCast(x)),
        .u64 => |x| @as(i32, @bitCast(@as(u32, @intCast(x)))),
        .big_int => unreachable,
        .lazy_align => |ty| @as(i32, @bitCast(@as(u32, @intCast(Type.fromInterned(ty).abiAlignment(mod).toByteUnits() orelse 0)))),
        .lazy_size => |ty| @as(i32, @bitCast(@as(u32, @intCast(Type.fromInterned(ty).abiSize(mod))))),
    };
}

fn airBlock(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Block, ty_pl.payload);
    try func.lowerBlock(inst, ty_pl.ty.toType(), @ptrCast(func.air.extra[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(func: *CodeGen, inst: Air.Inst.Index, block_ty: Type, body: []const Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const wasm_block_ty = genBlockType(block_ty, mod);

    // if wasm_block_ty is non-empty, we create a register to store the temporary value
    const block_result: WValue = if (wasm_block_ty != wasm.block_empty) blk: {
        const ty: Type = if (isByRef(block_ty, mod)) Type.u32 else block_ty;
        break :blk try func.ensureAllocLocal(ty); // make sure it's a clean local as it may never get overwritten
    } else WValue.none;

    try func.startBlock(.block, wasm.block_empty);
    // Here we set the current block idx, so breaks know the depth to jump
    // to when breaking out.
    try func.blocks.putNoClobber(func.gpa, inst, .{
        .label = func.block_depth,
        .value = block_result,
    });

    try func.genBody(body);
    try func.endBlock();

    const liveness = func.liveness.getBlock(inst);
    try func.currentBranch().values.ensureUnusedCapacity(func.gpa, liveness.deaths.len);

    func.finishAir(inst, block_result, &.{});
}

/// appends a new wasm block to the code section and increases the `block_depth` by 1
fn startBlock(func: *CodeGen, block_tag: wasm.Opcode, valtype: u8) !void {
    func.block_depth += 1;
    try func.addInst(.{
        .tag = Mir.Inst.Tag.fromOpcode(block_tag),
        .data = .{ .block_type = valtype },
    });
}

/// Ends the current wasm block and decreases the `block_depth` by 1
fn endBlock(func: *CodeGen) !void {
    try func.addTag(.end);
    func.block_depth -= 1;
}

fn airLoop(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = func.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(func.air.extra[loop.end..][0..loop.data.body_len]);

    // result type of loop is always 'noreturn', meaning we can always
    // emit the wasm type 'block_empty'.
    try func.startBlock(.loop, wasm.block_empty);
    try func.genBody(body);

    // breaking to the index of a loop block will continue the loop instead
    try func.addLabel(.br, 0);
    try func.endBlock();

    func.finishAir(inst, .none, &.{});
}

fn airCondBr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition = try func.resolveInst(pl_op.operand);
    const extra = func.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(func.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(func.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_condbr = func.liveness.getCondBr(inst);

    // result type is always noreturn, so use `block_empty` as type.
    try func.startBlock(.block, wasm.block_empty);
    // emit the conditional value
    try func.emitWValue(condition);

    // we inserted the block in front of the condition
    // so now check if condition matches. If not, break outside this block
    // and continue with the then codepath
    try func.addLabel(.br_if, 0);

    try func.branches.ensureUnusedCapacity(func.gpa, 2);
    {
        func.branches.appendAssumeCapacity(.{});
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, @as(u32, @intCast(liveness_condbr.else_deaths.len)));
        defer {
            var else_stack = func.branches.pop();
            else_stack.deinit(func.gpa);
        }
        try func.genBody(else_body);
        try func.endBlock();
    }

    // Outer block that matches the condition
    {
        func.branches.appendAssumeCapacity(.{});
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, @as(u32, @intCast(liveness_condbr.then_deaths.len)));
        defer {
            var then_stack = func.branches.pop();
            then_stack.deinit(func.gpa);
        }
        try func.genBody(then_body);
    }

    func.finishAir(inst, .none, &.{});
}

fn airCmp(func: *CodeGen, inst: Air.Inst.Index, op: std.math.CompareOperator) InnerError!void {
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const operand_ty = func.typeOf(bin_op.lhs);
    const result = try (try func.cmp(lhs, rhs, operand_ty, op)).toLocal(func, Type.u32); // comparison result is always 32 bits
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

/// Compares two operands.
/// Asserts rhs is not a stack value when the lhs isn't a stack value either
/// NOTE: This leaves the result on top of the stack, rather than a new local.
fn cmp(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    assert(!(lhs != .stack and rhs == .stack));
    const mod = func.bin_file.base.comp.module.?;
    if (ty.zigTypeTag(mod) == .Optional and !ty.optionalReprIsPayload(mod)) {
        const payload_ty = ty.optionalChild(mod);
        if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            // When we hit this case, we must check the value of optionals
            // that are not pointers. This means first checking against non-null for
            // both lhs and rhs, as well as checking the payload are matching of lhs and rhs
            return func.cmpOptionals(lhs, rhs, ty, op);
        }
    } else if (ty.isAnyFloat()) {
        return func.cmpFloat(ty, lhs, rhs, op);
    } else if (isByRef(ty, mod)) {
        return func.cmpBigInt(lhs, rhs, ty, op);
    }

    const signedness: std.builtin.Signedness = blk: {
        // by default we tell the operand type is unsigned (i.e. bools and enum values)
        if (ty.zigTypeTag(mod) != .Int) break :blk .unsigned;

        // incase of an actual integer, we emit the correct signedness
        break :blk ty.intInfo(mod).signedness;
    };
    const extend_sign = blk: {
        // do we need to extend the sign bit?
        if (signedness != .signed) break :blk false;
        if (op == .eq or op == .neq) break :blk false;
        const int_bits = ty.intInfo(mod).bits;
        const wasm_bits = toWasmBits(int_bits) orelse unreachable;
        break :blk (wasm_bits != int_bits);
    };

    const lhs_wasm = if (extend_sign)
        try func.signExtendInt(lhs, ty)
    else
        lhs;

    const rhs_wasm = if (extend_sign)
        try func.signExtendInt(rhs, ty)
    else
        rhs;

    // ensure that when we compare pointers, we emit
    // the true pointer of a stack value, rather than the stack pointer.
    try func.lowerToStack(lhs_wasm);
    try func.lowerToStack(rhs_wasm);

    const opcode: wasm.Opcode = buildOpcode(.{
        .valtype1 = typeToValtype(ty, mod),
        .op = switch (op) {
            .lt => .lt,
            .lte => .le,
            .eq => .eq,
            .neq => .ne,
            .gte => .ge,
            .gt => .gt,
        },
        .signedness = signedness,
    });
    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    return WValue{ .stack = {} };
}

/// Compares two floats.
/// NOTE: Leaves the result of the comparison on top of the stack.
fn cmpFloat(func: *CodeGen, ty: Type, lhs: WValue, rhs: WValue, cmp_op: std.math.CompareOperator) InnerError!WValue {
    const float_bits = ty.floatBits(func.target);

    const op: Op = switch (cmp_op) {
        .lt => .lt,
        .lte => .le,
        .eq => .eq,
        .neq => .ne,
        .gte => .ge,
        .gt => .gt,
    };

    switch (float_bits) {
        16 => {
            _ = try func.fpext(lhs, Type.f16, Type.f32);
            _ = try func.fpext(rhs, Type.f16, Type.f32);
            const opcode = buildOpcode(.{ .op = op, .valtype1 = .f32 });
            try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
            return .stack;
        },
        32, 64 => {
            try func.emitWValue(lhs);
            try func.emitWValue(rhs);
            const val_type: wasm.Valtype = if (float_bits == 32) .f32 else .f64;
            const opcode = buildOpcode(.{ .op = op, .valtype1 = val_type });
            try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
            return .stack;
        },
        80, 128 => {
            var fn_name_buf: [32]u8 = undefined;
            const fn_name = std.fmt.bufPrint(&fn_name_buf, "__{s}{s}f2", .{
                @tagName(op), target_util.compilerRtFloatAbbrev(float_bits),
            }) catch unreachable;

            const result = try func.callIntrinsic(fn_name, &.{ ty.ip_index, ty.ip_index }, Type.bool, &.{ lhs, rhs });
            return func.cmp(result, WValue{ .imm32 = 0 }, Type.i32, cmp_op);
        },
        else => unreachable,
    }
}

fn airCmpVector(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    _ = inst;
    return func.fail("TODO implement airCmpVector for wasm", .{});
}

fn airCmpLtErrorsLen(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const sym_index = try func.bin_file.getGlobalSymbol("__zig_errors_len", null);
    const errors_len = WValue{ .memory = @intFromEnum(sym_index) };

    try func.emitWValue(operand);
    const mod = func.bin_file.base.comp.module.?;
    const err_int_ty = try mod.errorIntType();
    const errors_len_val = try func.load(errors_len, err_int_ty, 0);
    const result = try func.cmp(.stack, errors_len_val, err_int_ty, .lt);

    return func.finishAir(inst, try result.toLocal(func, Type.bool), &.{un_op});
}

fn airBr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const br = func.air.instructions.items(.data)[@intFromEnum(inst)].br;
    const block = func.blocks.get(br.block_inst).?;

    // if operand has codegen bits we should break with a value
    if (func.typeOf(br.operand).hasRuntimeBitsIgnoreComptime(mod)) {
        const operand = try func.resolveInst(br.operand);
        try func.lowerToStack(operand);

        if (block.value != .none) {
            try func.addLabel(.local_set, block.value.local.value);
        }
    }

    // We map every block to its block index.
    // We then determine how far we have to jump to it by subtracting it from current block depth
    const idx: u32 = func.block_depth - block.label;
    try func.addLabel(.br, idx);

    func.finishAir(inst, .none, &.{br.operand});
}

fn airNot(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const operand_ty = func.typeOf(ty_op.operand);
    const mod = func.bin_file.base.comp.module.?;

    const result = result: {
        if (operand_ty.zigTypeTag(mod) == .Bool) {
            try func.emitWValue(operand);
            try func.addTag(.i32_eqz);
            const not_tmp = try func.allocLocal(operand_ty);
            try func.addLabel(.local_set, not_tmp.local.value);
            break :result not_tmp;
        } else {
            const operand_bits = operand_ty.intInfo(mod).bits;
            const wasm_bits = toWasmBits(operand_bits) orelse {
                return func.fail("TODO: Implement binary NOT for integer with bitsize '{d}'", .{operand_bits});
            };

            switch (wasm_bits) {
                32 => {
                    const bin_op = try func.binOp(operand, .{ .imm32 = ~@as(u32, 0) }, operand_ty, .xor);
                    break :result try (try func.wrapOperand(bin_op, operand_ty)).toLocal(func, operand_ty);
                },
                64 => {
                    const bin_op = try func.binOp(operand, .{ .imm64 = ~@as(u64, 0) }, operand_ty, .xor);
                    break :result try (try func.wrapOperand(bin_op, operand_ty)).toLocal(func, operand_ty);
                },
                128 => {
                    const result_ptr = try func.allocStack(operand_ty);
                    try func.emitWValue(result_ptr);
                    const msb = try func.load(operand, Type.u64, 0);
                    const msb_xor = try func.binOp(msb, .{ .imm64 = ~@as(u64, 0) }, Type.u64, .xor);
                    try func.store(.{ .stack = {} }, msb_xor, Type.u64, 0 + result_ptr.offset());

                    try func.emitWValue(result_ptr);
                    const lsb = try func.load(operand, Type.u64, 8);
                    const lsb_xor = try func.binOp(lsb, .{ .imm64 = ~@as(u64, 0) }, Type.u64, .xor);
                    try func.store(result_ptr, lsb_xor, Type.u64, 8 + result_ptr.offset());
                    break :result result_ptr;
                },
                else => unreachable,
            }
        }
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airTrap(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    try func.addTag(.@"unreachable");
    func.finishAir(inst, .none, &.{});
}

fn airBreakpoint(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    // unsupported by wasm itfunc. Can be implemented once we support DWARF
    // for wasm
    try func.addTag(.@"unreachable");
    func.finishAir(inst, .none, &.{});
}

fn airUnreachable(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    try func.addTag(.@"unreachable");
    func.finishAir(inst, .none, &.{});
}

fn airBitcast(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        const operand = try func.resolveInst(ty_op.operand);
        const wanted_ty = func.typeOfIndex(inst);
        const given_ty = func.typeOf(ty_op.operand);
        if (given_ty.isAnyFloat() or wanted_ty.isAnyFloat()) {
            const bitcast_result = try func.bitcast(wanted_ty, given_ty, operand);
            break :result try bitcast_result.toLocal(func, wanted_ty);
        }
        const mod = func.bin_file.base.comp.module.?;
        if (isByRef(given_ty, mod) and !isByRef(wanted_ty, mod)) {
            const loaded_memory = try func.load(operand, wanted_ty, 0);
            break :result try loaded_memory.toLocal(func, wanted_ty);
        }
        if (!isByRef(given_ty, mod) and isByRef(wanted_ty, mod)) {
            const stack_memory = try func.allocStack(wanted_ty);
            try func.store(stack_memory, operand, given_ty, 0);
            break :result stack_memory;
        }
        break :result func.reuseOperand(ty_op.operand, operand);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn bitcast(func: *CodeGen, wanted_ty: Type, given_ty: Type, operand: WValue) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    // if we bitcast a float to or from an integer we must use the 'reinterpret' instruction
    if (!(wanted_ty.isAnyFloat() or given_ty.isAnyFloat())) return operand;
    if (wanted_ty.ip_index == .f16_type or given_ty.ip_index == .f16_type) return operand;
    if (wanted_ty.bitSize(mod) > 64) return operand;
    assert((wanted_ty.isInt(mod) and given_ty.isAnyFloat()) or (wanted_ty.isAnyFloat() and given_ty.isInt(mod)));

    const opcode = buildOpcode(.{
        .op = .reinterpret,
        .valtype1 = typeToValtype(wanted_ty, mod),
        .valtype2 = typeToValtype(given_ty, mod),
    });
    try func.emitWValue(operand);
    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
    return WValue{ .stack = {} };
}

fn airStructFieldPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.StructField, ty_pl.payload);

    const struct_ptr = try func.resolveInst(extra.data.struct_operand);
    const struct_ptr_ty = func.typeOf(extra.data.struct_operand);
    const struct_ty = struct_ptr_ty.childType(mod);
    const result = try func.structFieldPtr(inst, extra.data.struct_operand, struct_ptr, struct_ptr_ty, struct_ty, extra.data.field_index);
    func.finishAir(inst, result, &.{extra.data.struct_operand});
}

fn airStructFieldPtrIndex(func: *CodeGen, inst: Air.Inst.Index, index: u32) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const struct_ptr = try func.resolveInst(ty_op.operand);
    const struct_ptr_ty = func.typeOf(ty_op.operand);
    const struct_ty = struct_ptr_ty.childType(mod);

    const result = try func.structFieldPtr(inst, ty_op.operand, struct_ptr, struct_ptr_ty, struct_ty, index);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn structFieldPtr(
    func: *CodeGen,
    inst: Air.Inst.Index,
    ref: Air.Inst.Ref,
    struct_ptr: WValue,
    struct_ptr_ty: Type,
    struct_ty: Type,
    index: u32,
) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const result_ty = func.typeOfIndex(inst);
    const struct_ptr_ty_info = struct_ptr_ty.ptrInfo(mod);

    const offset = switch (struct_ty.containerLayout(mod)) {
        .@"packed" => switch (struct_ty.zigTypeTag(mod)) {
            .Struct => offset: {
                if (result_ty.ptrInfo(mod).packed_offset.host_size != 0) {
                    break :offset @as(u32, 0);
                }
                const struct_type = mod.typeToStruct(struct_ty).?;
                break :offset @divExact(mod.structPackedFieldBitOffset(struct_type, index) + struct_ptr_ty_info.packed_offset.bit_offset, 8);
            },
            .Union => 0,
            else => unreachable,
        },
        else => struct_ty.structFieldOffset(index, mod),
    };
    // save a load and store when we can simply reuse the operand
    if (offset == 0) {
        return func.reuseOperand(ref, struct_ptr);
    }
    switch (struct_ptr) {
        .stack_offset => |stack_offset| {
            return WValue{ .stack_offset = .{ .value = stack_offset.value + @as(u32, @intCast(offset)), .references = 1 } };
        },
        else => return func.buildPointerOffset(struct_ptr, offset, .new),
    }
}

fn airStructFieldVal(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const struct_field = func.air.extraData(Air.StructField, ty_pl.payload).data;

    const struct_ty = func.typeOf(struct_field.struct_operand);
    const operand = try func.resolveInst(struct_field.struct_operand);
    const field_index = struct_field.field_index;
    const field_ty = struct_ty.structFieldType(field_index, mod);
    if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) return func.finishAir(inst, .none, &.{struct_field.struct_operand});

    const result = switch (struct_ty.containerLayout(mod)) {
        .@"packed" => switch (struct_ty.zigTypeTag(mod)) {
            .Struct => result: {
                const packed_struct = mod.typeToPackedStruct(struct_ty).?;
                const offset = mod.structPackedFieldBitOffset(packed_struct, field_index);
                const backing_ty = Type.fromInterned(packed_struct.backingIntType(ip).*);
                const wasm_bits = toWasmBits(backing_ty.intInfo(mod).bits) orelse {
                    return func.fail("TODO: airStructFieldVal for packed structs larger than 128 bits", .{});
                };
                const const_wvalue = if (wasm_bits == 32)
                    WValue{ .imm32 = offset }
                else if (wasm_bits == 64)
                    WValue{ .imm64 = offset }
                else
                    return func.fail("TODO: airStructFieldVal for packed structs larger than 64 bits", .{});

                // for first field we don't require any shifting
                const shifted_value = if (offset == 0)
                    operand
                else
                    try func.binOp(operand, const_wvalue, backing_ty, .shr);

                if (field_ty.zigTypeTag(mod) == .Float) {
                    const int_type = try mod.intType(.unsigned, @as(u16, @intCast(field_ty.bitSize(mod))));
                    const truncated = try func.trunc(shifted_value, int_type, backing_ty);
                    const bitcasted = try func.bitcast(field_ty, int_type, truncated);
                    break :result try bitcasted.toLocal(func, field_ty);
                } else if (field_ty.isPtrAtRuntime(mod) and packed_struct.field_types.len == 1) {
                    // In this case we do not have to perform any transformations,
                    // we can simply reuse the operand.
                    break :result func.reuseOperand(struct_field.struct_operand, operand);
                } else if (field_ty.isPtrAtRuntime(mod)) {
                    const int_type = try mod.intType(.unsigned, @as(u16, @intCast(field_ty.bitSize(mod))));
                    const truncated = try func.trunc(shifted_value, int_type, backing_ty);
                    break :result try truncated.toLocal(func, field_ty);
                }
                const truncated = try func.trunc(shifted_value, field_ty, backing_ty);
                break :result try truncated.toLocal(func, field_ty);
            },
            .Union => result: {
                if (isByRef(struct_ty, mod)) {
                    if (!isByRef(field_ty, mod)) {
                        const val = try func.load(operand, field_ty, 0);
                        break :result try val.toLocal(func, field_ty);
                    } else {
                        const new_stack_val = try func.allocStack(field_ty);
                        try func.store(new_stack_val, operand, field_ty, 0);
                        break :result new_stack_val;
                    }
                }

                const union_int_type = try mod.intType(.unsigned, @as(u16, @intCast(struct_ty.bitSize(mod))));
                if (field_ty.zigTypeTag(mod) == .Float) {
                    const int_type = try mod.intType(.unsigned, @as(u16, @intCast(field_ty.bitSize(mod))));
                    const truncated = try func.trunc(operand, int_type, union_int_type);
                    const bitcasted = try func.bitcast(field_ty, int_type, truncated);
                    break :result try bitcasted.toLocal(func, field_ty);
                } else if (field_ty.isPtrAtRuntime(mod)) {
                    const int_type = try mod.intType(.unsigned, @as(u16, @intCast(field_ty.bitSize(mod))));
                    const truncated = try func.trunc(operand, int_type, union_int_type);
                    break :result try truncated.toLocal(func, field_ty);
                }
                const truncated = try func.trunc(operand, field_ty, union_int_type);
                break :result try truncated.toLocal(func, field_ty);
            },
            else => unreachable,
        },
        else => result: {
            const offset = std.math.cast(u32, struct_ty.structFieldOffset(field_index, mod)) orelse {
                return func.fail("Field type '{}' too big to fit into stack frame", .{field_ty.fmt(mod)});
            };
            if (isByRef(field_ty, mod)) {
                switch (operand) {
                    .stack_offset => |stack_offset| {
                        break :result WValue{ .stack_offset = .{ .value = stack_offset.value + offset, .references = 1 } };
                    },
                    else => break :result try func.buildPointerOffset(operand, offset, .new),
                }
            }
            const field = try func.load(operand, field_ty, offset);
            break :result try field.toLocal(func, field_ty);
        },
    };

    func.finishAir(inst, result, &.{struct_field.struct_operand});
}

fn airSwitchBr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    // result type is always 'noreturn'
    const blocktype = wasm.block_empty;
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const target = try func.resolveInst(pl_op.operand);
    const target_ty = func.typeOf(pl_op.operand);
    const switch_br = func.air.extraData(Air.SwitchBr, pl_op.payload);
    const liveness = try func.liveness.getSwitchBr(func.gpa, inst, switch_br.data.cases_len + 1);
    defer func.gpa.free(liveness.deaths);

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;

    // a list that maps each value with its value and body based on the order inside the list.
    const CaseValue = struct { integer: i32, value: Value };
    var case_list = try std.ArrayList(struct {
        values: []const CaseValue,
        body: []const Air.Inst.Index,
    }).initCapacity(func.gpa, switch_br.data.cases_len);
    defer for (case_list.items) |case| {
        func.gpa.free(case.values);
    } else case_list.deinit();

    var lowest_maybe: ?i32 = null;
    var highest_maybe: ?i32 = null;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = func.air.extraData(Air.SwitchBr.Case, extra_index);
        const items: []const Air.Inst.Ref = @ptrCast(func.air.extra[case.end..][0..case.data.items_len]);
        const case_body: []const Air.Inst.Index = @ptrCast(func.air.extra[case.end + items.len ..][0..case.data.body_len]);
        extra_index = case.end + items.len + case_body.len;
        const values = try func.gpa.alloc(CaseValue, items.len);
        errdefer func.gpa.free(values);

        for (items, 0..) |ref, i| {
            const item_val = (try func.air.value(ref, mod)).?;
            const int_val = func.valueAsI32(item_val, target_ty);
            if (lowest_maybe == null or int_val < lowest_maybe.?) {
                lowest_maybe = int_val;
            }
            if (highest_maybe == null or int_val > highest_maybe.?) {
                highest_maybe = int_val;
            }
            values[i] = .{ .integer = int_val, .value = item_val };
        }

        case_list.appendAssumeCapacity(.{ .values = values, .body = case_body });
        try func.startBlock(.block, blocktype);
    }

    // When highest and lowest are null, we have no cases and can use a jump table
    const lowest = lowest_maybe orelse 0;
    const highest = highest_maybe orelse 0;
    // When the highest and lowest values are seperated by '50',
    // we define it as sparse and use an if/else-chain, rather than a jump table.
    // When the target is an integer size larger than u32, we have no way to use the value
    // as an index, therefore we also use an if/else-chain for those cases.
    // TODO: Benchmark this to find a proper value, LLVM seems to draw the line at '40~45'.
    const is_sparse = highest - lowest > 50 or target_ty.bitSize(mod) > 32;

    const else_body: []const Air.Inst.Index = @ptrCast(func.air.extra[extra_index..][0..switch_br.data.else_body_len]);
    const has_else_body = else_body.len != 0;
    if (has_else_body) {
        try func.startBlock(.block, blocktype);
    }

    if (!is_sparse) {
        // Generate the jump table 'br_table' when the prongs are not sparse.
        // The value 'target' represents the index into the table.
        // Each index in the table represents a label to the branch
        // to jump to.
        try func.startBlock(.block, blocktype);
        try func.emitWValue(target);
        if (lowest < 0) {
            // since br_table works using indexes, starting from '0', we must ensure all values
            // we put inside, are atleast 0.
            try func.addImm32(lowest * -1);
            try func.addTag(.i32_add);
        } else if (lowest > 0) {
            // make the index start from 0 by substracting the lowest value
            try func.addImm32(lowest);
            try func.addTag(.i32_sub);
        }

        // Account for default branch so always add '1'
        const depth = @as(u32, @intCast(highest - lowest + @intFromBool(has_else_body))) + 1;
        const jump_table: Mir.JumpTable = .{ .length = depth };
        const table_extra_index = try func.addExtra(jump_table);
        try func.addInst(.{ .tag = .br_table, .data = .{ .payload = table_extra_index } });
        try func.mir_extra.ensureUnusedCapacity(func.gpa, depth);
        var value = lowest;
        while (value <= highest) : (value += 1) {
            // idx represents the branch we jump to
            const idx = blk: {
                for (case_list.items, 0..) |case, idx| {
                    for (case.values) |case_value| {
                        if (case_value.integer == value) break :blk @as(u32, @intCast(idx));
                    }
                }
                // error sets are almost always sparse so we use the default case
                // for errors that are not present in any branch. This is fine as this default
                // case will never be hit for those cases but we do save runtime cost and size
                // by using a jump table for this instead of if-else chains.
                break :blk if (has_else_body or target_ty.zigTypeTag(mod) == .ErrorSet) case_i else unreachable;
            };
            func.mir_extra.appendAssumeCapacity(idx);
        } else if (has_else_body) {
            func.mir_extra.appendAssumeCapacity(case_i); // default branch
        }
        try func.endBlock();
    }

    const signedness: std.builtin.Signedness = blk: {
        // by default we tell the operand type is unsigned (i.e. bools and enum values)
        if (target_ty.zigTypeTag(mod) != .Int) break :blk .unsigned;

        // incase of an actual integer, we emit the correct signedness
        break :blk target_ty.intInfo(mod).signedness;
    };

    try func.branches.ensureUnusedCapacity(func.gpa, case_list.items.len + @intFromBool(has_else_body));
    for (case_list.items, 0..) |case, index| {
        // when sparse, we use if/else-chain, so emit conditional checks
        if (is_sparse) {
            // for single value prong we can emit a simple if
            if (case.values.len == 1) {
                try func.emitWValue(target);
                const val = try func.lowerConstant(case.values[0].value, target_ty);
                try func.emitWValue(val);
                const opcode = buildOpcode(.{
                    .valtype1 = typeToValtype(target_ty, mod),
                    .op = .ne, // not equal, because we want to jump out of this block if it does not match the condition.
                    .signedness = signedness,
                });
                try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
                try func.addLabel(.br_if, 0);
            } else {
                // in multi-value prongs we must check if any prongs match the target value.
                try func.startBlock(.block, blocktype);
                for (case.values) |value| {
                    try func.emitWValue(target);
                    const val = try func.lowerConstant(value.value, target_ty);
                    try func.emitWValue(val);
                    const opcode = buildOpcode(.{
                        .valtype1 = typeToValtype(target_ty, mod),
                        .op = .eq,
                        .signedness = signedness,
                    });
                    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
                    try func.addLabel(.br_if, 0);
                }
                // value did not match any of the prong values
                try func.addLabel(.br, 1);
                try func.endBlock();
            }
        }
        func.branches.appendAssumeCapacity(.{});
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, liveness.deaths[index].len);
        defer {
            var case_branch = func.branches.pop();
            case_branch.deinit(func.gpa);
        }
        try func.genBody(case.body);
        try func.endBlock();
    }

    if (has_else_body) {
        func.branches.appendAssumeCapacity(.{});
        const else_deaths = liveness.deaths.len - 1;
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, liveness.deaths[else_deaths].len);
        defer {
            var else_branch = func.branches.pop();
            else_branch.deinit(func.gpa);
        }
        try func.genBody(else_body);
        try func.endBlock();
    }
    func.finishAir(inst, .none, &.{});
}

fn airIsErr(func: *CodeGen, inst: Air.Inst.Index, opcode: wasm.Opcode) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const err_union_ty = func.typeOf(un_op);
    const pl_ty = err_union_ty.errorUnionPayload(mod);

    const result = result: {
        if (err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            switch (opcode) {
                .i32_ne => break :result WValue{ .imm32 = 0 },
                .i32_eq => break :result WValue{ .imm32 = 1 },
                else => unreachable,
            }
        }

        try func.emitWValue(operand);
        if (pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            try func.addMemArg(.i32_load16_u, .{
                .offset = operand.offset() + @as(u32, @intCast(errUnionErrorOffset(pl_ty, mod))),
                .alignment = @intCast(Type.anyerror.abiAlignment(mod).toByteUnits().?),
            });
        }

        // Compare the error value with '0'
        try func.addImm32(0);
        try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));

        const is_err_tmp = try func.allocLocal(Type.i32);
        try func.addLabel(.local_set, is_err_tmp.local.value);
        break :result is_err_tmp;
    };
    func.finishAir(inst, result, &.{un_op});
}

fn airUnwrapErrUnionPayload(func: *CodeGen, inst: Air.Inst.Index, op_is_ptr: bool) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const op_ty = func.typeOf(ty_op.operand);
    const err_ty = if (op_is_ptr) op_ty.childType(mod) else op_ty;
    const payload_ty = err_ty.errorUnionPayload(mod);

    const result = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            if (op_is_ptr) {
                break :result func.reuseOperand(ty_op.operand, operand);
            }
            break :result WValue{ .none = {} };
        }

        const pl_offset = @as(u32, @intCast(errUnionPayloadOffset(payload_ty, mod)));
        if (op_is_ptr or isByRef(payload_ty, mod)) {
            break :result try func.buildPointerOffset(operand, pl_offset, .new);
        }

        const payload = try func.load(operand, payload_ty, pl_offset);
        break :result try payload.toLocal(func, payload_ty);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airUnwrapErrUnionError(func: *CodeGen, inst: Air.Inst.Index, op_is_ptr: bool) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const op_ty = func.typeOf(ty_op.operand);
    const err_ty = if (op_is_ptr) op_ty.childType(mod) else op_ty;
    const payload_ty = err_ty.errorUnionPayload(mod);

    const result = result: {
        if (err_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
            break :result WValue{ .imm32 = 0 };
        }

        if (op_is_ptr or !payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }

        const error_val = try func.load(operand, Type.anyerror, @as(u32, @intCast(errUnionErrorOffset(payload_ty, mod))));
        break :result try error_val.toLocal(func, Type.anyerror);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airWrapErrUnionPayload(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const err_ty = func.typeOfIndex(inst);

    const pl_ty = func.typeOf(ty_op.operand);
    const result = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }

        const err_union = try func.allocStack(err_ty);
        const payload_ptr = try func.buildPointerOffset(err_union, @as(u32, @intCast(errUnionPayloadOffset(pl_ty, mod))), .new);
        try func.store(payload_ptr, operand, pl_ty, 0);

        // ensure we also write '0' to the error part, so any present stack value gets overwritten by it.
        try func.emitWValue(err_union);
        try func.addImm32(0);
        const err_val_offset = @as(u32, @intCast(errUnionErrorOffset(pl_ty, mod)));
        try func.addMemArg(.i32_store16, .{
            .offset = err_union.offset() + err_val_offset,
            .alignment = 2,
        });
        break :result err_union;
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airWrapErrUnionErr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const err_ty = ty_op.ty.toType();
    const pl_ty = err_ty.errorUnionPayload(mod);

    const result = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }

        const err_union = try func.allocStack(err_ty);
        // store error value
        try func.store(err_union, operand, Type.anyerror, @as(u32, @intCast(errUnionErrorOffset(pl_ty, mod))));

        // write 'undefined' to the payload
        const payload_ptr = try func.buildPointerOffset(err_union, @as(u32, @intCast(errUnionPayloadOffset(pl_ty, mod))), .new);
        const len = @as(u32, @intCast(err_ty.errorUnionPayload(mod).abiSize(mod)));
        try func.memset(Type.u8, payload_ptr, .{ .imm32 = len }, .{ .imm32 = 0xaa });

        break :result err_union;
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airIntcast(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ty = ty_op.ty.toType();
    const operand = try func.resolveInst(ty_op.operand);
    const operand_ty = func.typeOf(ty_op.operand);
    const mod = func.bin_file.base.comp.module.?;
    if (ty.zigTypeTag(mod) == .Vector or operand_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("todo Wasm intcast for vectors", .{});
    }
    if (ty.abiSize(mod) > 16 or operand_ty.abiSize(mod) > 16) {
        return func.fail("todo Wasm intcast for bitsize > 128", .{});
    }

    const op_bits = toWasmBits(@as(u16, @intCast(operand_ty.bitSize(mod)))).?;
    const wanted_bits = toWasmBits(@as(u16, @intCast(ty.bitSize(mod)))).?;
    const result = if (op_bits == wanted_bits and !ty.isSignedInt(mod))
        func.reuseOperand(ty_op.operand, operand)
    else
        try (try func.intcast(operand, operand_ty, ty)).toLocal(func, ty);

    func.finishAir(inst, result, &.{});
}

/// Upcasts or downcasts an integer based on the given and wanted types,
/// and stores the result in a new operand.
/// Asserts type's bitsize <= 128
/// NOTE: May leave the result on the top of the stack.
fn intcast(func: *CodeGen, operand: WValue, given: Type, wanted: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const given_bitsize = @as(u16, @intCast(given.bitSize(mod)));
    const wanted_bitsize = @as(u16, @intCast(wanted.bitSize(mod)));
    assert(given_bitsize <= 128);
    assert(wanted_bitsize <= 128);

    const op_bits = toWasmBits(given_bitsize).?;
    const wanted_bits = toWasmBits(wanted_bitsize).?;
    if (op_bits == wanted_bits) {
        if (given.isSignedInt(mod)) {
            if (given_bitsize < wanted_bitsize) {
                // signed integers are stored as two's complement,
                // when we upcast from a smaller integer to larger
                // integers, we must get its absolute value similar to
                // i64_extend_i32_s instruction.
                return func.signExtendInt(operand, given);
            }
            return func.wrapOperand(operand, wanted);
        }
        return operand;
    }

    if (op_bits > 32 and op_bits <= 64 and wanted_bits == 32) {
        try func.emitWValue(operand);
        try func.addTag(.i32_wrap_i64);
        if (given.isSignedInt(mod) and wanted_bitsize < 32)
            return func.wrapOperand(.{ .stack = {} }, wanted)
        else
            return WValue{ .stack = {} };
    } else if (op_bits == 32 and wanted_bits > 32 and wanted_bits <= 64) {
        const operand32 = if (given_bitsize < 32 and wanted.isSignedInt(mod))
            try func.signExtendInt(operand, given)
        else
            operand;
        try func.emitWValue(operand32);
        try func.addTag(if (wanted.isSignedInt(mod)) .i64_extend_i32_s else .i64_extend_i32_u);
        if (given.isSignedInt(mod) and wanted_bitsize < 64)
            return func.wrapOperand(.{ .stack = {} }, wanted)
        else
            return WValue{ .stack = {} };
    } else if (wanted_bits == 128) {
        // for 128bit integers we store the integer in the virtual stack, rather than a local
        const stack_ptr = try func.allocStack(wanted);
        try func.emitWValue(stack_ptr);

        // for 32 bit integers, we first coerce the value into a 64 bit integer before storing it
        // meaning less store operations are required.
        const lhs = if (op_bits == 32) blk: {
            break :blk try func.intcast(operand, given, if (wanted.isSignedInt(mod)) Type.i64 else Type.u64);
        } else operand;

        // store msb first
        try func.store(.{ .stack = {} }, lhs, Type.u64, 0 + stack_ptr.offset());

        // For signed integers we shift msb by 63 (64bit integer - 1 sign bit) and store remaining value
        if (wanted.isSignedInt(mod)) {
            try func.emitWValue(stack_ptr);
            const shr = try func.binOp(lhs, .{ .imm64 = 63 }, Type.i64, .shr);
            try func.store(.{ .stack = {} }, shr, Type.u64, 8 + stack_ptr.offset());
        } else {
            // Ensure memory of lsb is zero'd
            try func.store(stack_ptr, .{ .imm64 = 0 }, Type.u64, 8);
        }
        return stack_ptr;
    } else return func.load(operand, wanted, 0);
}

fn airIsNull(func: *CodeGen, inst: Air.Inst.Index, opcode: wasm.Opcode, op_kind: enum { value, ptr }) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);

    const op_ty = func.typeOf(un_op);
    const optional_ty = if (op_kind == .ptr) op_ty.childType(mod) else op_ty;
    const is_null = try func.isNull(operand, optional_ty, opcode);
    const result = try is_null.toLocal(func, optional_ty);
    func.finishAir(inst, result, &.{un_op});
}

/// For a given type and operand, checks if it's considered `null`.
/// NOTE: Leaves the result on the stack
fn isNull(func: *CodeGen, operand: WValue, optional_ty: Type, opcode: wasm.Opcode) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    try func.emitWValue(operand);
    const payload_ty = optional_ty.optionalChild(mod);
    if (!optional_ty.optionalReprIsPayload(mod)) {
        // When payload is zero-bits, we can treat operand as a value, rather than
        // a pointer to the stack value
        if (payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const offset = std.math.cast(u32, payload_ty.abiSize(mod)) orelse {
                return func.fail("Optional type {} too big to fit into stack frame", .{optional_ty.fmt(mod)});
            };
            try func.addMemArg(.i32_load8_u, .{ .offset = operand.offset() + offset, .alignment = 1 });
        }
    } else if (payload_ty.isSlice(mod)) {
        switch (func.arch()) {
            .wasm32 => try func.addMemArg(.i32_load, .{ .offset = operand.offset(), .alignment = 4 }),
            .wasm64 => try func.addMemArg(.i64_load, .{ .offset = operand.offset(), .alignment = 8 }),
            else => unreachable,
        }
    }

    // Compare the null value with '0'
    try func.addImm32(0);
    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    return WValue{ .stack = {} };
}

fn airOptionalPayload(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const opt_ty = func.typeOf(ty_op.operand);
    const payload_ty = func.typeOfIndex(inst);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return func.finishAir(inst, .none, &.{ty_op.operand});
    }

    const result = result: {
        const operand = try func.resolveInst(ty_op.operand);
        if (opt_ty.optionalReprIsPayload(mod)) break :result func.reuseOperand(ty_op.operand, operand);

        if (isByRef(payload_ty, mod)) {
            break :result try func.buildPointerOffset(operand, 0, .new);
        }

        const payload = try func.load(operand, payload_ty, 0);
        break :result try payload.toLocal(func, payload_ty);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airOptionalPayloadPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    const opt_ty = func.typeOf(ty_op.operand).childType(mod);

    const result = result: {
        const payload_ty = opt_ty.optionalChild(mod);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod) or opt_ty.optionalReprIsPayload(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }

        break :result try func.buildPointerOffset(operand, 0, .new);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airOptionalPayloadPtrSet(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    const opt_ty = func.typeOf(ty_op.operand).childType(mod);
    const payload_ty = opt_ty.optionalChild(mod);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return func.fail("TODO: Implement OptionalPayloadPtrSet for optional with zero-sized type {}", .{payload_ty.fmtDebug()});
    }

    if (opt_ty.optionalReprIsPayload(mod)) {
        return func.finishAir(inst, operand, &.{ty_op.operand});
    }

    const offset = std.math.cast(u32, payload_ty.abiSize(mod)) orelse {
        return func.fail("Optional type {} too big to fit into stack frame", .{opt_ty.fmt(mod)});
    };

    try func.emitWValue(operand);
    try func.addImm32(1);
    try func.addMemArg(.i32_store8, .{ .offset = operand.offset() + offset, .alignment = 1 });

    const result = try func.buildPointerOffset(operand, 0, .new);
    return func.finishAir(inst, result, &.{ty_op.operand});
}

fn airWrapOptional(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const payload_ty = func.typeOf(ty_op.operand);
    const mod = func.bin_file.base.comp.module.?;

    const result = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            const non_null_bit = try func.allocStack(Type.u1);
            try func.emitWValue(non_null_bit);
            try func.addImm32(1);
            try func.addMemArg(.i32_store8, .{ .offset = non_null_bit.offset(), .alignment = 1 });
            break :result non_null_bit;
        }

        const operand = try func.resolveInst(ty_op.operand);
        const op_ty = func.typeOfIndex(inst);
        if (op_ty.optionalReprIsPayload(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }
        const offset = std.math.cast(u32, payload_ty.abiSize(mod)) orelse {
            return func.fail("Optional type {} too big to fit into stack frame", .{op_ty.fmt(mod)});
        };

        // Create optional type, set the non-null bit, and store the operand inside the optional type
        const result_ptr = try func.allocStack(op_ty);
        try func.emitWValue(result_ptr);
        try func.addImm32(1);
        try func.addMemArg(.i32_store8, .{ .offset = result_ptr.offset() + offset, .alignment = 1 });

        const payload_ptr = try func.buildPointerOffset(result_ptr, 0, .new);
        try func.store(payload_ptr, operand, payload_ty, 0);
        break :result result_ptr;
    };

    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airSlice(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const slice_ty = func.typeOfIndex(inst);

    const slice = try func.allocStack(slice_ty);
    try func.store(slice, lhs, Type.usize, 0);
    try func.store(slice, rhs, Type.usize, func.ptrSize());

    func.finishAir(inst, slice, &.{ bin_op.lhs, bin_op.rhs });
}

fn airSliceLen(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    func.finishAir(inst, try func.sliceLen(operand), &.{ty_op.operand});
}

fn airSliceElemVal(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const slice_ty = func.typeOf(bin_op.lhs);
    const slice = try func.resolveInst(bin_op.lhs);
    const index = try func.resolveInst(bin_op.rhs);
    const elem_ty = slice_ty.childType(mod);
    const elem_size = elem_ty.abiSize(mod);

    // load pointer onto stack
    _ = try func.load(slice, Type.usize, 0);

    // calculate index into slice
    try func.emitWValue(index);
    try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
    try func.addTag(.i32_mul);
    try func.addTag(.i32_add);

    const result_ptr = try func.allocLocal(Type.usize);
    try func.addLabel(.local_set, result_ptr.local.value);

    const result = if (!isByRef(elem_ty, mod)) result: {
        const elem_val = try func.load(result_ptr, elem_ty, 0);
        break :result try elem_val.toLocal(func, elem_ty);
    } else result_ptr;

    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airSliceElemPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const elem_ty = ty_pl.ty.toType().childType(mod);
    const elem_size = elem_ty.abiSize(mod);

    const slice = try func.resolveInst(bin_op.lhs);
    const index = try func.resolveInst(bin_op.rhs);

    _ = try func.load(slice, Type.usize, 0);

    // calculate index into slice
    try func.emitWValue(index);
    try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
    try func.addTag(.i32_mul);
    try func.addTag(.i32_add);

    const result = try func.allocLocal(Type.i32);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airSlicePtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    func.finishAir(inst, try func.slicePtr(operand), &.{ty_op.operand});
}

fn slicePtr(func: *CodeGen, operand: WValue) InnerError!WValue {
    const ptr = try func.load(operand, Type.usize, 0);
    return ptr.toLocal(func, Type.usize);
}

fn sliceLen(func: *CodeGen, operand: WValue) InnerError!WValue {
    const len = try func.load(operand, Type.usize, func.ptrSize());
    return len.toLocal(func, Type.usize);
}

fn airTrunc(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const wanted_ty = ty_op.ty.toType();
    const op_ty = func.typeOf(ty_op.operand);

    const result = try func.trunc(operand, wanted_ty, op_ty);
    func.finishAir(inst, try result.toLocal(func, wanted_ty), &.{ty_op.operand});
}

/// Truncates a given operand to a given type, discarding any overflown bits.
/// NOTE: Resulting value is left on the stack.
fn trunc(func: *CodeGen, operand: WValue, wanted_ty: Type, given_ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const given_bits = @as(u16, @intCast(given_ty.bitSize(mod)));
    if (toWasmBits(given_bits) == null) {
        return func.fail("TODO: Implement wasm integer truncation for integer bitsize: {d}", .{given_bits});
    }

    var result = try func.intcast(operand, given_ty, wanted_ty);
    const wanted_bits = @as(u16, @intCast(wanted_ty.bitSize(mod)));
    const wasm_bits = toWasmBits(wanted_bits).?;
    if (wasm_bits != wanted_bits) {
        result = try func.wrapOperand(result, wanted_ty);
    }
    return result;
}

fn airIntFromBool(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const result = func.reuseOperand(un_op, operand);

    func.finishAir(inst, result, &.{un_op});
}

fn airArrayToSlice(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const array_ty = func.typeOf(ty_op.operand).childType(mod);
    const slice_ty = ty_op.ty.toType();

    // create a slice on the stack
    const slice_local = try func.allocStack(slice_ty);

    // store the array ptr in the slice
    if (array_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        try func.store(slice_local, operand, Type.usize, 0);
    }

    // store the length of the array in the slice
    const len = WValue{ .imm32 = @as(u32, @intCast(array_ty.arrayLen(mod))) };
    try func.store(slice_local, len, Type.usize, func.ptrSize());

    func.finishAir(inst, slice_local, &.{ty_op.operand});
}

fn airIntFromPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const ptr_ty = func.typeOf(un_op);
    const result = if (ptr_ty.isSlice(mod))
        try func.slicePtr(operand)
    else switch (operand) {
        // for stack offset, return a pointer to this offset.
        .stack_offset => try func.buildPointerOffset(operand, 0, .new),
        else => func.reuseOperand(un_op, operand),
    };
    func.finishAir(inst, result, &.{un_op});
}

fn airPtrElemVal(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr_ty = func.typeOf(bin_op.lhs);
    const ptr = try func.resolveInst(bin_op.lhs);
    const index = try func.resolveInst(bin_op.rhs);
    const elem_ty = ptr_ty.childType(mod);
    const elem_size = elem_ty.abiSize(mod);

    // load pointer onto the stack
    if (ptr_ty.isSlice(mod)) {
        _ = try func.load(ptr, Type.usize, 0);
    } else {
        try func.lowerToStack(ptr);
    }

    // calculate index into slice
    try func.emitWValue(index);
    try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
    try func.addTag(.i32_mul);
    try func.addTag(.i32_add);

    const elem_result = val: {
        var result = try func.allocLocal(Type.usize);
        try func.addLabel(.local_set, result.local.value);
        if (isByRef(elem_ty, mod)) {
            break :val result;
        }
        defer result.free(func); // only free if it's not returned like above

        const elem_val = try func.load(result, elem_ty, 0);
        break :val try elem_val.toLocal(func, elem_ty);
    };
    func.finishAir(inst, elem_result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airPtrElemPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const ptr_ty = func.typeOf(bin_op.lhs);
    const elem_ty = ty_pl.ty.toType().childType(mod);
    const elem_size = elem_ty.abiSize(mod);

    const ptr = try func.resolveInst(bin_op.lhs);
    const index = try func.resolveInst(bin_op.rhs);

    // load pointer onto the stack
    if (ptr_ty.isSlice(mod)) {
        _ = try func.load(ptr, Type.usize, 0);
    } else {
        try func.lowerToStack(ptr);
    }

    // calculate index into ptr
    try func.emitWValue(index);
    try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
    try func.addTag(.i32_mul);
    try func.addTag(.i32_add);

    const result = try func.allocLocal(Type.i32);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airPtrBinOp(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const ptr = try func.resolveInst(bin_op.lhs);
    const offset = try func.resolveInst(bin_op.rhs);
    const ptr_ty = func.typeOf(bin_op.lhs);
    const pointee_ty = switch (ptr_ty.ptrSize(mod)) {
        .One => ptr_ty.childType(mod).childType(mod), // ptr to array, so get array element type
        else => ptr_ty.childType(mod),
    };

    const valtype = typeToValtype(Type.usize, mod);
    const mul_opcode = buildOpcode(.{ .valtype1 = valtype, .op = .mul });
    const bin_opcode = buildOpcode(.{ .valtype1 = valtype, .op = op });

    try func.lowerToStack(ptr);
    try func.emitWValue(offset);
    try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(pointee_ty.abiSize(mod))))));
    try func.addTag(Mir.Inst.Tag.fromOpcode(mul_opcode));
    try func.addTag(Mir.Inst.Tag.fromOpcode(bin_opcode));

    const result = try func.allocLocal(Type.usize);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airMemset(func: *CodeGen, inst: Air.Inst.Index, safety: bool) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr = try func.resolveInst(bin_op.lhs);
    const ptr_ty = func.typeOf(bin_op.lhs);
    const value = try func.resolveInst(bin_op.rhs);
    const len = switch (ptr_ty.ptrSize(mod)) {
        .Slice => try func.sliceLen(ptr),
        .One => @as(WValue, .{ .imm32 = @as(u32, @intCast(ptr_ty.childType(mod).arrayLen(mod))) }),
        .C, .Many => unreachable,
    };

    const elem_ty = if (ptr_ty.ptrSize(mod) == .One)
        ptr_ty.childType(mod).childType(mod)
    else
        ptr_ty.childType(mod);

    const dst_ptr = try func.sliceOrArrayPtr(ptr, ptr_ty);
    try func.memset(elem_ty, dst_ptr, len, value);

    func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
}

/// Sets a region of memory at `ptr` to the value of `value`
/// When the user has enabled the bulk_memory feature, we lower
/// this to wasm's memset instruction. When the feature is not present,
/// we implement it manually.
fn memset(func: *CodeGen, elem_ty: Type, ptr: WValue, len: WValue, value: WValue) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const abi_size = @as(u32, @intCast(elem_ty.abiSize(mod)));

    // When bulk_memory is enabled, we lower it to wasm's memset instruction.
    // If not, we lower it ourselves.
    if (std.Target.wasm.featureSetHas(func.target.cpu.features, .bulk_memory) and abi_size == 1) {
        try func.lowerToStack(ptr);
        try func.emitWValue(value);
        try func.emitWValue(len);
        try func.addExtended(.memory_fill);
        return;
    }

    const final_len = switch (len) {
        .imm32 => |val| WValue{ .imm32 = val * abi_size },
        .imm64 => |val| WValue{ .imm64 = val * abi_size },
        else => if (abi_size != 1) blk: {
            const new_len = try func.ensureAllocLocal(Type.usize);
            try func.emitWValue(len);
            switch (func.arch()) {
                .wasm32 => {
                    try func.emitWValue(.{ .imm32 = abi_size });
                    try func.addTag(.i32_mul);
                },
                .wasm64 => {
                    try func.emitWValue(.{ .imm64 = abi_size });
                    try func.addTag(.i64_mul);
                },
                else => unreachable,
            }
            try func.addLabel(.local_set, new_len.local.value);
            break :blk new_len;
        } else len,
    };

    var end_ptr = try func.allocLocal(Type.usize);
    defer end_ptr.free(func);
    var new_ptr = try func.buildPointerOffset(ptr, 0, .new);
    defer new_ptr.free(func);

    // get the loop conditional: if current pointer address equals final pointer's address
    try func.lowerToStack(ptr);
    try func.emitWValue(final_len);
    switch (func.arch()) {
        .wasm32 => try func.addTag(.i32_add),
        .wasm64 => try func.addTag(.i64_add),
        else => unreachable,
    }
    try func.addLabel(.local_set, end_ptr.local.value);

    // outer block to jump to when loop is done
    try func.startBlock(.block, wasm.block_empty);
    try func.startBlock(.loop, wasm.block_empty);

    // check for codition for loop end
    try func.emitWValue(new_ptr);
    try func.emitWValue(end_ptr);
    switch (func.arch()) {
        .wasm32 => try func.addTag(.i32_eq),
        .wasm64 => try func.addTag(.i64_eq),
        else => unreachable,
    }
    try func.addLabel(.br_if, 1); // jump out of loop into outer block (finished)

    // store the value at the current position of the pointer
    try func.store(new_ptr, value, elem_ty, 0);

    // move the pointer to the next element
    try func.emitWValue(new_ptr);
    switch (func.arch()) {
        .wasm32 => {
            try func.emitWValue(.{ .imm32 = abi_size });
            try func.addTag(.i32_add);
        },
        .wasm64 => {
            try func.emitWValue(.{ .imm64 = abi_size });
            try func.addTag(.i64_add);
        },
        else => unreachable,
    }
    try func.addLabel(.local_set, new_ptr.local.value);

    // end of loop
    try func.addLabel(.br, 0); // jump to start of loop
    try func.endBlock();
    try func.endBlock();
}

fn airArrayElemVal(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const array_ty = func.typeOf(bin_op.lhs);
    const array = try func.resolveInst(bin_op.lhs);
    const index = try func.resolveInst(bin_op.rhs);
    const elem_ty = array_ty.childType(mod);
    const elem_size = elem_ty.abiSize(mod);

    if (isByRef(array_ty, mod)) {
        try func.lowerToStack(array);
        try func.emitWValue(index);
        try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
        try func.addTag(.i32_mul);
        try func.addTag(.i32_add);
    } else {
        std.debug.assert(array_ty.zigTypeTag(mod) == .Vector);

        switch (index) {
            inline .imm32, .imm64 => |lane| {
                const opcode: wasm.SimdOpcode = switch (elem_ty.bitSize(mod)) {
                    8 => if (elem_ty.isSignedInt(mod)) .i8x16_extract_lane_s else .i8x16_extract_lane_u,
                    16 => if (elem_ty.isSignedInt(mod)) .i16x8_extract_lane_s else .i16x8_extract_lane_u,
                    32 => if (elem_ty.isInt(mod)) .i32x4_extract_lane else .f32x4_extract_lane,
                    64 => if (elem_ty.isInt(mod)) .i64x2_extract_lane else .f64x2_extract_lane,
                    else => unreachable,
                };

                var operands = [_]u32{ std.wasm.simdOpcode(opcode), @as(u8, @intCast(lane)) };

                try func.emitWValue(array);

                const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
                try func.mir_extra.appendSlice(func.gpa, &operands);
                try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });

                return func.finishAir(inst, try WValue.toLocal(.stack, func, elem_ty), &.{ bin_op.lhs, bin_op.rhs });
            },
            else => {
                const stack_vec = try func.allocStack(array_ty);
                try func.store(stack_vec, array, array_ty, 0);

                // Is a non-unrolled vector (v128)
                try func.lowerToStack(stack_vec);
                try func.emitWValue(index);
                try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(elem_size)))));
                try func.addTag(.i32_mul);
                try func.addTag(.i32_add);
            },
        }
    }

    const elem_result = val: {
        var result = try func.allocLocal(Type.usize);
        try func.addLabel(.local_set, result.local.value);

        if (isByRef(elem_ty, mod)) {
            break :val result;
        }
        defer result.free(func); // only free if no longer needed and not returned like above

        const elem_val = try func.load(result, elem_ty, 0);
        break :val try elem_val.toLocal(func, elem_ty);
    };

    func.finishAir(inst, elem_result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airIntFromFloat(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const op_ty = func.typeOf(ty_op.operand);
    const op_bits = op_ty.floatBits(func.target);

    const dest_ty = func.typeOfIndex(inst);
    const dest_info = dest_ty.intInfo(mod);

    if (dest_info.bits > 128) {
        return func.fail("TODO: intFromFloat for integers/floats with bitsize {}", .{dest_info.bits});
    }

    if ((op_bits != 32 and op_bits != 64) or dest_info.bits > 64) {
        const dest_bitsize = if (dest_info.bits <= 16) 16 else std.math.ceilPowerOfTwoAssert(u16, dest_info.bits);

        var fn_name_buf: [16]u8 = undefined;
        const fn_name = std.fmt.bufPrint(&fn_name_buf, "__fix{s}{s}f{s}i", .{
            switch (dest_info.signedness) {
                .signed => "",
                .unsigned => "uns",
            },
            target_util.compilerRtFloatAbbrev(op_bits),
            target_util.compilerRtIntAbbrev(dest_bitsize),
        }) catch unreachable;

        const result = try (try func.callIntrinsic(fn_name, &.{op_ty.ip_index}, dest_ty, &.{operand})).toLocal(func, dest_ty);
        return func.finishAir(inst, result, &.{ty_op.operand});
    }

    try func.emitWValue(operand);
    const op = buildOpcode(.{
        .op = .trunc,
        .valtype1 = typeToValtype(dest_ty, mod),
        .valtype2 = typeToValtype(op_ty, mod),
        .signedness = dest_info.signedness,
    });
    try func.addTag(Mir.Inst.Tag.fromOpcode(op));
    const wrapped = try func.wrapOperand(.{ .stack = {} }, dest_ty);
    const result = try wrapped.toLocal(func, dest_ty);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airFloatFromInt(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const op_ty = func.typeOf(ty_op.operand);
    const op_info = op_ty.intInfo(mod);

    const dest_ty = func.typeOfIndex(inst);
    const dest_bits = dest_ty.floatBits(func.target);

    if (op_info.bits > 128) {
        return func.fail("TODO: floatFromInt for integers/floats with bitsize {d} bits", .{op_info.bits});
    }

    if (op_info.bits > 64 or (dest_bits > 64 or dest_bits < 32)) {
        const op_bitsize = if (op_info.bits <= 16) 16 else std.math.ceilPowerOfTwoAssert(u16, op_info.bits);

        var fn_name_buf: [16]u8 = undefined;
        const fn_name = std.fmt.bufPrint(&fn_name_buf, "__float{s}{s}i{s}f", .{
            switch (op_info.signedness) {
                .signed => "",
                .unsigned => "un",
            },
            target_util.compilerRtIntAbbrev(op_bitsize),
            target_util.compilerRtFloatAbbrev(dest_bits),
        }) catch unreachable;

        const result = try (try func.callIntrinsic(fn_name, &.{op_ty.ip_index}, dest_ty, &.{operand})).toLocal(func, dest_ty);
        return func.finishAir(inst, result, &.{ty_op.operand});
    }

    try func.emitWValue(operand);
    const op = buildOpcode(.{
        .op = .convert,
        .valtype1 = typeToValtype(dest_ty, mod),
        .valtype2 = typeToValtype(op_ty, mod),
        .signedness = op_info.signedness,
    });
    try func.addTag(Mir.Inst.Tag.fromOpcode(op));

    const result = try func.allocLocal(dest_ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airSplat(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try func.resolveInst(ty_op.operand);
    const ty = func.typeOfIndex(inst);
    const elem_ty = ty.childType(mod);

    if (determineSimdStoreStrategy(ty, mod) == .direct) blk: {
        switch (operand) {
            // when the operand lives in the linear memory section, we can directly
            // load and splat the value at once. Meaning we do not first have to load
            // the scalar value onto the stack.
            .stack_offset, .memory, .memory_offset => {
                const opcode = switch (elem_ty.bitSize(mod)) {
                    8 => std.wasm.simdOpcode(.v128_load8_splat),
                    16 => std.wasm.simdOpcode(.v128_load16_splat),
                    32 => std.wasm.simdOpcode(.v128_load32_splat),
                    64 => std.wasm.simdOpcode(.v128_load64_splat),
                    else => break :blk, // Cannot make use of simd-instructions
                };
                const result = try func.allocLocal(ty);
                try func.emitWValue(operand);
                // TODO: Add helper functions for simd opcodes
                const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
                // stores as := opcode, offset, alignment (opcode::memarg)
                try func.mir_extra.appendSlice(func.gpa, &[_]u32{
                    opcode,
                    operand.offset(),
                    @intCast(elem_ty.abiAlignment(mod).toByteUnits().?),
                });
                try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });
                try func.addLabel(.local_set, result.local.value);
                return func.finishAir(inst, result, &.{ty_op.operand});
            },
            .local => {
                const opcode = switch (elem_ty.bitSize(mod)) {
                    8 => std.wasm.simdOpcode(.i8x16_splat),
                    16 => std.wasm.simdOpcode(.i16x8_splat),
                    32 => if (elem_ty.isInt(mod)) std.wasm.simdOpcode(.i32x4_splat) else std.wasm.simdOpcode(.f32x4_splat),
                    64 => if (elem_ty.isInt(mod)) std.wasm.simdOpcode(.i64x2_splat) else std.wasm.simdOpcode(.f64x2_splat),
                    else => break :blk, // Cannot make use of simd-instructions
                };
                const result = try func.allocLocal(ty);
                try func.emitWValue(operand);
                const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
                try func.mir_extra.append(func.gpa, opcode);
                try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });
                try func.addLabel(.local_set, result.local.value);
                return func.finishAir(inst, result, &.{ty_op.operand});
            },
            else => unreachable,
        }
    }
    const elem_size = elem_ty.bitSize(mod);
    const vector_len = @as(usize, @intCast(ty.vectorLen(mod)));
    if ((!std.math.isPowerOfTwo(elem_size) or elem_size % 8 != 0) and vector_len > 1) {
        return func.fail("TODO: WebAssembly `@splat` for arbitrary element bitsize {d}", .{elem_size});
    }

    const result = try func.allocStack(ty);
    const elem_byte_size = @as(u32, @intCast(elem_ty.abiSize(mod)));
    var index: usize = 0;
    var offset: u32 = 0;
    while (index < vector_len) : (index += 1) {
        try func.store(result, operand, elem_ty, offset);
        offset += elem_byte_size;
    }

    return func.finishAir(inst, result, &.{ty_op.operand});
}

fn airSelect(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const operand = try func.resolveInst(pl_op.operand);

    _ = operand;
    return func.fail("TODO: Implement wasm airSelect", .{});
}

fn airShuffle(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const inst_ty = func.typeOfIndex(inst);
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Shuffle, ty_pl.payload).data;

    const a = try func.resolveInst(extra.a);
    const b = try func.resolveInst(extra.b);
    const mask = Value.fromInterned(extra.mask);
    const mask_len = extra.mask_len;

    const child_ty = inst_ty.childType(mod);
    const elem_size = child_ty.abiSize(mod);

    // TODO: One of them could be by ref; handle in loop
    if (isByRef(func.typeOf(extra.a), mod) or isByRef(inst_ty, mod)) {
        const result = try func.allocStack(inst_ty);

        for (0..mask_len) |index| {
            const value = (try mask.elemValue(mod, index)).toSignedInt(mod);

            try func.emitWValue(result);

            const loaded = if (value >= 0)
                try func.load(a, child_ty, @as(u32, @intCast(@as(i64, @intCast(elem_size)) * value)))
            else
                try func.load(b, child_ty, @as(u32, @intCast(@as(i64, @intCast(elem_size)) * ~value)));

            try func.store(.stack, loaded, child_ty, result.stack_offset.value + @as(u32, @intCast(elem_size)) * @as(u32, @intCast(index)));
        }

        return func.finishAir(inst, result, &.{ extra.a, extra.b });
    } else {
        var operands = [_]u32{
            std.wasm.simdOpcode(.i8x16_shuffle),
        } ++ [1]u32{undefined} ** 4;

        var lanes = mem.asBytes(operands[1..]);
        for (0..@as(usize, @intCast(mask_len))) |index| {
            const mask_elem = (try mask.elemValue(mod, index)).toSignedInt(mod);
            const base_index = if (mask_elem >= 0)
                @as(u8, @intCast(@as(i64, @intCast(elem_size)) * mask_elem))
            else
                16 + @as(u8, @intCast(@as(i64, @intCast(elem_size)) * ~mask_elem));

            for (0..@as(usize, @intCast(elem_size))) |byte_offset| {
                lanes[index * @as(usize, @intCast(elem_size)) + byte_offset] = base_index + @as(u8, @intCast(byte_offset));
            }
        }

        try func.emitWValue(a);
        try func.emitWValue(b);

        const extra_index = @as(u32, @intCast(func.mir_extra.items.len));
        try func.mir_extra.appendSlice(func.gpa, &operands);
        try func.addInst(.{ .tag = .simd_prefix, .data = .{ .payload = extra_index } });

        return func.finishAir(inst, try WValue.toLocal(.stack, func, inst_ty), &.{ extra.a, extra.b });
    }
}

fn airReduce(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const reduce = func.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
    const operand = try func.resolveInst(reduce.operand);

    _ = operand;
    return func.fail("TODO: Implement wasm airReduce", .{});
}

fn airAggregateInit(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const result_ty = func.typeOfIndex(inst);
    const len = @as(usize, @intCast(result_ty.arrayLen(mod)));
    const elements = @as([]const Air.Inst.Ref, @ptrCast(func.air.extra[ty_pl.payload..][0..len]));

    const result: WValue = result_value: {
        switch (result_ty.zigTypeTag(mod)) {
            .Array => {
                const result = try func.allocStack(result_ty);
                const elem_ty = result_ty.childType(mod);
                const elem_size = @as(u32, @intCast(elem_ty.abiSize(mod)));
                const sentinel = if (result_ty.sentinel(mod)) |sent| blk: {
                    break :blk try func.lowerConstant(sent, elem_ty);
                } else null;

                // When the element type is by reference, we must copy the entire
                // value. It is therefore safer to move the offset pointer and store
                // each value individually, instead of using store offsets.
                if (isByRef(elem_ty, mod)) {
                    // copy stack pointer into a temporary local, which is
                    // moved for each element to store each value in the right position.
                    const offset = try func.buildPointerOffset(result, 0, .new);
                    for (elements, 0..) |elem, elem_index| {
                        const elem_val = try func.resolveInst(elem);
                        try func.store(offset, elem_val, elem_ty, 0);

                        if (elem_index < elements.len - 1 and sentinel == null) {
                            _ = try func.buildPointerOffset(offset, elem_size, .modify);
                        }
                    }
                    if (sentinel) |sent| {
                        try func.store(offset, sent, elem_ty, 0);
                    }
                } else {
                    var offset: u32 = 0;
                    for (elements) |elem| {
                        const elem_val = try func.resolveInst(elem);
                        try func.store(result, elem_val, elem_ty, offset);
                        offset += elem_size;
                    }
                    if (sentinel) |sent| {
                        try func.store(result, sent, elem_ty, offset);
                    }
                }
                break :result_value result;
            },
            .Struct => switch (result_ty.containerLayout(mod)) {
                .@"packed" => {
                    if (isByRef(result_ty, mod)) {
                        return func.fail("TODO: airAggregateInit for packed structs larger than 64 bits", .{});
                    }
                    const packed_struct = mod.typeToPackedStruct(result_ty).?;
                    const field_types = packed_struct.field_types;
                    const backing_type = Type.fromInterned(packed_struct.backingIntType(ip).*);

                    // ensure the result is zero'd
                    const result = try func.allocLocal(backing_type);
                    if (backing_type.bitSize(mod) <= 32)
                        try func.addImm32(0)
                    else
                        try func.addImm64(0);
                    try func.addLabel(.local_set, result.local.value);

                    var current_bit: u16 = 0;
                    for (elements, 0..) |elem, elem_index| {
                        const field_ty = Type.fromInterned(field_types.get(ip)[elem_index]);
                        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) continue;

                        const shift_val = if (backing_type.bitSize(mod) <= 32)
                            WValue{ .imm32 = current_bit }
                        else
                            WValue{ .imm64 = current_bit };

                        const value = try func.resolveInst(elem);
                        const value_bit_size: u16 = @intCast(field_ty.bitSize(mod));
                        const int_ty = try mod.intType(.unsigned, value_bit_size);

                        // load our current result on stack so we can perform all transformations
                        // using only stack values. Saving the cost of loads and stores.
                        try func.emitWValue(result);
                        const bitcasted = try func.bitcast(int_ty, field_ty, value);
                        const extended_val = try func.intcast(bitcasted, int_ty, backing_type);
                        // no need to shift any values when the current offset is 0
                        const shifted = if (current_bit != 0) shifted: {
                            break :shifted try func.binOp(extended_val, shift_val, backing_type, .shl);
                        } else extended_val;
                        // we ignore the result as we keep it on the stack to assign it directly to `result`
                        _ = try func.binOp(.stack, shifted, backing_type, .@"or");
                        try func.addLabel(.local_set, result.local.value);
                        current_bit += value_bit_size;
                    }
                    break :result_value result;
                },
                else => {
                    const result = try func.allocStack(result_ty);
                    const offset = try func.buildPointerOffset(result, 0, .new); // pointer to offset
                    var prev_field_offset: u64 = 0;
                    for (elements, 0..) |elem, elem_index| {
                        if ((try result_ty.structFieldValueComptime(mod, elem_index)) != null) continue;

                        const elem_ty = result_ty.structFieldType(elem_index, mod);
                        const field_offset = result_ty.structFieldOffset(elem_index, mod);
                        _ = try func.buildPointerOffset(offset, @intCast(field_offset - prev_field_offset), .modify);
                        prev_field_offset = field_offset;

                        const value = try func.resolveInst(elem);
                        try func.store(offset, value, elem_ty, 0);
                    }

                    break :result_value result;
                },
            },
            .Vector => return func.fail("TODO: Wasm backend: implement airAggregateInit for vectors", .{}),
            else => unreachable,
        }
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        @memcpy(buf[0..elements.len], elements);
        return func.finishAir(inst, result, &buf);
    }
    var bt = try func.iterateBigTomb(inst, elements.len);
    for (elements) |arg| bt.feed(arg);
    return bt.finishAir(result);
}

fn airUnionInit(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.UnionInit, ty_pl.payload).data;

    const result = result: {
        const union_ty = func.typeOfIndex(inst);
        const layout = union_ty.unionGetLayout(mod);
        const union_obj = mod.typeToUnion(union_ty).?;
        const field_ty = Type.fromInterned(union_obj.field_types.get(ip)[extra.field_index]);
        const field_name = union_obj.loadTagType(ip).names.get(ip)[extra.field_index];

        const tag_int = blk: {
            const tag_ty = union_ty.unionTagTypeHypothetical(mod);
            const enum_field_index = tag_ty.enumFieldIndex(field_name, mod).?;
            const tag_val = try mod.enumValueFieldIndex(tag_ty, enum_field_index);
            break :blk try func.lowerConstant(tag_val, tag_ty);
        };
        if (layout.payload_size == 0) {
            if (layout.tag_size == 0) {
                break :result WValue{ .none = {} };
            }
            assert(!isByRef(union_ty, mod));
            break :result tag_int;
        }

        if (isByRef(union_ty, mod)) {
            const result_ptr = try func.allocStack(union_ty);
            const payload = try func.resolveInst(extra.init);
            if (layout.tag_align.compare(.gte, layout.payload_align)) {
                if (isByRef(field_ty, mod)) {
                    const payload_ptr = try func.buildPointerOffset(result_ptr, layout.tag_size, .new);
                    try func.store(payload_ptr, payload, field_ty, 0);
                } else {
                    try func.store(result_ptr, payload, field_ty, @intCast(layout.tag_size));
                }

                if (layout.tag_size > 0) {
                    try func.store(result_ptr, tag_int, Type.fromInterned(union_obj.enum_tag_ty), 0);
                }
            } else {
                try func.store(result_ptr, payload, field_ty, 0);
                if (layout.tag_size > 0) {
                    try func.store(
                        result_ptr,
                        tag_int,
                        Type.fromInterned(union_obj.enum_tag_ty),
                        @intCast(layout.payload_size),
                    );
                }
            }
            break :result result_ptr;
        } else {
            const operand = try func.resolveInst(extra.init);
            const union_int_type = try mod.intType(.unsigned, @as(u16, @intCast(union_ty.bitSize(mod))));
            if (field_ty.zigTypeTag(mod) == .Float) {
                const int_type = try mod.intType(.unsigned, @intCast(field_ty.bitSize(mod)));
                const bitcasted = try func.bitcast(field_ty, int_type, operand);
                const casted = try func.trunc(bitcasted, int_type, union_int_type);
                break :result try casted.toLocal(func, field_ty);
            } else if (field_ty.isPtrAtRuntime(mod)) {
                const int_type = try mod.intType(.unsigned, @intCast(field_ty.bitSize(mod)));
                const casted = try func.intcast(operand, int_type, union_int_type);
                break :result try casted.toLocal(func, field_ty);
            }
            const casted = try func.intcast(operand, field_ty, union_int_type);
            break :result try casted.toLocal(func, field_ty);
        }
    };

    return func.finishAir(inst, result, &.{extra.init});
}

fn airPrefetch(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const prefetch = func.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    func.finishAir(inst, .none, &.{prefetch.ptr});
}

fn airWasmMemorySize(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;

    const result = try func.allocLocal(func.typeOfIndex(inst));
    try func.addLabel(.memory_size, pl_op.payload);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{pl_op.operand});
}

fn airWasmMemoryGrow(func: *CodeGen, inst: Air.Inst.Index) !void {
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;

    const operand = try func.resolveInst(pl_op.operand);
    const result = try func.allocLocal(func.typeOfIndex(inst));
    try func.emitWValue(operand);
    try func.addLabel(.memory_grow, pl_op.payload);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{pl_op.operand});
}

fn cmpOptionals(func: *CodeGen, lhs: WValue, rhs: WValue, operand_ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(operand_ty.hasRuntimeBitsIgnoreComptime(mod));
    assert(op == .eq or op == .neq);
    const payload_ty = operand_ty.optionalChild(mod);

    // We store the final result in here that will be validated
    // if the optional is truly equal.
    var result = try func.ensureAllocLocal(Type.i32);
    defer result.free(func);

    try func.startBlock(.block, wasm.block_empty);
    _ = try func.isNull(lhs, operand_ty, .i32_eq);
    _ = try func.isNull(rhs, operand_ty, .i32_eq);
    try func.addTag(.i32_ne); // inverse so we can exit early
    try func.addLabel(.br_if, 0);

    _ = try func.load(lhs, payload_ty, 0);
    _ = try func.load(rhs, payload_ty, 0);
    const opcode = buildOpcode(.{ .op = .ne, .valtype1 = typeToValtype(payload_ty, mod) });
    try func.addTag(Mir.Inst.Tag.fromOpcode(opcode));
    try func.addLabel(.br_if, 0);

    try func.addImm32(1);
    try func.addLabel(.local_set, result.local.value);
    try func.endBlock();

    try func.emitWValue(result);
    try func.addImm32(0);
    try func.addTag(if (op == .eq) .i32_ne else .i32_eq);
    return WValue{ .stack = {} };
}

/// Compares big integers by checking both its high bits and low bits.
/// NOTE: Leaves the result of the comparison on top of the stack.
/// TODO: Lower this to compiler_rt call when bitsize > 128
fn cmpBigInt(func: *CodeGen, lhs: WValue, rhs: WValue, operand_ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(operand_ty.abiSize(mod) >= 16);
    assert(!(lhs != .stack and rhs == .stack));
    if (operand_ty.bitSize(mod) > 128) {
        return func.fail("TODO: Support cmpBigInt for integer bitsize: '{d}'", .{operand_ty.bitSize(mod)});
    }

    var lhs_high_bit = try (try func.load(lhs, Type.u64, 0)).toLocal(func, Type.u64);
    defer lhs_high_bit.free(func);
    var rhs_high_bit = try (try func.load(rhs, Type.u64, 0)).toLocal(func, Type.u64);
    defer rhs_high_bit.free(func);

    switch (op) {
        .eq, .neq => {
            const xor_high = try func.binOp(lhs_high_bit, rhs_high_bit, Type.u64, .xor);
            const lhs_low_bit = try func.load(lhs, Type.u64, 8);
            const rhs_low_bit = try func.load(rhs, Type.u64, 8);
            const xor_low = try func.binOp(lhs_low_bit, rhs_low_bit, Type.u64, .xor);
            const or_result = try func.binOp(xor_high, xor_low, Type.u64, .@"or");

            switch (op) {
                .eq => return func.cmp(or_result, .{ .imm64 = 0 }, Type.u64, .eq),
                .neq => return func.cmp(or_result, .{ .imm64 = 0 }, Type.u64, .neq),
                else => unreachable,
            }
        },
        else => {
            const ty = if (operand_ty.isSignedInt(mod)) Type.i64 else Type.u64;
            // leave those value on top of the stack for '.select'
            const lhs_low_bit = try func.load(lhs, Type.u64, 8);
            const rhs_low_bit = try func.load(rhs, Type.u64, 8);
            _ = try func.cmp(lhs_low_bit, rhs_low_bit, ty, op);
            _ = try func.cmp(lhs_high_bit, rhs_high_bit, ty, op);
            _ = try func.cmp(lhs_high_bit, rhs_high_bit, ty, .eq);
            try func.addTag(.select);
        },
    }

    return WValue{ .stack = {} };
}

fn airSetUnionTag(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const un_ty = func.typeOf(bin_op.lhs).childType(mod);
    const tag_ty = func.typeOf(bin_op.rhs);
    const layout = un_ty.unionGetLayout(mod);
    if (layout.tag_size == 0) return func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });

    const union_ptr = try func.resolveInst(bin_op.lhs);
    const new_tag = try func.resolveInst(bin_op.rhs);
    if (layout.payload_size == 0) {
        try func.store(union_ptr, new_tag, tag_ty, 0);
        return func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
    }

    // when the tag alignment is smaller than the payload, the field will be stored
    // after the payload.
    const offset: u32 = if (layout.tag_align.compare(.lt, layout.payload_align)) blk: {
        break :blk @intCast(layout.payload_size);
    } else 0;
    try func.store(union_ptr, new_tag, tag_ty, offset);
    func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
}

fn airGetUnionTag(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const un_ty = func.typeOf(ty_op.operand);
    const tag_ty = func.typeOfIndex(inst);
    const layout = un_ty.unionGetLayout(mod);
    if (layout.tag_size == 0) return func.finishAir(inst, .none, &.{ty_op.operand});

    const operand = try func.resolveInst(ty_op.operand);
    // when the tag alignment is smaller than the payload, the field will be stored
    // after the payload.
    const offset: u32 = if (layout.tag_align.compare(.lt, layout.payload_align)) blk: {
        break :blk @intCast(layout.payload_size);
    } else 0;
    const tag = try func.load(operand, tag_ty, offset);
    const result = try tag.toLocal(func, tag_ty);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airFpext(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dest_ty = func.typeOfIndex(inst);
    const operand = try func.resolveInst(ty_op.operand);
    const extended = try func.fpext(operand, func.typeOf(ty_op.operand), dest_ty);
    const result = try extended.toLocal(func, dest_ty);
    func.finishAir(inst, result, &.{ty_op.operand});
}

/// Extends a float from a given `Type` to a larger wanted `Type`
/// NOTE: Leaves the result on the stack
fn fpext(func: *CodeGen, operand: WValue, given: Type, wanted: Type) InnerError!WValue {
    const given_bits = given.floatBits(func.target);
    const wanted_bits = wanted.floatBits(func.target);

    if (wanted_bits == 64 and given_bits == 32) {
        try func.emitWValue(operand);
        try func.addTag(.f64_promote_f32);
        return WValue{ .stack = {} };
    } else if (given_bits == 16 and wanted_bits <= 64) {
        // call __extendhfsf2(f16) f32
        const f32_result = try func.callIntrinsic(
            "__extendhfsf2",
            &.{.f16_type},
            Type.f32,
            &.{operand},
        );
        std.debug.assert(f32_result == .stack);

        if (wanted_bits == 64) {
            try func.addTag(.f64_promote_f32);
        }
        return WValue{ .stack = {} };
    }

    var fn_name_buf: [13]u8 = undefined;
    const fn_name = std.fmt.bufPrint(&fn_name_buf, "__extend{s}f{s}f2", .{
        target_util.compilerRtFloatAbbrev(given_bits),
        target_util.compilerRtFloatAbbrev(wanted_bits),
    }) catch unreachable;

    return func.callIntrinsic(fn_name, &.{given.ip_index}, wanted, &.{operand});
}

fn airFptrunc(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const dest_ty = func.typeOfIndex(inst);
    const operand = try func.resolveInst(ty_op.operand);
    const truncated = try func.fptrunc(operand, func.typeOf(ty_op.operand), dest_ty);
    const result = try truncated.toLocal(func, dest_ty);
    func.finishAir(inst, result, &.{ty_op.operand});
}

/// Truncates a float from a given `Type` to its wanted `Type`
/// NOTE: The result value remains on the stack
fn fptrunc(func: *CodeGen, operand: WValue, given: Type, wanted: Type) InnerError!WValue {
    const given_bits = given.floatBits(func.target);
    const wanted_bits = wanted.floatBits(func.target);

    if (wanted_bits == 32 and given_bits == 64) {
        try func.emitWValue(operand);
        try func.addTag(.f32_demote_f64);
        return WValue{ .stack = {} };
    } else if (wanted_bits == 16 and given_bits <= 64) {
        const op: WValue = if (given_bits == 64) blk: {
            try func.emitWValue(operand);
            try func.addTag(.f32_demote_f64);
            break :blk WValue{ .stack = {} };
        } else operand;

        // call __truncsfhf2(f32) f16
        return func.callIntrinsic("__truncsfhf2", &.{.f32_type}, Type.f16, &.{op});
    }

    var fn_name_buf: [12]u8 = undefined;
    const fn_name = std.fmt.bufPrint(&fn_name_buf, "__trunc{s}f{s}f2", .{
        target_util.compilerRtFloatAbbrev(given_bits),
        target_util.compilerRtFloatAbbrev(wanted_bits),
    }) catch unreachable;

    return func.callIntrinsic(fn_name, &.{given.ip_index}, wanted, &.{operand});
}

fn airErrUnionPayloadPtrSet(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const err_set_ty = func.typeOf(ty_op.operand).childType(mod);
    const payload_ty = err_set_ty.errorUnionPayload(mod);
    const operand = try func.resolveInst(ty_op.operand);

    // set error-tag to '0' to annotate error union is non-error
    try func.store(
        operand,
        .{ .imm32 = 0 },
        Type.anyerror,
        @as(u32, @intCast(errUnionErrorOffset(payload_ty, mod))),
    );

    const result = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
            break :result func.reuseOperand(ty_op.operand, operand);
        }

        break :result try func.buildPointerOffset(operand, @as(u32, @intCast(errUnionPayloadOffset(payload_ty, mod))), .new);
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airFieldParentPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const field_ptr = try func.resolveInst(extra.field_ptr);
    const parent_ty = ty_pl.ty.toType().childType(mod);
    const field_offset = parent_ty.structFieldOffset(extra.field_index, mod);

    const result = if (field_offset != 0) result: {
        const base = try func.buildPointerOffset(field_ptr, 0, .new);
        try func.addLabel(.local_get, base.local.value);
        try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(field_offset)))));
        try func.addTag(.i32_sub);
        try func.addLabel(.local_set, base.local.value);
        break :result base;
    } else func.reuseOperand(extra.field_ptr, field_ptr);

    func.finishAir(inst, result, &.{extra.field_ptr});
}

fn sliceOrArrayPtr(func: *CodeGen, ptr: WValue, ptr_ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    if (ptr_ty.isSlice(mod)) {
        return func.slicePtr(ptr);
    } else {
        return ptr;
    }
}

fn airMemcpy(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const dst = try func.resolveInst(bin_op.lhs);
    const dst_ty = func.typeOf(bin_op.lhs);
    const ptr_elem_ty = dst_ty.childType(mod);
    const src = try func.resolveInst(bin_op.rhs);
    const src_ty = func.typeOf(bin_op.rhs);
    const len = switch (dst_ty.ptrSize(mod)) {
        .Slice => blk: {
            const slice_len = try func.sliceLen(dst);
            if (ptr_elem_ty.abiSize(mod) != 1) {
                try func.emitWValue(slice_len);
                try func.emitWValue(.{ .imm32 = @as(u32, @intCast(ptr_elem_ty.abiSize(mod))) });
                try func.addTag(.i32_mul);
                try func.addLabel(.local_set, slice_len.local.value);
            }
            break :blk slice_len;
        },
        .One => @as(WValue, .{
            .imm32 = @as(u32, @intCast(ptr_elem_ty.arrayLen(mod) * ptr_elem_ty.childType(mod).abiSize(mod))),
        }),
        .C, .Many => unreachable,
    };
    const dst_ptr = try func.sliceOrArrayPtr(dst, dst_ty);
    const src_ptr = try func.sliceOrArrayPtr(src, src_ty);
    try func.memcpy(dst_ptr, src_ptr, len);

    func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
}

fn airRetAddr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    // TODO: Implement this properly once stack serialization is solved
    func.finishAir(inst, switch (func.arch()) {
        .wasm32 => .{ .imm32 = 0 },
        .wasm64 => .{ .imm64 = 0 },
        else => unreachable,
    }, &.{});
}

fn airPopcount(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const op_ty = func.typeOf(ty_op.operand);
    const result_ty = func.typeOfIndex(inst);

    if (op_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement @popCount for vectors", .{});
    }

    const int_info = op_ty.intInfo(mod);
    const bits = int_info.bits;
    const wasm_bits = toWasmBits(bits) orelse {
        return func.fail("TODO: Implement @popCount for integers with bitsize '{d}'", .{bits});
    };

    switch (wasm_bits) {
        128 => {
            _ = try func.load(operand, Type.u64, 0);
            try func.addTag(.i64_popcnt);
            _ = try func.load(operand, Type.u64, 8);
            try func.addTag(.i64_popcnt);
            try func.addTag(.i64_add);
            try func.addTag(.i32_wrap_i64);
        },
        else => {
            try func.emitWValue(operand);
            switch (wasm_bits) {
                32 => try func.addTag(.i32_popcnt),
                64 => {
                    try func.addTag(.i64_popcnt);
                    try func.addTag(.i32_wrap_i64);
                },
                else => unreachable,
            }
        },
    }

    const result = try func.allocLocal(result_ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airErrorName(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const operand = try func.resolveInst(un_op);
    // First retrieve the symbol index to the error name table
    // that will be used to emit a relocation for the pointer
    // to the error name table.
    //
    // Each entry to this table is a slice (ptr+len).
    // The operand in this instruction represents the index within this table.
    // This means to get the final name, we emit the base pointer and then perform
    // pointer arithmetic to find the pointer to this slice and return that.
    //
    // As the names are global and the slice elements are constant, we do not have
    // to make a copy of the ptr+value but can point towards them directly.
    const error_table_symbol = try func.bin_file.getErrorTableSymbol();
    const name_ty = Type.slice_const_u8_sentinel_0;
    const mod = func.bin_file.base.comp.module.?;
    const abi_size = name_ty.abiSize(mod);

    const error_name_value: WValue = .{ .memory = error_table_symbol }; // emitting this will create a relocation
    try func.emitWValue(error_name_value);
    try func.emitWValue(operand);
    switch (func.arch()) {
        .wasm32 => {
            try func.addImm32(@as(i32, @bitCast(@as(u32, @intCast(abi_size)))));
            try func.addTag(.i32_mul);
            try func.addTag(.i32_add);
        },
        .wasm64 => {
            try func.addImm64(abi_size);
            try func.addTag(.i64_mul);
            try func.addTag(.i64_add);
        },
        else => unreachable,
    }

    const result_ptr = try func.allocLocal(Type.usize);
    try func.addLabel(.local_set, result_ptr.local.value);
    func.finishAir(inst, result_ptr, &.{un_op});
}

fn airPtrSliceFieldPtr(func: *CodeGen, inst: Air.Inst.Index, offset: u32) InnerError!void {
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const slice_ptr = try func.resolveInst(ty_op.operand);
    const result = try func.buildPointerOffset(slice_ptr, offset, .new);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airAddSubWithOverflow(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    assert(op == .add or op == .sub);
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs_op = try func.resolveInst(extra.lhs);
    const rhs_op = try func.resolveInst(extra.rhs);
    const lhs_ty = func.typeOf(extra.lhs);
    const mod = func.bin_file.base.comp.module.?;

    if (lhs_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement overflow arithmetic for vectors", .{});
    }

    const int_info = lhs_ty.intInfo(mod);
    const is_signed = int_info.signedness == .signed;
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return func.fail("TODO: Implement {{add/sub}}_with_overflow for integer bitsize: {d}", .{int_info.bits});
    };

    if (wasm_bits == 128) {
        const result = try func.addSubWithOverflowBigInt(lhs_op, rhs_op, lhs_ty, func.typeOfIndex(inst), op);
        return func.finishAir(inst, result, &.{ extra.lhs, extra.rhs });
    }

    const zero = switch (wasm_bits) {
        32 => WValue{ .imm32 = 0 },
        64 => WValue{ .imm64 = 0 },
        else => unreachable,
    };

    // for signed integers, we first apply signed shifts by the difference in bits
    // to get the signed value, as we store it internally as 2's complement.
    var lhs = if (wasm_bits != int_info.bits and is_signed) blk: {
        break :blk try (try func.signExtendInt(lhs_op, lhs_ty)).toLocal(func, lhs_ty);
    } else lhs_op;
    var rhs = if (wasm_bits != int_info.bits and is_signed) blk: {
        break :blk try (try func.signExtendInt(rhs_op, lhs_ty)).toLocal(func, lhs_ty);
    } else rhs_op;

    // in this case, we performed a signExtendInt which created a temporary local
    // so let's free this so it can be re-used instead.
    // In the other case we do not want to free it, because that would free the
    // resolved instructions which may be referenced by other instructions.
    defer if (wasm_bits != int_info.bits and is_signed) {
        lhs.free(func);
        rhs.free(func);
    };

    const bin_op = try (try func.binOp(lhs, rhs, lhs_ty, op)).toLocal(func, lhs_ty);
    var result = if (wasm_bits != int_info.bits) blk: {
        break :blk try (try func.wrapOperand(bin_op, lhs_ty)).toLocal(func, lhs_ty);
    } else bin_op;
    defer result.free(func);

    const cmp_op: std.math.CompareOperator = if (op == .sub) .gt else .lt;
    const overflow_bit: WValue = if (is_signed) blk: {
        if (wasm_bits == int_info.bits) {
            const cmp_zero = try func.cmp(rhs, zero, lhs_ty, cmp_op);
            const lt = try func.cmp(bin_op, lhs, lhs_ty, .lt);
            break :blk try func.binOp(cmp_zero, lt, Type.u32, .xor);
        }
        const abs = try func.signExtendInt(bin_op, lhs_ty);
        break :blk try func.cmp(abs, bin_op, lhs_ty, .neq);
    } else if (wasm_bits == int_info.bits)
        try func.cmp(bin_op, lhs, lhs_ty, cmp_op)
    else
        try func.cmp(bin_op, result, lhs_ty, .neq);
    var overflow_local = try overflow_bit.toLocal(func, Type.u32);
    defer overflow_local.free(func);

    const result_ptr = try func.allocStack(func.typeOfIndex(inst));
    try func.store(result_ptr, result, lhs_ty, 0);
    const offset = @as(u32, @intCast(lhs_ty.abiSize(mod)));
    try func.store(result_ptr, overflow_local, Type.u1, offset);

    func.finishAir(inst, result_ptr, &.{ extra.lhs, extra.rhs });
}

fn addSubWithOverflowBigInt(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type, result_ty: Type, op: Op) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    assert(op == .add or op == .sub);
    const int_info = ty.intInfo(mod);
    const is_signed = int_info.signedness == .signed;
    if (int_info.bits != 128) {
        return func.fail("TODO: Implement @{{add/sub}}WithOverflow for integer bitsize '{d}'", .{int_info.bits});
    }

    var lhs_high_bit = try (try func.load(lhs, Type.u64, 0)).toLocal(func, Type.u64);
    defer lhs_high_bit.free(func);
    var lhs_low_bit = try (try func.load(lhs, Type.u64, 8)).toLocal(func, Type.u64);
    defer lhs_low_bit.free(func);
    var rhs_high_bit = try (try func.load(rhs, Type.u64, 0)).toLocal(func, Type.u64);
    defer rhs_high_bit.free(func);
    var rhs_low_bit = try (try func.load(rhs, Type.u64, 8)).toLocal(func, Type.u64);
    defer rhs_low_bit.free(func);

    var low_op_res = try (try func.binOp(lhs_low_bit, rhs_low_bit, Type.u64, op)).toLocal(func, Type.u64);
    defer low_op_res.free(func);
    var high_op_res = try (try func.binOp(lhs_high_bit, rhs_high_bit, Type.u64, op)).toLocal(func, Type.u64);
    defer high_op_res.free(func);

    var lt = if (op == .add) blk: {
        break :blk try (try func.cmp(high_op_res, lhs_high_bit, Type.u64, .lt)).toLocal(func, Type.u32);
    } else if (op == .sub) blk: {
        break :blk try (try func.cmp(lhs_high_bit, rhs_high_bit, Type.u64, .lt)).toLocal(func, Type.u32);
    } else unreachable;
    defer lt.free(func);
    var tmp = try (try func.intcast(lt, Type.u32, Type.u64)).toLocal(func, Type.u64);
    defer tmp.free(func);
    var tmp_op = try (try func.binOp(low_op_res, tmp, Type.u64, op)).toLocal(func, Type.u64);
    defer tmp_op.free(func);

    const overflow_bit = if (is_signed) blk: {
        const xor_low = try func.binOp(lhs_low_bit, rhs_low_bit, Type.u64, .xor);
        const to_wrap = if (op == .add) wrap: {
            break :wrap try func.binOp(xor_low, .{ .imm64 = ~@as(u64, 0) }, Type.u64, .xor);
        } else xor_low;
        const xor_op = try func.binOp(lhs_low_bit, tmp_op, Type.u64, .xor);
        const wrap = try func.binOp(to_wrap, xor_op, Type.u64, .@"and");
        break :blk try func.cmp(wrap, .{ .imm64 = 0 }, Type.i64, .lt); // i64 because signed
    } else blk: {
        const first_arg = if (op == .sub) arg: {
            break :arg try func.cmp(high_op_res, lhs_high_bit, Type.u64, .gt);
        } else lt;

        try func.emitWValue(first_arg);
        _ = try func.cmp(tmp_op, lhs_low_bit, Type.u64, if (op == .add) .lt else .gt);
        _ = try func.cmp(tmp_op, lhs_low_bit, Type.u64, .eq);
        try func.addTag(.select);

        break :blk WValue{ .stack = {} };
    };
    var overflow_local = try overflow_bit.toLocal(func, Type.u1);
    defer overflow_local.free(func);

    const result_ptr = try func.allocStack(result_ty);
    try func.store(result_ptr, high_op_res, Type.u64, 0);
    try func.store(result_ptr, tmp_op, Type.u64, 8);
    try func.store(result_ptr, overflow_local, Type.u1, 16);

    return result_ptr;
}

fn airShlWithOverflow(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try func.resolveInst(extra.lhs);
    const rhs = try func.resolveInst(extra.rhs);
    const lhs_ty = func.typeOf(extra.lhs);
    const rhs_ty = func.typeOf(extra.rhs);

    if (lhs_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement overflow arithmetic for vectors", .{});
    }

    const int_info = lhs_ty.intInfo(mod);
    const is_signed = int_info.signedness == .signed;
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return func.fail("TODO: Implement shl_with_overflow for integer bitsize: {d}", .{int_info.bits});
    };

    // Ensure rhs is coerced to lhs as they must have the same WebAssembly types
    // before we can perform any binary operation.
    const rhs_wasm_bits = toWasmBits(rhs_ty.intInfo(mod).bits).?;
    const rhs_final = if (wasm_bits != rhs_wasm_bits) blk: {
        const rhs_casted = try func.intcast(rhs, rhs_ty, lhs_ty);
        break :blk try rhs_casted.toLocal(func, lhs_ty);
    } else rhs;

    var shl = try (try func.binOp(lhs, rhs_final, lhs_ty, .shl)).toLocal(func, lhs_ty);
    defer shl.free(func);
    var result = if (wasm_bits != int_info.bits) blk: {
        break :blk try (try func.wrapOperand(shl, lhs_ty)).toLocal(func, lhs_ty);
    } else shl;
    defer result.free(func); // it's a no-op to free the same local twice (when wasm_bits == int_info.bits)

    const overflow_bit = if (wasm_bits != int_info.bits and is_signed) blk: {
        // emit lhs to stack to we can keep 'wrapped' on the stack also
        try func.emitWValue(lhs);
        const abs = try func.signExtendInt(shl, lhs_ty);
        const wrapped = try func.wrapBinOp(abs, rhs_final, lhs_ty, .shr);
        break :blk try func.cmp(.{ .stack = {} }, wrapped, lhs_ty, .neq);
    } else blk: {
        try func.emitWValue(lhs);
        const shr = try func.binOp(result, rhs_final, lhs_ty, .shr);
        break :blk try func.cmp(.{ .stack = {} }, shr, lhs_ty, .neq);
    };
    var overflow_local = try overflow_bit.toLocal(func, Type.u1);
    defer overflow_local.free(func);

    const result_ptr = try func.allocStack(func.typeOfIndex(inst));
    try func.store(result_ptr, result, lhs_ty, 0);
    const offset = @as(u32, @intCast(lhs_ty.abiSize(mod)));
    try func.store(result_ptr, overflow_local, Type.u1, offset);

    func.finishAir(inst, result_ptr, &.{ extra.lhs, extra.rhs });
}

fn airMulWithOverflow(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Bin, ty_pl.payload).data;

    const lhs = try func.resolveInst(extra.lhs);
    const rhs = try func.resolveInst(extra.rhs);
    const lhs_ty = func.typeOf(extra.lhs);
    const mod = func.bin_file.base.comp.module.?;

    if (lhs_ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: Implement overflow arithmetic for vectors", .{});
    }

    // We store the bit if it's overflowed or not in this. As it's zero-initialized
    // we only need to update it if an overflow (or underflow) occurred.
    var overflow_bit = try func.ensureAllocLocal(Type.u1);
    defer overflow_bit.free(func);

    const int_info = lhs_ty.intInfo(mod);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return func.fail("TODO: Implement `@mulWithOverflow` for integer bitsize: {d}", .{int_info.bits});
    };

    const zero = switch (wasm_bits) {
        32 => WValue{ .imm32 = 0 },
        64, 128 => WValue{ .imm64 = 0 },
        else => unreachable,
    };

    // for 32 bit integers we upcast it to a 64bit integer
    const bin_op = if (int_info.bits == 32) blk: {
        const new_ty = if (int_info.signedness == .signed) Type.i64 else Type.u64;
        const lhs_upcast = try func.intcast(lhs, lhs_ty, new_ty);
        const rhs_upcast = try func.intcast(rhs, lhs_ty, new_ty);
        const bin_op = try (try func.binOp(lhs_upcast, rhs_upcast, new_ty, .mul)).toLocal(func, new_ty);
        if (int_info.signedness == .unsigned) {
            const shr = try func.binOp(bin_op, .{ .imm64 = int_info.bits }, new_ty, .shr);
            const wrap = try func.intcast(shr, new_ty, lhs_ty);
            _ = try func.cmp(wrap, zero, lhs_ty, .neq);
            try func.addLabel(.local_set, overflow_bit.local.value);
            break :blk try func.intcast(bin_op, new_ty, lhs_ty);
        } else {
            const down_cast = try (try func.intcast(bin_op, new_ty, lhs_ty)).toLocal(func, lhs_ty);
            var shr = try (try func.binOp(down_cast, .{ .imm32 = int_info.bits - 1 }, lhs_ty, .shr)).toLocal(func, lhs_ty);
            defer shr.free(func);

            const shr_res = try func.binOp(bin_op, .{ .imm64 = int_info.bits }, new_ty, .shr);
            const down_shr_res = try func.intcast(shr_res, new_ty, lhs_ty);
            _ = try func.cmp(down_shr_res, shr, lhs_ty, .neq);
            try func.addLabel(.local_set, overflow_bit.local.value);
            break :blk down_cast;
        }
    } else if (int_info.signedness == .signed and wasm_bits == 32) blk: {
        const lhs_abs = try func.signExtendInt(lhs, lhs_ty);
        const rhs_abs = try func.signExtendInt(rhs, lhs_ty);
        const bin_op = try (try func.binOp(lhs_abs, rhs_abs, lhs_ty, .mul)).toLocal(func, lhs_ty);
        const mul_abs = try func.signExtendInt(bin_op, lhs_ty);
        _ = try func.cmp(mul_abs, bin_op, lhs_ty, .neq);
        try func.addLabel(.local_set, overflow_bit.local.value);
        break :blk try func.wrapOperand(bin_op, lhs_ty);
    } else if (wasm_bits == 32) blk: {
        var bin_op = try (try func.binOp(lhs, rhs, lhs_ty, .mul)).toLocal(func, lhs_ty);
        defer bin_op.free(func);
        const shift_imm = if (wasm_bits == 32)
            WValue{ .imm32 = int_info.bits }
        else
            WValue{ .imm64 = int_info.bits };
        const shr = try func.binOp(bin_op, shift_imm, lhs_ty, .shr);
        _ = try func.cmp(shr, zero, lhs_ty, .neq);
        try func.addLabel(.local_set, overflow_bit.local.value);
        break :blk try func.wrapOperand(bin_op, lhs_ty);
    } else if (int_info.bits == 64 and int_info.signedness == .unsigned) blk: {
        const new_ty = Type.u128;
        var lhs_upcast = try (try func.intcast(lhs, lhs_ty, new_ty)).toLocal(func, lhs_ty);
        defer lhs_upcast.free(func);
        var rhs_upcast = try (try func.intcast(rhs, lhs_ty, new_ty)).toLocal(func, lhs_ty);
        defer rhs_upcast.free(func);
        const bin_op = try func.binOp(lhs_upcast, rhs_upcast, new_ty, .mul);
        const lsb = try func.load(bin_op, lhs_ty, 8);
        _ = try func.cmp(lsb, zero, lhs_ty, .neq);
        try func.addLabel(.local_set, overflow_bit.local.value);

        break :blk try func.load(bin_op, lhs_ty, 0);
    } else if (int_info.bits == 64 and int_info.signedness == .signed) blk: {
        const shift_val: WValue = .{ .imm64 = 63 };
        var lhs_shifted = try (try func.binOp(lhs, shift_val, lhs_ty, .shr)).toLocal(func, lhs_ty);
        defer lhs_shifted.free(func);
        var rhs_shifted = try (try func.binOp(rhs, shift_val, lhs_ty, .shr)).toLocal(func, lhs_ty);
        defer rhs_shifted.free(func);

        const bin_op = try func.callIntrinsic(
            "__multi3",
            &[_]InternPool.Index{.i64_type} ** 4,
            Type.i128,
            &.{ lhs, lhs_shifted, rhs, rhs_shifted },
        );
        const res = try func.allocLocal(lhs_ty);
        const msb = try func.load(bin_op, lhs_ty, 0);
        try func.addLabel(.local_tee, res.local.value);
        const msb_shifted = try func.binOp(msb, shift_val, lhs_ty, .shr);
        const lsb = try func.load(bin_op, lhs_ty, 8);
        _ = try func.cmp(lsb, msb_shifted, lhs_ty, .neq);
        try func.addLabel(.local_set, overflow_bit.local.value);
        break :blk res;
    } else if (int_info.bits == 128 and int_info.signedness == .unsigned) blk: {
        var lhs_msb = try (try func.load(lhs, Type.u64, 0)).toLocal(func, Type.u64);
        defer lhs_msb.free(func);
        var lhs_lsb = try (try func.load(lhs, Type.u64, 8)).toLocal(func, Type.u64);
        defer lhs_lsb.free(func);
        var rhs_msb = try (try func.load(rhs, Type.u64, 0)).toLocal(func, Type.u64);
        defer rhs_msb.free(func);
        var rhs_lsb = try (try func.load(rhs, Type.u64, 8)).toLocal(func, Type.u64);
        defer rhs_lsb.free(func);

        const mul1 = try func.callIntrinsic(
            "__multi3",
            &[_]InternPool.Index{.i64_type} ** 4,
            Type.i128,
            &.{ lhs_lsb, zero, rhs_msb, zero },
        );
        const mul2 = try func.callIntrinsic(
            "__multi3",
            &[_]InternPool.Index{.i64_type} ** 4,
            Type.i128,
            &.{ rhs_lsb, zero, lhs_msb, zero },
        );
        const mul3 = try func.callIntrinsic(
            "__multi3",
            &[_]InternPool.Index{.i64_type} ** 4,
            Type.i128,
            &.{ lhs_msb, zero, rhs_msb, zero },
        );

        const rhs_lsb_not_zero = try func.cmp(rhs_lsb, zero, Type.u64, .neq);
        const lhs_lsb_not_zero = try func.cmp(lhs_lsb, zero, Type.u64, .neq);
        const lsb_and = try func.binOp(rhs_lsb_not_zero, lhs_lsb_not_zero, Type.bool, .@"and");
        const mul1_lsb = try func.load(mul1, Type.u64, 8);
        const mul1_lsb_not_zero = try func.cmp(mul1_lsb, zero, Type.u64, .neq);
        const lsb_or1 = try func.binOp(lsb_and, mul1_lsb_not_zero, Type.bool, .@"or");
        const mul2_lsb = try func.load(mul2, Type.u64, 8);
        const mul2_lsb_not_zero = try func.cmp(mul2_lsb, zero, Type.u64, .neq);
        const lsb_or = try func.binOp(lsb_or1, mul2_lsb_not_zero, Type.bool, .@"or");

        const mul1_msb = try func.load(mul1, Type.u64, 0);
        const mul2_msb = try func.load(mul2, Type.u64, 0);
        const mul_add1 = try func.binOp(mul1_msb, mul2_msb, Type.u64, .add);

        var mul3_lsb = try (try func.load(mul3, Type.u64, 8)).toLocal(func, Type.u64);
        defer mul3_lsb.free(func);
        var mul_add2 = try (try func.binOp(mul_add1, mul3_lsb, Type.u64, .add)).toLocal(func, Type.u64);
        defer mul_add2.free(func);
        const mul_add_lt = try func.cmp(mul_add2, mul3_lsb, Type.u64, .lt);

        // result for overflow bit
        _ = try func.binOp(lsb_or, mul_add_lt, Type.bool, .@"or");
        try func.addLabel(.local_set, overflow_bit.local.value);

        const tmp_result = try func.allocStack(Type.u128);
        try func.emitWValue(tmp_result);
        const mul3_msb = try func.load(mul3, Type.u64, 0);
        try func.store(.stack, mul3_msb, Type.u64, tmp_result.offset());
        try func.store(tmp_result, mul_add2, Type.u64, 8);
        break :blk tmp_result;
    } else return func.fail("TODO: @mulWithOverflow for integers between 32 and 64 bits", .{});
    var bin_op_local = try bin_op.toLocal(func, lhs_ty);
    defer bin_op_local.free(func);

    const result_ptr = try func.allocStack(func.typeOfIndex(inst));
    try func.store(result_ptr, bin_op_local, lhs_ty, 0);
    const offset = @as(u32, @intCast(lhs_ty.abiSize(mod)));
    try func.store(result_ptr, overflow_bit, Type.u1, offset);

    func.finishAir(inst, result_ptr, &.{ extra.lhs, extra.rhs });
}

fn airMaxMin(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    assert(op == .max or op == .min);
    const mod = func.bin_file.base.comp.module.?;
    const target = mod.getTarget();
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ty = func.typeOfIndex(inst);
    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: `@maximum` and `@minimum` for vectors", .{});
    }

    if (ty.abiSize(mod) > 16) {
        return func.fail("TODO: `@maximum` and `@minimum` for types larger than 16 bytes", .{});
    }

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    if (ty.zigTypeTag(mod) == .Float) {
        var fn_name_buf: [64]u8 = undefined;
        const float_bits = ty.floatBits(target);
        const fn_name = std.fmt.bufPrint(&fn_name_buf, "{s}f{s}{s}", .{
            target_util.libcFloatPrefix(float_bits),
            @tagName(op),
            target_util.libcFloatSuffix(float_bits),
        }) catch unreachable;
        const result = try func.callIntrinsic(fn_name, &.{ ty.ip_index, ty.ip_index }, ty, &.{ lhs, rhs });
        try func.lowerToStack(result);
    } else {
        // operands to select from
        try func.lowerToStack(lhs);
        try func.lowerToStack(rhs);
        _ = try func.cmp(lhs, rhs, ty, if (op == .max) .gt else .lt);

        // based on the result from comparison, return operand 0 or 1.
        try func.addTag(.select);
    }

    // store result in local
    const result_ty = if (isByRef(ty, mod)) Type.u32 else ty;
    const result = try func.allocLocal(result_ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airMulAdd(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const bin_op = func.air.extraData(Air.Bin, pl_op.payload).data;

    const ty = func.typeOfIndex(inst);
    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: `@mulAdd` for vectors", .{});
    }

    const addend = try func.resolveInst(pl_op.operand);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    const result = if (ty.floatBits(func.target) == 16) fl_result: {
        const rhs_ext = try func.fpext(rhs, ty, Type.f32);
        const lhs_ext = try func.fpext(lhs, ty, Type.f32);
        const addend_ext = try func.fpext(addend, ty, Type.f32);
        // call to compiler-rt `fn fmaf(f32, f32, f32) f32`
        const result = try func.callIntrinsic(
            "fmaf",
            &.{ .f32_type, .f32_type, .f32_type },
            Type.f32,
            &.{ rhs_ext, lhs_ext, addend_ext },
        );
        break :fl_result try (try func.fptrunc(result, Type.f32, ty)).toLocal(func, ty);
    } else result: {
        const mul_result = try func.binOp(lhs, rhs, ty, .mul);
        break :result try (try func.binOp(mul_result, addend, ty, .add)).toLocal(func, ty);
    };

    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs, pl_op.operand });
}

fn airClz(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ty = func.typeOf(ty_op.operand);
    const result_ty = func.typeOfIndex(inst);
    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: `@clz` for vectors", .{});
    }

    const operand = try func.resolveInst(ty_op.operand);
    const int_info = ty.intInfo(mod);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return func.fail("TODO: `@clz` for integers with bitsize '{d}'", .{int_info.bits});
    };

    switch (wasm_bits) {
        32 => {
            try func.emitWValue(operand);
            try func.addTag(.i32_clz);
        },
        64 => {
            try func.emitWValue(operand);
            try func.addTag(.i64_clz);
            try func.addTag(.i32_wrap_i64);
        },
        128 => {
            var lsb = try (try func.load(operand, Type.u64, 8)).toLocal(func, Type.u64);
            defer lsb.free(func);

            try func.emitWValue(lsb);
            try func.addTag(.i64_clz);
            _ = try func.load(operand, Type.u64, 0);
            try func.addTag(.i64_clz);
            try func.emitWValue(.{ .imm64 = 64 });
            try func.addTag(.i64_add);
            _ = try func.cmp(lsb, .{ .imm64 = 0 }, Type.u64, .neq);
            try func.addTag(.select);
            try func.addTag(.i32_wrap_i64);
        },
        else => unreachable,
    }

    if (wasm_bits != int_info.bits) {
        try func.emitWValue(.{ .imm32 = wasm_bits - int_info.bits });
        try func.addTag(.i32_sub);
    }

    const result = try func.allocLocal(result_ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airCtz(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ty = func.typeOf(ty_op.operand);
    const result_ty = func.typeOfIndex(inst);

    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: `@ctz` for vectors", .{});
    }

    const operand = try func.resolveInst(ty_op.operand);
    const int_info = ty.intInfo(mod);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return func.fail("TODO: `@clz` for integers with bitsize '{d}'", .{int_info.bits});
    };

    switch (wasm_bits) {
        32 => {
            if (wasm_bits != int_info.bits) {
                const val: u32 = @as(u32, 1) << @as(u5, @intCast(int_info.bits));
                // leave value on the stack
                _ = try func.binOp(operand, .{ .imm32 = val }, ty, .@"or");
            } else try func.emitWValue(operand);
            try func.addTag(.i32_ctz);
        },
        64 => {
            if (wasm_bits != int_info.bits) {
                const val: u64 = @as(u64, 1) << @as(u6, @intCast(int_info.bits));
                // leave value on the stack
                _ = try func.binOp(operand, .{ .imm64 = val }, ty, .@"or");
            } else try func.emitWValue(operand);
            try func.addTag(.i64_ctz);
            try func.addTag(.i32_wrap_i64);
        },
        128 => {
            var msb = try (try func.load(operand, Type.u64, 0)).toLocal(func, Type.u64);
            defer msb.free(func);

            try func.emitWValue(msb);
            try func.addTag(.i64_ctz);
            _ = try func.load(operand, Type.u64, 8);
            if (wasm_bits != int_info.bits) {
                try func.addImm64(@as(u64, 1) << @as(u6, @intCast(int_info.bits - 64)));
                try func.addTag(.i64_or);
            }
            try func.addTag(.i64_ctz);
            try func.addImm64(64);
            if (wasm_bits != int_info.bits) {
                try func.addTag(.i64_or);
            } else {
                try func.addTag(.i64_add);
            }
            _ = try func.cmp(msb, .{ .imm64 = 0 }, Type.u64, .neq);
            try func.addTag(.select);
            try func.addTag(.i32_wrap_i64);
        },
        else => unreachable,
    }

    const result = try func.allocLocal(result_ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airDbgStmt(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    if (func.debug_output != .dwarf) return func.finishAir(inst, .none, &.{});

    const dbg_stmt = func.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;
    try func.addInst(.{ .tag = .dbg_line, .data = .{
        .payload = try func.addExtra(Mir.DbgLineColumn{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        }),
    } });
    func.finishAir(inst, .none, &.{});
}

fn airDbgInlineBlock(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    // TODO
    try func.lowerBlock(inst, ty_pl.ty.toType(), @ptrCast(func.air.extra[extra.end..][0..extra.data.body_len]));
}

fn airDbgVar(func: *CodeGen, inst: Air.Inst.Index, is_ptr: bool) InnerError!void {
    if (func.debug_output != .dwarf) return func.finishAir(inst, .none, &.{});

    const mod = func.bin_file.base.comp.module.?;
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const ty = func.typeOf(pl_op.operand);
    const operand = try func.resolveInst(pl_op.operand);

    log.debug("airDbgVar: %{d}: {}, {}", .{ inst, ty.fmtDebug(), operand });

    const name = func.air.nullTerminatedString(pl_op.payload);
    log.debug(" var name = ({s})", .{name});

    const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (operand) {
        .local => |local| .{ .wasm_local = local.value },
        else => blk: {
            log.debug("TODO generate debug info for {}", .{operand});
            break :blk .nop;
        },
    };
    try func.debug_output.dwarf.genVarDbgInfo(name, ty, mod.funcOwnerDeclIndex(func.func_index), is_ptr, loc);

    func.finishAir(inst, .none, &.{});
}

fn airTry(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const err_union = try func.resolveInst(pl_op.operand);
    const extra = func.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(func.air.extra[extra.end..][0..extra.data.body_len]);
    const err_union_ty = func.typeOf(pl_op.operand);
    const result = try lowerTry(func, inst, err_union, body, err_union_ty, false);
    func.finishAir(inst, result, &.{pl_op.operand});
}

fn airTryPtr(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.TryPtr, ty_pl.payload);
    const err_union_ptr = try func.resolveInst(extra.data.ptr);
    const body: []const Air.Inst.Index = @ptrCast(func.air.extra[extra.end..][0..extra.data.body_len]);
    const err_union_ty = func.typeOf(extra.data.ptr).childType(mod);
    const result = try lowerTry(func, inst, err_union_ptr, body, err_union_ty, true);
    func.finishAir(inst, result, &.{extra.data.ptr});
}

fn lowerTry(
    func: *CodeGen,
    inst: Air.Inst.Index,
    err_union: WValue,
    body: []const Air.Inst.Index,
    err_union_ty: Type,
    operand_is_ptr: bool,
) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    if (operand_is_ptr) {
        return func.fail("TODO: lowerTry for pointers", .{});
    }

    const pl_ty = err_union_ty.errorUnionPayload(mod);
    const pl_has_bits = pl_ty.hasRuntimeBitsIgnoreComptime(mod);

    if (!err_union_ty.errorUnionSet(mod).errorSetIsEmpty(mod)) {
        // Block we can jump out of when error is not set
        try func.startBlock(.block, wasm.block_empty);

        // check if the error tag is set for the error union.
        try func.emitWValue(err_union);
        if (pl_has_bits) {
            const err_offset = @as(u32, @intCast(errUnionErrorOffset(pl_ty, mod)));
            try func.addMemArg(.i32_load16_u, .{
                .offset = err_union.offset() + err_offset,
                .alignment = @intCast(Type.anyerror.abiAlignment(mod).toByteUnits().?),
            });
        }
        try func.addTag(.i32_eqz);
        try func.addLabel(.br_if, 0); // jump out of block when error is '0'

        const liveness = func.liveness.getCondBr(inst);
        try func.branches.append(func.gpa, .{});
        try func.currentBranch().values.ensureUnusedCapacity(func.gpa, liveness.else_deaths.len + liveness.then_deaths.len);
        defer {
            var branch = func.branches.pop();
            branch.deinit(func.gpa);
        }
        try func.genBody(body);
        try func.endBlock();
    }

    // if we reach here it means error was not set, and we want the payload
    if (!pl_has_bits) {
        return WValue{ .none = {} };
    }

    const pl_offset = @as(u32, @intCast(errUnionPayloadOffset(pl_ty, mod)));
    if (isByRef(pl_ty, mod)) {
        return buildPointerOffset(func, err_union, pl_offset, .new);
    }
    const payload = try func.load(err_union, pl_ty, pl_offset);
    return payload.toLocal(func, pl_ty);
}

fn airByteSwap(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const ty = func.typeOfIndex(inst);
    const operand = try func.resolveInst(ty_op.operand);

    if (ty.zigTypeTag(mod) == .Vector) {
        return func.fail("TODO: @byteSwap for vectors", .{});
    }
    const int_info = ty.intInfo(mod);

    // bytes are no-op
    if (int_info.bits == 8) {
        return func.finishAir(inst, func.reuseOperand(ty_op.operand, operand), &.{ty_op.operand});
    }

    const result = result: {
        switch (int_info.bits) {
            16 => {
                const shl_res = try func.binOp(operand, .{ .imm32 = 8 }, ty, .shl);
                const lhs = try func.binOp(shl_res, .{ .imm32 = 0xFF00 }, ty, .@"and");
                const shr_res = try func.binOp(operand, .{ .imm32 = 8 }, ty, .shr);
                const res = if (int_info.signedness == .signed) blk: {
                    break :blk try func.wrapOperand(shr_res, Type.u8);
                } else shr_res;
                break :result try (try func.binOp(lhs, res, ty, .@"or")).toLocal(func, ty);
            },
            24 => {
                var msb = try (try func.wrapOperand(operand, Type.u16)).toLocal(func, Type.u16);
                defer msb.free(func);

                const shl_res = try func.binOp(msb, .{ .imm32 = 8 }, Type.u16, .shl);
                const lhs = try func.binOp(shl_res, .{ .imm32 = 0xFF0000 }, Type.u16, .@"and");
                const shr_res = try func.binOp(msb, .{ .imm32 = 8 }, ty, .shr);

                const res = if (int_info.signedness == .signed) blk: {
                    break :blk try func.wrapOperand(shr_res, Type.u8);
                } else shr_res;
                const lhs_tmp = try func.binOp(lhs, res, ty, .@"or");
                const lhs_result = try func.binOp(lhs_tmp, .{ .imm32 = 8 }, ty, .shr);
                const rhs_wrap = try func.wrapOperand(msb, Type.u8);
                const rhs_result = try func.binOp(rhs_wrap, .{ .imm32 = 16 }, ty, .shl);

                const lsb = try func.wrapBinOp(operand, .{ .imm32 = 16 }, Type.u8, .shr);
                const tmp = try func.binOp(lhs_result, rhs_result, ty, .@"or");
                break :result try (try func.binOp(tmp, lsb, ty, .@"or")).toLocal(func, ty);
            },
            32 => {
                const shl_tmp = try func.binOp(operand, .{ .imm32 = 8 }, Type.u32, .shl);
                const lhs = try func.binOp(shl_tmp, .{ .imm32 = 0xFF00FF00 }, Type.u32, .@"and");
                const shr_tmp = try func.binOp(operand, .{ .imm32 = 8 }, Type.u32, .shr);
                const rhs = try func.binOp(shr_tmp, .{ .imm32 = 0x00FF00FF }, Type.u32, .@"and");
                var tmp_or = try (try func.binOp(lhs, rhs, Type.u32, .@"or")).toLocal(func, Type.u32);

                const shl = try func.binOp(tmp_or, .{ .imm32 = 16 }, Type.u32, .shl);
                const shr = try func.binOp(tmp_or, .{ .imm32 = 16 }, Type.u32, .shr);

                tmp_or.free(func);

                break :result try (try func.binOp(shl, shr, Type.u32, .@"or")).toLocal(func, Type.u32);
            },
            64 => {
                const shl_tmp_1 = try func.binOp(operand, .{ .imm64 = 8 }, Type.u64, .shl);
                const lhs_1 = try func.binOp(shl_tmp_1, .{ .imm64 = 0xFF00FF00FF00FF00 }, Type.u64, .@"and");

                const shr_tmp_1 = try func.binOp(operand, .{ .imm64 = 8 }, Type.u64, .shr);
                const rhs_1 = try func.binOp(shr_tmp_1, .{ .imm64 = 0x00FF00FF00FF00FF }, Type.u64, .@"and");

                var tmp_or_1 = try (try func.binOp(lhs_1, rhs_1, Type.u64, .@"or")).toLocal(func, Type.u64);

                const shl_tmp_2 = try func.binOp(tmp_or_1, .{ .imm64 = 16 }, Type.u64, .shl);
                const lhs_2 = try func.binOp(shl_tmp_2, .{ .imm64 = 0xFFFF0000FFFF0000 }, Type.u64, .@"and");

                const shr_tmp_2 = try func.binOp(tmp_or_1, .{ .imm64 = 16 }, Type.u64, .shr);
                tmp_or_1.free(func);
                const rhs_2 = try func.binOp(shr_tmp_2, .{ .imm64 = 0x0000FFFF0000FFFF }, Type.u64, .@"and");

                var tmp_or_2 = try (try func.binOp(lhs_2, rhs_2, Type.u64, .@"or")).toLocal(func, Type.u64);

                const shl = try func.binOp(tmp_or_2, .{ .imm64 = 32 }, Type.u64, .shl);
                const shr = try func.binOp(tmp_or_2, .{ .imm64 = 32 }, Type.u64, .shr);
                tmp_or_2.free(func);

                break :result try (try func.binOp(shl, shr, Type.u64, .@"or")).toLocal(func, Type.u64);
            },
            else => return func.fail("TODO: @byteSwap for integers with bitsize {d}", .{int_info.bits}),
        }
    };
    func.finishAir(inst, result, &.{ty_op.operand});
}

fn airDiv(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ty = func.typeOfIndex(inst);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    const result = if (ty.isSignedInt(mod))
        try func.divSigned(lhs, rhs, ty)
    else
        try (try func.binOp(lhs, rhs, ty, .div)).toLocal(func, ty);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airDivTrunc(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ty = func.typeOfIndex(inst);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    const div_result = if (ty.isSignedInt(mod))
        try func.divSigned(lhs, rhs, ty)
    else
        try (try func.binOp(lhs, rhs, ty, .div)).toLocal(func, ty);

    if (ty.isAnyFloat()) {
        const trunc_result = try (try func.floatOp(.trunc, ty, &.{div_result})).toLocal(func, ty);
        return func.finishAir(inst, trunc_result, &.{ bin_op.lhs, bin_op.rhs });
    }

    return func.finishAir(inst, div_result, &.{ bin_op.lhs, bin_op.rhs });
}

fn airDivFloor(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const mod = func.bin_file.base.comp.module.?;
    const ty = func.typeOfIndex(inst);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    if (ty.isUnsignedInt(mod)) {
        _ = try func.binOp(lhs, rhs, ty, .div);
    } else if (ty.isSignedInt(mod)) {
        const int_bits = ty.intInfo(mod).bits;
        const wasm_bits = toWasmBits(int_bits) orelse {
            return func.fail("TODO: `@divFloor` for signed integers larger than 64 bits ({d} bits requested)", .{int_bits});
        };

        if (wasm_bits > 64) {
            return func.fail("TODO: `@divFloor` for signed integers larger than 64 bits ({d} bits requested)", .{int_bits});
        }

        const lhs_wasm = if (wasm_bits != int_bits)
            try (try func.signExtendInt(lhs, ty)).toLocal(func, ty)
        else
            lhs;

        const rhs_wasm = if (wasm_bits != int_bits)
            try (try func.signExtendInt(rhs, ty)).toLocal(func, ty)
        else
            rhs;

        const zero = switch (wasm_bits) {
            32 => WValue{ .imm32 = 0 },
            64 => WValue{ .imm64 = 0 },
            else => unreachable,
        };

        // tee leaves the value on the stack and stores it in a local.
        const quotient = try func.allocLocal(ty);
        _ = try func.binOp(lhs_wasm, rhs_wasm, ty, .div);
        try func.addLabel(.local_tee, quotient.local.value);

        // select takes a 32 bit value as the condition, so in the 64 bit case we use eqz to narrow
        // the 64 bit value we want to use as the condition to 32 bits.
        // This also inverts the condition (non 0 => 0, 0 => 1), so we put the adjusted and
        // non-adjusted quotients on the stack in the opposite order for 32 vs 64 bits.
        if (wasm_bits == 64) {
            try func.emitWValue(quotient);
        }

        // 0 if the signs of rhs_wasm and lhs_wasm are the same, 1 otherwise.
        _ = try func.binOp(lhs_wasm, rhs_wasm, ty, .xor);
        _ = try func.cmp(.stack, zero, ty, .lt);

        switch (wasm_bits) {
            32 => {
                try func.addTag(.i32_sub);
                try func.emitWValue(quotient);
            },
            64 => {
                try func.addTag(.i64_extend_i32_u);
                try func.addTag(.i64_sub);
            },
            else => unreachable,
        }

        _ = try func.binOp(lhs_wasm, rhs_wasm, ty, .rem);

        if (wasm_bits == 64) {
            try func.addTag(.i64_eqz);
        }

        try func.addTag(.select);

        // We need to zero the high bits because N bit comparisons consider all 32 or 64 bits, and
        // expect all but the lowest N bits to be 0.
        // TODO: Should we be zeroing the high bits here or should we be ignoring the high bits
        // when performing comparisons?
        if (int_bits != wasm_bits) {
            _ = try func.wrapOperand(.{ .stack = {} }, ty);
        }
    } else {
        const float_bits = ty.floatBits(func.target);
        if (float_bits > 64) {
            return func.fail("TODO: `@divFloor` for floats with bitsize: {d}", .{float_bits});
        }
        const is_f16 = float_bits == 16;

        const lhs_wasm = if (is_f16) try func.fpext(lhs, Type.f16, Type.f32) else lhs;
        const rhs_wasm = if (is_f16) try func.fpext(rhs, Type.f16, Type.f32) else rhs;

        try func.emitWValue(lhs_wasm);
        try func.emitWValue(rhs_wasm);

        switch (float_bits) {
            16, 32 => {
                try func.addTag(.f32_div);
                try func.addTag(.f32_floor);
            },
            64 => {
                try func.addTag(.f64_div);
                try func.addTag(.f64_floor);
            },
            else => unreachable,
        }

        if (is_f16) {
            _ = try func.fptrunc(.{ .stack = {} }, Type.f32, Type.f16);
        }
    }

    const result = try func.allocLocal(ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn divSigned(func: *CodeGen, lhs: WValue, rhs: WValue, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const int_bits = ty.intInfo(mod).bits;
    const wasm_bits = toWasmBits(int_bits) orelse {
        return func.fail("TODO: Implement signed division for integers with bitsize '{d}'", .{int_bits});
    };

    if (wasm_bits == 128) {
        return func.fail("TODO: Implement signed division for 128-bit integerrs", .{});
    }

    if (wasm_bits != int_bits) {
        // Leave both values on the stack
        _ = try func.signExtendInt(lhs, ty);
        _ = try func.signExtendInt(rhs, ty);
    } else {
        try func.emitWValue(lhs);
        try func.emitWValue(rhs);
    }
    try func.addTag(.i32_div_s);

    const result = try func.allocLocal(ty);
    try func.addLabel(.local_set, result.local.value);
    return result;
}

/// Remainder after floor division, defined by:
/// @divFloor(a, b) * b + @mod(a, b) = a
fn airMod(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const mod = func.bin_file.base.comp.module.?;
    const ty = func.typeOfIndex(inst);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    if (ty.isUnsignedInt(mod)) {
        _ = try func.binOp(lhs, rhs, ty, .rem);
    } else if (ty.isSignedInt(mod)) {
        // The wasm rem instruction gives the remainder after truncating division (rounding towards
        // 0), equivalent to @rem.
        // We make use of the fact that:
        // @mod(a, b) = @rem(@rem(a, b) + b, b)
        const int_bits = ty.intInfo(mod).bits;
        const wasm_bits = toWasmBits(int_bits) orelse {
            return func.fail("TODO: `@mod` for signed integers larger than 64 bits ({d} bits requested)", .{int_bits});
        };

        if (wasm_bits > 64) {
            return func.fail("TODO: `@mod` for signed integers larger than 64 bits ({d} bits requested)", .{int_bits});
        }

        const lhs_wasm = if (wasm_bits != int_bits)
            try (try func.signExtendInt(lhs, ty)).toLocal(func, ty)
        else
            lhs;

        const rhs_wasm = if (wasm_bits != int_bits)
            try (try func.signExtendInt(rhs, ty)).toLocal(func, ty)
        else
            rhs;

        _ = try func.binOp(lhs_wasm, rhs_wasm, ty, .rem);
        _ = try func.binOp(.stack, rhs_wasm, ty, .add);
        _ = try func.binOp(.stack, rhs_wasm, ty, .rem);
    } else {
        return func.fail("TODO: implement `@mod` on floating point types for {}", .{func.target.cpu.arch});
    }

    const result = try func.allocLocal(ty);
    try func.addLabel(.local_set, result.local.value);
    func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

/// Sign extends an N bit signed integer and pushes the result to the stack.
/// The result will be sign extended to 32 bits if N <= 32 or 64 bits if N <= 64.
/// Support for integers wider than 64 bits has not yet been implemented.
fn signExtendInt(func: *CodeGen, operand: WValue, ty: Type) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const int_bits = ty.intInfo(mod).bits;
    const wasm_bits = toWasmBits(int_bits) orelse {
        return func.fail("TODO: signExtendInt for signed integers larger than '{d}' bits", .{int_bits});
    };

    const shift_val = switch (wasm_bits) {
        32 => WValue{ .imm32 = wasm_bits - int_bits },
        64 => WValue{ .imm64 = wasm_bits - int_bits },
        else => return func.fail("TODO: signExtendInt for i128", .{}),
    };

    try func.emitWValue(operand);
    switch (wasm_bits) {
        32 => {
            try func.emitWValue(shift_val);
            try func.addTag(.i32_shl);
            try func.emitWValue(shift_val);
            try func.addTag(.i32_shr_s);
        },
        64 => {
            try func.emitWValue(shift_val);
            try func.addTag(.i64_shl);
            try func.emitWValue(shift_val);
            try func.addTag(.i64_shr_s);
        },
        else => unreachable,
    }

    return WValue{ .stack = {} };
}

fn airSatBinOp(func: *CodeGen, inst: Air.Inst.Index, op: Op) InnerError!void {
    assert(op == .add or op == .sub);
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const mod = func.bin_file.base.comp.module.?;
    const ty = func.typeOfIndex(inst);
    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);

    const int_info = ty.intInfo(mod);
    const is_signed = int_info.signedness == .signed;

    if (int_info.bits > 64) {
        return func.fail("TODO: saturating arithmetic for integers with bitsize '{d}'", .{int_info.bits});
    }

    if (is_signed) {
        const result = try signedSat(func, lhs, rhs, ty, op);
        return func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
    }

    const wasm_bits = toWasmBits(int_info.bits).?;
    var bin_result = try (try func.binOp(lhs, rhs, ty, op)).toLocal(func, ty);
    defer bin_result.free(func);
    if (wasm_bits != int_info.bits and op == .add) {
        const val: u64 = @as(u64, @intCast((@as(u65, 1) << @as(u7, @intCast(int_info.bits))) - 1));
        const imm_val = switch (wasm_bits) {
            32 => WValue{ .imm32 = @as(u32, @intCast(val)) },
            64 => WValue{ .imm64 = val },
            else => unreachable,
        };

        try func.emitWValue(bin_result);
        try func.emitWValue(imm_val);
        _ = try func.cmp(bin_result, imm_val, ty, .lt);
    } else {
        switch (wasm_bits) {
            32 => try func.addImm32(if (op == .add) @as(i32, -1) else 0),
            64 => try func.addImm64(if (op == .add) @as(u64, @bitCast(@as(i64, -1))) else 0),
            else => unreachable,
        }
        try func.emitWValue(bin_result);
        _ = try func.cmp(bin_result, lhs, ty, if (op == .add) .lt else .gt);
    }

    try func.addTag(.select);
    const result = try func.allocLocal(ty);
    try func.addLabel(.local_set, result.local.value);
    return func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

fn signedSat(func: *CodeGen, lhs_operand: WValue, rhs_operand: WValue, ty: Type, op: Op) InnerError!WValue {
    const mod = func.bin_file.base.comp.module.?;
    const int_info = ty.intInfo(mod);
    const wasm_bits = toWasmBits(int_info.bits).?;
    const is_wasm_bits = wasm_bits == int_info.bits;
    const ext_ty = if (!is_wasm_bits) try mod.intType(int_info.signedness, wasm_bits) else ty;

    var lhs = if (!is_wasm_bits) lhs: {
        break :lhs try (try func.signExtendInt(lhs_operand, ty)).toLocal(func, ext_ty);
    } else lhs_operand;
    var rhs = if (!is_wasm_bits) rhs: {
        break :rhs try (try func.signExtendInt(rhs_operand, ty)).toLocal(func, ext_ty);
    } else rhs_operand;

    const max_val: u64 = @as(u64, @intCast((@as(u65, 1) << @as(u7, @intCast(int_info.bits - 1))) - 1));
    const min_val: i64 = (-@as(i64, @intCast(@as(u63, @intCast(max_val))))) - 1;
    const max_wvalue = switch (wasm_bits) {
        32 => WValue{ .imm32 = @as(u32, @truncate(max_val)) },
        64 => WValue{ .imm64 = max_val },
        else => unreachable,
    };
    const min_wvalue = switch (wasm_bits) {
        32 => WValue{ .imm32 = @as(u32, @bitCast(@as(i32, @truncate(min_val)))) },
        64 => WValue{ .imm64 = @as(u64, @bitCast(min_val)) },
        else => unreachable,
    };

    var bin_result = try (try func.binOp(lhs, rhs, ext_ty, op)).toLocal(func, ext_ty);
    if (!is_wasm_bits) {
        defer bin_result.free(func); // not returned in this branch
        defer lhs.free(func); // uses temporary local for absvalue
        defer rhs.free(func); // uses temporary local for absvalue
        try func.emitWValue(bin_result);
        try func.emitWValue(max_wvalue);
        _ = try func.cmp(bin_result, max_wvalue, ext_ty, .lt);
        try func.addTag(.select);
        try func.addLabel(.local_set, bin_result.local.value); // re-use local

        try func.emitWValue(bin_result);
        try func.emitWValue(min_wvalue);
        _ = try func.cmp(bin_result, min_wvalue, ext_ty, .gt);
        try func.addTag(.select);
        try func.addLabel(.local_set, bin_result.local.value); // re-use local
        return (try func.wrapOperand(bin_result, ty)).toLocal(func, ty);
    } else {
        const zero = switch (wasm_bits) {
            32 => WValue{ .imm32 = 0 },
            64 => WValue{ .imm64 = 0 },
            else => unreachable,
        };
        try func.emitWValue(max_wvalue);
        try func.emitWValue(min_wvalue);
        _ = try func.cmp(bin_result, zero, ty, .lt);
        try func.addTag(.select);
        try func.emitWValue(bin_result);
        // leave on stack
        const cmp_zero_result = try func.cmp(rhs, zero, ty, if (op == .add) .lt else .gt);
        const cmp_bin_result = try func.cmp(bin_result, lhs, ty, .lt);
        _ = try func.binOp(cmp_zero_result, cmp_bin_result, Type.u32, .xor); // comparisons always return i32, so provide u32 as type to xor.
        try func.addTag(.select);
        try func.addLabel(.local_set, bin_result.local.value); // re-use local
        return bin_result;
    }
}

fn airShlSat(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const mod = func.bin_file.base.comp.module.?;
    const ty = func.typeOfIndex(inst);
    const int_info = ty.intInfo(mod);
    const is_signed = int_info.signedness == .signed;
    if (int_info.bits > 64) {
        return func.fail("TODO: Saturating shifting left for integers with bitsize '{d}'", .{int_info.bits});
    }

    const lhs = try func.resolveInst(bin_op.lhs);
    const rhs = try func.resolveInst(bin_op.rhs);
    const wasm_bits = toWasmBits(int_info.bits).?;
    const result = try func.allocLocal(ty);

    if (wasm_bits == int_info.bits) outer_blk: {
        var shl = try (try func.binOp(lhs, rhs, ty, .shl)).toLocal(func, ty);
        defer shl.free(func);
        var shr = try (try func.binOp(shl, rhs, ty, .shr)).toLocal(func, ty);
        defer shr.free(func);

        switch (wasm_bits) {
            32 => blk: {
                if (!is_signed) {
                    try func.addImm32(-1);
                    break :blk;
                }
                try func.addImm32(std.math.minInt(i32));
                try func.addImm32(std.math.maxInt(i32));
                _ = try func.cmp(lhs, .{ .imm32 = 0 }, ty, .lt);
                try func.addTag(.select);
            },
            64 => blk: {
                if (!is_signed) {
                    try func.addImm64(@as(u64, @bitCast(@as(i64, -1))));
                    break :blk;
                }
                try func.addImm64(@as(u64, @bitCast(@as(i64, std.math.minInt(i64)))));
                try func.addImm64(@as(u64, @bitCast(@as(i64, std.math.maxInt(i64)))));
                _ = try func.cmp(lhs, .{ .imm64 = 0 }, ty, .lt);
                try func.addTag(.select);
            },
            else => unreachable,
        }
        try func.emitWValue(shl);
        _ = try func.cmp(lhs, shr, ty, .neq);
        try func.addTag(.select);
        try func.addLabel(.local_set, result.local.value);
        break :outer_blk;
    } else {
        const shift_size = wasm_bits - int_info.bits;
        const shift_value = switch (wasm_bits) {
            32 => WValue{ .imm32 = shift_size },
            64 => WValue{ .imm64 = shift_size },
            else => unreachable,
        };
        const ext_ty = try mod.intType(int_info.signedness, wasm_bits);

        var shl_res = try (try func.binOp(lhs, shift_value, ext_ty, .shl)).toLocal(func, ext_ty);
        defer shl_res.free(func);
        var shl = try (try func.binOp(shl_res, rhs, ext_ty, .shl)).toLocal(func, ext_ty);
        defer shl.free(func);
        var shr = try (try func.binOp(shl, rhs, ext_ty, .shr)).toLocal(func, ext_ty);
        defer shr.free(func);

        switch (wasm_bits) {
            32 => blk: {
                if (!is_signed) {
                    try func.addImm32(-1);
                    break :blk;
                }

                try func.addImm32(std.math.minInt(i32));
                try func.addImm32(std.math.maxInt(i32));
                _ = try func.cmp(shl_res, .{ .imm32 = 0 }, ext_ty, .lt);
                try func.addTag(.select);
            },
            64 => blk: {
                if (!is_signed) {
                    try func.addImm64(@as(u64, @bitCast(@as(i64, -1))));
                    break :blk;
                }

                try func.addImm64(@as(u64, @bitCast(@as(i64, std.math.minInt(i64)))));
                try func.addImm64(@as(u64, @bitCast(@as(i64, std.math.maxInt(i64)))));
                _ = try func.cmp(shl_res, .{ .imm64 = 0 }, ext_ty, .lt);
                try func.addTag(.select);
            },
            else => unreachable,
        }
        try func.emitWValue(shl);
        _ = try func.cmp(shl_res, shr, ext_ty, .neq);
        try func.addTag(.select);
        try func.addLabel(.local_set, result.local.value);
        var shift_result = try func.binOp(result, shift_value, ext_ty, .shr);
        if (is_signed) {
            shift_result = try func.wrapOperand(shift_result, ty);
        }
        try func.addLabel(.local_set, result.local.value);
    }

    return func.finishAir(inst, result, &.{ bin_op.lhs, bin_op.rhs });
}

/// Calls a compiler-rt intrinsic by creating an undefined symbol,
/// then lowering the arguments and calling the symbol as a function call.
/// This function call assumes the C-ABI.
/// Asserts arguments are not stack values when the return value is
/// passed as the first parameter.
/// May leave the return value on the stack.
fn callIntrinsic(
    func: *CodeGen,
    name: []const u8,
    param_types: []const InternPool.Index,
    return_type: Type,
    args: []const WValue,
) InnerError!WValue {
    assert(param_types.len == args.len);
    const symbol_index = func.bin_file.getGlobalSymbol(name, null) catch |err| {
        return func.fail("Could not find or create global symbol '{s}'", .{@errorName(err)});
    };

    // Always pass over C-ABI
    const mod = func.bin_file.base.comp.module.?;
    var func_type = try genFunctype(func.gpa, .C, param_types, return_type, mod);
    defer func_type.deinit(func.gpa);
    const func_type_index = try func.bin_file.zigObjectPtr().?.putOrGetFuncType(func.gpa, func_type);
    try func.bin_file.addOrUpdateImport(name, symbol_index, null, func_type_index);

    const want_sret_param = firstParamSRet(.C, return_type, mod);
    // if we want return as first param, we allocate a pointer to stack,
    // and emit it as our first argument
    const sret = if (want_sret_param) blk: {
        const sret_local = try func.allocStack(return_type);
        try func.lowerToStack(sret_local);
        break :blk sret_local;
    } else WValue{ .none = {} };

    // Lower all arguments to the stack before we call our function
    for (args, 0..) |arg, arg_i| {
        assert(!(want_sret_param and arg == .stack));
        assert(Type.fromInterned(param_types[arg_i]).hasRuntimeBitsIgnoreComptime(mod));
        try func.lowerArg(.C, Type.fromInterned(param_types[arg_i]), arg);
    }

    // Actually call our intrinsic
    try func.addLabel(.call, @intFromEnum(symbol_index));

    if (!return_type.hasRuntimeBitsIgnoreComptime(mod)) {
        return WValue.none;
    } else if (return_type.isNoReturn(mod)) {
        try func.addTag(.@"unreachable");
        return WValue.none;
    } else if (want_sret_param) {
        return sret;
    } else {
        return WValue{ .stack = {} };
    }
}

fn airTagName(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const un_op = func.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try func.resolveInst(un_op);
    const enum_ty = func.typeOf(un_op);

    const func_sym_index = try func.getTagNameFunction(enum_ty);

    const result_ptr = try func.allocStack(func.typeOfIndex(inst));
    try func.lowerToStack(result_ptr);
    try func.emitWValue(operand);
    try func.addLabel(.call, func_sym_index);

    return func.finishAir(inst, result_ptr, &.{un_op});
}

fn getTagNameFunction(func: *CodeGen, enum_ty: Type) InnerError!u32 {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const enum_decl_index = enum_ty.getOwnerDecl(mod);

    var arena_allocator = std.heap.ArenaAllocator.init(func.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const fqn = try mod.declPtr(enum_decl_index).fullyQualifiedName(mod);
    const func_name = try std.fmt.allocPrintZ(arena, "__zig_tag_name_{}", .{fqn.fmt(ip)});

    // check if we already generated code for this.
    if (func.bin_file.findGlobalSymbol(func_name)) |loc| {
        return @intFromEnum(loc.index);
    }

    const int_tag_ty = enum_ty.intTagType(mod);

    if (int_tag_ty.bitSize(mod) > 64) {
        return func.fail("TODO: Implement @tagName for enums with tag size larger than 64 bits", .{});
    }

    var relocs = std.ArrayList(link.File.Wasm.Relocation).init(func.gpa);
    defer relocs.deinit();

    var body_list = std.ArrayList(u8).init(func.gpa);
    defer body_list.deinit();
    var writer = body_list.writer();

    // The locals of the function body (always 0)
    try leb.writeULEB128(writer, @as(u32, 0));

    // outer block
    try writer.writeByte(std.wasm.opcode(.block));
    try writer.writeByte(std.wasm.block_empty);

    // TODO: Make switch implementation generic so we can use a jump table for this when the tags are not sparse.
    // generate an if-else chain for each tag value as well as constant.
    const tag_names = enum_ty.enumFields(mod);
    for (0..tag_names.len) |tag_index| {
        const tag_name = tag_names.get(ip)[tag_index];
        const tag_name_len = tag_name.length(ip);
        // for each tag name, create an unnamed const,
        // and then get a pointer to its value.
        const name_ty = try mod.arrayType(.{
            .len = tag_name_len,
            .child = .u8_type,
            .sentinel = .zero_u8,
        });
        const name_val = try mod.intern(.{ .aggregate = .{
            .ty = name_ty.toIntern(),
            .storage = .{ .bytes = tag_name.toString() },
        } });
        const tag_sym_index = try func.bin_file.lowerUnnamedConst(
            Value.fromInterned(name_val),
            enum_decl_index,
        );

        // block for this if case
        try writer.writeByte(std.wasm.opcode(.block));
        try writer.writeByte(std.wasm.block_empty);

        // get actual tag value (stored in 2nd parameter);
        try writer.writeByte(std.wasm.opcode(.local_get));
        try leb.writeULEB128(writer, @as(u32, 1));

        const tag_val = try mod.enumValueFieldIndex(enum_ty, @intCast(tag_index));
        const tag_value = try func.lowerConstant(tag_val, enum_ty);

        switch (tag_value) {
            .imm32 => |value| {
                try writer.writeByte(std.wasm.opcode(.i32_const));
                try leb.writeILEB128(writer, @as(i32, @bitCast(value)));
                try writer.writeByte(std.wasm.opcode(.i32_ne));
            },
            .imm64 => |value| {
                try writer.writeByte(std.wasm.opcode(.i64_const));
                try leb.writeILEB128(writer, @as(i64, @bitCast(value)));
                try writer.writeByte(std.wasm.opcode(.i64_ne));
            },
            else => unreachable,
        }
        // if they're not equal, break out of current branch
        try writer.writeByte(std.wasm.opcode(.br_if));
        try leb.writeULEB128(writer, @as(u32, 0));

        // store the address of the tagname in the pointer field of the slice
        // get the address twice so we can also store the length.
        try writer.writeByte(std.wasm.opcode(.local_get));
        try leb.writeULEB128(writer, @as(u32, 0));
        try writer.writeByte(std.wasm.opcode(.local_get));
        try leb.writeULEB128(writer, @as(u32, 0));

        // get address of tagname and emit a relocation to it
        if (func.arch() == .wasm32) {
            const encoded_alignment = @ctz(@as(u32, 4));
            try writer.writeByte(std.wasm.opcode(.i32_const));
            try relocs.append(.{
                .relocation_type = .R_WASM_MEMORY_ADDR_LEB,
                .offset = @as(u32, @intCast(body_list.items.len)),
                .index = tag_sym_index,
            });
            try writer.writeAll(&[_]u8{0} ** 5); // will be relocated

            // store pointer
            try writer.writeByte(std.wasm.opcode(.i32_store));
            try leb.writeULEB128(writer, encoded_alignment);
            try leb.writeULEB128(writer, @as(u32, 0));

            // store length
            try writer.writeByte(std.wasm.opcode(.i32_const));
            try leb.writeULEB128(writer, @as(u32, @intCast(tag_name_len)));
            try writer.writeByte(std.wasm.opcode(.i32_store));
            try leb.writeULEB128(writer, encoded_alignment);
            try leb.writeULEB128(writer, @as(u32, 4));
        } else {
            const encoded_alignment = @ctz(@as(u32, 8));
            try writer.writeByte(std.wasm.opcode(.i64_const));
            try relocs.append(.{
                .relocation_type = .R_WASM_MEMORY_ADDR_LEB64,
                .offset = @as(u32, @intCast(body_list.items.len)),
                .index = tag_sym_index,
            });
            try writer.writeAll(&[_]u8{0} ** 10); // will be relocated

            // store pointer
            try writer.writeByte(std.wasm.opcode(.i64_store));
            try leb.writeULEB128(writer, encoded_alignment);
            try leb.writeULEB128(writer, @as(u32, 0));

            // store length
            try writer.writeByte(std.wasm.opcode(.i64_const));
            try leb.writeULEB128(writer, @as(u64, @intCast(tag_name_len)));
            try writer.writeByte(std.wasm.opcode(.i64_store));
            try leb.writeULEB128(writer, encoded_alignment);
            try leb.writeULEB128(writer, @as(u32, 8));
        }

        // break outside blocks
        try writer.writeByte(std.wasm.opcode(.br));
        try leb.writeULEB128(writer, @as(u32, 1));

        // end the block for this case
        try writer.writeByte(std.wasm.opcode(.end));
    }

    try writer.writeByte(std.wasm.opcode(.@"unreachable")); // tag value does not have a name
    // finish outer block
    try writer.writeByte(std.wasm.opcode(.end));
    // finish function body
    try writer.writeByte(std.wasm.opcode(.end));

    const slice_ty = Type.slice_const_u8_sentinel_0;
    const func_type = try genFunctype(arena, .Unspecified, &.{int_tag_ty.ip_index}, slice_ty, mod);
    const sym_index = try func.bin_file.createFunction(func_name, func_type, &body_list, &relocs);
    return @intFromEnum(sym_index);
}

fn airErrorSetHasValue(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ip = &mod.intern_pool;
    const ty_op = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const operand = try func.resolveInst(ty_op.operand);
    const error_set_ty = ty_op.ty.toType();
    const result = try func.allocLocal(Type.bool);

    const names = error_set_ty.errorSetNames(mod);
    var values = try std.ArrayList(u32).initCapacity(func.gpa, names.len);
    defer values.deinit();

    var lowest: ?u32 = null;
    var highest: ?u32 = null;
    for (0..names.len) |name_index| {
        const err_int: Module.ErrorInt = @intCast(mod.global_error_set.getIndex(names.get(ip)[name_index]).?);
        if (lowest) |*l| {
            if (err_int < l.*) {
                l.* = err_int;
            }
        } else {
            lowest = err_int;
        }
        if (highest) |*h| {
            if (err_int > h.*) {
                highest = err_int;
            }
        } else {
            highest = err_int;
        }

        values.appendAssumeCapacity(err_int);
    }

    // start block for 'true' branch
    try func.startBlock(.block, wasm.block_empty);
    // start block for 'false' branch
    try func.startBlock(.block, wasm.block_empty);
    // block for the jump table itself
    try func.startBlock(.block, wasm.block_empty);

    // lower operand to determine jump table target
    try func.emitWValue(operand);
    try func.addImm32(@as(i32, @intCast(lowest.?)));
    try func.addTag(.i32_sub);

    // Account for default branch so always add '1'
    const depth = @as(u32, @intCast(highest.? - lowest.? + 1));
    const jump_table: Mir.JumpTable = .{ .length = depth };
    const table_extra_index = try func.addExtra(jump_table);
    try func.addInst(.{ .tag = .br_table, .data = .{ .payload = table_extra_index } });
    try func.mir_extra.ensureUnusedCapacity(func.gpa, depth);

    var value: u32 = lowest.?;
    while (value <= highest.?) : (value += 1) {
        const idx: u32 = blk: {
            for (values.items) |val| {
                if (val == value) break :blk 1;
            }
            break :blk 0;
        };
        func.mir_extra.appendAssumeCapacity(idx);
    }
    try func.endBlock();

    // 'false' branch (i.e. error set does not have value
    // ensure we set local to 0 in case the local was re-used.
    try func.addImm32(0);
    try func.addLabel(.local_set, result.local.value);
    try func.addLabel(.br, 1);
    try func.endBlock();

    // 'true' branch
    try func.addImm32(1);
    try func.addLabel(.local_set, result.local.value);
    try func.addLabel(.br, 0);
    try func.endBlock();

    return func.finishAir(inst, result, &.{ty_op.operand});
}

inline fn useAtomicFeature(func: *const CodeGen) bool {
    return std.Target.wasm.featureSetHas(func.target.cpu.features, .atomics);
}

fn airCmpxchg(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const ty_pl = func.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = func.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

    const ptr_ty = func.typeOf(extra.ptr);
    const ty = ptr_ty.childType(mod);
    const result_ty = func.typeOfIndex(inst);

    const ptr_operand = try func.resolveInst(extra.ptr);
    const expected_val = try func.resolveInst(extra.expected_value);
    const new_val = try func.resolveInst(extra.new_value);

    const cmp_result = try func.allocLocal(Type.bool);

    const ptr_val = if (func.useAtomicFeature()) val: {
        const val_local = try func.allocLocal(ty);
        try func.emitWValue(ptr_operand);
        try func.lowerToStack(expected_val);
        try func.lowerToStack(new_val);
        try func.addAtomicMemArg(switch (ty.abiSize(mod)) {
            1 => .i32_atomic_rmw8_cmpxchg_u,
            2 => .i32_atomic_rmw16_cmpxchg_u,
            4 => .i32_atomic_rmw_cmpxchg,
            8 => .i32_atomic_rmw_cmpxchg,
            else => |size| return func.fail("TODO: implement `@cmpxchg` for types with abi size '{d}'", .{size}),
        }, .{
            .offset = ptr_operand.offset(),
            .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
        });
        try func.addLabel(.local_tee, val_local.local.value);
        _ = try func.cmp(.stack, expected_val, ty, .eq);
        try func.addLabel(.local_set, cmp_result.local.value);
        break :val val_local;
    } else val: {
        if (ty.abiSize(mod) > 8) {
            return func.fail("TODO: Implement `@cmpxchg` for types larger than abi size of 8 bytes", .{});
        }
        const ptr_val = try WValue.toLocal(try func.load(ptr_operand, ty, 0), func, ty);

        try func.lowerToStack(ptr_operand);
        try func.lowerToStack(new_val);
        try func.emitWValue(ptr_val);
        _ = try func.cmp(ptr_val, expected_val, ty, .eq);
        try func.addLabel(.local_tee, cmp_result.local.value);
        try func.addTag(.select);
        try func.store(.stack, .stack, ty, 0);

        break :val ptr_val;
    };

    const result_ptr = if (isByRef(result_ty, mod)) val: {
        try func.emitWValue(cmp_result);
        try func.addImm32(-1);
        try func.addTag(.i32_xor);
        try func.addImm32(1);
        try func.addTag(.i32_and);
        const and_result = try WValue.toLocal(.stack, func, Type.bool);
        const result_ptr = try func.allocStack(result_ty);
        try func.store(result_ptr, and_result, Type.bool, @as(u32, @intCast(ty.abiSize(mod))));
        try func.store(result_ptr, ptr_val, ty, 0);
        break :val result_ptr;
    } else val: {
        try func.addImm32(0);
        try func.emitWValue(ptr_val);
        try func.emitWValue(cmp_result);
        try func.addTag(.select);
        break :val try WValue.toLocal(.stack, func, result_ty);
    };

    return func.finishAir(inst, result_ptr, &.{ extra.ptr, extra.expected_value, extra.new_value });
}

fn airAtomicLoad(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const atomic_load = func.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;
    const ptr = try func.resolveInst(atomic_load.ptr);
    const ty = func.typeOfIndex(inst);

    if (func.useAtomicFeature()) {
        const tag: wasm.AtomicsOpcode = switch (ty.abiSize(mod)) {
            1 => .i32_atomic_load8_u,
            2 => .i32_atomic_load16_u,
            4 => .i32_atomic_load,
            8 => .i64_atomic_load,
            else => |size| return func.fail("TODO: @atomicLoad for types with abi size {d}", .{size}),
        };
        try func.emitWValue(ptr);
        try func.addAtomicMemArg(tag, .{
            .offset = ptr.offset(),
            .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
        });
    } else {
        _ = try func.load(ptr, ty, 0);
    }

    const result = try WValue.toLocal(.stack, func, ty);
    return func.finishAir(inst, result, &.{atomic_load.ptr});
}

fn airAtomicRmw(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const pl_op = func.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = func.air.extraData(Air.AtomicRmw, pl_op.payload).data;

    const ptr = try func.resolveInst(pl_op.operand);
    const operand = try func.resolveInst(extra.operand);
    const ty = func.typeOfIndex(inst);
    const op: std.builtin.AtomicRmwOp = extra.op();

    if (func.useAtomicFeature()) {
        switch (op) {
            .Max,
            .Min,
            .Nand,
            => {
                const tmp = try func.load(ptr, ty, 0);
                const value = try tmp.toLocal(func, ty);

                // create a loop to cmpxchg the new value
                try func.startBlock(.loop, wasm.block_empty);

                try func.emitWValue(ptr);
                try func.emitWValue(value);
                if (op == .Nand) {
                    const wasm_bits = toWasmBits(@as(u16, @intCast(ty.bitSize(mod)))).?;

                    const and_res = try func.binOp(value, operand, ty, .@"and");
                    if (wasm_bits == 32)
                        try func.addImm32(-1)
                    else if (wasm_bits == 64)
                        try func.addImm64(@as(u64, @bitCast(@as(i64, -1))))
                    else
                        return func.fail("TODO: `@atomicRmw` with operator `Nand` for types larger than 64 bits", .{});
                    _ = try func.binOp(and_res, .stack, ty, .xor);
                } else {
                    try func.emitWValue(value);
                    try func.emitWValue(operand);
                    _ = try func.cmp(value, operand, ty, if (op == .Max) .gt else .lt);
                    try func.addTag(.select);
                }
                try func.addAtomicMemArg(
                    switch (ty.abiSize(mod)) {
                        1 => .i32_atomic_rmw8_cmpxchg_u,
                        2 => .i32_atomic_rmw16_cmpxchg_u,
                        4 => .i32_atomic_rmw_cmpxchg,
                        8 => .i64_atomic_rmw_cmpxchg,
                        else => return func.fail("TODO: implement `@atomicRmw` with operation `{s}` for types larger than 64 bits", .{@tagName(op)}),
                    },
                    .{
                        .offset = ptr.offset(),
                        .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
                    },
                );
                const select_res = try func.allocLocal(ty);
                try func.addLabel(.local_tee, select_res.local.value);
                _ = try func.cmp(.stack, value, ty, .neq); // leave on stack so we can use it for br_if

                try func.emitWValue(select_res);
                try func.addLabel(.local_set, value.local.value);

                try func.addLabel(.br_if, 0);
                try func.endBlock();
                return func.finishAir(inst, value, &.{ pl_op.operand, extra.operand });
            },

            // the other operations have their own instructions for Wasm.
            else => {
                try func.emitWValue(ptr);
                try func.emitWValue(operand);
                const tag: wasm.AtomicsOpcode = switch (ty.abiSize(mod)) {
                    1 => switch (op) {
                        .Xchg => .i32_atomic_rmw8_xchg_u,
                        .Add => .i32_atomic_rmw8_add_u,
                        .Sub => .i32_atomic_rmw8_sub_u,
                        .And => .i32_atomic_rmw8_and_u,
                        .Or => .i32_atomic_rmw8_or_u,
                        .Xor => .i32_atomic_rmw8_xor_u,
                        else => unreachable,
                    },
                    2 => switch (op) {
                        .Xchg => .i32_atomic_rmw16_xchg_u,
                        .Add => .i32_atomic_rmw16_add_u,
                        .Sub => .i32_atomic_rmw16_sub_u,
                        .And => .i32_atomic_rmw16_and_u,
                        .Or => .i32_atomic_rmw16_or_u,
                        .Xor => .i32_atomic_rmw16_xor_u,
                        else => unreachable,
                    },
                    4 => switch (op) {
                        .Xchg => .i32_atomic_rmw_xchg,
                        .Add => .i32_atomic_rmw_add,
                        .Sub => .i32_atomic_rmw_sub,
                        .And => .i32_atomic_rmw_and,
                        .Or => .i32_atomic_rmw_or,
                        .Xor => .i32_atomic_rmw_xor,
                        else => unreachable,
                    },
                    8 => switch (op) {
                        .Xchg => .i64_atomic_rmw_xchg,
                        .Add => .i64_atomic_rmw_add,
                        .Sub => .i64_atomic_rmw_sub,
                        .And => .i64_atomic_rmw_and,
                        .Or => .i64_atomic_rmw_or,
                        .Xor => .i64_atomic_rmw_xor,
                        else => unreachable,
                    },
                    else => |size| return func.fail("TODO: Implement `@atomicRmw` for types with abi size {d}", .{size}),
                };
                try func.addAtomicMemArg(tag, .{
                    .offset = ptr.offset(),
                    .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
                });
                const result = try WValue.toLocal(.stack, func, ty);
                return func.finishAir(inst, result, &.{ pl_op.operand, extra.operand });
            },
        }
    } else {
        const loaded = try func.load(ptr, ty, 0);
        const result = try loaded.toLocal(func, ty);

        switch (op) {
            .Xchg => {
                try func.store(ptr, operand, ty, 0);
            },
            .Add,
            .Sub,
            .And,
            .Or,
            .Xor,
            => {
                try func.emitWValue(ptr);
                _ = try func.binOp(result, operand, ty, switch (op) {
                    .Add => .add,
                    .Sub => .sub,
                    .And => .@"and",
                    .Or => .@"or",
                    .Xor => .xor,
                    else => unreachable,
                });
                if (ty.isInt(mod) and (op == .Add or op == .Sub)) {
                    _ = try func.wrapOperand(.stack, ty);
                }
                try func.store(.stack, .stack, ty, ptr.offset());
            },
            .Max,
            .Min,
            => {
                try func.emitWValue(ptr);
                try func.emitWValue(result);
                try func.emitWValue(operand);
                _ = try func.cmp(result, operand, ty, if (op == .Max) .gt else .lt);
                try func.addTag(.select);
                try func.store(.stack, .stack, ty, ptr.offset());
            },
            .Nand => {
                const wasm_bits = toWasmBits(@as(u16, @intCast(ty.bitSize(mod)))).?;

                try func.emitWValue(ptr);
                const and_res = try func.binOp(result, operand, ty, .@"and");
                if (wasm_bits == 32)
                    try func.addImm32(-1)
                else if (wasm_bits == 64)
                    try func.addImm64(@as(u64, @bitCast(@as(i64, -1))))
                else
                    return func.fail("TODO: `@atomicRmw` with operator `Nand` for types larger than 64 bits", .{});
                _ = try func.binOp(and_res, .stack, ty, .xor);
                try func.store(.stack, .stack, ty, ptr.offset());
            },
        }

        return func.finishAir(inst, result, &.{ pl_op.operand, extra.operand });
    }
}

fn airFence(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const zcu = func.bin_file.base.comp.module.?;
    // Only when the atomic feature is enabled, and we're not building
    // for a single-threaded build, can we emit the `fence` instruction.
    // In all other cases, we emit no instructions for a fence.
    const func_namespace = zcu.namespacePtr(func.decl.src_namespace);
    const single_threaded = func_namespace.file_scope.mod.single_threaded;
    if (func.useAtomicFeature() and !single_threaded) {
        try func.addAtomicTag(.atomic_fence);
    }

    return func.finishAir(inst, .none, &.{});
}

fn airAtomicStore(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    const mod = func.bin_file.base.comp.module.?;
    const bin_op = func.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const ptr = try func.resolveInst(bin_op.lhs);
    const operand = try func.resolveInst(bin_op.rhs);
    const ptr_ty = func.typeOf(bin_op.lhs);
    const ty = ptr_ty.childType(mod);

    if (func.useAtomicFeature()) {
        const tag: wasm.AtomicsOpcode = switch (ty.abiSize(mod)) {
            1 => .i32_atomic_store8,
            2 => .i32_atomic_store16,
            4 => .i32_atomic_store,
            8 => .i64_atomic_store,
            else => |size| return func.fail("TODO: @atomicLoad for types with abi size {d}", .{size}),
        };
        try func.emitWValue(ptr);
        try func.lowerToStack(operand);
        try func.addAtomicMemArg(tag, .{
            .offset = ptr.offset(),
            .alignment = @intCast(ty.abiAlignment(mod).toByteUnits().?),
        });
    } else {
        try func.store(ptr, operand, ty, 0);
    }

    return func.finishAir(inst, .none, &.{ bin_op.lhs, bin_op.rhs });
}

fn airFrameAddress(func: *CodeGen, inst: Air.Inst.Index) InnerError!void {
    if (func.initial_stack_value == .none) {
        try func.initializeStack();
    }
    try func.emitWValue(func.bottom_stack_value);
    const result = try WValue.toLocal(.stack, func, Type.usize);
    return func.finishAir(inst, result, &.{});
}

fn typeOf(func: *CodeGen, inst: Air.Inst.Ref) Type {
    const mod = func.bin_file.base.comp.module.?;
    return func.air.typeOf(inst, &mod.intern_pool);
}

fn typeOfIndex(func: *CodeGen, inst: Air.Inst.Index) Type {
    const mod = func.bin_file.base.comp.module.?;
    return func.air.typeOfIndex(inst, &mod.intern_pool);
}
