const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const codegen = @import("../../codegen.zig");
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

const FnResult = codegen.FnResult;
const GenerateSymbolError = codegen.GenerateSymbolError;
const DebugInfoOutput = codegen.DebugInfoOutput;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;
const errUnionErrorOffset = codegen.errUnionErrorOffset;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const Register = bits.Register;
const Instruction = bits.Instruction;
const Condition = bits.Condition;
const callee_preserved_regs = abi.callee_preserved_regs;
const caller_preserved_regs = abi.caller_preserved_regs;
const c_abi_int_param_regs = abi.c_abi_int_param_regs;
const c_abi_int_return_regs = abi.c_abi_int_return_regs;
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
debug_output: DebugInfoOutput,
target: *const std.Target,
mod_fn: *const Module.Fn,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: MCValue,
fn_type: Type,
arg_index: u32,
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

/// For every argument, we postpone the creation of debug info for
/// later after all Mir instructions have been generated. Only then we
/// will know saved_regs_stack_space which is necessary in order to
/// address parameters passed on the stack.
dbg_arg_relocs: std.ArrayListUnmanaged(DbgArgReloc) = .{},

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
/// Tracks the current instruction allocated to the compare flags
cpsr_flags_inst: ?Air.Inst.Index = null,

/// Offset from the stack base, representing the end of the stack frame.
max_end_stack: u32 = 0,
/// Represents the current end stack offset. If there is no existing slot
/// to place a new stack allocation, it goes here, and then bumps `max_end_stack`.
next_stack_offset: u32 = 0,

saved_regs_stack_space: u32 = 0,

