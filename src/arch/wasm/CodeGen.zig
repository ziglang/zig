const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const testing = std.testing;
const leb = std.leb;
const mem = std.mem;
const wasm = std.wasm;
const log = std.log.scoped(.codegen);

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
    /// Holds a memoized typed value
    constant: TypedValue,
    /// Used for types that contains of multiple areas within
    /// a memory region in the stack.
    /// The local represents the position in the stack,
    /// whereas the offset represents the offset from that position.
    local_with_offset: struct {
        /// Index of the local variable
        local: u32,
        /// The offset from the local's stack position
        offset: u32,
    },
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
                .f32, .f64 => unreachable,
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
                    .f32, .f64 => unreachable,
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
pub const ValueTable = std.AutoHashMapUnmanaged(Air.Inst.Index, WValue);

const Self = @This();

/// Reference to the function declaration the code
/// section belongs to
decl: *Decl,
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
code: ArrayList(u8),
/// The index the next local generated will have
/// NOTE: arguments share the index with locals therefore the first variable
/// will have the index that comes after the last argument's index
local_index: u32 = 0,
/// The index of the current argument.
/// Used to track which argument is being referenced in `airArg`.
arg_index: u32 = 0,
/// If codegen fails, an error messages will be allocated and saved in `err_msg`
err_msg: *Module.ErrorMsg,
/// Current block depth. Used to calculate the relative difference between a break
/// and block
block_depth: u32 = 0,
/// List of all locals' types generated throughout this declaration
/// used to emit locals count at start of 'code' section.
locals: std.ArrayListUnmanaged(u8),
/// The Target we're emitting (used to call intInfo)
target: std.Target,
/// Represents the wasm binary file that is being linked.
bin_file: *link.File.Wasm,
/// Table with the global error set. Consists of every error found in
/// the compiled code. Each error name maps to a `Module.ErrorInt` which is emitted
/// during codegen to determine the error value.
global_error_set: std.StringHashMapUnmanaged(Module.ErrorInt),
/// List of MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// Contains extra data for MIR
mir_extra: std.ArrayListUnmanaged(u32) = .{},
/// When a function is executing, we store the the current stack pointer's value within this local.
/// This value is then used to restore the stack pointer to the original value at the return of the function.
initial_stack_value: WValue = .none,
/// Arguments of this function declaration
/// This will be set after `resolveCallingConventionValues`
args: []WValue = &.{},
/// This will only be `.none` if the function returns void, or returns an immediate.
/// When it returns a pointer to the stack, the `.local` tag will be active and must be populated
/// before this function returns its execution to the caller.
return_value: WValue = .none,

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
    self.code.deinit();
    self.* = undefined;
}

/// Sets `err_msg` on `Context` and returns `error.CodegemFail` which is caught in link/Wasm.zig
fn fail(self: *Self, comptime fmt: []const u8, args: anytype) InnerError {
    const src: LazySrcLoc = .{ .node_offset = 0 };
    const src_loc = src.toSrcLoc(self.decl);
    self.err_msg = try Module.ErrorMsg.create(self.gpa, src_loc, fmt, args);
    return error.CodegenFail;
}

/// Resolves the `WValue` for the given instruction `inst`
/// When the given instruction has a `Value`, it returns a constant instead
fn resolveInst(self: Self, ref: Air.Inst.Ref) WValue {
    const inst_index = Air.refToIndex(ref) orelse {
        const tv = Air.Inst.Ref.typed_value_map[@enumToInt(ref)];
        if (!tv.ty.hasCodeGenBits()) {
            return WValue.none;
        }
        return WValue{ .constant = tv };
    };

    const inst_type = self.air.typeOfIndex(inst_index);
    if (!inst_type.hasCodeGenBits()) return .none;

    if (self.air.instructions.items(.tag)[inst_index] == .constant) {
        const ty_pl = self.air.instructions.items(.data)[inst_index].ty_pl;
        return WValue{ .constant = .{ .ty = inst_type, .val = self.air.values[ty_pl.payload] } };
    }

    return self.values.get(inst_index).?; // Instruction does not dominate all uses!
}

/// Appends a MIR instruction and returns its index within the list of instructions
fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!void {
    try self.mir_instructions.append(self.gpa, inst);
}

/// Inserts a Mir instruction at the given `offset`.
/// Asserts offset is within bound.
fn addInstAt(self: *Self, offset: usize, inst: Mir.Inst) error{OutOfMemory}!void {
    try self.mir_instructions.ensureUnusedCapacity(self.gpa, 1);
    self.mir_instructions.insertAssumeCapacity(offset, inst);
}

