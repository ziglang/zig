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
const callee_preserved_regs = abi.callee_preserved_regs;
/// General Purpose
const gp = abi.RegisterClass.gp;
/// Function Args
const fa = abi.RegisterClass.fa;

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

const SymbolOffset = struct { sym: u32, off: i32 = 0 };

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
    /// The value is in memory at an address not-yet-allocated by the linker.
    /// This traditionally corresponds to a relocation emitted in a relocatable object file.
    load_symbol: SymbolOffset,
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
            .load_symbol,
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
    /// TODO: make the size inferred from the bits of the inst
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
        .stack_size = @max(32, function.max_end_stack),
        .code_offset_mapping = .{},
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

fn addNop(self: *Self) error{OutOfMemory}!Mir.Inst.Index {
    return try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });
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
    _ = try self.addInst(.{
        .tag = .psuedo_prologue,
        .data = .{ .nop = {} }, // Backpatched later.
    });

    _ = try self.addInst(.{
        .tag = .dbg_prologue_end,
        .data = .{ .nop = {} },
    });

    try self.genBody(self.air.getMainBody());

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

            .cmp_lt  => try self.airCmp(inst),
            .cmp_lte => try self.airCmp(inst),
            .cmp_eq  => try self.airCmp(inst),
            .cmp_gte => try self.airCmp(inst),
            .cmp_gt  => try self.airCmp(inst),
            .cmp_neq => try self.airCmp(inst),

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
            .dbg_stmt        => try self.airDbgStmt(inst),
            .fptrunc         => try self.airFptrunc(inst),
            .fpext           => try self.airFpext(inst),
            .intcast         => try self.airIntCast(inst),
            .trunc           => try self.airTrunc(inst),
            .int_from_bool   => try self.airIntFromBool(inst),
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
            .int_from_ptr    => try self.airIntFromPtr(inst),
            .ret             => try self.airRet(inst, false),
            .ret_safe        => try self.airRet(inst, true),
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst, false),
            .store_safe      => try self.airStore(inst, true),
            .struct_field_ptr=> try self.airStructFieldPtr(inst),
            .struct_field_val=> try self.airStructFieldVal(inst),
            .array_to_slice  => try self.airArrayToSlice(inst),
            .float_from_int  => try self.airFloatFromInt(inst),
            .int_from_float  => try self.airIntFromFloat(inst),
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
            .addrspace_cast  => return self.fail("TODO: addrspace_cast", .{}),

            .@"try"          =>  return self.fail("TODO: try", .{}),
            .try_ptr         =>  return self.fail("TODO: try_ptr", .{}),

            .dbg_var_ptr,
            .dbg_var_val,
            => try self.airDbgVar(inst),

            .dbg_inline_block => try self.airDbgInlineBlock(inst),

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
    log.debug("airAlloc offset: {}", .{stack_offset});
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
        .cmp_eq => .cmp_eq,
        .cmp_gt => .cmp_gt,
        .shl => .sllw,
        .shr => .srlw,
        else => return self.fail("TODO: binOpRegister {s}", .{@tagName(tag)}),
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = .{
            .r_type = .{
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .rs2 = rhs_reg,
            },
        },
    });

    // generate the struct for OF checks

    return MCValue{ .register = dest_reg };
}

