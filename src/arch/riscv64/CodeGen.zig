const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Air = @import("../../Air.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Type = @import("../../type.zig").Type;
const Value = @import("../../Value.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const InternPool = @import("../../InternPool.zig");
const Compilation = @import("../../Compilation.zig");
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("../../tracy.zig").trace;
const DW = std.dwarf;
const leb128 = std.leb;
const log = std.log.scoped(.codegen);
const build_options = @import("build_options");
const codegen = @import("../../codegen.zig");
const Alignment = InternPool.Alignment;

const CodeGenError = codegen.CodeGenError;
const Result = codegen.Result;
const DebugInfoOutput = codegen.DebugInfoOutput;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const Instruction = abi.Instruction;
const callee_preserved_regs = abi.callee_preserved_regs;
const gp = abi.RegisterClass.gp;

const InnerError = CodeGenError || error{OutOfRegisters};

gpa: Allocator,
air: Air,
liveness: Liveness,
bin_file: *link.File,
target: *const std.Target,
func_index: InternPool.Index,
code: *std.ArrayList(u8),
debug_output: DebugInfoOutput,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: MCValue,
fn_type: Type,
arg_index: usize,
src_loc: Module.SrcLoc,
stack_align: Alignment,

/// MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// MIR extra data
mir_extra: std.ArrayListUnmanaged(u32) = .{},

/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,

/// The value is an offset into the `Function` `code` from the beginning.
/// To perform the reloc, write 32-bit signed little-endian integer
/// which is a relative jump, based on the address following the reloc.
exitlude_jump_relocs: std.ArrayListUnmanaged(usize) = .{},

/// Whenever there is a runtime branch, we push a Branch onto this stack,
/// and pop it off when the runtime branch joins. This provides an "overlay"
/// of the table of mappings from instructions to `MCValue` from within the branch.
/// This way we can modify the `MCValue` for an instruction in different ways
/// within different branches. Special consideration is needed when a branch
/// joins with its parent, to make sure all instructions have the same MCValue
/// across each runtime branch upon joining.
branch_stack: *std.ArrayList(Branch),

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .{},

register_manager: RegisterManager = .{},
/// Maps offset to what is stored there.
stack: std.AutoHashMapUnmanaged(u32, StackAllocation) = .{},

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
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value is one of the stack variables.
    /// If the type is a pointer, it means the pointer address is in the stack at this offset.
    stack_offset: u32,
    /// The value is a pointer to one of the stack variables (payload is stack offset).
    ptr_stack_offset: u32,

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
    inst_table: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, MCValue) = .{},

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
    relocs: std.ArrayListUnmanaged(Reloc),
    /// The first break instruction encounters `null` here and chooses a
    /// machine code value for the block result, populating this field.
    /// Following break instructions encounter that value and use it for
    /// the location to store their block results.
    mcv: MCValue,
};

const Reloc = union(enum) {
    /// The value is an offset into the `Function` `code` from the beginning.
    /// To perform the reloc, write 32-bit signed little-endian integer
    /// which is a relative jump, based on the address following the reloc.
    rel32: usize,
    /// A branch in the ARM instruction set
    arm_branch: struct {
        pos: usize,
        cond: @import("../arm/bits.zig").Condition,
    },
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

const Self = @This();

pub fn generate(
    lf: *link.File,
    src_loc: Module.SrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    const gpa = lf.comp.gpa;
    const zcu = lf.comp.module.?;
    const func = zcu.funcInfo(func_index);
    const fn_owner_decl = zcu.declPtr(func.owner_decl);
    assert(fn_owner_decl.has_tv);
    const fn_type = fn_owner_decl.typeOf(zcu);
    const namespace = zcu.namespacePtr(fn_owner_decl.src_namespace);
    const target = &namespace.file_scope.mod.resolved_target.result;

    var branch_stack = std.ArrayList(Branch).init(gpa);
    defer {
        assert(branch_stack.items.len == 1);
        branch_stack.items[0].deinit(gpa);
        branch_stack.deinit();
    }
    try branch_stack.append(.{});

    var function = Self{
        .gpa = gpa,
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
        .fn_type = fn_type,
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

    var call_info = function.resolveCallingConventionValues(fn_type) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };
    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.stack_align = call_info.stack_align;
    function.max_end_stack = call_info.stack_byte_count;

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(gpa),
    };
    defer mir.deinit(gpa);

    var emit = Emit{
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
        error.EmitFail => return Result{ .fail = emit.err_msg.? },
        else => |e| return e,
    };

    if (function.err_msg) |em| {
        return Result{ .fail = em };
    } else {
        return Result.ok;
    }
}

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;

    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);

    const result_index: Mir.Inst.Index = @intCast(self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

pub fn addExtra(self: *Self, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try self.mir_extra.ensureUnusedCapacity(self.gpa, fields.len);
    return self.addExtraAssumeCapacity(extra);
}

pub fn addExtraAssumeCapacity(self: *Self, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result: u32 = @intCast(self.mir_extra.items.len);
    inline for (fields) |field| {
        self.mir_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            i32 => @bitCast(@field(extra, field.name)),
            else => @compileError("bad field type"),
        });
    }
    return result;
}

