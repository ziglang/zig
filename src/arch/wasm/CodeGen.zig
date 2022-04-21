const std = @import("std");
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
const Decl = Module.Decl;
const Type = @import("../../type.zig").Type;
const Value = @import("../../value.zig").Value;
const Compilation = @import("../../Compilation.zig");
const LazySrcLoc = Module.LazySrcLoc;
const link = @import("../../link.zig");
const TypedValue = @import("../../TypedValue.zig");
const Air = @import("../../Air.zig");
const Liveness = @import("../../Liveness.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");

/// Wasm Value, created when generating an instruction
const WValue = union(enum) {
    /// May be referenced but is unused
    none: void,
    /// Index of the local variable
    local: u32,
    /// An immediate 32bit value
    imm32: u32,
    /// An immediate 64bit value
    imm64: u64,
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
    /// Offset from the bottom of the stack, with the offset
    /// pointing to where the value lives.
    stack_offset: u32,

    /// Returns the offset from the bottom of the stack. This is useful when
    /// we use the load or store instruction to ensure we retrieve the value
    /// from the correct position, rather than the value that lives at the
    /// bottom of the stack. For instances where `WValue` is not `stack_value`
    /// this will return 0, which allows us to simply call this function for all
    /// loads and stores without requiring checks everywhere.
    fn offset(self: WValue) u32 {
        switch (self) {
            .stack_offset => |stack_offset| return stack_offset,
            else => return 0,
        }
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
                .f32, .f64 => unreachable,
            },
            16 => switch (args.valtype1.?) {
                .i32 => if (args.signedness.? == .signed) return .i32_load16_s else return .i32_load16_u,
                .i64 => if (args.signedness.? == .signed) return .i64_load16_s else return .i64_load16_u,
                .f32 => return .f32_load,
                .f64 => unreachable,
            },
            32 => switch (args.valtype1.?) {
                .i64 => if (args.signedness.? == .signed) return .i64_load32_s else return .i64_load32_u,
                .i32 => return .i32_load,
                .f32 => return .f32_load,
                .f64 => unreachable,
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
        },
        .store => if (args.width) |width| {
            switch (width) {
                8 => switch (args.valtype1.?) {
                    .i32 => return .i32_store8,
                    .i64 => return .i64_store8,
                    .f32, .f64 => unreachable,
                },
                16 => switch (args.valtype1.?) {
                    .i32 => return .i32_store16,
                    .i64 => return .i64_store16,
                    .f32 => return .f32_store,
                    .f64 => unreachable,
                },
                32 => switch (args.valtype1.?) {
                    .i64 => return .i64_store32,
                    .i32 => return .i32_store,
                    .f32 => return .f32_store,
                    .f64 => unreachable,
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
            }
        },

        .memory_size => return .memory_size,
        .memory_grow => return .memory_grow,

        .@"const" => switch (args.valtype1.?) {
            .i32 => return .i32_const,
            .i64 => return .i64_const,
            .f32 => return .f32_const,
            .f64 => return .f64_const,
        },

        .eqz => switch (args.valtype1.?) {
            .i32 => return .i32_eqz,
            .i64 => return .i64_eqz,
            .f32, .f64 => unreachable,
        },
        .eq => switch (args.valtype1.?) {
            .i32 => return .i32_eq,
            .i64 => return .i64_eq,
            .f32 => return .f32_eq,
            .f64 => return .f64_eq,
        },
        .ne => switch (args.valtype1.?) {
            .i32 => return .i32_ne,
            .i64 => return .i64_ne,
            .f32 => return .f32_ne,
            .f64 => return .f64_ne,
        },

        .lt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_lt_s else return .i32_lt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_lt_s else return .i64_lt_u,
            .f32 => return .f32_lt,
            .f64 => return .f64_lt,
        },
        .gt => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_gt_s else return .i32_gt_u,
            .i64 => if (args.signedness.? == .signed) return .i64_gt_s else return .i64_gt_u,
            .f32 => return .f32_gt,
            .f64 => return .f64_gt,
        },
        .le => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_le_s else return .i32_le_u,
            .i64 => if (args.signedness.? == .signed) return .i64_le_s else return .i64_le_u,
            .f32 => return .f32_le,
            .f64 => return .f64_le,
        },
        .ge => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_ge_s else return .i32_ge_u,
            .i64 => if (args.signedness.? == .signed) return .i64_ge_s else return .i64_ge_u,
            .f32 => return .f32_ge,
            .f64 => return .f64_ge,
        },

        .clz => switch (args.valtype1.?) {
            .i32 => return .i32_clz,
            .i64 => return .i64_clz,
            .f32, .f64 => unreachable,
        },
        .ctz => switch (args.valtype1.?) {
            .i32 => return .i32_ctz,
            .i64 => return .i64_ctz,
            .f32, .f64 => unreachable,
        },
        .popcnt => switch (args.valtype1.?) {
            .i32 => return .i32_popcnt,
            .i64 => return .i64_popcnt,
            .f32, .f64 => unreachable,
        },

        .add => switch (args.valtype1.?) {
            .i32 => return .i32_add,
            .i64 => return .i64_add,
            .f32 => return .f32_add,
            .f64 => return .f64_add,
        },
        .sub => switch (args.valtype1.?) {
            .i32 => return .i32_sub,
            .i64 => return .i64_sub,
            .f32 => return .f32_sub,
            .f64 => return .f64_sub,
        },
        .mul => switch (args.valtype1.?) {
            .i32 => return .i32_mul,
            .i64 => return .i64_mul,
            .f32 => return .f32_mul,
            .f64 => return .f64_mul,
        },

        .div => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_div_s else return .i32_div_u,
            .i64 => if (args.signedness.? == .signed) return .i64_div_s else return .i64_div_u,
            .f32 => return .f32_div,
            .f64 => return .f64_div,
        },
        .rem => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_rem_s else return .i32_rem_u,
            .i64 => if (args.signedness.? == .signed) return .i64_rem_s else return .i64_rem_u,
            .f32, .f64 => unreachable,
        },

        .@"and" => switch (args.valtype1.?) {
            .i32 => return .i32_and,
            .i64 => return .i64_and,
            .f32, .f64 => unreachable,
        },
        .@"or" => switch (args.valtype1.?) {
            .i32 => return .i32_or,
            .i64 => return .i64_or,
            .f32, .f64 => unreachable,
        },
        .xor => switch (args.valtype1.?) {
            .i32 => return .i32_xor,
            .i64 => return .i64_xor,
            .f32, .f64 => unreachable,
        },

        .shl => switch (args.valtype1.?) {
            .i32 => return .i32_shl,
            .i64 => return .i64_shl,
            .f32, .f64 => unreachable,
        },
        .shr => switch (args.valtype1.?) {
            .i32 => if (args.signedness.? == .signed) return .i32_shr_s else return .i32_shr_u,
            .i64 => if (args.signedness.? == .signed) return .i64_shr_s else return .i64_shr_u,
            .f32, .f64 => unreachable,
        },
        .rotl => switch (args.valtype1.?) {
            .i32 => return .i32_rotl,
            .i64 => return .i64_rotl,
            .f32, .f64 => unreachable,
        },
        .rotr => switch (args.valtype1.?) {
            .i32 => return .i32_rotr,
            .i64 => return .i64_rotr,
            .f32, .f64 => unreachable,
        },

        .abs => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_abs,
            .f64 => return .f64_abs,
        },
        .neg => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_neg,
            .f64 => return .f64_neg,
        },
        .ceil => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_ceil,
            .f64 => return .f64_ceil,
        },
        .floor => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_floor,
            .f64 => return .f64_floor,
        },
        .trunc => switch (args.valtype1.?) {
            .i32 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => unreachable,
                .f32 => if (args.signedness.? == .signed) return .i32_trunc_f32_s else return .i32_trunc_f32_u,
                .f64 => if (args.signedness.? == .signed) return .i32_trunc_f64_s else return .i32_trunc_f64_u,
            },
            .i64 => unreachable,
            .f32 => return .f32_trunc,
            .f64 => return .f64_trunc,
        },
        .nearest => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_nearest,
            .f64 => return .f64_nearest,
        },
        .sqrt => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_sqrt,
            .f64 => return .f64_sqrt,
        },
        .min => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_min,
            .f64 => return .f64_min,
        },
        .max => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_max,
            .f64 => return .f64_max,
        },
        .copysign => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => return .f32_copysign,
            .f64 => return .f64_copysign,
        },

        .wrap => switch (args.valtype1.?) {
            .i32 => switch (args.valtype2.?) {
                .i32 => unreachable,
                .i64 => return .i32_wrap_i64,
                .f32, .f64 => unreachable,
            },
            .i64, .f32, .f64 => unreachable,
        },
        .convert => switch (args.valtype1.?) {
            .i32, .i64 => unreachable,
            .f32 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f32_convert_i32_s else return .f32_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f32_convert_i64_s else return .f32_convert_i64_u,
                .f32, .f64 => unreachable,
            },
            .f64 => switch (args.valtype2.?) {
                .i32 => if (args.signedness.? == .signed) return .f64_convert_i32_s else return .f64_convert_i32_u,
                .i64 => if (args.signedness.? == .signed) return .f64_convert_i64_s else return .f64_convert_i64_u,
                .f32, .f64 => unreachable,
            },
        },
        .demote => if (args.valtype1.? == .f32 and args.valtype2.? == .f64) return .f32_demote_f64 else unreachable,
        .promote => if (args.valtype1.? == .f64 and args.valtype2.? == .f32) return .f64_promote_f32 else unreachable,
        .reinterpret => switch (args.valtype1.?) {
            .i32 => if (args.valtype2.? == .f32) return .i32_reinterpret_f32 else unreachable,
            .i64 => if (args.valtype2.? == .f64) return .i64_reinterpret_f64 else unreachable,
            .f32 => if (args.valtype2.? == .i32) return .f32_reinterpret_i32 else unreachable,
            .f64 => if (args.valtype2.? == .i64) return .f64_reinterpret_i64 else unreachable,
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

pub const Result = union(enum) {
    /// The codegen bytes have been appended to `Context.code`
    appended: void,
    /// The data is managed externally and are part of the `Result`
    externally_managed: []const u8,
};

/// Hashmap to store generated `WValue` for each `Air.Inst.Ref`
pub const ValueTable = std.AutoHashMapUnmanaged(Air.Inst.Ref, WValue);

const Self = @This();

/// Reference to the function declaration the code
/// section belongs to
decl: *Decl,
decl_index: Decl.Index,
/// Current block depth. Used to calculate the relative difference between a break
/// and block
block_depth: u32 = 0,
air: Air,
liveness: Liveness,
gpa: mem.Allocator,
/// Table to save `WValue`'s generated by an `Air.Inst`
values: ValueTable,
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
stack_alignment: u32 = 16,

const InnerError = error{
    OutOfMemory,
    /// An error occured when trying to lower AIR to MIR.
    CodegenFail,
    /// Can occur when dereferencing a pointer that points to a `Decl` of which the analysis has failed
    AnalysisFail,
    /// Compiler implementation could not handle a large integer.
    Overflow,
};

pub fn deinit(self: *Self) void {
    self.values.deinit(self.gpa);
    self.blocks.deinit(self.gpa);
    self.locals.deinit(self.gpa);
    self.mir_instructions.deinit(self.gpa);
    self.mir_extra.deinit(self.gpa);
    self.* = undefined;
}

/// Sets `err_msg` on `CodeGen` and returns `error.CodegenFail` which is caught in link/Wasm.zig
fn fail(self: *Self, comptime fmt: []const u8, args: anytype) InnerError {
    const src: LazySrcLoc = .{ .node_offset = 0 };
    const src_loc = src.toSrcLoc(self.decl);
    self.err_msg = try Module.ErrorMsg.create(self.gpa, src_loc, fmt, args);
    return error.CodegenFail;
}

/// Resolves the `WValue` for the given instruction `inst`
/// When the given instruction has a `Value`, it returns a constant instead
fn resolveInst(self: *Self, ref: Air.Inst.Ref) InnerError!WValue {
    const gop = try self.values.getOrPut(self.gpa, ref);
    if (gop.found_existing) return gop.value_ptr.*;

    // when we did not find an existing instruction, it
    // means we must generate it from a constant.
    const val = self.air.value(ref).?;
    const ty = self.air.typeOf(ref);
    if (!ty.hasRuntimeBitsIgnoreComptime() and !ty.isInt()) {
        gop.value_ptr.* = WValue{ .none = {} };
        return gop.value_ptr.*;
    }

    // When we need to pass the value by reference (such as a struct), we will
    // leverage `generateSymbol` to lower the constant to bytes and emit it
    // to the 'rodata' section. We then return the index into the section as `WValue`.
    //
    // In the other cases, we will simply lower the constant to a value that fits
    // into a single local (such as a pointer, integer, bool, etc).
    const result = if (isByRef(ty, self.target)) blk: {
        const sym_index = try self.bin_file.lowerUnnamedConst(.{ .ty = ty, .val = val }, self.decl_index);
        break :blk WValue{ .memory = sym_index };
    } else try self.lowerConstant(val, ty);

    gop.value_ptr.* = result;
    return result;
}

/// Appends a MIR instruction and returns its index within the list of instructions
fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!void {
    try self.mir_instructions.append(self.gpa, inst);
}

fn addTag(self: *Self, tag: Mir.Inst.Tag) error{OutOfMemory}!void {
    try self.addInst(.{ .tag = tag, .data = .{ .tag = {} } });
}

fn addExtended(self: *Self, opcode: wasm.PrefixedOpcode) error{OutOfMemory}!void {
    try self.addInst(.{ .tag = .extended, .secondary = @enumToInt(opcode), .data = .{ .tag = {} } });
}

fn addLabel(self: *Self, tag: Mir.Inst.Tag, label: u32) error{OutOfMemory}!void {
    try self.addInst(.{ .tag = tag, .data = .{ .label = label } });
}

fn addImm32(self: *Self, imm: i32) error{OutOfMemory}!void {
    try self.addInst(.{ .tag = .i32_const, .data = .{ .imm32 = imm } });
}

/// Accepts an unsigned 64bit integer rather than a signed integer to
/// prevent us from having to bitcast multiple times as most values
/// within codegen are represented as unsigned rather than signed.
fn addImm64(self: *Self, imm: u64) error{OutOfMemory}!void {
    const extra_index = try self.addExtra(Mir.Imm64.fromU64(imm));
    try self.addInst(.{ .tag = .i64_const, .data = .{ .payload = extra_index } });
}

fn addFloat64(self: *Self, float: f64) error{OutOfMemory}!void {
    const extra_index = try self.addExtra(Mir.Float64.fromFloat64(float));
    try self.addInst(.{ .tag = .f64_const, .data = .{ .payload = extra_index } });
}

/// Inserts an instruction to load/store from/to wasm's linear memory dependent on the given `tag`.
fn addMemArg(self: *Self, tag: Mir.Inst.Tag, mem_arg: Mir.MemArg) error{OutOfMemory}!void {
    const extra_index = try self.addExtra(mem_arg);
    try self.addInst(.{ .tag = tag, .data = .{ .payload = extra_index } });
}

/// Appends entries to `mir_extra` based on the type of `extra`.
/// Returns the index into `mir_extra`
fn addExtra(self: *Self, extra: anytype) error{OutOfMemory}!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try self.mir_extra.ensureUnusedCapacity(self.gpa, fields.len);
    return self.addExtraAssumeCapacity(extra);
}

/// Appends entries to `mir_extra` based on the type of `extra`.
/// Returns the index into `mir_extra`
fn addExtraAssumeCapacity(self: *Self, extra: anytype) error{OutOfMemory}!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, self.mir_extra.items.len);
    inline for (fields) |field| {
        self.mir_extra.appendAssumeCapacity(switch (field.field_type) {
            u32 => @field(extra, field.name),
            else => |field_type| @compileError("Unsupported field type " ++ @typeName(field_type)),
        });
    }
    return result;
}