/// Debug field, used to find bugs in the compiler.
air_bookkeeping: @TypeOf(air_bookkeeping_init) = air_bookkeeping_init,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const MCValue = union(enum) {
    /// No runtime bits. `void` types, empty structs, u0, enums with 1
    /// tag, etc.
    ///
    /// TODO Look into deleting this tag and using `dead` instead,
    /// since every use of MCValue.none should be instead looking at
    /// the type and noticing it is 0 bits.
    none,
    /// Control flow will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    dead,
    /// The value is undefined.
    undef,
    /// A pointer-sized integer that fits in a register.
    ///
    /// If the type is a pointer, this is the pointer address in
    /// virtual address space.
    immediate: u32,
    /// The value is in a target-specific register.
    register: Register,
    /// The value is a tuple { wrapped: u32, overflow: u1 } where
    /// wrapped is stored in the register and the overflow bit is
    /// stored in the C flag of the CPSR.
    ///
    /// This MCValue is only generated by a add_with_overflow or
    /// sub_with_overflow instruction operating on u32.
    register_c_flag: Register,
    /// The value is a tuple { wrapped: i32, overflow: u1 } where
    /// wrapped is stored in the register and the overflow bit is
    /// stored in the V flag of the CPSR.
    ///
    /// This MCValue is only generated by a add_with_overflow or
    /// sub_with_overflow instruction operating on i32.
    register_v_flag: Register,
    /// The value is in memory at a hard-coded address.
    ///
    /// If the type is a pointer, it means the pointer address is at
    /// this memory location.
    memory: u64,
    /// The value is one of the stack variables.
    ///
    /// If the type is a pointer, it means the pointer address is in
    /// the stack at this offset.
    stack_offset: u32,
    /// The value is a pointer to one of the stack variables (payload
    /// is stack offset).
    ptr_stack_offset: u32,
    /// The value resides in the N, Z, C, V flags of the Current
    /// Program Status Register (CPSR). The value is 1 (if the type is
    /// u1) or true (if the type in bool) iff the specified condition
    /// is true.
    cpsr_flags: Condition,
    /// The value is a function argument passed via the stack.
    stack_argument_offset: u32,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .stack_offset, .stack_argument_offset => true,
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
            .cpsr_flags,
            .ptr_stack_offset,
            .undef,
            .stack_argument_offset,
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

const DbgArgReloc = struct {
    inst: Air.Inst.Index,
    index: u32,
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
        .debug_output = debug_output,
        .mod_fn = module_fn,
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
    defer function.dbg_arg_relocs.deinit(bin_file.allocator);

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

    for (function.dbg_arg_relocs.items) |reloc| {
        try function.genArgDbgInfo(reloc.inst, reloc.index, call_info.stack_byte_count);
    }

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
        .prologue_stack_space = call_info.stack_byte_count + function.saved_regs_stack_space,
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
        // push {fp, lr}
        const push_reloc = try self.addNop();

        // mov fp, sp
        _ = try self.addInst(.{
            .tag = .mov,
            .data = .{ .rr_op = .{
                .rd = .fp,
                .rn = .r0,
                .op = Instruction.Operand.reg(.sp, Instruction.Operand.Shift.none),
            } },
        });

        // sub sp, sp, #reloc
        const sub_reloc = try self.addNop();

        if (self.ret_mcv == .stack_offset) {
            // The address of where to store the return value is in
            // r0. As this register might get overwritten along the
            // way, save the address to the stack.
            const stack_offset = mem.alignForwardGeneric(u32, self.next_stack_offset, 4) + 4;
            self.next_stack_offset = stack_offset;
            self.max_end_stack = @maximum(self.max_end_stack, self.next_stack_offset);

            try self.genSetStack(Type.usize, stack_offset, MCValue{ .register = .r0 });
            self.ret_mcv = MCValue{ .stack_offset = stack_offset };
        }

        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .cond = undefined,
            .data = .{ .nop = {} },
        });

        try self.genBody(self.air.getMainBody());

        // Backpatch push callee saved regs
        var saved_regs = Instruction.RegisterList{
            .r11 = true, // fp
            .r14 = true, // lr
        };
        self.saved_regs_stack_space = 8;
        inline for (callee_preserved_regs) |reg| {
            if (self.register_manager.isRegAllocated(reg)) {
                @field(saved_regs, @tagName(reg)) = true;
                self.saved_regs_stack_space += 4;
            }
        }

        self.mir_instructions.set(push_reloc, .{
            .tag = .push,
            .data = .{ .register_list = saved_regs },
        });

        // Backpatch stack offset
        const total_stack_size = self.max_end_stack + self.saved_regs_stack_space;
        const aligned_total_stack_end = mem.alignForwardGeneric(u32, total_stack_size, self.stack_align);
        const stack_size = aligned_total_stack_end - self.saved_regs_stack_space;
        if (Instruction.Operand.fromU32(stack_size)) |op| {
            self.mir_instructions.set(sub_reloc, .{
                .tag = .sub,
                .data = .{ .rr_op = .{ .rd = .sp, .rn = .sp, .op = op } },
            });
        } else {
            return self.failSymbol("TODO ARM: allow larger stacks", .{});
        }

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .cond = undefined,
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
            self.mir_instructions.set(jmp_reloc, .{
                .tag = .b,
                .data = .{ .inst = @intCast(u32, self.mir_instructions.len) },
            });
        }

        // Epilogue: pop callee saved registers (swap lr with pc in saved_regs)
        saved_regs.r14 = false; // lr
        saved_regs.r15 = true; // pc

        // mov sp, fp
        _ = try self.addInst(.{
            .tag = .mov,
            .data = .{ .rr_op = .{
                .rd = .sp,
                .rn = .r0,
                .op = Instruction.Operand.reg(.fp, Instruction.Operand.Shift.none),
            } },
        });

        // pop {fp, pc}
        _ = try self.addInst(.{
            .tag = .pop,
            .data = .{ .register_list = saved_regs },
        });
    } else {
        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .cond = undefined,
            .data = .{ .nop = {} },
        });

        try self.genBody(self.air.getMainBody());

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .cond = undefined,
            .data = .{ .nop = {} },
        });
    }

    // Drop them off at the rbrace.
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .cond = undefined,
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
            .add,            => try self.airBinOp(inst, .add),
            .addwrap         => try self.airBinOp(inst, .addwrap),
            .sub,            => try self.airBinOp(inst, .sub),
            .subwrap         => try self.airBinOp(inst, .subwrap),
            .mul             => try self.airBinOp(inst, .mul),
            .mulwrap         => try self.airBinOp(inst, .mulwrap),
            .shl             => try self.airBinOp(inst, .shl),
            .shl_exact       => try self.airBinOp(inst, .shl_exact),
            .bool_and        => try self.airBinOp(inst, .bool_and),
            .bool_or         => try self.airBinOp(inst, .bool_or),
            .bit_and         => try self.airBinOp(inst, .bit_and),
            .bit_or          => try self.airBinOp(inst, .bit_or),
            .xor             => try self.airBinOp(inst, .xor),
            .shr             => try self.airBinOp(inst, .shr),
            .shr_exact       => try self.airBinOp(inst, .shr_exact),
            .div_float       => try self.airBinOp(inst, .div_float),
            .div_trunc       => try self.airBinOp(inst, .div_trunc),
            .div_floor       => try self.airBinOp(inst, .div_floor),
            .div_exact       => try self.airBinOp(inst, .div_exact),
            .rem             => try self.airBinOp(inst, .rem),
            .mod             => try self.airBinOp(inst, .mod),

            .ptr_add => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub => try self.airPtrArithmetic(inst, .ptr_sub),

            .min => try self.airMinMax(inst),
            .max => try self.airMinMax(inst),

            .add_sat         => try self.airAddSat(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul_sat         => try self.airMulSat(inst),
            .shl_sat         => try self.airShlSat(inst),
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

            .add_with_overflow => try self.airOverflow(inst),
            .sub_with_overflow => try self.airOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

            .cmp_lt  => try self.airCmp(inst, .lt),
            .cmp_lte => try self.airCmp(inst, .lte),
            .cmp_eq  => try self.airCmp(inst, .eq),
            .cmp_gte => try self.airCmp(inst, .gte),
            .cmp_gt  => try self.airCmp(inst, .gt),
            .cmp_neq => try self.airCmp(inst, .neq),

            .cmp_vector => try self.airCmpVector(inst),
            .cmp_lt_errors_len => try self.airCmpLtErrorsLen(inst),

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

            .@"try"          => try self.airTry(inst),
            .try_ptr         => try self.airTryPtr(inst),

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

        assert(!self.register_manager.lockedRegsExist());

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
        .register_c_flag,
        .register_v_flag,
        => |reg| {
            self.register_manager.freeReg(reg);
            self.cpsr_flags_inst = null;
        },
        .cpsr_flags => {
            self.cpsr_flags_inst = null;
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
            .register_c_flag,
            .register_v_flag,
            => |reg| {
                if (self.register_manager.isRegFree(reg)) {
                    self.register_manager.getRegAssumeFree(reg, inst);
                }
                self.cpsr_flags_inst = inst;
            },
            .cpsr_flags => {
                self.cpsr_flags_inst = inst;
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

fn allocMem(self: *Self, inst: Air.Inst.Index, abi_size: u32, abi_align: u32) !u32 {
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;
    // TODO find a free slot instead of always appending
    const offset = mem.alignForwardGeneric(u32, self.next_stack_offset, abi_align) + abi_size;
    self.next_stack_offset = offset;
    self.max_end_stack = @maximum(self.max_end_stack, self.next_stack_offset);
    try self.stack.putNoClobber(self.gpa, offset, .{
        .inst = inst,
        .size = abi_size,
    });
    return offset;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !u32 {
    const elem_ty = self.air.typeOfIndex(inst).elemType();

    if (!elem_ty.hasRuntimeBits()) {
        // As this stack item will never be dereferenced at runtime,
        // return the stack offset 0. Stack offset 0 will be where all
        // zero-sized stack allocations live as non-zero-sized
        // allocations will always have an offset > 0.
        return @as(u32, 0);
    }

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
    log.debug("spilling {} (%{d}) to stack mcv {any}", .{ reg, inst, stack_mcv });

    const reg_mcv = self.getResolvedInstValue(inst);
    switch (reg_mcv) {
        .register,
        .register_c_flag,
        .register_v_flag,
        => |r| assert(r == reg),
        else => unreachable, // not a register
    }

    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
}

/// Save the current instruction stored in the compare flags if
/// occupied
fn spillCompareFlagsIfOccupied(self: *Self) !void {
    if (self.cpsr_flags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save);
        const new_mcv = switch (mcv) {
            .cpsr_flags => try self.allocRegOrMem(inst_to_save, true),
            .register_c_flag,
            .register_v_flag,
            => try self.allocRegOrMem(inst_to_save, false),
            else => unreachable, // mcv doesn't occupy the compare flags
        };

        try self.setRegOrMem(self.air.typeOfIndex(inst_to_save), new_mcv, mcv);
        log.debug("spilling {d} to mcv {any}", .{ inst_to_save, new_mcv });

        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        try branch.inst_table.put(self.gpa, inst_to_save, new_mcv);

        self.cpsr_flags_inst = null;

        // TODO consolidate with register manager and spillInstruction
        // this call should really belong in the register manager!
        switch (mcv) {
            .register_c_flag,
            .register_v_flag,
            => |reg| self.register_manager.freeReg(reg),
            else => {},
        }
    }
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null, gp);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = switch (self.ret_mcv) {
        .none, .register => .{ .ptr_stack_offset = try self.allocMemPtr(inst) },
        .stack_offset => blk: {
            // self.ret_mcv is an address to where this function
            // should store its result into
            const ret_ty = self.fn_type.fnReturnType();
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = ret_ty,
            };
            const ptr_ty = Type.initPayload(&ptr_ty_payload.base);

            // addr_reg will contain the address of where to store the
            // result into
            const addr_reg = try self.copyToTmpRegister(ptr_ty, self.ret_mcv);
            break :blk .{ .register = addr_reg };
        },
        else => unreachable, // invalid return result
    };

    return self.finishAir(inst, result, .{ .none, .none, .none });
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

    const operand = try self.resolveInst(ty_op.operand);
    const operand_ty = self.air.typeOf(ty_op.operand);
    const dest_ty = self.air.typeOfIndex(inst);

    const operand_abi_size = operand_ty.abiSize(self.target.*);
    const dest_abi_size = dest_ty.abiSize(self.target.*);
    const info_a = operand_ty.intInfo(self.target.*);
    const info_b = dest_ty.intInfo(self.target.*);

    const dst_mcv: MCValue = blk: {
        if (info_a.bits == info_b.bits) {
            break :blk operand;
        }
        if (operand_abi_size > 4 or dest_abi_size > 4) {
            return self.fail("TODO implement intCast for abi sizes larger than 4", .{});
        }

        const operand_lock: ?RegisterLock = switch (operand) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const reg = try self.register_manager.allocReg(inst, gp);
        try self.genSetReg(dest_ty, reg, operand);
        break :blk MCValue{ .register = reg };
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn truncRegister(
    self: *Self,
    operand_reg: Register,
    dest_reg: Register,
    int_signedness: std.builtin.Signedness,
    int_bits: u16,
) !void {
    // TODO check if sxtb/uxtb/sxth/uxth are more efficient
    _ = try self.addInst(.{
        .tag = switch (int_signedness) {
            .signed => .sbfx,
            .unsigned => .ubfx,
        },
        .data = .{ .rr_lsb_width = .{
            .rd = dest_reg,
            .rn = operand_reg,
            .lsb = 0,
            .width = @intCast(u6, int_bits),
        } },
    });
}

fn trunc(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    operand: MCValue,
    operand_ty: Type,
    dest_ty: Type,
) !MCValue {
    const info_a = operand_ty.intInfo(self.target.*);
    const info_b = dest_ty.intInfo(self.target.*);

    if (info_b.bits <= 32) {
        const operand_reg = switch (operand) {
            .register => |r| r,
            else => operand_reg: {
                if (info_a.bits <= 32) {
                    break :operand_reg try self.copyToTmpRegister(operand_ty, operand);
                } else {
                    return self.fail("TODO load least significant word into register", .{});
                }
            },
        };
        const operand_reg_lock = self.register_manager.lockReg(operand_reg);
        defer if (operand_reg_lock) |reg| self.register_manager.unlockReg(reg);

        const dest_reg = if (maybe_inst) |inst| blk: {
            const ty_op = self.air.instructions.items(.data)[inst].ty_op;

            if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                break :blk operand_reg;
            } else {
                break :blk try self.register_manager.allocReg(inst, gp);
            }
        } else try self.register_manager.allocReg(null, gp);

        switch (info_b.bits) {
            32 => {
                try self.genSetReg(operand_ty, dest_reg, .{ .register = operand_reg });
                return MCValue{ .register = dest_reg };
            },
            else => {
                try self.truncRegister(operand_reg, dest_reg, info_b.signedness, info_b.bits);
                return MCValue{ .register = dest_reg };
            },
        }
    } else {
        return self.fail("TODO: truncate to ints > 32 bits", .{});
    }
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const operand = try self.resolveInst(ty_op.operand);
    const operand_ty = self.air.typeOf(ty_op.operand);
    const dest_ty = self.air.typeOfIndex(inst);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        break :blk try self.trunc(inst, operand, operand_ty, dest_ty);
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.air.typeOf(ty_op.operand);
        switch (operand) {
            .dead => unreachable,
            .unreach => unreachable,
            .cpsr_flags => |cond| break :result MCValue{ .cpsr_flags = cond.negate() },
            else => {
                switch (operand_ty.zigTypeTag()) {
                    .Bool => {
                        const op_reg = switch (operand) {
                            .register => |r| r,
                            else => try self.copyToTmpRegister(operand_ty, operand),
                        };
                        const op_reg_lock = self.register_manager.lockRegAssumeUnused(op_reg);
                        defer self.register_manager.unlockReg(op_reg_lock);

                        const dest_reg = blk: {
                            if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                                break :blk op_reg;
                            }

                            break :blk try self.register_manager.allocReg(null, gp);
                        };

                        _ = try self.addInst(.{
                            .tag = .eor,
                            .data = .{ .rr_op = .{
                                .rd = dest_reg,
                                .rn = op_reg,
                                .op = Instruction.Operand.fromU32(1).?,
                            } },
                        });

                        break :result MCValue{ .register = dest_reg };
                    },
                    .Vector => return self.fail("TODO bitwise not for vectors", .{}),
                    .Int => {
                        const int_info = operand_ty.intInfo(self.target.*);
                        if (int_info.bits <= 32) {
                            const op_reg = switch (operand) {
                                .register => |r| r,
                                else => try self.copyToTmpRegister(operand_ty, operand),
                            };
                            const op_reg_lock = self.register_manager.lockRegAssumeUnused(op_reg);
                            defer self.register_manager.unlockReg(op_reg_lock);

                            const dest_reg = blk: {
                                if (operand == .register and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                                    break :blk op_reg;
                                }

                                break :blk try self.register_manager.allocReg(null, gp);
                            };

                            _ = try self.addInst(.{
                                .tag = .mvn,
                                .data = .{ .rr_op = .{
                                    .rd = dest_reg,
                                    .rn = undefined,
                                    .op = Instruction.Operand.reg(op_reg, Instruction.Operand.Shift.none),
                                } },
                            });

                            if (int_info.bits < 32) {
                                try self.truncRegister(dest_reg, dest_reg, int_info.signedness, int_info.bits);
                            }

                            break :result MCValue{ .register = dest_reg };
                        } else {
                            return self.fail("TODO ARM not on integers > u32/i32", .{});
                        }
                    },
                    else => unreachable,
                }
            },
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn minMax(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    switch (lhs_ty.zigTypeTag()) {
        .Float => return self.fail("TODO ARM min/max on floats", .{}),
        .Vector => return self.fail("TODO ARM min/max on vectors", .{}),
        .Int => {
            const mod = self.bin_file.options.module.?;
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(self.target.*);
            if (int_info.bits <= 32) {
                const lhs_is_register = lhs == .register;
                const rhs_is_register = rhs == .register;

                const lhs_reg = switch (lhs) {
                    .register => |r| r,
                    else => try self.copyToTmpRegister(lhs_ty, lhs),
                };
                const lhs_reg_lock = self.register_manager.lockReg(lhs_reg);
                defer if (lhs_reg_lock) |reg| self.register_manager.unlockReg(reg);

                const rhs_reg = switch (rhs) {
                    .register => |r| r,
                    else => try self.copyToTmpRegister(rhs_ty, rhs),
                };
                const rhs_reg_lock = self.register_manager.lockReg(rhs_reg);
                defer if (rhs_reg_lock) |reg| self.register_manager.unlockReg(reg);

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

                // lhs == reg should have been checked by airMinMax
                //
                // By guaranteeing lhs != rhs, we guarantee (dst !=
                // lhs) or (dst != rhs), which is a property we use to
                // omit generating one instruction when we reuse a
                // register.
                assert(lhs_reg != rhs_reg); // see note above

                _ = try self.binOpRegister(.cmp, .{ .register = lhs_reg }, .{ .register = rhs_reg }, lhs_ty, rhs_ty, null);

                const cond_choose_lhs: Condition = switch (tag) {
                    .max => switch (int_info.signedness) {
                        .signed => Condition.gt,
                        .unsigned => Condition.hi,
                    },
                    .min => switch (int_info.signedness) {
                        .signed => Condition.lt,
                        .unsigned => Condition.cc,
                    },
                    else => unreachable,
                };
                const cond_choose_rhs = cond_choose_lhs.negate();

                if (dest_reg != lhs_reg) {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = cond_choose_lhs,
                        .data = .{ .rr_op = .{
                            .rd = dest_reg,
                            .rn = .r0,
                            .op = Instruction.Operand.reg(lhs_reg, Instruction.Operand.Shift.none),
                        } },
                    });
                }
                if (dest_reg != rhs_reg) {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = cond_choose_rhs,
                        .data = .{ .rr_op = .{
                            .rd = dest_reg,
                            .rn = .r0,
                            .op = Instruction.Operand.reg(rhs_reg, Instruction.Operand.Shift.none),
                        } },
                    });
                }

                return MCValue{ .register = dest_reg };
            } else {
                return self.fail("TODO ARM min/max on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn airMinMax(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[inst];
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        if (bin_op.lhs == bin_op.rhs) break :result lhs;

        break :result try self.minMax(tag, inst, lhs, rhs, lhs_ty, rhs_ty);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const len_ty = self.air.typeOf(bin_op.rhs);

        const stack_offset = try self.allocMem(inst, 8, 4);
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(len_ty, stack_offset - 4, len);
        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

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
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

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

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[inst];
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.air.typeOf(extra.lhs);
        const rhs_ty = self.air.typeOf(extra.rhs);

        const tuple_ty = self.air.typeOfIndex(inst);
        const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
        const tuple_align = tuple_ty.abiAlignment(self.target.*);
        const overflow_bit_offset = @intCast(u32, tuple_ty.structFieldOffset(1, self.target.*));

        switch (lhs_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement add_with_overflow/sub_with_overflow for vectors", .{}),
            .Int => {
                const mod = self.bin_file.options.module.?;
                assert(lhs_ty.eql(rhs_ty, mod));
                const int_info = lhs_ty.intInfo(self.target.*);
                if (int_info.bits < 32) {
                    const stack_offset = try self.allocMem(inst, tuple_size, tuple_align);

                    try self.spillCompareFlagsIfOccupied();
                    self.cpsr_flags_inst = null;

                    const base_tag: Air.Inst.Tag = switch (tag) {
                        .add_with_overflow => .add,
                        .sub_with_overflow => .sub,
                        else => unreachable,
                    };
                    const dest = try self.binOp(base_tag, lhs, rhs, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_reg_lock);

                    const truncated_reg = try self.register_manager.allocReg(null, gp);
                    const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                    defer self.register_manager.unlockReg(truncated_reg_lock);

                    // sbfx/ubfx truncated, dest, #0, #bits
                    try self.truncRegister(dest_reg, truncated_reg, int_info.signedness, int_info.bits);

                    // cmp dest, truncated
                    _ = try self.binOp(.cmp_eq, dest, .{ .register = truncated_reg }, Type.usize, Type.usize, null);

                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = truncated_reg });
                    try self.genSetStack(Type.initTag(.u1), stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else if (int_info.bits == 32) {
                    // Only say yes if the operation is
                    // commutative, i.e. we can swap both of the
                    // operands
                    const lhs_immediate_ok = switch (tag) {
                        .add_with_overflow => lhs == .immediate and Instruction.Operand.fromU32(lhs.immediate) != null,
                        .sub_with_overflow => false,
                        else => unreachable,
                    };
                    const rhs_immediate_ok = switch (tag) {
                        .add_with_overflow,
                        .sub_with_overflow,
                        => rhs == .immediate and Instruction.Operand.fromU32(rhs.immediate) != null,
                        else => unreachable,
                    };

                    const mir_tag: Mir.Inst.Tag = switch (tag) {
                        .add_with_overflow => .adds,
                        .sub_with_overflow => .subs,
                        else => unreachable,
                    };

                    try self.spillCompareFlagsIfOccupied();
                    self.cpsr_flags_inst = inst;

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

                    if (tag == .sub_with_overflow) {
                        break :result MCValue{ .register_v_flag = dest.register };
                    }

                    switch (int_info.signedness) {
                        .unsigned => break :result MCValue{ .register_c_flag = dest.register },
                        .signed => break :result MCValue{ .register_v_flag = dest.register },
                    }
                } else {
                    return self.fail("TODO ARM overflow operations on integers > u32/i32", .{});
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    if (self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ extra.lhs, extra.rhs, .none });
    const result: MCValue = result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.air.typeOf(extra.lhs);
        const rhs_ty = self.air.typeOf(extra.rhs);

        const tuple_ty = self.air.typeOfIndex(inst);
        const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
        const tuple_align = tuple_ty.abiAlignment(self.target.*);
        const overflow_bit_offset = @intCast(u32, tuple_ty.structFieldOffset(1, self.target.*));

        switch (lhs_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement mul_with_overflow for vectors", .{}),
            .Int => {
                const mod = self.bin_file.options.module.?;
                assert(lhs_ty.eql(rhs_ty, mod));
                const int_info = lhs_ty.intInfo(self.target.*);
                if (int_info.bits <= 16) {
                    const stack_offset = try self.allocMem(inst, tuple_size, tuple_align);

                    try self.spillCompareFlagsIfOccupied();
                    self.cpsr_flags_inst = null;

                    const base_tag: Mir.Inst.Tag = switch (int_info.signedness) {
                        .signed => .smulbb,
                        .unsigned => .mul,
                    };

                    const dest = try self.binOpRegister(base_tag, lhs, rhs, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_reg_lock);

                    const truncated_reg = try self.register_manager.allocReg(null, gp);
                    const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                    defer self.register_manager.unlockReg(truncated_reg_lock);

                    // sbfx/ubfx truncated, dest, #0, #bits
                    try self.truncRegister(dest_reg, truncated_reg, int_info.signedness, int_info.bits);

                    // cmp dest, truncated
                    _ = try self.binOp(.cmp_eq, dest, .{ .register = truncated_reg }, Type.usize, Type.usize, null);

                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = truncated_reg });
                    try self.genSetStack(Type.initTag(.u1), stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else if (int_info.bits <= 32) {
                    const stack_offset = try self.allocMem(inst, tuple_size, tuple_align);

                    try self.spillCompareFlagsIfOccupied();
                    self.cpsr_flags_inst = null;

                    const base_tag: Mir.Inst.Tag = switch (int_info.signedness) {
                        .signed => .smull,
                        .unsigned => .umull,
                    };

                    // TODO extract umull etc. to binOpTwoRegister
                    // once MCValue.rr is implemented
                    const lhs_is_register = lhs == .register;
                    const rhs_is_register = rhs == .register;

                    const lhs_lock: ?RegisterLock = if (lhs_is_register)
                        self.register_manager.lockReg(lhs.register)
                    else
                        null;
                    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

                    const lhs_reg = if (lhs_is_register)
                        lhs.register
                    else
                        try self.register_manager.allocReg(null, gp);
                    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
                    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

                    const rhs_reg = if (rhs_is_register)
                        rhs.register
                    else
                        try self.register_manager.allocReg(null, gp);
                    const new_rhs_lock = self.register_manager.lockReg(rhs_reg);
                    defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

                    const dest_regs = try self.register_manager.allocRegs(2, .{ null, null }, gp);
                    const dest_regs_locks = self.register_manager.lockRegsAssumeUnused(2, dest_regs);
                    defer for (dest_regs_locks) |reg| {
                        self.register_manager.unlockReg(reg);
                    };
                    const rdlo = dest_regs[0];
                    const rdhi = dest_regs[1];

                    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);
                    if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

                    const truncated_reg = try self.register_manager.allocReg(null, gp);
                    const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                    defer self.register_manager.unlockReg(truncated_reg_lock);

                    _ = try self.addInst(.{
                        .tag = base_tag,
                        .data = .{ .rrrr = .{
                            .rdlo = rdlo,
                            .rdhi = rdhi,
                            .rn = lhs_reg,
                            .rm = rhs_reg,
                        } },
                    });

                    // sbfx/ubfx truncated, rdlo, #0, #bits
                    try self.truncRegister(rdlo, truncated_reg, int_info.signedness, int_info.bits);

                    // str truncated, [...]
                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = truncated_reg });

                    // cmp truncated, rdlo
                    _ = try self.binOp(.cmp_eq, .{ .register = truncated_reg }, .{ .register = rdlo }, Type.usize, Type.usize, null);

                    // mov rdlo, #0
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .data = .{ .rr_op = .{
                            .rd = rdlo,
                            .rn = .r0,
                            .op = Instruction.Operand.fromU32(0).?,
                        } },
                    });

                    // movne rdlo, #1
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = .ne,
                        .data = .{ .rr_op = .{
                            .rd = rdlo,
                            .rn = .r0,
                            .op = Instruction.Operand.fromU32(1).?,
                        } },
                    });

                    // cmp rdhi, #0
                    _ = try self.binOp(.cmp_eq, .{ .register = rdhi }, .{ .immediate = 0 }, Type.usize, Type.usize, null);

                    // movne rdlo, #1
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = .ne,
                        .data = .{ .rr_op = .{
                            .rd = rdlo,
                            .rn = .r0,
                            .op = Instruction.Operand.fromU32(1).?,
                        } },
                    });

                    // strb rdlo, [...]
                    try self.genSetStack(Type.initTag(.u1), stack_offset - overflow_bit_offset, .{ .register = rdlo });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else {
                    return self.fail("TODO ARM overflow operations on integers > u32/i32", .{});
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    if (self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ extra.lhs, extra.rhs, .none });
    const result: MCValue = result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.air.typeOf(extra.lhs);
        const rhs_ty = self.air.typeOf(extra.rhs);

        const tuple_ty = self.air.typeOfIndex(inst);
        const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
        const tuple_align = tuple_ty.abiAlignment(self.target.*);
        const overflow_bit_offset = @intCast(u32, tuple_ty.structFieldOffset(1, self.target.*));

        switch (lhs_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement shl_with_overflow for vectors", .{}),
            .Int => {
                const int_info = lhs_ty.intInfo(self.target.*);
                if (int_info.bits <= 32) {
                    const stack_offset = try self.allocMem(inst, tuple_size, tuple_align);

                    const lhs_lock: ?RegisterLock = if (lhs == .register)
                        self.register_manager.lockRegAssumeUnused(lhs.register)
                    else
                        null;
                    defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

                    try self.spillCompareFlagsIfOccupied();
                    self.cpsr_flags_inst = null;

                    // lsl dest, lhs, rhs
                    const dest = try self.binOp(.shl, lhs, rhs, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_lock);

                    // asr/lsr reconstructed, dest, rhs
                    const reconstructed = try self.binOp(.shr, dest, rhs, lhs_ty, rhs_ty, null);

                    // cmp lhs, reconstructed
                    _ = try self.binOp(.cmp_eq, lhs, reconstructed, lhs_ty, lhs_ty, null);

                    try self.genSetStack(lhs_ty, stack_offset, dest);
                    try self.genSetStack(Type.initTag(.u1), stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else {
                    return self.fail("TODO ARM overflow operations on integers > u32/i32", .{});
                }
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
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

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const optional_ty = self.air.typeOfIndex(inst);
        const abi_size = @intCast(u32, optional_ty.abiSize(self.target.*));

        // Optional with a zero-bit payload type is just a boolean true
        if (abi_size == 1) {
            break :result MCValue{ .immediate = 1 };
        } else {
            return self.fail("TODO implement wrap optional for {}", .{self.target.cpu.arch});
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// Given an error union, returns the error
fn errUnionErr(self: *Self, error_union_mcv: MCValue, error_union_ty: Type) !MCValue {
    const err_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();
    if (err_ty.errorSetIsEmpty()) {
        return MCValue{ .immediate = 0 };
    }
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return error_union_mcv;
    }

    const err_offset = @intCast(u32, errUnionErrorOffset(payload_ty, self.target.*));
    switch (error_union_mcv) {
        .register => return self.fail("TODO errUnionErr for registers", .{}),
        .stack_argument_offset => |off| {
            return MCValue{ .stack_argument_offset = off - err_offset };
        },
        .stack_offset => |off| {
            return MCValue{ .stack_offset = off - err_offset };
        },
        .memory => |addr| {
            return MCValue{ .memory = addr + err_offset };
        },
        else => unreachable, // invalid MCValue for an error union
    }
}

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.air.typeOf(ty_op.operand);
        const mcv = try self.resolveInst(ty_op.operand);
        break :result try self.errUnionErr(mcv, error_union_ty);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// Given an error union, returns the payload
fn errUnionPayload(self: *Self, error_union_mcv: MCValue, error_union_ty: Type) !MCValue {
    const err_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();
    if (err_ty.errorSetIsEmpty()) {
        return error_union_mcv;
    }
    if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
        return MCValue.none;
    }

    const payload_offset = @intCast(u32, errUnionPayloadOffset(payload_ty, self.target.*));
    switch (error_union_mcv) {
        .register => return self.fail("TODO errUnionPayload for registers", .{}),
        .stack_argument_offset => |off| {
            return MCValue{ .stack_argument_offset = off - payload_offset };
        },
        .stack_offset => |off| {
            return MCValue{ .stack_offset = off - payload_offset };
        },
        .memory => |addr| {
            return MCValue{ .memory = addr + payload_offset };
        },
        else => unreachable, // invalid MCValue for an error union
    }
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.air.typeOf(ty_op.operand);
        const error_union = try self.resolveInst(ty_op.operand);
        break :result try self.errUnionPayload(error_union, error_union_ty);
    };
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

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.air.getRefType(ty_op.ty);
        const payload_ty = error_union_ty.errorUnionPayload();
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) break :result operand;

        const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
        const abi_align = error_union_ty.abiAlignment(self.target.*);
        const stack_offset = @intCast(u32, try self.allocMem(inst, abi_size, abi_align));
        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        const err_off = errUnionErrorOffset(payload_ty, self.target.*);
        try self.genSetStack(payload_ty, stack_offset - @intCast(u32, payload_off), operand);
        try self.genSetStack(Type.anyerror, stack_offset - @intCast(u32, err_off), .{ .immediate = 0 });

        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.air.getRefType(ty_op.ty);
        const payload_ty = error_union_ty.errorUnionPayload();
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) break :result operand;

        const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
        const abi_align = error_union_ty.abiAlignment(self.target.*);
        const stack_offset = @intCast(u32, try self.allocMem(inst, abi_size, abi_align));
        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        const err_off = errUnionErrorOffset(payload_ty, self.target.*);
        try self.genSetStack(Type.anyerror, stack_offset - @intCast(u32, err_off), operand);
        try self.genSetStack(payload_ty, stack_offset - @intCast(u32, payload_off), .undef);

        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// Given a slice, returns the length
fn slicePtr(mcv: MCValue) MCValue {
    switch (mcv) {
        .register => unreachable, // a slice doesn't fit in one register
        .stack_argument_offset => |off| {
            return MCValue{ .stack_argument_offset = off };
        },
        .stack_offset => |off| {
            return MCValue{ .stack_offset = off };
        },
        .memory => |addr| {
            return MCValue{ .memory = addr };
        },
        else => unreachable, // invalid MCValue for a slice
    }
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        break :result slicePtr(mcv);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach => unreachable,
            .register => unreachable, // a slice doesn't fit in one register
            .stack_argument_offset => |off| {
                break :result MCValue{ .stack_argument_offset = off - 4 };
            },
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - 4 };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr + 4 };
            },
            else => return self.fail("TODO implement slice_len for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off - 4 };
            },
            else => return self.fail("TODO implement ptr_slice_len_ptr for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off };
            },
            else => return self.fail("TODO implement ptr_slice_ptr_ptr for {}", .{mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (!is_volatile and self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    const result: MCValue = result: {
        const slice_mcv = try self.resolveInst(bin_op.lhs);

        // TODO optimize for the case where the index is a constant,
        // i.e. index_mcv == .immediate
        const index_mcv = try self.resolveInst(bin_op.rhs);
        const index_is_register = index_mcv == .register;

        const slice_ty = self.air.typeOf(bin_op.lhs);
        const elem_ty = slice_ty.childType();
        const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);

        const index_lock: ?RegisterLock = if (index_is_register)
            self.register_manager.lockRegAssumeUnused(index_mcv.register)
        else
            null;
        defer if (index_lock) |reg| self.register_manager.unlockReg(reg);

        const base_mcv = slicePtr(slice_mcv);

        switch (elem_size) {
            1, 4 => {
                const base_reg = switch (base_mcv) {
                    .register => |r| r,
                    else => try self.copyToTmpRegister(slice_ptr_field_type, base_mcv),
                };
                const base_reg_lock = self.register_manager.lockRegAssumeUnused(base_reg);
                defer self.register_manager.unlockReg(base_reg_lock);

                const dst_reg = try self.register_manager.allocReg(inst, gp);
                const dst_mcv = MCValue{ .register = dst_reg };
                const dst_reg_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                defer self.register_manager.unlockReg(dst_reg_lock);

                const index_reg: Register = switch (index_mcv) {
                    .register => |reg| reg,
                    else => try self.copyToTmpRegister(Type.usize, index_mcv),
                };
                const index_reg_lock = self.register_manager.lockReg(index_reg);
                defer if (index_reg_lock) |lock| self.register_manager.unlockReg(lock);

                const tag: Mir.Inst.Tag = switch (elem_size) {
                    1 => .ldrb,
                    4 => .ldr,
                    else => unreachable,
                };
                const shift: u5 = switch (elem_size) {
                    1 => 0,
                    4 => 2,
                    else => unreachable,
                };

                _ = try self.addInst(.{
                    .tag = tag,
                    .data = .{ .rr_offset = .{
                        .rt = dst_reg,
                        .rn = base_reg,
                        .offset = .{ .offset = Instruction.Offset.reg(index_reg, .{ .lsl = shift }) },
                    } },
                });

                break :result dst_mcv;
            },
            else => {
                const dest = try self.allocRegOrMem(inst, true);
                const addr = try self.binOp(.ptr_add, base_mcv, index_mcv, slice_ptr_field_type, Type.usize, null);
                try self.load(dest, addr, slice_ptr_field_type);

                break :result dest;
            },
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const slice_mcv = try self.resolveInst(extra.lhs);
        const index_mcv = try self.resolveInst(extra.rhs);
        const base_mcv = slicePtr(slice_mcv);

        const slice_ty = self.air.typeOf(extra.lhs);

        const addr = try self.binOp(.ptr_add, base_mcv, index_mcv, slice_ty, Type.usize, null);
        break :result addr;
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_mcv = try self.resolveInst(extra.lhs);
        const index_mcv = try self.resolveInst(extra.rhs);

        const ptr_ty = self.air.typeOf(extra.lhs);

        const addr = try self.binOp(.ptr_add, ptr_mcv, index_mcv, ptr_ty, Type.usize, null);
        break :result addr;
    };
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
    _ = ty_op;
    return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airByteSwap for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
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
            // We assert that this register is allocatable by asking
            // for its index
            const index = RegisterManager.indexOfRegIntoTracked(reg).?; // see note above
            if (!self.register_manager.isRegFree(reg)) {
                self.register_manager.registers[index] = inst;
            }

            log.debug("%{d} => {} (reused)", .{ inst, reg });
        },
        .stack_offset => |off| {
            log.debug("%{d} => stack offset {d} (reused)", .{ inst, off });
        },
        .cpsr_flags => {
            log.debug("%{d} => cpsr_flags (reused)", .{inst});
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
    const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .cpsr_flags,
        .register_c_flag,
        .register_v_flag,
        => unreachable, // cannot hold an address
        .immediate => |imm| try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm }),
        .ptr_stack_offset => |off| try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off }),
        .register => |reg| {
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |reg_locked| self.register_manager.unlockReg(reg_locked);

            switch (dst_mcv) {
                .dead => unreachable,
                .undef => unreachable,
                .cpsr_flags => unreachable,
                .register => |dst_reg| {
                    try self.genLdrRegister(dst_reg, reg, elem_ty);
                },
                .stack_offset => |off| {
                    if (elem_size <= 4) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        const tmp_reg_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                        defer self.register_manager.unlockReg(tmp_reg_lock);

                        try self.load(.{ .register = tmp_reg }, ptr, ptr_ty);
                        try self.genSetStack(elem_ty, off, MCValue{ .register = tmp_reg });
                    } else {
                        // TODO optimize the register allocation
                        const regs = try self.register_manager.allocRegs(4, .{ null, null, null, null }, gp);
                        const regs_locks = self.register_manager.lockRegsAssumeUnused(4, regs);
                        defer for (regs_locks) |reg_locked| {
                            self.register_manager.unlockReg(reg_locked);
                        };

                        const src_reg = reg;
                        const dst_reg = regs[0];
                        const len_reg = regs[1];
                        const count_reg = regs[2];
                        const tmp_reg = regs[3];

                        // sub dst_reg, fp, #off
                        try self.genSetReg(ptr_ty, dst_reg, .{ .ptr_stack_offset = off });

                        // mov len, #elem_size
                        try self.genSetReg(Type.usize, len_reg, .{ .immediate = elem_size });

                        // memcpy(src, dst, len)
                        try self.genInlineMemcpy(src_reg, dst_reg, len_reg, count_reg, tmp_reg);
                    }
                },
                else => return self.fail("TODO load from register into {}", .{dst_mcv}),
            }
        },
        .memory,
        .stack_offset,
        .stack_argument_offset,
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

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    const elem_size = @intCast(u32, value_ty.abiSize(self.target.*));

    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .cpsr_flags,
        .register_c_flag,
        .register_v_flag,
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
                .dead => unreachable,
                .undef => unreachable,
                .register => |value_reg| {
                    try self.genStrRegister(value_reg, addr_reg, value_ty);
                },
                else => {
                    if (elem_size <= 4) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        const tmp_reg_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                        defer self.register_manager.unlockReg(tmp_reg_lock);

                        try self.genSetReg(value_ty, tmp_reg, value);
                        try self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                    } else {
                        const regs = try self.register_manager.allocRegs(4, .{ null, null, null, null }, gp);
                        const regs_locks = self.register_manager.lockRegsAssumeUnused(4, regs);
                        defer for (regs_locks) |reg| {
                            self.register_manager.unlockReg(reg);
                        };

                        const src_reg = regs[0];
                        const dst_reg = addr_reg;
                        const len_reg = regs[1];
                        const count_reg = regs[2];
                        const tmp_reg = regs[3];

                        switch (value) {
                            .stack_offset => |off| {
                                // sub src_reg, fp, #off
                                try self.genSetReg(ptr_ty, src_reg, .{ .ptr_stack_offset = off });
                            },
                            .memory => |addr| try self.genSetReg(Type.usize, src_reg, .{ .immediate = @intCast(u32, addr) }),
                            .stack_argument_offset => |off| {
                                _ = try self.addInst(.{
                                    .tag = .ldr_ptr_stack_argument,
                                    .data = .{ .r_stack_offset = .{
                                        .rt = src_reg,
                                        .stack_offset = off,
                                    } },
                                });
                            },
                            else => return self.fail("TODO store {} to register", .{value}),
                        }

                        // mov len, #elem_size
                        try self.genSetReg(Type.usize, len_reg, .{ .immediate = elem_size });

                        // memcpy(src, dst, len)
                        try self.genInlineMemcpy(src_reg, dst_reg, len_reg, count_reg, tmp_reg);
                    }
                },
            }
        },
        .memory,
        .stack_offset,
        .stack_argument_offset,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.store(.{ .register = addr_reg }, value, ptr_ty, value_ty);
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
    const result = try self.structFieldPtr(inst, extra.struct_operand, extra.field_index);
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = try self.structFieldPtr(inst, ty_op.operand, index);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn structFieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, index: u32) !MCValue {
    return if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(operand);
        const ptr_ty = self.air.typeOf(operand);
        const struct_ty = ptr_ty.childType();
        const struct_field_offset = @intCast(u32, struct_ty.structFieldOffset(index, self.target.*));
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

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(operand);
        const struct_ty = self.air.typeOf(operand);
        const struct_field_offset = @intCast(u32, struct_ty.structFieldOffset(index, self.target.*));

        switch (mcv) {
            .dead, .unreach => unreachable,
            .stack_argument_offset => |off| {
                break :result MCValue{ .stack_argument_offset = off - struct_field_offset };
            },
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - struct_field_offset };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr + struct_field_offset };
            },
            .register_c_flag,
            .register_v_flag,
            => |reg| {
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);

                const field: MCValue = switch (index) {
                    // get wrapped value: return register
                    0 => MCValue{ .register = reg },

                    // get overflow bit: return C or V flag
                    1 => MCValue{ .cpsr_flags = switch (mcv) {
                        .register_c_flag => .cs,
                        .register_v_flag => .vs,
                        else => unreachable,
                    } },

                    else => unreachable,
                };

                if (self.reuseOperand(inst, operand, 0, field)) {
                    break :result field;
                } else {
                    // Copy to new register
                    const dest_reg = try self.register_manager.allocReg(null, gp);
                    try self.genSetReg(struct_ty.structFieldType(index), dest_reg, field);

                    break :result MCValue{ .register = dest_reg };
                }
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFieldParentPtr", .{});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