fn gen(self: *Self) !void {
    const mod = self.bin_file.comp.module.?;
    const cc = self.fn_type.fnCallingConvention(mod);
    if (cc != .Naked) {
        // TODO Finish function prologue and epilogue for riscv64.

        // TODO Backpatch stack offset
        // addi sp, sp, -16
        _ = try self.addInst(.{
            .tag = .addi,
            .data = .{ .i_type = .{
                .rd = .sp,
                .rs1 = .sp,
                .imm12 = -16,
            } },
        });

        // sd ra, 8(sp)
        _ = try self.addInst(.{
            .tag = .sd,
            .data = .{ .i_type = .{
                .rd = .ra,
                .rs1 = .sp,
                .imm12 = 8,
            } },
        });

        // sd s0, 0(sp)
        _ = try self.addInst(.{
            .tag = .sd,
            .data = .{ .i_type = .{
                .rd = .s0,
                .rs1 = .sp,
                .imm12 = 0,
            } },
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
            self.exitlude_jump_relocs.items[self.exitlude_jump_relocs.items.len - 1] == self.mir_instructions.len - 2)
        {
            // If the last Mir instruction (apart from the
            // dbg_epilogue_begin) is the last exitlude jump
            // relocation (which would just jump one instruction
            // further), it can be safely removed
            self.mir_instructions.orderedRemove(self.exitlude_jump_relocs.pop());
        }

        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            _ = jmp_reloc;
            return self.fail("TODO add branches in RISCV64", .{});
        }

        // ld ra, 8(sp)
        _ = try self.addInst(.{
            .tag = .ld,
            .data = .{ .i_type = .{
                .rd = .ra,
                .rs1 = .sp,
                .imm12 = 8,
            } },
        });

        // ld s0, 0(sp)
        _ = try self.addInst(.{
            .tag = .ld,
            .data = .{ .i_type = .{
                .rd = .s0,
                .rs1 = .sp,
                .imm12 = 0,
            } },
        });

        // addi sp, sp, 16
        _ = try self.addInst(.{
            .tag = .addi,
            .data = .{ .i_type = .{
                .rd = .sp,
                .rs1 = .sp,
                .imm12 = 16,
            } },
        });

        // ret
        _ = try self.addInst(.{
            .tag = .ret,
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
    const mod = self.bin_file.comp.module.?;
    const ip = &mod.intern_pool;
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        // TODO: remove now-redundant isUnused calls from AIR handler functions
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip))
            continue;

        const old_air_bookkeeping = self.air_bookkeeping;
        try self.ensureProcessDeathCapacity(Liveness.bpi);

        switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .ptr_add => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub => try self.airPtrArithmetic(inst, .ptr_sub),

            .add => try self.airBinOp(inst, .add),
            .sub => try self.airBinOp(inst, .sub),

            .add_safe,
            .sub_safe,
            .mul_safe,
            => return self.fail("TODO implement safety_checked_instructions", .{}),

            .add_wrap        => try self.airAddWrap(inst),
            .add_sat         => try self.airAddSat(inst),
            .sub_wrap        => try self.airSubWrap(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul             => try self.airMul(inst),
            .mul_wrap        => try self.airMulWrap(inst),
            .mul_sat         => try self.airMulSat(inst),
            .rem             => try self.airRem(inst),
            .mod             => try self.airMod(inst),
            .shl, .shl_exact => try self.airShl(inst),
            .shl_sat         => try self.airShlSat(inst),
            .min             => try self.airMin(inst),
            .max             => try self.airMax(inst),
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
            .floor,
            .ceil,
            .round,
            .trunc_float,
            .neg,
            => try self.airUnaryMath(inst),

            .add_with_overflow => try self.airAddWithOverflow(inst),
            .sub_with_overflow => try self.airSubWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airDiv(inst),

            .cmp_lt  => try self.airCmp(inst, .lt),
            .cmp_lte => try self.airCmp(inst, .lte),
            .cmp_eq  => try self.airCmp(inst, .eq),
            .cmp_gte => try self.airCmp(inst, .gte),
            .cmp_gt  => try self.airCmp(inst, .gt),
            .cmp_neq => try self.airCmp(inst, .neq),

            .cmp_vector => try self.airCmpVector(inst),
            .cmp_lt_errors_len => try self.airCmpLtErrorsLen(inst),

            .bool_and        => try self.airBoolOp(inst),
            .bool_or         => try self.airBoolOp(inst),
            .bit_and         => try self.airBitAnd(inst),
            .bit_or          => try self.airBitOr(inst),
            .xor             => try self.airXor(inst),
            .shr, .shr_exact => try self.airShr(inst),

            .alloc           => try self.airAlloc(inst),
            .ret_ptr         => try self.airRetPtr(inst),
            .arg             => try self.airArg(inst),
            .assembly        => try self.airAsm(inst),
            .bitcast         => try self.airBitCast(inst),
            .block           => try self.airBlock(inst),
            .br              => try self.airBr(inst),
            .trap            => try self.airTrap(),
            .breakpoint      => try self.airBreakpoint(),
            .ret_addr        => try self.airRetAddr(inst),
            .frame_addr      => try self.airFrameAddress(inst),
            .fence           => try self.airFence(),
            .cond_br         => try self.airCondBr(inst),
            .fptrunc         => try self.airFptrunc(inst),
            .fpext           => try self.airFpext(inst),
            .intcast         => try self.airIntCast(inst),
            .trunc           => try self.airTrunc(inst),
            .int_from_bool     => try self.airIntFromBool(inst),
            .is_non_null     => try self.airIsNonNull(inst),
            .is_non_null_ptr => try self.airIsNonNullPtr(inst),
            .is_null         => try self.airIsNull(inst),
            .is_null_ptr     => try self.airIsNullPtr(inst),
            .is_non_err      => try self.airIsNonErr(inst),
            .is_non_err_ptr  => try self.airIsNonErrPtr(inst),
            .is_err          => try self.airIsErr(inst),
            .is_err_ptr      => try self.airIsErrPtr(inst),
            .load            => try self.airLoad(inst),
            .loop            => try self.airLoop(inst),
            .not             => try self.airNot(inst),
            .int_from_ptr        => try self.airIntFromPtr(inst),
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
            .cmpxchg_strong  => try self.airCmpxchg(inst),
            .cmpxchg_weak    => try self.airCmpxchg(inst),
            .atomic_rmw      => try self.airAtomicRmw(inst),
            .atomic_load     => try self.airAtomicLoad(inst),
            .memcpy          => try self.airMemcpy(inst),
            .memset          => try self.airMemset(inst, false),
            .memset_safe     => try self.airMemset(inst, true),
            .set_union_tag   => try self.airSetUnionTag(inst),
            .get_union_tag   => try self.airGetUnionTag(inst),
            .clz             => try self.airClz(inst),
            .ctz             => try self.airCtz(inst),
            .popcount        => try self.airPopcount(inst),
            .abs             => try self.airAbs(inst),
            .byte_swap       => try self.airByteSwap(inst),
            .bit_reverse     => try self.airBitReverse(inst),
            .tag_name        => try self.airTagName(inst),
            .error_name      => try self.airErrorName(inst),
            .splat           => try self.airSplat(inst),
            .select          => try self.airSelect(inst),
            .shuffle         => try self.airShuffle(inst),
            .reduce          => try self.airReduce(inst),
            .aggregate_init  => try self.airAggregateInit(inst),
            .union_init      => try self.airUnionInit(inst),
            .prefetch        => try self.airPrefetch(inst),
            .mul_add         => try self.airMulAdd(inst),
            .addrspace_cast  => @panic("TODO"),

            .@"try"          => @panic("TODO"),
            .try_ptr         => @panic("TODO"),

            .dbg_stmt         => try self.airDbgStmt(inst),
            .dbg_inline_block => try self.airDbgInlineBlock(inst),
            .dbg_var_ptr,
            .dbg_var_val,
            => try self.airDbgVar(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .atomic_store_unordered => try self.airAtomicStore(inst, .unordered),
            .atomic_store_monotonic => try self.airAtomicStore(inst, .monotonic),
            .atomic_store_release   => try self.airAtomicStore(inst, .release),
            .atomic_store_seq_cst   => try self.airAtomicStore(inst, .seq_cst),

            .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
            .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
            .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
            .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

            .field_parent_ptr => try self.airFieldParentPtr(inst),

            .switch_br       => try self.airSwitch(inst),
            .slice_ptr       => try self.airSlicePtr(inst),
            .slice_len       => try self.airSliceLen(inst),

            .ptr_slice_len_ptr => try self.airPtrSliceLenPtr(inst),
            .ptr_slice_ptr_ptr => try self.airPtrSlicePtrPtr(inst),

            .array_elem_val      => try self.airArrayElemVal(inst),
            .slice_elem_val      => try self.airSliceElemVal(inst),
            .slice_elem_ptr      => try self.airSliceElemPtr(inst),
            .ptr_elem_val        => try self.airPtrElemVal(inst),
            .ptr_elem_ptr        => try self.airPtrElemPtr(inst),

            .inferred_alloc, .inferred_alloc_comptime => unreachable,
            .unreach  => self.finishAirBookkeeping(),

            .optional_payload           => try self.airOptionalPayload(inst),
            .optional_payload_ptr       => try self.airOptionalPayloadPtr(inst),
            .optional_payload_ptr_set   => try self.airOptionalPayloadPtrSet(inst),
            .unwrap_errunion_err        => try self.airUnwrapErrErr(inst),
            .unwrap_errunion_payload    => try self.airUnwrapErrPayload(inst),
            .unwrap_errunion_err_ptr    => try self.airUnwrapErrErrPtr(inst),
            .unwrap_errunion_payload_ptr=> try self.airUnwrapErrPayloadPtr(inst),
            .errunion_payload_ptr_set   => try self.airErrUnionPayloadPtrSet(inst),
            .err_return_trace           => try self.airErrReturnTrace(inst),
            .set_err_return_trace       => try self.airSetErrReturnTrace(inst),
            .save_err_return_trace_index=> try self.airSaveErrReturnTraceIndex(inst),

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
            => return self.fail("TODO implement optimized float mode", .{}),

            .is_named_enum_value => return self.fail("TODO implement is_named_enum_value", .{}),
            .error_set_has_value => return self.fail("TODO implement error_set_has_value", .{}),
            .vector_store_elem => return self.fail("TODO implement vector_store_elem", .{}),

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
        if (std.debug.runtime_safety) {
            if (self.air_bookkeeping < old_air_bookkeeping + 1) {
                std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, air_tags[@intFromEnum(inst)] });
            }
        }
    }
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) void {
    // When editing this function, note that the logic must synchronize with `reuseOperand`.
    const prev_value = self.getResolvedInstValue(inst);
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    branch.inst_table.putAssumeCapacity(inst, .dead);
    switch (prev_value) {
        .register => |reg| {
            self.register_manager.freeReg(reg);
        },
        else => {}, // TODO process stack allocation death
    }
}

