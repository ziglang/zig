//! SPARCv9 codegen.
//! This lowers AIR into MIR.
//! For now this only implements medium/low code model with absolute addressing.
//! TODO add support for other code models.
const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
const InternPool = @import("../../InternPool.zig");
const Value = @import("../../Value.zig");
const ErrorMsg = Zcu.ErrorMsg;
const codegen = @import("../../codegen.zig");
const Air = @import("../../Air.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Type = @import("../../Type.zig");
const CodeGenError = codegen.CodeGenError;
const Endian = std.builtin.Endian;
const Alignment = InternPool.Alignment;

const build_options = @import("build_options");

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;
const errUnionErrorOffset = codegen.errUnionErrorOffset;
const Instruction = bits.Instruction;
const ASI = Instruction.ASI;
const ShiftWidth = Instruction.ShiftWidth;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const Register = bits.Register;
const gp = abi.RegisterClass.gp;

const Self = @This();

const InnerError = CodeGenError || error{OutOfRegisters};

const RegisterView = enum(u1) {
    caller,
    callee,
};

gpa: Allocator,
pt: Zcu.PerThread,
air: Air,
liveness: Liveness,
bin_file: *link.File,
target: *const std.Target,
func_index: InternPool.Index,
code: *std.ArrayListUnmanaged(u8),
debug_output: link.File.DebugInfoOutput,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: MCValue,
fn_type: Type,
arg_index: usize,
src_loc: Zcu.LazySrcLoc,
stack_align: Alignment,

/// MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// MIR extra data
mir_extra: std.ArrayListUnmanaged(u32) = .empty,

/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,

/// The value is an offset into the `Function` `code` from the beginning.
/// To perform the reloc, write 32-bit signed little-endian integer
/// which is a relative jump, based on the address following the reloc.
exitlude_jump_relocs: std.ArrayListUnmanaged(usize) = .empty,

reused_operands: std.StaticBitSet(Liveness.bpi - 1) = undefined,

/// Whenever there is a runtime branch, we push a Branch onto this stack,
/// and pop it off when the runtime branch joins. This provides an "overlay"
/// of the table of mappings from instructions to `MCValue` from within the branch.
/// This way we can modify the `MCValue` for an instruction in different ways
/// within different branches. Special consideration is needed when a branch
/// joins with its parent, to make sure all instructions have the same MCValue
/// across each runtime branch upon joining.
branch_stack: *std.ArrayList(Branch),

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .empty,

register_manager: RegisterManager = .{},

/// Maps offset to what is stored there.
stack: std.AutoHashMapUnmanaged(u32, StackAllocation) = .empty,

/// Tracks the current instruction allocated to the condition flags
condition_flags_inst: ?Air.Inst.Index = null,

/// Tracks the current instruction allocated to the condition register
condition_register_inst: ?Air.Inst.Index = null,

/// Offset from the stack base, representing the end of the stack frame.
max_end_stack: u32 = 0,
/// Represents the current end stack offset. If there is no existing slot
/// to place a new stack allocation, it goes here, and then bumps `max_end_stack`.
next_stack_offset: u32 = 0,

/// Debug field, used to find bugs in the compiler.
air_bookkeeping: @TypeOf(air_bookkeeping_init) = air_bookkeeping_init,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const MCValue = union(enum) {
    /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
    /// TODO Look into deleting this tag and using `dead` instead, since every use
    /// of MCValue.none should be instead looking at the type and noticing it is 0 bits.
    none,
    /// Control flow will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    dead,
    /// The value is undefined.
    undef,
    /// A pointer-sized integer that fits in a register.
    /// If the type is a pointer, this is the pointer address in virtual address space.
    immediate: u64,
    /// The value is in a target-specific register.
    register: Register,
    /// The value is a tuple { wrapped, overflow } where
    /// wrapped is stored in the register and the overflow bit is
    /// stored in the C (signed) or V (unsigned) flag of the CCR.
    ///
    /// This MCValue is only generated by a add_with_overflow or
    /// sub_with_overflow instruction operating on 32- or 64-bit values.
    register_with_overflow: struct {
        reg: Register,
        flag: struct { cond: Instruction.ICondition, ccr: Instruction.CCR },
    },
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value is one of the stack variables.
    /// If the type is a pointer, it means the pointer address is in the stack at this offset.
    /// Note that this stores the plain value (i.e without the effects of the stack bias).
    /// Always convert this value into machine offsets with realStackOffset() before
    /// lowering into asm!
    stack_offset: u32,
    /// The value is a pointer to one of the stack variables (payload is stack offset).
    ptr_stack_offset: u32,
    /// The value is in the specified CCR. The value is 1 (if
    /// the type is u1) or true (if the type in bool) iff the
    /// specified condition is true.
    condition_flags: struct {
        cond: Instruction.Condition,
        ccr: Instruction.CCR,
    },
    /// The value is in the specified Register. The value is 1 (if
    /// the type is u1) or true (if the type in bool) iff the
    /// specified condition is true.
    condition_register: struct {
        cond: Instruction.RCondition,
        reg: Register,
    },

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .stack_offset => true,
            else => false,
        };
    }

    fn isImmediate(mcv: MCValue) bool {
        return switch (mcv) {
            .immediate => true,
            else => false,
        };
    }

    fn isMutable(mcv: MCValue) bool {
        return switch (mcv) {
            .none => unreachable,
            .unreach => unreachable,
            .dead => unreachable,

            .immediate,
            .memory,
            .condition_flags,
            .condition_register,
            .ptr_stack_offset,
            .undef,
            => false,

            .register,
            .stack_offset,
            => true,
        };
    }
};

const Branch = struct {
    inst_table: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, MCValue) = .empty,

    fn deinit(self: *Branch, gpa: Allocator) void {
        self.inst_table.deinit(gpa);
        self.* = undefined;
    }
};

const StackAllocation = struct {
    inst: Air.Inst.Index,
    /// TODO do we need size? should be determined by inst.ty.abiSize()
    size: u32,
};

const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index),
    /// The first break instruction encounters `null` here and chooses a
    /// machine code value for the block result, populating this field.
    /// Following break instructions encounter that value and use it for
    /// the location to store their block results.
    mcv: MCValue,
};

const CallMCValues = struct {
    args: []MCValue,
    return_value: MCValue,
    stack_byte_count: u32,
    stack_align: Alignment,

    fn deinit(self: *CallMCValues, func: *Self) void {
        func.gpa.free(self.args);
        self.* = undefined;
    }
};

const BigTomb = struct {
    function: *Self,
    inst: Air.Inst.Index,
    lbt: Liveness.BigTomb,

    fn feed(bt: *BigTomb, op_ref: Air.Inst.Ref) void {
        const dies = bt.lbt.feed();
        const op_index = op_ref.toIndex() orelse return;
        if (!dies) return;
        bt.function.processDeath(op_index);
    }

    fn finishAir(bt: *BigTomb, result: MCValue) void {
        const is_used = !bt.function.liveness.isUnused(bt.inst);
        if (is_used) {
            log.debug("%{d} => {}", .{ bt.inst, result });
            const branch = &bt.function.branch_stack.items[bt.function.branch_stack.items.len - 1];
            branch.inst_table.putAssumeCapacityNoClobber(bt.inst, result);
        }
        bt.function.finishAirBookkeeping();
    }
};

pub fn generate(
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) CodeGenError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);
    const func_ty = Type.fromInterned(func.ty);
    const file_scope = zcu.navFileScope(func.owner_nav);
    const target = &file_scope.mod.resolved_target.result;

    var branch_stack = std.ArrayList(Branch).init(gpa);
    defer {
        assert(branch_stack.items.len == 1);
        branch_stack.items[0].deinit(gpa);
        branch_stack.deinit();
    }
    try branch_stack.append(.{});

    var function: Self = .{
        .gpa = gpa,
        .pt = pt,
        .air = air,
        .liveness = liveness,
        .target = target,
        .bin_file = lf,
        .func_index = func_index,
        .code = code,
        .debug_output = debug_output,
        .err_msg = null,
        .args = undefined, // populated after `resolveCallingConventionValues`
        .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
        .fn_type = func_ty,
        .arg_index = 0,
        .branch_stack = &branch_stack,
        .src_loc = src_loc,
        .stack_align = undefined,
        .end_di_line = func.rbrace_line,
        .end_di_column = func.rbrace_column,
    };
    defer function.stack.deinit(gpa);
    defer function.blocks.deinit(gpa);
    defer function.exitlude_jump_relocs.deinit(gpa);

    var call_info = function.resolveCallingConventionValues(func_ty, .callee) catch |err| switch (err) {
        error.CodegenFail => return error.CodegenFail,
        else => |e| return e,
    };
    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.stack_align = call_info.stack_align;
    function.max_end_stack = call_info.stack_byte_count;

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return error.CodegenFail,
        error.OutOfRegisters => return function.fail("ran out of registers (Zig compiler bug)", .{}),
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(gpa),
    };
    defer mir.deinit(gpa);

    var emit: Emit = .{
        .mir = mir,
        .bin_file = lf,
        .debug_output = debug_output,
        .target = target,
        .src_loc = src_loc,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = func.lbrace_line,
        .prev_di_column = func.lbrace_column,
    };
    defer emit.deinit();

    emit.emitMir() catch |err| switch (err) {
        error.EmitFail => return function.failMsg(emit.err_msg.?),
        else => |e| return e,
    };
}