/// Allocates a new register. If Inst in non-null, additionally tracks
/// this register and the corresponding int and removes all previous
/// tracking. Does not do the actual moving (that is handled by
/// genSetReg).
fn prepareNewRegForMoving(
    self: *Self,
    track_inst: ?Air.Inst.Index,
    register_class: RegisterManager.RegisterBitSet,
    mcv: MCValue,
) !Register {
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    const reg = try self.register_manager.allocReg(track_inst, register_class);

    if (track_inst) |inst| {
        // Overwrite the MCValue associated with this inst
        branch.inst_table.putAssumeCapacity(inst, .{ .register = reg });

        // If the previous MCValue occupied some space we track, we
        // need to make sure it is marked as free now.
        switch (mcv) {
            .cpsr_flags => {
                assert(self.cpsr_flags_inst.? == inst);
                self.cpsr_flags_inst = null;
            },
            .register => |prev_reg| {
                assert(!self.register_manager.isRegFree(prev_reg));
                self.register_manager.freeReg(prev_reg);
            },
            else => {},
        }
    }

    return reg;
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

    const lhs_reg = if (lhs_is_register) lhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst Air.refToIndex(md.lhs).?;
        } else null;

        break :blk try self.prepareNewRegForMoving(track_inst, gp, lhs);
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const rhs_reg = if (rhs_is_register) rhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst Air.refToIndex(md.rhs).?;
        } else null;

        break :blk try self.prepareNewRegForMoving(track_inst, gp, rhs);
    };
    const new_rhs_lock = self.register_manager.lockReg(rhs_reg);
    defer if (new_rhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = switch (mir_tag) {
        .cmp => .r0, // cmp has no destination regardless
        else => if (metadata) |md| blk: {
            if (lhs_is_register and self.reuseOperand(md.inst, md.lhs, 0, lhs)) {
                break :blk lhs_reg;
            } else if (rhs_is_register and self.reuseOperand(md.inst, md.rhs, 1, rhs)) {
                break :blk rhs_reg;
            } else {
                break :blk try self.register_manager.allocReg(md.inst, gp);
            }
        } else try self.register_manager.allocReg(null, gp),
    };

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);
    if (!rhs_is_register) try self.genSetReg(rhs_ty, rhs_reg, rhs);

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .adds,
        .sub,
        .subs,
        .cmp,
        .@"and",
        .orr,
        .eor,
        => .{ .rr_op = .{
            .rd = dest_reg,
            .rn = lhs_reg,
            .op = Instruction.Operand.reg(rhs_reg, Instruction.Operand.Shift.none),
        } },
        .lsl,
        .asr,
        .lsr,
        => .{ .rr_shift = .{
            .rd = dest_reg,
            .rm = lhs_reg,
            .shift_amount = Instruction.ShiftAmount.reg(rhs_reg),
        } },
        .mul,
        .smulbb,
        => .{ .rrr = .{
            .rd = dest_reg,
            .rn = lhs_reg,
            .rm = rhs_reg,
        } },
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
///     op dest, lhs, #rhs_imm
///
/// Set lhs_and_rhs_swapped to true iff inst.bin_op.lhs corresponds to
/// rhs and vice versa. This parameter is only used when maybe_inst !=
/// null.
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

    const lhs_reg = if (lhs_is_register) lhs.register else blk: {
        const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
            break :inst Air.refToIndex(
                if (lhs_and_rhs_swapped) md.rhs else md.lhs,
            ).?;
        } else null;

        break :blk try self.prepareNewRegForMoving(track_inst, gp, lhs);
    };
    const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
    defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

    const dest_reg = switch (mir_tag) {
        .cmp => .r0, // cmp has no destination reg
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
        } else try self.register_manager.allocReg(null, gp),
    };

    if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .adds,
        .sub,
        .subs,
        .cmp,
        .@"and",
        .orr,
        .eor,
        => .{ .rr_op = .{
            .rd = dest_reg,
            .rn = lhs_reg,
            .op = Instruction.Operand.fromU32(rhs.immediate).?,
        } },
        .lsl,
        .asr,
        .lsr,
        => .{ .rr_shift = .{
            .rd = dest_reg,
            .rm = lhs_reg,
            .shift_amount = Instruction.ShiftAmount.imm(@intCast(u5, rhs.immediate)),
        } },
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = mir_data,
    });

    return MCValue{ .register = dest_reg };
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
    switch (tag) {
        .add,
        .sub,
        .cmp_eq,
        => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        // Only say yes if the operation is
                        // commutative, i.e. we can swap both of the
                        // operands
                        const lhs_immediate_ok = switch (tag) {
                            .add => lhs == .immediate and Instruction.Operand.fromU32(lhs.immediate) != null,
                            .sub,
                            .cmp_eq,
                            => false,
                            else => unreachable,
                        };
                        const rhs_immediate_ok = switch (tag) {
                            .add,
                            .sub,
                            .cmp_eq,
                            => rhs == .immediate and Instruction.Operand.fromU32(rhs.immediate) != null,
                            else => unreachable,
                        };

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .add => .add,
                            .sub => .sub,
                            .cmp_eq => .cmp,
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                        } else if (lhs_immediate_ok) {
                            // swap lhs and rhs
                            return try self.binOpImmediate(mir_tag, rhs, lhs, rhs_ty, true, metadata);
                        } else {
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .mul => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        // TODO add optimisations for multiplication
                        // with immediates, for example a * 2 can be
                        // lowered to a << 1
                        return try self.binOpRegister(.mul, lhs, rhs, lhs_ty, rhs_ty, metadata);
                    } else {
                        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .div_float => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                else => unreachable,
            }
        },
        .div_trunc, .div_floor => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        switch (int_info.signedness) {
                            .signed => {
                                return self.fail("TODO ARM signed integer division", .{});
                            },
                            .unsigned => {
                                switch (rhs) {
                                    .immediate => |imm| {
                                        if (std.math.isPowerOfTwo(imm)) {
                                            const shift = MCValue{ .immediate = std.math.log2_int(u32, imm) };
                                            return try self.binOp(.shr, lhs, shift, lhs_ty, rhs_ty, metadata);
                                        } else {
                                            return self.fail("TODO ARM integer division by constants", .{});
                                        }
                                    },
                                    else => return self.fail("TODO ARM integer division", .{}),
                                }
                            },
                        }
                    } else {
                        return self.fail("TODO ARM integer division for integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .div_exact => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => return self.fail("TODO ARM div_exact", .{}),
                else => unreachable,
            }
        },
        .rem => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        switch (int_info.signedness) {
                            .signed => {
                                return self.fail("TODO ARM signed integer mod", .{});
                            },
                            .unsigned => {
                                switch (rhs) {
                                    .immediate => |imm| {
                                        if (std.math.isPowerOfTwo(imm)) {
                                            const log2 = std.math.log2_int(u32, imm);

                                            const lhs_is_register = lhs == .register;

                                            const lhs_lock: ?RegisterLock = if (lhs_is_register)
                                                self.register_manager.lockReg(lhs.register)
                                            else
                                                null;
                                            defer if (lhs_lock) |reg| self.register_manager.unlockReg(reg);

                                            const lhs_reg = if (lhs_is_register) lhs.register else blk: {
                                                const track_inst: ?Air.Inst.Index = if (metadata) |md| inst: {
                                                    break :inst Air.refToIndex(md.lhs).?;
                                                } else null;

                                                break :blk try self.prepareNewRegForMoving(track_inst, gp, lhs);
                                            };
                                            const new_lhs_lock = self.register_manager.lockReg(lhs_reg);
                                            defer if (new_lhs_lock) |reg| self.register_manager.unlockReg(reg);

                                            const dest_reg = if (metadata) |md| blk: {
                                                if (lhs_is_register and self.reuseOperand(md.inst, md.lhs, 0, lhs)) {
                                                    break :blk lhs_reg;
                                                } else {
                                                    break :blk try self.register_manager.allocReg(md.inst, gp);
                                                }
                                            } else try self.register_manager.allocReg(null, gp);

                                            if (!lhs_is_register) try self.genSetReg(lhs_ty, lhs_reg, lhs);

                                            try self.truncRegister(lhs_reg, dest_reg, int_info.signedness, log2);
                                            return MCValue{ .register = dest_reg };
                                        } else {
                                            return self.fail("TODO ARM integer mod by constants", .{});
                                        }
                                    },
                                    else => return self.fail("TODO ARM integer mod", .{}),
                                }
                            },
                        }
                    } else {
                        return self.fail("TODO ARM integer division for integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .mod => {
            switch (lhs_ty.zigTypeTag()) {
                .Float => return self.fail("TODO ARM binary operations on floats", .{}),
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => return self.fail("TODO ARM mod", .{}),
                else => unreachable,
            }
        },
        .addwrap,
        .subwrap,
        .mulwrap,
        => {
            const base_tag: Air.Inst.Tag = switch (tag) {
                .addwrap => .add,
                .subwrap => .sub,
                .mulwrap => .mul,
                else => unreachable,
            };

            // Generate an add/sub/mul
            const result = try self.binOp(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);

            // Truncate if necessary
            switch (lhs_ty.zigTypeTag()) {
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        const result_reg = result.register;

                        if (int_info.bits < 32) {
                            try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                            return result;
                        } else return result;
                    } else {
                        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .bit_and,
        .bit_or,
        .xor,
        => {
            switch (lhs_ty.zigTypeTag()) {
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const mod = self.bin_file.options.module.?;
                    assert(lhs_ty.eql(rhs_ty, mod));
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        const lhs_immediate_ok = lhs == .immediate and Instruction.Operand.fromU32(lhs.immediate) != null;
                        const rhs_immediate_ok = rhs == .immediate and Instruction.Operand.fromU32(rhs.immediate) != null;

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .bit_and => .@"and",
                            .bit_or => .orr,
                            .xor => .eor,
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                        } else if (lhs_immediate_ok) {
                            // swap lhs and rhs
                            return try self.binOpImmediate(mir_tag, rhs, lhs, rhs_ty, true, metadata);
                        } else {
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                    }
                },
                else => unreachable,
            }
        },
        .shl_exact,
        .shr_exact,
        => {
            switch (lhs_ty.zigTypeTag()) {
                .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                .Int => {
                    const int_info = lhs_ty.intInfo(self.target.*);
                    if (int_info.bits <= 32) {
                        const rhs_immediate_ok = rhs == .immediate;

                        const mir_tag: Mir.Inst.Tag = switch (tag) {
                            .shl_exact => .lsl,
                            .shr_exact => switch (lhs_ty.intInfo(self.target.*).signedness) {
                                .signed => Mir.Inst.Tag.asr,
                                .unsigned => Mir.Inst.Tag.lsr,
                            },
                            else => unreachable,
                        };

                        if (rhs_immediate_ok) {
                            return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                        } else {
                            return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                        }
                    } else {
                        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                    }
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

            // Generate a shl_exact/shr_exact
            const result = try self.binOp(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);

            // Truncate if necessary
            switch (tag) {
                .shr => return result,
                .shl => switch (lhs_ty.zigTypeTag()) {
                    .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
                    .Int => {
                        const int_info = lhs_ty.intInfo(self.target.*);
                        if (int_info.bits <= 32) {
                            const result_reg = result.register;

                            if (int_info.bits < 32) {
                                try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                                return result;
                            } else return result;
                        } else {
                            return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
                        }
                    },
                    else => unreachable,
                },
                else => unreachable,
            }
        },
        .bool_and,
        .bool_or,
        => {
            switch (lhs_ty.zigTypeTag()) {
                .Bool => {
                    const lhs_immediate_ok = lhs == .immediate;
                    const rhs_immediate_ok = rhs == .immediate;

                    const mir_tag: Mir.Inst.Tag = switch (tag) {
                        .bool_and => .@"and",
                        .bool_or => .orr,
                        else => unreachable,
                    };

                    if (rhs_immediate_ok) {
                        return try self.binOpImmediate(mir_tag, lhs, rhs, lhs_ty, false, metadata);
                    } else if (lhs_immediate_ok) {
                        // swap lhs and rhs
                        return try self.binOpImmediate(mir_tag, rhs, lhs, rhs_ty, true, metadata);
                    } else {
                        return try self.binOpRegister(mir_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
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
                    const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

                    if (elem_size == 1) {
                        const base_tag: Mir.Inst.Tag = switch (tag) {
                            .ptr_add => .add,
                            .ptr_sub => .sub,
                            else => unreachable,
                        };

                        return try self.binOpRegister(base_tag, lhs, rhs, lhs_ty, rhs_ty, metadata);
                    } else {
                        // convert the offset into a byte offset by
                        // multiplying it with elem_size
                        const offset = try self.binOp(.mul, rhs, .{ .immediate = elem_size }, Type.usize, Type.usize, null);
                        const addr = try self.binOp(tag, lhs, offset, Type.initTag(.manyptr_u8), Type.usize, null);
                        return addr;
                    }
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

fn genLdrRegister(self: *Self, dest_reg: Register, addr_reg: Register, ty: Type) !void {
    const abi_size = ty.abiSize(self.target.*);

    const tag: Mir.Inst.Tag = switch (abi_size) {
        1 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsb else .ldrb,
        2 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsh else .ldrh,
        3, 4 => .ldr,
        else => unreachable,
    };

    const rr_offset: Mir.Inst.Data = .{ .rr_offset = .{
        .rt = dest_reg,
        .rn = addr_reg,
        .offset = .{ .offset = Instruction.Offset.none },
    } };
    const rr_extra_offset: Mir.Inst.Data = .{ .rr_extra_offset = .{
        .rt = dest_reg,
        .rn = addr_reg,
        .offset = .{ .offset = Instruction.ExtraLoadStoreOffset.none },
    } };

    const data: Mir.Inst.Data = switch (abi_size) {
        1 => if (ty.isSignedInt()) rr_extra_offset else rr_offset,
        2 => rr_extra_offset,
        3, 4 => rr_offset,
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = tag,
        .data = data,
    });
}

fn genStrRegister(self: *Self, source_reg: Register, addr_reg: Register, ty: Type) !void {
    const abi_size = ty.abiSize(self.target.*);

    const tag: Mir.Inst.Tag = switch (abi_size) {
        1 => .strb,
        2 => .strh,
        3, 4 => .str,
        else => unreachable,
    };

    const rr_offset: Mir.Inst.Data = .{ .rr_offset = .{
        .rt = source_reg,
        .rn = addr_reg,
        .offset = .{ .offset = Instruction.Offset.none },
    } };
    const rr_extra_offset: Mir.Inst.Data = .{ .rr_extra_offset = .{
        .rt = source_reg,
        .rn = addr_reg,
        .offset = .{ .offset = Instruction.ExtraLoadStoreOffset.none },
    } };

    const data: Mir.Inst.Data = switch (abi_size) {
        1, 3, 4 => rr_offset,
        2 => rr_extra_offset,
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = tag,
        .data = data,
    });
}

fn genInlineMemcpy(
    self: *Self,
    src: Register,
    dst: Register,
    len: Register,
    count: Register,
    tmp: Register,
) !void {
    // mov count, #0
    _ = try self.addInst(.{
        .tag = .mov,
        .data = .{ .rr_op = .{
            .rd = count,
            .rn = .r0,
            .op = Instruction.Operand.imm(0, 0),
        } },
    });

    // loop:
    // cmp count, len
    _ = try self.addInst(.{
        .tag = .cmp,
        .data = .{ .rr_op = .{
            .rd = .r0,
            .rn = count,
            .op = Instruction.Operand.reg(len, Instruction.Operand.Shift.none),
        } },
    });

    // bge end
    _ = try self.addInst(.{
        .tag = .b,
        .cond = .ge,
        .data = .{ .inst = @intCast(u32, self.mir_instructions.len + 5) },
    });

    // ldrb tmp, [src, count]
    _ = try self.addInst(.{
        .tag = .ldrb,
        .data = .{ .rr_offset = .{
            .rt = tmp,
            .rn = src,
            .offset = .{ .offset = Instruction.Offset.reg(count, .none) },
        } },
    });

    // strb tmp, [src, count]
    _ = try self.addInst(.{
        .tag = .strb,
        .data = .{ .rr_offset = .{
            .rt = tmp,
            .rn = dst,
            .offset = .{ .offset = Instruction.Offset.reg(count, .none) },
        } },
    });

    // add count, count, #1
    _ = try self.addInst(.{
        .tag = .add,
        .data = .{ .rr_op = .{
            .rd = count,
            .rn = count,
            .op = Instruction.Operand.imm(1, 0),
        } },
    });

    // b loop
    _ = try self.addInst(.{
        .tag = .b,
        .data = .{ .inst = @intCast(u32, self.mir_instructions.len - 5) },
    });

    // end:
}

/// Adds a Type to the .debug_info at the current position. The bytes will be populated later,
/// after codegen for this symbol is done.
fn addDbgInfoTypeReloc(self: *Self, ty: Type) error{OutOfMemory}!void {
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

fn genArgDbgInfo(self: *Self, inst: Air.Inst.Index, arg_index: u32, stack_byte_count: u32) error{OutOfMemory}!void {
    const prologue_stack_space = stack_byte_count + self.saved_regs_stack_space;

    const mcv = self.args[arg_index];
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
        .stack_offset,
        .stack_argument_offset,
        => {
            switch (self.debug_output) {
                .dwarf => |dw| {
                    // const abi_size = @intCast(u32, ty.abiSize(self.target.*));
                    const adjusted_stack_offset = switch (mcv) {
                        .stack_offset => |offset| -@intCast(i32, offset),
                        .stack_argument_offset => |offset| @intCast(i32, prologue_stack_space - offset),
                        else => unreachable,
                    };

                    const dbg_info = &dw.dbg_info;
                    try dbg_info.append(@enumToInt(link.File.Dwarf.AbbrevKind.parameter));

                    // Get length of the LEB128 stack offset
                    var counting_writer = std.io.countingWriter(std.io.null_writer);
                    leb128.writeILEB128(counting_writer.writer(), adjusted_stack_offset) catch unreachable;

                    // DW.AT.location, DW.FORM.exprloc
                    // ULEB128 dwarf expression length
                    try leb128.writeULEB128(dbg_info.writer(), counting_writer.bytes_written + 1);
                    try dbg_info.append(DW.OP.breg11);
                    try leb128.writeILEB128(dbg_info.writer(), adjusted_stack_offset);

                    try dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                    try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                    dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
                },
                .plan9 => {},
                .none => {},
            }
        },
        else => unreachable, // not a possible argument
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.air.typeOfIndex(inst);

    const result = self.args[arg_index];
    const mcv = switch (result) {
        // Copy registers to the stack
        .register => |reg| blk: {
            const abi_size = @intCast(u32, ty.abiSize(self.target.*));
            const abi_align = ty.abiAlignment(self.target.*);
            const stack_offset = try self.allocMem(inst, abi_size, abi_align);
            try self.genSetStack(ty, stack_offset, MCValue{ .register = reg });

            break :blk MCValue{ .stack_offset = stack_offset };
        },
        else => result,
    };

    try self.dbg_arg_relocs.append(self.gpa, .{
        .inst = inst,
        .index = arg_index,
    });

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
        .tag = .bkpt,
        .data = .{ .imm16 = 0 },
    });
    return self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airRetAddr for arm", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFrameAddress for arm", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for arm", .{});
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);
    const ty = self.air.typeOf(callee);

    const fn_ty = switch (ty.zigTypeTag()) {
        .Fn => ty,
        .Pointer => ty.childType(),
        else => unreachable,
    };

    var info = try self.resolveCallingConventionValues(fn_ty);
    defer info.deinit(self);

    // According to the Procedure Call Standard for the ARM
    // Architecture, compare flags are not preserved across
    // calls. Therefore, if some value is currently stored there, we
    // need to save it.
    try self.spillCompareFlagsIfOccupied();

    // Save caller-saved registers, but crucially *after* we save the
    // compare flags as saving compare flags may require a new
    // caller-saved register
    for (caller_preserved_regs) |reg| {
        try self.register_manager.getReg(reg, null);
    }

    if (info.return_value == .stack_offset) {
        log.debug("airCall: return by reference", .{});
        const ret_ty = fn_ty.fnReturnType();
        const ret_abi_size = @intCast(u32, ret_ty.abiSize(self.target.*));
        const ret_abi_align = @intCast(u32, ret_ty.abiAlignment(self.target.*));
        const stack_offset = try self.allocMem(inst, ret_abi_size, ret_abi_align);

        var ptr_ty_payload: Type.Payload.ElemType = .{
            .base = .{ .tag = .single_mut_pointer },
            .data = ret_ty,
        };
        const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
        try self.register_manager.getReg(.r0, null);
        try self.genSetReg(ptr_ty, .r0, .{ .ptr_stack_offset = stack_offset });

        info.return_value = .{ .stack_offset = stack_offset };
    }

    // Make space for the arguments passed via the stack
    self.max_end_stack += info.stack_byte_count;

    for (info.args) |mc_arg, arg_i| {
        const arg = args[arg_i];
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(args[arg_i]);

        switch (mc_arg) {
            .none => continue,
            .register => |reg| {
                try self.register_manager.getReg(reg, null);
                try self.genSetReg(arg_ty, reg, arg_mcv);
            },
            .stack_offset => unreachable,
            .stack_argument_offset => |offset| try self.genSetStackArgument(
                arg_ty,
                info.stack_byte_count - offset,
                arg_mcv,
            ),
            else => unreachable,
        }
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    switch (self.bin_file.tag) {
        .elf, .coff => {
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

                    try self.genSetReg(Type.initTag(.usize), .lr, .{ .memory = got_addr });
                } else if (func_value.castTag(.extern_fn)) |_| {
                    return self.fail("TODO implement calling extern functions", .{});
                } else {
                    return self.fail("TODO implement calling bitcasted functions", .{});
                }
            } else {
                assert(ty.zigTypeTag() == .Pointer);
                const mcv = try self.resolveInst(callee);

                try self.genSetReg(Type.initTag(.usize), .lr, mcv);
            }

            // TODO: add Instruction.supportedOn
            // function for ARM
            if (Target.arm.featureSetHas(self.target.cpu.features, .has_v5t)) {
                _ = try self.addInst(.{
                    .tag = .blx,
                    .data = .{ .reg = .lr },
                });
            } else {
                return self.fail("TODO fix blx emulation for ARM <v5", .{});
                // _ = try self.addInst(.{
                //     .tag = .mov,
                //     .data = .{ .rr_op = .{
                //         .rd = .lr,
                //         .rn = .r0,
                //         .op = Instruction.Operand.reg(.pc, Instruction.Operand.Shift.none),
                //     } },
                // });
                // _ = try self.addInst(.{
                //     .tag = .bx,
                //     .data = .{ .reg = .lr },
                // });
            }
        },
        .macho => unreachable, // unsupported architecture for MachO
        .plan9 => return self.fail("TODO implement call on plan9 for {}", .{self.target.cpu.arch}),
        else => unreachable,
    }

    const result: MCValue = result: {
        switch (info.return_value) {
            .register => |reg| {
                if (RegisterManager.indexOfRegIntoTracked(reg) == null) {
                    // Save function return value into a tracked register
                    log.debug("airCall: copying {} as it is not tracked", .{reg});
                    const new_reg = try self.copyToTmpRegister(fn_ty.fnReturnType(), info.return_value);
                    break :result MCValue{ .register = new_reg };
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

fn airRet(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ret_ty = self.fn_type.fnReturnType();

    switch (self.ret_mcv) {
        .none => {},
        .immediate => {
            assert(ret_ty.isError());
        },
        .register => |reg| {
            // Return result by value
            try self.genSetReg(ret_ty, reg, operand);
        },
        .stack_offset => {
            // Return result by reference
            //
            // self.ret_mcv is an address to where this function
            // should store its result into
            var ptr_ty_payload: Type.Payload.ElemType = .{
                .base = .{ .tag = .single_mut_pointer },
                .data = ret_ty,
            };
            const ptr_ty = Type.initPayload(&ptr_ty_payload.base);
            try self.store(self.ret_mcv, operand, ptr_ty, ret_ty);
        },
        else => unreachable, // invalid return result
    }

    // Just add space for an instruction, patch this later
    try self.exitlude_jump_relocs.append(self.gpa, try self.addNop());

    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ptr = try self.resolveInst(un_op);
    const ptr_ty = self.air.typeOf(un_op);
    const ret_ty = self.fn_type.fnReturnType();

    switch (self.ret_mcv) {
        .none => {},
        .register => {
            // Return result by value
            try self.load(self.ret_mcv, ptr, ptr_ty);
        },
        .stack_offset => {
            // Return result by reference
            //
            // self.ret_mcv is an address to where this function
            // should store its result into
            //
            // If the operand is a ret_ptr instruction, we are done
            // here. Else we need to load the result from the location
            // pointed to by the operand and store it to the result
            // location.
            const op_inst = Air.refToIndex(un_op).?;
            if (self.air.instructions.items(.tag)[op_inst] != .ret_ptr) {
                const abi_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                const abi_align = ret_ty.abiAlignment(self.target.*);

                // This is essentially allocMem without the
                // instruction tracking
                if (abi_align > self.stack_align)
                    self.stack_align = abi_align;
                // TODO find a free slot instead of always appending
                const offset = mem.alignForwardGeneric(u32, self.next_stack_offset, abi_align) + abi_size;
                self.next_stack_offset = offset;
                self.max_end_stack = @maximum(self.max_end_stack, self.next_stack_offset);

                const tmp_mcv = MCValue{ .stack_offset = offset };
                try self.load(tmp_mcv, ptr, ptr_ty);
                try self.store(self.ret_mcv, tmp_mcv, ptr_ty, ret_ty);
            }
        },
        else => unreachable, // invalid return result
    }

    // Just add space for an instruction, patch this later
    try self.exitlude_jump_relocs.append(self.gpa, try self.addNop());

    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const lhs_ty = self.air.typeOf(bin_op.lhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        const operands: BinOpOperands = .{ .inst = .{
            .inst = inst,
            .lhs = bin_op.lhs,
            .rhs = bin_op.rhs,
        } };
        break :blk try self.cmp(operands, lhs_ty, op);
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

const BinOpOperands = union(enum) {
    inst: struct {
        inst: Air.Inst.Index,
        lhs: Air.Inst.Ref,
        rhs: Air.Inst.Ref,
    },
    mcv: struct {
        lhs: MCValue,
        rhs: MCValue,
    },
};

fn cmp(
    self: *Self,
    operands: BinOpOperands,
    lhs_ty: Type,
    op: math.CompareOperator,
) !MCValue {
    var int_buffer: Type.Payload.Bits = undefined;
    const int_ty = switch (lhs_ty.zigTypeTag()) {
        .Optional => blk: {
            var opt_buffer: Type.Payload.ElemType = undefined;
            const payload_ty = lhs_ty.optionalChild(&opt_buffer);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
                break :blk Type.initTag(.u1);
            } else if (lhs_ty.isPtrLikeOptional()) {
                break :blk Type.usize;
            } else {
                return self.fail("TODO ARM cmp non-pointer optionals", .{});
            }
        },
        .Float => return self.fail("TODO ARM cmp floats", .{}),
        .Enum => lhs_ty.intTagType(&int_buffer),
        .Int => lhs_ty,
        .Bool => Type.initTag(.u1),
        .Pointer => Type.usize,
        .ErrorSet => Type.initTag(.u16),
        else => unreachable,
    };

    const int_info = int_ty.intInfo(self.target.*);
    if (int_info.bits <= 32) {
        try self.spillCompareFlagsIfOccupied();

        switch (operands) {
            .inst => |inst_op| {
                const metadata: BinOpMetadata = .{
                    .inst = inst_op.inst,
                    .lhs = inst_op.lhs,
                    .rhs = inst_op.rhs,
                };
                const lhs = try self.resolveInst(inst_op.lhs);
                const rhs = try self.resolveInst(inst_op.rhs);

                self.cpsr_flags_inst = inst_op.inst;
                _ = try self.binOp(.cmp_eq, lhs, rhs, int_ty, int_ty, metadata);
            },
            .mcv => |mcv_op| {
                _ = try self.binOp(.cmp_eq, mcv_op.lhs, mcv_op.rhs, int_ty, int_ty, null);
            },
        }

        return switch (int_info.signedness) {
            .signed => MCValue{ .cpsr_flags = Condition.fromCompareOperatorSigned(op) },
            .unsigned => MCValue{ .cpsr_flags = Condition.fromCompareOperatorUnsigned(op) },
        };
    } else {
        return self.fail("TODO ARM cmp for ints > 32 bits", .{});
    }
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
        .cond = undefined,
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

/// Given a boolean condition, emit a jump that is taken when that
/// condition is false.
fn condBr(self: *Self, condition: MCValue) !Mir.Inst.Index {
    const condition_code: Condition = switch (condition) {
        .cpsr_flags => |cond| cond.negate(),
        else => blk: {
            const reg = switch (condition) {
                .register => |r| r,
                else => try self.copyToTmpRegister(Type.bool, condition),
            };

            try self.spillCompareFlagsIfOccupied();

            // cmp reg, 1
            // bne ...
            _ = try self.addInst(.{
                .tag = .cmp,
                .cond = .al,
                .data = .{ .rr_op = .{
                    .rd = .r0,
                    .rn = reg,
                    .op = Instruction.Operand.imm(1, 0),
                } },
            });

            break :blk .ne;
        },
    };

    return try self.addInst(.{
        .tag = .b,
        .cond = condition_code,
        .data = .{ .inst = undefined }, // populated later through performReloc
    });
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const cond_inst = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc: Mir.Inst.Index = try self.condBr(cond_inst);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        const op_int = @enumToInt(pl_op.operand);
        if (op_int >= Air.Inst.Ref.typed_value_map.len) {
            const op_index = @intCast(Air.Inst.Index, op_int - Air.Inst.Ref.typed_value_map.len);
            self.processDeath(op_index);
        }
    }

    // Capture the state of register and stack allocation state so that we can revert to it.
    const parent_next_stack_offset = self.next_stack_offset;
    const parent_free_registers = self.register_manager.free_registers;
    var parent_stack = try self.stack.clone(self.gpa);
    defer parent_stack.deinit(self.gpa);
    const parent_registers = self.register_manager.registers;
    const parent_cpsr_flags_inst = self.cpsr_flags_inst;

    try self.branch_stack.append(.{});
    errdefer {
        _ = self.branch_stack.pop();
    }

    try self.ensureProcessDeathCapacity(liveness_condbr.then_deaths.len);
    for (liveness_condbr.then_deaths) |operand| {
        self.processDeath(operand);
    }
    try self.genBody(then_body);

    // Revert to the previous register and stack allocation state.

    var saved_then_branch = self.branch_stack.pop();
    defer saved_then_branch.deinit(self.gpa);

    self.register_manager.registers = parent_registers;
    self.cpsr_flags_inst = parent_cpsr_flags_inst;

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
    for (else_keys) |else_key, else_idx| {
        const else_value = else_values[else_idx];
        const canon_mcv = if (saved_then_branch.inst_table.fetchSwapRemove(else_key)) |then_entry| blk: {
            // The instruction's MCValue is overridden in both branches.
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
        try self.setRegOrMem(self.air.typeOfIndex(else_key), canon_mcv, else_value);
        // TODO track the new register / stack allocation
    }
    try parent_branch.inst_table.ensureUnusedCapacity(self.gpa, saved_then_branch.inst_table.count());
    const then_slice = saved_then_branch.inst_table.entries.slice();
    const then_keys = then_slice.items(.key);
    const then_values = then_slice.items(.value);
    for (then_keys) |then_key, then_idx| {
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
        try self.setRegOrMem(self.air.typeOfIndex(then_key), parent_mcv, then_value);
        // TODO track the new register / stack allocation
    }

    {
        var item = self.branch_stack.pop();
        item.deinit(self.gpa);
    }

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn isNull(self: *Self, ty: Type, operand: MCValue) !MCValue {
    if (ty.isPtrLikeOptional()) {
        assert(ty.abiSize(self.target.*) == 4);

        const reg_mcv: MCValue = switch (operand) {
            .register => operand,
            else => .{ .register = try self.copyToTmpRegister(ty, operand) },
        };

        _ = try self.addInst(.{
            .tag = .cmp,
            .data = .{ .rr_op = .{
                .rd = undefined,
                .rn = reg_mcv.register,
                .op = Instruction.Operand.fromU32(0).?,
            } },
        });

        return MCValue{ .cpsr_flags = .eq };
    } else {
        return self.fail("TODO implement non-pointer optionals", .{});
    }
}

fn isNonNull(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const is_null_result = try self.isNull(ty, operand);
    assert(is_null_result.cpsr_flags == .eq);

    return MCValue{ .cpsr_flags = .ne };
}

fn isErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const error_type = ty.errorUnionSet();
    const error_int_type = Type.initTag(.u16);

    if (error_type.errorSetIsEmpty()) {
        return MCValue{ .immediate = 0 }; // always false
    }

    const error_mcv = try self.errUnionErr(operand, ty);
    _ = try self.binOp(.cmp_eq, error_mcv, .{ .immediate = 0 }, error_int_type, error_int_type, null);
    return MCValue{ .cpsr_flags = .hi };
}

fn isNonErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const is_err_result = try self.isErr(ty, operand);
    switch (is_err_result) {
        .cpsr_flags => |cond| {
            assert(cond == .hi);
            return MCValue{ .cpsr_flags = cond.negate() };
        },
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = 1 };
        },
        else => unreachable,
    }
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    try self.spillCompareFlagsIfOccupied();
    self.cpsr_flags_inst = inst;

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNull(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.air.typeOf(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, ptr_ty);
        break :result try self.isNull(ptr_ty.elemType(), operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNonNull(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.air.typeOf(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, ptr_ty);
        break :result try self.isNonNull(ptr_ty.elemType(), operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isErr(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.air.typeOf(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, ptr_ty);
        break :result try self.isErr(ptr_ty.elemType(), operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNonErr(ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.air.typeOf(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, ptr_ty);
        break :result try self.isNonErr(ptr_ty.elemType(), operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[loop.end..][0..loop.data.body_len];
    const start_index = @intCast(Mir.Inst.Index, self.mir_instructions.len);
    try self.genBody(body);
    try self.jump(start_index);
    return self.finishAirBookkeeping();
}

/// Send control flow to `inst`.
fn jump(self: *Self, inst: Mir.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = .b,
        .data = .{ .inst = inst },
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

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    try self.genBody(body);

    // relocations for `br` instructions
    const relocs = &self.blocks.getPtr(inst).?.relocs;
    if (relocs.items.len > 0 and relocs.items[relocs.items.len - 1] == self.mir_instructions.len - 1) {
        // If the last Mir instruction is the last relocation (which
        // would just jump one instruction further), it can be safely
        // removed
        self.mir_instructions.orderedRemove(relocs.pop());
    }
    for (relocs.items) |reloc| {
        try self.performReloc(reloc);
    }

    const result = self.blocks.getPtr(inst).?.mcv;
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition_ty = self.air.typeOf(pl_op.operand);
    const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
    const liveness = try self.liveness.getSwitchBr(
        self.gpa,
        inst,
        switch_br.data.cases_len + 1,
    );
    defer self.gpa.free(liveness.deaths);

    // If the condition dies here in this switch instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        const op_int = @enumToInt(pl_op.operand);
        if (op_int >= Air.Inst.Ref.typed_value_map.len) {
            const op_index = @intCast(Air.Inst.Index, op_int - Air.Inst.Ref.typed_value_map.len);
            self.processDeath(op_index);
        }
    }

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
        assert(items.len > 0);
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;

        var relocs = try self.gpa.alloc(u32, items.len);
        defer self.gpa.free(relocs);

        if (items.len == 1) {
            const condition = try self.resolveInst(pl_op.operand);
            const item = try self.resolveInst(items[0]);

            const operands: BinOpOperands = .{ .mcv = .{
                .lhs = condition,
                .rhs = item,
            } };
            const cmp_result = try self.cmp(operands, condition_ty, .eq);
            relocs[0] = try self.condBr(cmp_result);
        } else {
            return self.fail("TODO switch with multiple items", .{});
        }

        // Capture the state of register and stack allocation state so that we can revert to it.
        const parent_next_stack_offset = self.next_stack_offset;
        const parent_free_registers = self.register_manager.free_registers;
        const parent_cpsr_flags_inst = self.cpsr_flags_inst;
        var parent_stack = try self.stack.clone(self.gpa);
        defer parent_stack.deinit(self.gpa);
        const parent_registers = self.register_manager.registers;

        try self.branch_stack.append(.{});
        errdefer {
            _ = self.branch_stack.pop();
        }

        try self.ensureProcessDeathCapacity(liveness.deaths[case_i].len);
        for (liveness.deaths[case_i]) |operand| {
            self.processDeath(operand);
        }
        try self.genBody(case_body);

        // Revert to the previous register and stack allocation state.
        var saved_case_branch = self.branch_stack.pop();
        defer saved_case_branch.deinit(self.gpa);

        self.register_manager.registers = parent_registers;
        self.cpsr_flags_inst = parent_cpsr_flags_inst;
        self.stack.deinit(self.gpa);
        self.stack = parent_stack;
        parent_stack = .{};

        self.next_stack_offset = parent_next_stack_offset;
        self.register_manager.free_registers = parent_free_registers;

        for (relocs) |reloc| {
            try self.performReloc(reloc);
        }
    }

    if (switch_br.data.else_body_len > 0) {
        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];

        // Capture the state of register and stack allocation state so that we can revert to it.
        const parent_next_stack_offset = self.next_stack_offset;
        const parent_free_registers = self.register_manager.free_registers;
        const parent_cpsr_flags_inst = self.cpsr_flags_inst;
        var parent_stack = try self.stack.clone(self.gpa);
        defer parent_stack.deinit(self.gpa);
        const parent_registers = self.register_manager.registers;

        try self.branch_stack.append(.{});
        errdefer {
            _ = self.branch_stack.pop();
        }

        const else_deaths = liveness.deaths.len - 1;
        try self.ensureProcessDeathCapacity(liveness.deaths[else_deaths].len);
        for (liveness.deaths[else_deaths]) |operand| {
            self.processDeath(operand);
        }
        try self.genBody(else_body);

        // Revert to the previous register and stack allocation state.
        var saved_case_branch = self.branch_stack.pop();
        defer saved_case_branch.deinit(self.gpa);

        self.register_manager.registers = parent_registers;
        self.cpsr_flags_inst = parent_cpsr_flags_inst;
        self.stack.deinit(self.gpa);
        self.stack = parent_stack;
        parent_stack = .{};

        self.next_stack_offset = parent_next_stack_offset;
        self.register_manager.free_registers = parent_free_registers;

        // TODO consolidate returned MCValues between prongs and else branch like we do
        // in airCondBr.
    }

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn performReloc(self: *Self, inst: Mir.Inst.Index) !void {
    const tag = self.mir_instructions.items(.tag)[inst];
    switch (tag) {
        .b => self.mir_instructions.items(.data)[inst].inst = @intCast(Air.Inst.Index, self.mir_instructions.len),
        else => unreachable,
    }
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const branch = self.air.instructions.items(.data)[inst].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const block_data = self.blocks.getPtr(block).?;

    if (self.air.typeOf(operand).hasRuntimeBits()) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = switch (operand_mcv) {
                .none, .dead, .unreach => unreachable,
                .register, .stack_offset, .memory => operand_mcv,
                .immediate, .stack_argument_offset, .cpsr_flags => blk: {
                    const new_mcv = try self.allocRegOrMem(block, true);
                    try self.setRegOrMem(self.air.typeOfIndex(block), new_mcv, operand_mcv);
                    break :blk new_mcv;
                },
                else => return self.fail("TODO implement block_data.mcv = operand_mcv for {}", .{operand_mcv}),
            };
        } else {
            try self.setRegOrMem(self.air.typeOfIndex(block), block_mcv, operand_mcv);
        }
    }
    return self.brVoid(block);
}

fn brVoid(self: *Self, block: Air.Inst.Index) !void {
    const block_data = self.blocks.getPtr(block).?;

    // Emit a jump with a relocation. It will be patched up after the block ends.
    try block_data.relocs.append(self.gpa, try self.addInst(.{
        .tag = .b,
        .data = .{ .inst = undefined }, // populated later through performReloc
    }));
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

        if (mem.eql(u8, asm_source, "svc #0")) {
            _ = try self.addInst(.{
                .tag = .svc,
                .data = .{ .imm24 = 0 },
            });
        } else {
            return self.fail("TODO implement support for more arm assembly instructions", .{});
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
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (ty.abiSize(self.target.*)) {
                1 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .cpsr_flags,
        .immediate,
        .ptr_stack_offset,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .register => |reg| {
            switch (abi_size) {
                1, 4 => {
                    const offset = if (math.cast(u12, stack_offset)) |imm| blk: {
                        break :blk Instruction.Offset.imm(imm);
                    } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = stack_offset }), .none);

                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .strb,
                        4 => .str,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .data = .{ .rr_offset = .{
                            .rt = reg,
                            .rn = .fp,
                            .offset = .{
                                .offset = offset,
                                .positive = false,
                            },
                        } },
                    });
                },
                2 => {
                    const offset = if (stack_offset <= math.maxInt(u8)) blk: {
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, stack_offset));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = stack_offset }));

                    _ = try self.addInst(.{
                        .tag = .strh,
                        .data = .{ .rr_extra_offset = .{
                            .rt = reg,
                            .rn = .fp,
                            .offset = .{
                                .offset = offset,
                                .positive = false,
                            },
                        } },
                    });
                },
                else => return self.fail("TODO implement storing other types abi_size={}", .{abi_size}),
            }
        },
        .register_c_flag,
        .register_v_flag,
        => |reg| {
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |locked_reg| self.register_manager.unlockReg(locked_reg);

            const wrapped_ty = ty.structFieldType(0);
            try self.genSetStack(wrapped_ty, stack_offset, .{ .register = reg });

            const overflow_bit_ty = ty.structFieldType(1);
            const overflow_bit_offset = @intCast(u32, ty.structFieldOffset(1, self.target.*));
            const cond_reg = try self.register_manager.allocReg(null, gp);

            // C flag: movcs reg, #1
            // V flag: movvs reg, #1
            _ = try self.addInst(.{
                .tag = .mov,
                .cond = switch (mcv) {
                    .register_c_flag => .cs,
                    .register_v_flag => .vs,
                    else => unreachable,
                },
                .data = .{ .rr_op = .{
                    .rd = cond_reg,
                    .rn = .r0,
                    .op = Instruction.Operand.fromU32(1).?,
                } },
            });

            try self.genSetStack(overflow_bit_ty, stack_offset - overflow_bit_offset, .{
                .register = cond_reg,
            });
        },
        .memory,
        .stack_argument_offset,
        .stack_offset,
        => {
            switch (mcv) {
                .stack_offset => |off| {
                    if (stack_offset == off)
                        return; // Copy stack variable to itself; nothing to do.
                },
                else => {},
            }

            if (abi_size <= 4) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            } else {
                var ptr_ty_payload: Type.Payload.ElemType = .{
                    .base = .{ .tag = .single_mut_pointer },
                    .data = ty,
                };
                const ptr_ty = Type.initPayload(&ptr_ty_payload.base);

                // TODO call extern memcpy
                const regs = try self.register_manager.allocRegs(5, .{ null, null, null, null, null }, gp);
                const src_reg = regs[0];
                const dst_reg = regs[1];
                const len_reg = regs[2];
                const count_reg = regs[3];
                const tmp_reg = regs[4];

                switch (mcv) {
                    .stack_offset => |off| {
                        // sub src_reg, fp, #off
                        try self.genSetReg(ptr_ty, src_reg, .{ .ptr_stack_offset = off });
                    },
                    .memory => |addr| try self.genSetReg(ptr_ty, src_reg, .{ .immediate = @intCast(u32, addr) }),
                    .stack_argument_offset => |off| {
                        _ = try self.addInst(.{
                            .tag = .ldr_ptr_stack_argument,
                            .data = .{ .r_stack_offset = .{
                                .rt = src_reg,
                                .stack_offset = off,
                            } },
                        });
                    },
                    else => unreachable,
                }

                // sub dst_reg, fp, #stack_offset
                try self.genSetReg(ptr_ty, dst_reg, .{ .ptr_stack_offset = stack_offset });

                // mov len, #abi_size
                try self.genSetReg(Type.usize, len_reg, .{ .immediate = abi_size });

                // memcpy(src, dst, len)
                try self.genInlineMemcpy(src_reg, dst_reg, len_reg, count_reg, tmp_reg);
            }
        },
    }
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaa });
        },
        .ptr_stack_offset => |off| {
            // TODO: maybe addressing from sp instead of fp
            const op = Instruction.Operand.fromU32(off) orelse
                return self.fail("TODO larger stack offsets", .{});

            _ = try self.addInst(.{
                .tag = .sub,
                .data = .{ .rr_op = .{
                    .rd = reg,
                    .rn = .fp,
                    .op = op,
                } },
            });
        },
        .cpsr_flags => |condition| {
            const zero = Instruction.Operand.imm(0, 0);
            const one = Instruction.Operand.imm(1, 0);

            // mov reg, 0
            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{ .rr_op = .{
                    .rd = reg,
                    .rn = .r0,
                    .op = zero,
                } },
            });

            // moveq reg, 1
            _ = try self.addInst(.{
                .tag = .mov,
                .cond = condition,
                .data = .{ .rr_op = .{
                    .rd = reg,
                    .rn = .r0,
                    .op = one,
                } },
            });
        },
        .immediate => |x| {
            if (Instruction.Operand.fromU32(x)) |op| {
                _ = try self.addInst(.{
                    .tag = .mov,
                    .data = .{ .rr_op = .{
                        .rd = reg,
                        .rn = .r0,
                        .op = op,
                    } },
                });
            } else if (Instruction.Operand.fromU32(~x)) |op| {
                _ = try self.addInst(.{
                    .tag = .mvn,
                    .data = .{ .rr_op = .{
                        .rd = reg,
                        .rn = .r0,
                        .op = op,
                    } },
                });
            } else if (x <= math.maxInt(u16)) {
                if (Target.arm.featureSetHas(self.target.cpu.features, .has_v7)) {
                    _ = try self.addInst(.{
                        .tag = .movw,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @intCast(u16, x),
                        } },
                    });
                } else {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = .r0,
                            .op = Instruction.Operand.imm(@truncate(u8, x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 8), 12),
                        } },
                    });
                }
            } else {
                // TODO write constant to code and load
                // relative to pc
                if (Target.arm.featureSetHas(self.target.cpu.features, .has_v7)) {
                    // immediate: 0xaaaabbbb
                    // movw reg, #0xbbbb
                    // movt reg, #0xaaaa
                    _ = try self.addInst(.{
                        .tag = .movw,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @truncate(u16, x),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .movt,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @truncate(u16, x >> 16),
                        } },
                    });
                } else {
                    // immediate: 0xaabbccdd
                    // mov reg, #0xaa
                    // orr reg, reg, #0xbb, 24
                    // orr reg, reg, #0xcc, 16
                    // orr reg, reg, #0xdd, 8
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = .r0,
                            .op = Instruction.Operand.imm(@truncate(u8, x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 8), 12),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 16), 8),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 24), 4),
                        } },
                    });
                }
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // mov reg, src_reg
            _ = try self.addInst(.{
                .tag = .mov,
                .data = .{ .rr_op = .{
                    .rd = reg,
                    .rn = .r0,
                    .op = Instruction.Operand.reg(src_reg, Instruction.Operand.Shift.none),
                } },
            });
        },
        .register_c_flag => unreachable, // doesn't fit into a register
        .register_v_flag => unreachable, // doesn't fit into a register
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = @intCast(u32, addr) });
            try self.genLdrRegister(reg, reg, ty);
        },
        .stack_offset => |off| {
            // TODO: maybe addressing from sp instead of fp
            const abi_size = @intCast(u32, ty.abiSize(self.target.*));

            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsb else .ldrb,
                2 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsh else .ldrh,
                3, 4 => .ldr,
                else => unreachable,
            };

            const extra_offset = switch (abi_size) {
                1 => ty.isSignedInt(),
                2 => true,
                3, 4 => false,
                else => unreachable,
            };

            if (extra_offset) {
                const offset = if (off <= math.maxInt(u8)) blk: {
                    break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, off));
                } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.usize), MCValue{ .immediate = off }));

                _ = try self.addInst(.{
                    .tag = tag,
                    .data = .{ .rr_extra_offset = .{
                        .rt = reg,
                        .rn = .fp,
                        .offset = .{
                            .offset = offset,
                            .positive = false,
                        },
                    } },
                });
            } else {
                const offset = if (off <= math.maxInt(u12)) blk: {
                    break :blk Instruction.Offset.imm(@intCast(u12, off));
                } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.usize), MCValue{ .immediate = off }), .none);

                _ = try self.addInst(.{
                    .tag = tag,
                    .data = .{ .rr_offset = .{
                        .rt = reg,
                        .rn = .fp,
                        .offset = .{
                            .offset = offset,
                            .positive = false,
                        },
                    } },
                });
            }
        },
        .stack_argument_offset => |off| {
            const abi_size = ty.abiSize(self.target.*);

            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsb_stack_argument else .ldrb_stack_argument,
                2 => if (ty.isSignedInt()) Mir.Inst.Tag.ldrsh_stack_argument else .ldrh_stack_argument,
                3, 4 => .ldr_stack_argument,
                else => unreachable,
            };

            _ = try self.addInst(.{
                .tag = tag,
                .data = .{ .r_stack_offset = .{
                    .rt = reg,
                    .stack_offset = off,
                } },
            });
        },
    }
}