/// Called when there are no operands, and the instruction is always unreferenced.
fn finishAirBookkeeping(self: *Self) void {
    if (std.debug.runtime_safety) {
        self.air_bookkeeping += 1;
    }
}

fn finishAir(self: *Self, inst: Air.Inst.Index, result: MCValue, operands: [Liveness.bpi - 1]Air.Inst.Ref) void {
    var tomb_bits = self.liveness.getTombBits(inst);
    for (operands) |op| {
        const dies = @as(u1, @truncate(tomb_bits)) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        const op_index = op.toIndex() orelse continue;
        self.processDeath(op_index);
    }
    const is_used = @as(u1, @truncate(tomb_bits)) == 0;
    if (is_used) {
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

fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
    const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
    try table.ensureUnusedCapacity(self.gpa, additional_count);
}

fn allocMem(self: *Self, inst: Air.Inst.Index, abi_size: u32, abi_align: Alignment) !u32 {
    self.stack_align = self.stack_align.max(abi_align);
    // TODO find a free slot instead of always appending
    const offset: u32 = @intCast(abi_align.forward(self.next_stack_offset));
    self.next_stack_offset = offset + abi_size;
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
    const mod = self.bin_file.comp.module.?;
    const elem_ty = self.typeOfIndex(inst).childType(mod);
    const abi_size = math.cast(u32, elem_ty.abiSize(mod)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(mod);
    return self.allocMem(inst, abi_size, abi_align);
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = self.typeOfIndex(inst);
    const abi_size = math.cast(u32, elem_ty.abiSize(mod)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    const abi_align = elem_ty.abiAlignment(mod);
    self.stack_align = self.stack_align.max(abi_align);

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        if (abi_size <= ptr_bytes) {
            if (self.register_manager.tryAllocReg(inst, gp)) |reg| {
                return MCValue{ .register = reg };
            }
        }
    }
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = stack_offset };
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

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null, gp);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToNewRegister(self: *Self, reg_owner: Air.Inst.Index, mcv: MCValue) !MCValue {
    const reg = try self.register_manager.allocReg(reg_owner, gp);
    try self.genSetReg(self.typeOfIndex(reg_owner), reg, mcv);
    return MCValue{ .register = reg };
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFptrunc for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFpext for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const mod = self.bin_file.comp.module.?;
    const operand_ty = self.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const info_a = operand_ty.intInfo(mod);
    const info_b = self.typeOfIndex(inst).intInfo(mod);
    if (info_a.signedness != info_b.signedness)
        return self.fail("TODO gen intcast sign safety in semantic analysis", .{});

    if (info_a.bits == info_b.bits)
        return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });

    return self.fail("TODO implement intCast for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand = try self.resolveInst(ty_op.operand);
    _ = operand;
    return self.fail("TODO implement trunc for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromBool(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement NOT for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airMin(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement min for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMax(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement max for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    const lhs_is_register = lhs == .register;
    const rhs_is_register = rhs == .register;

    const lhs_lock: ?RegisterLock = if (lhs_is_register)
        self.register_manager.lockReg(lhs.register)
    else
        null;
    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];

    const lhs_reg = if (lhs_is_register) lhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (maybe_inst) |inst| inst: {
            const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
            break :inst bin_op.lhs.toIndex().?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);

        if (track_inst) |inst| branch.inst_table.putAssumeCapacity(inst, .{ .register = reg });

        break :blk reg;
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_reg = if (rhs_is_register) rhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (maybe_inst) |inst| inst: {
            const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
            break :inst bin_op.rhs.toIndex().?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);

        if (track_inst) |inst| branch.inst_table.putAssumeCapacity(inst, .{ .register = reg });

        break :blk reg;
    };
    const new_rhs_lock = self.register_manager.lockReg(rhs_reg);
    defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = if (maybe_inst) |inst| blk: {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        if (lhs_is_register and self.reuseOperand(inst, bin_op.lhs, 0, lhs)) {
            break :blk lhs_reg;
        } else if (rhs_is_register and self.reuseOperand(inst, bin_op.rhs, 1, rhs)) {
            break :blk rhs_reg;
        } else {
            break :blk try self.register_manager.allocReg(inst, gp);
        }
    } else try self.register_manager.allocReg(null, gp);

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);
    if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

    const mir_tag: Mir.Inst.Tag = switch (tag) {
        .add => .add,
        .sub => .sub,
        else => unreachable,
    };
    const mir_data: Mir.Inst.Data = switch (tag) {
        .add,
        .sub,
        => .{ .r_type = .{
            .rd = dest_reg,
            .rs1 = lhs_reg,
            .rs2 = rhs_reg,
        } },
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = mir_data,
    });

    return MCValue{ .register = dest_reg };
}

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
    maybe_inst: ?Air.Inst.Index,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (tag) {
        // Arithmetic operations on integers and floats
        .add,
        .sub,
        => {
            switch (lhs_ty.zigTypeTag(mod)) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(mod);
                    if (int_info.bits <= 64) {
                        // TODO immediate operands
                        return try self.binOpRegister(tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => unreachable,
            }
        },
        .ptr_add,
        .ptr_sub,
        => {
            switch (lhs_ty.zigTypeTag(mod)) {
                .Pointer => {
                    const ptr_ty = lhs_ty;
                    const elem_ty = switch (ptr_ty.ptrSize(mod)) {
                        .One => ptr_ty.childType(mod).childType(mod), // ptr to array, so get array element type
                        else => ptr_ty.childType(mod),
                    };
                    const elem_size = elem_ty.abiSize(mod);

                    if (elem_size == 1) {
                        const base_tag: Air.Inst.Tag = switch (tag) {
                            .ptr_add => .add,
                            .ptr_sub => .sub,
                            else => unreachable,
                        };

                        return try self.binOpRegister(base_tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
                    } else {
                        return self.fail("TODO ptr_add with elem_size > 1", .{});
                    }
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.binOp(tag, inst, lhs, rhs, lhs_ty, rhs_ty);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.binOp(tag, inst, lhs, rhs, lhs_ty, rhs_ty);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement addwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement subwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMul(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mulwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airAddWithOverflow for {}", .{self.target.cpu.arch});
}

fn airSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSubWithOverflow for {}", .{self.target.cpu.arch});
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airMulWithOverflow for {}", .{self.target.cpu.arch});
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airShlWithOverflow for {}", .{self.target.cpu.arch});
}

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement rem for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mod for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitAnd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement bitwise and for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement bitwise or for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement xor for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> E
fn airUnwrapErrErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union error ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union payload ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .errunion_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airErrReturnTrace for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSetErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSetErrReturnTrace for {}", .{self.target.cpu.arch});
}

fn airSaveErrReturnTraceIndex(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSaveErrReturnTraceIndex for {}", .{self.target.cpu.arch});
}

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mod = self.bin_file.comp.module.?;
        const optional_ty = self.typeOfIndex(inst);

        // Optional with a zero-bit payload type is just a boolean true
        if (optional_ty.abiSize(mod) == 1)
            break :result MCValue{ .immediate = 1 };

        return self.fail("TODO implement wrap optional for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement wrap errunion payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement wrap errunion error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_len for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_slice_len_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_slice_ptr_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement array_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    _ = bin_op;
    return self.fail("TODO implement airSetUnionTag for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airAbs(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airAbs for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airByteSwap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airUnaryMath for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
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
    self.liveness.clearOperandDeath(inst, op_index);

    // That makes us responsible for doing the rest of the stuff that processDeath would have done.
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    branch.inst_table.putAssumeCapacity(operand.toIndex().?, .dead);

    return true;
}

fn load(self: *Self, dst_mcv: MCValue, ptr: MCValue, ptr_ty: Type) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = ptr_ty.childType(mod);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .immediate => |imm| try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm }),
        .ptr_stack_offset => |off| try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off }),
        .register => {
            return self.fail("TODO implement loading from MCValue.register", .{});
        },
        .memory,
        .stack_offset,
        => {
            const reg = try self.register_manager.allocReg(null, gp);
            const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
            defer self.register_manager.unlockReg(reg_lock);

            try self.genSetReg(ptr_ty, reg, ptr);
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const elem_ty = self.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBits(mod))
            break :result MCValue.none;

        const ptr = try self.resolveInst(ty_op.operand);
        const is_volatile = self.typeOf(ty_op.operand).isVolatilePtr(mod);
        if (self.liveness.isUnused(inst) and !is_volatile)
            break :result MCValue.dead;

        const dst_mcv: MCValue = blk: {
            if (self.reuseOperand(inst, ty_op.operand, 0, ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(dst_mcv, ptr, self.typeOf(ty_op.operand));
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) !void {
    _ = ptr_ty;

    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(value_ty, .{ .memory = imm }, value);
        },
        .ptr_stack_offset => |off| {
            try self.genSetStack(value_ty, off, value);
        },
        .register => {
            return self.fail("TODO implement storing to MCValue.register", .{});
        },
        .memory => {
            return self.fail("TODO implement storing to MCValue.memory", .{});
        },
        .stack_offset => {
            return self.fail("TODO implement storing to MCValue.stack_offset", .{});
        },
    }
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
    return self.structFieldPtr(extra.struct_operand, ty_pl.ty, extra.field_index);
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    return self.structFieldPtr(ty_op.operand, ty_op.ty, index);
}
fn structFieldPtr(self: *Self, operand: Air.Inst.Ref, ty: Air.Inst.Ref, index: u32) !void {
    _ = operand;
    _ = ty;
    _ = index;
    return self.fail("TODO implement codegen struct_field_ptr", .{});
    //return self.finishAir(inst, result, .{ extra.struct_ptr, .none, .none });
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement codegen struct_field_val", .{});
    //return self.finishAir(inst, result, .{ extra.struct_ptr, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement codegen airFieldParentPtr", .{});
}

fn genArgDbgInfo(self: Self, inst: Air.Inst.Index, mcv: MCValue) !void {
    const mod = self.bin_file.comp.module.?;
    const arg = self.air.instructions.items(.data)[@intFromEnum(inst)].arg;
    const ty = arg.ty.toType();
    const owner_decl = mod.funcOwnerDeclIndex(self.func_index);
    const name = mod.getParamName(self.func_index, arg.src_index);

    switch (self.debug_output) {
        .dwarf => |dw| switch (mcv) {
            .register => |reg| try dw.genArgDbgInfo(name, ty, owner_decl, .{
                .register = reg.dwarfLocOp(),
            }),
            .stack_offset => {},
            else => {},
        },
        .plan9 => {},
        .none => {},
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.typeOfIndex(inst);
    _ = ty;

    const result = self.args[arg_index];
    // TODO support stack-only arguments
    // TODO Copy registers to the stack
    const mcv = result;
    try self.genArgDbgInfo(inst, mcv);

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

fn airTrap(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .unimp,
        .data = .{ .nop = {} },
    });
    return self.finishAirBookkeeping();
}

fn airBreakpoint(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .ebreak,
        .data = .{ .nop = {} },
    });
    return self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airRetAddr for riscv64", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFrameAddress for riscv64", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    const mod = self.bin_file.comp.module.?;
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for riscv64", .{});
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const fn_ty = self.typeOf(pl_op.operand);
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);

    var info = try self.resolveCallingConventionValues(fn_ty);
    defer info.deinit(self);

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        for (info.args, 0..) |mc_arg, arg_i| {
            const arg = args[arg_i];
            const arg_ty = self.typeOf(arg);
            const arg_mcv = try self.resolveInst(args[arg_i]);

            switch (mc_arg) {
                .none => continue,
                .undef => unreachable,
                .immediate => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .memory => unreachable,
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
            }
        }

        if (try self.air.value(callee, mod)) |func_value| {
            switch (mod.intern_pool.indexToKey(func_value.ip_index)) {
                .func => |func| {
                    const sym_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, func.owner_decl);
                    const sym = elf_file.symbol(sym_index);
                    _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);
                    const got_addr: u32 = @intCast(sym.zigGotAddress(elf_file));
                    try self.genSetReg(Type.usize, .ra, .{ .memory = got_addr });
                    _ = try self.addInst(.{
                        .tag = .jalr,
                        .data = .{ .i_type = .{
                            .rd = .ra,
                            .rs1 = .ra,
                            .imm12 = 0,
                        } },
                    });
                },
                .extern_func => {
                    return self.fail("TODO implement calling extern functions", .{});
                },
                else => {
                    return self.fail("TODO implement calling bitcasted functions", .{});
                },
            }
        } else {
            return self.fail("TODO implement calling runtime-known function pointer", .{});
        }
    } else if (self.bin_file.cast(link.File.Coff)) |_| {
        return self.fail("TODO implement calling in COFF for {}", .{self.target.cpu.arch});
    } else if (self.bin_file.cast(link.File.MachO)) |_| {
        unreachable; // unsupported architecture for MachO
    } else if (self.bin_file.cast(link.File.Plan9)) |_| {
        return self.fail("TODO implement call on plan9 for {}", .{self.target.cpu.arch});
    } else unreachable;

    const result: MCValue = result: {
        switch (info.return_value) {
            .register => |reg| {
                if (RegisterManager.indexOfReg(&callee_preserved_regs, reg) == null) {
                    // Save function return value in a callee saved register
                    break :result try self.copyToNewRegister(inst, info.return_value);
                }
            },
            else => {},
        }
        break :result info.return_value;
    };

    if (args.len <= Liveness.bpi - 2) {
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

fn ret(self: *Self, mcv: MCValue) !void {
    const mod = self.bin_file.comp.module.?;
    const ret_ty = self.fn_type.fnReturnType(mod);
    try self.setRegOrMem(ret_ty, self.ret_mcv, mcv);
    // Just add space for an instruction, patch this later
    const index = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });
    try self.exitlude_jump_relocs.append(self.gpa, index);
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

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    const ty = self.typeOf(bin_op.lhs);
    const mod = self.bin_file.comp.module.?;
    assert(ty.eql(self.typeOf(bin_op.rhs), mod));
    if (ty.zigTypeTag(mod) == .ErrorSet)
        return self.fail("TODO implement cmp for errors", .{});

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    _ = op;
    _ = lhs;
    _ = rhs;

    return self.fail("TODO implement cmp for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airCmpVector(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airCmpVector for {}", .{self.target.cpu.arch});
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    _ = operand;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCmpLtErrorsLen for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;

    _ = try self.addInst(.{
        .tag = .dbg_line,
        .data = .{ .dbg_line_column = .{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        } },
    });

    return self.finishAirBookkeeping();
}