fn gen(self: *Self) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const cc = self.fn_type.fnCallingConvention(zcu);
    if (cc != .naked) {
        // TODO Finish function prologue and epilogue for sparc64.

        // save %sp, stack_reserved_area, %sp
        const save_inst = try self.addInst(.{
            .tag = .save,
            .data = .{
                .arithmetic_3op = .{
                    .is_imm = true,
                    .rd = .sp,
                    .rs1 = .sp,
                    .rs2_or_imm = .{ .imm = -abi.stack_reserved_area },
                },
            },
        });

        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .data = .{ .nop = {} },
        });

        try self.genBody(self.air.getMainBody());

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .data = .{ .nop = {} },
        });

        // exitlude jumps
        if (self.exitlude_jump_relocs.items.len > 0 and
            self.exitlude_jump_relocs.items[self.exitlude_jump_relocs.items.len - 1] == self.mir_instructions.len - 3)
        {
            // If the last Mir instruction (apart from the
            // dbg_epilogue_begin) is the last exitlude jump
            // relocation (which would just jump two instructions
            // further), it can be safely removed
            const index = self.exitlude_jump_relocs.pop().?;

            // First, remove the delay slot, then remove
            // the branch instruction itself.
            self.mir_instructions.orderedRemove(index + 1);
            self.mir_instructions.orderedRemove(index);
        }

        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.set(jmp_reloc, .{
                .tag = .bpcc,
                .data = .{
                    .branch_predict_int = .{
                        .ccr = .xcc,
                        .cond = .al,
                        .inst = @as(u32, @intCast(self.mir_instructions.len)),
                    },
                },
            });
        }

        // Backpatch stack offset
        const total_stack_size = self.max_end_stack + abi.stack_reserved_area;
        const stack_size = self.stack_align.forward(total_stack_size);
        if (math.cast(i13, stack_size)) |size| {
            self.mir_instructions.set(save_inst, .{
                .tag = .save,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = true,
                        .rd = .sp,
                        .rs1 = .sp,
                        .rs2_or_imm = .{ .imm = -size },
                    },
                },
            });
        } else {
            // TODO for large stacks, replace the prologue with:
            // setx stack_size, %g1
            // save %sp, %g1, %sp
            return self.fail("TODO SPARCv9: allow larger stacks", .{});
        }

        // return %i7 + 8
        _ = try self.addInst(.{
            .tag = .@"return",
            .data = .{
                .arithmetic_2op = .{
                    .is_imm = true,
                    .rs1 = .i7,
                    .rs2_or_imm = .{ .imm = 8 },
                },
            },
        });

        // Branches in SPARC have a delay slot, that is, the instruction
        // following it will unconditionally be executed.
        // See: Section 3.2.3 Control Transfer in SPARCv9 manual.
        // See also: https://arcb.csc.ncsu.edu/~mueller/codeopt/codeopt00/notes/delaybra.html
        // TODO Find a way to fill this delay slot
        // nop
        _ = try self.addInst(.{
            .tag = .nop,
            .data = .{ .nop = {} },
        });
    } else {
        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .data = .{ .nop = {} },
        });

        try self.genBody(self.air.getMainBody());

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .data = .{ .nop = {} },
        });
    }

    // Drop them off at the rbrace.
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .data = .{ .dbg_line_column = .{
            .line = self.end_di_line,
            .column = self.end_di_column,
        } },
    });
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        // TODO: remove now-redundant isUnused calls from AIR handler functions
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip))
            continue;

        const old_air_bookkeeping = self.air_bookkeeping;
        try self.ensureProcessDeathCapacity(Liveness.bpi);

        self.reused_operands = @TypeOf(self.reused_operands).initEmpty();
        switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .ptr_add => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub => try self.airPtrArithmetic(inst, .ptr_sub),

            .add             => try self.airBinOp(inst, .add),
            .add_wrap        => try self.airBinOp(inst, .add_wrap),
            .sub             => try self.airBinOp(inst, .sub),
            .sub_wrap        => try self.airBinOp(inst, .sub_wrap),
            .mul             => try self.airBinOp(inst, .mul),
            .mul_wrap        => try self.airBinOp(inst, .mul_wrap),
            .shl             => try self.airBinOp(inst, .shl),
            .shl_exact       => try self.airBinOp(inst, .shl_exact),
            .shr             => try self.airBinOp(inst, .shr),
            .shr_exact       => try self.airBinOp(inst, .shr_exact),
            .bool_and        => try self.airBinOp(inst, .bool_and),
            .bool_or         => try self.airBinOp(inst, .bool_or),
            .bit_and         => try self.airBinOp(inst, .bit_and),
            .bit_or          => try self.airBinOp(inst, .bit_or),
            .xor             => try self.airBinOp(inst, .xor),

            .add_sat         => try self.airAddSat(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul_sat         => try self.airMulSat(inst),
            .shl_sat         => try self.airShlSat(inst),
            .min, .max       => try self.airMinMax(inst),
            .rem             => try self.airRem(inst),
            .mod             => try self.airMod(inst),
            .slice           => try self.airSlice(inst),

            .sqrt,
            .sin,
            .cos,
            .tan,
            .exp,
            .exp2,
            .log,
            .log2,
            .log10,
            .abs,
            .floor,
            .ceil,
            .round,
            .trunc_float,
            .neg,
            => try self.airUnaryMath(inst),

            .add_with_overflow => try self.airAddSubWithOverflow(inst),
            .sub_with_overflow => try self.airAddSubWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airDiv(inst),

            .cmp_lt  => try self.airCmp(inst, .lt),
            .cmp_lte => try self.airCmp(inst, .lte),
            .cmp_eq  => try self.airCmp(inst, .eq),
            .cmp_gte => try self.airCmp(inst, .gte),
            .cmp_gt  => try self.airCmp(inst, .gt),
            .cmp_neq => try self.airCmp(inst, .neq),
            .cmp_vector => @panic("TODO try self.airCmpVector(inst)"),
            .cmp_lt_errors_len => try self.airCmpLtErrorsLen(inst),

            .alloc           => try self.airAlloc(inst),
            .ret_ptr         => try self.airRetPtr(inst),
            .arg             => try self.airArg(inst),
            .assembly        => try self.airAsm(inst),
            .bitcast         => try self.airBitCast(inst),
            .block           => try self.airBlock(inst),
            .br              => try self.airBr(inst),
            .repeat          => return self.fail("TODO implement `repeat`", .{}),
            .switch_dispatch => return self.fail("TODO implement `switch_dispatch`", .{}),
            .trap            => try self.airTrap(),
            .breakpoint      => try self.airBreakpoint(),
            .ret_addr        => @panic("TODO try self.airRetAddr(inst)"),
            .frame_addr      => @panic("TODO try self.airFrameAddress(inst)"),
            .cond_br         => try self.airCondBr(inst),
            .fptrunc         => @panic("TODO try self.airFptrunc(inst)"),
            .fpext           => @panic("TODO try self.airFpext(inst)"),
            .intcast         => try self.airIntCast(inst),
            .trunc           => try self.airTrunc(inst),
            .is_non_null     => try self.airIsNonNull(inst),
            .is_non_null_ptr => @panic("TODO try self.airIsNonNullPtr(inst)"),
            .is_null         => try self.airIsNull(inst),
            .is_null_ptr     => @panic("TODO try self.airIsNullPtr(inst)"),
            .is_non_err      => try self.airIsNonErr(inst),
            .is_non_err_ptr  => @panic("TODO try self.airIsNonErrPtr(inst)"),
            .is_err          => try self.airIsErr(inst),
            .is_err_ptr      => @panic("TODO try self.airIsErrPtr(inst)"),
            .load            => try self.airLoad(inst),
            .loop            => try self.airLoop(inst),
            .not             => try self.airNot(inst),
            .ret             => try self.airRet(inst),
            .ret_safe        => try self.airRet(inst), // TODO
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst, false),
            .store_safe      => try self.airStore(inst, true),
            .struct_field_ptr=> try self.airStructFieldPtr(inst),
            .struct_field_val=> try self.airStructFieldVal(inst),
            .array_to_slice  => try self.airArrayToSlice(inst),
            .float_from_int    => try self.airFloatFromInt(inst),
            .int_from_float    => try self.airIntFromFloat(inst),
            .cmpxchg_strong,
            .cmpxchg_weak,
            => try self.airCmpxchg(inst),
            .atomic_rmw      => try self.airAtomicRmw(inst),
            .atomic_load     => try self.airAtomicLoad(inst),
            .memcpy          => @panic("TODO try self.airMemcpy(inst)"),
            .memset          => try self.airMemset(inst, false),
            .memset_safe     => try self.airMemset(inst, true),
            .set_union_tag   => try self.airSetUnionTag(inst),
            .get_union_tag   => try self.airGetUnionTag(inst),
            .clz             => try self.airClz(inst),
            .ctz             => try self.airCtz(inst),
            .popcount        => try self.airPopcount(inst),
            .byte_swap       => try self.airByteSwap(inst),
            .bit_reverse     => try self.airBitReverse(inst),
            .tag_name        => try self.airTagName(inst),
            .error_name      => try self.airErrorName(inst),
            .splat           => try self.airSplat(inst),
            .select          => @panic("TODO try self.airSelect(inst)"),
            .shuffle         => @panic("TODO try self.airShuffle(inst)"),
            .reduce          => @panic("TODO try self.airReduce(inst)"),
            .aggregate_init  => try self.airAggregateInit(inst),
            .union_init      => try self.airUnionInit(inst),
            .prefetch        => try self.airPrefetch(inst),
            .mul_add         => @panic("TODO try self.airMulAdd(inst)"),
            .addrspace_cast  => @panic("TODO try self.airAddrSpaceCast(int)"),

            .@"try"          => try self.airTry(inst),
            .try_cold        => try self.airTry(inst),
            .try_ptr         => @panic("TODO try self.airTryPtr(inst)"),
            .try_ptr_cold    => @panic("TODO try self.airTryPtrCold(inst)"),

            .dbg_stmt         => try self.airDbgStmt(inst),
            .dbg_empty_stmt   => self.finishAirBookkeeping(),
            .dbg_inline_block => try self.airDbgInlineBlock(inst),
            .dbg_var_ptr,
            .dbg_var_val,
            .dbg_arg_inline,
            => try self.airDbgVar(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .atomic_store_unordered => @panic("TODO try self.airAtomicStore(inst, .unordered)"),
            .atomic_store_monotonic => @panic("TODO try self.airAtomicStore(inst, .monotonic)"),
            .atomic_store_release   => @panic("TODO try self.airAtomicStore(inst, .release)"),
            .atomic_store_seq_cst   => @panic("TODO try self.airAtomicStore(inst, .seq_cst)"),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .field_parent_ptr => @panic("TODO try self.airFieldParentPtr(inst)"),

            .switch_br       => try self.airSwitch(inst),
            .loop_switch_br  => return self.fail("TODO implement `loop_switch_br`", .{}),
            .slice_ptr       => try self.airSlicePtr(inst),
            .slice_len       => try self.airSliceLen(inst),

            .ptr_slice_len_ptr => try self.airPtrSliceLenPtr(inst),
            .ptr_slice_ptr_ptr => try self.airPtrSlicePtrPtr(inst),

            .array_elem_val      => try self.airArrayElemVal(inst),
            .slice_elem_val      => try self.airSliceElemVal(inst),
            .slice_elem_ptr      => @panic("TODO try self.airSliceElemPtr(inst)"),
            .ptr_elem_val        => try self.airPtrElemVal(inst),
            .ptr_elem_ptr        => try self.airPtrElemPtr(inst),

            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .unreach  => self.finishAirBookkeeping(),

            .optional_payload           => try self.airOptionalPayload(inst),
            .optional_payload_ptr       => try self.airOptionalPayloadPtr(inst),
            .optional_payload_ptr_set   => try self.airOptionalPayloadPtrSet(inst),
            .unwrap_errunion_err        => try self.airUnwrapErrErr(inst),
            .unwrap_errunion_payload    => try self.airUnwrapErrPayload(inst),
            .unwrap_errunion_err_ptr    => @panic("TODO try self.airUnwrapErrErrPtr(inst)"),
            .unwrap_errunion_payload_ptr=> @panic("TODO try self.airUnwrapErrPayloadPtr(inst)"),
            .errunion_payload_ptr_set   => try self.airErrUnionPayloadPtrSet(inst),
            .err_return_trace           => @panic("TODO try self.airErrReturnTrace(inst)"),
            .set_err_return_trace       => @panic("TODO try self.airSetErrReturnTrace(inst)"),
            .save_err_return_trace_index=> @panic("TODO try self.airSaveErrReturnTraceIndex(inst)"),

            .wrap_optional         => try self.airWrapOptional(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
            .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

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
            => @panic("TODO implement optimized float mode"),

            .add_safe,
            .sub_safe,
            .mul_safe,
            .intcast_safe,
            => @panic("TODO implement safety_checked_instructions"),

            .is_named_enum_value => @panic("TODO implement is_named_enum_value"),
            .error_set_has_value => @panic("TODO implement error_set_has_value"),
            .vector_store_elem => @panic("TODO implement vector_store_elem"),

            .c_va_arg => return self.fail("TODO implement c_va_arg", .{}),
            .c_va_copy => return self.fail("TODO implement c_va_copy", .{}),
            .c_va_end => return self.fail("TODO implement c_va_end", .{}),
            .c_va_start => return self.fail("TODO implement c_va_start", .{}),

            .wasm_memory_size => unreachable,
            .wasm_memory_grow => unreachable,

            .work_item_id => unreachable,
            .work_group_size => unreachable,
            .work_group_id => unreachable,
            // zig fmt: on
        }

        assert(!self.register_manager.lockedRegsExist());

        if (std.debug.runtime_safety) {
            if (self.air_bookkeeping < old_air_bookkeeping + 1) {
                std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, air_tags[@intFromEnum(inst)] });
            }
        }
    }
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const pt = self.pt;
    const zcu = pt.zcu;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        switch (lhs_ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO implement add_with_overflow/sub_with_overflow for vectors", .{}),
            .int => {
                assert(lhs_ty.eql(rhs_ty, zcu));
                const int_info = lhs_ty.intInfo(zcu);
                switch (int_info.bits) {
                    32, 64 => {
                        // Only say yes if the operation is
                        // commutative, i.e. we can swap both of the
                        // operands
                        const lhs_immediate_ok = switch (tag) {
                            .add_with_overflow => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .sub_with_overflow => false,
                            else => unreachable,
                        };
                        const rhs_immediate_ok = switch (tag) {
                            .add_with_overflow,
                            .sub_with_overflow,
                            => rhs == .immediate and rhs.immediate <= std.math.maxInt(u12),
                            else => unreachable,
                        };

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .add_with_overflow => .addcc,
                            .sub_with_overflow => .subcc,
                            else => unreachable,
                        };

                        try self.spillConditionFlagsIfOccupied();

                        const dest = blk: {
                            if (rhs_immediate_ok) {
                                break :blk try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, null);
                            } else if (lhs_immediate_ok) {
                                // swap lhs and rhs
                                break :blk try self.binOpImmediate(mir_tag, rhs, lhs, rhs_ty, true, null);
                            } else {
                                break :blk try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, null);
                            }
                        };

                        const cond = switch (int_info.signedness) {
                            .unsigned => switch (tag) {
                                .add_with_overflow => Instruction.ICondition.cs,
                                .sub_with_overflow => Instruction.ICondition.cc,
                                else => unreachable,
                            },
                            .signed => Instruction.ICondition.vs,
                        };

                        const ccr = switch (int_info.bits) {
                            32 => Instruction.CCR.icc,
                            64 => Instruction.CCR.xcc,
                            else => unreachable,
                        };

                        break :result MCValue{ .register_with_overflow = .{
                            .reg = dest.register,
                            .flag = .{ .cond = cond, .ccr = ccr },
                        } };
                    },
                    else => return self.fail("TODO overflow operations on other integer sizes", .{}),
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const vector_ty = self.typeOfIndex(inst);
    const len = vector_ty.vectorLen(zcu);
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const elements = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[ty_pl.payload..][0..len]));
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airAggregateInit for {}", .{self.target.cpu.arch});
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        @memcpy(buf[0..elements.len], elements);
        return self.finishAir(inst, result, buf);
    }
    var bt = try self.iterateBigTomb(inst, elements.len);
    for (elements) |elem| {
        bt.feed(elem);
    }
    return bt.finishAir(result);
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement array_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = self.typeOf(ty_op.operand);
        const ptr = try self.resolveInst(ty_op.operand);
        const array_ty = ptr_ty.childType(zcu);
        const array_len = @as(u32, @intCast(array_ty.arrayLen(zcu)));
        const ptr_bytes = 8;
        const stack_offset = try self.allocMem(inst, ptr_bytes * 2, .@"8");
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(Type.usize, stack_offset - ptr_bytes, .{ .immediate = array_len });
        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = (extra.data.flags & 0x80000000) != 0;
    const clobbers_len = @as(u31, @truncate(extra.data.flags));
    var extra_i: usize = extra.end;
    const outputs = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra_i .. extra_i + extra.data.outputs_len]));
    extra_i += outputs.len;
    const inputs = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra_i .. extra_i + extra.data.inputs_len]));
    extra_i += inputs.len;

    const dead = !is_volatile and self.liveness.isUnused(inst);
    const result: MCValue = if (dead) .dead else result: {
        if (outputs.len > 1) {
            return self.fail("TODO implement codegen for asm with more than 1 output", .{});
        }

        const output_constraint: ?[]const u8 = for (outputs) |output| {
            if (output != .none) {
                return self.fail("TODO implement codegen for non-expr asm", .{});
            }
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            break constraint;
        } else null;

        for (inputs) |input| {
            const input_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(input_bytes, 0);
            const name = std.mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            if (constraint.len < 3 or constraint[0] != '{' or constraint[constraint.len - 1] != '}') {
                return self.fail("unrecognized asm input constraint: '{s}'", .{constraint});
            }
            const reg_name = constraint[1 .. constraint.len - 1];
            const reg = parseRegName(reg_name) orelse
                return self.fail("unrecognized register: '{s}'", .{reg_name});

            const arg_mcv = try self.resolveInst(input);
            try self.register_manager.getReg(reg, null);
            try self.genSetReg(self.typeOf(input), reg, arg_mcv);
        }

        {
            var clobber_i: u32 = 0;
            while (clobber_i < clobbers_len) : (clobber_i += 1) {
                const clobber = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
                // This equation accounts for the fact that even if we have exactly 4 bytes
                // for the string, we still use the next u32 for the null terminator.
                extra_i += clobber.len / 4 + 1;

                // TODO honor these
            }
        }

        const asm_source = std.mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];

        if (mem.eql(u8, asm_source, "ta 0x6d")) {
            _ = try self.addInst(.{
                .tag = .tcc,
                .data = .{
                    .trap = .{
                        .is_imm = true,
                        .cond = .al,
                        .rs2_or_imm = .{ .imm = 0x6d },
                    },
                },
            });
        } else {
            return self.fail("TODO implement a full SPARCv9 assembly parsing", .{});
        }

        if (output_constraint) |output| {
            if (output.len < 4 or output[0] != '=' or output[1] != '{' or output[output.len - 1] != '}') {
                return self.fail("unrecognized asm output constraint: '{s}'", .{output});
            }
            const reg_name = output[2 .. output.len - 1];
            const reg = parseRegName(reg_name) orelse
                return self.fail("unrecognized register: '{s}'", .{reg_name});
            break :result MCValue{ .register = reg };
        } else {
            break :result MCValue{ .none = {} };
        }
    };

    simple: {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        var buf_index: usize = 0;
        for (outputs) |output| {
            if (output == .none) continue;

            if (buf_index >= buf.len) break :simple;
            buf[buf_index] = output;
            buf_index += 1;
        }
        if (buf_index + inputs.len > buf.len) break :simple;
        @memcpy(buf[buf_index..][0..inputs.len], inputs);
        return self.finishAir(inst, result, buf);
    }

    var bt = try self.iterateBigTomb(inst, outputs.len + inputs.len);
    for (outputs) |output| {
        if (output == .none) continue;

        bt.feed(output);
    }
    for (inputs) |input| {
        bt.feed(input);
    }
    return bt.finishAir(result);
}

fn airArg(self: *Self, inst: Air.Inst.Index) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.typeOfIndex(inst);

    const arg = self.args[arg_index];
    const mcv = blk: {
        switch (arg) {
            .stack_offset => |off| {
                const abi_size = math.cast(u32, ty.abiSize(zcu)) orelse {
                    return self.fail("type '{}' too big to fit into stack frame", .{ty.fmt(pt)});
                };
                const offset = off + abi_size;
                break :blk MCValue{ .stack_offset = offset };
            },
            else => break :blk arg,
        }
    };

    self.genArgDbgInfo(inst, mcv) catch |err|
        return self.fail("failed to generate debug info for parameter: {s}", .{@errorName(err)});

    if (self.liveness.isUnused(inst))
        return self.finishAirBookkeeping();

    switch (mcv) {
        .register => |reg| {
            self.register_manager.getRegAssumeFree(reg, inst);
        },
        else => {},
    }

    return self.finishAir(inst, mcv, .{ .none, .none, .none });
}