/// Don't call this function directly. Use binOp instead.
///
/// Call this function if rhs is an immediate. Generates I version of binops.
///
/// Asserts that rhs is an immediate MCValue
fn binOpImm(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    _ = rhs_ty;
    assert(rhs == .immediate);

    const lhs_is_register = lhs == .register;

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

    const dest_reg = if (maybe_inst) |inst| blk: {
        const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

        if (lhs_is_register and self.reuseOperand(inst, bin_op.lhs, 0, lhs)) {
            break :blk lhs_reg;
        } else {
            break :blk try self.register_manager.allocReg(inst, gp);
        }
    } else try self.register_manager.allocReg(null, gp);

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);

    const mir_tag: Mir.Inst.Tag = switch (tag) {
        .shl => .slli,
        .shr => .srli,
        else => return self.fail("TODO: binOpImm {s}", .{@tagName(tag)}),
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = .{
            .i_type = .{
                .rd = dest_reg,
                .rs1 = lhs_reg,
                .imm12 = math.cast(i12, rhs.immediate) orelse {
                    return self.fail("TODO: binOpImm larger than i12 i_type payload", .{});
                },
            },
        },
    });

    // generate the struct for OF checks

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
///
/// `maybe_inst` **needs** to be a bin_op, make sure of that.
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
        .cmp_eq,
        .cmp_neq,
        .cmp_gt,
        .cmp_gte,
        .cmp_lt,
        .cmp_lte,
        => {
            switch (lhs_ty.zigTypeTag(mod)) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(mod);
                    if (int_info.bits <= 64) {
                        if (rhs == .immediate) {
                            return self.binOpImm(tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
                        }
                        return self.binOpRegister(tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
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

        // These instructions have unsymteric bit sizes.
        .shr,
        .shl,
        => {
            switch (lhs_ty.zigTypeTag(mod)) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    const int_info = lhs_ty.intInfo(mod);
                    if (int_info.bits <= 64) {
                        if (rhs == .immediate) {
                            return self.binOpImm(tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
                        }
                        return self.binOpRegister(tag, maybe_inst, lhs, rhs, lhs_ty, rhs_ty);
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
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
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        break :result try self.binOp(.add, null, lhs, rhs, lhs_ty, rhs_ty);
    };

    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);
        const rhs_ty = self.typeOf(bin_op.rhs);
        break :result try self.binOp(.shl, inst, lhs, rhs, lhs_ty, rhs_ty);
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        break :result try self.slicePtr(mcv);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn slicePtr(self: *Self, mcv: MCValue) !MCValue {
    switch (mcv) {
        .dead, .unreach, .none => unreachable,
        .register => unreachable, // a slice doesn't fit in one register
        .stack_offset => |off| {
            return MCValue{ .stack_offset = off };
        },
        .memory => |addr| {
            return MCValue{ .memory = addr };
        },
        else => return self.fail("TODO slicePtr {s}", .{@tagName(mcv)}),
    }
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSliceLen for {}", .{self.target.cpu.arch});
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
    const mod = self.bin_file.comp.module.?;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const array_ty = self.typeOf(bin_op.lhs);
        const array_mcv = try self.resolveInst(bin_op.lhs);

        const index_mcv = try self.resolveInst(bin_op.rhs);

        const elem_ty = array_ty.childType(mod);
        const elem_abi_size = elem_ty.abiSize(mod);

        switch (array_mcv) {
            // all we need to do is calculate the offset that the elem exits at.
            .stack_offset => |off| {
                if (index_mcv == .immediate) {
                    const true_offset: u32 = @intCast(index_mcv.immediate * elem_abi_size);
                    break :result MCValue{ .stack_offset = off + true_offset };
                }
                return self.fail("TODO: airArrayElemVal with runtime index", .{});
            },
            else => return self.fail("TODO: airArrayElemVal {s}", .{@tagName(array_mcv)}),
        }
    };
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
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.typeOf(ty_op.operand);
        const scalar_ty = ty.scalarType(mod);
        const operand = try self.resolveInst(ty_op.operand);

        switch (scalar_ty.zigTypeTag(mod)) {
            .Int => if (ty.zigTypeTag(mod) == .Vector) {
                return self.fail("TODO implement airAbs for {}", .{ty.fmt(mod)});
            } else {
                const int_bits = ty.intInfo(mod).bits;

                if (int_bits > 32) {
                    return self.fail("TODO: airAbs for larger than 32 bits", .{});
                }

                // promote the src into a register
                const src_mcv = try self.copyToNewRegister(inst, operand);
                // temp register for shift
                const temp_reg = try self.register_manager.allocReg(inst, gp);

                _ = try self.addInst(.{
                    .tag = .abs,
                    .data = .{
                        .i_type = .{
                            .rs1 = src_mcv.register,
                            .rd = temp_reg,
                            .imm12 = @intCast(int_bits - 1),
                        },
                    },
                });

                break :result src_mcv;
            },
            else => return self.fail("TODO: implement airAbs {}", .{scalar_ty.fmt(mod)}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mod = self.bin_file.comp.module.?;
        const ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const int_bits = ty.intInfo(mod).bits;

        // bytes are no-op
        if (int_bits == 8 and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
            return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });
        }

        const dest_reg = try self.register_manager.allocReg(null, gp);
        try self.genSetReg(ty, dest_reg, operand);

        const dest_mcv: MCValue = .{ .register = dest_reg };

        switch (int_bits) {
            16 => {
                const temp = try self.binOp(.shr, null, dest_mcv, .{ .immediate = 8 }, ty, Type.u8);
                assert(temp == .register);
                _ = try self.addInst(.{
                    .tag = .slli,
                    .data = .{ .i_type = .{
                        .imm12 = 8,
                        .rd = dest_reg,
                        .rs1 = dest_reg,
                    } },
                });
                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{ .r_type = .{
                        .rd = dest_reg,
                        .rs1 = dest_reg,
                        .rs2 = temp.register,
                    } },
                });
            },
            else => return self.fail("TODO: {d} bits for airByteSwap", .{int_bits}),
        }

        break :result dest_mcv;
    };
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

fn load(self: *Self, dst_mcv: MCValue, src_ptr: MCValue, ptr_ty: Type) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = ptr_ty.childType(mod);

    switch (src_ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .immediate => |imm| try self.setValue(elem_ty, dst_mcv, .{ .memory = imm }),
        .ptr_stack_offset => |off| try self.setValue(elem_ty, dst_mcv, .{ .stack_offset = off }),
        .stack_offset,
        .register,
        => try self.setValue(elem_ty, dst_mcv, src_ptr),
        .memory => return self.fail("TODO: load memory", .{}),
        .load_symbol => {
            const reg = try self.copyToTmpRegister(ptr_ty, src_ptr);
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
                // TODO: set this to true, will need to implement register version of arrays and structs
                break :blk try self.allocRegOrMem(inst, false);
            }
        };
        try self.load(dst_mcv, ptr, self.typeOf(ty_op.operand));
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn store(self: *Self, dst_ptr: MCValue, src_val: MCValue, ptr_ty: Type, value_ty: Type) !void {
    _ = ptr_ty;

    log.debug("storing {s}", .{@tagName(dst_ptr)});

    switch (dst_ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .ptr_stack_offset => |off| try self.genSetStack(value_ty, off, src_val),
        else => return self.fail("TODO implement storing to MCValue.{s}", .{@tagName(dst_ptr)}),
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
    const result = try self.structFieldPtr(inst, extra.struct_operand, ty_pl.ty, extra.field_index);
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = try self.structFieldPtr(inst, ty_op.operand, ty_op.ty, index);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn structFieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, ty: Air.Inst.Ref, index: u32) !MCValue {
    _ = inst;
    _ = operand;
    _ = ty;
    _ = index;

    return self.fail("TODO: structFieldPtr", .{});
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mod = self.bin_file.comp.module.?;
        const src_mcv = try self.resolveInst(operand);
        const struct_ty = self.typeOf(operand);
        const field_ty = struct_ty.structFieldType(index, mod);
        if (!field_ty.hasRuntimeBitsIgnoreComptime(mod)) break :result .none;

        const field_off: u32 = switch (struct_ty.containerLayout(mod)) {
            .Auto, .Extern => @intCast(struct_ty.structFieldOffset(index, mod) * 8),
            .Packed => if (mod.typeToStruct(struct_ty)) |struct_type|
                mod.structPackedFieldBitOffset(struct_type, index)
            else
                0,
        };

        switch (src_mcv) {
            .dead, .unreach => unreachable,
            .register => |src_reg| {
                const src_reg_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_reg_lock);

                const dst_reg = if (field_off == 0)
                    (try self.copyToNewRegister(inst, src_mcv)).register
                else
                    try self.copyToTmpRegister(Type.usize, .{ .register = src_reg });

                const dst_mcv: MCValue = .{ .register = dst_reg };
                const dst_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                if (field_off > 0) {
                    _ = try self.addInst(.{
                        .tag = .srli,
                        .data = .{
                            .i_type = .{
                                .imm12 = @intCast(field_off),
                                .rd = dst_reg,
                                .rs1 = dst_reg,
                            },
                        },
                    });

                    return self.fail("TODO: airStructFieldVal register with field_off > 0", .{});
                }

                break :result if (field_off == 0) dst_mcv else try self.copyToNewRegister(inst, dst_mcv);
            },
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off + field_off };
            },
            else => return self.fail("TODO: airStructField {s}", .{@tagName(src_mcv)}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
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
    var arg_index = self.arg_index;

    // we skip over args that have no bits
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const src_mcv = self.args[arg_index];

        const dst_mcv = switch (src_mcv) {
            .register => |src_reg| dst: {
                try self.register_manager.getReg(src_reg, inst);
                break :dst src_mcv;
            },
            else => return self.fail("TODO: airArg {s}", .{@tagName(src_mcv)}),
        };

        try self.genArgDbgInfo(inst, src_mcv);
        break :result dst_mcv;
    };

    return self.finishAir(inst, result, .{ .none, .none, .none });
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
            try self.setValue(arg_ty, mc_arg, arg_mcv);
        }

        if (try self.air.value(callee, mod)) |func_value| {
            switch (mod.intern_pool.indexToKey(func_value.ip_index)) {
                .func => |func| {
                    const sym_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, func.owner_decl);
                    const sym = elf_file.symbol(sym_index);
                    _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);
                    const got_addr = sym.zigGotAddress(elf_file);
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
    try self.setValue(ret_ty, self.ret_mcv, mcv);

    // Just add space for an instruction, patch this later
    const index = try self.addInst(.{
        .tag = .ret,
        .data = .{ .nop = {} },
    });

    try self.exitlude_jump_relocs.append(self.gpa, index);
}

fn airRet(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    if (safety) {
        // safe
    } else {
        // not safe
    }

    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);

    _ = try self.addInst(.{
        .tag = .dbg_epilogue_begin,
        .data = .{ .nop = {} },
    });

    _ = try self.addInst(.{
        .tag = .psuedo_epilogue,
        .data = .{ .nop = {} },
    });

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

fn airCmp(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
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
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result = try self.binOp(tag, null, lhs, rhs, lhs_ty, rhs_ty);

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    _ = extra;
    // TODO: emit debug info for this block
    return self.finishAir(inst, .dead, .{ .none, .none, .none });
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
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const cond_ty = self.typeOf(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_condbr = self.liveness.getCondBr(inst);

    // A branch to the false section. Uses beq
    const reloc = try self.condBr(cond_ty, cond);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (pl_op.operand.toIndex()) |op_index| {
            self.processDeath(op_index);
        }
    }

    // Save state
    const parent_next_stack_offset = self.next_stack_offset;
    const parent_free_registers = self.register_manager.free_registers;
    var parent_stack = try self.stack.clone(self.gpa);
    defer parent_stack.deinit(self.gpa);
    const parent_registers = self.register_manager.registers;

    try self.branch_stack.append(.{});
    errdefer {
        _ = self.branch_stack.pop();
    }

    try self.ensureProcessDeathCapacity(liveness_condbr.then_deaths.len);
    for (liveness_condbr.then_deaths) |operand| {
        self.processDeath(operand);
    }
    try self.genBody(then_body);
    // point at the to-be-generated else case
    try self.performReloc(reloc, @intCast(self.mir_instructions.len));

    // Revert to the previous register and stack allocation state.

    var saved_then_branch = self.branch_stack.pop();
    defer saved_then_branch.deinit(self.gpa);

    self.register_manager.registers = parent_registers;

    self.stack.deinit(self.gpa);
    self.stack = parent_stack;
    parent_stack = .{};

    self.next_stack_offset = parent_next_stack_offset;
    self.register_manager.free_registers = parent_free_registers;

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
        try self.setValue(self.typeOfIndex(else_key), canon_mcv, else_value);
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
        try self.setValue(self.typeOfIndex(then_key), parent_mcv, then_value);
        // TODO track the new register / stack allocation
    }

    {
        var item = self.branch_stack.pop();
        item.deinit(self.gpa);
    }
}