fn addTag(self: *Self, tag: Mir.Inst.Tag) error{OutOfMemory}!void {
    try self.addInst(.{ .tag = tag, .data = .{ .tag = {} } });
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

/// Using a given `Type`, returns the corresponding wasm Valtype
fn typeToValtype(self: *Self, ty: Type) InnerError!wasm.Valtype {
    return switch (ty.zigTypeTag()) {
        .Float => blk: {
            const bits = ty.floatBits(self.target);
            if (bits == 16 or bits == 32) break :blk wasm.Valtype.f32;
            if (bits == 64) break :blk wasm.Valtype.f64;
            return self.fail("Float bit size not supported by wasm: '{d}'", .{bits});
        },
        .Int => blk: {
            const info = ty.intInfo(self.target);
            if (info.bits <= 32) break :blk wasm.Valtype.i32;
            if (info.bits > 32 and info.bits <= 64) break :blk wasm.Valtype.i64;
            return self.fail("Integer bit size not supported by wasm: '{d}'", .{info.bits});
        },
        .Enum => switch (ty.tag()) {
            .enum_simple => wasm.Valtype.i32,
            else => self.typeToValtype(ty.cast(Type.Payload.EnumFull).?.data.tag_ty),
        },
        .Bool,
        .Pointer,
        .ErrorSet,
        .Struct,
        .ErrorUnion,
        .Optional,
        .Fn,
        => wasm.Valtype.i32,
        else => self.fail("TODO - Wasm valtype for type '{}'", .{ty}),
    };
}

/// Using a given `Type`, returns the byte representation of its wasm value type
fn genValtype(self: *Self, ty: Type) InnerError!u8 {
    return wasm.valtype(try self.typeToValtype(ty));
}

/// Using a given `Type`, returns the corresponding wasm value type
/// Differently from `genValtype` this also allows `void` to create a block
/// with no return type
fn genBlockType(self: *Self, ty: Type) InnerError!u8 {
    return switch (ty.tag()) {
        .void, .noreturn => wasm.block_empty,
        else => self.genValtype(ty),
    };
}

/// Writes the bytecode depending on the given `WValue` in `val`
fn emitWValue(self: *Self, val: WValue) InnerError!void {
    switch (val) {
        .none => {}, // no-op
        .local_with_offset => |with_off| try self.addLabel(.local_get, with_off.local),
        .local => |idx| try self.addLabel(.local_get, idx),
        .constant => |tv| try self.emitConstant(tv.val, tv.ty), // Creates a new constant on the stack
    }
}

/// Creates one locals for a given `Type`.
/// Returns a corresponding `Wvalue` with `local` as active tag
fn allocLocal(self: *Self, ty: Type) InnerError!WValue {
    const initial_index = self.local_index;
    const valtype = try self.genValtype(ty);
    try self.locals.append(self.gpa, valtype);
    self.local_index += 1;
    return WValue{ .local = initial_index };
}

/// Generates a `wasm.Type` from a given function type.
/// Memory is owned by the caller.
fn genFunctype(self: *Self, fn_ty: Type) !wasm.Type {
    var params = std.ArrayList(wasm.Valtype).init(self.gpa);
    defer params.deinit();
    var returns = std.ArrayList(wasm.Valtype).init(self.gpa);
    defer returns.deinit();

    // param types
    if (fn_ty.fnParamLen() != 0) {
        const fn_params = try self.gpa.alloc(Type, fn_ty.fnParamLen());
        defer self.gpa.free(fn_params);
        fn_ty.fnParamTypes(fn_params);
        for (fn_params) |param_type| {
            if (!param_type.hasCodeGenBits()) continue;
            try params.append(try self.typeToValtype(param_type));
        }
    }

    // return type
    const return_type = fn_ty.fnReturnType();
    switch (return_type.zigTypeTag()) {
        .Void, .NoReturn => {},
        .Struct => return self.fail("TODO: Implement struct as return type for wasm", .{}),
        .Optional => return self.fail("TODO: Implement optionals as return type for wasm", .{}),
        else => try returns.append(try self.typeToValtype(return_type)),
    }

    return wasm.Type{
        .params = params.toOwnedSlice(),
        .returns = returns.toOwnedSlice(),
    };
}

pub fn genFunc(self: *Self) InnerError!Result {
    var func_type = try self.genFunctype(self.decl.ty);
    defer func_type.deinit(self.gpa);
    self.decl.fn_link.wasm.type_index = try self.bin_file.putOrGetFuncType(func_type);

    var cc_result = try self.resolveCallingConventionValues(self.decl.ty);
    defer cc_result.deinit(self.gpa);

    self.args = cc_result.args;
    self.return_value = cc_result.return_value;

    // Generate MIR for function body
    try self.genBody(self.air.getMainBody());
    // End of function body
    try self.addTag(.end);

    var mir: Mir = .{
        .instructions = self.mir_instructions.toOwnedSlice(),
        .extra = self.mir_extra.toOwnedSlice(self.gpa),
    };
    defer mir.deinit(self.gpa);

    var emit: Emit = .{
        .mir = mir,
        .bin_file = &self.bin_file.base,
        .code = &self.code,
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

    // codegen data has been appended to `code`
    return Result.appended;
}

pub fn genDecl(self: *Self) InnerError!Result {
    const decl = self.decl;
    assert(decl.has_tv);

    log.debug("gen: {s} type: {}, value: {}", .{ decl.name, decl.ty, decl.val });

    if (decl.val.castTag(.function)) |func_payload| {
        _ = func_payload;
        return self.fail("TODO wasm backend genDecl function pointer", .{});
    } else if (decl.val.castTag(.extern_fn)) |extern_fn| {
        const ext_decl = extern_fn.data;
        var func_type = try self.genFunctype(ext_decl.ty);
        func_type.deinit(self.gpa);
        ext_decl.fn_link.wasm.type_index = try self.bin_file.putOrGetFuncType(func_type);
        return Result.appended;
    } else {
        const init_val = if (decl.val.castTag(.variable)) |payload| init_val: {
            break :init_val payload.data.init;
        } else decl.val;
        if (init_val.tag() != .unreachable_value) {
            return try self.genTypedValue(decl.ty, init_val);
        }
        return Result.appended;
    }
}

/// Generates the wasm bytecode for the declaration belonging to `Context`
fn genTypedValue(self: *Self, ty: Type, val: Value) InnerError!Result {
    if (val.isUndef()) {
        try self.code.appendNTimes(0xaa, @intCast(usize, ty.abiSize(self.target)));
        return Result.appended;
    }
    switch (ty.zigTypeTag()) {
        .Fn => {
            const fn_decl = switch (val.tag()) {
                .extern_fn => val.castTag(.extern_fn).?.data,
                .function => val.castTag(.function).?.data.owner_decl,
                else => unreachable,
            };
            return try self.lowerDeclRef(ty, val, fn_decl);
        },
        .Optional => {
            var opt_buf: Type.Payload.ElemType = undefined;
            const payload_type = ty.optionalChild(&opt_buf);
            if (ty.isPtrLikeOptional()) {
                if (val.castTag(.opt_payload)) |payload| {
                    return try self.genTypedValue(payload_type, payload.data);
                } else if (!val.isNull()) {
                    return try self.genTypedValue(payload_type, val);
                } else {
                    try self.code.appendNTimes(0, @intCast(usize, ty.abiSize(self.target)));
                    return Result.appended;
                }
            }
            // `null-tag` byte
            try self.code.appendNTimes(@boolToInt(!val.isNull()), 4);
            const pl_result = try self.genTypedValue(
                payload_type,
                if (val.castTag(.opt_payload)) |pl| pl.data else Value.initTag(.undef),
            );
            switch (pl_result) {
                .appended => {},
                .externally_managed => |payload| try self.code.appendSlice(payload),
            }
            return Result.appended;
        },
        .Array => switch (val.tag()) {
            .bytes => {
                const payload = val.castTag(.bytes).?;
                if (ty.sentinel()) |sentinel| {
                    try self.code.appendSlice(payload.data);

                    switch (try self.genTypedValue(ty.childType(), sentinel)) {
                        .appended => return Result.appended,
                        .externally_managed => |data| {
                            try self.code.appendSlice(data);
                            return Result.appended;
                        },
                    }
                }
                return Result{ .externally_managed = payload.data };
            },
            .array => {
                const elem_vals = val.castTag(.array).?.data;
                const elem_ty = ty.elemType();
                for (elem_vals) |elem_val| {
                    switch (try self.genTypedValue(elem_ty, elem_val)) {
                        .appended => {},
                        .externally_managed => |data| try self.code.appendSlice(data),
                    }
                }
                return Result.appended;
            },
            else => return self.fail("TODO implement genTypedValue for array type value: {s}", .{@tagName(val.tag())}),
        },
        .Int => {
            const info = ty.intInfo(self.target);
            const abi_size = @intCast(usize, ty.abiSize(self.target));
            // todo: Implement integer sizes larger than 64bits
            if (info.bits > 64) return self.fail("TODO: Implement genTypedValue for integer bit size: {d}", .{info.bits});
            var buf: [8]u8 = undefined;
            if (info.signedness == .unsigned) {
                std.mem.writeIntLittle(u64, &buf, val.toUnsignedInt());
            } else std.mem.writeIntLittle(i64, &buf, val.toSignedInt());
            try self.code.appendSlice(buf[0..abi_size]);
            return Result.appended;
        },
        .Enum => {
            try self.emitConstant(val, ty);
            return Result.appended;
        },
        .Bool => {
            const int_byte: u8 = @boolToInt(val.toBool());
            try self.code.append(int_byte);
            return Result.appended;
        },
        .Struct => {
            const field_vals = val.castTag(.@"struct").?.data;
            for (field_vals) |field_val, index| {
                const field_ty = ty.structFieldType(index);
                if (!field_ty.hasCodeGenBits()) continue;
                switch (try self.genTypedValue(field_ty, field_val)) {
                    .appended => {},
                    .externally_managed => |payload| try self.code.appendSlice(payload),
                }
            }
            return Result.appended;
        },
        .Union => {
            // TODO: Implement Union declarations
            const abi_size = @intCast(usize, ty.abiSize(self.target));
            try self.code.appendNTimes(0xaa, abi_size);
            return Result.appended;
        },
        .Pointer => switch (val.tag()) {
            .variable => {
                const decl = val.castTag(.variable).?.data.owner_decl;
                return try self.lowerDeclRef(ty, val, decl);
            },
            .decl_ref => {
                const decl = val.castTag(.decl_ref).?.data;
                return try self.lowerDeclRef(ty, val, decl);
            },
            .slice => {
                const slice = val.castTag(.slice).?.data;
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_ty = ty.slicePtrFieldType(&buf);
                switch (try self.genTypedValue(ptr_ty, slice.ptr)) {
                    .externally_managed => |data| try self.code.appendSlice(data),
                    .appended => {},
                }
                switch (try self.genTypedValue(Type.usize, slice.len)) {
                    .externally_managed => |data| try self.code.appendSlice(data),
                    .appended => {},
                }
                return Result.appended;
            },
            else => return self.fail("TODO: Implement zig decl gen for pointer type value: '{s}'", .{@tagName(val.tag())}),
        },
        else => |tag| return self.fail("TODO: Implement zig type codegen for type: '{s}'", .{tag}),
    }
}

fn lowerDeclRef(self: *Self, ty: Type, val: Value, decl: *Module.Decl) InnerError!Result {
    if (ty.isSlice()) {
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ty = ty.slicePtrFieldType(&buf);
        switch (try self.genTypedValue(slice_ty, val)) {
            .appended => {},
            .externally_managed => |payload| try self.code.appendSlice(payload),
        }
        var slice_len: Value.Payload.U64 = .{
            .base = .{ .tag = .int_u64 },
            .data = val.sliceLen(),
        };
        return try self.genTypedValue(Type.usize, Value.initPayload(&slice_len.base));
    }

    const offset = @intCast(u32, self.code.items.len);
    const atom = &self.decl.link.wasm;
    const target_sym_index = decl.link.wasm.sym_index;
    decl.alive = true;
    if (decl.ty.zigTypeTag() == .Fn) {
        // We found a function pointer, so add it to our table,
        // as function pointers are not allowed to be stored inside the data section,
        // but rather in a function table which are called by index
        try self.bin_file.addTableFunction(target_sym_index);
        try atom.relocs.append(self.gpa, .{
            .index = target_sym_index,
            .offset = offset,
            .relocation_type = .R_WASM_TABLE_INDEX_I32,
        });
    } else {
        try atom.relocs.append(self.gpa, .{
            .index = target_sym_index,
            .offset = offset,
            .relocation_type = .R_WASM_MEMORY_ADDR_I32,
        });
    }
    const ptr_width = @intCast(usize, self.target.cpu.arch.ptrBitWidth() / 8);
    try self.code.appendNTimes(0xaa, ptr_width);

    return Result.appended;
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
        .args = try self.gpa.alloc(WValue, param_types.len),
        .return_value = .none,
    };
    errdefer self.gpa.free(result.args);
    switch (cc) {
        .Naked => return result,
        .Unspecified, .C => {
            for (param_types) |ty, ty_index| {
                if (!ty.hasCodeGenBits()) {
                    result.args[ty_index] = .{ .none = {} };
                    continue;
                }

                result.args[ty_index] = .{ .local = self.local_index };
                self.local_index += 1;
            }

            const ret_ty = fn_ty.fnReturnType();
            switch (ret_ty.zigTypeTag()) {
                .ErrorUnion, .Optional, .Pointer => result.return_value = try self.allocLocal(Type.initTag(.i32)),
                .Int, .Float, .Bool, .Void, .NoReturn => {},
                else => return self.fail("TODO: Implement function return type {}", .{ret_ty}),
            }

            // Check if we store the result as a pointer to the stack rather than
            // by value
            if (result.return_value != .none) {
                if (self.initial_stack_value == .none) try self.initializeStack();
                const offset = std.math.cast(u32, ret_ty.abiSize(self.target)) catch {
                    return self.fail("Return type '{}' too big for stack frame", .{ret_ty});
                };

                try self.moveStack(offset, result.return_value.local);

                // We want to make sure the return value's stack value doesn't get overwritten,
                // so set initial stack value to current's position instead.
                try self.addLabel(.global_get, 0);
                try self.addLabel(.local_set, self.initial_stack_value.local);
            }
        },
        else => return self.fail("TODO implement function parameters for cc '{}' on wasm", .{cc}),
    }
    return result;
}

/// Retrieves the stack pointer's value from the global variable and stores
/// it in a local
/// Asserts `initial_stack_value` is `.none`
fn initializeStack(self: *Self) !void {
    assert(self.initial_stack_value == .none);
    // reserve space for immediate value
    // get stack pointer global
    try self.addLabel(.global_get, 0);

    // Reserve a local to store the current stack pointer
    // We can later use this local to set the stack pointer back to the value
    // we have stored here.
    self.initial_stack_value = try self.allocLocal(Type.initTag(.i32));

    // save the value to the local
    try self.addLabel(.local_set, self.initial_stack_value.local);
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

/// Moves the stack pointer by given `offset`
/// It does this by retrieving the stack pointer, subtracting `offset` and storing
/// the result back into the stack pointer.
fn moveStack(self: *Self, offset: u32, local: u32) !void {
    if (offset == 0) return;
    try self.addLabel(.global_get, 0);
    try self.addImm32(@bitCast(i32, offset));
    try self.addTag(.i32_sub);
    try self.addLabel(.local_tee, local);
    try self.addLabel(.global_set, 0);
}

/// From given zig bitsize, returns the wasm bitsize
fn toWasmIntBits(bits: u16) ?u16 {
    return for ([_]u16{ 32, 64 }) |wasm_bits| {
        if (bits <= wasm_bits) return wasm_bits;
    } else null;
}

fn genInst(self: *Self, inst: Air.Inst.Index) !WValue {
    const air_tags = self.air.instructions.items(.tag);
    return switch (air_tags[inst]) {
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
        .xor => self.airBinOp(inst, .xor),

        .cmp_eq => self.airCmp(inst, .eq),
        .cmp_gte => self.airCmp(inst, .gte),
        .cmp_gt => self.airCmp(inst, .gt),
        .cmp_lte => self.airCmp(inst, .lte),
        .cmp_lt => self.airCmp(inst, .lt),
        .cmp_neq => self.airCmp(inst, .neq),

        .alloc => self.airAlloc(inst),
        .arg => self.airArg(inst),
        .bitcast => self.airBitcast(inst),
        .block => self.airBlock(inst),
        .breakpoint => self.airBreakpoint(inst),
        .br => self.airBr(inst),
        .call => self.airCall(inst),
        .cond_br => self.airCondBr(inst),
        .constant => unreachable,
        .dbg_stmt => WValue.none,
        .intcast => self.airIntcast(inst),

        .is_err => self.airIsErr(inst, .i32_ne),
        .is_non_err => self.airIsErr(inst, .i32_eq),

        .is_null => self.airIsNull(inst, .i32_ne),
        .is_non_null => self.airIsNull(inst, .i32_eq),
        .is_null_ptr => self.airIsNull(inst, .i32_ne),
        .is_non_null_ptr => self.airIsNull(inst, .i32_eq),

        .load => self.airLoad(inst),
        .loop => self.airLoop(inst),
        .not => self.airNot(inst),
        .optional_payload => self.airOptionalPayload(inst),
        .optional_payload_ptr => self.airOptionalPayload(inst),
        .optional_payload_ptr_set => self.airOptionalPayloadPtrSet(inst),
        .ret => self.airRet(inst),
        .ret_ptr => self.airRetPtr(inst),
        .ret_load => self.airRetLoad(inst),
        .slice_len => self.airSliceLen(inst),
        .slice_elem_val => self.airSliceElemVal(inst),
        .slice_ptr => self.airSlicePtr(inst),
        .store => self.airStore(inst),
        .struct_field_ptr => self.airStructFieldPtr(inst),
        .struct_field_ptr_index_0 => self.airStructFieldPtrIndex(inst, 0),
        .struct_field_ptr_index_1 => self.airStructFieldPtrIndex(inst, 1),
        .struct_field_ptr_index_2 => self.airStructFieldPtrIndex(inst, 2),
        .struct_field_ptr_index_3 => self.airStructFieldPtrIndex(inst, 3),
        .struct_field_val => self.airStructFieldVal(inst),
        .switch_br => self.airSwitchBr(inst),
        .trunc => self.airTrunc(inst),
        .unreach => self.airUnreachable(inst),

        .wrap_optional => self.airWrapOptional(inst),
        .unwrap_errunion_payload => self.airUnwrapErrUnionPayload(inst),
        .unwrap_errunion_err => self.airUnwrapErrUnionError(inst),
        .wrap_errunion_payload => self.airWrapErrUnionPayload(inst),
        .wrap_errunion_err => self.airWrapErrUnionErr(inst),
        else => |tag| self.fail("TODO: Implement wasm inst: {s}", .{@tagName(tag)}),
    };
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    for (body) |inst| {
        const result = try self.genInst(inst);
        try self.values.putNoClobber(self.gpa, inst, result);
    }
}

fn airRet(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = self.resolveInst(un_op);
    // result must be stored in the stack and we return a pointer
    // to the stack instead
    if (self.return_value != .none) {
        try self.store(self.return_value, operand, self.decl.ty.fnReturnType(), 0);
        try self.emitWValue(self.return_value);
    } else {
        try self.emitWValue(operand);
    }
    try self.restoreStackPointer();
    try self.addTag(.@"return");
    return .none;
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const child_type = self.air.typeOfIndex(inst).childType();

    // Initialize the stack
    if (self.initial_stack_value == .none) {
        try self.initializeStack();
    }

    const abi_size = child_type.abiSize(self.target);
    if (abi_size == 0) return WValue{ .none = {} };

    // local, containing the offset to the stack position
    const local = try self.allocLocal(Type.initTag(.i32)); // always pointer therefore i32
    try self.moveStack(@intCast(u32, abi_size), local.local);
    return local;
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = self.resolveInst(un_op);

    const result = try self.load(operand, self.air.typeOf(un_op).childType(), 0);
    try self.emitWValue(result);
    try self.restoreStackPointer();
    try self.addTag(.@"return");
    return .none;
}

fn airCall(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = self.air.extra[extra.end..][0..extra.data.args_len];
    const ty = self.air.typeOf(pl_op.operand);

    const fn_ty = switch (ty.zigTypeTag()) {
        .Fn => ty,
        .Pointer => ty.childType(),
        else => unreachable,
    };

    const target: ?*Decl = blk: {
        const func_val = self.air.value(pl_op.operand) orelse break :blk null;

        if (func_val.castTag(.function)) |func| {
            break :blk func.data.owner_decl;
        } else if (func_val.castTag(.extern_fn)) |ext_fn| {
            break :blk ext_fn.data;
        }
        return self.fail("Expected a function, but instead found type '{s}'", .{func_val.tag()});
    };

    for (args) |arg| {
        const arg_ref = @intToEnum(Air.Inst.Ref, arg);
        const arg_val = self.resolveInst(arg_ref);

        const arg_ty = self.air.typeOf(arg_ref);
        switch (arg_ty.zigTypeTag()) {
            .Struct, .Pointer, .Optional, .ErrorUnion => {
                // single pointer can be passed directly
                if (arg_ty.isSinglePointer() or arg_val != .constant) {
                    try self.emitWValue(arg_val);
                    continue;
                }
                const abi_size = arg_ty.abiSize(self.target);
                const arg_local = try self.allocLocal(Type.initTag(.i32));
                try self.moveStack(@intCast(u32, abi_size), arg_local.local);
                try self.store(arg_local, arg_val, arg_ty, 0);
                try self.emitWValue(arg_local);
            },
            else => try self.emitWValue(arg_val),
        }
    }

    if (target) |direct| {
        try self.addLabel(.call, direct.link.wasm.sym_index);
    } else {
        // in this case we call a function pointer
        // so load its value onto the stack
        std.debug.assert(ty.zigTypeTag() == .Pointer);
        const operand = self.resolveInst(pl_op.operand);
        const offset = switch (operand) {
            .local_with_offset => |with_offset| with_offset.offset,
            else => @as(u32, 0),
        };
        const result = try self.load(operand, fn_ty, offset);
        try self.addLabel(.local_get, result.local);

        var fn_type = try self.genFunctype(fn_ty);
        defer fn_type.deinit(self.gpa);

        const fn_type_index = try self.bin_file.putOrGetFuncType(fn_type);
        try self.addLabel(.call_indirect, fn_type_index);
    }

    const ret_ty = fn_ty.fnReturnType();
    if (!ret_ty.hasCodeGenBits()) return WValue.none;

    const result_local = try self.allocLocal(ret_ty);
    try self.addLabel(.local_set, result_local.local);
    // if the result was allocated on the virtual stack, we must load
    return result_local;
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const child_type = self.air.typeOfIndex(inst).childType();

    // Initialize the stack
    if (self.initial_stack_value == .none) {
        try self.initializeStack();
    }

    const abi_size = child_type.abiSize(self.target);
    if (abi_size == 0) return WValue{ .none = {} };

    // local, containing the offset to the stack position
    const local = try self.allocLocal(Type.initTag(.i32)); // always pointer therefore i32
    try self.moveStack(@intCast(u32, abi_size), local.local);
    return local;
}

fn airStore(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const lhs = self.resolveInst(bin_op.lhs);
    const rhs = self.resolveInst(bin_op.rhs);
    const ty = self.air.typeOf(bin_op.lhs).childType();

    const offset: u32 = switch (lhs) {
        .local_with_offset => |with_off| with_off.offset,
        else => 0,
    };

    try self.store(lhs, rhs, ty, offset);
    return .none;
}

fn store(self: *Self, lhs: WValue, rhs: WValue, ty: Type, offset: u32) InnerError!void {
    switch (ty.zigTypeTag()) {
        .ErrorUnion, .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            const payload_ty = if (ty.zigTypeTag() == .ErrorUnion) ty.errorUnionPayload() else ty.optionalChild(&buf);
            const tag_ty = if (ty.zigTypeTag() == .ErrorUnion) ty.errorUnionSet() else Type.initTag(.u8);
            const payload_offset = if (ty.zigTypeTag() == .ErrorUnion)
                @intCast(u32, tag_ty.abiSize(self.target))
            else
                @intCast(u32, ty.abiSize(self.target) - payload_ty.abiSize(self.target));

            switch (rhs) {
                .constant => {
                    // constant will contain both tag and payload,
                    // so save those in 2 temporary locals before storing them
                    // in memory
                    try self.emitWValue(rhs);
                    const tag_local = try self.allocLocal(tag_ty);

                    if (payload_ty.hasCodeGenBits()) {
                        const payload_local = try self.allocLocal(payload_ty);
                        try self.addLabel(.local_set, payload_local.local);
                        try self.store(lhs, payload_local, payload_ty, payload_offset);
                    }
                    try self.addLabel(.local_set, tag_local.local);

                    try self.store(lhs, tag_local, tag_ty, 0);
                    return;
                },
                .local => {
                    // Load values from `rhs` stack position and store in `lhs` instead
                    const tag_local = try self.load(rhs, tag_ty, 0);
                    if (payload_ty.hasCodeGenBits()) {
                        const payload_local = try self.load(rhs, payload_ty, payload_offset);
                        try self.store(lhs, payload_local, payload_ty, payload_offset);
                    }
                    return try self.store(lhs, tag_local, tag_ty, 0);
                },
                .local_with_offset => |with_offset| {
                    const tag_local = try self.allocLocal(tag_ty);
                    try self.addImm32(0);
                    try self.addLabel(.local_set, tag_local.local);
                    try self.store(lhs, tag_local, tag_ty, 0);

                    return try self.store(
                        lhs,
                        .{ .local = with_offset.local },
                        payload_ty,
                        with_offset.offset,
                    );
                },
                else => unreachable,
            }
        },
        .Struct => {
            // we are copying a struct with its fields.
            // Replace this with a wasm memcpy instruction once we support that feature.
            const fields_len = ty.structFieldCount();
            var index: usize = 0;
            while (index < fields_len) : (index += 1) {
                const field_ty = ty.structFieldType(index);
                if (!field_ty.hasCodeGenBits()) continue;
                const field_offset = std.math.cast(u32, ty.structFieldOffset(index, self.target)) catch {
                    return self.fail("Field type '{}' too big to fit into stack frame", .{field_ty});
                };
                const field_local = try self.load(rhs, field_ty, field_offset);
                try self.store(lhs, field_local, field_ty, field_offset);
            }
            return;
        },
        .Pointer => {
            if (ty.isSlice() and rhs == .constant) {
                try self.emitWValue(rhs);
                const len_local = try self.allocLocal(Type.usize);
                const ptr_local = try self.allocLocal(Type.usize);
                try self.addLabel(.local_set, len_local.local);
                try self.addLabel(.local_set, ptr_local.local);
                try self.store(lhs, ptr_local, Type.usize, 0);
                try self.store(lhs, len_local, Type.usize, self.target.cpu.arch.ptrBitWidth() / 8);
                return;
            }
        },
        else => {},
    }
    try self.emitWValue(lhs);
    try self.emitWValue(rhs);
    const valtype = try self.typeToValtype(ty);
    // check if we should pass by pointer or value based on ABI size
    // TODO: Implement a way to get ABI values from a given type,
    // that is portable across the backend, rather than copying logic.
    const abi_size = if ((ty.isInt() or ty.isAnyFloat()) and ty.abiSize(self.target) <= 8)
        @intCast(u8, ty.abiSize(self.target))
    else if (ty.zigTypeTag() == .ErrorSet or ty.zigTypeTag() == .Enum)
        @intCast(u8, ty.abiSize(self.target))
    else
        @as(u8, 4);
    const opcode = buildOpcode(.{
        .valtype1 = valtype,
        .width = abi_size * 8, // use bitsize instead of byte size
        .op = .store,
    });

    // store rhs value at stack pointer's location in memory
    const mem_arg_index = try self.addExtra(Mir.MemArg{
        .offset = offset,
        .alignment = ty.abiAlignment(self.target),
    });
    try self.addInst(.{
        .tag = Mir.Inst.Tag.fromOpcode(opcode),
        .data = .{ .payload = mem_arg_index },
    });
}

fn airLoad(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const ty = self.air.getRefType(ty_op.ty);

    if (!ty.hasCodeGenBits()) return WValue{ .none = {} };

    return switch (ty.zigTypeTag()) {
        .Struct, .ErrorUnion, .Optional, .Pointer => operand, // pass as pointer
        else => switch (operand) {
            .local_with_offset => |with_offset| try self.load(operand, ty, with_offset.offset),
            else => try self.load(operand, ty, 0),
        },
    };
}

fn load(self: *Self, operand: WValue, ty: Type, offset: u32) InnerError!WValue {
    // load local's value from memory by its stack position
    try self.emitWValue(operand);
    // Build the opcode with the right bitsize
    const signedness: std.builtin.Signedness = if (ty.isUnsignedInt() or ty.zigTypeTag() == .ErrorSet)
        .unsigned
    else
        .signed;
    // check if we should pass by pointer or value based on ABI size
    // TODO: Implement a way to get ABI values from a given type,
    // that is portable across the backend, rather than copying logic.
    const abi_size = if ((ty.isInt() or ty.isAnyFloat()) and ty.abiSize(self.target) <= 8)
        @intCast(u8, ty.abiSize(self.target))
    else if (ty.zigTypeTag() == .ErrorSet or ty.zigTypeTag() == .Enum)
        @intCast(u8, ty.abiSize(self.target))
    else
        @as(u8, 4);

    const opcode = buildOpcode(.{
        .valtype1 = try self.typeToValtype(ty),
        .width = abi_size * 8, // use bitsize instead of byte size
        .op = .load,
        .signedness = signedness,
    });

    const mem_arg_index = try self.addExtra(Mir.MemArg{
        .offset = offset,
        .alignment = ty.abiAlignment(self.target),
    });
    try self.addInst(.{
        .tag = Mir.Inst.Tag.fromOpcode(opcode),
        .data = .{ .payload = mem_arg_index },
    });

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
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = self.resolveInst(bin_op.lhs);
    const rhs = self.resolveInst(bin_op.rhs);

    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    const bin_ty = self.air.typeOf(bin_op.lhs);
    const opcode: wasm.Opcode = buildOpcode(.{
        .op = op,
        .valtype1 = try self.typeToValtype(bin_ty),
        .signedness = if (bin_ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    // save the result in a temporary
    const bin_local = try self.allocLocal(bin_ty);
    try self.addLabel(.local_set, bin_local.local);
    return bin_local;
}

fn airWrapBinOp(self: *Self, inst: Air.Inst.Index, op: Op) InnerError!WValue {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = self.resolveInst(bin_op.lhs);
    const rhs = self.resolveInst(bin_op.rhs);

    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    const bin_ty = self.air.typeOf(bin_op.lhs);
    const opcode: wasm.Opcode = buildOpcode(.{
        .op = op,
        .valtype1 = try self.typeToValtype(bin_ty),
        .signedness = if (bin_ty.isSignedInt()) .signed else .unsigned,
    });
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const int_info = bin_ty.intInfo(self.target);
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
    const bin_local = try self.allocLocal(bin_ty);
    try self.addLabel(.local_set, bin_local.local);
    return bin_local;
}

fn emitConstant(self: *Self, val: Value, ty: Type) InnerError!void {
    if (val.isUndefDeep()) return self.emitUndefined(ty);
    switch (ty.zigTypeTag()) {
        .Int => {
            const int_info = ty.intInfo(self.target);
            // write constant
            switch (int_info.signedness) {
                .signed => switch (int_info.bits) {
                    0...32 => try self.addImm32(@intCast(i32, val.toSignedInt())),
                    33...64 => try self.addImm64(@bitCast(u64, val.toSignedInt())),
                    else => |bits| return self.fail("Wasm todo: emitConstant for integer with {d} bits", .{bits}),
                },
                .unsigned => switch (int_info.bits) {
                    0...32 => try self.addImm32(@bitCast(i32, @intCast(u32, val.toUnsignedInt()))),
                    33...64 => try self.addImm64(val.toUnsignedInt()),
                    else => |bits| return self.fail("Wasm TODO: emitConstant for integer with {d} bits", .{bits}),
                },
            }
        },
        .Bool => try self.addImm32(@intCast(i32, val.toSignedInt())),
        .Float => {
            // write constant
            switch (ty.floatBits(self.target)) {
                0...32 => try self.addInst(.{ .tag = .f32_const, .data = .{ .float32 = val.toFloat(f32) } }),
                64 => try self.addFloat64(val.toFloat(f64)),
                else => |bits| return self.fail("Wasm TODO: emitConstant for float with {d} bits", .{bits}),
            }
        },
        .Pointer => {
            if (val.castTag(.slice)) |slice| {
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                try self.emitConstant(slice.data.ptr, ty.slicePtrFieldType(&buf));
                try self.emitConstant(slice.data.len, Type.usize);
            } else if (val.castTag(.decl_ref)) |payload| {
                const decl = payload.data;
                decl.alive = true;
                // Function pointers use a table index, rather than a memory address
                if (decl.ty.zigTypeTag() == .Fn) {
                    const target_sym_index = decl.link.wasm.sym_index;
                    try self.bin_file.addTableFunction(target_sym_index);
                    try self.addLabel(.function_index, target_sym_index);
                } else {
                    try self.addLabel(.memory_address, decl.link.wasm.sym_index);
                }
            } else return self.fail("Wasm TODO: emitConstant for other const pointer tag {s}", .{val.tag()});
        },
        .Void => {},
        .Enum => {
            if (val.castTag(.enum_field_index)) |field_index| {
                switch (ty.tag()) {
                    .enum_simple => try self.addImm32(@bitCast(i32, field_index.data)),
                    .enum_full, .enum_nonexhaustive => {
                        const enum_full = ty.cast(Type.Payload.EnumFull).?.data;
                        if (enum_full.values.count() != 0) {
                            const tag_val = enum_full.values.keys()[field_index.data];
                            try self.emitConstant(tag_val, enum_full.tag_ty);
                        } else {
                            try self.addImm32(@bitCast(i32, field_index.data));
                        }
                    },
                    else => unreachable,
                }
            } else {
                var int_tag_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = ty.intTagType(&int_tag_buffer);
                try self.emitConstant(val, int_tag_ty);
            }
        },
        .ErrorSet => {
            const error_index = self.global_error_set.get(val.getError().?).?;
            try self.addImm32(@bitCast(i32, error_index));
        },
        .ErrorUnion => {
            const error_type = ty.errorUnionSet();
            const payload_type = ty.errorUnionPayload();
            if (val.castTag(.eu_payload)) |pl| {
                const payload_val = pl.data;
                // no error, so write a '0' const
                try self.addImm32(0);

                if (payload_type.hasCodeGenBits()) {
                    // after the error code, we emit the payload
                    try self.emitConstant(payload_val, payload_type);
                }
            } else {
                // write the error val
                try self.emitConstant(val, error_type);

                if (payload_type.hasCodeGenBits()) {
                    // no payload, so write a '0' const
                    try self.addImm32(0);
                }
            }
        },
        .Optional => {
            var buf: Type.Payload.ElemType = undefined;
            const payload_type = ty.optionalChild(&buf);
            if (ty.isPtrLikeOptional()) {
                return self.fail("Wasm TODO: emitConstant for optional pointer", .{});
            }

            // When constant has value 'null', set is_null local to '1'
            // and payload to '0'
            if (val.castTag(.opt_payload)) |pl| {
                const payload_val = pl.data;
                try self.addImm32(0);
                try self.emitConstant(payload_val, payload_type);
            } else {
                // set null-tag
                try self.addImm32(1);
                // null-tag is set, so write a '0' const
                try self.addImm32(0);
            }
        },
        else => |zig_type| return self.fail("Wasm TODO: emitConstant for zigTypeTag {s}", .{zig_type}),
    }
}

fn emitUndefined(self: *Self, ty: Type) InnerError!void {
    switch (ty.zigTypeTag()) {
        .Int => switch (ty.intInfo(self.target).bits) {
            0...32 => try self.addImm32(@bitCast(i32, @as(u32, 0xaaaaaaaa))),
            33...64 => try self.addImm64(0xaaaaaaaaaaaaaaaa),
            else => |bits| return self.fail("Wasm TODO: emitUndefined for integer bitsize: {d}", .{bits}),
        },
        .Float => switch (ty.floatBits(self.target)) {
            0...32 => try self.addInst(.{ .tag = .f32_const, .data = .{ .float32 = @bitCast(f32, @as(u32, 0xaaaaaaaa)) } }),
            33...64 => try self.addFloat64(@bitCast(f64, @as(u64, 0xaaaaaaaaaaaaaaaa))),
            else => |bits| return self.fail("Wasm TODO: emitUndefined for float bitsize: {d}", .{bits}),
        },
        else => return self.fail("Wasm TODO: emitUndefined for type: {}\n", .{ty}),
    }
}

/// Returns a `Value` as a signed 32 bit value.
/// It's illegal to provide a value with a type that cannot be represented
/// as an integer value.
fn valueAsI32(self: Self, val: Value, ty: Type) i32 {
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
            .unsigned => return @bitCast(i32, @truncate(u32, val.toUnsignedInt())),
        },
        .ErrorSet => {
            const error_index = self.global_error_set.get(val.getError().?).?;
            return @bitCast(i32, error_index);
        },
        else => unreachable, // Programmer called this function for an illegal type
    }
}

fn airBlock(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const block_ty = try self.genBlockType(self.air.getRefType(ty_pl.ty));
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
    const condition = self.resolveInst(pl_op.operand);
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
    const data: Air.Inst.Data = self.air.instructions.items(.data)[inst];
    const lhs = self.resolveInst(data.bin_op.lhs);
    const rhs = self.resolveInst(data.bin_op.rhs);
    const lhs_ty = self.air.typeOf(data.bin_op.lhs);

    try self.emitWValue(lhs);
    try self.emitWValue(rhs);

    const signedness: std.builtin.Signedness = blk: {
        // by default we tell the operand type is unsigned (i.e. bools and enum values)
        if (lhs_ty.zigTypeTag() != .Int) break :blk .unsigned;

        // incase of an actual integer, we emit the correct signedness
        break :blk lhs_ty.intInfo(self.target).signedness;
    };
    const opcode: wasm.Opcode = buildOpcode(.{
        .valtype1 = try self.typeToValtype(lhs_ty),
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

fn airBr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const br = self.air.instructions.items(.data)[inst].br;
    const block = self.blocks.get(br.block_inst).?;

    // if operand has codegen bits we should break with a value
    if (self.air.typeOf(br.operand).hasCodeGenBits()) {
        try self.emitWValue(self.resolveInst(br.operand));

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

    const operand = self.resolveInst(ty_op.operand);
    try self.emitWValue(operand);

    // wasm does not have booleans nor the `not` instruction, therefore compare with 0
    // to create the same logic
    try self.addImm32(0);
    try self.addTag(.i32_eq);

    // save the result in the local
    const not_tmp = try self.allocLocal(self.air.getRefType(ty_op.ty));
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
    const struct_ptr = self.resolveInst(extra.data.struct_operand);
    const struct_ty = self.air.typeOf(extra.data.struct_operand).childType();
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(extra.data.field_index, self.target)) catch {
        return self.fail("Field type '{}' too big to fit into stack frame", .{
            struct_ty.structFieldType(extra.data.field_index),
        });
    };
    return structFieldPtr(struct_ptr, offset);
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u32) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const struct_ptr = self.resolveInst(ty_op.operand);
    const struct_ty = self.air.typeOf(ty_op.operand).childType();
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(index, self.target)) catch {
        return self.fail("Field type '{}' too big to fit into stack frame", .{
            struct_ty.structFieldType(index),
        });
    };
    return structFieldPtr(struct_ptr, offset);
}

fn structFieldPtr(struct_ptr: WValue, offset: u32) InnerError!WValue {
    return WValue{ .local_with_offset = .{ .local = struct_ptr.local, .offset = offset } };
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const struct_field = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const struct_ty = self.air.typeOf(struct_field.struct_operand);
    const operand = self.resolveInst(struct_field.struct_operand);
    const field_index = struct_field.field_index;
    const field_ty = struct_ty.structFieldType(field_index);
    if (!field_ty.hasCodeGenBits()) return WValue.none;
    const offset = std.math.cast(u32, struct_ty.structFieldOffset(field_index, self.target)) catch {
        return self.fail("Field type '{}' too big to fit into stack frame", .{field_ty});
    };
    return try self.load(operand, field_ty, offset);
}

fn airSwitchBr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    // result type is always 'noreturn'
    const blocktype = wasm.block_empty;
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const target = self.resolveInst(pl_op.operand);
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

    var lowest: i32 = 0;
    var highest: i32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @bitCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;
        const values = try self.gpa.alloc(CaseValue, items.len);
        errdefer self.gpa.free(values);

        for (items) |ref, i| {
            const item_val = self.air.value(ref).?;
            const int_val = self.valueAsI32(item_val, target_ty);
            if (int_val < lowest) {
                lowest = int_val;
            }
            if (int_val > highest) {
                highest = int_val;
            }
            values[i] = .{ .integer = int_val, .value = item_val };
        }

        case_list.appendAssumeCapacity(.{ .values = values, .body = case_body });
        try self.startBlock(.block, blocktype);
    }

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
        }

        // Account for default branch so always add '1'
        const depth = @intCast(u32, highest - lowest + @boolToInt(has_else_body)) + 1;
        const jump_table: Mir.JumpTable = .{ .length = depth };
        const table_extra_index = try self.addExtra(jump_table);
        try self.addInst(.{ .tag = .br_table, .data = .{ .payload = table_extra_index } });
        try self.mir_extra.ensureUnusedCapacity(self.gpa, depth);
        while (lowest <= highest) : (lowest += 1) {
            // idx represents the branch we jump to
            const idx = blk: {
                for (case_list.items) |case, idx| {
                    for (case.values) |case_value| {
                        if (case_value.integer == lowest) break :blk @intCast(u32, idx);
                    }
                }
                break :blk if (has_else_body) case_i else unreachable;
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
                try self.emitConstant(case.values[0].value, target_ty);
                const opcode = buildOpcode(.{
                    .valtype1 = try self.typeToValtype(target_ty),
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
                    try self.emitConstant(value.value, target_ty);
                    const opcode = buildOpcode(.{
                        .valtype1 = try self.typeToValtype(target_ty),
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
    const operand = self.resolveInst(un_op);
    const err_ty = self.air.typeOf(un_op).errorUnionSet();

    // load the error tag value
    try self.emitWValue(operand);
    const mem_arg_index = try self.addExtra(Mir.MemArg{
        .offset = 0,
        .alignment = err_ty.abiAlignment(self.target),
    });
    try self.addInst(.{
        .tag = .i32_load16_u,
        .data = .{ .payload = mem_arg_index },
    });

    // Compare the error value with '0'
    try self.addImm32(0);
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const is_err_tmp = try self.allocLocal(err_ty);
    try self.addLabel(.local_set, is_err_tmp.local);
    return is_err_tmp;
}

fn airUnwrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const err_ty = self.air.typeOf(ty_op.operand);
    const payload_ty = err_ty.errorUnionPayload();
    if (!payload_ty.hasCodeGenBits()) return WValue.none;
    const offset = @intCast(u32, err_ty.errorUnionSet().abiSize(self.target));
    return try self.load(operand, payload_ty, offset);
}

fn airUnwrapErrUnionError(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const err_ty = self.air.typeOf(ty_op.operand);
    return try self.load(operand, err_ty.errorUnionSet(), 0);
}

fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);

    const op_ty = self.air.typeOf(ty_op.operand);
    if (!op_ty.hasCodeGenBits()) return WValue.none;
    const err_ty = self.air.getRefType(ty_op.ty);
    const offset = err_ty.errorUnionSet().abiSize(self.target);

    return WValue{ .local_with_offset = .{
        .local = operand.local,
        .offset = @intCast(u32, offset),
    } };
}

fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    return self.resolveInst(ty_op.operand);
}

fn airIntcast(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const ty = self.air.getRefType(ty_op.ty);
    const operand = self.resolveInst(ty_op.operand);
    const ref_ty = self.air.typeOf(ty_op.operand);
    const ref_info = ref_ty.intInfo(self.target);
    const wanted_info = ty.intInfo(self.target);

    const op_bits = toWasmIntBits(ref_info.bits) orelse
        return self.fail("TODO: Wasm intcast integer types of bitsize: {d}", .{ref_info.bits});
    const wanted_bits = toWasmIntBits(wanted_info.bits) orelse
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
    }
    const result = try self.allocLocal(ty);
    try self.addLabel(.local_set, result.local);
    return result;
}