fn genSetStackArgument(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .none, .unreach => return,
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (abi_size) {
                1 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .register => |reg| {
            switch (abi_size) {
                1, 4 => {
                    const offset = if (math.cast(u12, stack_offset)) |imm| blk: {
                        break :blk Instruction.Offset.imm(imm);
                    } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = stack_offset }), .none);

                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .strb,
                        4 => .str,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .data = .{ .rr_offset = .{
                            .rt = reg,
                            .rn = .sp,
                            .offset = .{ .offset = offset },
                        } },
                    });
                },
                2 => {
                    const offset = if (stack_offset <= math.maxInt(u8)) blk: {
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, stack_offset));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = stack_offset }));

                    _ = try self.addInst(.{
                        .tag = .strh,
                        .data = .{ .rr_extra_offset = .{
                            .rt = reg,
                            .rn = .sp,
                            .offset = .{ .offset = offset },
                        } },
                    });
                },
                else => return self.fail("TODO implement storing other types abi_size={}", .{abi_size}),
            }
        },
        .register_c_flag,
        .register_v_flag,
        => {
            return self.fail("TODO implement genSetStack {}", .{mcv});
        },
        .stack_offset,
        .memory,
        .stack_argument_offset,
        => {
            if (abi_size <= 4) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArgument(ty, stack_offset, MCValue{ .register = reg });
            } else {
                var ptr_ty_payload: Type.Payload.ElemType = .{
                    .base = .{ .tag = .single_mut_pointer },
                    .data = ty,
                };
                const ptr_ty = Type.initPayload(&ptr_ty_payload.base);

                // TODO call extern memcpy
                const regs = try self.register_manager.allocRegs(5, .{ null, null, null, null, null }, gp);
                const src_reg = regs[0];
                const dst_reg = regs[1];
                const len_reg = regs[2];
                const count_reg = regs[3];
                const tmp_reg = regs[4];

                switch (mcv) {
                    .stack_offset => |off| {
                        // sub src_reg, fp, #off
                        try self.genSetReg(ptr_ty, src_reg, .{ .ptr_stack_offset = off });
                    },
                    .memory => |addr| try self.genSetReg(ptr_ty, src_reg, .{ .immediate = @intCast(u32, addr) }),
                    .stack_argument_offset => |off| {
                        _ = try self.addInst(.{
                            .tag = .ldr_ptr_stack_argument,
                            .data = .{ .r_stack_offset = .{
                                .rt = src_reg,
                                .stack_offset = off,
                            } },
                        });
                    },
                    else => unreachable,
                }

                // add dst_reg, sp, #stack_offset
                const dst_offset_op: Instruction.Operand = if (Instruction.Operand.fromU32(stack_offset)) |x| x else {
                    return self.fail("TODO load: set reg to stack offset with all possible offsets", .{});
                };
                _ = try self.addInst(.{
                    .tag = .add,
                    .data = .{ .rr_op = .{
                        .rd = dst_reg,
                        .rn = .sp,
                        .op = dst_offset_op,
                    } },
                });

                // mov len, #abi_size
                try self.genSetReg(Type.usize, len_reg, .{ .immediate = abi_size });

                // memcpy(src, dst, len)
                try self.genInlineMemcpy(src_reg, dst_reg, len_reg, count_reg, tmp_reg);
            }
        },
        .cpsr_flags,
        .immediate,
        .ptr_stack_offset,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStackArgument(ty, stack_offset, MCValue{ .register = reg });
        },
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = self.air.typeOf(ty_op.operand);
        const ptr = try self.resolveInst(ty_op.operand);
        const array_ty = ptr_ty.childType();
        const array_len = @intCast(u32, array_ty.arrayLen());

        const stack_offset = try self.allocMem(inst, 8, 8);
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(Type.initTag(.usize), stack_offset - 4, .{ .immediate = array_len });
        break :result MCValue{ .stack_offset = stack_offset };
    };
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
        return self.fail("TODO implement airTagName for arm", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for arm", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for arm", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSelect for arm", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airShuffle for arm", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[inst].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airReduce for arm", .{});
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const vector_ty = self.air.typeOfIndex(inst);
    const len = vector_ty.vectorLen();
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airAggregateInit for arm", .{});
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

    return self.fail("TODO implement airUnionInit for arm", .{});
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        return self.fail("TODO implement airMulAdd for arm", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    const result: MCValue = result: {
        const error_union_ty = self.air.typeOf(pl_op.operand);
        const error_union = try self.resolveInst(pl_op.operand);
        const is_err_result = try self.isErr(error_union_ty, error_union);
        const reloc = try self.condBr(is_err_result);

        try self.genBody(body);

        try self.performReloc(reloc);
        break :result try self.errUnionPayload(error_union, error_union_ty);
    };
    return self.finishAir(inst, result, .{ pl_op.operand, .none, .none });
}

fn airTryPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    _ = body;
    return self.fail("TODO implement airTryPtr for arm", .{});
    // return self.finishAir(inst, result, .{ extra.data.ptr, .none, .none });
}

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    // First section of indexes correspond to a set number of constant values.
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        const tv = Air.Inst.Ref.typed_value_map[ref_int];
        if (!tv.ty.hasRuntimeBitsIgnoreComptime() and !tv.ty.isError()) {
            return MCValue{ .none = {} };
        }
        return self.genTypedValue(tv);
    }

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.air.typeOf(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime() and !inst_ty.isError())
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
        unreachable; // unsupported architecture for MachO
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