fn condBr(self: *Self, cond_ty: Type, condition: MCValue) !Mir.Inst.Index {
    _ = cond_ty;

    const reg = switch (condition) {
        .register => |r| r,
        else => try self.copyToTmpRegister(Type.bool, condition),
    };

    return try self.addInst(.{
        .tag = .bne,
        .data = .{
            .b_type = .{
                .rs1 = reg,
                .rs2 = .zero,
                .inst = undefined,
            },
        },
    });
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

    const start_index: Mir.Inst.Index = @intCast(self.code.items.len);

    try self.genBody(body);
    try self.jump(start_index);

    return self.finishAirBookkeeping();
}

/// Send control flow to the `index` of `self.code`.
fn jump(self: *Self, index: Mir.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = .j,
        .data = .{
            .inst = index,
        },
    });
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
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

    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    // TODO emit debug info lexical block
    try self.genBody(body);

    for (self.blocks.getPtr(inst).?.relocs.items) |reloc| {
        // here we are relocing to point at the instruction after the block.
        // [then case]
        // [jump to end] // this is reloced
        // [else case]
        // [jump to end] // this is reloced
        // [this isn't generated yet] // point to here
        try self.performReloc(reloc, @intCast(self.mir_instructions.len));
    }

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

fn performReloc(self: *Self, inst: Mir.Inst.Index, target: Mir.Inst.Index) !void {
    const tag = self.mir_instructions.items(.tag)[inst];

    switch (tag) {
        .bne,
        .beq,
        => self.mir_instructions.items(.data)[inst].b_type.inst = target,
        .jal,
        => self.mir_instructions.items(.data)[inst].j_type.inst = target,
        else => return self.fail("TODO: performReloc {s}", .{@tagName(tag)}),
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
            try self.setValue(self.typeOfIndex(block), block_mcv, operand_mcv);
        }
    }
    return self.brVoid(block);
}

