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
const Value = @import("../../value.zig").Value;
const TypedValue = @import("../../TypedValue.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const Compilation = @import("../../Compilation.zig");
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("../../tracy.zig").trace;
const DW = std.dwarf;
const leb128 = std.leb;
const log = std.log.scoped(.codegen);
const build_options = @import("build_options");

const FnResult = @import("../../codegen.zig").FnResult;
const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const Instruction = abi.Instruction;
const callee_preserved_regs = abi.callee_preserved_regs;
const gp = abi.RegisterClass.gp;

const InnerError = error{
    OutOfMemory,
    CodegenFail,
    OutOfRegisters,
};

gpa: Allocator,
air: Air,
liveness: Liveness,
bin_file: *link.File,
target: *const std.Target,
mod_fn: *const Module.Fn,
code: *std.ArrayList(u8),
debug_output: DebugInfoOutput,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: MCValue,
fn_type: Type,
arg_index: usize,
src_loc: Module.SrcLoc,
stack_align: u32,

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
        const op_index = Air.refToIndex(op_ref) orelse return;
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
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    module_fn: *Module.Fn,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!FnResult {
    if (build_options.skip_non_native and builtin.cpu.arch != bin_file.options.target.cpu.arch) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const mod = bin_file.options.module.?;
    const fn_owner_decl = mod.declPtr(module_fn.owner_decl);
    assert(fn_owner_decl.has_tv);
    const fn_type = fn_owner_decl.ty;

    var branch_stack = std.ArrayList(Branch).init(bin_file.allocator);
    defer {
        assert(branch_stack.items.len == 1);
        branch_stack.items[0].deinit(bin_file.allocator);
        branch_stack.deinit();
    }
    try branch_stack.append(.{});

    var function = Self{
        .gpa = bin_file.allocator,
        .air = air,
        .liveness = liveness,
        .target = &bin_file.options.target,
        .bin_file = bin_file,
        .mod_fn = module_fn,
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
        .end_di_line = module_fn.rbrace_line,
        .end_di_column = module_fn.rbrace_column,
    };
    defer function.stack.deinit(bin_file.allocator);
    defer function.blocks.deinit(bin_file.allocator);
    defer function.exitlude_jump_relocs.deinit(bin_file.allocator);

    var call_info = function.resolveCallingConventionValues(fn_type) catch |err| switch (err) {
        error.CodegenFail => return FnResult{ .fail = function.err_msg.? },
        error.OutOfRegisters => return FnResult{
            .fail = try ErrorMsg.create(bin_file.allocator, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };
    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.stack_align = call_info.stack_align;
    function.max_end_stack = call_info.stack_byte_count;

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return FnResult{ .fail = function.err_msg.? },
        error.OutOfRegisters => return FnResult{
            .fail = try ErrorMsg.create(bin_file.allocator, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = function.mir_extra.toOwnedSlice(bin_file.allocator),
    };
    defer mir.deinit(bin_file.allocator);

    var emit = Emit{
        .mir = mir,
        .bin_file = bin_file,
        .debug_output = debug_output,
        .target = &bin_file.options.target,
        .src_loc = src_loc,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = module_fn.lbrace_line,
        .prev_di_column = module_fn.lbrace_column,
    };
    defer emit.deinit();

    emit.emitMir() catch |err| switch (err) {
        error.EmitFail => return FnResult{ .fail = emit.err_msg.? },
        else => |e| return e,
    };

    if (function.err_msg) |em| {
        return FnResult{ .fail = em };
    } else {
        return FnResult{ .appended = {} };
    }
}

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;

    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);

    const result_index = @intCast(Air.Inst.Index, self.mir_instructions.len);
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
    const result = @intCast(u32, self.mir_extra.items.len);
    inline for (fields) |field| {
        self.mir_extra.appendAssumeCapacity(switch (field.field_type) {
            u32 => @field(extra, field.name),
            i32 => @bitCast(u32, @field(extra, field.name)),
            else => @compileError("bad field type"),
        });
    }
    return result;
}

fn gen(self: *Self) !void {
    const cc = self.fn_type.fnCallingConvention();
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
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        const old_air_bookkeeping = self.air_bookkeeping;
        try self.ensureProcessDeathCapacity(Liveness.bpi);

        switch (air_tags[inst]) {
            // zig fmt: off
            .ptr_add => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub => try self.airPtrArithmetic(inst, .ptr_sub),

            .add => try self.airBinOp(inst, .add),
            .sub => try self.airBinOp(inst, .sub),

            .addwrap         => try self.airAddWrap(inst),
            .add_sat         => try self.airAddSat(inst),
            .subwrap         => try self.airSubWrap(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul             => try self.airMul(inst),
            .mulwrap         => try self.airMulWrap(inst),
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
            .fabs,
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
            .bool_to_int     => try self.airBoolToInt(inst),
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
            .ptrtoint        => try self.airPtrToInt(inst),
            .ret             => try self.airRet(inst),
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst),
            .struct_field_ptr=> try self.airStructFieldPtr(inst),
            .struct_field_val=> try self.airStructFieldVal(inst),
            .array_to_slice  => try self.airArrayToSlice(inst),
            .int_to_float    => try self.airIntToFloat(inst),
            .float_to_int    => try self.airFloatToInt(inst),
            .cmpxchg_strong  => try self.airCmpxchg(inst),
            .cmpxchg_weak    => try self.airCmpxchg(inst),
            .atomic_rmw      => try self.airAtomicRmw(inst),
            .atomic_load     => try self.airAtomicLoad(inst),
            .memcpy          => try self.airMemcpy(inst),
            .memset          => try self.airMemset(inst),
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
            .select          => try self.airSelect(inst),
            .shuffle         => try self.airShuffle(inst),
            .reduce          => try self.airReduce(inst),
            .aggregate_init  => try self.airAggregateInit(inst),
            .union_init      => try self.airUnionInit(inst),
            .prefetch        => try self.airPrefetch(inst),
            .mul_add         => try self.airMulAdd(inst),

            .@"try"          => @panic("TODO"),
            .try_ptr         => @panic("TODO"),

            .dbg_var_ptr,
            .dbg_var_val,
            => try self.airDbgVar(inst),

            .dbg_inline_begin,
            .dbg_inline_end,
            => try self.airDbgInline(inst),

            .dbg_block_begin,
            .dbg_block_end,
            => try self.airDbgBlock(inst),

            .call              => try self.airCall(inst, .auto),
            .call_always_tail  => try self.airCall(inst, .always_tail),
            .call_never_tail   => try self.airCall(inst, .never_tail),
            .call_never_inline => try self.airCall(inst, .never_inline),

            .atomic_store_unordered => try self.airAtomicStore(inst, .Unordered),
            .atomic_store_monotonic => try self.airAtomicStore(inst, .Monotonic),
            .atomic_store_release   => try self.airAtomicStore(inst, .Release),
            .atomic_store_seq_cst   => try self.airAtomicStore(inst, .SeqCst),

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

            .constant => unreachable, // excluded from function bodies
            .const_ty => unreachable, // excluded from function bodies
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

            .wrap_optional         => try self.airWrapOptional(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
            .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

            .wasm_memory_size => unreachable,
            .wasm_memory_grow => unreachable,
            // zig fmt: on
        }
        if (std.debug.runtime_safety) {
            if (self.air_bookkeeping < old_air_bookkeeping + 1) {
                std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, air_tags[inst] });
            }
        }
    }
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) void {
    const air_tags = self.air.instructions.items(.tag);
    if (air_tags[inst] == .constant) return; // Constants are immortal.
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
        const dies = @truncate(u1, tomb_bits) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        const op_int = @enumToInt(op);
        if (op_int < Air.Inst.Ref.typed_value_map.len) continue;
        const op_index = @intCast(Air.Inst.Index, op_int - Air.Inst.Ref.typed_value_map.len);
        self.processDeath(op_index);
    }
    const is_used = @truncate(u1, tomb_bits) == 0;
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