fn airAtomicLoad(self: *Self, inst: Air.Inst.Index) !void {
    _ = self.air.instructions.items(.data)[@intFromEnum(inst)].atomic_load;

    return self.fail("TODO implement airAtomicLoad for {}", .{
        self.target.cpu.arch,
    });
}

fn airAtomicRmw(self: *Self, inst: Air.Inst.Index) !void {
    _ = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;

    return self.fail("TODO implement airAtomicRmw for {}", .{
        self.target.cpu.arch,
    });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.binOp(tag, lhs, rhs, lhs_ty, rhs_ty, BinOpMetadata{
            .lhs = bin_op.lhs,
            .rhs = bin_op.rhs,
            .inst = inst,
        });
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.binOp(tag, lhs, rhs, lhs_ty, rhs_ty, BinOpMetadata{
            .lhs = bin_op.lhs,
            .rhs = bin_op.rhs,
            .inst = inst,
        });
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, operand)) break :result operand;

        const operand_lock = switch (operand) {
            .register => |reg| self.register_manager.lockReg(reg),
            .register_with_overflow => |rwo| self.register_manager.lockReg(rwo.reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dest = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(self.typeOfIndex(inst), dest, operand);
        break :result dest;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(self: *Self, inst: Air.Inst.Index, body: []const Air.Inst.Index) !void {
    try self.blocks.putNoClobber(self.gpa, inst, .{
        // A block is a setup to be able to jump to the end.
        .relocs = .{},
        // It also acts as a receptacle for break operands.
        // Here we use `MCValue.none` to represent a null value so that the first
        // break instruction will choose a MCValue for the block result and overwrite
        // this field. Following break instructions will use that MCValue to put their
        // block results.
        .mcv = MCValue{ .none = {} },
    });
    defer self.blocks.getPtr(inst).?.relocs.deinit(self.gpa);

    // TODO emit debug info lexical block
    try self.genBody(body);

    // relocations for `bpcc` instructions
    const relocs = &self.blocks.getPtr(inst).?.relocs;
    if (relocs.items.len > 0 and relocs.items[relocs.items.len - 1] == self.mir_instructions.len - 1) {
        // If the last Mir instruction is the last relocation (which
        // would just jump two instruction further), it can be safely
        // removed
        const index = relocs.pop().?;

        // First, remove the delay slot, then remove
        // the branch instruction itself.
        self.mir_instructions.orderedRemove(index + 1);
        self.mir_instructions.orderedRemove(index);
    }
    for (relocs.items) |reloc| {
        try self.performReloc(reloc);
    }

    const result = self.blocks.getPtr(inst).?.mcv;
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const branch = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn airTrap(self: *Self) !void {
    // ta 0x05
    _ = try self.addInst(.{
        .tag = .tcc,
        .data = .{
            .trap = .{
                .is_imm = true,
                .cond = .al,
                .rs2_or_imm = .{ .imm = 0x05 },
            },
        },
    });
    return self.finishAirBookkeeping();
}

fn airBreakpoint(self: *Self) !void {
    // ta 0x01
    _ = try self.addInst(.{
        .tag = .tcc,
        .data = .{
            .trap = .{
                .is_imm = true,
                .cond = .al,
                .rs2_or_imm = .{ .imm = 0x01 },
            },
        },
    });
    return self.finishAirBookkeeping();
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    // We have hardware byteswapper in SPARCv9, don't let mainstream compilers mislead you.
    // That being said, the strategy to lower this is:
    // - If src is an immediate, comptime-swap it.
    // - If src is in memory then issue an LD*A with #ASI_P_[oppposite-endian]
    // - If src is a register then issue an ST*A with #ASI_P_[oppposite-endian]
    //   to a stack slot, then follow with a normal load from said stack slot.
    //   This is because on some implementations, ASI-tagged memory operations are non-piplelinable
    //   and loads tend to have longer latency than stores, so the sequence will minimize stall.
    // The result will always be either another immediate or stored in a register.
    // TODO: Fold byteswap+store into a single ST*A and load+byteswap into a single LD*A.
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        switch (operand_ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO byteswap for vectors", .{}),
            .int => {
                const int_info = operand_ty.intInfo(zcu);
                if (int_info.bits == 8) break :result operand;

                const abi_size = int_info.bits >> 3;
                const abi_align = operand_ty.abiAlignment(zcu);
                const opposite_endian_asi = switch (self.target.cpu.arch.endian()) {
                    Endian.big => ASI.asi_primary_little,
                    Endian.little => ASI.asi_primary,
                };

                switch (operand) {
                    .immediate => |imm| {
                        const swapped = switch (int_info.bits) {
                            16 => @byteSwap(@as(u16, @intCast(imm))),
                            24 => @byteSwap(@as(u24, @intCast(imm))),
                            32 => @byteSwap(@as(u32, @intCast(imm))),
                            40 => @byteSwap(@as(u40, @intCast(imm))),
                            48 => @byteSwap(@as(u48, @intCast(imm))),
                            56 => @byteSwap(@as(u56, @intCast(imm))),
                            64 => @byteSwap(@as(u64, @intCast(imm))),
                            else => return self.fail("TODO synthesize SPARCv9 byteswap for other integer sizes", .{}),
                        };
                        break :result .{ .immediate = swapped };
                    },
                    .register => |reg| {
                        if (int_info.bits > 64 or @popCount(int_info.bits) != 1)
                            return self.fail("TODO synthesize SPARCv9 byteswap for other integer sizes", .{});

                        const off = try self.allocMem(inst, abi_size, abi_align);
                        const off_reg = try self.copyToTmpRegister(operand_ty, .{ .immediate = realStackOffset(off) });

                        try self.genStoreASI(reg, .sp, off_reg, abi_size, opposite_endian_asi);
                        try self.genLoad(reg, .sp, Register, off_reg, abi_size);
                        break :result .{ .register = reg };
                    },
                    .memory => {
                        if (int_info.bits > 64 or @popCount(int_info.bits) != 1)
                            return self.fail("TODO synthesize SPARCv9 byteswap for other integer sizes", .{});

                        const addr_reg = try self.copyToTmpRegister(operand_ty, operand);
                        const dst_reg = try self.register_manager.allocReg(null, gp);

                        try self.genLoadASI(dst_reg, addr_reg, .g0, abi_size, opposite_endian_asi);
                        break :result .{ .register = dst_reg };
                    },
                    .stack_offset => |off| {
                        if (int_info.bits > 64 or @popCount(int_info.bits) != 1)
                            return self.fail("TODO synthesize SPARCv9 byteswap for other integer sizes", .{});

                        const off_reg = try self.copyToTmpRegister(operand_ty, .{ .immediate = realStackOffset(off) });
                        const dst_reg = try self.register_manager.allocReg(null, gp);

                        try self.genLoadASI(dst_reg, .sp, off_reg, abi_size, opposite_endian_asi);
                        break :result .{ .register = dst_reg };
                    },
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for {}", .{self.target.cpu.arch});

    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @as([]const Air.Inst.Ref, @ptrCast(self.air.extra[extra.end .. extra.end + extra.data.args_len]));
    const ty = self.typeOf(callee);
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const fn_ty = switch (ty.zigTypeTag(zcu)) {
        .@"fn" => ty,
        .pointer => ty.childType(zcu),
        else => unreachable,
    };

    var info = try self.resolveCallingConventionValues(fn_ty, .caller);
    defer info.deinit(self);

    // CCR is volatile across function calls
    // (SCD 2.4.1, page 3P-10)
    try self.spillConditionFlagsIfOccupied();

    // Save caller-saved registers, but crucially *after* we save the
    // compare flags as saving compare flags may require a new
    // caller-saved register
    for (abi.caller_preserved_regs) |reg| {
        try self.register_manager.getReg(reg, null);
    }

    for (info.args, 0..) |mc_arg, arg_i| {
        const arg = args[arg_i];
        const arg_ty = self.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);

        switch (mc_arg) {
            .none => continue,
            .register => |reg| {
                try self.register_manager.getReg(reg, null);
                try self.genSetReg(arg_ty, reg, arg_mcv);
            },
            .stack_offset => {
                return self.fail("TODO implement calling with parameters in memory", .{});
            },
            .ptr_stack_offset => {
                return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
            },
            else => unreachable,
        }
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (try self.air.value(callee, pt)) |func_value| switch (ip.indexToKey(func_value.toIntern())) {
        .func => {
            return self.fail("TODO implement calling functions", .{});
        },
        .@"extern" => {
            return self.fail("TODO implement calling extern functions", .{});
        },
        else => {
            return self.fail("TODO implement calling bitcasted functions", .{});
        },
    } else {
        assert(ty.zigTypeTag(zcu) == .pointer);
        const mcv = try self.resolveInst(callee);
        try self.genSetReg(ty, .o7, mcv);

        _ = try self.addInst(.{
            .tag = .jmpl,
            .data = .{
                .arithmetic_3op = .{
                    .is_imm = false,
                    .rd = .o7,
                    .rs1 = .o7,
                    .rs2_or_imm = .{ .rs2 = .g0 },
                },
            },
        });

        // TODO Find a way to fill this delay slot
        _ = try self.addInst(.{
            .tag = .nop,
            .data = .{ .nop = {} },
        });
    }

    const result = info.return_value;

    if (args.len + 1 <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        buf[0] = callee;
        @memcpy(buf[1..][0..args.len], args);
        return self.finishAir(inst, result, buf);
    }

    var bt = try self.iterateBigTomb(inst, 1 + args.len);
    bt.feed(callee);
    for (args) |arg| {
        bt.feed(arg);
    }
    return bt.finishAir(result);
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const pt = self.pt;
    const zcu = pt.zcu;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);

        const int_ty = switch (lhs_ty.zigTypeTag(zcu)) {
            .vector => unreachable, // Handled by cmp_vector.
            .@"enum" => lhs_ty.intTagType(zcu),
            .int => lhs_ty,
            .bool => Type.u1,
            .pointer => Type.usize,
            .error_set => Type.u16,
            .optional => blk: {
                const payload_ty = lhs_ty.optionalChild(zcu);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    break :blk Type.u1;
                } else if (lhs_ty.isPtrLikeOptional(zcu)) {
                    break :blk Type.usize;
                } else {
                    return self.fail("TODO SPARCv9 cmp non-pointer optionals", .{});
                }
            },
            .float => return self.fail("TODO SPARCv9 cmp floats", .{}),
            else => unreachable,
        };

        const int_info = int_ty.intInfo(zcu);
        if (int_info.bits <= 64) {
            _ = try self.binOp(.cmp_eq, lhs, rhs, int_ty, int_ty, BinOpMetadata{
                .lhs = bin_op.lhs,
                .rhs = bin_op.rhs,
                .inst = inst,
            });

            try self.spillConditionFlagsIfOccupied();
            self.condition_flags_inst = inst;

            break :result switch (int_info.signedness) {
                .signed => MCValue{ .condition_flags = .{
                    .cond = .{ .icond = Instruction.ICondition.fromCompareOperatorSigned(op) },
                    .ccr = .xcc,
                } },
                .unsigned => MCValue{ .condition_flags = .{
                    .cond = .{ .icond = Instruction.ICondition.fromCompareOperatorUnsigned(op) },
                    .ccr = .xcc,
                } },
            };
        } else {
            return self.fail("TODO SPARCv9 cmp for ints > 64 bits", .{});
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    _ = operand;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCmpLtErrorsLen for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    _ = extra;

    return self.fail("TODO implement airCmpxchg for {}", .{
        self.target.cpu.arch,
    });
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_condbr = self.liveness.getCondBr(inst);

    // Here we emit a branch to the false section.
    const reloc: Mir.Inst.Index = try self.condBr(condition);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (pl_op.operand.toIndex()) |op_index| {
            self.processDeath(op_index);
        }
    }

    // Capture the state of register and stack allocation state so that we can revert to it.
    const parent_next_stack_offset = self.next_stack_offset;
    const parent_free_registers = self.register_manager.free_registers;
    var parent_stack = try self.stack.clone(self.gpa);
    defer parent_stack.deinit(self.gpa);
    const parent_registers = self.register_manager.registers;
    const parent_condition_flags_inst = self.condition_flags_inst;

    try self.branch_stack.append(.{});
    errdefer {
        _ = self.branch_stack.pop().?;
    }

    try self.ensureProcessDeathCapacity(liveness_condbr.then_deaths.len);
    for (liveness_condbr.then_deaths) |operand| {
        self.processDeath(operand);
    }
    try self.genBody(then_body);

    // Revert to the previous register and stack allocation state.

    var saved_then_branch = self.branch_stack.pop().?;
    defer saved_then_branch.deinit(self.gpa);

    self.register_manager.registers = parent_registers;
    self.condition_flags_inst = parent_condition_flags_inst;

    self.stack.deinit(self.gpa);
    self.stack = parent_stack;
    parent_stack = .{};

    self.next_stack_offset = parent_next_stack_offset;
    self.register_manager.free_registers = parent_free_registers;

    try self.performReloc(reloc);
    const else_branch = self.branch_stack.addOneAssumeCapacity();
    else_branch.* = .{};

    try self.ensureProcessDeathCapacity(liveness_condbr.else_deaths.len);
    for (liveness_condbr.else_deaths) |operand| {
        self.processDeath(operand);
    }
    try self.genBody(else_body);

    // At this point, each branch will possibly have conflicting values for where
    // each instruction is stored. They agree, however, on which instructions are alive/dead.
    // We use the first ("then") branch as canonical, and here emit
    // instructions into the second ("else") branch to make it conform.
    // We continue respect the data structure semantic guarantees of the else_branch so
    // that we can use all the code emitting abstractions. This is why at the bottom we
    // assert that parent_branch.free_registers equals the saved_then_branch.free_registers
    // rather than assigning it.
    const parent_branch = &self.branch_stack.items[self.branch_stack.items.len - 2];
    try parent_branch.inst_table.ensureUnusedCapacity(self.gpa, else_branch.inst_table.count());

    const else_slice = else_branch.inst_table.entries.slice();
    const else_keys = else_slice.items(.key);
    const else_values = else_slice.items(.value);
    for (else_keys, 0..) |else_key, else_idx| {
        const else_value = else_values[else_idx];
        const canon_mcv = if (saved_then_branch.inst_table.fetchSwapRemove(else_key)) |then_entry| blk: {
            // The instruction's MCValue is overridden in both branches.
            log.debug("condBr put branch table (key = %{d}, value = {})", .{ else_key, then_entry.value });
            parent_branch.inst_table.putAssumeCapacity(else_key, then_entry.value);
            if (else_value == .dead) {
                assert(then_entry.value == .dead);
                continue;
            }
            break :blk then_entry.value;
        } else blk: {
            if (else_value == .dead)
                continue;
            // The instruction is only overridden in the else branch.
            var i: usize = self.branch_stack.items.len - 2;
            while (true) {
                i -= 1; // If this overflows, the question is: why wasn't the instruction marked dead?
                if (self.branch_stack.items[i].inst_table.get(else_key)) |mcv| {
                    assert(mcv != .dead);
                    break :blk mcv;
                }
            }
        };
        log.debug("consolidating else_entry {d} {}=>{}", .{ else_key, else_value, canon_mcv });
        // TODO make sure the destination stack offset / register does not already have something
        // going on there.
        try self.setRegOrMem(self.typeOfIndex(else_key), canon_mcv, else_value);
        // TODO track the new register / stack allocation
    }
    try parent_branch.inst_table.ensureUnusedCapacity(self.gpa, saved_then_branch.inst_table.count());
    const then_slice = saved_then_branch.inst_table.entries.slice();
    const then_keys = then_slice.items(.key);
    const then_values = then_slice.items(.value);
    for (then_keys, 0..) |then_key, then_idx| {
        const then_value = then_values[then_idx];
        // We already deleted the items from this table that matched the else_branch.
        // So these are all instructions that are only overridden in the then branch.
        parent_branch.inst_table.putAssumeCapacity(then_key, then_value);
        if (then_value == .dead)
            continue;
        const parent_mcv = blk: {
            var i: usize = self.branch_stack.items.len - 2;
            while (true) {
                i -= 1;
                if (self.branch_stack.items[i].inst_table.get(then_key)) |mcv| {
                    assert(mcv != .dead);
                    break :blk mcv;
                }
            }
        };
        log.debug("consolidating then_entry {d} {}=>{}", .{ then_key, parent_mcv, then_value });
        // TODO make sure the destination stack offset / register does not already have something
        // going on there.
        try self.setRegOrMem(self.typeOfIndex(then_key), parent_mcv, then_value);
        // TODO track the new register / stack allocation
    }

    {
        var item = self.branch_stack.pop().?;
        item.deinit(self.gpa);
    }

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airDbgInlineBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    // TODO emit debug info for function change
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;

    _ = try self.addInst(.{
        .tag = .dbg_line,
        .data = .{
            .dbg_line_column = .{
                .line = dbg_stmt.line,
                .column = dbg_stmt.column,
            },
        },
    });

    return self.finishAirBookkeeping();
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const name: Air.NullTerminatedString = @enumFromInt(pl_op.payload);
    const operand = pl_op.operand;
    // TODO emit debug info for this variable
    _ = name;
    return self.finishAir(inst, .dead, .{ operand, .none, .none });
}

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .errunion_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airIntFromFloat for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const pt = self.pt;
    const zcu = pt.zcu;
    const operand_ty = self.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const info_a = operand_ty.intInfo(zcu);
    const info_b = self.typeOfIndex(inst).intInfo(zcu);
    if (info_a.signedness != info_b.signedness)
        return self.fail("TODO gen intcast sign safety in semantic analysis", .{});

    if (info_a.bits == info_b.bits)
        return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });

    return self.fail("TODO implement intCast for {}", .{self.target.cpu.arch});
}

fn airFloatFromInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFloatFromInt for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.typeOf(un_op);
        break :result try self.isErr(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.typeOf(un_op);
        break :result try self.isNonErr(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const elem_ty = self.typeOfIndex(inst);
    const elem_size = elem_ty.abiSize(zcu);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBits(zcu))
            break :result MCValue.none;

        const ptr = try self.resolveInst(ty_op.operand);
        const is_volatile = self.typeOf(ty_op.operand).isVolatilePtr(zcu);
        if (self.liveness.isUnused(inst) and !is_volatile)
            break :result MCValue.dead;

        const dst_mcv: MCValue = blk: {
            if (elem_size <= 8 and self.reuseOperand(inst, ty_op.operand, 0, ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk switch (ptr) {
                    .register => |r| MCValue{ .register = r },
                    else => ptr,
                };
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(dst_mcv, ptr, self.typeOf(ty_op.operand));
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end .. loop.end + loop.data.body_len]);
    const start = @as(u32, @intCast(self.mir_instructions.len));

    try self.genBody(body);
    try self.jump(start);

    return self.finishAirBookkeeping();
}

fn airMemset(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload);

    const operand = pl_op.operand;
    const value = extra.data.lhs;
    const length = extra.data.rhs;
    _ = operand;
    _ = value;
    _ = length;

    return self.fail("TODO implement airMemset for {}", .{self.target.cpu.arch});
}

fn airMinMax(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.minMax(tag, lhs, rhs, lhs_ty, rhs_ty);

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);
    assert(lhs_ty.eql(rhs_ty, self.pt.zcu));

    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });

    // TODO add safety check

    // We use manual assembly emission to generate faster code
    // First, ensure lhs, rhs, rem, and added are in registers

    const lhs_is_register = lhs == .register;
    const rhs_is_register = rhs == .register;

    const lhs_reg = if (lhs_is_register)
        lhs.register
    else
        try self.register_manager.allocReg(null, gp);

    const lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_reg = if (rhs_is_register)
        rhs.register
    else
        try self.register_manager.allocReg(null, gp);
    const rhs_lock = self.register_manager.lockReg(rhs_reg);
    defer if (rhs_lock) |reg| self.register_manager.unlockReg(reg);

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);
    if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

    const regs = try self.register_manager.allocRegs(2, .{ null, null }, gp);
    const regs_locks = self.register_manager.lockRegsAssumeUnused(2, regs);
    defer for (regs_locks) |reg| {
        self.register_manager.unlockReg(reg);
    };

    const add_reg = regs[0];
    const mod_reg = regs[1];

    // mod_reg = @rem(lhs_reg, rhs_reg)
    _ = try self.addInst(.{
        .tag = .sdivx,
        .data = .{
            .arithmetic_3op = .{
                .is_imm = false,
                .rd = mod_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
    });

    _ = try self.addInst(.{
        .tag = .mulx,
        .data = .{
            .arithmetic_3op = .{
                .is_imm = false,
                .rd = mod_reg,
                .rs1 = mod_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
    });

    _ = try self.addInst(.{
        .tag = .sub,
        .data = .{
            .arithmetic_3op = .{
                .is_imm = false,
                .rd = mod_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = mod_reg },
            },
        },
    });

    // add_reg = mod_reg + rhs_reg
    _ = try self.addInst(.{
        .tag = .add,
        .data = .{
            .arithmetic_3op = .{
                .is_imm = false,
                .rd = add_reg,
                .rs1 = mod_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
    });

    // if (add_reg == rhs_reg) add_reg = 0
    _ = try self.addInst(.{
        .tag = .cmp,
        .data = .{
            .arithmetic_2op = .{
                .is_imm = false,
                .rs1 = add_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
    });

    _ = try self.addInst(.{
        .tag = .movcc,
        .data = .{
            .conditional_move_int = .{
                .is_imm = true,
                .ccr = .xcc,
                .cond = .{ .icond = .eq },
                .rd = add_reg,
                .rs2_or_imm = .{ .imm = 0 },
            },
        },
    });

    // if (lhs_reg < 0) mod_reg = add_reg
    _ = try self.addInst(.{
        .tag = .movr,
        .data = .{
            .conditional_move_reg = .{
                .is_imm = false,
                .cond = .lt_zero,
                .rd = mod_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = add_reg },
            },
        },
    });

    return self.finishAir(inst, .{ .register = mod_reg }, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    //const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const pt = self.pt;
    const zcu = pt.zcu;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        switch (lhs_ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO implement mul_with_overflow for vectors", .{}),
            .int => {
                assert(lhs_ty.eql(rhs_ty, zcu));
                const int_info = lhs_ty.intInfo(zcu);
                switch (int_info.bits) {
                    1...32 => {
                        try self.spillConditionFlagsIfOccupied();

                        const dest = try self.binOp(.mul, lhs, rhs, lhs_ty, rhs_ty, null);

                        const dest_reg = dest.register;
                        const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                        defer self.register_manager.unlockReg(dest_reg_lock);

                        const truncated_reg = try self.register_manager.allocReg(null, gp);
                        const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                        defer self.register_manager.unlockReg(truncated_reg_lock);

                        try self.truncRegister(
                            dest_reg,
                            truncated_reg,
                            int_info.signedness,
                            int_info.bits,
                        );

                        _ = try self.addInst(.{
                            .tag = .cmp,
                            .data = .{ .arithmetic_2op = .{
                                .is_imm = false,
                                .rs1 = dest_reg,
                                .rs2_or_imm = .{ .rs2 = truncated_reg },
                            } },
                        });

                        const cond = Instruction.ICondition.ne;
                        const ccr = Instruction.CCR.xcc;

                        break :result MCValue{ .register_with_overflow = .{
                            .reg = truncated_reg,
                            .flag = .{ .cond = cond, .ccr = ccr },
                        } };
                    },
                    // XXX DO NOT call __multi3 directly as it'll result in us doing six multiplications,
                    // which is far more than strictly necessary
                    33...64 => return self.fail("TODO copy compiler-rt's mulddi3 for a 64x64->128 multiply", .{}),
                    else => return self.fail("TODO overflow operations on other integer sizes", .{}),
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const pt = self.pt;
    const zcu = pt.zcu;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);
        switch (operand) {
            .dead => unreachable,
            .unreach => unreachable,
            .condition_flags => |op| {
                break :result MCValue{
                    .condition_flags = .{
                        .cond = op.cond.negate(),
                        .ccr = op.ccr,
                    },
                };
            },
            else => {
                switch (operand_ty.zigTypeTag(zcu)) {
                    .bool => {
                        const op_reg = switch (operand) {
                            .register => |r| r,
                            else => try self.copyToTmpRegister(operand_ty, operand),
                        };
                        const reg_lock = self.register_manager.lockRegAssumeUnused(op_reg);
                        defer self.register_manager.unlockReg(reg_lock);

                        const dest_reg = blk: {
                            if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                                break :blk op_reg;
                            }

                            const reg = try self.register_manager.allocReg(null, gp);
                            break :blk reg;
                        };

                        _ = try self.addInst(.{
                            .tag = .xor,
                            .data = .{
                                .arithmetic_3op = .{
                                    .is_imm = true,
                                    .rd = dest_reg,
                                    .rs1 = op_reg,
                                    .rs2_or_imm = .{ .imm = 1 },
                                },
                            },
                        });

                        break :result MCValue{ .register = dest_reg };
                    },
                    .vector => return self.fail("TODO bitwise not for vectors", .{}),
                    .int => {
                        const int_info = operand_ty.intInfo(zcu);
                        if (int_info.bits <= 64) {
                            const op_reg = switch (operand) {
                                .register => |r| r,
                                else => try self.copyToTmpRegister(operand_ty, operand),
                            };
                            const reg_lock = self.register_manager.lockRegAssumeUnused(op_reg);
                            defer self.register_manager.unlockReg(reg_lock);

                            const dest_reg = blk: {
                                if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                                    break :blk op_reg;
                                }

                                const reg = try self.register_manager.allocReg(null, gp);
                                break :blk reg;
                            };

                            _ = try self.addInst(.{
                                .tag = .not,
                                .data = .{
                                    .arithmetic_2op = .{
                                        .is_imm = false,
                                        .rs1 = dest_reg,
                                        .rs2_or_imm = .{ .rs2 = op_reg },
                                    },
                                },
                            });

                            try self.truncRegister(dest_reg, dest_reg, int_info.signedness, int_info.bits);

                            break :result MCValue{ .register = dest_reg };
                        } else {
                            return self.fail("TODO sparc64 not on integers > u64/i64", .{});
                        }
                    },
                    else => unreachable,
                }
            },
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    // TODO Emit a PREFETCH/IPREFETCH as necessary, see A.7 and A.42
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_bits = self.target.ptrBitWidth();
        const ptr_bytes = @divExact(ptr_bits, 8);
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach, .none => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off - ptr_bytes };
            },
            else => return self.fail("TODO implement ptr_slice_len_ptr for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach, .none => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off };
            },
            else => return self.fail("TODO implement ptr_slice_len_ptr for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    // TODO add safety check

    // result = lhs - @divTrunc(lhs, rhs) * rhs
    const result: MCValue = if (self.liveness.isUnused(inst)) blk: {
        break :blk .dead;
    } else blk: {
        const tmp0 = try self.binOp(.div_trunc, lhs, rhs, lhs_ty, rhs_ty, null);
        const tmp1 = try self.binOp(.mul, tmp0, rhs, lhs_ty, rhs_ty, null);
        break :blk try self.binOp(.sub, lhs, tmp1, lhs_ty, rhs_ty, null);
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRet(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    try self.ret(operand);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ptr = try self.resolveInst(un_op);
    _ = ptr;
    return self.fail("TODO implement airRetLoad for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    _ = bin_op;
    return self.fail("TODO implement airSetUnionTag for {}", .{self.target.cpu.arch});
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const pt = self.pt;
    const zcu = pt.zcu;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        switch (lhs_ty.zigTypeTag(zcu)) {
            .vector => return self.fail("TODO implement mul_with_overflow for vectors", .{}),
            .int => {
                const int_info = lhs_ty.intInfo(zcu);
                if (int_info.bits <= 64) {
                    try self.spillConditionFlagsIfOccupied();

                    const lhs_lock: ?RegisterLock = if (lhs == .register)
                        self.register_manager.lockRegAssumeUnused(lhs.register)
                    else
                        null;
                    // TODO this currently crashes stage1
                    // defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

                    // Increase shift amount (i.e, rhs) by shamt_bits - int_info.bits
                    // e.g if shifting a i48 then use sr*x (shamt_bits == 64) but increase rhs by 16
                    // and if shifting a i24 then use sr*  (shamt_bits == 32) but increase rhs by 8
                    const new_rhs = switch (int_info.bits) {
                        1...31 => if (rhs == .immediate) MCValue{
                            .immediate = rhs.immediate + 32 - int_info.bits,
                        } else try self.binOp(.add, rhs, .{ .immediate = 32 - int_info.bits }, rhs_ty, rhs_ty, null),
                        33...63 => if (rhs == .immediate) MCValue{
                            .immediate = rhs.immediate + 64 - int_info.bits,
                        } else try self.binOp(.add, rhs, .{ .immediate = 64 - int_info.bits }, rhs_ty, rhs_ty, null),
                        32, 64 => rhs,
                        else => unreachable,
                    };

                    const new_rhs_lock: ?RegisterLock = if (new_rhs == .register)
                        self.register_manager.lockRegAssumeUnused(new_rhs.register)
                    else
                        null;
                    // TODO this currently crashes stage1
                    // defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

                    const dest = try self.binOp(.shl, lhs, new_rhs, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_reg_lock);

                    const shr = try self.binOp(.shr, dest, new_rhs, lhs_ty, rhs_ty, null);

                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .arithmetic_2op = .{
                            .is_imm = false,
                            .rs1 = dest_reg,
                            .rs2_or_imm = .{ .rs2 = shr.register },
                        } },
                    });

                    const cond = Instruction.ICondition.ne;
                    const ccr = switch (int_info.bits) {
                        1...32 => Instruction.CCR.icc,
                        33...64 => Instruction.CCR.xcc,
                        else => unreachable,
                    };

                    // TODO Those should really be written as defers, however stage1 currently
                    // panics when those are turned into defer statements so those are
                    // written here at the end as ordinary statements.
                    // Because of that, on failure, the lock on those registers wouldn't be
                    // released.
                    if (lhs_lock) |reg| self.register_manager.unlockReg(reg);
                    if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

                    break :result MCValue{ .register_with_overflow = .{
                        .reg = dest_reg,
                        .flag = .{ .cond = cond, .ccr = ccr },
                    } };
                } else {
                    return self.fail("TODO overflow operations on other integer sizes", .{});
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const len_ty = self.typeOf(bin_op.rhs);
        const ptr_bytes = 8;
        const stack_offset = try self.allocMem(inst, ptr_bytes * 2, .@"8");
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(len_ty, stack_offset - ptr_bytes, len);
        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    if (!is_volatile and self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    const result: MCValue = result: {
        const slice_mcv = try self.resolveInst(bin_op.lhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);

        const slice_ty = self.typeOf(bin_op.lhs);
        const elem_ty = slice_ty.childType(zcu);
        const elem_size = elem_ty.abiSize(zcu);

        const slice_ptr_field_type = slice_ty.slicePtrFieldType(zcu);

        const index_lock: ?RegisterLock = if (index_mcv == .register)
            self.register_manager.lockRegAssumeUnused(index_mcv.register)
        else
            null;
        defer if (index_lock) |reg| self.register_manager.unlockReg(reg);

        const base_mcv: MCValue = switch (slice_mcv) {
            .stack_offset => |off| .{ .register = try self.copyToTmpRegister(slice_ptr_field_type, .{ .stack_offset = off }) },
            else => return self.fail("TODO slice_elem_val when slice is {}", .{slice_mcv}),
        };
        const base_lock = self.register_manager.lockRegAssumeUnused(base_mcv.register);
        defer self.register_manager.unlockReg(base_lock);

        switch (elem_size) {
            else => {
                // TODO skip the ptr_add emission entirely and use native addressing modes
                // i.e sllx/mulx then R+R or scale immediate then R+I
                const dest = try self.allocRegOrMem(inst, true);
                const addr = try self.binOp(.ptr_add, base_mcv, index_mcv, slice_ptr_field_type, Type.usize, null);
                try self.load(dest, addr, slice_ptr_field_type);

                break :result dest;
            },
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_bits = self.target.ptrBitWidth();
        const ptr_bytes = @divExact(ptr_bits, 8);
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach, .none => unreachable,
            .register => unreachable, // a slice doesn't fit in one register
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - ptr_bytes };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr + ptr_bytes };
            },
            else => return self.fail("TODO implement slice_len for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach, .none => unreachable,
            .register => unreachable, // a slice doesn't fit in one register
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr };
            },
            else => return self.fail("TODO implement slice_len for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airStore(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const value = try self.resolveInst(bin_op.rhs);
    const ptr_ty = self.typeOf(bin_op.lhs);
    const value_ty = self.typeOf(bin_op.rhs);

    try self.store(ptr, value, ptr_ty, value_ty);

    return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airStructFieldPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result = try self.structFieldPtr(inst, extra.struct_operand, extra.field_index);
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = try self.structFieldPtr(inst, ty_op.operand, index);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const zcu = self.pt.zcu;
        const mcv = try self.resolveInst(operand);
        const struct_ty = self.typeOf(operand);
        const struct_field_offset = @as(u32, @intCast(struct_ty.structFieldOffset(index, zcu)));

        switch (mcv) {
            .dead, .unreach => unreachable,
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - struct_field_offset };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr + struct_field_offset };
            },
            .register_with_overflow => |rwo| {
                switch (index) {
                    0 => {
                        // get wrapped value: return register
                        break :result MCValue{ .register = rwo.reg };
                    },
                    1 => {
                        // TODO return special MCValue condition flags
                        // get overflow bit: set register to C flag
                        // resp. V flag
                        const dest_reg = try self.register_manager.allocReg(null, gp);

                        // TODO handle floating point CCRs
                        assert(rwo.flag.ccr == .xcc or rwo.flag.ccr == .icc);

                        _ = try self.addInst(.{
                            .tag = .mov,
                            .data = .{
                                .arithmetic_2op = .{
                                    .is_imm = false,
                                    .rs1 = dest_reg,
                                    .rs2_or_imm = .{ .rs2 = .g0 },
                                },
                            },
                        });

                        _ = try self.addInst(.{
                            .tag = .movcc,
                            .data = .{
                                .conditional_move_int = .{
                                    .ccr = rwo.flag.ccr,
                                    .cond = .{ .icond = rwo.flag.cond },
                                    .is_imm = true,
                                    .rd = dest_reg,
                                    .rs2_or_imm = .{ .imm = 1 },
                                },
                            },
                        });

                        break :result MCValue{ .register = dest_reg };
                    },
                    else => unreachable,
                }
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement switch for {}", .{self.target.cpu.arch});
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airTagName for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const operand_ty = self.typeOf(ty_op.operand);
    const dest_ty = self.typeOfIndex(inst);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        break :blk try self.trunc(inst, operand, operand_ty, dest_ty);
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    const result: MCValue = result: {
        const error_union_ty = self.typeOf(pl_op.operand);
        const error_union = try self.resolveInst(pl_op.operand);
        const is_err_result = try self.isErr(error_union_ty, error_union);
        const reloc = try self.condBr(is_err_result);

        try self.genBody(body);

        try self.performReloc(reloc);
        break :result try self.errUnionPayload(error_union, error_union_ty);
    };
    return self.finishAir(inst, result, .{ pl_op.operand, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airUnaryMath for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement airUnionInit for {}", .{self.target.cpu.arch});
}

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.typeOf(ty_op.operand);
        const payload_ty = error_union_ty.errorUnionPayload(zcu);
        const mcv = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBits(zcu)) break :result mcv;

        return self.fail("TODO implement unwrap error union error for non-empty payloads", .{});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.typeOf(ty_op.operand);
        const payload_ty = error_union_ty.errorUnionPayload(zcu);
        if (!payload_ty.hasRuntimeBits(zcu)) break :result MCValue.none;

        return self.fail("TODO implement unwrap error union payload for non-empty payloads", .{});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = ty_op.ty.toType();
        const payload_ty = error_union_ty.errorUnionPayload(zcu);
        const mcv = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBits(zcu)) break :result mcv;

        return self.fail("TODO implement wrap errunion error for non-empty payloads", .{});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement wrap errunion payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const pt = self.pt;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const optional_ty = self.typeOfIndex(inst);

        // Optional with a zero-bit payload type is just a boolean true
        if (optional_ty.abiSize(pt.zcu) == 1)
            break :result MCValue{ .immediate = 1 };

        return self.fail("TODO implement wrap optional for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// Common helper functions

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;
    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index: Mir.Inst.Index = @intCast(self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

fn allocMem(self: *Self, inst: Air.Inst.Index, abi_size: u32, abi_align: Alignment) !u32 {
    self.stack_align = self.stack_align.max(abi_align);
    // TODO find a free slot instead of always appending
    const offset: u32 = @intCast(abi_align.forward(self.next_stack_offset) + abi_size);
    self.next_stack_offset = offset;
    if (self.next_stack_offset > self.max_end_stack)
        self.max_end_stack = self.next_stack_offset;
    try self.stack.putNoClobber(self.gpa, offset, .{
        .inst = inst,
        .size = abi_size,
    });
    return offset;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !u32 {
    const pt = self.pt;
    const zcu = pt.zcu;
    const elem_ty = self.typeOfIndex(inst).childType(zcu);

    if (!elem_ty.hasRuntimeBits(zcu)) {
        // As this stack item will never be dereferenced at runtime,
        // return the stack offset 0. Stack offset 0 will be where all
        // zero-sized stack allocations live as non-zero-sized
        // allocations will always have an offset > 0.
        return @as(u32, 0);
    }

    const abi_size = math.cast(u32, elem_ty.abiSize(zcu)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(pt)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(zcu);
    return self.allocMem(inst, abi_size, abi_align);
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const elem_ty = self.typeOfIndex(inst);
    const abi_size = math.cast(u32, elem_ty.abiSize(zcu)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(pt)});
    };
    const abi_align = elem_ty.abiAlignment(zcu);
    self.stack_align = self.stack_align.max(abi_align);

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        if (abi_size <= 8) {
            if (self.register_manager.tryAllocReg(inst, gp)) |reg| {
                return MCValue{ .register = reg };
            }
        }
    }
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = stack_offset };
}

const BinOpMetadata = struct {
    inst: Air.Inst.Index,
    lhs: Air.Inst.Ref,
    rhs: Air.Inst.Ref,
};

/// For all your binary operation needs, this function will generate
/// the corresponding Mir instruction(s). Returns the location of the
/// result.
///
/// If the binary operation itself happens to be an Air instruction,
/// pass the corresponding index in the inst parameter. That helps
/// this function do stuff like reusing operands.
///
/// This function does not do any lowering to Mir itself, but instead
/// looks at the lhs and rhs and determines which kind of lowering
/// would be best suitable and then delegates the lowering to other
/// functions.
fn binOp(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
    metadata: ?BinOpMetadata,
) InnerError!MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    switch (tag) {
        .add,
        .sub,
        .mul,
        .bit_and,
        .bit_or,
        .xor,
        .cmp_eq,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .float => return self.fail("TODO binary operations on floats", .{}),
                .vector => return self.fail("TODO binary operations on vectors", .{}),
                .int => {
                    assert(lhs_ty.eql(rhs_ty, zcu));
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        // Only say yes if the operation is
                        // commutative, i.e. we can swap both of the
                        // operands
                        const lhs_immediate_ok = switch (tag) {
                            .add => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .mul => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .bit_and => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .bit_or => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .xor => lhs == .immediate and lhs.immediate <= std.math.maxInt(u12),
                            .sub, .cmp_eq => false,
                            else => unreachable,
                        };
                        const rhs_immediate_ok = switch (tag) {
                            .add,
                            .sub,
                            .mul,
                            .bit_and,
                            .bit_or,
                            .xor,
                            .cmp_eq,
                            => rhs == .immediate and rhs.immediate <= std.math.maxInt(u12),
                            else => unreachable,
                        };

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .add => .add,
                            .sub => .sub,
                            .mul => .mulx,
                            .bit_and => .@"and",
                            .bit_or => .@"or",
                            .xor => .xor,
                            .cmp_eq => .cmp,
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                        } else if (lhs_immediate_ok) {
                            // swap lhs and rhs
                            return try self.binOpImmediate(mir_tag, rhs, lhs, rhs_ty, true, metadata);
                        } else {
                            // TODO convert large immediates to register before adding
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => unreachable,
            }
        },

        .add_wrap,
        .sub_wrap,
        .mul_wrap,
        => {
            const base_tag: Air.Inst.Tag = switch (tag) {
                .add_wrap => .add,
                .sub_wrap => .sub,
                .mul_wrap => .mul,
                else => unreachable,
            };

            // Generate the base operation
            const result = try self.binOp(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);

            // Truncate if necessary
            switch (lhs_ty.zigTypeTag(zcu)) {
                .vector => return self.fail("TODO binary operations on vectors", .{}),
                .int => {
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        const result_reg = result.register;
                        try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                        return result;
                    } else {
                        return self.fail("TODO binary operations on integers > u64/i64", .{});
                    }
                },
                else => unreachable,
            }
        },

        .div_trunc => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .vector => return self.fail("TODO binary operations on vectors", .{}),
                .int => {
                    assert(lhs_ty.eql(rhs_ty, zcu));
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        const rhs_immediate_ok = switch (tag) {
                            .div_trunc => rhs == .immediate and rhs.immediate <= std.math.maxInt(u12),
                            else => unreachable,
                        };

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .div_trunc => switch (int_info.signedness) {
                                .signed => Mir.Inst.Tag.sdivx,
                                .unsigned => Mir.Inst.Tag.udivx,
                            },
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, true, metadata);
                        } else {
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => unreachable,
            }
        },

        .ptr_add => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .pointer => {
                    const ptr_ty = lhs_ty;
                    const elem_ty = switch (ptr_ty.ptrSize(zcu)) {
                        .one => ptr_ty.childType(zcu).childType(zcu), // ptr to array, so get array element type
                        else => ptr_ty.childType(zcu),
                    };
                    const elem_size = elem_ty.abiSize(zcu);

                    if (elem_size == 1) {
                        const base_tag: Mir.Inst.Tag = switch (tag) {
                            .ptr_add => .add,
                            else => unreachable,
                        };

                        return try self.binOpRegister(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                    } else {
                        // convert the offset into a byte offset by
                        // multiplying it with elem_size

                        const offset = try self.binOp(.mul, rhs, .{ .immediate = elem_size }, Type.usize, Type.usize, null);
                        const addr = try self.binOp(tag, lhs, offset, Type.manyptr_u8, Type.usize, null);
                        return addr;
                    }
                },
                else => unreachable,
            }
        },

        .bool_and,
        .bool_or,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .bool => {
                    assert(lhs != .immediate); // should have been handled by Sema
                    assert(rhs != .immediate); // should have been handled by Sema

                    const mir_tag: Mir.Inst.Tag = switch (tag) {
                        .bool_and => .@"and",
                        .bool_or => .@"or",
                        else => unreachable,
                    };

                    return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                },
                else => unreachable,
            }
        },

        .shl,
        .shr,
        => {
            const base_tag: Air.Inst.Tag = switch (tag) {
                .shl => .shl_exact,
                .shr => .shr_exact,
                else => unreachable,
            };

            // Generate the base operation
            const result = try self.binOp(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);

            // Truncate if necessary
            switch (lhs_ty.zigTypeTag(zcu)) {
                .vector => return self.fail("TODO binary operations on vectors", .{}),
                .int => {
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        // 32 and 64 bit operands doesn't need truncating
                        if (int_info.bits == 32 or int_info.bits == 64) return result;

                        const result_reg = result.register;
                        try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                        return result;
                    } else {
                        return self.fail("TODO binary operations on integers > u64/i64", .{});
                    }
                },
                else => unreachable,
            }
        },

        .shl_exact,
        .shr_exact,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .vector => return self.fail("TODO binary operations on vectors", .{}),
                .int => {
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        const rhs_immediate_ok = rhs == .immediate;

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .shl_exact => if (int_info.bits <= 32) Mir.Inst.Tag.sll else Mir.Inst.Tag.sllx,
                            .shr_exact => switch (int_info.signedness) {
                                .signed => if (int_info.bits <= 32) Mir.Inst.Tag.sra else Mir.Inst.Tag.srax,
                                .unsigned => if (int_info.bits <= 32) Mir.Inst.Tag.srl else Mir.Inst.Tag.srlx,
                            },
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                        } else {
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => unreachable,
            }
        },

        else => return self.fail("TODO implement {} binOp for SPARCv9", .{tag}),
    }
}