/// Using a given `Type`, returns the corresponding type
fn typeToValtype(ty: Type, target: std.Target) wasm.Valtype {
    return switch (ty.zigTypeTag()) {
        .Float => blk: {
            const bits = ty.floatBits(target);
            if (bits == 16 or bits == 32) break :blk wasm.Valtype.f32;
            if (bits == 64) break :blk wasm.Valtype.f64;
            return wasm.Valtype.i32; // represented as pointer to stack
        },
        .Int => blk: {
            const info = ty.intInfo(target);
            if (info.bits <= 32) break :blk wasm.Valtype.i32;
            if (info.bits > 32 and info.bits <= 64) break :blk wasm.Valtype.i64;
            break :blk wasm.Valtype.i32; // represented as pointer to stack
        },
        .Enum => {
            var buf: Type.Payload.Bits = undefined;
            return typeToValtype(ty.intTagType(&buf), target);
        },
        else => wasm.Valtype.i32, // all represented as reference/immediate
    };
}

/// Using a given `Type`, returns the byte representation of its wasm value type
fn genValtype(ty: Type, target: std.Target) u8 {
    return wasm.valtype(typeToValtype(ty, target));
}

/// Using a given `Type`, returns the corresponding wasm value type
/// Differently from `genValtype` this also allows `void` to create a block
/// with no return type
fn genBlockType(ty: Type, target: std.Target) u8 {
    return switch (ty.tag()) {
        .void, .noreturn => wasm.block_empty,
        else => genValtype(ty, target),
    };
}

/// Writes the bytecode depending on the given `WValue` in `val`
fn emitWValue(self: *Self, value: WValue) InnerError!void {
    switch (value) {
        .none => {}, // no-op
        .local => |idx| try self.addLabel(.local_get, idx),
        .imm32 => |val| try self.addImm32(@bitCast(i32, val)),
        .imm64 => |val| try self.addImm64(val),
        .float32 => |val| try self.addInst(.{ .tag = .f32_const, .data = .{ .float32 = val } }),
        .float64 => |val| try self.addFloat64(val),
        .memory => |ptr| {
            const extra_index = try self.addExtra(Mir.Memory{ .pointer = ptr, .offset = 0 });
            try self.addInst(.{ .tag = .memory_address, .data = .{ .payload = extra_index } });
        },
        .memory_offset => |mem_off| {
            const extra_index = try self.addExtra(Mir.Memory{ .pointer = mem_off.pointer, .offset = mem_off.offset });
            try self.addInst(.{ .tag = .memory_address, .data = .{ .payload = extra_index } });
        },
        .function_index => |index| try self.addLabel(.function_index, index), // write function index and generate relocation
        .stack_offset => try self.addLabel(.local_get, self.bottom_stack_value.local), // caller must ensure to address the offset
    }
}

/// Creates one locals for a given `Type`.
/// Returns a corresponding `Wvalue` with `local` as active tag
fn allocLocal(self: *Self, ty: Type) InnerError!WValue {
    const initial_index = self.local_index;
    const valtype = genValtype(ty, self.target);
    try self.locals.append(self.gpa, valtype);
    self.local_index += 1;
    return WValue{ .local = initial_index };
}

/// Generates a `wasm.Type` from a given function type.
/// Memory is owned by the caller.
fn genFunctype(gpa: Allocator, fn_ty: Type, target: std.Target) !wasm.Type {
    var params = std.ArrayList(wasm.Valtype).init(gpa);
    defer params.deinit();
    var returns = std.ArrayList(wasm.Valtype).init(gpa);
    defer returns.deinit();
    const return_type = fn_ty.fnReturnType();

    const want_sret = isByRef(return_type, target);

    if (want_sret) {
        try params.append(typeToValtype(return_type, target));
    }

    // param types
    if (fn_ty.fnParamLen() != 0) {
        const fn_params = try gpa.alloc(Type, fn_ty.fnParamLen());
        defer gpa.free(fn_params);
        fn_ty.fnParamTypes(fn_params);
        for (fn_params) |param_type| {
            if (!param_type.hasRuntimeBitsIgnoreComptime()) continue;
            try params.append(typeToValtype(param_type, target));
        }
    }

    // return type
    if (!want_sret and return_type.hasRuntimeBitsIgnoreComptime()) {
        try returns.append(typeToValtype(return_type, target));
    }

    return wasm.Type{
        .params = params.toOwnedSlice(),
        .returns = returns.toOwnedSlice(),
    };
}

pub fn generate(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    func: *Module.Fn,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: codegen.DebugInfoOutput,
) codegen.GenerateSymbolError!codegen.FnResult {
    _ = debug_output; // TODO
    _ = src_loc;
    var code_gen: Self = .{
        .gpa = bin_file.allocator,
        .air = air,
        .liveness = liveness,
        .values = .{},
        .code = code,
        .decl_index = func.owner_decl,
        .decl = bin_file.options.module.?.declPtr(func.owner_decl),
        .err_msg = undefined,
        .locals = .{},
        .target = bin_file.options.target,
        .bin_file = bin_file.cast(link.File.Wasm).?,
    };
    defer code_gen.deinit();

    genFunc(&code_gen) catch |err| switch (err) {
        error.CodegenFail => return codegen.FnResult{ .fail = code_gen.err_msg },
        else => |e| return e,
    };

    return codegen.FnResult{ .appended = {} };
}

fn genFunc(self: *Self) InnerError!void {
    var func_type = try genFunctype(self.gpa, self.decl.ty, self.target);
    defer func_type.deinit(self.gpa);
    self.decl.fn_link.wasm.type_index = try self.bin_file.putOrGetFuncType(func_type);

    var cc_result = try self.resolveCallingConventionValues(self.decl.ty);
    defer cc_result.deinit(self.gpa);

    self.args = cc_result.args;
    self.return_value = cc_result.return_value;

    // Generate MIR for function body
    try self.genBody(self.air.getMainBody());
    // In case we have a return value, but the last instruction is a noreturn (such as a while loop)
    // we emit an unreachable instruction to tell the stack validator that part will never be reached.
    if (func_type.returns.len != 0 and self.air.instructions.len > 0) {
        const inst = @intCast(u32, self.air.instructions.len - 1);
        const last_inst_ty = self.air.typeOfIndex(inst);
        if (!last_inst_ty.hasRuntimeBitsIgnoreComptime() or last_inst_ty.isNoReturn()) {
            try self.addTag(.@"unreachable");
        }
    }
    // End of function body
    try self.addTag(.end);

    // check if we have to initialize and allocate anything into the stack frame.
    // If so, create enough stack space and insert the instructions at the front of the list.
    if (self.stack_size > 0) {
        var prologue = std.ArrayList(Mir.Inst).init(self.gpa);
        defer prologue.deinit();

        // load stack pointer
        try prologue.append(.{ .tag = .global_get, .data = .{ .label = 0 } });
        // store stack pointer so we can restore it when we return from the function
        try prologue.append(.{ .tag = .local_tee, .data = .{ .label = self.initial_stack_value.local } });
        // get the total stack size
        const aligned_stack = std.mem.alignForwardGeneric(u32, self.stack_size, self.stack_alignment);
        try prologue.append(.{ .tag = .i32_const, .data = .{ .imm32 = @intCast(i32, aligned_stack) } });
        // substract it from the current stack pointer
        try prologue.append(.{ .tag = .i32_sub, .data = .{ .tag = {} } });
        // Get negative stack aligment
        try prologue.append(.{ .tag = .i32_const, .data = .{ .imm32 = @intCast(i32, self.stack_alignment) * -1 } });
        // Bitwise-and the value to get the new stack pointer to ensure the pointers are aligned with the abi alignment
        try prologue.append(.{ .tag = .i32_and, .data = .{ .tag = {} } });
        // store the current stack pointer as the bottom, which will be used to calculate all stack pointer offsets
        try prologue.append(.{ .tag = .local_tee, .data = .{ .label = self.bottom_stack_value.local } });
        // Store the current stack pointer value into the global stack pointer so other function calls will
        // start from this value instead and not overwrite the current stack.
        try prologue.append(.{ .tag = .global_set, .data = .{ .label = 0 } });

        // reserve space and insert all prologue instructions at the front of the instruction list
        // We insert them in reserve order as there is no insertSlice in multiArrayList.
        try self.mir_instructions.ensureUnusedCapacity(self.gpa, prologue.items.len);
        for (prologue.items) |_, index| {
            const inst = prologue.items[prologue.items.len - 1 - index];
            self.mir_instructions.insertAssumeCapacity(0, inst);
        }
    }

    var mir: Mir = .{
        .instructions = self.mir_instructions.toOwnedSlice(),
        .extra = self.mir_extra.toOwnedSlice(self.gpa),
    };
    defer mir.deinit(self.gpa);

    var emit: Emit = .{
        .mir = mir,
        .bin_file = &self.bin_file.base,
        .code = self.code,
        .locals = self.locals.items,
        .decl = self.decl,
    };

    emit.emitMir() catch |err| switch (err) {
        error.EmitFail => {
            self.err_msg = emit.error_msg.?;
            return error.CodegenFail;
        },
        else => |e| return e,
    };
}

const CallWValues = struct {
    args: []WValue,
    return_value: WValue,

    fn deinit(self: *CallWValues, gpa: Allocator) void {
        gpa.free(self.args);
        self.* = undefined;
    }
};

fn resolveCallingConventionValues(self: *Self, fn_ty: Type) InnerError!CallWValues {
    const cc = fn_ty.fnCallingConvention();
    const param_types = try self.gpa.alloc(Type, fn_ty.fnParamLen());
    defer self.gpa.free(param_types);
    fn_ty.fnParamTypes(param_types);
    var result: CallWValues = .{
        .args = &.{},
        .return_value = .none,
    };
    var args = std.ArrayList(WValue).init(self.gpa);
    defer args.deinit();

    const ret_ty = fn_ty.fnReturnType();
    // Check if we store the result as a pointer to the stack rather than
    // by value
    if (isByRef(ret_ty, self.target)) {
        // the sret arg will be passed as first argument, therefore we
        // set the `return_value` before allocating locals for regular args.
        result.return_value = .{ .local = self.local_index };
        self.local_index += 1;
    }
    switch (cc) {
        .Naked => return result,
        .Unspecified, .C => {
            for (param_types) |ty| {
                if (!ty.hasRuntimeBitsIgnoreComptime()) {
                    continue;
                }

                try args.append(.{ .local = self.local_index });
                self.local_index += 1;
            }
        },
        else => return self.fail("TODO implement function parameters for cc '{}' on wasm", .{cc}),
    }
    result.args = args.toOwnedSlice();
    return result;
}

/// Creates a local for the initial stack value
/// Asserts `initial_stack_value` is `.none`
fn initializeStack(self: *Self) !void {
    assert(self.initial_stack_value == .none);
    // Reserve a local to store the current stack pointer
    // We can later use this local to set the stack pointer back to the value
    // we have stored here.
    self.initial_stack_value = try self.allocLocal(Type.usize);
    // Also reserve a local to store the bottom stack value
    self.bottom_stack_value = try self.allocLocal(Type.usize);
}

/// Reads the stack pointer from `Context.initial_stack_value` and writes it
/// to the global stack pointer variable
fn restoreStackPointer(self: *Self) !void {
    // only restore the pointer if it was initialized
    if (self.initial_stack_value == .none) return;
    // Get the original stack pointer's value
    try self.emitWValue(self.initial_stack_value);

    // save its value in the global stack pointer
    try self.addLabel(.global_set, 0);
}

/// From a given type, will create space on the virtual stack to store the value of such type.
/// This returns a `WValue` with its active tag set to `local`, containing the index to the local
/// that points to the position on the virtual stack. This function should be used instead of
/// moveStack unless a local was already created to store the pointer.
///
/// Asserts Type has codegenbits
fn allocStack(self: *Self, ty: Type) !WValue {
    assert(ty.hasRuntimeBitsIgnoreComptime());
    if (self.initial_stack_value == .none) {
        try self.initializeStack();
    }

    const abi_size = std.math.cast(u32, ty.abiSize(self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Type {} with ABI size of {d} exceeds stack frame size", .{
            ty.fmt(module), ty.abiSize(self.target),
        });
    };
    const abi_align = ty.abiAlignment(self.target);

    if (abi_align > self.stack_alignment) {
        self.stack_alignment = abi_align;
    }

    const offset = std.mem.alignForwardGeneric(u32, self.stack_size, abi_align);
    defer self.stack_size = offset + abi_size;

    return WValue{ .stack_offset = offset };
}

/// From a given AIR instruction generates a pointer to the stack where
/// the value of its type will live.
/// This is different from allocStack where this will use the pointer's alignment
/// if it is set, to ensure the stack alignment will be set correctly.
fn allocStackPtr(self: *Self, inst: Air.Inst.Index) !WValue {
    const ptr_ty = self.air.typeOfIndex(inst);
    const pointee_ty = ptr_ty.childType();

    if (self.initial_stack_value == .none) {
        try self.initializeStack();
    }

    if (!pointee_ty.hasRuntimeBitsIgnoreComptime()) {
        return self.allocStack(Type.usize); // create a value containing just the stack pointer.
    }

    const abi_alignment = ptr_ty.ptrAlignment(self.target);
    const abi_size = std.math.cast(u32, pointee_ty.abiSize(self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Type {} with ABI size of {d} exceeds stack frame size", .{
            pointee_ty.fmt(module), pointee_ty.abiSize(self.target),
        });
    };
    if (abi_alignment > self.stack_alignment) {
        self.stack_alignment = abi_alignment;
    }

    const offset = std.mem.alignForwardGeneric(u32, self.stack_size, abi_alignment);
    defer self.stack_size = offset + abi_size;

    return WValue{ .stack_offset = offset };
}

/// From given zig bitsize, returns the wasm bitsize
fn toWasmBits(bits: u16) ?u16 {
    return for ([_]u16{ 32, 64 }) |wasm_bits| {
        if (bits <= wasm_bits) return wasm_bits;
    } else null;
}