fn airDbgInlineBlock(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    const func = mod.funcInfo(extra.data.func);
    // TODO emit debug info for function change
    _ = func;
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const name = self.air.nullTerminatedString(pl_op.payload);
    const operand = pl_op.operand;
    // TODO emit debug info for this variable
    _ = name;
    return self.finishAir(inst, .dead, .{ operand, .none, .none });
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;

    return self.fail("TODO implement condbr {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, .unreach, .{ pl_op.operand, .none, .none });
}

fn isNull(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNonNull and invert the result.
    return self.fail("TODO call isNonNull and invert the result", .{});
}

fn isNonNull(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNull and invert the result.
    return self.fail("TODO call isNull and invert the result", .{});
}

fn isErr(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNonNull and invert the result.
    return self.fail("TODO call isNonErr and invert the result", .{});
}

fn isNonErr(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNull and invert the result.
    return self.fail("TODO call isErr and invert the result", .{});
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
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

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNonErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isNonErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);
    const start_index = self.code.items.len;
    try self.genBody(body);
    try self.jump(start_index);
    return self.finishAirBookkeeping();
}

/// Send control flow to the `index` of `self.code`.
fn jump(self: *Self, index: usize) !void {
    _ = index;
    return self.fail("TODO implement jump for {}", .{self.target.cpu.arch});
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

    for (self.blocks.getPtr(inst).?.relocs.items) |reloc| try self.performReloc(reloc);

    const result = self.blocks.getPtr(inst).?.mcv;
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition = pl_op.operand;
    _ = condition;
    return self.fail("TODO airSwitch for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, .dead, .{ condition, .none, .none });
}

fn performReloc(self: *Self, reloc: Reloc) !void {
    _ = self;
    switch (reloc) {
        .rel32 => unreachable,
        .arm_branch => unreachable,
    }
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const branch = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn airBoolOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const air_tags = self.air.instructions.items(.tag);
    _ = air_tags;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement boolean operations for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const block_data = self.blocks.getPtr(block).?;

    const mod = self.bin_file.comp.module.?;
    if (self.typeOf(operand).hasRuntimeBits(mod)) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = operand_mcv;
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

    return self.fail("TODO implement brvoid for {}", .{self.target.cpu.arch});
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
    const clobbers_len: u31 = @truncate(extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]);
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

        if (mem.eql(u8, asm_source, "ecall")) {
            _ = try self.addInst(.{
                .tag = .ecall,
                .data = .{ .nop = {} },
            });
        } else {
            return self.fail("TODO implement support for more riscv64 assembly instructions", .{});
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

fn iterateBigTomb(self: *Self, inst: Air.Inst.Index, operand_count: usize) !BigTomb {
    try self.ensureProcessDeathCapacity(operand_count + 1);
    return BigTomb{
        .function = self,
        .inst = inst,
        .lbt = self.liveness.iterateBigTomb(inst),
    };
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

fn genSetStack(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    _ = ty;
    _ = stack_offset;
    _ = mcv;
    return self.fail("TODO implement getSetStack for {}", .{self.target.cpu.arch});
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    switch (mcv) {
        .dead => unreachable,
        .ptr_stack_offset => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .immediate => |unsigned_x| {
            const x: i64 = @bitCast(unsigned_x);
            if (math.minInt(i12) <= x and x <= math.maxInt(i12)) {
                _ = try self.addInst(.{
                    .tag = .addi,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = .zero,
                        .imm12 = @intCast(x),
                    } },
                });
            } else if (math.minInt(i32) <= x and x <= math.maxInt(i32)) {
                const lo12: i12 = @truncate(x);
                const carry: i32 = if (lo12 < 0) 1 else 0;
                const hi20: i20 = @truncate((x >> 12) +% carry);

                // TODO: add test case for 32-bit immediate
                _ = try self.addInst(.{
                    .tag = .lui,
                    .data = .{ .u_type = .{
                        .rd = reg,
                        .imm20 = hi20,
                    } },
                });
                _ = try self.addInst(.{
                    .tag = .addi,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = reg,
                        .imm12 = lo12,
                    } },
                });
            } else {
                // li rd, immediate
                // "Myriad sequences"
                return self.fail("TODO genSetReg 33-64 bit immediates for riscv64", .{}); // glhf
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // mov reg, src_reg
            _ = try self.addInst(.{
                .tag = .mv,
                .data = .{ .rr = .{
                    .rd = reg,
                    .rs = src_reg,
                } },
            });
        },
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = addr });

            _ = try self.addInst(.{
                .tag = .ld,
                .data = .{ .i_type = .{
                    .rd = reg,
                    .rs1 = reg,
                    .imm12 = 0,
                } },
            });
            // LOAD imm=[i12 offset = 0], rs1 =

            // return self.fail("TODO implement genSetReg memory for riscv64");
        },
        else => return self.fail("TODO implement getSetReg for riscv64 {}", .{mcv}),
    }
}