/// Don't call this function directly. Use binOp instead.
///
/// Calling this function signals an intention to generate a Mir
/// instruction of the form
///
///     op dest, lhs, #rhs_imm
///
/// Set lhs_and_rhs_swapped to true iff inst.bin_op.lhs corresponds to
/// rhs and vice versa. This parameter is only used when metadata != null.
///
/// Asserts that generating an instruction of that form is possible.
fn binOpImmediate(
    self: *Self,
    mir_tag: Mir.Inst.Tag,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    lhs_and_rhs_swapped: bool,
    metadata: ?BinOpMetadata,
) !MCValue {
    const lhs_is_register = lhs == .register;

    const lhs_lock: ?RegisterLock = if (lhs_is_register)
        self.register_manager.lockReg(lhs.register)
    else
        null;
    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];

    const lhs_reg = if (lhs_is_register) lhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst (if (lhs_and_rhs_swapped) md.rhs else md.lhs).toIndex().?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);

        if (track_inst) |inst| {
            const mcv: MCValue = .{ .register = reg };
            log.debug("binOpRegister move lhs %{d} to register: {} -> {}", .{ inst, lhs, mcv });
            branch.inst_table.putAssumeCapacity(inst, mcv);

            // If we're moving a condition flag MCV to register,
            // mark it as free.
            if (lhs == .condition_flags) {
                assert(self.condition_flags_inst.? == inst);
                self.condition_flags_inst = null;
            }
        }

        break :blk reg;
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = switch (mir_tag) {
        .cmp => undefined, // cmp has no destination register
        else => if (metadata) |md| blk: {
            if (lhs_is_register and self.reuseOperand(
                md.inst,
                if (lhs_and_rhs_swapped) md.rhs else md.lhs,
                if (lhs_and_rhs_swapped) 1 else 0,
                lhs,
            )) {
                break :blk lhs_reg;
            } else {
                break :blk try self.register_manager.allocReg(md.inst, gp);
            }
        } else blk: {
            break :blk try self.register_manager.allocReg(null, gp);
        },
    };

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .addcc,
        .@"and",
        .@"or",
        .xor,
        .xnor,
        .mulx,
        .sdivx,
        .udivx,
        .sub,
        .subcc,
        => .{
            .arithmetic_3op = .{
                .is_imm = true,
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .imm = @as(u12, @intCast(rhs.immediate)) },
            },
        },
        .sll,
        .srl,
        .sra,
        => .{
            .shift = .{
                .is_imm = true,
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .imm = @as(u5, @intCast(rhs.immediate)) },
            },
        },
        .sllx,
        .srlx,
        .srax,
        => .{
            .shift = .{
                .is_imm = true,
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .imm = @as(u6, @intCast(rhs.immediate)) },
            },
        },
        .cmp => .{
            .arithmetic_2op = .{
                .is_imm = true,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .imm = @as(u12, @intCast(rhs.immediate)) },
            },
        },
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = mir_data,
    });

    return MCValue{ .register = dest_reg };
}