/// Performs a copy of bytes for a given type. Copying all bytes
/// from rhs to lhs.
fn memcpy(self: *Self, dst: WValue, src: WValue, len: WValue) !void {
    // When bulk_memory is enabled, we lower it to wasm's memcpy instruction.
    // If not, we lower it ourselves manually
    if (std.Target.wasm.featureSetHas(self.target.cpu.features, .bulk_memory)) {
        switch (dst) {
            .stack_offset => try self.emitWValue(try self.buildPointerOffset(dst, 0, .new)),
            else => try self.emitWValue(dst),
        }
        switch (src) {
            .stack_offset => try self.emitWValue(try self.buildPointerOffset(src, 0, .new)),
            else => try self.emitWValue(src),
        }
        try self.emitWValue(len);
        try self.addExtended(.memory_copy);
        return;
    }

    // when the length is comptime-known, rather than a runtime value, we can optimize the generated code by having
    // the loop during codegen, rather than inserting a runtime loop into the binary.
    switch (len) {
        .imm32, .imm64 => {
            const length = switch (len) {
                .imm32 => |val| val,
                .imm64 => |val| val,
                else => unreachable,
            };
            var offset: u32 = 0;
            const lhs_base = dst.offset();
            const rhs_base = src.offset();
            while (offset < length) : (offset += 1) {
                // get dst's address to store the result
                try self.emitWValue(dst);
                // load byte from src's address
                try self.emitWValue(src);
                switch (self.arch()) {
                    .wasm32 => {
                        try self.addMemArg(.i32_load8_u, .{ .offset = rhs_base + offset, .alignment = 1 });
                        try self.addMemArg(.i32_store8, .{ .offset = lhs_base + offset, .alignment = 1 });
                    },
                    .wasm64 => {
                        try self.addMemArg(.i64_load8_u, .{ .offset = rhs_base + offset, .alignment = 1 });
                        try self.addMemArg(.i64_store8, .{ .offset = lhs_base + offset, .alignment = 1 });
                    },
                    else => unreachable,
                }
            }
        },
        else => {
            // TODO: We should probably lower this to a call to compiler_rt
            // But for now, we implement it manually
            const offset = try self.allocLocal(Type.usize); // local for counter
            // outer block to jump to when loop is done
            try self.startBlock(.block, wasm.block_empty);
            try self.startBlock(.loop, wasm.block_empty);

            // loop condition (offset == length -> break)
            {
                try self.emitWValue(offset);
                try self.emitWValue(len);
                switch (self.arch()) {
                    .wasm32 => try self.addTag(.i32_eq),
                    .wasm64 => try self.addTag(.i64_eq),
                    else => unreachable,
                }
                try self.addLabel(.br_if, 1); // jump out of loop into outer block (finished)
            }

            // get dst ptr
            {
                try self.emitWValue(dst);
                try self.emitWValue(offset);
                switch (self.arch()) {
                    .wasm32 => try self.addTag(.i32_add),
                    .wasm64 => try self.addTag(.i64_add),
                    else => unreachable,
                }
            }

            // get src value and also store in dst
            {
                try self.emitWValue(src);
                try self.emitWValue(offset);
                switch (self.arch()) {
                    .wasm32 => {
                        try self.addTag(.i32_add);
                        try self.addMemArg(.i32_load8_u, .{ .offset = src.offset(), .alignment = 1 });
                        try self.addMemArg(.i32_store8, .{ .offset = dst.offset(), .alignment = 1 });
                    },
                    .wasm64 => {
                        try self.addTag(.i64_add);
                        try self.addMemArg(.i64_load8_u, .{ .offset = src.offset(), .alignment = 1 });
                        try self.addMemArg(.i64_store8, .{ .offset = dst.offset(), .alignment = 1 });
                    },
                    else => unreachable,
                }
            }

            // increment loop counter
            {
                try self.emitWValue(offset);
                switch (self.arch()) {
                    .wasm32 => {
                        try self.addImm32(1);
                        try self.addTag(.i32_add);
                    },
                    .wasm64 => {
                        try self.addImm64(1);
                        try self.addTag(.i64_add);
                    },
                    else => unreachable,
                }
                try self.addLabel(.local_set, offset.local);
                try self.addLabel(.br, 0); // jump to start of loop
            }
            try self.endBlock(); // close off loop block
            try self.endBlock(); // close off outer block
        },
    }
}

fn ptrSize(self: *const Self) u16 {
    return @divExact(self.target.cpu.arch.ptrBitWidth(), 8);
}

fn arch(self: *const Self) std.Target.Cpu.Arch {
    return self.target.cpu.arch;
}

/// For a given `Type`, will return true when the type will be passed
/// by reference, rather than by value
fn isByRef(ty: Type, target: std.Target) bool {
    switch (ty.zigTypeTag()) {
        .Type,
        .ComptimeInt,
        .ComptimeFloat,
        .EnumLiteral,
        .Undefined,
        .Null,
        .BoundFn,
        .Opaque,
        => unreachable,

        .NoReturn,
        .Void,
        .Bool,
        .Float,
        .ErrorSet,
        .Fn,
        .Enum,
        .AnyFrame,
        => return false,

        .Array,
        .Vector,
        .Struct,
        .Frame,
        .Union,
        => return ty.hasRuntimeBitsIgnoreComptime(),
        .Int => return if (ty.intInfo(target).bits > 64) true else false,
        .ErrorUnion => {
            const has_tag = ty.errorUnionSet().hasRuntimeBitsIgnoreComptime();
            const has_pl = ty.errorUnionPayload().hasRuntimeBitsIgnoreComptime();
            if (!has_tag or !has_pl) return false;
            return ty.hasRuntimeBitsIgnoreComptime();
        },
        .Optional => {
            if (ty.isPtrLikeOptional()) return false;
            var buf: Type.Payload.ElemType = undefined;
            return ty.optionalChild(&buf).hasRuntimeBitsIgnoreComptime();
        },
        .Pointer => {
            // Slices act like struct and will be passed by reference
            if (ty.isSlice()) return true;
            return false;
        },
    }
}

/// Creates a new local for a pointer that points to memory with given offset.
/// This can be used to get a pointer to a struct field, error payload, etc.
/// By providing `modify` as action, it will modify the given `ptr_value` instead of making a new
/// local value to store the pointer. This allows for local re-use and improves binary size.
fn buildPointerOffset(self: *Self, ptr_value: WValue, offset: u64, action: enum { modify, new }) InnerError!WValue {
    // do not perform arithmetic when offset is 0.
    if (offset == 0 and ptr_value.offset() == 0 and action == .modify) return ptr_value;
    const result_ptr: WValue = switch (action) {
        .new => try self.allocLocal(Type.usize),
        .modify => ptr_value,
    };
    try self.emitWValue(ptr_value);
    if (offset + ptr_value.offset() > 0) {
        switch (self.arch()) {
            .wasm32 => {
                try self.addImm32(@bitCast(i32, @intCast(u32, offset + ptr_value.offset())));
                try self.addTag(.i32_add);
            },
            .wasm64 => {
                try self.addImm64(offset + ptr_value.offset());
                try self.addTag(.i64_add);
            },
            else => unreachable,
        }
    }
    try self.addLabel(.local_set, result_ptr.local);
    return result_ptr;
}

fn genInst(self: *Self, inst: Air.Inst.Index) !WValue {
    const air_tags = self.air.instructions.items(.tag);
    return switch (air_tags[inst]) {
        .constant => unreachable,
        .const_ty => unreachable,

        .add => self.airBinOp(inst, .add),
        .addwrap => self.airWrapBinOp(inst, .add),
        .sub => self.airBinOp(inst, .sub),
        .subwrap => self.airWrapBinOp(inst, .sub),
        .mul => self.airBinOp(inst, .mul),
        .mulwrap => self.airWrapBinOp(inst, .mul),
        .div_trunc => self.airBinOp(inst, .div),
        .bit_and => self.airBinOp(inst, .@"and"),
        .bit_or => self.airBinOp(inst, .@"or"),
        .bool_and => self.airBinOp(inst, .@"and"),
        .bool_or => self.airBinOp(inst, .@"or"),
        .rem => self.airBinOp(inst, .rem),
        .shl => self.airWrapBinOp(inst, .shl),
        .shl_exact => self.airBinOp(inst, .shl),
        .shr, .shr_exact => self.airBinOp(inst, .shr),
        .xor => self.airBinOp(inst, .xor),
        .max => self.airMaxMin(inst, .max),
        .min => self.airMaxMin(inst, .min),
        .mul_add => self.airMulAdd(inst),

        .add_with_overflow => self.airBinOpOverflow(inst, .add),
        .sub_with_overflow => self.airBinOpOverflow(inst, .sub),
        .shl_with_overflow => self.airBinOpOverflow(inst, .shl),
        .mul_with_overflow => self.airBinOpOverflow(inst, .mul),

        .clz => self.airClz(inst),
        .ctz => self.airCtz(inst),

        .cmp_eq => self.airCmp(inst, .eq),
        .cmp_gte => self.airCmp(inst, .gte),
        .cmp_gt => self.airCmp(inst, .gt),
        .cmp_lte => self.airCmp(inst, .lte),
        .cmp_lt => self.airCmp(inst, .lt),
        .cmp_neq => self.airCmp(inst, .neq),

        .cmp_vector => self.airCmpVector(inst),
        .cmp_lt_errors_len => self.airCmpLtErrorsLen(inst),

        .array_elem_val => self.airArrayElemVal(inst),
        .array_to_slice => self.airArrayToSlice(inst),
        .alloc => self.airAlloc(inst),
        .arg => self.airArg(inst),
        .bitcast => self.airBitcast(inst),
        .block => self.airBlock(inst),
        .breakpoint => self.airBreakpoint(inst),
        .br => self.airBr(inst),
        .bool_to_int => self.airBoolToInt(inst),
        .cond_br => self.airCondBr(inst),
        .intcast => self.airIntcast(inst),
        .fptrunc => self.airFptrunc(inst),
        .fpext => self.airFpext(inst),
        .float_to_int => self.airFloatToInt(inst),
        .int_to_float => self.airIntToFloat(inst),
        .get_union_tag => self.airGetUnionTag(inst),

        // TODO
        .dbg_stmt,
        .dbg_inline_begin,
        .dbg_inline_end,
        .dbg_block_begin,
        .dbg_block_end,
        .dbg_var_ptr,
        .dbg_var_val,
        => WValue.none,

        .call => self.airCall(inst, .auto),
        .call_always_tail => self.airCall(inst, .always_tail),
        .call_never_tail => self.airCall(inst, .never_tail),
        .call_never_inline => self.airCall(inst, .never_inline),

        .is_err => self.airIsErr(inst, .i32_ne),
        .is_non_err => self.airIsErr(inst, .i32_eq),

        .is_null => self.airIsNull(inst, .i32_eq, .value),
        .is_non_null => self.airIsNull(inst, .i32_ne, .value),
        .is_null_ptr => self.airIsNull(inst, .i32_eq, .ptr),
        .is_non_null_ptr => self.airIsNull(inst, .i32_ne, .ptr),

        .load => self.airLoad(inst),
        .loop => self.airLoop(inst),
        .memset => self.airMemset(inst),
        .not => self.airNot(inst),
        .optional_payload => self.airOptionalPayload(inst),
        .optional_payload_ptr => self.airOptionalPayloadPtr(inst),
        .optional_payload_ptr_set => self.airOptionalPayloadPtrSet(inst),
        .ptr_add => self.airPtrBinOp(inst, .add),
        .ptr_sub => self.airPtrBinOp(inst, .sub),
        .ptr_elem_ptr => self.airPtrElemPtr(inst),
        .ptr_elem_val => self.airPtrElemVal(inst),
        .ptrtoint => self.airPtrToInt(inst),
        .ret => self.airRet(inst),
        .ret_ptr => self.airRetPtr(inst),
        .ret_load => self.airRetLoad(inst),
        .splat => self.airSplat(inst),
        .select => self.airSelect(inst),
        .shuffle => self.airShuffle(inst),
        .reduce => self.airReduce(inst),
        .aggregate_init => self.airAggregateInit(inst),
        .union_init => self.airUnionInit(inst),
        .prefetch => self.airPrefetch(inst),
        .popcount => self.airPopcount(inst),

        .slice => self.airSlice(inst),
        .slice_len => self.airSliceLen(inst),
        .slice_elem_val => self.airSliceElemVal(inst),
        .slice_elem_ptr => self.airSliceElemPtr(inst),
        .slice_ptr => self.airSlicePtr(inst),
        .ptr_slice_len_ptr => self.airPtrSliceFieldPtr(inst, self.ptrSize()),
        .ptr_slice_ptr_ptr => self.airPtrSliceFieldPtr(inst, 0),
        .store => self.airStore(inst),

        .set_union_tag => self.airSetUnionTag(inst),
        .struct_field_ptr => self.airStructFieldPtr(inst),
        .struct_field_ptr_index_0 => self.airStructFieldPtrIndex(inst, 0),
        .struct_field_ptr_index_1 => self.airStructFieldPtrIndex(inst, 1),
        .struct_field_ptr_index_2 => self.airStructFieldPtrIndex(inst, 2),
        .struct_field_ptr_index_3 => self.airStructFieldPtrIndex(inst, 3),
        .struct_field_val => self.airStructFieldVal(inst),
        .field_parent_ptr => self.airFieldParentPtr(inst),

        .switch_br => self.airSwitchBr(inst),
        .trunc => self.airTrunc(inst),
        .unreach => self.airUnreachable(inst),

        .wrap_optional => self.airWrapOptional(inst),
        .unwrap_errunion_payload => self.airUnwrapErrUnionPayload(inst, false),
        .unwrap_errunion_payload_ptr => self.airUnwrapErrUnionPayload(inst, true),
        .unwrap_errunion_err => self.airUnwrapErrUnionError(inst, false),
        .unwrap_errunion_err_ptr => self.airUnwrapErrUnionError(inst, true),
        .wrap_errunion_payload => self.airWrapErrUnionPayload(inst),
        .wrap_errunion_err => self.airWrapErrUnionErr(inst),
        .errunion_payload_ptr_set => self.airErrUnionPayloadPtrSet(inst),
        .error_name => self.airErrorName(inst),

        .wasm_memory_size => self.airWasmMemorySize(inst),
        .wasm_memory_grow => self.airWasmMemoryGrow(inst),

        .memcpy => self.airMemcpy(inst),

        .add_sat,
        .sub_sat,
        .mul_sat,
        .div_float,
        .div_floor,
        .div_exact,
        .mod,
        .assembly,
        .shl_sat,
        .ret_addr,
        .frame_addr,
        .byte_swap,
        .bit_reverse,
        .is_err_ptr,
        .is_non_err_ptr,

        .sqrt,
        .sin,
        .cos,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .fabs,
        .floor,
        .ceil,
        .round,
        .trunc_float,

        .cmpxchg_weak,
        .cmpxchg_strong,
        .fence,
        .atomic_load,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .atomic_rmw,
        .tag_name,
        => |tag| return self.fail("TODO: Implement wasm inst: {s}", .{@tagName(tag)}),
    };
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    for (body) |inst| {
        const result = try self.genInst(inst);
        try self.values.putNoClobber(self.gpa, Air.indexToRef(inst), result);
    }
}

fn airRet(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);

    // result must be stored in the stack and we return a pointer
    // to the stack instead
    if (self.return_value != .none) {
        try self.store(self.return_value, operand, self.decl.ty.fnReturnType(), 0);
    } else {
        try self.emitWValue(operand);
    }
    try self.restoreStackPointer();
    try self.addTag(.@"return");
    return WValue{ .none = {} };
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const child_type = self.air.typeOfIndex(inst).childType();

    if (!child_type.isFnOrHasRuntimeBitsIgnoreComptime()) {
        return self.allocStack(Type.usize); // create pointer to void
    }

    if (isByRef(child_type, self.target)) {
        return self.return_value;
    }
    return self.allocStackPtr(inst);
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ret_ty = self.air.typeOf(un_op).childType();
    if (!ret_ty.hasRuntimeBitsIgnoreComptime()) return WValue.none;

    if (!isByRef(ret_ty, self.target)) {
        const result = try self.load(operand, ret_ty, 0);
        try self.emitWValue(result);
    }

    try self.restoreStackPointer();
    try self.addTag(.@"return");
    return .none;
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) InnerError!WValue {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for wasm", .{});
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = self.air.extra[extra.end..][0..extra.data.args_len];
    const ty = self.air.typeOf(pl_op.operand);

    const fn_ty = switch (ty.zigTypeTag()) {
        .Fn => ty,
        .Pointer => ty.childType(),
        else => unreachable,
    };
    const ret_ty = fn_ty.fnReturnType();
    const first_param_sret = isByRef(ret_ty, self.target);

    const callee: ?*Decl = blk: {
        const func_val = self.air.value(pl_op.operand) orelse break :blk null;
        const module = self.bin_file.base.options.module.?;

        if (func_val.castTag(.function)) |func| {
            break :blk module.declPtr(func.data.owner_decl);
        } else if (func_val.castTag(.extern_fn)) |extern_fn| {
            const ext_decl = module.declPtr(extern_fn.data.owner_decl);
            var func_type = try genFunctype(self.gpa, ext_decl.ty, self.target);
            defer func_type.deinit(self.gpa);
            ext_decl.fn_link.wasm.type_index = try self.bin_file.putOrGetFuncType(func_type);
            try self.bin_file.addOrUpdateImport(ext_decl);
            break :blk ext_decl;
        } else if (func_val.castTag(.decl_ref)) |decl_ref| {
            break :blk module.declPtr(decl_ref.data);
        }
        return self.fail("Expected a function, but instead found type '{s}'", .{func_val.tag()});
    };

    const sret = if (first_param_sret) blk: {
        const sret_local = try self.allocStack(ret_ty);
        const ptr_offset = try self.buildPointerOffset(sret_local, 0, .new);
        try self.emitWValue(ptr_offset);
        break :blk sret_local;
    } else WValue{ .none = {} };

    for (args) |arg| {
        const arg_ref = @intToEnum(Air.Inst.Ref, arg);
        const arg_val = try self.resolveInst(arg_ref);

        const arg_ty = self.air.typeOf(arg_ref);
        if (!arg_ty.hasRuntimeBitsIgnoreComptime()) continue;

        switch (arg_val) {
            .stack_offset => try self.emitWValue(try self.buildPointerOffset(arg_val, 0, .new)),
            else => try self.emitWValue(arg_val),
        }
    }

    if (callee) |direct| {
        try self.addLabel(.call, direct.link.wasm.sym_index);
    } else {
        // in this case we call a function pointer
        // so load its value onto the stack
        std.debug.assert(ty.zigTypeTag() == .Pointer);
        const operand = try self.resolveInst(pl_op.operand);
        try self.emitWValue(operand);

        var fn_type = try genFunctype(self.gpa, fn_ty, self.target);
        defer fn_type.deinit(self.gpa);

        const fn_type_index = try self.bin_file.putOrGetFuncType(fn_type);
        try self.addLabel(.call_indirect, fn_type_index);
    }

    if (self.liveness.isUnused(inst) or !ret_ty.hasRuntimeBitsIgnoreComptime()) {
        return WValue.none;
    } else if (ret_ty.isNoReturn()) {
        try self.addTag(.@"unreachable");
        return WValue.none;
    } else if (first_param_sret) {
        return sret;
    } else {
        const result_local = try self.allocLocal(ret_ty);
        try self.addLabel(.local_set, result_local.local);
        return result_local;
    }
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    return self.allocStackPtr(inst);
}