fn airIntFromPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result = try self.resolveInst(un_op);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, operand)) break :result operand;

        const operand_lock = switch (operand) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dest = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(self.typeOfIndex(inst), dest, operand);
        break :result dest;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airArrayToSlice for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFloatFromInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFloatFromInt for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airIntFromFloat for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    _ = extra;
    return self.fail("TODO implement airCmpxchg for {}", .{
        self.target.cpu.arch,
    });
    // return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn airAtomicRmw(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airCmpxchg for {}", .{self.target.cpu.arch});
}

fn airAtomicLoad(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airAtomicLoad for {}", .{self.target.cpu.arch});
}

fn airAtomicStore(self: *Self, inst: Air.Inst.Index, order: std.builtin.AtomicOrder) !void {
    _ = inst;
    _ = order;
    return self.fail("TODO implement airAtomicStore for {}", .{self.target.cpu.arch});
}

fn airMemset(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    _ = inst;
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    return self.fail("TODO implement airMemset for {}", .{self.target.cpu.arch});
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airMemcpy for {}", .{self.target.cpu.arch});
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airTagName for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSelect for riscv64", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airShuffle for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airReduce for riscv64", .{});
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const vector_ty = self.typeOfIndex(inst);
    const len = vector_ty.vectorLen(mod);
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airAggregateInit for riscv64", .{});
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

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement airUnionInit for riscv64", .{});
    // return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        return self.fail("TODO implement airMulAdd for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.typeOf(inst);
    if (!inst_ty.hasRuntimeBits(mod))
        return MCValue{ .none = {} };

    const inst_index = inst.toIndex() orelse return self.genTypedValue((try self.air.value(inst, mod)).?);

    return self.getResolvedInstValue(inst_index);
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) MCValue {
    // Treat each stack item as a "layer" on top of the previous one.
    var i: usize = self.branch_stack.items.len;
    while (true) {
        i -= 1;
        if (self.branch_stack.items[i].inst_table.get(inst)) |mcv| {
            assert(mcv != .dead);
            return mcv;
        }
    }
}