/// Don't call this function directly. Use binOp instead.
///
/// Calling this function signals an intention to generate a Mir
/// instruction of the form
///
///     op dest, lhs, rhs
///
/// Asserts that generating an instruction of that form is possible.
fn binOpRegister(
    self: *Self,
    mir_tag: Mir.Inst.Tag,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
    metadata: ?BinOpMetadata,
) !MCValue {
    const lhs_is_register = lhs == .register;
    const rhs_is_register = rhs == .register;

    const lhs_lock: ?RegisterLock = if (lhs_is_register)
        self.register_manager.lockReg(lhs.register)
    else
        null;
    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_lock: ?RegisterLock = if (rhs_is_register)
        self.register_manager.lockReg(rhs.register)
    else
        null;
    defer if (rhs_lock) |reg| self.register_manager.unlockReg(reg);

    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];

    const lhs_reg = if (lhs_is_register) lhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst md.lhs.toIndex().?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);
        if (track_inst) |inst| {
            const mcv: MCValue = .{ .register = reg };
            log.debug("binOpRegister move lhs %{d} to register: {} -> {}", .{ inst, lhs, mcv });
            branch.inst_table.putAssumeCapacity(inst, mcv);

            // If we're moving a condition flag MCV to register,
            // mark it as free.
            if (lhs == .condition_flags) {
                assert(self.condition_flags_inst.? == inst);
                self.condition_flags_inst = null;
            }
        }

        break :blk reg;
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_reg = if (rhs_is_register) rhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst md.rhs.toIndex().?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);
        if (track_inst) |inst| {
            const mcv: MCValue = .{ .register = reg };
            log.debug("binOpRegister move rhs %{d} to register: {} -> {}", .{ inst, rhs, mcv });
            branch.inst_table.putAssumeCapacity(inst, mcv);

            // If we're moving a condition flag MCV to register,
            // mark it as free.
            if (rhs == .condition_flags) {
                assert(self.condition_flags_inst.? == inst);
                self.condition_flags_inst = null;
            }
        }

        break :blk reg;
    };
    const new_rhs_lock = self.register_manager.lockReg(rhs_reg);
    defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = switch (mir_tag) {
        .cmp => undefined, // cmp has no destination register
        else => if (metadata) |md| blk: {
            if (lhs_is_register and self.reuseOperand(md.inst, md.lhs, 0, lhs)) {
                break :blk lhs_reg;
            } else if (rhs_is_register and self.reuseOperand(md.inst, md.rhs, 1, rhs)) {
                break :blk rhs_reg;
            } else {
                break :blk try self.register_manager.allocReg(md.inst, gp);
            }
        } else blk: {
            break :blk try self.register_manager.allocReg(null, gp);
        },
    };

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);
    if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .addcc,
        .@"and",
        .@"or",
        .xor,
        .xnor,
        .mulx,
        .sdivx,
        .udivx,
        .sub,
        .subcc,
        => .{
            .arithmetic_3op = .{
                .is_imm = false,
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
        .sll,
        .srl,
        .sra,
        .sllx,
        .srlx,
        .srax,
        => .{
            .shift = .{
                .is_imm = false,
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
        .cmp => .{
            .arithmetic_2op = .{
                .is_imm = false,
                .rs1 = lhs_reg,
                .rs2_or_imm = .{ .rs2 = rhs_reg },
            },
        },
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = mir_data,
    });

    return MCValue{ .register = dest_reg };
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const block_data = self.blocks.getPtr(block).?;

    const zcu = self.pt.zcu;
    if (self.typeOf(operand).hasRuntimeBits(zcu)) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = switch (operand_mcv) {
                .none, .dead, .unreach => unreachable,
                .register, .stack_offset, .memory => operand_mcv,
                .immediate => blk: {
                    const new_mcv = try self.allocRegOrMem(block, true);
                    try self.setRegOrMem(self.typeOfIndex(block), new_mcv, operand_mcv);
                    break :blk new_mcv;
                },
                else => return self.fail("TODO implement block_data.mcv = operand_mcv for {}", .{operand_mcv}),
            };
        } else {
            try self.setRegOrMem(self.typeOfIndex(block), block_mcv, operand_mcv);
        }
    }
    return self.brVoid(block);
}