fn airStore(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const ty = self.air.typeOf(bin_op.lhs).childType();

    try self.store(lhs, rhs, ty, 0);
    return .none;
}

fn store(self: *Self, lhs: WValue, rhs: WValue, ty: Type, offset: u32) InnerError!void {
    switch (ty.zigTypeTag()) {
        .ErrorUnion => {
            const err_ty = ty.errorUnionSet();
            const pl_ty = ty.errorUnionPayload();
            if (!pl_ty.hasRuntimeBitsIgnoreComptime()) {
                return self.store(lhs, rhs, err_ty, 0);
            }

            const len = @intCast(u32, ty.abiSize(self.target));
            return self.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Optional => {
            if (ty.isPtrLikeOptional()) {
                return self.store(lhs, rhs, Type.usize, 0);
            }
            var buf: Type.Payload.ElemType = undefined;
            const pl_ty = ty.optionalChild(&buf);
            if (!pl_ty.hasRuntimeBitsIgnoreComptime()) {
                return self.store(lhs, rhs, Type.u8, 0);
            }

            const len = @intCast(u32, ty.abiSize(self.target));
            return self.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Struct, .Array, .Union, .Vector => {
            const len = @intCast(u32, ty.abiSize(self.target));
            return self.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        .Pointer => {
            if (ty.isSlice()) {
                // store pointer first
                const ptr_local = try self.load(rhs, Type.usize, 0);
                try self.store(lhs, ptr_local, Type.usize, 0);

                // retrieve length from rhs, and store that alongside lhs as well
                const len_local = try self.load(rhs, Type.usize, self.ptrSize());
                try self.store(lhs, len_local, Type.usize, self.ptrSize());
                return;
            }
        },
        .Int => if (ty.intInfo(self.target).bits > 64) {
            const len = @intCast(u32, ty.abiSize(self.target));
            return self.memcpy(lhs, rhs, .{ .imm32 = len });
        },
        else => {},
    }
    try self.emitWValue(lhs);
    // In this case we're actually interested in storing the stack position
    // into lhs, so we calculate that and emit that instead
    if (rhs == .stack_offset) {
        try self.emitWValue(try self.buildPointerOffset(rhs, 0, .new));
    } else {
        try self.emitWValue(rhs);
    }
    const valtype = typeToValtype(ty, self.target);
    const abi_size = @intCast(u8, ty.abiSize(self.target));

    const opcode = buildOpcode(.{
        .valtype1 = valtype,
        .width = abi_size * 8, // use bitsize instead of byte size
        .op = .store,
    });

    // store rhs value at stack pointer's location in memory
    try self.addMemArg(
        Mir.Inst.Tag.fromOpcode(opcode),
        .{ .offset = offset + lhs.offset(), .alignment = ty.abiAlignment(self.target) },
    );
}

fn airLoad(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const ty = self.air.getRefType(ty_op.ty);

    if (!ty.hasRuntimeBitsIgnoreComptime()) return WValue{ .none = {} };

    if (isByRef(ty, self.target)) {
        const new_local = try self.allocStack(ty);
        try self.store(new_local, operand, ty, 0);
        return new_local;
    }

    return self.load(operand, ty, 0);
}

fn load(self: *Self, operand: WValue, ty: Type, offset: u32) InnerError!WValue {
    // load local's value from memory by its stack position
    try self.emitWValue(operand);
    // Build the opcode with the right bitsize
    const signedness: std.builtin.Signedness = if (ty.isUnsignedInt() or
        ty.zigTypeTag() == .ErrorSet or
        ty.zigTypeTag() == .Bool)
        .unsigned
    else
        .signed;

    const abi_size = @intCast(u8, ty.abiSize(self.target));

    const opcode = buildOpcode(.{
        .valtype1 = typeToValtype(ty, self.target),
        .width = abi_size * 8, // use bitsize instead of byte size
        .op = .load,
        .signedness = signedness,
    });

    try self.addMemArg(
        Mir.Inst.Tag.fromOpcode(opcode),
        .{ .offset = offset + operand.offset(), .alignment = ty.abiAlignment(self.target) },
    );

    // store the result in a local
    const result = try self.allocLocal(ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airArg(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    _ = inst;
    defer self.arg_index += 1;
    return self.args[self.arg_index];
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, op: Op) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const operand_ty = self.air.typeOfIndex(inst);
    const ty = self.air.typeOf(bin_op.lhs);

    if (isByRef(operand_ty, self.target)) {
        return self.fail("TODO: Implement binary operation for type: {}", .{operand_ty.fmtDebug()});
    }

    return self.binOp(lhs, rhs, ty, op);
}

fn binOp(self: *Self, lhs: WValue, rhs: WValue, ty: Type, op: Op) InnerError!WValue {
    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    const opcode: wasm.Opcode = buildOpcode(.{
        .op = op,
        .valtype1 = typeToValtype(ty, self.target),
        .signedness = if (ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    // save the result in a temporary
    const bin_local = try self.allocLocal(ty);
    try self.addLabel(.local_set, bin_local.local);
    return bin_local;
}

fn airWrapBinOp(self: *Self, inst: Air.Inst.Index, op: Op) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);

    return self.wrapBinOp(lhs, rhs, self.air.typeOf(bin_op.lhs), op);
}

fn wrapBinOp(self: *Self, lhs: WValue, rhs: WValue, ty: Type, op: Op) InnerError!WValue {
    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    const opcode: wasm.Opcode = buildOpcode(.{
        .op = op,
        .valtype1 = typeToValtype(ty, self.target),
        .signedness = if (ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const int_info = ty.intInfo(self.target);
    const bitsize = int_info.bits;
    const is_signed = int_info.signedness == .signed;
    // if target type bitsize is x < 32 and 32 > x < 64, we perform
    // result & ((1<<N)-1) where N = bitsize or bitsize -1 incase of signed.
    if (bitsize != 32 and bitsize < 64) {
        // first check if we can use a single instruction,
        // wasm provides those if the integers are signed and 8/16-bit.
        // For arbitrary integer sizes, we use the algorithm mentioned above.
        if (is_signed and bitsize == 8) {
            try self.addTag(.i32_extend8_s);
        } else if (is_signed and bitsize == 16) {
            try self.addTag(.i32_extend16_s);
        } else {
            const result = (@as(u64, 1) << @intCast(u6, bitsize - @boolToInt(is_signed))) - 1;
            if (bitsize < 32) {
                try self.addImm32(@bitCast(i32, @intCast(u32, result)));
                try self.addTag(.i32_and);
            } else {
                try self.addImm64(result);
                try self.addTag(.i64_and);
            }
        }
    } else if (int_info.bits > 64) {
        return self.fail("TODO wasm: Integer wrapping for bitsizes larger than 64", .{});
    }

    // save the result in a temporary
    const bin_local = try self.allocLocal(ty);
    try self.addLabel(.local_set, bin_local.local);
    return bin_local;
}

fn lowerParentPtr(self: *Self, ptr_val: Value, ptr_child_ty: Type) InnerError!WValue {
    switch (ptr_val.tag()) {
        .decl_ref_mut => {
            const decl_index = ptr_val.castTag(.decl_ref_mut).?.data.decl_index;
            return self.lowerParentPtrDecl(ptr_val, decl_index);
        },
        .decl_ref => {
            const decl_index = ptr_val.castTag(.decl_ref).?.data;
            return self.lowerParentPtrDecl(ptr_val, decl_index);
        },
        .variable => {
            const decl_index = ptr_val.castTag(.variable).?.data.owner_decl;
            return self.lowerParentPtrDecl(ptr_val, decl_index);
        },
        .field_ptr => {
            const field_ptr = ptr_val.castTag(.field_ptr).?.data;
            const parent_ty = field_ptr.container_ty;
            const parent_ptr = try self.lowerParentPtr(field_ptr.container_ptr, parent_ty);

            const offset = switch (parent_ty.zigTypeTag()) {
                .Struct => blk: {
                    const offset = parent_ty.structFieldOffset(field_ptr.field_index, self.target);
                    break :blk offset;
                },
                .Union => blk: {
                    const layout: Module.Union.Layout = parent_ty.unionGetLayout(self.target);
                    if (layout.payload_size == 0) break :blk 0;
                    if (layout.payload_align > layout.tag_align) break :blk 0;

                    // tag is stored first so calculate offset from where payload starts
                    const offset = @intCast(u32, std.mem.alignForwardGeneric(u64, layout.tag_size, layout.tag_align));
                    break :blk offset;
                },
                else => unreachable,
            };

            return switch (parent_ptr) {
                .memory => |ptr| WValue{
                    .memory_offset = .{
                        .pointer = ptr,
                        .offset = @intCast(u32, offset),
                    },
                },
                .memory_offset => |mem_off| WValue{
                    .memory_offset = .{
                        .pointer = mem_off.pointer,
                        .offset = @intCast(u32, offset) + mem_off.offset,
                    },
                },
                else => unreachable,
            };
        },
        .elem_ptr => {
            const elem_ptr = ptr_val.castTag(.elem_ptr).?.data;
            const index = elem_ptr.index;
            const offset = index * ptr_child_ty.abiSize(self.target);
            const array_ptr = try self.lowerParentPtr(elem_ptr.array_ptr, elem_ptr.elem_ty);

            return WValue{ .memory_offset = .{
                .pointer = array_ptr.memory,
                .offset = @intCast(u32, offset),
            } };
        },
        .opt_payload_ptr => {
            const payload_ptr = ptr_val.castTag(.opt_payload_ptr).?.data;
            const parent_ptr = try self.lowerParentPtr(payload_ptr.container_ptr, payload_ptr.container_ty);
            var buf: Type.Payload.ElemType = undefined;
            const payload_ty = payload_ptr.container_ty.optionalChild(&buf);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime() or payload_ty.isPtrLikeOptional()) {
                return parent_ptr;
            }

            const abi_size = payload_ptr.container_ty.abiSize(self.target);
            const offset = abi_size - payload_ty.abiSize(self.target);

            return WValue{ .memory_offset = .{
                .pointer = parent_ptr.memory,
                .offset = @intCast(u32, offset),
            } };
        },
        else => |tag| return self.fail("TODO: Implement lowerParentPtr for tag: {}", .{tag}),
    }
}

fn lowerParentPtrDecl(self: *Self, ptr_val: Value, decl_index: Module.Decl.Index) InnerError!WValue {
    const module = self.bin_file.base.options.module.?;
    const decl = module.declPtr(decl_index);
    module.markDeclAlive(decl);
    var ptr_ty_payload: Type.Payload.ElemType = .{
        .base = .{ .tag = .single_mut_pointer },
        .data = decl.ty,
    };
    const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
    return self.lowerDeclRefValue(.{ .ty = ptr_ty, .val = ptr_val }, decl_index);
}

fn lowerDeclRefValue(self: *Self, tv: TypedValue, decl_index: Module.Decl.Index) InnerError!WValue {
    if (tv.ty.isSlice()) {
        return WValue{ .memory = try self.bin_file.lowerUnnamedConst(tv, decl_index) };
    }

    const module = self.bin_file.base.options.module.?;
    const decl = module.declPtr(decl_index);
    if (decl.ty.zigTypeTag() != .Fn and !decl.ty.hasRuntimeBitsIgnoreComptime()) {
        return WValue{ .imm32 = 0xaaaaaaaa };
    }

    module.markDeclAlive(decl);

    const target_sym_index = decl.link.wasm.sym_index;
    if (decl.ty.zigTypeTag() == .Fn) {
        try self.bin_file.addTableFunction(target_sym_index);
        return WValue{ .function_index = target_sym_index };
    } else return WValue{ .memory = target_sym_index };
}

fn lowerConstant(self: *Self, val: Value, ty: Type) InnerError!WValue {
    if (val.isUndefDeep()) return self.emitUndefined(ty);
    if (val.castTag(.decl_ref)) |decl_ref| {
        const decl_index = decl_ref.data;
        return self.lowerDeclRefValue(.{ .ty = ty, .val = val }, decl_index);
    }
    if (val.castTag(.decl_ref_mut)) |decl_ref_mut| {
        const decl_index = decl_ref_mut.data.decl_index;
        return self.lowerDeclRefValue(.{ .ty = ty, .val = val }, decl_index);
    }

    const target = self.target;

    switch (ty.zigTypeTag()) {
        .Int => {
            const int_info = ty.intInfo(self.target);
            // write constant
            switch (int_info.signedness) {
                .signed => switch (int_info.bits) {
                    0...32 => return WValue{ .imm32 = @bitCast(u32, @intCast(i32, val.toSignedInt())) },
                    33...64 => return WValue{ .imm64 = @bitCast(u64, val.toSignedInt()) },
                    else => unreachable,
                },
                .unsigned => switch (int_info.bits) {
                    0...32 => return WValue{ .imm32 = @intCast(u32, val.toUnsignedInt(target)) },
                    33...64 => return WValue{ .imm64 = val.toUnsignedInt(target) },
                    else => unreachable,
                },
            }
        },
        .Bool => return WValue{ .imm32 = @intCast(u32, val.toUnsignedInt(target)) },
        .Float => switch (ty.floatBits(self.target)) {
            0...32 => return WValue{ .float32 = val.toFloat(f32) },
            33...64 => return WValue{ .float64 = val.toFloat(f64) },
            else => unreachable,
        },
        .Pointer => switch (val.tag()) {
            .field_ptr, .elem_ptr, .opt_payload_ptr => {
                return self.lowerParentPtr(val, ty.childType());
            },
            .int_u64, .one => return WValue{ .imm32 = @intCast(u32, val.toUnsignedInt(target)) },
            .zero, .null_value => return WValue{ .imm32 = 0 },
            else => return self.fail("Wasm TODO: lowerConstant for other const pointer tag {s}", .{val.tag()}),
        },
        .Enum => {
            if (val.castTag(.enum_field_index)) |field_index| {
                switch (ty.tag()) {
                    .enum_simple => return WValue{ .imm32 = field_index.data },
                    .enum_full, .enum_nonexhaustive => {
                        const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                        if (enum_full.values.count() != 0) {
                            const tag_val = enum_full.values.keys()[field_index.data];
                            return self.lowerConstant(tag_val, enum_full.tag_ty);
                        } else {
                            return WValue{ .imm32 = field_index.data };
                        }
                    },
                    .enum_numbered => {
                        const index = field_index.data;
                        const enum_data = ty.castTag(.enum_numbered).?.data;
                        const enum_val = enum_data.values.keys()[index];
                        return self.lowerConstant(enum_val, enum_data.tag_ty);
                    },
                    else => return self.fail("TODO: lowerConstant for enum tag: {}", .{ty.tag()}),
                }
            } else {
                var int_tag_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&int_tag_buffer);
                return self.lowerConstant(val, int_tag_ty);
            }
        },
        .ErrorSet => switch (val.tag()) {
            .@"error" => {
                const kv = try self.bin_file.base.options.module.?.getErrorValue(val.getError().?);
                return WValue{ .imm32 = kv.value };
            },
            else => return WValue{ .imm32 = 0 },
        },
        .ErrorUnion => {
            const error_type = ty.errorUnionSet();
            const is_pl = val.errorUnionIsPayload();
            const err_val = if (!is_pl) val else Value.initTag(.zero);
            return self.lowerConstant(err_val, error_type);
        },
        .Optional => if (ty.isPtrLikeOptional()) {
            var buf: Type.Payload.ElemType = undefined;
            const pl_ty = ty.optionalChild(&buf);
            if (val.castTag(.opt_payload)) |payload| {
                return self.lowerConstant(payload.data, pl_ty);
            } else if (val.isNull()) {
                return WValue{ .imm32 = 0 };
            } else {
                return self.lowerConstant(val, pl_ty);
            }
        } else {
            const is_pl = val.tag() == .opt_payload;
            return WValue{ .imm32 = if (is_pl) @as(u32, 1) else 0 };
        },
        else => |zig_type| return self.fail("Wasm TODO: LowerConstant for zigTypeTag {s}", .{zig_type}),
    }
}

fn emitUndefined(self: *Self, ty: Type) InnerError!WValue {
    switch (ty.zigTypeTag()) {
        .Bool, .ErrorSet => return WValue{ .imm32 = 0xaaaaaaaa },
        .Int => switch (ty.intInfo(self.target).bits) {
            0...32 => return WValue{ .imm32 = 0xaaaaaaaa },
            33...64 => return WValue{ .imm64 = 0xaaaaaaaaaaaaaaaa },
            else => unreachable,
        },
        .Float => switch (ty.floatBits(self.target)) {
            0...32 => return WValue{ .float32 = @bitCast(f32, @as(u32, 0xaaaaaaaa)) },
            33...64 => return WValue{ .float64 = @bitCast(f64, @as(u64, 0xaaaaaaaaaaaaaaaa)) },
            else => unreachable,
        },
        .Pointer => switch (self.arch()) {
            .wasm32 => return WValue{ .imm32 = 0xaaaaaaaa },
            .wasm64 => return WValue{ .imm64 = 0xaaaaaaaaaaaaaaaa },
            else => unreachable,
        },
        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            const pl_ty = ty.optionalChild(&buf);
            if (ty.isPtrLikeOptional()) {
                return self.emitUndefined(pl_ty);
            }
            return WValue{ .imm32 = 0xaaaaaaaa };
        },
        .ErrorUnion => {
            return WValue{ .imm32 = 0xaaaaaaaa };
        },
        else => return self.fail("Wasm TODO: emitUndefined for type: {}\n", .{ty.zigTypeTag()}),
    }
}

/// Returns a `Value` as a signed 32 bit value.
/// It's illegal to provide a value with a type that cannot be represented
/// as an integer value.
fn valueAsI32(self: Self, val: Value, ty: Type) i32 {
    const target = self.target;
    switch (ty.zigTypeTag()) {
        .Enum => {
            if (val.castTag(.enum_field_index)) |field_index| {
                switch (ty.tag()) {
                    .enum_simple => return @bitCast(i32, field_index.data),
                    .enum_full, .enum_nonexhaustive => {
                        const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                        if (enum_full.values.count() != 0) {
                            const tag_val = enum_full.values.keys()[field_index.data];
                            return self.valueAsI32(tag_val, enum_full.tag_ty);
                        } else return @bitCast(i32, field_index.data);
                    },
                    .enum_numbered => {
                        const index = field_index.data;
                        const enum_data = ty.castTag(.enum_numbered).?.data;
                        return self.valueAsI32(enum_data.values.keys()[index], enum_data.tag_ty);
                    },
                    else => unreachable,
                }
            } else {
                var int_tag_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&int_tag_buffer);
                return self.valueAsI32(val, int_tag_ty);
            }
        },
        .Int => switch (ty.intInfo(self.target).signedness) {
            .signed => return @truncate(i32, val.toSignedInt()),
            .unsigned => return @bitCast(i32, @truncate(u32, val.toUnsignedInt(target))),
        },
        .ErrorSet => {
            const kv = self.bin_file.base.options.module.?.getErrorValue(val.getError().?) catch unreachable; // passed invalid `Value` to function
            return @bitCast(i32, kv.value);
        },
        .Bool => return @intCast(i32, val.toSignedInt()),
        .Pointer => return @intCast(i32, val.toSignedInt()),
        else => unreachable, // Programmer called this function for an illegal type
    }
}

fn airBlock(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const block_ty = genBlockType(self.air.getRefType(ty_pl.ty), self.target);
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];

    // if block_ty is non-empty, we create a register to store the temporary value
    const block_result: WValue = if (block_ty != wasm.block_empty)
        try self.allocLocal(self.air.getRefType(ty_pl.ty))
    else
        WValue.none;

    try self.startBlock(.block, wasm.block_empty);
    // Here we set the current block idx, so breaks know the depth to jump
    // to when breaking out.
    try self.blocks.putNoClobber(self.gpa, inst, .{
        .label = self.block_depth,
        .value = block_result,
    });
    try self.genBody(body);
    try self.endBlock();

    return block_result;
}

/// appends a new wasm block to the code section and increases the `block_depth` by 1
fn startBlock(self: *Self, block_tag: wasm.Opcode, valtype: u8) !void {
    self.block_depth += 1;
    try self.addInst(.{
        .tag = Mir.Inst.Tag.fromOpcode(block_tag),
        .data = .{ .block_type = valtype },
    });
}

/// Ends the current wasm block and decreases the `block_depth` by 1
fn endBlock(self: *Self) !void {
    try self.addTag(.end);
    self.block_depth -= 1;
}

fn airLoop(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[loop.end..][0..loop.data.body_len];

    // result type of loop is always 'noreturn', meaning we can always
    // emit the wasm type 'block_empty'.
    try self.startBlock(.loop, wasm.block_empty);
    try self.genBody(body);

    // breaking to the index of a loop block will continue the loop instead
    try self.addLabel(.br, 0);
    try self.endBlock();

    return .none;
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    // TODO: Handle death instructions for then and else body

    // result type is always noreturn, so use `block_empty` as type.
    try self.startBlock(.block, wasm.block_empty);
    // emit the conditional value
    try self.emitWValue(condition);

    // we inserted the block in front of the condition
    // so now check if condition matches. If not, break outside this block
    // and continue with the then codepath
    try self.addLabel(.br_if, 0);

    try self.genBody(else_body);
    try self.endBlock();

    // Outer block that matches the condition
    try self.genBody(then_body);

    return .none;
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: std.math.CompareOperator) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const operand_ty = self.air.typeOf(bin_op.lhs);
    return self.cmp(lhs, rhs, operand_ty, op);
}

fn cmp(self: *Self, lhs: WValue, rhs: WValue, ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    if (ty.zigTypeTag() == .Optional and !ty.isPtrLikeOptional()) {
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = ty.optionalChild(&buf);
        if (payload_ty.hasRuntimeBitsIgnoreComptime()) {
            // When we hit this case, we must check the value of optionals
            // that are not pointers. This means first checking against non-null for
            // both lhs and rhs, as well as checking the payload are matching of lhs and rhs
            return self.cmpOptionals(lhs, rhs, ty, op);
        }
    } else if (isByRef(ty, self.target)) {
        return self.cmpBigInt(lhs, rhs, ty, op);
    }

    // ensure that when we compare pointers, we emit
    // the true pointer of a stack value, rather than the stack pointer.
    switch (lhs) {
        .stack_offset => try self.emitWValue(try self.buildPointerOffset(lhs, 0, .new)),
        else => try self.emitWValue(lhs),
    }
    switch (rhs) {
        .stack_offset => try self.emitWValue(try self.buildPointerOffset(rhs, 0, .new)),
        else => try self.emitWValue(rhs),
    }

    const signedness: std.builtin.Signedness = blk: {
        // by default we tell the operand type is unsigned (i.e. bools and enum values)
        if (ty.zigTypeTag() != .Int) break :blk .unsigned;

        // incase of an actual integer, we emit the correct signedness
        break :blk ty.intInfo(self.target).signedness;
    };
    const opcode: wasm.Opcode = buildOpcode(.{
        .valtype1 = typeToValtype(ty, self.target),
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
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const cmp_tmp = try self.allocLocal(Type.initTag(.i32)); // bool is always i32
    try self.addLabel(.local_set, cmp_tmp.local);
    return cmp_tmp;
}

fn airCmpVector(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    _ = inst;
    return self.fail("TODO implement airCmpVector for wasm", .{});
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);

    _ = operand;
    return self.fail("TODO implement airCmpLtErrorsLen for wasm", .{});
}

fn airBr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const br = self.air.instructions.items(.data)[inst].br;
    const block = self.blocks.get(br.block_inst).?;

    // if operand has codegen bits we should break with a value
    if (self.air.typeOf(br.operand).hasRuntimeBitsIgnoreComptime()) {
        const operand = try self.resolveInst(br.operand);
        const op = switch (operand) {
            .stack_offset => try self.buildPointerOffset(operand, 0, .new),
            else => operand,
        };
        try self.emitWValue(op);

        if (block.value != .none) {
            try self.addLabel(.local_set, block.value.local);
        }
    }

    // We map every block to its block index.
    // We then determine how far we have to jump to it by subtracting it from current block depth
    const idx: u32 = self.block_depth - block.label;
    try self.addLabel(.br, idx);

    return .none;
}

fn airNot(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const operand = try self.resolveInst(ty_op.operand);
    try self.emitWValue(operand);

    // wasm does not have booleans nor the `not` instruction, therefore compare with 0
    // to create the same logic
    try self.addTag(.i32_eqz);

    // save the result in the local
    const not_tmp = try self.allocLocal(Type.initTag(.i32));
    try self.addLabel(.local_set, not_tmp.local);
    return not_tmp;
}

fn airBreakpoint(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    _ = self;
    _ = inst;
    // unsupported by wasm itself. Can be implemented once we support DWARF
    // for wasm
    return .none;
}

fn airUnreachable(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    _ = inst;
    try self.addTag(.@"unreachable");
    return .none;
}

fn airBitcast(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    return self.resolveInst(ty_op.operand);
}

fn airStructFieldPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload);
    const struct_ptr = try self.resolveInst(extra.data.struct_operand);
    const struct_ty = self.air.typeOf(extra.data.struct_operand).childType();
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(extra.data.field_index, self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Field type '{}' too big to fit into stack frame", .{
            struct_ty.structFieldType(extra.data.field_index).fmt(module),
        });
    };
    return self.structFieldPtr(struct_ptr, offset);
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u32) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const struct_ptr = try self.resolveInst(ty_op.operand);
    const struct_ty = self.air.typeOf(ty_op.operand).childType();
    const field_ty = struct_ty.structFieldType(index);
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(index, self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Field type '{}' too big to fit into stack frame", .{
            field_ty.fmt(module),
        });
    };
    return self.structFieldPtr(struct_ptr, offset);
}