fn brVoid(self: *Self, block: Air.Inst.Index) !void {
    const block_data = self.blocks.getPtr(block).?;

    // Emit a jump with a relocation. It will be patched up after the block ends.
    try block_data.relocs.ensureUnusedCapacity(self.gpa, 1);

    block_data.relocs.appendAssumeCapacity(try self.addInst(.{
        .tag = .jal,
        .data = .{
            .j_type = .{
                .rd = .ra,
                .inst = undefined,
            },
        },
    }));
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
fn setValue(self: *Self, ty: Type, dst_val: MCValue, src_val: MCValue) !void {
    // There isn't anything to store
    if (dst_val == .none) return;

    if (!dst_val.isMutable()) {
        // panic so we can see the trace
        return std.debug.panic("tried to setValue immutable: {s}", .{@tagName(dst_val)});
    }

    switch (dst_val) {
        .register => |reg| return self.genSetReg(ty, reg, src_val),
        .stack_offset => |off| return self.genSetStack(ty, off, src_val),
        .memory => |addr| return self.genSetMem(ty, addr, src_val),
        else => return self.fail("TODO: setValue {s}", .{@tagName(dst_val)}),
    }
}

/// Sets the value of `src_val` into stack memory at `stack_offset`.
fn genSetStack(self: *Self, ty: Type, stack_offset: u32, src_val: MCValue) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(mod));

    switch (src_val) {
        .none => return,
        .dead => unreachable,
        .undef => {
            if (!self.wantSafety()) return;
            try self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .immediate => {
            const reg = try self.register_manager.allocReg(null, gp);
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |lock| self.register_manager.unlockReg(lock);

            try self.genSetReg(ty, reg, src_val);

            return self.genSetStack(ty, stack_offset, .{ .register = reg });
        },
        .register => |reg| {
            switch (abi_size) {
                1, 2, 4, 8 => {
                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .sb,
                        2 => .sh,
                        4 => .sw,
                        8 => .sd,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .data = .{ .i_type = .{
                            .rd = reg,
                            .rs1 = .s0,
                            .imm12 = math.cast(i12, stack_offset) orelse {
                                return self.fail("TODO: genSetStack bigger stack values", .{});
                            },
                        } },
                    });
                },
                else => return self.fail("TODO: genSetStack for size={d}", .{abi_size}),
            }
        },
        .stack_offset, .load_symbol => {
            switch (src_val) {
                .stack_offset => |off| if (off == stack_offset) return,
                else => {},
            }

            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, src_val);
                return self.genSetStack(ty, stack_offset, .{ .register = reg });
            }

            const ptr_ty = try mod.singleMutPtrType(ty);

            // TODO call extern memcpy
            const regs = try self.register_manager.allocRegs(5, .{ null, null, null, null, null }, gp);
            const regs_locks = self.register_manager.lockRegsAssumeUnused(5, regs);
            defer for (regs_locks) |reg| {
                self.register_manager.unlockReg(reg);
            };

            const src_reg = regs[0];
            const dst_reg = regs[1];
            const len_reg = regs[2];
            const count_reg = regs[3];
            const tmp_reg = regs[4];

            switch (src_val) {
                .stack_offset => |offset| {
                    try self.genSetReg(ptr_ty, src_reg, .{ .ptr_stack_offset = offset });
                },
                .load_symbol => |sym_off| {
                    const atom_index = atom: {
                        const decl_index = mod.funcOwnerDeclIndex(self.func_index);

                        if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                            const atom_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, decl_index);
                            break :atom atom_index;
                        } else return self.fail("TODO genSetStack for {s}", .{@tagName(self.bin_file.tag)});
                    };

                    _ = try self.addInst(.{
                        .tag = .load_symbol,
                        .data = .{
                            .payload = try self.addExtra(Mir.LoadSymbolPayload{
                                .register = @intFromEnum(src_reg),
                                .atom_index = atom_index,
                                .sym_index = sym_off.sym,
                            }),
                        },
                    });
                },
                else => return self.fail("TODO: genSetStack unreachable {s}", .{@tagName(src_val)}),
            }

            try self.genSetReg(ptr_ty, dst_reg, .{ .ptr_stack_offset = stack_offset });
            try self.genSetReg(Type.usize, len_reg, .{ .immediate = abi_size });

            // memcpy(src, dst, len)
            try self.genInlineMemcpy(src_reg, dst_reg, len_reg, count_reg, tmp_reg);
        },
        else => return self.fail("TODO: genSetStack {s}", .{@tagName(src_val)}),
    }
}