fn brVoid(self: *Self, block: Air.Inst.Index) !void {
    const block_data = self.blocks.getPtr(block).?;

    // Emit a jump with a relocation. It will be patched up after the block ends.
    try block_data.relocs.ensureUnusedCapacity(self.gpa, 1);

    const br_index = try self.addInst(.{
        .tag = .bpcc,
        .data = .{
            .branch_predict_int = .{
                .ccr = .xcc,
                .cond = .al,
                .inst = undefined, // Will be filled by performReloc
            },
        },
    });

    // TODO Find a way to fill this delay slot
    _ = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });

    block_data.relocs.appendAssumeCapacity(br_index);
}

fn condBr(self: *Self, condition: MCValue) !Mir.Inst.Index {
    // Here we either emit a BPcc for branching on CCR content,
    // or emit a BPr to branch on register content.
    const reloc: Mir.Inst.Index = switch (condition) {
        .condition_flags => |flags| try self.addInst(.{
            .tag = .bpcc,
            .data = .{
                .branch_predict_int = .{
                    .ccr = flags.ccr,
                    // Here we map to the opposite condition because the jump is to the false branch.
                    .cond = flags.cond.icond.negate(),
                    .inst = undefined, // Will be filled by performReloc
                },
            },
        }),
        .condition_register => |reg| try self.addInst(.{
            .tag = .bpr,
            .data = .{
                .branch_predict_reg = .{
                    .rs1 = reg.reg,
                    // Here we map to the opposite condition because the jump is to the false branch.
                    .cond = reg.cond.negate(),
                    .inst = undefined, // Will be filled by performReloc
                },
            },
        }),
        else => blk: {
            const reg = switch (condition) {
                .register => |r| r,
                else => try self.copyToTmpRegister(Type.bool, condition),
            };

            break :blk try self.addInst(.{
                .tag = .bpr,
                .data = .{
                    .branch_predict_reg = .{
                        .cond = .eq_zero,
                        .rs1 = reg,
                        .inst = undefined, // populated later through performReloc
                    },
                },
            });
        },
    };

    // Regardless of the branch type that's emitted, we need to reserve
    // a space for the delay slot.
    // TODO Find a way to fill this delay slot
    _ = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });

    return reloc;
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null, gp);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
    const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
    try table.ensureUnusedCapacity(self.gpa, additional_count);
}

/// Given an error union, returns the payload
fn errUnionPayload(self: *Self, error_union_mcv: MCValue, error_union_ty: Type) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const err_ty = error_union_ty.errorUnionSet(zcu);
    const payload_ty = error_union_ty.errorUnionPayload(zcu);
    if (err_ty.errorSetIsEmpty(zcu)) {
        return error_union_mcv;
    }
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return MCValue.none;
    }

    const payload_offset = @as(u32, @intCast(errUnionPayloadOffset(payload_ty, zcu)));
    switch (error_union_mcv) {
        .register => return self.fail("TODO errUnionPayload for registers", .{}),
        .stack_offset => |off| {
            return MCValue{ .stack_offset = off - payload_offset };
        },
        .memory => |addr| {
            return MCValue{ .memory = addr + payload_offset };
        },
        else => unreachable, // invalid MCValue for an error union
    }
}

fn fail(self: *Self, comptime format: []const u8, args: anytype) error{ OutOfMemory, CodegenFail } {
    @branchHint(.cold);
    const zcu = self.pt.zcu;
    const func = zcu.funcInfo(self.func_index);
    const msg = try ErrorMsg.create(zcu.gpa, self.src_loc, format, args);
    return zcu.codegenFailMsg(func.owner_nav, msg);
}

fn failMsg(self: *Self, msg: *ErrorMsg) error{ OutOfMemory, CodegenFail } {
    @branchHint(.cold);
    const zcu = self.pt.zcu;
    const func = zcu.funcInfo(self.func_index);
    return zcu.codegenFailMsg(func.owner_nav, msg);
}

/// Called when there are no operands, and the instruction is always unreferenced.
fn finishAirBookkeeping(self: *Self) void {
    if (std.debug.runtime_safety) {
        self.air_bookkeeping += 1;
    }
}

fn finishAir(self: *Self, inst: Air.Inst.Index, result: MCValue, operands: [Liveness.bpi - 1]Air.Inst.Ref) void {
    const tomb_bits = self.liveness.getTombBits(inst);
    for (0.., operands) |op_index, op| {
        if (tomb_bits & @as(Liveness.Bpi, 1) << @intCast(op_index) == 0) continue;
        if (self.reused_operands.isSet(op_index)) continue;
        self.processDeath(op.toIndexAllowNone() orelse continue);
    }
    if (tomb_bits & 1 << (Liveness.bpi - 1) == 0) {
        log.debug("%{d} => {}", .{ inst, result });
        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        branch.inst_table.putAssumeCapacityNoClobber(inst, result);

        switch (result) {
            .register => |reg| {
                // In some cases (such as bitcast), an operand
                // may be the same MCValue as the result. If
                // that operand died and was a register, it
                // was freed by processDeath. We have to
                // "re-allocate" the register.
                if (self.register_manager.isRegFree(reg)) {
                    self.register_manager.getRegAssumeFree(reg, inst);
                }
            },
            else => {},
        }
    }
    self.finishAirBookkeeping();
}

fn genArgDbgInfo(self: Self, inst: Air.Inst.Index, mcv: MCValue) !void {
    const arg = self.air.instructions.items(.data)[@intFromEnum(inst)].arg;
    const ty = arg.ty.toType();
    if (arg.name == .none) return;

    switch (self.debug_output) {
        .dwarf => |dw| switch (mcv) {
            .register => |reg| try dw.genLocalDebugInfo(
                .local_arg,
                arg.name.toSlice(self.air),
                ty,
                .{ .reg = reg.dwarfNum() },
            ),
            else => {},
        },
        else => {},
    }
}

// TODO replace this to call to extern memcpy
fn genInlineMemcpy(
    self: *Self,
    src: Register,
    dst: Register,
    len: Register,
    tmp: Register,
) !void {
    // Here we assume that len > 0.
    // Also we do the copy from end -> start address to save a register.

    // sub len, 1, len
    _ = try self.addInst(.{
        .tag = .sub,
        .data = .{ .arithmetic_3op = .{
            .is_imm = true,
            .rs1 = len,
            .rs2_or_imm = .{ .imm = 1 },
            .rd = len,
        } },
    });

    // loop:
    // ldub [src + len], tmp
    _ = try self.addInst(.{
        .tag = .ldub,
        .data = .{ .arithmetic_3op = .{
            .is_imm = false,
            .rs1 = src,
            .rs2_or_imm = .{ .rs2 = len },
            .rd = tmp,
        } },
    });

    // stb tmp, [dst + len]
    _ = try self.addInst(.{
        .tag = .stb,
        .data = .{ .arithmetic_3op = .{
            .is_imm = false,
            .rs1 = dst,
            .rs2_or_imm = .{ .rs2 = len },
            .rd = tmp,
        } },
    });

    // brnz len, loop
    _ = try self.addInst(.{
        .tag = .bpr,
        .data = .{ .branch_predict_reg = .{
            .cond = .ne_zero,
            .rs1 = len,
            .inst = @as(u32, @intCast(self.mir_instructions.len - 2)),
        } },
    });

    // Delay slot:
    //  sub len, 1, len
    _ = try self.addInst(.{
        .tag = .sub,
        .data = .{ .arithmetic_3op = .{
            .is_imm = true,
            .rs1 = len,
            .rs2_or_imm = .{ .imm = 1 },
            .rd = len,
        } },
    });

    // end:
}

fn genLoad(self: *Self, value_reg: Register, addr_reg: Register, comptime off_type: type, off: off_type, abi_size: u64) !void {
    assert(off_type == Register or off_type == i13);

    const is_imm = (off_type == i13);

    switch (abi_size) {
        1, 2, 4, 8 => {
            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .ldub,
                2 => .lduh,
                4 => .lduw,
                8 => .ldx,
                else => unreachable, // unexpected abi size
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = if (is_imm) .{ .imm = off } else .{ .rs2 = off },
                    },
                },
            });
        },
        3, 5, 6, 7 => return self.fail("TODO: genLoad for more abi_sizes", .{}),
        else => unreachable,
    }
}