fn structFieldPtr(self: *Self, struct_ptr: WValue, offset: u32) InnerError!WValue {
    switch (struct_ptr) {
        .stack_offset => |stack_offset| {
            return WValue{ .stack_offset = stack_offset + offset };
        },
        else => return self.buildPointerOffset(struct_ptr, offset, .new),
    }
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const struct_ty = self.air.typeOf(struct_field.struct_operand);
    const operand = try self.resolveInst(struct_field.struct_operand);
    const field_index = struct_field.field_index;
    const field_ty = struct_ty.structFieldType(field_index);
    if (!field_ty.hasRuntimeBitsIgnoreComptime()) return WValue{ .none = {} };
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(field_index, self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Field type '{}' too big to fit into stack frame", .{field_ty.fmt(module)});
    };

    if (isByRef(field_ty, self.target)) {
        switch (operand) {
            .stack_offset => |stack_offset| {
                return WValue{ .stack_offset = stack_offset + offset };
            },
            else => return self.buildPointerOffset(operand, offset, .new),
        }
    }

    return self.load(operand, field_ty, offset);
}

fn airSwitchBr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    // result type is always 'noreturn'
    const blocktype = wasm.block_empty;
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const target = try self.resolveInst(pl_op.operand);
    const target_ty = self.air.typeOf(pl_op.operand);
    const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;

    // a list that maps each value with its value and body based on the order inside the list.
    const CaseValue = struct { integer: i32, value: Value };
    var case_list = try std.ArrayList(struct {
        values: []const CaseValue,
        body: []const Air.Inst.Index,
    }).initCapacity(self.gpa, switch_br.data.cases_len);
    defer for (case_list.items) |case| {
        self.gpa.free(case.values);
    } else case_list.deinit();

    var lowest_maybe: ?i32 = null;
    var highest_maybe: ?i32 = null;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;
        const values = try self.gpa.alloc(CaseValue, items.len);
        errdefer self.gpa.free(values);

        for (items) |ref, i| {
            const item_val = self.air.value(ref).?;
            const int_val = self.valueAsI32(item_val, target_ty);
            if (lowest_maybe == null or int_val < lowest_maybe.?) {
                lowest_maybe = int_val;
            }
            if (highest_maybe == null or int_val > highest_maybe.?) {
                highest_maybe = int_val;
            }
            values[i] = .{ .integer = int_val, .value = item_val };
        }

        case_list.appendAssumeCapacity(.{ .values = values, .body = case_body });
        try self.startBlock(.block, blocktype);
    }

    // When highest and lowest are null, we have no cases and can use a jump table
    const lowest = lowest_maybe orelse 0;
    const highest = highest_maybe orelse 0;
    // When the highest and lowest values are seperated by '50',
    // we define it as sparse and use an if/else-chain, rather than a jump table.
    // When the target is an integer size larger than u32, we have no way to use the value
    // as an index, therefore we also use an if/else-chain for those cases.
    // TODO: Benchmark this to find a proper value, LLVM seems to draw the line at '40~45'.
    const is_sparse = highest - lowest > 50 or target_ty.bitSize(self.target) > 32;

    const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];
    const has_else_body = else_body.len != 0;
    if (has_else_body) {
        try self.startBlock(.block, blocktype);
    }

    if (!is_sparse) {
        // Generate the jump table 'br_table' when the prongs are not sparse.
        // The value 'target' represents the index into the table.
        // Each index in the table represents a label to the branch
        // to jump to.
        try self.startBlock(.block, blocktype);
        try self.emitWValue(target);
        if (lowest < 0) {
            // since br_table works using indexes, starting from '0', we must ensure all values
            // we put inside, are atleast 0.
            try self.addImm32(lowest * -1);
            try self.addTag(.i32_add);
        } else if (lowest > 0) {
            // make the index start from 0 by substracting the lowest value
            try self.addImm32(lowest);
            try self.addTag(.i32_sub);
        }

        // Account for default branch so always add '1'
        const depth = @intCast(u32, highest - lowest + @boolToInt(has_else_body)) + 1;
        const jump_table: Mir.JumpTable = .{ .length = depth };
        const table_extra_index = try self.addExtra(jump_table);
        try self.addInst(.{ .tag = .br_table, .data = .{ .payload = table_extra_index } });
        try self.mir_extra.ensureUnusedCapacity(self.gpa, depth);
        var value = lowest;
        while (value <= highest) : (value += 1) {
            // idx represents the branch we jump to
            const idx = blk: {
                for (case_list.items) |case, idx| {
                    for (case.values) |case_value| {
                        if (case_value.integer == value) break :blk @intCast(u32, idx);
                    }
                }
                // error sets are almost always sparse so we use the default case
                // for errors that are not present in any branch. This is fine as this default
                // case will never be hit for those cases but we do save runtime cost and size
                // by using a jump table for this instead of if-else chains.
                break :blk if (has_else_body or target_ty.zigTypeTag() == .ErrorSet) case_i else unreachable;
            };
            self.mir_extra.appendAssumeCapacity(idx);
        } else if (has_else_body) {
            self.mir_extra.appendAssumeCapacity(case_i); // default branch
        }
        try self.endBlock();
    }

    const signedness: std.builtin.Signedness = blk: {
        // by default we tell the operand type is unsigned (i.e. bools and enum values)
        if (target_ty.zigTypeTag() != .Int) break :blk .unsigned;

        // incase of an actual integer, we emit the correct signedness
        break :blk target_ty.intInfo(self.target).signedness;
    };

    for (case_list.items) |case| {
        // when sparse, we use if/else-chain, so emit conditional checks
        if (is_sparse) {
            // for single value prong we can emit a simple if
            if (case.values.len == 1) {
                try self.emitWValue(target);
                const val = try self.lowerConstant(case.values[0].value, target_ty);
                try self.emitWValue(val);
                const opcode = buildOpcode(.{
                    .valtype1 = typeToValtype(target_ty, self.target),
                    .op = .ne, // not equal, because we want to jump out of this block if it does not match the condition.
                    .signedness = signedness,
                });
                try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));
                try self.addLabel(.br_if, 0);
            } else {
                // in multi-value prongs we must check if any prongs match the target value.
                try self.startBlock(.block, blocktype);
                for (case.values) |value| {
                    try self.emitWValue(target);
                    const val = try self.lowerConstant(value.value, target_ty);
                    try self.emitWValue(val);
                    const opcode = buildOpcode(.{
                        .valtype1 = typeToValtype(target_ty, self.target),
                        .op = .eq,
                        .signedness = signedness,
                    });
                    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));
                    try self.addLabel(.br_if, 0);
                }
                // value did not match any of the prong values
                try self.addLabel(.br, 1);
                try self.endBlock();
            }
        }
        try self.genBody(case.body);
        try self.endBlock();
    }

    if (has_else_body) {
        try self.genBody(else_body);
        try self.endBlock();
    }
    return .none;
}