/// Adds a Type to the .debug_info at the current position. The bytes will be populated later,
/// after codegen for this symbol is done.
fn addDbgInfoTypeReloc(self: *Self, ty: Type) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            assert(ty.hasRuntimeBits());
            const dbg_info = &dw.dbg_info;
            const index = dbg_info.items.len;
            try dbg_info.resize(index + 4); // DW.AT.type,  DW.FORM.ref4
            const mod = self.bin_file.options.module.?;
            const atom = switch (self.bin_file.tag) {
                .elf => &mod.declPtr(self.mod_fn.owner_decl).link.elf.dbg_info_atom,
                .macho => unreachable,
                else => unreachable,
            };
            try dw.addTypeRelocGlobal(atom, ty, @intCast(u32, index));
        },
        .plan9 => {},
        .none => {},
    }
}

fn allocMem(self: *Self, inst: Air.Inst.Index, abi_size: u32, abi_align: u32) !u32 {
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;
    // TODO find a free slot instead of always appending
    const offset = mem.alignForwardGeneric(u32, self.next_stack_offset, abi_align);
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
    const elem_ty = self.air.typeOfIndex(inst).elemType();
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) orelse {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(self.target.*);
    return self.allocMem(inst, abi_size, abi_align);
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const elem_ty = self.air.typeOfIndex(inst);
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) orelse {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    const abi_align = elem_ty.abiAlignment(self.target.*);
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
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
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
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
    try self.genSetReg(self.air.typeOfIndex(reg_owner), reg, mcv);
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
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFptrunc for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFpext for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand_ty = self.air.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const info_a = operand_ty.intInfo(self.target.*);
    const info_b = self.air.typeOfIndex(inst).intInfo(self.target.*);
    if (info_a.signedness != info_b.signedness)
        return self.fail("TODO gen intcast sign safety in semantic analysis", .{});

    if (info_a.bits == info_b.bits)
        return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });

    return self.fail("TODO implement intCast for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand = try self.resolveInst(ty_op.operand);
    _ = operand;
    return self.fail("TODO implement trunc for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement NOT for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airMin(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement min for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMax(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement max for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
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
            const bin_op = self.air.instructions.items(.data)[inst].bin_op;
            break :inst Air.refToIndex(bin_op.lhs).?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);

        if (track_inst) |inst| branch.inst_table.putAssumeCapacity(inst, .{ .register = reg });

        break :blk reg;
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_reg = if (rhs_is_register) rhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (maybe_inst) |inst| inst: {
            const bin_op = self.air.instructions.items(.data)[inst].bin_op;
            break :inst Air.refToIndex(bin_op.rhs).?;
        } else null;

        const reg = try self.register_manager.allocReg(track_inst, gp);

        if (track_inst) |inst| branch.inst_table.putAssumeCapacity(inst, .{ .register = reg });

        break :blk reg;
    };
    const new_rhs_lock = self.register_manager.lockReg(rhs_reg);
    defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = if (maybe_inst) |inst| blk: {
        const bin_op = self.air.instructions.items(.data)[inst].bin_op;

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
    switch (tag) {
        // Arithmetic operations on integers and floats
        .add,
        .sub,
        => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
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
            switch (lhs_ty.zigTypeTag()) {
                .Pointer => {
                    const ptr_ty = lhs_ty;
                    const elem_ty = switch (ptr_ty.ptrSize()) {
                        .One => ptr_ty.childType().childType(), // ptr to array, so get array element type
                        else => ptr_ty.childType(),
                    };
                    const elem_size = elem_ty.abiSize(self.target.*);

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
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.binOp(tag, inst, lhs, rhs, lhs_ty, rhs_ty);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.binOp(tag, inst, lhs, rhs, lhs_ty, rhs_ty);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement addwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement subwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMul(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mulwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
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
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement rem for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mod for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitAnd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement bitwise and for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement bitwise or for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement xor for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .optional_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> E
fn airUnwrapErrErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union error ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement unwrap error union payload ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement .errunion_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
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

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const optional_ty = self.air.typeOfIndex(inst);

        // Optional with a zero-bit payload type is just a boolean true
        if (optional_ty.abiSize(self.target.*) == 1)
            break :result MCValue{ .immediate = 1 };

        return self.fail("TODO implement wrap optional for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement wrap errunion payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement wrap errunion error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_len for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_slice_len_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_slice_ptr_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement slice_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement array_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement ptr_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    _ = bin_op;
    return self.fail("TODO implement airSetUnionTag for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airByteSwap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
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
    branch.inst_table.putAssumeCapacity(Air.refToIndex(operand).?, .dead);

    return true;
}

fn load(self: *Self, dst_mcv: MCValue, ptr: MCValue, ptr_ty: Type) InnerError!void {
    const elem_ty = ptr_ty.elemType();
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
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const elem_ty = self.air.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBits())
            break :result MCValue.none;

        const ptr = try self.resolveInst(ty_op.operand);
        const is_volatile = self.air.typeOf(ty_op.operand).isVolatilePtr();
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
        try self.load(dst_mcv, ptr, self.air.typeOf(ty_op.operand));
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

fn airStore(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const value = try self.resolveInst(bin_op.rhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const value_ty = self.air.typeOf(bin_op.rhs);

    try self.store(ptr, value, ptr_ty, value_ty);

    return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airStructFieldPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    return self.structFieldPtr(extra.struct_operand, ty_pl.ty, extra.field_index);
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    return self.structFieldPtr(ty_op.operand, ty_op.ty, index);
}
fn structFieldPtr(self: *Self, operand: Air.Inst.Ref, ty: Air.Inst.Ref, index: u32) !void {
    _ = self;
    _ = operand;
    _ = ty;
    _ = index;
    return self.fail("TODO implement codegen struct_field_ptr", .{});
    //return self.finishAir(inst, result, .{ extra.struct_ptr, .none, .none });
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement codegen struct_field_val", .{});
    //return self.finishAir(inst, result, .{ extra.struct_ptr, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    _ = self;
    _ = inst;
    return self.fail("TODO implement codegen airFieldParentPtr", .{});
}

fn genArgDbgInfo(self: *Self, inst: Air.Inst.Index, mcv: MCValue, arg_index: u32) !void {
    const ty = self.air.instructions.items(.data)[inst].ty;
    const name = self.mod_fn.getParamName(arg_index);
    const name_with_null = name.ptr[0 .. name.len + 1];

    switch (mcv) {
        .register => |reg| {
            switch (self.debug_output) {
                .dwarf => |dw| {
                    const dbg_info = &dw.dbg_info;
                    try dbg_info.ensureUnusedCapacity(3);
                    dbg_info.appendAssumeCapacity(@enumToInt(link.File.Dwarf.AbbrevKind.parameter));
                    dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1, // ULEB128 dwarf expression length
                        reg.dwarfLocOp(),
                    });
                    try dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                    try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                    dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
                },
                .plan9 => {},
                .none => {},
            }
        },
        .stack_offset => |offset| {
            _ = offset;
            switch (self.debug_output) {
                .dwarf => {},
                .plan9 => {},
                .none => {},
            }
        },
        else => {},
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.air.typeOfIndex(inst);
    _ = ty;

    const result = self.args[arg_index];
    // TODO support stack-only arguments
    // TODO Copy registers to the stack
    const mcv = result;
    try self.genArgDbgInfo(inst, mcv, @intCast(u32, arg_index));

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

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for riscv64", .{});
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const fn_ty = self.air.typeOf(pl_op.operand);
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);

    var info = try self.resolveCallingConventionValues(fn_ty);
    defer info.deinit(self);

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (self.bin_file.tag == link.File.Elf.base_tag or self.bin_file.tag == link.File.Coff.base_tag) {
        for (info.args) |mc_arg, arg_i| {
            const arg = args[arg_i];
            const arg_ty = self.air.typeOf(arg);
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

        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;

                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const mod = self.bin_file.options.module.?;
                const fn_owner_decl = mod.declPtr(func.owner_decl);
                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                    break :blk @intCast(u32, got.p_vaddr + fn_owner_decl.link.elf.offset_table_index * ptr_bytes);
                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                    coff_file.offset_table_virtual_address + fn_owner_decl.link.coff.offset_table_index * ptr_bytes
                else
                    unreachable;

                try self.genSetReg(Type.initTag(.usize), .ra, .{ .memory = got_addr });
                _ = try self.addInst(.{
                    .tag = .jalr,
                    .data = .{ .i_type = .{
                        .rd = .ra,
                        .rs1 = .ra,
                        .imm12 = 0,
                    } },
                });
            } else if (func_value.castTag(.extern_fn)) |_| {
                return self.fail("TODO implement calling extern functions", .{});
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else {
            return self.fail("TODO implement calling runtime known function pointer", .{});
        }
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
        std.mem.copy(Air.Inst.Ref, buf[1..], args);
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
    const ret_ty = self.fn_type.fnReturnType();
    try self.setRegOrMem(ret_ty, self.ret_mcv, mcv);
    // Just add space for an instruction, patch this later
    const index = try self.addInst(.{
        .tag = .nop,
        .data = .{ .nop = {} },
    });
    try self.exitlude_jump_relocs.append(self.gpa, index);
}

fn airRet(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    try self.ret(operand);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ptr = try self.resolveInst(un_op);
    _ = ptr;
    return self.fail("TODO implement airRetLoad for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    const ty = self.air.typeOf(bin_op.lhs);
    const mod = self.bin_file.options.module.?;
    assert(ty.eql(self.air.typeOf(bin_op.rhs), mod));
    if (ty.zigTypeTag() == .ErrorSet)
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
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    _ = operand;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airCmpLtErrorsLen for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;

    _ = try self.addInst(.{
        .tag = .dbg_line,
        .data = .{ .dbg_line_column = .{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        } },
    });

    return self.finishAirBookkeeping();
}

fn airDbgInline(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const function = self.air.values[ty_pl.payload].castTag(.function).?.data;
    // TODO emit debug info for function change
    _ = function;
    return self.finishAir(inst, .dead, .{ .none, .none, .none });
}

fn airDbgBlock(self: *Self, inst: Air.Inst.Index) !void {
    // TODO emit debug info lexical block
    return self.finishAir(inst, .dead, .{ .none, .none, .none });
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
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
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
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
        try self.load(operand, operand_ptr, self.air.typeOf(un_op));
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
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
        try self.load(operand, operand_ptr, self.air.typeOf(un_op));
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
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
        try self.load(operand, operand_ptr, self.air.typeOf(un_op));
        break :result try self.isErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNonErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
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
        try self.load(operand, operand_ptr, self.air.typeOf(un_op));
        break :result try self.isNonErr(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[loop.end..][0..loop.data.body_len];
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

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    try self.genBody(body);

    for (self.blocks.getPtr(inst).?.relocs.items) |reloc| try self.performReloc(reloc);

    const result = self.blocks.getPtr(inst).?.mcv;
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
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
    const branch = self.air.instructions.items(.data)[inst].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn airBoolOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const air_tags = self.air.instructions.items(.tag);
    _ = air_tags;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement boolean operations for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const block_data = self.blocks.getPtr(block).?;

    if (self.air.typeOf(operand).hasRuntimeBits()) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = operand_mcv;
        } else {
            try self.setRegOrMem(self.air.typeOfIndex(block), block_mcv, operand_mcv);
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
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = @truncate(u1, extra.data.flags >> 31) != 0;
    const clobbers_len = @truncate(u31, extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.inputs_len]);
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
            try self.genSetReg(self.air.typeOf(input), reg, arg_mcv);
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
        std.mem.copy(Air.Inst.Ref, buf[buf_index..], inputs);
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
            const x = @bitCast(i64, unsigned_x);
            if (math.minInt(i12) <= x and x <= math.maxInt(i12)) {
                _ = try self.addInst(.{
                    .tag = .addi,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = .zero,
                        .imm12 = @intCast(i12, x),
                    } },
                });
            } else if (math.minInt(i32) <= x and x <= math.maxInt(i32)) {
                const lo12 = @truncate(i12, x);
                const carry: i32 = if (lo12 < 0) 1 else 0;
                const hi20 = @truncate(i20, (x >> 12) +% carry);

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

fn airPtrToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result = try self.resolveInst(un_op);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = try self.resolveInst(ty_op.operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airArrayToSlice for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntToFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airIntToFloat for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFloatToInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFloatToInt for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
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

fn airMemset(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airMemset for {}", .{self.target.cpu.arch});
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airMemcpy for {}", .{self.target.cpu.arch});
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airTagName for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSelect for riscv64", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airShuffle for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[inst].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airReduce for riscv64", .{});
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const vector_ty = self.air.typeOfIndex(inst);
    const len = vector_ty.vectorLen();
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airAggregateInit for riscv64", .{});
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        std.mem.copy(Air.Inst.Ref, &buf, elements);
        return self.finishAir(inst, result, buf);
    }
    var bt = try self.iterateBigTomb(inst, elements.len);
    for (elements) |elem| {
        bt.feed(elem);
    }
    return bt.finishAir(result);
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement airUnionInit for riscv64", .{});
    // return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        return self.fail("TODO implement airMulAdd for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    // First section of indexes correspond to a set number of constant values.
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        const tv = Air.Inst.Ref.typed_value_map[ref_int];
        if (!tv.ty.hasRuntimeBits()) {
            return MCValue{ .none = {} };
        }
        return self.genTypedValue(tv);
    }

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.air.typeOf(inst);
    if (!inst_ty.hasRuntimeBits())
        return MCValue{ .none = {} };

    const inst_index = @intCast(Air.Inst.Index, ref_int - Air.Inst.Ref.typed_value_map.len);
    switch (self.air.instructions.items(.tag)[inst_index]) {
        .constant => {
            // Constants have static lifetimes, so they are always memoized in the outer most table.
            const branch = &self.branch_stack.items[0];
            const gop = try branch.inst_table.getOrPut(self.gpa, inst_index);
            if (!gop.found_existing) {
                const ty_pl = self.air.instructions.items(.data)[inst_index].ty_pl;
                gop.value_ptr.* = try self.genTypedValue(.{
                    .ty = inst_ty,
                    .val = self.air.values[ty_pl.payload],
                });
            }
            return gop.value_ptr.*;
        },
        .const_ty => unreachable,
        else => return self.getResolvedInstValue(inst_index),
    }
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

fn lowerDeclRef(self: *Self, tv: TypedValue, decl_index: Module.Decl.Index) InnerError!MCValue {
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);
    const mod = self.bin_file.options.module.?;
    const decl = mod.declPtr(decl_index);
    mod.markDeclAlive(decl);
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
        const got_addr = got.p_vaddr + decl.link.elf.offset_table_index * ptr_bytes;
        return MCValue{ .memory = got_addr };
    } else if (self.bin_file.cast(link.File.MachO)) |_| {
        // TODO I'm hacking my way through here by repurposing .memory for storing
        // index to the GOT target symbol index.
        return MCValue{ .memory = decl.link.macho.local_sym_index };
    } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
        const got_addr = coff_file.offset_table_virtual_address + decl.link.coff.offset_table_index * ptr_bytes;
        return MCValue{ .memory = got_addr };
    } else if (self.bin_file.cast(link.File.Plan9)) |p9| {
        try p9.seeDecl(decl_index);
        const got_addr = p9.bases.data + decl.link.plan9.got_index.? * ptr_bytes;
        return MCValue{ .memory = got_addr };
    } else {
        return self.fail("TODO codegen non-ELF const Decl pointer", .{});
    }
    _ = tv;
}

fn genTypedValue(self: *Self, typed_value: TypedValue) InnerError!MCValue {
    if (typed_value.val.isUndef())
        return MCValue{ .undef = {} };

    if (typed_value.val.castTag(.decl_ref)) |payload| {
        return self.lowerDeclRef(typed_value, payload.data);
    }
    if (typed_value.val.castTag(.decl_ref_mut)) |payload| {
        return self.lowerDeclRef(typed_value, payload.data.decl_index);
    }
    const target = self.target.*;
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();
    switch (typed_value.ty.zigTypeTag()) {
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_type = typed_value.ty.slicePtrFieldType(&buf);
                const ptr_mcv = try self.genTypedValue(.{ .ty = ptr_type, .val = typed_value.val });
                const mod = self.bin_file.options.module.?;
                const slice_len = typed_value.val.sliceLen(mod);
                // Codegen can't handle some kinds of indirection. If the wrong union field is accessed here it may mean
                // the Sema code needs to use anonymous Decls or alloca instructions to store data.
                const ptr_imm = ptr_mcv.memory;
                _ = slice_len;
                _ = ptr_imm;
                // We need more general support for const data being stored in memory to make this work.
                return self.fail("TODO codegen for const slices", .{});
            },
            else => {
                if (typed_value.val.tag() == .int_u64) {
                    return MCValue{ .immediate = typed_value.val.toUnsignedInt(target) };
                }
                return self.fail("TODO codegen more kinds of const pointers", .{});
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits > ptr_bits or info.signedness == .signed) {
                return self.fail("TODO const int bigger than ptr and signed int", .{});
            }
            return MCValue{ .immediate = typed_value.val.toUnsignedInt(target) };
        },
        .Bool => {
            return MCValue{ .immediate = @boolToInt(typed_value.val.toBool()) };
        },
        .ComptimeInt => unreachable, // semantic analysis prevents this
        .ComptimeFloat => unreachable, // semantic analysis prevents this
        .Optional => {
            if (typed_value.ty.isPtrLikeOptional()) {
                if (typed_value.val.isNull())
                    return MCValue{ .immediate = 0 };

                var buf: Type.Payload.ElemType = undefined;
                return self.genTypedValue(.{
                    .ty = typed_value.ty.optionalChild(&buf),
                    .val = typed_value.val,
                });
            } else if (typed_value.ty.abiSize(self.target.*) == 1) {
                return MCValue{ .immediate = @boolToInt(typed_value.val.isNull()) };
            }
            return self.fail("TODO non pointer optionals", .{});
        },
        .Enum => {
            if (typed_value.val.castTag(.enum_field_index)) |field_index| {
                switch (typed_value.ty.tag()) {
                    .enum_simple => {
                        return MCValue{ .immediate = field_index.data };
                    },
                    .enum_full, .enum_nonexhaustive => {
                        const enum_full = typed_value.ty.cast(Type.Payload.EnumFull).?.data;
                        if (enum_full.values.count() != 0) {
                            const tag_val = enum_full.values.keys()[field_index.data];
                            return self.genTypedValue(.{ .ty = enum_full.tag_ty, .val = tag_val });
                        } else {
                            return MCValue{ .immediate = field_index.data };
                        }
                    },
                    else => unreachable,
                }
            } else {
                var int_tag_buffer: Type.Payload.Bits = undefined;
                const int_tag_ty = typed_value.ty.intTagType(&int_tag_buffer);
                return self.genTypedValue(.{ .ty = int_tag_ty, .val = typed_value.val });
            }
        },
        .ErrorSet => {
            switch (typed_value.val.tag()) {
                .@"error" => {
                    const err_name = typed_value.val.castTag(.@"error").?.data.name;
                    const module = self.bin_file.options.module.?;
                    const global_error_set = module.global_error_set;
                    const error_index = global_error_set.get(err_name).?;
                    return MCValue{ .immediate = error_index };
                },
                else => {
                    // In this case we are rendering an error union which has a 0 bits payload.
                    return MCValue{ .immediate = 0 };
                },
            }
        },
        .ErrorUnion => {
            const error_type = typed_value.ty.errorUnionSet();
            const payload_type = typed_value.ty.errorUnionPayload();
            const sub_val = typed_value.val.castTag(.eu_payload).?.data;

            if (!payload_type.hasRuntimeBits()) {
                // We use the error type directly as the type.
                return self.genTypedValue(.{ .ty = error_type, .val = sub_val });
            }

            return self.fail("TODO implement error union const of type '{}'", .{typed_value.ty.fmtDebug()});
        },
        else => return self.fail("TODO implement const of type '{}'", .{typed_value.ty.fmtDebug()}),
    }
}

const CallMCValues = struct {
    args: []MCValue,
    return_value: MCValue,
    stack_byte_count: u32,
    stack_align: u32,

    fn deinit(self: *CallMCValues, func: *Self) void {
        func.gpa.free(self.args);
        self.* = undefined;
    }
};

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(self: *Self, fn_ty: Type) !CallMCValues {
    const cc = fn_ty.fnCallingConvention();
    const param_types = try self.gpa.alloc(Type, fn_ty.fnParamLen());
    defer self.gpa.free(param_types);
    fn_ty.fnParamTypes(param_types);
    var result: CallMCValues = .{
        .args = try self.gpa.alloc(MCValue, param_types.len),
        // These undefined values must be populated before returning from this function.
        .return_value = undefined,
        .stack_byte_count = undefined,
        .stack_align = undefined,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = fn_ty.fnReturnType();

    switch (cc) {
        .Naked => {
            assert(result.args.len == 0);
            result.return_value = .{ .unreach = {} };
            result.stack_byte_count = 0;
            result.stack_align = 1;
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
            const argument_registers = [_]Register{ .a0, .a1, .a2, .a3, .a4, .a5, .a6, .a7 };

            for (param_types) |ty, i| {
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                if (param_size <= 8) {
                    if (next_register < argument_registers.len) {
                        result.args[i] = .{ .register = argument_registers[next_register] };
                        next_register += 1;
                    } else {
                        result.args[i] = .{ .stack_offset = next_stack_offset };
                        next_register += next_stack_offset;
                    }
                } else if (param_size <= 16) {
                    if (next_register < argument_registers.len - 1) {
                        return self.fail("TODO MCValues with 2 registers", .{});
                    } else if (next_register < argument_registers.len) {
                        return self.fail("TODO MCValues split register + stack", .{});
                    } else {
                        result.args[i] = .{ .stack_offset = next_stack_offset };
                        next_register += next_stack_offset;
                    }
                } else {
                    result.args[i] = .{ .stack_offset = next_stack_offset };
                    next_register += next_stack_offset;
                }
            }

            result.stack_byte_count = next_stack_offset;
            result.stack_align = 16;
        },
        else => return self.fail("TODO implement function parameters for {} on riscv64", .{cc}),
    }

    if (ret_ty.zigTypeTag() == .NoReturn) {
        result.return_value = .{ .unreach = {} };
    } else if (!ret_ty.hasRuntimeBits()) {
        result.return_value = .{ .none = {} };
    } else switch (cc) {
        .Naked => unreachable,
        .Unspecified, .C => {
            const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
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
    return switch (self.bin_file.options.optimize_mode) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

fn fail(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.bin_file.allocator, self.src_loc, format, args);
    return error.CodegenFail;
}

fn failSymbol(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.bin_file.allocator, self.src_loc, format, args);
    return error.CodegenFail;
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}