fn genLoadASI(self: *Self, value_reg: Register, addr_reg: Register, off_reg: Register, abi_size: u64, asi: ASI) !void {
    switch (abi_size) {
        1, 2, 4, 8 => {
            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .lduba,
                2 => .lduha,
                4 => .lduwa,
                8 => .ldxa,
                else => unreachable, // unexpected abi size
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{
                    .mem_asi = .{
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2 = off_reg,
                        .asi = asi,
                    },
                },
            });
        },
        3, 5, 6, 7 => return self.fail("TODO: genLoad for more abi_sizes", .{}),
        else => unreachable,
    }
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .condition_flags => |op| {
            const condition = op.cond;
            const ccr = op.ccr;

            // TODO handle floating point CCRs
            assert(ccr == .xcc or ccr == .icc);

            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{
                    .arithmetic_2op = .{
                        .is_imm = false,
                        .rs1 = reg,
                        .rs2_or_imm = .{ .rs2 = .g0 },
                    },
                },
            });

            _ = try self.addInst(.{
                .tag = .movcc,
                .data = .{
                    .conditional_move_int = .{
                        .ccr = ccr,
                        .cond = condition,
                        .is_imm = true,
                        .rd = reg,
                        .rs2_or_imm = .{ .imm = 1 },
                    },
                },
            });
        },
        .condition_register => |op| {
            const condition = op.cond;
            const register = op.reg;

            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{
                    .arithmetic_2op = .{
                        .is_imm = false,
                        .rs1 = reg,
                        .rs2_or_imm = .{ .rs2 = .g0 },
                    },
                },
            });

            _ = try self.addInst(.{
                .tag = .movr,
                .data = .{
                    .conditional_move_reg = .{
                        .cond = condition,
                        .is_imm = true,
                        .rd = reg,
                        .rs1 = register,
                        .rs2_or_imm = .{ .imm = 1 },
                    },
                },
            });
        },
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .ptr_stack_offset => |off| {
            const real_offset = realStackOffset(off);
            const simm13 = math.cast(i13, real_offset) orelse
                return self.fail("TODO larger stack offsets: {}", .{real_offset});

            _ = try self.addInst(.{
                .tag = .add,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = true,
                        .rd = reg,
                        .rs1 = .sp,
                        .rs2_or_imm = .{ .imm = simm13 },
                    },
                },
            });
        },
        .immediate => |x| {
            if (x <= math.maxInt(u12)) {
                _ = try self.addInst(.{
                    .tag = .mov,
                    .data = .{
                        .arithmetic_2op = .{
                            .is_imm = true,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = @as(u12, @truncate(x)) },
                        },
                    },
                });
            } else if (x <= math.maxInt(u32)) {
                _ = try self.addInst(.{
                    .tag = .sethi,
                    .data = .{
                        .sethi = .{
                            .rd = reg,
                            .imm = @as(u22, @truncate(x >> 10)),
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = @as(u10, @truncate(x)) },
                        },
                    },
                });
            } else if (x <= math.maxInt(u44)) {
                try self.genSetReg(ty, reg, .{ .immediate = @as(u32, @truncate(x >> 12)) });

                _ = try self.addInst(.{
                    .tag = .sllx,
                    .data = .{
                        .shift = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = 12 },
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = @as(u12, @truncate(x)) },
                        },
                    },
                });
            } else {
                // Need to allocate a temporary register to load 64-bit immediates.
                const tmp_reg = try self.register_manager.allocReg(null, gp);

                try self.genSetReg(ty, tmp_reg, .{ .immediate = @as(u32, @truncate(x)) });
                try self.genSetReg(ty, reg, .{ .immediate = @as(u32, @truncate(x >> 32)) });

                _ = try self.addInst(.{
                    .tag = .sllx,
                    .data = .{
                        .shift = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = 32 },
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = false,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .rs2 = tmp_reg },
                        },
                    },
                });
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{
                    .arithmetic_2op = .{
                        .is_imm = false,
                        .rs1 = reg,
                        .rs2_or_imm = .{ .rs2 = src_reg },
                    },
                },
            });
        },
        .register_with_overflow => unreachable,
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = addr });
            try self.genLoad(reg, reg, i13, 0, ty.abiSize(zcu));
        },
        .stack_offset => |off| {
            const real_offset = realStackOffset(off);
            const simm13 = math.cast(i13, real_offset) orelse
                return self.fail("TODO larger stack offsets: {}", .{real_offset});
            try self.genLoad(reg, .sp, i13, simm13, ty.abiSize(zcu));
        },
    }
}

fn genSetStack(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const abi_size = ty.abiSize(zcu);
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (ty.abiSize(zcu)) {
                1 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                8 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .condition_flags,
        .condition_register,
        .immediate,
        .ptr_stack_offset,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .register => |reg| {
            const real_offset = realStackOffset(stack_offset);
            const simm13 = math.cast(i13, real_offset) orelse
                return self.fail("TODO larger stack offsets: {}", .{real_offset});
            return self.genStore(reg, .sp, i13, simm13, abi_size);
        },
        .register_with_overflow => |rwo| {
            const reg_lock = self.register_manager.lockReg(rwo.reg);
            defer if (reg_lock) |locked_reg| self.register_manager.unlockReg(locked_reg);

            const wrapped_ty = ty.fieldType(0, zcu);
            try self.genSetStack(wrapped_ty, stack_offset, .{ .register = rwo.reg });

            const overflow_bit_ty = ty.fieldType(1, zcu);
            const overflow_bit_offset = @as(u32, @intCast(ty.structFieldOffset(1, zcu)));
            const cond_reg = try self.register_manager.allocReg(null, gp);

            // TODO handle floating point CCRs
            assert(rwo.flag.ccr == .xcc or rwo.flag.ccr == .icc);

            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{
                    .arithmetic_2op = .{
                        .is_imm = false,
                        .rs1 = cond_reg,
                        .rs2_or_imm = .{ .rs2 = .g0 },
                    },
                },
            });

            _ = try self.addInst(.{
                .tag = .movcc,
                .data = .{
                    .conditional_move_int = .{
                        .ccr = rwo.flag.ccr,
                        .cond = .{ .icond = rwo.flag.cond },
                        .is_imm = true,
                        .rd = cond_reg,
                        .rs2_or_imm = .{ .imm = 1 },
                    },
                },
            });
            try self.genSetStack(overflow_bit_ty, stack_offset - overflow_bit_offset, .{
                .register = cond_reg,
            });
        },
        .memory, .stack_offset => {
            switch (mcv) {
                .stack_offset => |off| {
                    if (stack_offset == off)
                        return; // Copy stack variable to itself; nothing to do.
                },
                else => {},
            }

            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            } else {
                const ptr_ty = try pt.singleMutPtrType(ty);

                const regs = try self.register_manager.allocRegs(4, .{ null, null, null, null }, gp);
                const regs_locks = self.register_manager.lockRegsAssumeUnused(4, regs);
                defer for (regs_locks) |reg| {
                    self.register_manager.unlockReg(reg);
                };

                const src_reg = regs[0];
                const dst_reg = regs[1];
                const len_reg = regs[2];
                const tmp_reg = regs[3];

                switch (mcv) {
                    .stack_offset => |off| try self.genSetReg(ptr_ty, src_reg, .{ .ptr_stack_offset = off }),
                    .memory => |addr| try self.genSetReg(Type.usize, src_reg, .{ .immediate = addr }),
                    else => unreachable,
                }

                try self.genSetReg(ptr_ty, dst_reg, .{ .ptr_stack_offset = stack_offset });
                try self.genSetReg(Type.usize, len_reg, .{ .immediate = abi_size });
                try self.genInlineMemcpy(src_reg, dst_reg, len_reg, tmp_reg);
            }
        },
    }
}

fn genStore(self: *Self, value_reg: Register, addr_reg: Register, comptime off_type: type, off: off_type, abi_size: u64) !void {
    assert(off_type == Register or off_type == i13);

    const is_imm = (off_type == i13);

    switch (abi_size) {
        1, 2, 4, 8 => {
            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .stb,
                2 => .sth,
                4 => .stw,
                8 => .stx,
                else => unreachable, // unexpected abi size
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = if (is_imm) .{ .imm = off } else .{ .rs2 = off },
                    },
                },
            });
        },
        3, 5, 6, 7 => return self.fail("TODO: genLoad for more abi_sizes", .{}),
        else => unreachable,
    }
}

fn genStoreASI(self: *Self, value_reg: Register, addr_reg: Register, off_reg: Register, abi_size: u64, asi: ASI) !void {
    switch (abi_size) {
        1, 2, 4, 8 => {
            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .stba,
                2 => .stha,
                4 => .stwa,
                8 => .stxa,
                else => unreachable, // unexpected abi size
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{
                    .mem_asi = .{
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2 = off_reg,
                        .asi = asi,
                    },
                },
            });
        },
        3, 5, 6, 7 => return self.fail("TODO: genLoad for more abi_sizes", .{}),
        else => unreachable,
    }
}

fn genTypedValue(self: *Self, val: Value) InnerError!MCValue {
    const pt = self.pt;
    const mcv: MCValue = switch (try codegen.genTypedValue(
        self.bin_file,
        pt,
        self.src_loc,
        val,
        self.target.*,
    )) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .load_got, .load_symbol, .load_direct, .load_tlv, .lea_symbol, .lea_direct => unreachable, // TODO
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
        },
        .fail => |msg| {
            self.err_msg = msg;
            return error.CodegenFail;
        },
    };
    return mcv;
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) MCValue {
    // Treat each stack item as a "layer" on top of the previous one.
    var i: usize = self.branch_stack.items.len;
    while (true) {
        i -= 1;
        if (self.branch_stack.items[i].inst_table.get(inst)) |mcv| {
            log.debug("getResolvedInstValue %{} => {}", .{ inst, mcv });
            assert(mcv != .dead);
            return mcv;
        }
    }
}

fn isErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const error_type = ty.errorUnionSet(zcu);
    const payload_type = ty.errorUnionPayload(zcu);

    if (!error_type.hasRuntimeBits(zcu)) {
        return MCValue{ .immediate = 0 }; // always false
    } else if (!payload_type.hasRuntimeBits(zcu)) {
        if (error_type.abiSize(zcu) <= 8) {
            const reg_mcv: MCValue = switch (operand) {
                .register => operand,
                else => .{ .register = try self.copyToTmpRegister(error_type, operand) },
            };

            _ = try self.addInst(.{
                .tag = .cmp,
                .data = .{ .arithmetic_2op = .{
                    .is_imm = true,
                    .rs1 = reg_mcv.register,
                    .rs2_or_imm = .{ .imm = 0 },
                } },
            });

            return MCValue{ .condition_flags = .{ .cond = .{ .icond = .gu }, .ccr = .xcc } };
        } else {
            return self.fail("TODO isErr for errors with size > 8", .{});
        }
    } else {
        return self.fail("TODO isErr for non-empty payloads", .{});
    }
}

fn isNonErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    // Call isErr, then negate the result.
    const is_err_result = try self.isErr(ty, operand);
    switch (is_err_result) {
        .condition_flags => |op| {
            return MCValue{ .condition_flags = .{ .cond = op.cond.negate(), .ccr = op.ccr } };
        },
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = 1 };
        },
        else => unreachable,
    }
}

fn isNull(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNonNull and invert the result.
    return self.fail("TODO call isNonNull and invert the result", .{});
}

fn isNonNull(self: *Self, operand: MCValue) !MCValue {
    // Call isNull, then negate the result.
    const is_null_result = try self.isNull(operand);
    switch (is_null_result) {
        .condition_flags => |op| {
            return MCValue{ .condition_flags = .{ .cond = op.cond.negate(), .ccr = op.ccr } };
        },
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = 1 };
        },
        else => unreachable,
    }
}

fn iterateBigTomb(self: *Self, inst: Air.Inst.Index, operand_count: usize) !BigTomb {
    try self.ensureProcessDeathCapacity(operand_count + 1);
    return BigTomb{
        .function = self,
        .inst = inst,
        .lbt = self.liveness.iterateBigTomb(inst),
    };
}

/// Send control flow to `inst`.
fn jump(self: *Self, inst: Mir.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = .bpcc,
        .data = .{
            .branch_predict_int = .{
                .cond = .al,
                .ccr = .xcc,
                .inst = inst,
            },
        },
    });

    // TODO find out a way to fill this delay slot
    _ = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });
}

fn load(self: *Self, dst_mcv: MCValue, ptr: MCValue, ptr_ty: Type) InnerError!void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const elem_ty = ptr_ty.childType(zcu);
    const elem_size = elem_ty.abiSize(zcu);

    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .condition_flags,
        .condition_register,
        .register_with_overflow,
        => unreachable, // cannot hold an address
        .immediate => |imm| try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm }),
        .ptr_stack_offset => |off| try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off }),
        .register => |addr_reg| {
            const addr_reg_lock = self.register_manager.lockReg(addr_reg);
            defer if (addr_reg_lock) |reg| self.register_manager.unlockReg(reg);

            switch (dst_mcv) {
                .dead => unreachable,
                .undef => unreachable,
                .condition_flags => unreachable,
                .register => |dst_reg| {
                    try self.genLoad(dst_reg, addr_reg, i13, 0, elem_size);
                },
                .stack_offset => |off| {
                    if (elem_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        const tmp_reg_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                        defer self.register_manager.unlockReg(tmp_reg_lock);

                        try self.load(.{ .register = tmp_reg }, ptr, ptr_ty);
                        try self.genSetStack(elem_ty, off, MCValue{ .register = tmp_reg });
                    } else {
                        const regs = try self.register_manager.allocRegs(3, .{ null, null, null }, gp);
                        const regs_locks = self.register_manager.lockRegsAssumeUnused(3, regs);
                        defer for (regs_locks) |reg| {
                            self.register_manager.unlockReg(reg);
                        };

                        const src_reg = addr_reg;
                        const dst_reg = regs[0];
                        const len_reg = regs[1];
                        const tmp_reg = regs[2];

                        try self.genSetReg(ptr_ty, dst_reg, .{ .ptr_stack_offset = off });
                        try self.genSetReg(Type.usize, len_reg, .{ .immediate = elem_size });
                        try self.genInlineMemcpy(src_reg, dst_reg, len_reg, tmp_reg);
                    }
                },
                else => return self.fail("TODO load from register into {}", .{dst_mcv}),
            }
        },
        .memory,
        .stack_offset,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.load(dst_mcv, .{ .register = addr_reg }, ptr_ty);
        },
    }
}