fn airIsErr(self: *Self, inst: Air.Inst.Index, opcode: wasm.Opcode) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const err_ty = self.air.typeOf(un_op);
    const pl_ty = err_ty.errorUnionPayload();

    // load the error tag value
    try self.emitWValue(operand);
    if (pl_ty.hasRuntimeBitsIgnoreComptime()) {
        try self.addMemArg(.i32_load16_u, .{
            .offset = operand.offset(),
            .alignment = err_ty.errorUnionSet().abiAlignment(self.target),
        });
    }

    // Compare the error value with '0'
    try self.addImm32(0);
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const is_err_tmp = try self.allocLocal(Type.initTag(.i32)); // result is always an i32
    try self.addLabel(.local_set, is_err_tmp.local);
    return is_err_tmp;
}

fn airUnwrapErrUnionPayload(self: *Self, inst: Air.Inst.Index, op_is_ptr: bool) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOf(ty_op.operand);
    const err_ty = if (op_is_ptr) op_ty.childType() else op_ty;
    const payload_ty = err_ty.errorUnionPayload();
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) return WValue{ .none = {} };
    const err_align = err_ty.abiAlignment(self.target);
    const set_size = err_ty.errorUnionSet().abiSize(self.target);
    const offset = mem.alignForwardGeneric(u64, set_size, err_align);
    if (op_is_ptr or isByRef(payload_ty, self.target)) {
        return self.buildPointerOffset(operand, offset, .new);
    }
    return self.load(operand, payload_ty, @intCast(u32, offset));
}

fn airUnwrapErrUnionError(self: *Self, inst: Air.Inst.Index, op_is_ptr: bool) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOf(ty_op.operand);
    const err_ty = if (op_is_ptr) op_ty.childType() else op_ty;
    const payload_ty = err_ty.errorUnionPayload();
    if (op_is_ptr or !payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return operand;
    }

    return self.load(operand, err_ty.errorUnionSet(), 0);
}

fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);

    const op_ty = self.air.typeOf(ty_op.operand);
    if (!op_ty.hasRuntimeBitsIgnoreComptime()) return operand;
    const err_union_ty = self.air.getRefType(ty_op.ty);
    const err_align = err_union_ty.abiAlignment(self.target);
    const set_size = err_union_ty.errorUnionSet().abiSize(self.target);
    const offset = mem.alignForwardGeneric(u64, set_size, err_align);

    const err_union = try self.allocStack(err_union_ty);
    const payload_ptr = try self.buildPointerOffset(err_union, offset, .new);
    try self.store(payload_ptr, operand, op_ty, 0);

    // ensure we also write '0' to the error part, so any present stack value gets overwritten by it.
    try self.emitWValue(err_union);
    try self.addImm32(0);
    try self.addMemArg(.i32_store16, .{ .offset = err_union.offset(), .alignment = 2 });

    return err_union;
}

fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const err_ty = self.air.getRefType(ty_op.ty);

    if (!err_ty.errorUnionPayload().hasRuntimeBitsIgnoreComptime()) return operand;

    const err_union = try self.allocStack(err_ty);
    try self.store(err_union, operand, err_ty.errorUnionSet(), 0);

    // write 'undefined' to the payload
    const err_align = err_ty.abiAlignment(self.target);
    const set_size = err_ty.errorUnionSet().abiSize(self.target);
    const offset = mem.alignForwardGeneric(u64, set_size, err_align);
    const payload_ptr = try self.buildPointerOffset(err_union, offset, .new);
    const len = @intCast(u32, err_ty.errorUnionPayload().abiSize(self.target));
    try self.memset(payload_ptr, .{ .imm32 = len }, .{ .imm32 = 0xaaaaaaaa });

    return err_union;
}

fn airIntcast(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const ty = self.air.getRefType(ty_op.ty);
    const operand = try self.resolveInst(ty_op.operand);
    const ref_ty = self.air.typeOf(ty_op.operand);
    const ref_info = ref_ty.intInfo(self.target);
    const wanted_info = ty.intInfo(self.target);

    const op_bits = toWasmBits(ref_info.bits) orelse
        return self.fail("TODO: Wasm intcast integer types of bitsize: {d}", .{ref_info.bits});
    const wanted_bits = toWasmBits(wanted_info.bits) orelse
        return self.fail("TODO: Wasm intcast integer types of bitsize: {d}", .{wanted_info.bits});

    // hot path
    if (op_bits == wanted_bits) return operand;

    if (op_bits > 32 and wanted_bits == 32) {
        try self.emitWValue(operand);
        try self.addTag(.i32_wrap_i64);
    } else if (op_bits == 32 and wanted_bits > 32) {
        try self.emitWValue(operand);
        try self.addTag(switch (ref_info.signedness) {
            .signed => .i64_extend_i32_s,
            .unsigned => .i64_extend_i32_u,
        });
    } else unreachable;

    const result = try self.allocLocal(ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airIsNull(self: *Self, inst: Air.Inst.Index, opcode: wasm.Opcode, op_kind: enum { value, ptr }) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);

    const op_ty = self.air.typeOf(un_op);
    const optional_ty = if (op_kind == .ptr) op_ty.childType() else op_ty;
    return self.isNull(operand, optional_ty, opcode);
}

fn isNull(self: *Self, operand: WValue, optional_ty: Type, opcode: wasm.Opcode) InnerError!WValue {
    try self.emitWValue(operand);
    if (!optional_ty.isPtrLikeOptional()) {
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = optional_ty.optionalChild(&buf);
        // When payload is zero-bits, we can treat operand as a value, rather than
        // a pointer to the stack value
        if (payload_ty.hasRuntimeBitsIgnoreComptime()) {
            try self.addMemArg(.i32_load8_u, .{ .offset = operand.offset(), .alignment = 1 });
        }
    }

    // Compare the null value with '0'
    try self.addImm32(0);
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const is_null_tmp = try self.allocLocal(Type.initTag(.i32));
    try self.addLabel(.local_set, is_null_tmp.local);
    return is_null_tmp;
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const opt_ty = self.air.typeOf(ty_op.operand);
    const payload_ty = self.air.typeOfIndex(inst);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) return WValue{ .none = {} };
    if (opt_ty.isPtrLikeOptional()) return operand;

    const offset = opt_ty.abiSize(self.target) - payload_ty.abiSize(self.target);

    if (isByRef(payload_ty, self.target)) {
        return self.buildPointerOffset(operand, offset, .new);
    }

    return self.load(operand, payload_ty, @intCast(u32, offset));
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const opt_ty = self.air.typeOf(ty_op.operand).childType();

    var buf: Type.Payload.ElemType = undefined;
    const payload_ty = opt_ty.optionalChild(&buf);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime() or opt_ty.isPtrLikeOptional()) {
        return operand;
    }

    const offset = opt_ty.abiSize(self.target) - payload_ty.abiSize(self.target);
    return self.buildPointerOffset(operand, offset, .new);
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const opt_ty = self.air.typeOf(ty_op.operand).childType();
    var buf: Type.Payload.ElemType = undefined;
    const payload_ty = opt_ty.optionalChild(&buf);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return self.fail("TODO: Implement OptionalPayloadPtrSet for optional with zero-sized type {}", .{payload_ty.fmtDebug()});
    }

    if (opt_ty.isPtrLikeOptional()) {
        return operand;
    }

    const offset = std.math.cast(u32, opt_ty.abiSize(self.target) - payload_ty.abiSize(self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Optional type {} too big to fit into stack frame", .{opt_ty.fmt(module)});
    };

    try self.emitWValue(operand);
    try self.addImm32(1);
    try self.addMemArg(.i32_store8, .{ .offset = operand.offset(), .alignment = 1 });

    return self.buildPointerOffset(operand, offset, .new);
}

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const payload_ty = self.air.typeOf(ty_op.operand);
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        const non_null_bit = try self.allocStack(Type.initTag(.u1));
        try self.emitWValue(non_null_bit);
        try self.addImm32(1);
        try self.addMemArg(.i32_store8, .{ .offset = non_null_bit.offset(), .alignment = 1 });
        return non_null_bit;
    }

    const operand = try self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOfIndex(inst);
    if (op_ty.isPtrLikeOptional()) {
        return operand;
    }
    const offset = std.math.cast(u32, op_ty.abiSize(self.target) - payload_ty.abiSize(self.target)) catch {
        const module = self.bin_file.base.options.module.?;
        return self.fail("Optional type {} too big to fit into stack frame", .{op_ty.fmt(module)});
    };

    // Create optional type, set the non-null bit, and store the operand inside the optional type
    const result = try self.allocStack(op_ty);
    try self.emitWValue(result);
    try self.addImm32(1);
    try self.addMemArg(.i32_store8, .{ .offset = result.offset(), .alignment = 1 });

    const payload_ptr = try self.buildPointerOffset(result, offset, .new);
    try self.store(payload_ptr, operand, payload_ty, 0);

    return result;
}

fn airSlice(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const slice_ty = self.air.typeOfIndex(inst);

    const slice = try self.allocStack(slice_ty);
    try self.store(slice, lhs, Type.usize, 0);
    try self.store(slice, rhs, Type.usize, self.ptrSize());

    return slice;
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);

    return self.load(operand, Type.usize, self.ptrSize());
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const slice_ty = self.air.typeOf(bin_op.lhs);
    const slice = try self.resolveInst(bin_op.lhs);
    const index = try self.resolveInst(bin_op.rhs);
    const elem_ty = slice_ty.childType();
    const elem_size = elem_ty.abiSize(self.target);

    // load pointer onto stack
    const slice_ptr = try self.load(slice, Type.usize, 0);
    try self.addLabel(.local_get, slice_ptr.local);

    // calculate index into slice
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(elem_ty);
    try self.addLabel(.local_set, result.local);

    if (isByRef(elem_ty, self.target)) {
        return result;
    }
    return self.load(result, elem_ty, 0);
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const elem_ty = self.air.getRefType(ty_pl.ty).childType();
    const elem_size = elem_ty.abiSize(self.target);

    const slice = try self.resolveInst(bin_op.lhs);
    const index = try self.resolveInst(bin_op.rhs);

    const slice_ptr = try self.load(slice, Type.usize, 0);
    try self.addLabel(.local_get, slice_ptr.local);

    // calculate index into slice
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(Type.initTag(.i32));
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    return self.load(operand, Type.usize, 0);
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOf(ty_op.operand);
    const int_info = self.air.getRefType(ty_op.ty).intInfo(self.target);
    const wanted_bits = int_info.bits;
    const result = try self.allocLocal(self.air.getRefType(ty_op.ty));
    const op_bits = op_ty.intInfo(self.target).bits;

    const wasm_bits = toWasmBits(wanted_bits) orelse
        return self.fail("TODO: Implement wasm integer truncation for integer bitsize: {d}", .{wanted_bits});

    // Use wasm's instruction to wrap from 64bit to 32bit integer when possible
    if (op_bits == 64 and wanted_bits == 32) {
        try self.emitWValue(operand);
        try self.addTag(.i32_wrap_i64);
        try self.addLabel(.local_set, result.local);
        return result;
    }

    // Any other truncation must be done manually
    if (int_info.signedness == .unsigned) {
        const mask = (@as(u65, 1) << @intCast(u7, wanted_bits)) - 1;
        try self.emitWValue(operand);
        switch (wasm_bits) {
            32 => {
                try self.addImm32(@bitCast(i32, @intCast(u32, mask)));
                try self.addTag(.i32_and);
            },
            64 => {
                try self.addImm64(@intCast(u64, mask));
                try self.addTag(.i64_and);
            },
            else => unreachable,
        }
    } else {
        const shift_bits = wasm_bits - wanted_bits;
        try self.emitWValue(operand);
        switch (wasm_bits) {
            32 => {
                try self.addImm32(@bitCast(i16, shift_bits));
                try self.addTag(.i32_shl);
                try self.addImm32(@bitCast(i16, shift_bits));
                try self.addTag(.i32_shr_s);
            },
            64 => {
                try self.addImm64(shift_bits);
                try self.addTag(.i64_shl);
                try self.addImm64(shift_bits);
                try self.addTag(.i64_shr_s);
            },
            else => unreachable,
        }
    }

    try self.addLabel(.local_set, result.local);
    return result;
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    return self.resolveInst(un_op);
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const array_ty = self.air.typeOf(ty_op.operand).childType();
    const slice_ty = self.air.getRefType(ty_op.ty);

    // create a slice on the stack
    const slice_local = try self.allocStack(slice_ty);

    // store the array ptr in the slice
    if (array_ty.hasRuntimeBitsIgnoreComptime()) {
        try self.store(slice_local, operand, Type.usize, 0);
    }

    // store the length of the array in the slice
    const len = WValue{ .imm32 = @intCast(u32, array_ty.arrayLen()) };
    try self.store(slice_local, len, Type.usize, self.ptrSize());

    return slice_local;
}