fn lowerUnnamedConst(self: *Self, tv: TypedValue) InnerError!MCValue {
    const local_sym_index = self.bin_file.lowerUnnamedConst(tv, self.mod_fn.owner_decl) catch |err| {
        return self.fail("lowering unnamed constant failed: {s}", .{@errorName(err)});
    };
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const vaddr = elf_file.local_symbols.items[local_sym_index].st_value;
        return MCValue{ .memory = vaddr };
    } else if (self.bin_file.cast(link.File.MachO)) |_| {
        unreachable;
    } else if (self.bin_file.cast(link.File.Coff)) |_| {
        return self.fail("TODO lower unnamed const in COFF", .{});
    } else if (self.bin_file.cast(link.File.Plan9)) |_| {
        return self.fail("TODO lower unnamed const in Plan9", .{});
    } else {
        return self.fail("TODO lower unnamed const", .{});
    }
}

fn genTypedValue(self: *Self, typed_value: TypedValue) InnerError!MCValue {
    log.debug("genTypedValue: ty = {}, val = {}", .{ typed_value.ty.fmtDebug(), typed_value.val.fmtDebug() });
    if (typed_value.val.isUndef())
        return MCValue{ .undef = {} };
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();

    if (typed_value.val.castTag(.decl_ref)) |payload| {
        return self.lowerDeclRef(typed_value, payload.data);
    }
    if (typed_value.val.castTag(.decl_ref_mut)) |payload| {
        return self.lowerDeclRef(typed_value, payload.data.decl_index);
    }
    const target = self.target.*;

    switch (typed_value.ty.zigTypeTag()) {
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {},
            else => {
                switch (typed_value.val.tag()) {
                    .int_u64 => {
                        return MCValue{ .immediate = @intCast(u32, typed_value.val.toUnsignedInt(target)) };
                    },
                    else => {},
                }
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits <= ptr_bits) {
                const unsigned = switch (info.signedness) {
                    .signed => blk: {
                        const signed = @intCast(i32, typed_value.val.toSignedInt());
                        break :blk @bitCast(u32, signed);
                    },
                    .unsigned => @intCast(u32, typed_value.val.toUnsignedInt(target)),
                };

                return MCValue{ .immediate = unsigned };
            } else {
                return self.lowerUnnamedConst(typed_value);
            }
        },
        .Bool => {
            return MCValue{ .immediate = @boolToInt(typed_value.val.toBool()) };
        },
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
            const is_pl = typed_value.val.errorUnionIsPayload();

            if (!payload_type.hasRuntimeBitsIgnoreComptime()) {
                // We use the error type directly as the type.
                const err_val = if (!is_pl) typed_value.val else Value.initTag(.zero);
                return self.genTypedValue(.{ .ty = error_type, .val = err_val });
            }
        },

        .ComptimeInt => unreachable, // semantic analysis prevents this
        .ComptimeFloat => unreachable, // semantic analysis prevents this
        .Type => unreachable,
        .EnumLiteral => unreachable,
        .Void => unreachable,
        .NoReturn => unreachable,
        .Undefined => unreachable,
        .Null => unreachable,
        .BoundFn => unreachable,
        .Opaque => unreachable,

        else => {},
    }

    return self.lowerUnnamedConst(typed_value);
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
        .C => {
            // ARM Procedure Call Standard, Chapter 6.5
            var ncrn: usize = 0; // Next Core Register Number
            var nsaa: u32 = 0; // Next stacked argument address

            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                // TODO handle cases where multiple registers are used
                if (ret_ty_size <= 4) {
                    result.return_value = .{ .register = c_abi_int_return_regs[0] };
                } else {
                    // The result is returned by reference, not by
                    // value. This means that r0 will contain the
                    // address of where this function should write the
                    // result into.
                    result.return_value = .{ .stack_offset = 0 };
                    ncrn = 1;
                }
            }

            for (param_types) |ty, i| {
                if (ty.abiAlignment(self.target.*) == 8)
                    ncrn = std.mem.alignForwardGeneric(usize, ncrn, 2);

                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                if (std.math.divCeil(u32, param_size, 4) catch unreachable <= 4 - ncrn) {
                    if (param_size <= 4) {
                        result.args[i] = .{ .register = c_abi_int_param_regs[ncrn] };
                        ncrn += 1;
                    } else {
                        return self.fail("TODO MCValues with multiple registers", .{});
                    }
                } else if (ncrn < 4 and nsaa == 0) {
                    return self.fail("TODO MCValues split between registers and stack", .{});
                } else {
                    ncrn = 4;
                    if (ty.abiAlignment(self.target.*) == 8)
                        nsaa = std.mem.alignForwardGeneric(u32, nsaa, 8);

                    nsaa += param_size;
                    result.args[i] = .{ .stack_argument_offset = nsaa };
                }
            }

            result.stack_byte_count = nsaa;
            result.stack_align = 8;
        },
        .Unspecified => {
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime() and !ret_ty.isError()) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                if (ret_ty_size == 0) {
                    assert(ret_ty.isError());
                    result.return_value = .{ .immediate = 0 };
                } else if (ret_ty_size <= 4) {
                    result.return_value = .{ .register = .r0 };
                } else {
                    // The result is returned by reference, not by
                    // value. This means that r0 will contain the
                    // address of where this function should write the
                    // result into.
                    result.return_value = .{ .stack_offset = 0 };
                }
            }

            var stack_offset: u32 = 0;

            for (param_types) |ty, i| {
                if (ty.abiSize(self.target.*) > 0) {
                    const param_size = @intCast(u32, ty.abiSize(self.target.*));

                    stack_offset = std.mem.alignForwardGeneric(u32, stack_offset, ty.abiAlignment(self.target.*)) + param_size;
                    result.args[i] = .{ .stack_argument_offset = stack_offset };
                } else {
                    result.args[i] = .{ .none = {} };
                }
            }

            result.stack_byte_count = stack_offset;
            result.stack_align = 8;
        },
        else => return self.fail("TODO implement function parameters for {} on arm", .{cc}),
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