fn genSetMem(self: *Self, ty: Type, addr: u64, src_val: MCValue) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(mod));
    _ = abi_size;
    _ = addr;
    _ = src_val;

    return self.fail("TODO: genSetMem", .{});
}

fn genInlineMemcpy(
    self: *Self,
    src: Register,
    dst: Register,
    len: Register,
    count: Register,
    tmp: Register,
) !void {
    _ = src;
    _ = dst;

    // store 0 in the count
    try self.genSetReg(Type.usize, count, .{ .immediate = 0 });

    // compare count to length
    const compare_inst = try self.addInst(.{
        .tag = .cmp_gt,
        .data = .{ .r_type = .{
            .rd = tmp,
            .rs1 = count,
            .rs2 = len,
        } },
    });

    // end if true
    _ = try self.addInst(.{
        .tag = .bne,
        .data = .{
            .b_type = .{
                .inst = @intCast(self.mir_instructions.len + 0), // points after the last inst
                .rs1 = .zero,
                .rs2 = tmp,
            },
        },
    });
    _ = compare_inst;

    return self.fail("TODO: finish genInlineMemcpy", .{});
}

/// Sets the value of `src_val` into `reg`. Assumes you have a lock on it.
fn genSetReg(self: *Self, ty: Type, reg: Register, src_val: MCValue) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(mod));

    switch (src_val) {
        .dead => unreachable,
        .ptr_stack_offset => |off| try self.genSetReg(ty, reg, .{ .stack_offset = off }),
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
                const temp = try self.register_manager.allocReg(null, gp);
                const maybe_temp_lock = self.register_manager.lockReg(temp);
                defer if (maybe_temp_lock) |temp_lock| self.register_manager.unlockReg(temp_lock);

                const lo32: i32 = @truncate(x);
                const carry: i32 = if (lo32 < 0) 1 else 0;
                const hi32: i32 = @truncate((x >> 32) +% carry);

                try self.genSetReg(Type.i32, temp, .{ .immediate = @bitCast(@as(i64, lo32)) });
                try self.genSetReg(Type.i32, reg, .{ .immediate = @bitCast(@as(i64, hi32)) });

                _ = try self.addInst(.{
                    .tag = .slli,
                    .data = .{ .i_type = .{
                        .imm12 = 32,
                        .rd = reg,
                        .rs1 = reg,
                    } },
                });

                _ = try self.addInst(.{
                    .tag = .add,
                    .data = .{ .r_type = .{
                        .rd = reg,
                        .rs1 = reg,
                        .rs2 = temp,
                    } },
                });
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
            try self.genSetReg(ty, reg, .{ .immediate = addr });

            _ = try self.addInst(.{
                .tag = .ld,
                .data = .{ .i_type = .{
                    .rd = reg,
                    .rs1 = reg,
                    .imm12 = 0,
                } },
            });

            // LOAD imm=[i12 offset = 0], rs1
        },
        .stack_offset => |off| {
            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .lb,
                2 => .lh,
                4 => .lw,
                8 => .ld,
                else => return self.fail("TODO: genSetReg for size {d}", .{abi_size}),
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{ .i_type = .{
                    .rd = reg,
                    .rs1 = .s0,
                    .imm12 = math.cast(i12, off) orelse {
                        return self.fail("TODO: genSetReg support larger stack sizes", .{});
                    },
                } },
            });
        },
        .load_symbol => |sym_off| {
            assert(sym_off.off == 0);

            const decl_index = mod.funcOwnerDeclIndex(self.func_index);

            const atom_index = switch (self.bin_file.tag) {
                .elf => blk: {
                    const elf_file = self.bin_file.cast(link.File.Elf).?;
                    const atom_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, decl_index);
                    break :blk atom_index;
                },
                else => return self.fail("TODO genSetReg load_symbol for {s}", .{@tagName(self.bin_file.tag)}),
            };
            _ = try self.addInst(.{
                .tag = .load_symbol,
                .data = .{
                    .payload = try self.addExtra(Mir.LoadSymbolPayload{
                        .register = @intFromEnum(reg),
                        .atom_index = atom_index,
                        .sym_index = sym_off.sym,
                    }),
                },
            });
        },
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
        try self.setValue(self.typeOfIndex(inst), dest, operand);
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
            .load_symbol => |sym_index| .{ .load_symbol = .{ .sym = sym_index } },
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_got, .load_direct, .load_tlv => {
                return self.fail("TODO: genTypedValue {s}", .{@tagName(mcv)});
            },
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
            if (result.args.len > 8) {
                return self.fail("TODO: support more than 8 function args", .{});
            }

            for (0..result.args.len) |i| {
                const arg_reg = try self.register_manager.allocReg(null, fa);
                result.args[i] = .{ .register = arg_reg };
            }

            // stack_offset = num s registers spilled + local var space
            var stack_offset: u32 = 0;
            _ = &stack_offset;
            // TODO: spill used s registers here

            result.stack_byte_count = stack_offset;
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