fn airPtrToInt(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);

    switch (operand) {
        // for stack offset, return a pointer to this offset.
        .stack_offset => return self.buildPointerOffset(operand, 0, .new),
        else => return operand,
    }
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const ptr = try self.resolveInst(bin_op.lhs);
    const index = try self.resolveInst(bin_op.rhs);
    const elem_ty = ptr_ty.childType();
    const elem_size = elem_ty.abiSize(self.target);

    // load pointer onto the stack
    if (ptr_ty.isSlice()) {
        const ptr_local = try self.load(ptr, Type.usize, 0);
        try self.addLabel(.local_get, ptr_local.local);
    } else {
        const pointer = switch (ptr) {
            .stack_offset => try self.buildPointerOffset(ptr, 0, .new),
            else => ptr,
        };
        try self.emitWValue(pointer);
    }

    // calculate index into slice
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(elem_ty);
    try self.addLabel(.local_set, result.local);
    if (isByRef(elem_ty, self.target)) {
        return result;
    }
    return self.load(result, elem_ty, 0);
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const elem_ty = self.air.getRefType(ty_pl.ty).childType();
    const elem_size = elem_ty.abiSize(self.target);

    const ptr = try self.resolveInst(bin_op.lhs);
    const index = try self.resolveInst(bin_op.rhs);

    // load pointer onto the stack
    if (ptr_ty.isSlice()) {
        const ptr_local = try self.load(ptr, Type.usize, 0);
        try self.addLabel(.local_get, ptr_local.local);
    } else {
        const pointer = switch (ptr) {
            .stack_offset => try self.buildPointerOffset(ptr, 0, .new),
            else => ptr,
        };
        try self.emitWValue(pointer);
    }

    // calculate index into ptr
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(Type.initTag(.i32));
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airPtrBinOp(self: *Self, inst: Air.Inst.Index, op: Op) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const offset = try self.resolveInst(bin_op.rhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const pointee_ty = switch (ptr_ty.ptrSize()) {
        .One => ptr_ty.childType().childType(), // ptr to array, so get array element type
        else => ptr_ty.childType(),
    };

    const valtype = typeToValtype(Type.usize, self.target);
    const mul_opcode = buildOpcode(.{ .valtype1 = valtype, .op = .mul });
    const bin_opcode = buildOpcode(.{ .valtype1 = valtype, .op = op });

    const pointer = switch (ptr) {
        .stack_offset => try self.buildPointerOffset(ptr, 0, .new),
        else => ptr,
    };
    try self.emitWValue(pointer);
    try self.emitWValue(offset);
    try self.addImm32(@bitCast(i32, @intCast(u32, pointee_ty.abiSize(self.target))));
    try self.addTag(Mir.Inst.Tag.fromOpcode(mul_opcode));
    try self.addTag(Mir.Inst.Tag.fromOpcode(bin_opcode));

    const result = try self.allocLocal(Type.usize);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airMemset(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const bin_op = self.air.extraData(Air.Bin, pl_op.payload).data;

    const ptr = try self.resolveInst(pl_op.operand);
    const value = try self.resolveInst(bin_op.lhs);
    const len = try self.resolveInst(bin_op.rhs);
    try self.memset(ptr, len, value);

    return WValue{ .none = {} };
}

/// Sets a region of memory at `ptr` to the value of `value`
/// When the user has enabled the bulk_memory feature, we lower
/// this to wasm's memset instruction. When the feature is not present,
/// we implement it manually.
fn memset(self: *Self, ptr: WValue, len: WValue, value: WValue) InnerError!void {
    // When bulk_memory is enabled, we lower it to wasm's memset instruction.
    // If not, we lower it ourselves
    if (std.Target.wasm.featureSetHas(self.target.cpu.features, .bulk_memory)) {
        switch (ptr) {
            .stack_offset => try self.emitWValue(try self.buildPointerOffset(ptr, 0, .new)),
            else => try self.emitWValue(ptr),
        }
        try self.emitWValue(value);
        try self.emitWValue(len);
        try self.addExtended(.memory_fill);
        return;
    }

    // When the length is comptime-known we do the loop at codegen, rather
    // than emitting a runtime loop into the binary
    switch (len) {
        .imm32, .imm64 => {
            const length = switch (len) {
                .imm32 => |val| val,
                .imm64 => |val| val,
                else => unreachable,
            };

            var offset: u32 = 0;
            const base = ptr.offset();
            while (offset < length) : (offset += 1) {
                try self.emitWValue(ptr);
                try self.emitWValue(value);
                switch (self.arch()) {
                    .wasm32 => {
                        try self.addMemArg(.i32_store8, .{ .offset = base + offset, .alignment = 1 });
                    },
                    .wasm64 => {
                        try self.addMemArg(.i64_store8, .{ .offset = base + offset, .alignment = 1 });
                    },
                    else => unreachable,
                }
            }
        },
        else => {
            // TODO: We should probably lower this to a call to compiler_rt
            // But for now, we implement it manually
            const offset = try self.allocLocal(Type.usize); // local for counter
            // outer block to jump to when loop is done
            try self.startBlock(.block, wasm.block_empty);
            try self.startBlock(.loop, wasm.block_empty);
            try self.emitWValue(offset);
            try self.emitWValue(len);
            switch (self.arch()) {
                .wasm32 => try self.addTag(.i32_eq),
                .wasm64 => try self.addTag(.i64_eq),
                else => unreachable,
            }
            try self.addLabel(.br_if, 1); // jump out of loop into outer block (finished)
            try self.emitWValue(ptr);
            try self.emitWValue(offset);
            switch (self.arch()) {
                .wasm32 => try self.addTag(.i32_add),
                .wasm64 => try self.addTag(.i64_add),
                else => unreachable,
            }
            try self.emitWValue(value);
            const mem_store_op: Mir.Inst.Tag = switch (self.arch()) {
                .wasm32 => .i32_store8,
                .wasm64 => .i64_store8,
                else => unreachable,
            };
            try self.addMemArg(mem_store_op, .{ .offset = ptr.offset(), .alignment = 1 });
            try self.emitWValue(offset);
            try self.addImm32(1);
            switch (self.arch()) {
                .wasm32 => try self.addTag(.i32_add),
                .wasm64 => try self.addTag(.i64_add),
                else => unreachable,
            }
            try self.addLabel(.local_set, offset.local);
            try self.addLabel(.br, 0); // jump to start of loop
            try self.endBlock();
            try self.endBlock();
        },
    }
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const array_ty = self.air.typeOf(bin_op.lhs);
    const array = try self.resolveInst(bin_op.lhs);
    const index = try self.resolveInst(bin_op.rhs);
    const elem_ty = array_ty.childType();
    const elem_size = elem_ty.abiSize(self.target);

    const array_ptr = switch (array) {
        .stack_offset => try self.buildPointerOffset(array, 0, .new),
        else => array,
    };

    try self.emitWValue(array_ptr);
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(Type.usize);
    try self.addLabel(.local_set, result.local);

    if (isByRef(elem_ty, self.target)) {
        return result;
    }
    return self.load(result, elem_ty, 0);
}

fn airFloatToInt(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const dest_ty = self.air.typeOfIndex(inst);
    const op_ty = self.air.typeOf(ty_op.operand);

    try self.emitWValue(operand);
    const op = buildOpcode(.{
        .op = .trunc,
        .valtype1 = typeToValtype(dest_ty, self.target),
        .valtype2 = typeToValtype(op_ty, self.target),
        .signedness = if (dest_ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(op));

    const result = try self.allocLocal(dest_ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airIntToFloat(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const dest_ty = self.air.typeOfIndex(inst);
    const op_ty = self.air.typeOf(ty_op.operand);

    try self.emitWValue(operand);
    const op = buildOpcode(.{
        .op = .convert,
        .valtype1 = typeToValtype(dest_ty, self.target),
        .valtype2 = typeToValtype(op_ty, self.target),
        .signedness = if (op_ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(op));

    const result = try self.allocLocal(dest_ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airSplat(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);

    _ = operand;
    return self.fail("TODO: Implement wasm airSplat", .{});
}

fn airSelect(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const operand = try self.resolveInst(pl_op.operand);

    _ = operand;
    return self.fail("TODO: Implement wasm airSelect", .{});
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);

    _ = operand;
    return self.fail("TODO: Implement wasm airShuffle", .{});
}

fn airReduce(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const reduce = self.air.instructions.items(.data)[inst].reduce;
    const operand = try self.resolveInst(reduce.operand);

    _ = operand;
    return self.fail("TODO: Implement wasm airReduce", .{});
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const result_ty = self.air.typeOfIndex(inst);
    const len = @intCast(usize, result_ty.arrayLen());
    const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);

    switch (result_ty.zigTypeTag()) {
        .Vector => return self.fail("TODO: Wasm backend: implement airAggregateInit for vectors", .{}),
        .Array => {
            const result = try self.allocStack(result_ty);
            const elem_ty = result_ty.childType();
            const elem_size = @intCast(u32, elem_ty.abiSize(self.target));

            // When the element type is by reference, we must copy the entire
            // value. It is therefore safer to move the offset pointer and store
            // each value individually, instead of using store offsets.
            if (isByRef(elem_ty, self.target)) {
                // copy stack pointer into a temporary local, which is
                // moved for each element to store each value in the right position.
                const offset = try self.buildPointerOffset(result, 0, .new);
                for (elements) |elem, elem_index| {
                    const elem_val = try self.resolveInst(elem);
                    try self.store(offset, elem_val, elem_ty, 0);

                    if (elem_index < elements.len - 1) {
                        _ = try self.buildPointerOffset(offset, elem_size, .modify);
                    }
                }
            } else {
                var offset: u32 = 0;
                for (elements) |elem| {
                    const elem_val = try self.resolveInst(elem);
                    try self.store(result, elem_val, elem_ty, offset);
                    offset += elem_size;
                }
            }
            return result;
        },
        .Struct => {
            const result = try self.allocStack(result_ty);
            const offset = try self.buildPointerOffset(result, 0, .new); // pointer to offset
            for (elements) |elem, elem_index| {
                if (result_ty.structFieldValueComptime(elem_index) != null) continue;

                const elem_ty = result_ty.structFieldType(elem_index);
                const elem_size = @intCast(u32, elem_ty.abiSize(self.target));
                const value = try self.resolveInst(elem);
                try self.store(offset, value, elem_ty, 0);

                if (elem_index < elements.len - 1) {
                    _ = try self.buildPointerOffset(offset, elem_size, .modify);
                }
            }

            return result;
        },
        else => unreachable,
    }
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    const union_ty = self.air.typeOfIndex(inst);
    const layout = union_ty.unionGetLayout(self.target);
    if (layout.payload_size == 0) {
        if (layout.tag_size == 0) {
            return WValue{ .none = {} };
        }
        assert(!isByRef(union_ty, self.target));
        return WValue{ .imm32 = extra.field_index };
    }
    assert(isByRef(union_ty, self.target));

    const result_ptr = try self.allocStack(union_ty);
    const payload = try self.resolveInst(extra.init);
    const union_obj = union_ty.cast(Type.Payload.Union).?.data;
    assert(union_obj.haveFieldTypes());
    const field = union_obj.fields.values()[extra.field_index];

    if (layout.tag_align >= layout.payload_align) {
        const payload_ptr = try self.buildPointerOffset(result_ptr, layout.tag_size, .new);
        try self.store(payload_ptr, payload, field.ty, 0);
    } else {
        try self.store(result_ptr, payload, field.ty, 0);
    }

    return result_ptr;
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    _ = prefetch;
    return WValue{ .none = {} };
}

fn airWasmMemorySize(self: *Self, inst: Air.Inst.Index) !WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const pl_op = self.air.instructions.items(.data)[inst].pl_op;

    const result = try self.allocLocal(self.air.typeOfIndex(inst));
    try self.addLabel(.memory_size, pl_op.payload);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airWasmMemoryGrow(self: *Self, inst: Air.Inst.Index) !WValue {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const operand = try self.resolveInst(pl_op.operand);

    const result = try self.allocLocal(self.air.typeOfIndex(inst));
    try self.emitWValue(operand);
    try self.addLabel(.memory_grow, pl_op.payload);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn cmpOptionals(self: *Self, lhs: WValue, rhs: WValue, operand_ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    assert(operand_ty.hasRuntimeBitsIgnoreComptime());
    assert(op == .eq or op == .neq);
    var buf: Type.Payload.ElemType = undefined;
    const payload_ty = operand_ty.optionalChild(&buf);
    const offset = @intCast(u32, operand_ty.abiSize(self.target) - payload_ty.abiSize(self.target));

    const lhs_is_null = try self.isNull(lhs, operand_ty, .i32_eq);
    const rhs_is_null = try self.isNull(rhs, operand_ty, .i32_eq);

    // We store the final result in here that will be validated
    // if the optional is truly equal.
    const result = try self.allocLocal(Type.initTag(.i32));

    try self.startBlock(.block, wasm.block_empty);
    try self.emitWValue(lhs_is_null);
    try self.emitWValue(rhs_is_null);
    try self.addTag(.i32_ne); // inverse so we can exit early
    try self.addLabel(.br_if, 0);

    const lhs_pl = try self.load(lhs, payload_ty, offset);
    const rhs_pl = try self.load(rhs, payload_ty, offset);

    try self.emitWValue(lhs_pl);
    try self.emitWValue(rhs_pl);
    const opcode = buildOpcode(.{ .op = .ne, .valtype1 = typeToValtype(payload_ty, self.target) });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));
    try self.addLabel(.br_if, 0);

    try self.addImm32(1);
    try self.addLabel(.local_set, result.local);
    try self.endBlock();

    try self.emitWValue(result);
    try self.addImm32(0);
    try self.addTag(if (op == .eq) .i32_ne else .i32_eq);
    try self.addLabel(.local_set, result.local);
    return result;
}

/// Compares big integers by checking both its high bits and low bits.
/// TODO: Lower this to compiler_rt call
fn cmpBigInt(self: *Self, lhs: WValue, rhs: WValue, operand_ty: Type, op: std.math.CompareOperator) InnerError!WValue {
    if (operand_ty.intInfo(self.target).bits > 128) {
        return self.fail("TODO: Support cmpBigInt for integer bitsize: '{d}'", .{operand_ty.intInfo(self.target).bits});
    }

    const result = try self.allocLocal(Type.initTag(.i32));
    {
        try self.startBlock(.block, wasm.block_empty);
        const lhs_high_bit = try self.load(lhs, Type.u64, 0);
        const lhs_low_bit = try self.load(lhs, Type.u64, 8);
        const rhs_high_bit = try self.load(rhs, Type.u64, 0);
        const rhs_low_bit = try self.load(rhs, Type.u64, 8);
        try self.emitWValue(lhs_high_bit);
        try self.emitWValue(rhs_high_bit);
        try self.addTag(.i64_ne);
        try self.addLabel(.br_if, 0);
        try self.emitWValue(lhs_low_bit);
        try self.emitWValue(rhs_low_bit);
        try self.addTag(.i64_ne);
        try self.addLabel(.br_if, 0);
        try self.addImm32(1);
        try self.addLabel(.local_set, result.local);
        try self.endBlock();
    }

    try self.emitWValue(result);
    try self.addImm32(0);
    try self.addTag(if (op == .eq) .i32_ne else .i32_eq);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const un_ty = self.air.typeOf(bin_op.lhs).childType();
    const tag_ty = self.air.typeOf(bin_op.rhs);
    const layout = un_ty.unionGetLayout(self.target);
    if (layout.tag_size == 0) return WValue{ .none = {} };
    const union_ptr = try self.resolveInst(bin_op.lhs);
    const new_tag = try self.resolveInst(bin_op.rhs);
    if (layout.payload_size == 0) {
        try self.store(union_ptr, new_tag, tag_ty, 0);
        return WValue{ .none = {} };
    }

    // when the tag alignment is smaller than the payload, the field will be stored
    // after the payload.
    const offset = if (layout.tag_align < layout.payload_align) blk: {
        break :blk @intCast(u32, layout.payload_size);
    } else @as(u32, 0);
    try self.store(union_ptr, new_tag, tag_ty, offset);
    return WValue{ .none = {} };
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const un_ty = self.air.typeOf(ty_op.operand);
    const tag_ty = self.air.typeOfIndex(inst);
    const layout = un_ty.unionGetLayout(self.target);
    if (layout.tag_size == 0) return WValue{ .none = {} };
    const operand = try self.resolveInst(ty_op.operand);

    // when the tag alignment is smaller than the payload, the field will be stored
    // after the payload.
    const offset = if (layout.tag_align < layout.payload_align) blk: {
        break :blk @intCast(u32, layout.payload_size);
    } else @as(u32, 0);
    return self.load(operand, tag_ty, offset);
}

fn airFpext(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dest_ty = self.air.typeOfIndex(inst);
    const dest_bits = dest_ty.floatBits(self.target);
    const src_bits = self.air.typeOf(ty_op.operand).floatBits(self.target);
    const operand = try self.resolveInst(ty_op.operand);

    if (dest_bits == 64 and src_bits == 32) {
        const result = try self.allocLocal(dest_ty);
        try self.emitWValue(operand);
        try self.addTag(.f64_promote_f32);
        try self.addLabel(.local_set, result.local);
        return result;
    } else {
        // TODO: Emit a call to compiler-rt to extend the float. e.g. __extendhfsf2
        return self.fail("TODO: Implement 'fpext' for floats with bitsize: {d}", .{dest_bits});
    }
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dest_ty = self.air.typeOfIndex(inst);
    const dest_bits = dest_ty.floatBits(self.target);
    const src_bits = self.air.typeOf(ty_op.operand).floatBits(self.target);
    const operand = try self.resolveInst(ty_op.operand);

    if (dest_bits == 32 and src_bits == 64) {
        const result = try self.allocLocal(dest_ty);
        try self.emitWValue(operand);
        try self.addTag(.f32_demote_f64);
        try self.addLabel(.local_set, result.local);
        return result;
    } else {
        // TODO: Emit a call to compiler-rt to trunc the float. e.g. __truncdfhf2
        return self.fail("TODO: Implement 'fptrunc' for floats with bitsize: {d}", .{dest_bits});
    }
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const err_set_ty = self.air.typeOf(ty_op.operand).childType();
    const err_ty = err_set_ty.errorUnionSet();
    const payload_ty = err_set_ty.errorUnionPayload();
    const operand = try self.resolveInst(ty_op.operand);

    // set error-tag to '0' to annotate error union is non-error
    try self.store(operand, .{ .imm32 = 0 }, err_ty, 0);

    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return operand;
    }

    const err_align = err_set_ty.abiAlignment(self.target);
    const set_size = err_ty.abiSize(self.target);
    const offset = mem.alignForwardGeneric(u64, set_size, err_align);

    return self.buildPointerOffset(operand, @intCast(u32, offset), .new);
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;
    const field_ptr = try self.resolveInst(extra.field_ptr);

    const struct_ty = self.air.getRefType(ty_pl.ty).childType();
    const field_offset = struct_ty.structFieldOffset(extra.field_index, self.target);

    if (field_offset == 0) {
        return field_ptr;
    }

    const base = try self.buildPointerOffset(field_ptr, 0, .new);
    try self.addLabel(.local_get, base.local);
    try self.addImm32(@bitCast(i32, @intCast(u32, field_offset)));
    try self.addTag(.i32_sub);
    try self.addLabel(.local_set, base.local);
    return base;
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const bin_op = self.air.extraData(Air.Bin, pl_op.payload).data;
    const dst = try self.resolveInst(pl_op.operand);
    const src = try self.resolveInst(bin_op.lhs);
    const len = try self.resolveInst(bin_op.rhs);
    try self.memcpy(dst, src, len);
    return WValue{ .none = {} };
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOf(ty_op.operand);

    if (op_ty.zigTypeTag() == .Vector) {
        return self.fail("TODO: Implement @popCount for vectors", .{});
    }

    const int_info = op_ty.intInfo(self.target);
    const bits = int_info.bits;
    const wasm_bits = toWasmBits(bits) orelse {
        return self.fail("TODO: Implement @popCount for integers with bitsize '{d}'", .{bits});
    };

    try self.emitWValue(operand);

    // for signed integers we first mask the signedness bit
    if (int_info.signedness == .signed and wasm_bits != bits) {
        switch (wasm_bits) {
            32 => {
                const mask = (@as(u32, 1) << @intCast(u5, bits)) - 1;
                try self.addImm32(@bitCast(i32, mask));
                try self.addTag(.i32_and);
            },
            64 => {
                const mask = (@as(u64, 1) << @intCast(u6, bits)) - 1;
                try self.addImm64(mask);
                try self.addTag(.i64_and);
            },
            else => unreachable,
        }
    }

    switch (wasm_bits) {
        32 => try self.addTag(.i32_popcnt),
        64 => try self.addTag(.i64_popcnt),
        else => unreachable,
    }

    const result = try self.allocLocal(op_ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);

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
    const error_table_symbol = try self.bin_file.getErrorTableSymbol();
    const name_ty = Type.initTag(.const_slice_u8_sentinel_0);
    const abi_size = name_ty.abiSize(self.target);

    const error_name_value: WValue = .{ .memory = error_table_symbol }; // emitting this will create a relocation
    try self.emitWValue(error_name_value);
    try self.emitWValue(operand);
    switch (self.arch()) {
        .wasm32 => {
            try self.addImm32(@bitCast(i32, @intCast(u32, abi_size)));
            try self.addTag(.i32_mul);
            try self.addTag(.i32_add);
        },
        .wasm64 => {
            try self.addImm64(abi_size);
            try self.addTag(.i64_mul);
            try self.addTag(.i64_add);
        },
        else => unreachable,
    }

    const result_ptr = try self.allocLocal(Type.usize);
    try self.addLabel(.local_set, result_ptr.local);
    return result_ptr;
}

fn airPtrSliceFieldPtr(self: *Self, inst: Air.Inst.Index, offset: u32) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const slice_ptr = try self.resolveInst(ty_op.operand);
    return self.buildPointerOffset(slice_ptr, offset, .new);
}

fn airBinOpOverflow(self: *Self, inst: Air.Inst.Index, op: Op) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(extra.lhs);
    const rhs = try self.resolveInst(extra.rhs);
    const lhs_ty = self.air.typeOf(extra.lhs);

    // We store the bit if it's overflowed or not in this. As it's zero-initialized
    // we only need to update it if an overflow (or underflow) occured.
    const overflow_bit = try self.allocLocal(Type.initTag(.u1));
    const int_info = lhs_ty.intInfo(self.target);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return self.fail("TODO: Implement overflow arithmetic for integer bitsize: {d}", .{int_info.bits});
    };

    const zero = switch (wasm_bits) {
        32 => WValue{ .imm32 = 0 },
        64 => WValue{ .imm64 = 0 },
        else => unreachable,
    };
    const int_max = (@as(u65, 1) << @intCast(u7, int_info.bits - @boolToInt(int_info.signedness == .signed))) - 1;
    const int_max_wvalue = switch (wasm_bits) {
        32 => WValue{ .imm32 = @intCast(u32, int_max) },
        64 => WValue{ .imm64 = @intCast(u64, int_max) },
        else => unreachable,
    };
    const int_min = if (int_info.signedness == .unsigned)
        @as(i64, 0)
    else
        -@as(i64, 1) << @intCast(u6, int_info.bits - 1);
    const int_min_wvalue = switch (wasm_bits) {
        32 => WValue{ .imm32 = @bitCast(u32, @intCast(i32, int_min)) },
        64 => WValue{ .imm64 = @bitCast(u64, int_min) },
        else => unreachable,
    };

    if (int_info.signedness == .unsigned and op == .add) {
        const diff = try self.binOp(int_max_wvalue, lhs, lhs_ty, .sub);
        const cmp_res = try self.cmp(rhs, diff, lhs_ty, .gt);
        try self.emitWValue(cmp_res);
        try self.addLabel(.local_set, overflow_bit.local);
    } else if (int_info.signedness == .unsigned and op == .sub) {
        const cmp_res = try self.cmp(lhs, rhs, lhs_ty, .lt);
        try self.emitWValue(cmp_res);
        try self.addLabel(.local_set, overflow_bit.local);
    } else if (int_info.signedness == .signed and op != .shl) {
        // for overflow, we first check if lhs is > 0 (or lhs < 0 in case of subtraction). If not, we will not overflow.
        // We first create an outer block, where we handle overflow.
        // Then we create an inner block, where underflow is handled.
        try self.startBlock(.block, wasm.block_empty);
        try self.startBlock(.block, wasm.block_empty);
        {
            try self.emitWValue(lhs);
            const cmp_result = try self.cmp(lhs, zero, lhs_ty, .lt);
            try self.emitWValue(cmp_result);
        }
        try self.addLabel(.br_if, 0); // break to outer block, and handle underflow

        // handle overflow
        {
            const diff = try self.binOp(int_max_wvalue, lhs, lhs_ty, .sub);
            const cmp_res = try self.cmp(rhs, diff, lhs_ty, if (op == .add) .gt else .lt);
            try self.emitWValue(cmp_res);
            try self.addLabel(.local_set, overflow_bit.local);
        }
        try self.addLabel(.br, 1); // break from blocks, and continue regular flow.
        try self.endBlock();

        // handle underflow
        {
            const diff = try self.binOp(int_min_wvalue, lhs, lhs_ty, .sub);
            const cmp_res = try self.cmp(rhs, diff, lhs_ty, if (op == .add) .lt else .gt);
            try self.emitWValue(cmp_res);
            try self.addLabel(.local_set, overflow_bit.local);
        }
        try self.endBlock();
    }

    const bin_op = if (op == .shl) blk: {
        const tmp_val = try self.binOp(lhs, rhs, lhs_ty, op);
        const cmp_res = try self.cmp(tmp_val, int_max_wvalue, lhs_ty, .gt);
        try self.emitWValue(cmp_res);
        try self.addLabel(.local_set, overflow_bit.local);

        try self.emitWValue(tmp_val);
        try self.emitWValue(int_max_wvalue);
        switch (wasm_bits) {
            32 => try self.addTag(.i32_and),
            64 => try self.addTag(.i64_and),
            else => unreachable,
        }
        try self.addLabel(.local_set, tmp_val.local);
        break :blk tmp_val;
    } else if (op == .mul) blk: {
        const bin_op = try self.wrapBinOp(lhs, rhs, lhs_ty, op);
        try self.startBlock(.block, wasm.block_empty);
        // check if 0. true => Break out of block as cannot over -or underflow.
        try self.emitWValue(lhs);
        switch (wasm_bits) {
            32 => try self.addTag(.i32_eqz),
            64 => try self.addTag(.i64_eqz),
            else => unreachable,
        }
        try self.addLabel(.br_if, 0);
        const div = try self.binOp(bin_op, lhs, lhs_ty, .div);
        const cmp_res = try self.cmp(div, rhs, lhs_ty, .neq);
        try self.emitWValue(cmp_res);
        try self.addLabel(.local_set, overflow_bit.local);
        try self.endBlock();
        break :blk bin_op;
    } else try self.wrapBinOp(lhs, rhs, lhs_ty, op);

    const result_ptr = try self.allocStack(self.air.typeOfIndex(inst));
    try self.store(result_ptr, bin_op, lhs_ty, 0);
    const offset = @intCast(u32, lhs_ty.abiSize(self.target));
    try self.store(result_ptr, overflow_bit, Type.initTag(.u1), offset);

    return result_ptr;
}

fn airMaxMin(self: *Self, inst: Air.Inst.Index, op: enum { max, min }) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ty = self.air.typeOfIndex(inst);
    if (ty.zigTypeTag() == .Vector) {
        return self.fail("TODO: `@maximum` and `@minimum` for vectors", .{});
    }

    if (ty.abiSize(self.target) > 8) {
        return self.fail("TODO: `@maximum` and `@minimum` for types larger than 8 bytes", .{});
    }

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);

    // operands to select from
    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    // operands to compare
    try self.emitWValue(lhs);
    try self.emitWValue(rhs);
    const opcode = buildOpcode(.{
        .op = if (op == .max) .gt else .lt,
        .signedness = if (ty.isSignedInt()) .signed else .unsigned,
        .valtype1 = typeToValtype(ty, self.target),
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    // based on the result from comparison, return operand 0 or 1.
    try self.addTag(.select);

    // store result in local
    const result = try self.allocLocal(ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const bin_op = self.air.extraData(Air.Bin, pl_op.payload).data;
    const ty = self.air.typeOfIndex(inst);
    if (ty.zigTypeTag() == .Vector) {
        return self.fail("TODO: `@mulAdd` for vectors", .{});
    }

    if (ty.floatBits(self.target) == 16) {
        return self.fail("TODO: `@mulAdd` for f16", .{});
    }

    const addend = try self.resolveInst(pl_op.operand);
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);

    const mul_result = try self.binOp(lhs, rhs, ty, .mul);
    return self.binOp(mul_result, addend, ty, .add);
}

fn airClz(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const ty = self.air.typeOf(ty_op.operand);
    const result_ty = self.air.typeOfIndex(inst);
    if (ty.zigTypeTag() == .Vector) {
        return self.fail("TODO: `@clz` for vectors", .{});
    }

    const operand = try self.resolveInst(ty_op.operand);
    const int_info = ty.intInfo(self.target);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return self.fail("TODO: `@clz` for integers with bitsize '{d}'", .{int_info.bits});
    };

    try self.emitWValue(operand);
    switch (wasm_bits) {
        32 => {
            try self.addTag(.i32_clz);

            if (wasm_bits != int_info.bits) {
                const tmp = try self.allocLocal(ty);
                try self.addLabel(.local_set, tmp.local);
                const val: i32 = -@intCast(i32, wasm_bits - int_info.bits);
                return self.wrapBinOp(tmp, .{ .imm32 = @bitCast(u32, val) }, ty, .add);
            }
        },
        64 => {
            try self.addTag(.i64_clz);

            if (wasm_bits != int_info.bits) {
                const tmp = try self.allocLocal(ty);
                try self.addLabel(.local_set, tmp.local);
                const val: i64 = -@intCast(i64, wasm_bits - int_info.bits);
                return self.wrapBinOp(tmp, .{ .imm64 = @bitCast(u64, val) }, ty, .add);
            }
        },
        else => unreachable,
    }

    const result = try self.allocLocal(result_ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airCtz(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue{ .none = {} };
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const ty = self.air.typeOf(ty_op.operand);
    const result_ty = self.air.typeOfIndex(inst);

    if (ty.zigTypeTag() == .Vector) {
        return self.fail("TODO: `@ctz` for vectors", .{});
    }

    const operand = try self.resolveInst(ty_op.operand);
    const int_info = ty.intInfo(self.target);
    const wasm_bits = toWasmBits(int_info.bits) orelse {
        return self.fail("TODO: `@clz` for integers with bitsize '{d}'", .{int_info.bits});
    };

    switch (wasm_bits) {
        32 => {
            if (wasm_bits != int_info.bits) {
                const val: u32 = @as(u32, 1) << @intCast(u5, int_info.bits);
                const bin_op = try self.binOp(operand, .{ .imm32 = val }, ty, .@"or");
                try self.emitWValue(bin_op);
            } else try self.emitWValue(operand);
            try self.addTag(.i32_ctz);
        },
        64 => {
            if (wasm_bits != int_info.bits) {
                const val: u64 = @as(u64, 1) << @intCast(u6, int_info.bits);
                const bin_op = try self.binOp(operand, .{ .imm64 = val }, ty, .@"or");
                try self.emitWValue(bin_op);
            } else try self.emitWValue(operand);
            try self.addTag(.i64_ctz);
        },
        else => unreachable,
    }

    const result = try self.allocLocal(result_ty);
    try self.addLabel(.local_set, result.local);
    return result;
}