fn airIsNull(self: *Self, inst: Air.Inst.Index, opcode: wasm.Opcode) InnerError!WValue {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = self.resolveInst(un_op);

    // load the null tag value
    try self.emitWValue(operand);
    const mem_arg_index = try self.addExtra(Mir.MemArg{ .offset = 0, .alignment = 1 });
    try self.addInst(.{
        .tag = .i32_load8_u,
        .data = .{ .payload = mem_arg_index },
    });

    // Compare the error value with '0'
    try self.addImm32(0);
    try self.addTag(Mir.Inst.Tag.fromOpcode(opcode));

    const is_null_tmp = try self.allocLocal(Type.initTag(.u8));
    try self.addLabel(.local_set, is_null_tmp.local);
    return is_null_tmp;
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const opt_ty = self.air.typeOf(ty_op.operand);

    // For pointers we simply return its stack address, rather than
    // loading its value
    if (opt_ty.zigTypeTag() == .Pointer) {
        return WValue{ .local_with_offset = .{ .local = operand.local, .offset = 1 } };
    }

    if (opt_ty.isPtrLikeOptional()) return operand;

    var buf: Type.Payload.ElemType = undefined;
    const child_ty = opt_ty.optionalChild(&buf);
    const offset = opt_ty.abiSize(self.target) - child_ty.abiSize(self.target);

    return self.load(operand, child_ty, @intCast(u32, offset));
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    _ = operand;
    return self.fail("TODO - wasm codegen for optional_payload_ptr_set", .{});
}

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);

    const op_ty = self.air.typeOf(ty_op.operand);
    const optional_ty = self.air.getRefType(ty_op.ty);
    const offset = optional_ty.abiSize(self.target) - op_ty.abiSize(self.target);

    return WValue{ .local_with_offset = .{
        .local = operand.local,
        .offset = @intCast(u32, offset),
    } };
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;

    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const pointer_width = self.target.cpu.arch.ptrBitWidth() / 8;

    return try self.load(operand, Type.usize, pointer_width);
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const slice_ty = self.air.typeOf(bin_op.lhs);
    const slice = self.resolveInst(bin_op.lhs);
    const index = self.resolveInst(bin_op.rhs);
    const elem_ty = slice_ty.childType();
    const elem_size = elem_ty.abiSize(self.target);

    // load pointer onto stack
    const slice_ptr = try self.load(slice, slice_ty, 0);
    try self.addLabel(.local_get, slice_ptr.local);

    // calculate index into slice
    try self.emitWValue(index);
    try self.addImm32(@bitCast(i32, @intCast(u32, elem_size)));
    try self.addTag(.i32_mul);
    try self.addTag(.i32_add);

    const result = try self.allocLocal(elem_ty);
    try self.addLabel(.local_set, result.local);
    return switch (elem_ty.zigTypeTag()) {
        // pass as pointer
        .Pointer, .Struct, .Optional => result,
        // pass by value
        else => try self.load(result, elem_ty, 0),
    };
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    return try self.load(operand, Type.usize, 0);
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) InnerError!WValue {
    if (self.liveness.isUnused(inst)) return WValue.none;
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = self.resolveInst(ty_op.operand);
    const op_ty = self.air.typeOf(ty_op.operand);
    const int_info = self.air.getRefType(ty_op.ty).intInfo(self.target);
    const wanted_bits = int_info.bits;
    const result = try self.allocLocal(self.air.getRefType(ty_op.ty));
    const op_bits = op_ty.intInfo(self.target).bits;

    const wasm_bits = toWasmIntBits(wanted_bits) orelse
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