fn genTypedValue(self: *Self, val: Value) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    const mcv: MCValue = switch (try codegen.genTypedValue(
        self.bin_file,
        self.src_loc,
        val,
        mod.funcOwnerDeclIndex(self.func_index),
    )) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .load_got, .load_symbol, .load_direct, .load_tlv => unreachable, // TODO
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

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(self: *Self, fn_ty: Type) !CallMCValues {
    const mod = self.bin_file.comp.module.?;
    const ip = &mod.intern_pool;
    const fn_info = mod.typeToFunc(fn_ty).?;
    const cc = fn_info.cc;
    var result: CallMCValues = .{
        .args = try self.gpa.alloc(MCValue, fn_info.param_types.len),
        // These undefined values must be populated before returning from this function.
        .return_value = undefined,
        .stack_byte_count = undefined,
        .stack_align = undefined,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = fn_ty.fnReturnType(mod);

    switch (cc) {
        .Naked => {
            assert(result.args.len == 0);
            result.return_value = .{ .unreach = {} };
            result.stack_byte_count = 0;
            result.stack_align = .@"1";
            return result;
        },
        .Unspecified, .C => {
            // LP64D ABI
            //
            // TODO make this generic with other ABIs, in particular
            // with different hardware floating-point calling
            // conventions
            var next_register: usize = 0;
            var next_stack_offset: u32 = 0;
            // TODO: this is never assigned, which is a bug, but I don't know how this code works
            // well enough to try and fix it. I *think* `next_register += next_stack_offset` is
            // supposed to be `next_stack_offset += param_size` in every case where it appears.
            _ = &next_stack_offset;

            const argument_registers = [_]Register{ .a0, .a1, .a2, .a3, .a4, .a5, .a6, .a7 };

            for (fn_info.param_types.get(ip), result.args) |ty, *result_arg| {
                const param_size: u32 = @intCast(Type.fromInterned(ty).abiSize(mod));
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
        },
        else => return self.fail("TODO implement function parameters for {} on riscv64", .{cc}),
    }

    if (ret_ty.zigTypeTag(mod) == .NoReturn) {
        result.return_value = .{ .unreach = {} };
    } else if (!ret_ty.hasRuntimeBits(mod)) {
        result.return_value = .{ .none = {} };
    } else switch (cc) {
        .Naked => unreachable,
        .Unspecified, .C => {
            const ret_ty_size: u32 = @intCast(ret_ty.abiSize(mod));
            if (ret_ty_size <= 8) {
                result.return_value = .{ .register = .a0 };
            } else if (ret_ty_size <= 16) {
                return self.fail("TODO support MCValue 2 registers", .{});
            } else {
                return self.fail("TODO support return by reference", .{});
            }
        },
        else => return self.fail("TODO implement function return values for {}", .{cc}),
    }
    return result;
}

/// TODO support scope overrides. Also note this logic is duplicated with `Module.wantSafety`.
fn wantSafety(self: *Self) bool {
    return switch (self.bin_file.comp.root_mod.optimize_mode) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

fn fail(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn failSymbol(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

fn typeOf(self: *Self, inst: Air.Inst.Ref) Type {
    const mod = self.bin_file.comp.module.?;
    return self.air.typeOf(inst, &mod.intern_pool);
}

fn typeOfIndex(self: *Self, inst: Air.Inst.Index) Type {
    const mod = self.bin_file.comp.module.?;
    return self.air.typeOfIndex(inst, &mod.intern_pool);
}