fn minMax(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) InnerError!MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    assert(lhs_ty.eql(rhs_ty, zcu));
    switch (lhs_ty.zigTypeTag(zcu)) {
        .float => return self.fail("TODO min/max on floats", .{}),
        .vector => return self.fail("TODO min/max on vectors", .{}),
        .int => {
            const int_info = lhs_ty.intInfo(zcu);
            if (int_info.bits <= 64) {
                // TODO skip register setting when one of the operands
                // is a small (fits in i13) immediate.
                const rhs_is_register = rhs == .register;
                const rhs_reg = if (rhs_is_register)
                    rhs.register
                else
                    try self.register_manager.allocReg(null, gp);
                const rhs_lock = self.register_manager.lockReg(rhs_reg);
                defer if (rhs_lock) |reg| self.register_manager.unlockReg(reg);
                if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

                const result_reg = try self.register_manager.allocReg(null, gp);
                const result_lock = self.register_manager.lockReg(result_reg);
                defer if (result_lock) |reg| self.register_manager.unlockReg(reg);
                try self.genSetReg(lhs_ty, result_reg, lhs);

                const cond_choose_rhs: Instruction.ICondition = switch (tag) {
                    .max => switch (int_info.signedness) {
                        .signed => Instruction.ICondition.gt,
                        .unsigned => Instruction.ICondition.gu,
                    },
                    .min => switch (int_info.signedness) {
                        .signed => Instruction.ICondition.lt,
                        .unsigned => Instruction.ICondition.cs,
                    },
                    else => unreachable,
                };

                _ = try self.addInst(.{
                    .tag = .cmp,
                    .data = .{
                        .arithmetic_2op = .{
                            .is_imm = false,
                            .rs1 = result_reg,
                            .rs2_or_imm = .{ .rs2 = rhs_reg },
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .movcc,
                    .data = .{
                        .conditional_move_int = .{
                            .is_imm = false,
                            .ccr = .xcc,
                            .cond = .{ .icond = cond_choose_rhs },
                            .rd = result_reg,
                            .rs2_or_imm = .{ .rs2 = rhs_reg },
                        },
                    },
                });

                return MCValue{ .register = result_reg };
            } else {
                return self.fail("TODO min/max on integers > u64/i64", .{});
            }
        },
        else => unreachable,
    }
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

fn performReloc(self: *Self, inst: Mir.Inst.Index) !void {
    const tag = self.mir_instructions.items(.tag)[inst];
    switch (tag) {
        .bpcc => self.mir_instructions.items(.data)[inst].branch_predict_int.inst = @intCast(self.mir_instructions.len),
        .bpr => self.mir_instructions.items(.data)[inst].branch_predict_reg.inst = @intCast(self.mir_instructions.len),
        else => unreachable,
    }
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) void {
    // When editing this function, note that the logic must synchronize with `reuseOperand`.
    const prev_value = self.getResolvedInstValue(inst);
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    branch.inst_table.putAssumeCapacity(inst, .dead);
    log.debug("%{} death: {} -> .dead", .{ inst, prev_value });
    switch (prev_value) {
        .register => |reg| {
            self.register_manager.freeReg(reg);
        },
        .register_with_overflow => |rwo| {
            self.register_manager.freeReg(rwo.reg);
            self.condition_flags_inst = null;
        },
        .condition_flags => {
            self.condition_flags_inst = null;
        },
        else => {}, // TODO process stack allocation death
    }
}

/// Turns stack_offset MCV into a real SPARCv9 stack offset usable for asm.
fn realStackOffset(off: u32) u32 {
    return off
    // SPARCv9 %sp points away from the stack by some amount.
    + abi.stack_bias
    // The first couple bytes of each stack frame is reserved
    // for ABI and hardware purposes.
    + abi.stack_reserved_area;
    // Only after that we have the usable stack frame portion.
}

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(self: *Self, fn_ty: Type, role: RegisterView) !CallMCValues {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const fn_info = zcu.typeToFunc(fn_ty).?;
    const cc = fn_info.cc;
    var result: CallMCValues = .{
        .args = try self.gpa.alloc(MCValue, fn_info.param_types.len),
        // These undefined values must be populated before returning from this function.
        .return_value = undefined,
        .stack_byte_count = undefined,
        .stack_align = undefined,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = fn_ty.fnReturnType(zcu);

    switch (cc) {
        .naked => {
            assert(result.args.len == 0);
            result.return_value = .{ .unreach = {} };
            result.stack_byte_count = 0;
            result.stack_align = .@"1";
            return result;
        },
        .auto, .sparc64_sysv => {
            // SPARC Compliance Definition 2.4.1, Chapter 3
            // Low-Level System Information (64-bit psABI) - Function Calling Sequence

            var next_register: usize = 0;
            var next_stack_offset: u32 = 0;
            // TODO: this is never assigned, which is a bug, but I don't know how this code works
            // well enough to try and fix it. I *think* `next_register += next_stack_offset` is
            // supposed to be `next_stack_offset += param_size` in every case where it appears.
            _ = &next_stack_offset;

            // The caller puts the argument in %o0-%o5, which becomes %i0-%i5 inside the callee.
            const argument_registers = switch (role) {
                .caller => abi.c_abi_int_param_regs_caller_view,
                .callee => abi.c_abi_int_param_regs_callee_view,
            };

            for (fn_info.param_types.get(ip), result.args) |ty, *result_arg| {
                const param_size = @as(u32, @intCast(Type.fromInterned(ty).abiSize(zcu)));
                if (param_size <= 8) {
                    if (next_register < argument_registers.len) {
                        result_arg.* = .{ .register = argument_registers[next_register] };
                        next_register += 1;
                    } else {
                        result_arg.* = .{ .stack_offset = next_stack_offset };
                        next_register += next_stack_offset;
                    }
                } else if (param_size <= 16) {
                    if (next_register < argument_registers.len - 1) {
                        return self.fail("TODO MCValues with 2 registers", .{});
                    } else if (next_register < argument_registers.len) {
                        return self.fail("TODO MCValues split register + stack", .{});
                    } else {
                        result_arg.* = .{ .stack_offset = next_stack_offset };
                        next_register += next_stack_offset;
                    }
                } else {
                    result_arg.* = .{ .stack_offset = next_stack_offset };
                    next_register += next_stack_offset;
                }
            }

            result.stack_byte_count = next_stack_offset;
            result.stack_align = .@"16";

            if (ret_ty.zigTypeTag(zcu) == .noreturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBits(zcu)) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size: u32 = @intCast(ret_ty.abiSize(zcu));
                // The callee puts the return values in %i0-%i3, which becomes %o0-%o3 inside the caller.
                if (ret_ty_size <= 8) {
                    result.return_value = switch (role) {
                        .caller => .{ .register = abi.c_abi_int_return_regs_caller_view[0] },
                        .callee => .{ .register = abi.c_abi_int_return_regs_callee_view[0] },
                    };
                } else {
                    return self.fail("TODO support more return values for sparc64", .{});
                }
            }
        },
        else => return self.fail("TODO implement function parameters for {} on sparc64", .{cc}),
    }

    return result;
}

fn resolveInst(self: *Self, ref: Air.Inst.Ref) InnerError!MCValue {
    const pt = self.pt;
    const ty = self.typeOf(ref);

    // If the type has no codegen bits, no need to store it.
    if (!ty.hasRuntimeBitsIgnoreComptime(pt.zcu)) return .none;

    if (ref.toIndex()) |inst| {
        return self.getResolvedInstValue(inst);
    }

    return self.genTypedValue((try self.air.value(ref, pt)).?);
}

fn ret(self: *Self, mcv: MCValue) !void {
    const pt = self.pt;
    const zcu = pt.zcu;
    const ret_ty = self.fn_type.fnReturnType(zcu);
    try self.setRegOrMem(ret_ty, self.ret_mcv, mcv);

    // Just add space for a branch instruction, patch this later
    const index = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });

    // Reserve space for the delay slot too
    // TODO find out a way to fill this
    _ = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });
    try self.exitlude_jump_relocs.append(self.gpa, index);
}

fn reuseOperand(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, op_index: Liveness.OperandInt, mcv: MCValue) bool {
    if (!self.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register => |reg| {
            // If it's in the registers table, need to associate the register with the
            // new instruction.
            if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
                if (!self.register_manager.isRegFree(reg)) {
                    self.register_manager.registers[index] = inst;
                }
            }
            log.debug("%{d} => {} (reused)", .{ inst, reg });
        },
        .stack_offset => |off| {
            log.debug("%{d} => stack offset {d} (reused)", .{ inst, off });
        },
        else => return false,
    }

    // Prevent the operand deaths processing code from deallocating it.
    self.reused_operands.set(op_index);

    // That makes us responsible for doing the rest of the stuff that processDeath would have done.
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    branch.inst_table.putAssumeCapacity(operand.toIndex().?, .dead);

    return true;
}

/// Sets the value without any modifications to register allocation metadata or stack allocation metadata.
fn setRegOrMem(self: *Self, ty: Type, loc: MCValue, val: MCValue) !void {
    switch (loc) {
        .none => return,
        .register => |reg| return self.genSetReg(ty, reg, val),
        .stack_offset => |off| return self.genSetStack(ty, off, val),
        .memory => {
            return self.fail("TODO implement setRegOrMem for memory", .{});
        },
        else => unreachable,
    }
}

/// Save the current instruction stored in the condition flags if
/// occupied
fn spillConditionFlagsIfOccupied(self: *Self) !void {
    if (self.condition_flags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save);
        const new_mcv = switch (mcv) {
            .condition_flags => try self.allocRegOrMem(inst_to_save, true),
            .register_with_overflow => try self.allocRegOrMem(inst_to_save, false),
            else => unreachable, // mcv doesn't occupy the compare flags
        };

        try self.setRegOrMem(self.typeOfIndex(inst_to_save), new_mcv, mcv);
        log.debug("spilling {d} to mcv {any}", .{ inst_to_save, new_mcv });

        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        try branch.inst_table.put(self.gpa, inst_to_save, new_mcv);

        self.condition_flags_inst = null;

        // TODO consolidate with register manager and spillInstruction
        // this call should really belong in the register manager!
        switch (mcv) {
            .register_with_overflow => |rwo| self.register_manager.freeReg(rwo.reg),
            else => {},
        }
    }
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(inst, false);
    log.debug("spilling {d} to stack mcv {any}", .{ inst, stack_mcv });
    const reg_mcv = self.getResolvedInstValue(inst);
    assert(reg == reg_mcv.register);
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
}

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    const pt = self.pt;
    const abi_size = value_ty.abiSize(pt.zcu);

    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .condition_flags,
        .condition_register,
        .register_with_overflow,
        => unreachable, // cannot hold an address
        .immediate => |imm| {
            try self.setRegOrMem(value_ty, .{ .memory = imm }, value);
        },
        .ptr_stack_offset => |off| {
            try self.genSetStack(value_ty, off, value);
        },
        .register => |addr_reg| {
            const addr_reg_lock = self.register_manager.lockReg(addr_reg);
            defer if (addr_reg_lock) |reg| self.register_manager.unlockReg(reg);

            switch (value) {
                .register => |value_reg| {
                    try self.genStore(value_reg, addr_reg, i13, 0, abi_size);
                },
                else => {
                    return self.fail("TODO implement copying of memory", .{});
                },
            }
        },
        .memory,
        .stack_offset,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.store(.{ .register = addr_reg }, value, ptr_ty, value_ty);
        },
    }
}

fn structFieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, index: u32) !MCValue {
    return if (self.liveness.isUnused(inst)) .dead else result: {
        const pt = self.pt;
        const zcu = pt.zcu;
        const mcv = try self.resolveInst(operand);
        const ptr_ty = self.typeOf(operand);
        const struct_ty = ptr_ty.childType(zcu);
        const struct_field_offset = @as(u32, @intCast(struct_ty.structFieldOffset(index, zcu)));
        switch (mcv) {
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off - struct_field_offset };
            },
            else => {
                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = struct_field_offset,
                });
                const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
                defer self.register_manager.unlockReg(offset_reg_lock);

                const addr_reg = try self.copyToTmpRegister(ptr_ty, mcv);
                const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
                defer self.register_manager.unlockReg(addr_reg_lock);

                const dest = try self.binOp(
                    .add,
                    .{ .register = addr_reg },
                    .{ .register = offset_reg },
                    Type.usize,
                    Type.usize,
                    null,
                );

                break :result dest;
            },
        }
    };
}

fn trunc(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    operand: MCValue,
    operand_ty: Type,
    dest_ty: Type,
) !MCValue {
    const pt = self.pt;
    const zcu = pt.zcu;
    const info_a = operand_ty.intInfo(zcu);
    const info_b = dest_ty.intInfo(zcu);

    if (info_b.bits <= 64) {
        const operand_reg = switch (operand) {
            .register => |r| r,
            else => operand_reg: {
                if (info_a.bits <= 64) {
                    const reg = try self.copyToTmpRegister(operand_ty, operand);
                    break :operand_reg reg;
                } else {
                    return self.fail("TODO load least significant word into register", .{});
                }
            },
        };
        const lock = self.register_manager.lockReg(operand_reg);
        defer if (lock) |reg| self.register_manager.unlockReg(reg);

        const dest_reg = if (maybe_inst) |inst| blk: {
            const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

            if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                break :blk operand_reg;
            } else {
                const reg = try self.register_manager.allocReg(inst, gp);
                break :blk reg;
            }
        } else blk: {
            const reg = try self.register_manager.allocReg(null, gp);
            break :blk reg;
        };

        try self.truncRegister(operand_reg, dest_reg, info_b.signedness, info_b.bits);

        return MCValue{ .register = dest_reg };
    } else {
        return self.fail("TODO: truncate to ints > 64 bits", .{});
    }
}

fn truncRegister(
    self: *Self,
    operand_reg: Register,
    dest_reg: Register,
    int_signedness: std.builtin.Signedness,
    int_bits: u16,
) !void {
    switch (int_bits) {
        1...31, 33...63 => {
            _ = try self.addInst(.{
                .tag = .sllx,
                .data = .{
                    .shift = .{
                        .is_imm = true,
                        .rd = dest_reg,
                        .rs1 = operand_reg,
                        .rs2_or_imm = .{ .imm = @as(u6, @intCast(64 - int_bits)) },
                    },
                },
            });
            _ = try self.addInst(.{
                .tag = switch (int_signedness) {
                    .signed => .srax,
                    .unsigned => .srlx,
                },
                .data = .{
                    .shift = .{
                        .is_imm = true,
                        .rd = dest_reg,
                        .rs1 = dest_reg,
                        .rs2_or_imm = .{ .imm = @as(u6, @intCast(int_bits)) },
                    },
                },
            });
        },
        32 => {
            _ = try self.addInst(.{
                .tag = switch (int_signedness) {
                    .signed => .sra,
                    .unsigned => .srl,
                },
                .data = .{
                    .shift = .{
                        .is_imm = true,
                        .rd = dest_reg,
                        .rs1 = operand_reg,
                        .rs2_or_imm = .{ .imm = 0 },
                    },
                },
            });
        },
        64 => {
            if (dest_reg == operand_reg)
                return; // Copy register to itself; nothing to do.
            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{
                    .arithmetic_2op = .{
                        .is_imm = false,
                        .rs1 = dest_reg,
                        .rs2_or_imm = .{ .rs2 = operand_reg },
                    },
                },
            });
        },
        else => unreachable,
    }
}

/// TODO support scope overrides. Also note this logic is duplicated with `Zcu.wantSafety`.
fn wantSafety(self: *Self) bool {
    return switch (self.bin_file.comp.root_mod.optimize_mode) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

fn typeOf(self: *Self, inst: Air.Inst.Ref) Type {
    return self.air.typeOf(inst, &self.pt.zcu.intern_pool);
}

fn typeOfIndex(self: *Self, inst: Air.Inst.Index) Type {
    return self.air.typeOfIndex(inst, &self.pt.zcu.intern_pool);
}
