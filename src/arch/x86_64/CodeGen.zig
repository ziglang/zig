const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const codegen = @import("../../codegen.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;

const Air = @import("../../Air.zig");
const Allocator = mem.Allocator;
const Compilation = @import("../../Compilation.zig");
const DebugInfoOutput = codegen.DebugInfoOutput;
const DW = std.dwarf;
const ErrorMsg = Module.ErrorMsg;
const FnResult = codegen.FnResult;
const GenerateSymbolError = codegen.GenerateSymbolError;
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Target = std.Target;
const Type = @import("../../type.zig").Type;
const TypedValue = @import("../../TypedValue.zig");
const Value = @import("../../value.zig").Value;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;
const errUnionErrorOffset = codegen.errUnionErrorOffset;

const callee_preserved_regs = abi.callee_preserved_regs;
const caller_preserved_regs = abi.caller_preserved_regs;
const c_abi_int_param_regs = abi.c_abi_int_param_regs;
const c_abi_int_return_regs = abi.c_abi_int_return_regs;

const Condition = bits.Condition;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const Register = bits.Register;

const gp = abi.RegisterClass.gp;
const sse = abi.RegisterClass.sse;

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

eflags_inst: ?Air.Inst.Index = null,

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
exitlude_jump_relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .{},

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

/// For mir debug info, maps a mir index to a air index
mir_to_air_map: if (builtin.mode == .Debug) std.AutoHashMap(Mir.Inst.Index, Air.Inst.Index) else void,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

pub const MCValue = union(enum) {
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
    /// The value is in a GP register.
    register: Register,
    /// The value is a tuple { wrapped, overflow } where wrapped value is stored in the GP register.
    register_overflow: struct { reg: Register, eflags: Condition },
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value is in memory referenced indirectly via a GOT entry index.
    /// If the type is a pointer, it means the pointer is referenced indirectly via GOT.
    /// When lowered, linker will emit a relocation of type X86_64_RELOC_GOT.
    got_load: u32,
    /// The value is in memory referenced directly via symbol index.
    /// If the type is a pointer, it means the pointer is referenced directly via symbol index.
    /// When lowered, linker will emit a relocation of type X86_64_RELOC_SIGNED.
    direct_load: u32,
    /// The value is one of the stack variables.
    /// If the type is a pointer, it means the pointer address is in the stack at this offset.
    stack_offset: i32,
    /// The value is a pointer to one of the stack variables (payload is stack offset).
    ptr_stack_offset: i32,
    /// The value resides in the EFLAGS register.
    eflags: Condition,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory,
            .stack_offset,
            .ptr_stack_offset,
            .direct_load,
            .got_load,
            => true,
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
            .eflags,
            .ptr_stack_offset,
            .undef,
            .register_overflow,
            => false,

            .register,
            .stack_offset,
            => true,
        };
    }

    fn isRegister(mcv: MCValue) bool {
        return switch (mcv) {
            .register => true,
            else => false,
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
    /// TODO do we need size? should be determined by inst.ty.abiSize(self.target.*)
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
        .mir_to_air_map = if (builtin.mode == .Debug)
            std.AutoHashMap(Mir.Inst.Index, Air.Inst.Index).init(bin_file.allocator)
        else {},
    };
    defer function.stack.deinit(bin_file.allocator);
    defer function.blocks.deinit(bin_file.allocator);
    defer function.exitlude_jump_relocs.deinit(bin_file.allocator);
    defer function.mir_instructions.deinit(bin_file.allocator);
    defer function.mir_extra.deinit(bin_file.allocator);
    defer if (builtin.mode == .Debug) function.mir_to_air_map.deinit();

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
    emit.lowerMir() catch |err| switch (err) {
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

fn gen(self: *Self) InnerError!void {
    const cc = self.fn_type.fnCallingConvention();
    if (cc != .Naked) {
        _ = try self.addInst(.{
            .tag = .push,
            .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rbp }),
            .data = undefined, // unused for push reg,
        });
        _ = try self.addInst(.{
            .tag = .mov,
            .ops = Mir.Inst.Ops.encode(.{
                .reg1 = .rbp,
                .reg2 = .rsp,
            }),
            .data = undefined,
        });
        // We want to subtract the aligned stack frame size from rsp here, but we don't
        // yet know how big it will be, so we leave room for a 4-byte stack size.
        // TODO During semantic analysis, check if there are no function calls. If there
        // are none, here we can omit the part where we subtract and then add rsp.
        const backpatch_stack_sub = try self.addInst(.{
            .tag = .nop,
            .ops = undefined,
            .data = undefined,
        });

        if (self.ret_mcv == .stack_offset) {
            // The address where to store the return value for the caller is in `.rdi`
            // register which the callee is free to clobber. Therefore, we purposely
            // spill it to stack immediately.
            const stack_offset = mem.alignForwardGeneric(u32, self.next_stack_offset + 8, 8);
            self.next_stack_offset = stack_offset;
            self.max_end_stack = @maximum(self.max_end_stack, self.next_stack_offset);

            try self.genSetStack(Type.usize, @intCast(i32, stack_offset), MCValue{ .register = .rdi }, .{});
            self.ret_mcv = MCValue{ .stack_offset = @intCast(i32, stack_offset) };
            log.debug("gen: spilling .rdi to stack at offset {}", .{stack_offset});
        }

        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .ops = undefined,
            .data = undefined,
        });

        // Push callee-preserved regs that were used actually in use.
        const backpatch_push_callee_preserved_regs = try self.addInst(.{
            .tag = .nop,
            .ops = undefined,
            .data = undefined,
        });

        try self.genBody(self.air.getMainBody());

        // TODO can single exitlude jump reloc be elided? What if it is not at the end of the code?
        // Example:
        // pub fn main() void {
        //     maybeErr() catch return;
        //     unreachable;
        // }
        // Eliding the reloc will cause a miscompilation in this case.
        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.items(.data)[jmp_reloc].inst = @intCast(u32, self.mir_instructions.len);
        }

        // Create list of registers to save in the prologue.
        // TODO handle register classes
        var reg_list: Mir.RegisterList(Register, &callee_preserved_regs) = .{};
        inline for (callee_preserved_regs) |reg| {
            if (self.register_manager.isRegAllocated(reg)) {
                reg_list.push(reg);
            }
        }
        const saved_regs_stack_space: u32 = reg_list.count() * 8;

        // Pop saved callee-preserved regs.
        const backpatch_pop_callee_preserved_regs = try self.addInst(.{
            .tag = .nop,
            .ops = undefined,
            .data = undefined,
        });

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .ops = undefined,
            .data = undefined,
        });

        // Maybe add rsp, x if required. This is backpatched later.
        const backpatch_stack_add = try self.addInst(.{
            .tag = .nop,
            .ops = undefined,
            .data = undefined,
        });

        _ = try self.addInst(.{
            .tag = .pop,
            .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rbp }),
            .data = undefined,
        });

        _ = try self.addInst(.{
            .tag = .ret,
            .ops = Mir.Inst.Ops.encode(.{ .flags = 0b11 }),
            .data = undefined,
        });

        // Adjust the stack
        if (self.max_end_stack > math.maxInt(i32)) {
            return self.failSymbol("too much stack used in call parameters", .{});
        }

        const aligned_stack_end = @intCast(
            u32,
            mem.alignForward(self.max_end_stack + saved_regs_stack_space, self.stack_align),
        );
        if (aligned_stack_end > 0) {
            self.mir_instructions.set(backpatch_stack_sub, .{
                .tag = .sub,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rsp }),
                .data = .{ .imm = aligned_stack_end },
            });
            self.mir_instructions.set(backpatch_stack_add, .{
                .tag = .add,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rsp }),
                .data = .{ .imm = aligned_stack_end },
            });

            const save_reg_list = try self.addExtra(Mir.SaveRegisterList{
                .register_list = reg_list.asInt(),
                .stack_end = aligned_stack_end,
            });
            self.mir_instructions.set(backpatch_push_callee_preserved_regs, .{
                .tag = .push_regs,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rbp }),
                .data = .{ .payload = save_reg_list },
            });
            self.mir_instructions.set(backpatch_pop_callee_preserved_regs, .{
                .tag = .pop_regs,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rbp }),
                .data = .{ .payload = save_reg_list },
            });
        }
    } else {
        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .ops = undefined,
            .data = undefined,
        });

        try self.genBody(self.air.getMainBody());

        _ = try self.addInst(.{
            .tag = .dbg_epilogue_begin,
            .ops = undefined,
            .data = undefined,
        });
    }

    // Drop them off at the rbrace.
    const payload = try self.addExtra(Mir.DbgLineColumn{
        .line = self.end_di_line,
        .column = self.end_di_column,
    });
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .ops = undefined,
        .data = .{ .payload = payload },
    });
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        const old_air_bookkeeping = self.air_bookkeeping;
        try self.ensureProcessDeathCapacity(Liveness.bpi);
        if (builtin.mode == .Debug) {
            try self.mir_to_air_map.put(@intCast(u32, self.mir_instructions.len), inst);
        }

        switch (air_tags[inst]) {
            // zig fmt: off
            .add             => try self.airBinOp(inst, .add),
            .addwrap         => try self.airBinOp(inst, .addwrap),
            .sub             => try self.airBinOp(inst, .sub),
            .subwrap         => try self.airBinOp(inst, .subwrap),
            .bool_and        => try self.airBinOp(inst, .bool_and),
            .bool_or         => try self.airBinOp(inst, .bool_or),
            .bit_and         => try self.airBinOp(inst, .bit_and),
            .bit_or          => try self.airBinOp(inst, .bit_or),
            .xor             => try self.airBinOp(inst, .xor),

            .ptr_add         => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub         => try self.airPtrArithmetic(inst, .ptr_sub),

            .shr, .shr_exact => try self.airShlShrBinOp(inst),
            .shl, .shl_exact => try self.airShlShrBinOp(inst),

            .mul             => try self.airMulDivBinOp(inst),
            .mulwrap         => try self.airMulDivBinOp(inst),
            .rem             => try self.airMulDivBinOp(inst),
            .mod             => try self.airMulDivBinOp(inst),

            .add_sat         => try self.airAddSat(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul_sat         => try self.airMulSat(inst),
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

            .add_with_overflow => try self.airAddSubShlWithOverflow(inst),
            .sub_with_overflow => try self.airAddSubShlWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airAddSubShlWithOverflow(inst),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airMulDivBinOp(inst),

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
            self.register_manager.freeReg(reg.to64());
        },
        .register_overflow => |ro| {
            self.register_manager.freeReg(ro.reg.to64());
            self.eflags_inst = null;
        },
        .eflags => {
            self.eflags_inst = null;
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

        // In some cases (such as bitcast), an operand
        // may be the same MCValue as the result. If
        // that operand died and was a register, it
        // was freed by processDeath. We have to
        // "re-allocate" the register.
        switch (result) {
            .register => |reg| {
                if (self.register_manager.isRegFree(reg)) {
                    self.register_manager.getRegAssumeFree(reg, inst);
                }
            },
            .register_overflow => |ro| {
                if (self.register_manager.isRegFree(ro.reg)) {
                    self.register_manager.getRegAssumeFree(ro.reg, inst);
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

fn allocMem(self: *Self, inst: Air.Inst.Index, abi_size: u32, abi_align: u32) !u32 {
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;
    // TODO find a free slot instead of always appending
    const offset = mem.alignForwardGeneric(u32, self.next_stack_offset + abi_size, abi_align);
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
    const ptr_ty = self.air.typeOfIndex(inst);
    const elem_ty = ptr_ty.elemType();

    if (!elem_ty.hasRuntimeBitsIgnoreComptime()) {
        return self.allocMem(inst, @sizeOf(usize), @alignOf(usize));
    }

    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) orelse {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = ptr_ty.ptrAlignment(self.target.*);
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
        switch (elem_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO allocRegOrMem for Vector type", .{}),
            .Float => {
                if (intrinsicsAllowed(self.target.*, elem_ty)) {
                    const ptr_bytes: u64 = 32;
                    if (abi_size <= ptr_bytes) {
                        if (self.register_manager.tryAllocReg(inst, sse)) |reg| {
                            return MCValue{ .register = registerAlias(reg, abi_size) };
                        }
                    }
                }

                return self.fail("TODO allocRegOrMem for Float type without SSE/AVX support", .{});
            },
            else => {
                // Make sure the type can fit in a register before we try to allocate one.
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                if (abi_size <= ptr_bytes) {
                    if (self.register_manager.tryAllocReg(inst, gp)) |reg| {
                        return MCValue{ .register = registerAlias(reg, abi_size) };
                    }
                }
            },
        }
    }
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = @intCast(i32, stack_offset) };
}

const State = struct {
    next_stack_offset: u32,
    registers: abi.RegisterManager.TrackedRegisters,
    free_registers: abi.RegisterManager.RegisterBitSet,
    eflags_inst: ?Air.Inst.Index,
    stack: std.AutoHashMapUnmanaged(u32, StackAllocation),

    fn deinit(state: *State, gpa: Allocator) void {
        state.stack.deinit(gpa);
    }
};

fn captureState(self: *Self) !State {
    return State{
        .next_stack_offset = self.next_stack_offset,
        .registers = self.register_manager.registers,
        .free_registers = self.register_manager.free_registers,
        .eflags_inst = self.eflags_inst,
        .stack = try self.stack.clone(self.gpa),
    };
}

fn revertState(self: *Self, state: State) void {
    self.register_manager.registers = state.registers;
    self.eflags_inst = state.eflags_inst;

    self.stack.deinit(self.gpa);
    self.stack = state.stack;

    self.next_stack_offset = state.next_stack_offset;
    self.register_manager.free_registers = state.free_registers;
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(inst, false);
    log.debug("spilling {d} to stack mcv {any}", .{ inst, stack_mcv });
    const reg_mcv = self.getResolvedInstValue(inst);
    switch (reg_mcv) {
        .register => |other| {
            assert(reg.to64() == other.to64());
        },
        .register_overflow => |ro| {
            assert(reg.to64() == ro.reg.to64());
        },
        else => {},
    }
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv, .{});
}

pub fn spillEflagsIfOccupied(self: *Self) !void {
    if (self.eflags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save);
        const new_mcv = switch (mcv) {
            .register_overflow => try self.allocRegOrMem(inst_to_save, false),
            .eflags => try self.allocRegOrMem(inst_to_save, true),
            else => unreachable,
        };

        try self.setRegOrMem(self.air.typeOfIndex(inst_to_save), new_mcv, mcv);
        log.debug("spilling {d} to mcv {any}", .{ inst_to_save, new_mcv });

        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        try branch.inst_table.put(self.gpa, inst_to_save, new_mcv);

        self.eflags_inst = null;

        // TODO consolidate with register manager and spillInstruction
        // this call should really belong in the register manager!
        switch (mcv) {
            .register_overflow => |ro| self.register_manager.freeReg(ro.reg),
            else => {},
        }
    }
}

pub fn spillRegisters(self: *Self, comptime count: comptime_int, registers: [count]Register) !void {
    for (registers) |reg| {
        try self.register_manager.getReg(reg, null);
    }
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg_class: RegisterManager.RegisterBitSet = switch (ty.zigTypeTag()) {
        .Float => blk: {
            if (intrinsicsAllowed(self.target.*, ty)) break :blk sse;
            return self.fail("TODO copy {} to register", .{ty.fmtDebug()});
        },
        else => gp,
    };
    const reg: Register = try self.register_manager.allocReg(null, reg_class);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
/// WARNING make sure that the allocated register matches the returned MCValue from an instruction!
fn copyToRegisterWithInstTracking(self: *Self, reg_owner: Air.Inst.Index, ty: Type, mcv: MCValue) !MCValue {
    const reg_class: RegisterManager.RegisterBitSet = switch (ty.zigTypeTag()) {
        .Float => blk: {
            if (intrinsicsAllowed(self.target.*, ty)) break :blk sse;
            return self.fail("TODO copy {} to register", .{ty.fmtDebug()});
        },
        else => gp,
    };
    const reg: Register = try self.register_manager.allocReg(reg_owner, reg_class);
    try self.genSetReg(ty, reg, mcv);
    return MCValue{ .register = reg };
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = @intCast(i32, stack_offset) }, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = @intCast(i32, stack_offset) }, .{ .none, .none, .none });
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airFptrunc for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airFpext for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand_ty = self.air.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const info_a = operand_ty.intInfo(self.target.*);
    const info_b = self.air.typeOfIndex(inst).intInfo(self.target.*);

    const operand_abi_size = operand_ty.abiSize(self.target.*);
    const dest_ty = self.air.typeOfIndex(inst);
    const dest_abi_size = dest_ty.abiSize(self.target.*);
    const dst_mcv: MCValue = blk: {
        if (info_a.bits == info_b.bits) {
            break :blk operand;
        }
        if (operand_abi_size > 8 or dest_abi_size > 8) {
            return self.fail("TODO implement intCast for abi sizes larger than 8", .{});
        }

        const operand_lock: ?RegisterLock = switch (operand) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const reg = try self.register_manager.allocReg(inst, gp);
        try self.genSetReg(dest_ty, reg, .{ .immediate = 0 });
        try self.genSetReg(operand_ty, reg, operand);
        break :blk MCValue{ .register = reg };
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const src_ty = self.air.typeOf(ty_op.operand);
    const dst_ty = self.air.typeOfIndex(inst);
    const operand = try self.resolveInst(ty_op.operand);

    const src_ty_size = src_ty.abiSize(self.target.*);
    const dst_ty_size = dst_ty.abiSize(self.target.*);

    if (src_ty_size > 8 or dst_ty_size > 8) {
        return self.fail("TODO implement trunc for abi sizes larger than 8", .{});
    }

    const operand_lock: ?RegisterLock = switch (operand) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

    const reg: Register = blk: {
        if (operand.isRegister()) {
            if (self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                break :blk operand.register.to64();
            }
        }
        const mcv = try self.copyToRegisterWithInstTracking(inst, src_ty, operand);
        break :blk mcv.register.to64();
    };

    // when truncating a `u16` to `u5`, for example, those top 3 bits in the result
    // have to be removed. this only happens if the dst if not a power-of-two size.
    const dst_bit_size = dst_ty.bitSize(self.target.*);
    if (!math.isPowerOfTwo(dst_bit_size) or dst_bit_size < 8) {
        try self.truncateRegister(dst_ty, reg);
    }

    return self.finishAir(inst, .{ .register = reg }, .{ ty_op.operand, .none, .none });
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }

    const operand_ty = self.air.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        switch (operand) {
            .dead => unreachable,
            .unreach => unreachable,
            .eflags => |cc| {
                break :result MCValue{ .eflags = cc.negate() };
            },
            else => {},
        }

        const operand_lock: ?RegisterLock = switch (operand) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv: MCValue = blk: {
            if (self.reuseOperand(inst, ty_op.operand, 0, operand) and operand.isRegister()) {
                break :blk operand;
            }
            break :blk try self.copyToRegisterWithInstTracking(inst, operand_ty, operand);
        };
        const dst_mcv_lock: ?RegisterLock = switch (dst_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (dst_mcv_lock) |lock| self.register_manager.unlockReg(lock);

        const mask = ~@as(u64, 0);
        try self.genBinOpMir(.xor, operand_ty, dst_mcv, .{ .immediate = mask });

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airMin(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOfIndex(inst);
    if (ty.zigTypeTag() != .Int) {
        return self.fail("TODO implement min for type {}", .{ty.fmtDebug()});
    }
    const signedness = ty.intInfo(self.target.*).signedness;
    const result: MCValue = result: {
        // TODO improve by checking if any operand can be reused.
        // TODO audit register allocation
        const lhs = try self.resolveInst(bin_op.lhs);
        const lhs_lock: ?RegisterLock = switch (lhs) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const lhs_reg = try self.copyToTmpRegister(ty, lhs);
        const lhs_reg_lock = self.register_manager.lockRegAssumeUnused(lhs_reg);
        defer self.register_manager.unlockReg(lhs_reg_lock);

        const rhs_mcv = try self.limitImmediateType(bin_op.rhs, i32);
        const rhs_lock: ?RegisterLock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        try self.genBinOpMir(.cmp, ty, .{ .register = lhs_reg }, rhs_mcv);

        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ty, rhs_mcv);
        const cc: Condition = switch (signedness) {
            .unsigned => .b,
            .signed => .l,
        };
        _ = try self.addInst(.{
            .tag = .cond_mov,
            .ops = Mir.Inst.Ops.encode(.{
                .reg1 = dst_mcv.register,
                .reg2 = lhs_reg,
            }),
            .data = .{ .cc = cc },
        });

        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMax(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement max for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const len = try self.resolveInst(bin_op.rhs);
    const len_ty = self.air.typeOf(bin_op.rhs);

    const stack_offset = @intCast(i32, try self.allocMem(inst, 16, 16));
    try self.genSetStack(ptr_ty, stack_offset, ptr, .{});
    try self.genSetStack(len_ty, stack_offset - 8, len, .{});
    const result = MCValue{ .stack_offset = stack_offset };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const result = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const result = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulDivBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const tag = self.air.instructions.items(.tag)[inst];
    const ty = self.air.typeOfIndex(inst);

    try self.spillRegisters(2, .{ .rax, .rdx });

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);

    const result = try self.genMulDivBinOp(tag, inst, ty, lhs, rhs);

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSubShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const tag = self.air.instructions.items(.tag)[inst];
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);
        const abi_size = ty.abiSize(self.target.*);
        switch (ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement add/sub/shl with overflow for Vector type", .{}),
            .Int => {
                if (abi_size > 8) {
                    return self.fail("TODO implement add/sub/shl with overflow for Ints larger than 64bits", .{});
                }

                try self.spillEflagsIfOccupied();

                if (tag == .shl_with_overflow) {
                    try self.spillRegisters(1, .{.rcx});
                }

                const partial: MCValue = switch (tag) {
                    .add_with_overflow => try self.genBinOp(null, .add, bin_op.lhs, bin_op.rhs),
                    .sub_with_overflow => try self.genBinOp(null, .sub, bin_op.lhs, bin_op.rhs),
                    .shl_with_overflow => blk: {
                        const lhs = try self.resolveInst(bin_op.lhs);
                        const rhs = try self.resolveInst(bin_op.rhs);
                        const shift_ty = self.air.typeOf(bin_op.rhs);
                        break :blk try self.genShiftBinOp(.shl, null, lhs, rhs, ty, shift_ty);
                    },
                    else => unreachable,
                };

                const int_info = ty.intInfo(self.target.*);

                if (math.isPowerOfTwo(int_info.bits) and int_info.bits >= 8) {
                    self.eflags_inst = inst;

                    const cc: Condition = switch (int_info.signedness) {
                        .unsigned => .c,
                        .signed => .o,
                    };
                    break :result MCValue{ .register_overflow = .{
                        .reg = partial.register,
                        .eflags = cc,
                    } };
                }

                self.eflags_inst = null;

                const tuple_ty = self.air.typeOfIndex(inst);
                const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
                const tuple_align = tuple_ty.abiAlignment(self.target.*);
                const overflow_bit_offset = @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*));
                const stack_offset = @intCast(i32, try self.allocMem(inst, tuple_size, tuple_align));

                try self.genSetStackTruncatedOverflowCompare(ty, stack_offset, overflow_bit_offset, partial.register);

                break :result MCValue{ .stack_offset = stack_offset };
            },
            else => unreachable,
        }
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn genSetStackTruncatedOverflowCompare(
    self: *Self,
    ty: Type,
    stack_offset: i32,
    overflow_bit_offset: i32,
    reg: Register,
) !void {
    const reg_lock = self.register_manager.lockReg(reg);
    defer if (reg_lock) |lock| self.register_manager.unlockReg(lock);

    const int_info = ty.intInfo(self.target.*);
    const extended_ty = switch (int_info.signedness) {
        .signed => Type.isize,
        .unsigned => ty,
    };

    const temp_regs = try self.register_manager.allocRegs(3, .{ null, null, null }, gp);
    const temp_regs_locks = self.register_manager.lockRegsAssumeUnused(3, temp_regs);
    defer for (temp_regs_locks) |rreg| {
        self.register_manager.unlockReg(rreg);
    };

    const overflow_reg = temp_regs[0];
    const cc: Condition = switch (int_info.signedness) {
        .signed => .o,
        .unsigned => .c,
    };
    _ = try self.addInst(.{
        .tag = .cond_set_byte,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = overflow_reg.to8(),
        }),
        .data = .{ .cc = cc },
    });

    const scratch_reg = temp_regs[1];
    try self.genSetReg(extended_ty, scratch_reg, .{ .register = reg });
    try self.truncateRegister(ty, scratch_reg);
    try self.genBinOpMir(
        .cmp,
        extended_ty,
        .{ .register = reg },
        .{ .register = scratch_reg },
    );

    const eq_reg = temp_regs[2];
    _ = try self.addInst(.{
        .tag = .cond_set_byte,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = eq_reg.to8() }),
        .data = .{ .cc = .ne },
    });

    try self.genBinOpMir(
        .@"or",
        Type.u8,
        .{ .register = overflow_reg },
        .{ .register = eq_reg },
    );

    try self.genSetStack(ty, stack_offset, .{ .register = scratch_reg }, .{});
    try self.genSetStack(Type.initTag(.u1), stack_offset - overflow_bit_offset, .{
        .register = overflow_reg.to8(),
    }, .{});
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOf(bin_op.lhs);
    const abi_size = ty.abiSize(self.target.*);
    const result: MCValue = result: {
        switch (ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement mul_with_overflow for Vector type", .{}),
            .Int => {
                if (abi_size > 8) {
                    return self.fail("TODO implement mul_with_overflow for Ints larger than 64bits", .{});
                }

                const int_info = ty.intInfo(self.target.*);

                if (math.isPowerOfTwo(int_info.bits) and int_info.bits >= 8) {
                    try self.spillEflagsIfOccupied();
                    self.eflags_inst = inst;

                    try self.spillRegisters(2, .{ .rax, .rdx });

                    const lhs = try self.resolveInst(bin_op.lhs);
                    const rhs = try self.resolveInst(bin_op.rhs);

                    const partial = try self.genMulDivBinOp(.mul, null, ty, lhs, rhs);
                    const cc: Condition = switch (int_info.signedness) {
                        .unsigned => .c,
                        .signed => .o,
                    };
                    break :result MCValue{ .register_overflow = .{
                        .reg = partial.register,
                        .eflags = cc,
                    } };
                }

                try self.spillEflagsIfOccupied();
                self.eflags_inst = null;

                const dst_reg: Register = dst_reg: {
                    switch (int_info.signedness) {
                        .signed => {
                            const lhs = try self.resolveInst(bin_op.lhs);
                            const rhs = try self.resolveInst(bin_op.rhs);

                            const rhs_lock: ?RegisterLock = switch (rhs) {
                                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                                else => null,
                            };
                            defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                            const dst_reg: Register = blk: {
                                if (lhs.isRegister()) break :blk lhs.register;
                                break :blk try self.copyToTmpRegister(ty, lhs);
                            };
                            const dst_reg_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                            defer self.register_manager.unlockReg(dst_reg_lock);

                            const rhs_mcv: MCValue = blk: {
                                if (rhs.isRegister() or rhs.isMemory()) break :blk rhs;
                                break :blk MCValue{ .register = try self.copyToTmpRegister(ty, rhs) };
                            };
                            const rhs_mcv_lock: ?RegisterLock = switch (rhs_mcv) {
                                .register => |reg| self.register_manager.lockReg(reg),
                                else => null,
                            };
                            defer if (rhs_mcv_lock) |lock| self.register_manager.unlockReg(lock);

                            try self.genIntMulComplexOpMir(Type.isize, .{ .register = dst_reg }, rhs_mcv);

                            break :dst_reg dst_reg;
                        },
                        .unsigned => {
                            try self.spillRegisters(2, .{ .rax, .rdx });

                            const lhs = try self.resolveInst(bin_op.lhs);
                            const rhs = try self.resolveInst(bin_op.rhs);

                            const dst_mcv = try self.genMulDivBinOp(.mul, null, ty, lhs, rhs);
                            break :dst_reg dst_mcv.register;
                        },
                    }
                };

                const tuple_ty = self.air.typeOfIndex(inst);
                const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
                const tuple_align = tuple_ty.abiAlignment(self.target.*);
                const overflow_bit_offset = @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*));
                const stack_offset = @intCast(i32, try self.allocMem(inst, tuple_size, tuple_align));

                try self.genSetStackTruncatedOverflowCompare(ty, stack_offset, overflow_bit_offset, dst_reg);

                break :result MCValue{ .stack_offset = stack_offset };
            },
            else => unreachable,
        }
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

/// Generates signed or unsigned integer multiplication/division.
/// Clobbers .rax and .rdx registers.
/// Quotient is saved in .rax and remainder in .rdx.
fn genIntMulDivOpMir(
    self: *Self,
    tag: Mir.Inst.Tag,
    ty: Type,
    signedness: std.builtin.Signedness,
    lhs: MCValue,
    rhs: MCValue,
) !void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    if (abi_size > 8) {
        return self.fail("TODO implement genIntMulDivOpMir for ABI size larger than 8", .{});
    }

    lhs: {
        switch (lhs) {
            .register => |reg| if (reg.to64() == .rax) break :lhs,
            else => {},
        }
        try self.genSetReg(ty, .rax, lhs);
    }

    switch (signedness) {
        .signed => {
            _ = try self.addInst(.{
                .tag = .cwd,
                .ops = Mir.Inst.Ops.encode(.{ .flags = 0b11 }),
                .data = undefined,
            });
        },
        .unsigned => {
            _ = try self.addInst(.{
                .tag = .xor,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = .rdx,
                    .reg2 = .rdx,
                }),
                .data = undefined,
            });
        },
    }

    const factor = switch (rhs) {
        .register => rhs,
        .stack_offset => rhs,
        else => blk: {
            const reg = try self.copyToTmpRegister(ty, rhs);
            break :blk MCValue{ .register = reg };
        },
    };

    switch (factor) {
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = tag,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = reg }),
                .data = undefined,
            });
        },
        .stack_offset => |off| {
            _ = try self.addInst(.{
                .tag = tag,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg2 = .rbp,
                    .flags = switch (abi_size) {
                        1 => 0b00,
                        2 => 0b01,
                        4 => 0b10,
                        8 => 0b11,
                        else => unreachable,
                    },
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        else => unreachable,
    }
}

/// Always returns a register.
/// Clobbers .rax and .rdx registers.
fn genInlineIntDivFloor(self: *Self, ty: Type, lhs: MCValue, rhs: MCValue) !MCValue {
    const signedness = ty.intInfo(self.target.*).signedness;
    const dividend: Register = switch (lhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, lhs),
    };
    const dividend_lock = self.register_manager.lockReg(dividend);
    defer if (dividend_lock) |lock| self.register_manager.unlockReg(lock);

    const divisor: Register = switch (rhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, rhs),
    };
    const divisor_lock = self.register_manager.lockReg(divisor);
    defer if (divisor_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genIntMulDivOpMir(switch (signedness) {
        .signed => .idiv,
        .unsigned => .div,
    }, Type.isize, signedness, .{ .register = dividend }, .{ .register = divisor });

    _ = try self.addInst(.{
        .tag = .xor,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = divisor.to64(),
            .reg2 = dividend.to64(),
        }),
        .data = undefined,
    });
    _ = try self.addInst(.{
        .tag = .sar,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = divisor.to64(),
            .flags = 0b10,
        }),
        .data = .{ .imm = 63 },
    });
    _ = try self.addInst(.{
        .tag = .@"test",
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = .rdx,
            .reg2 = .rdx,
        }),
        .data = undefined,
    });
    _ = try self.addInst(.{
        .tag = .cond_mov,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = divisor.to64(),
            .reg2 = .rdx,
        }),
        .data = .{ .cc = .e },
    });
    try self.genBinOpMir(.add, Type.isize, .{ .register = divisor }, .{ .register = .rax });
    return MCValue{ .register = divisor };
}

fn airShlShrBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    try self.spillRegisters(1, .{.rcx});

    const tag = self.air.instructions.items(.tag)[inst];
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.air.typeOf(bin_op.lhs);
    const rhs_ty = self.air.typeOf(bin_op.rhs);

    const result = try self.genShiftBinOp(tag, inst, lhs, rhs, lhs_ty, rhs_ty);

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }

    const payload_ty = self.air.typeOfIndex(inst);
    const optional_ty = self.air.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBits()) break :result MCValue.none;
        if (optional_ty.isPtrLikeOptional()) {
            if (self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                break :result operand;
            }
            break :result try self.copyToRegisterWithInstTracking(inst, payload_ty, operand);
        }

        const offset = optional_ty.abiSize(self.target.*) - payload_ty.abiSize(self.target.*);
        switch (operand) {
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - @intCast(i32, offset) };
            },
            .register => {
                // TODO reuse the operand
                const result = try self.copyToRegisterWithInstTracking(inst, optional_ty, operand);
                const shift = @intCast(u8, offset * @sizeOf(usize));
                try self.genShiftBinOpMir(.shr, optional_ty, result.register, .{ .immediate = @intCast(u8, shift) });
                break :result result;
            },
            else => return self.fail("TODO implement optional_payload when operand is {}", .{operand}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement .optional_payload_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement .optional_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }
    const err_union_ty = self.air.typeOf(ty_op.operand);
    const err_ty = err_union_ty.errorUnionSet();
    const payload_ty = err_union_ty.errorUnionPayload();
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (err_ty.errorSetIsEmpty()) {
            break :result MCValue{ .immediate = 0 };
        }

        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            break :result operand;
        }

        const err_off = errUnionErrorOffset(payload_ty, self.target.*);
        switch (operand) {
            .stack_offset => |off| {
                const offset = off - @intCast(i32, err_off);
                break :result MCValue{ .stack_offset = offset };
            },
            .register => |reg| {
                // TODO reuse operand
                const lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(lock);
                const result = try self.copyToRegisterWithInstTracking(inst, err_union_ty, operand);
                if (err_off > 0) {
                    const shift = @intCast(u6, err_off * 8);
                    try self.genShiftBinOpMir(.shr, err_union_ty, result.register, .{ .immediate = shift });
                } else {
                    try self.truncateRegister(Type.anyerror, result.register);
                }
                break :result result;
            },
            else => return self.fail("TODO implement unwrap_err_err for {}", .{operand}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }
    const err_union_ty = self.air.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const result = try self.genUnwrapErrorUnionPayloadMir(inst, err_union_ty, operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn genUnwrapErrorUnionPayloadMir(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    err_union_ty: Type,
    err_union: MCValue,
) !MCValue {
    const payload_ty = err_union_ty.errorUnionPayload();

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            break :result MCValue.none;
        }

        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        switch (err_union) {
            .stack_offset => |off| {
                const offset = off - @intCast(i32, payload_off);
                break :result MCValue{ .stack_offset = offset };
            },
            .register => |reg| {
                // TODO reuse operand
                const lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(lock);
                const result_reg: Register = if (maybe_inst) |inst|
                    (try self.copyToRegisterWithInstTracking(inst, err_union_ty, err_union)).register
                else
                    try self.copyToTmpRegister(err_union_ty, err_union);
                if (payload_off > 0) {
                    const shift = @intCast(u6, payload_off * 8);
                    try self.genShiftBinOpMir(.shr, err_union_ty, result_reg, .{ .immediate = shift });
                } else {
                    try self.truncateRegister(payload_ty, result_reg);
                }
                break :result MCValue{ .register = result_reg };
            },
            else => return self.fail("TODO implement genUnwrapErrorUnionPayloadMir for {}", .{err_union}),
        }
    };

    return result;
}

// *(E!T) -> E
fn airUnwrapErrErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement unwrap error union error ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement unwrap error union payload ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement .errunion_payload_ptr_set for {}", .{self.target.cpu.arch});
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
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }

    const payload_ty = self.air.typeOf(ty_op.operand);
    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBits()) {
            break :result MCValue{ .immediate = 1 };
        }

        const optional_ty = self.air.typeOfIndex(inst);
        const operand = try self.resolveInst(ty_op.operand);
        const operand_lock: ?RegisterLock = switch (operand) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        if (optional_ty.isPtrLikeOptional()) {
            // TODO should we check if we can reuse the operand?
            if (self.reuseOperand(inst, ty_op.operand, 0, operand)) {
                break :result operand;
            }
            break :result try self.copyToRegisterWithInstTracking(inst, payload_ty, operand);
        }

        const optional_abi_size = @intCast(u32, optional_ty.abiSize(self.target.*));
        const optional_abi_align = optional_ty.abiAlignment(self.target.*);
        const payload_abi_size = @intCast(u32, payload_ty.abiSize(self.target.*));
        const offset = optional_abi_size - payload_abi_size;

        const stack_offset = @intCast(i32, try self.allocMem(inst, optional_abi_size, optional_abi_align));
        try self.genSetStack(Type.bool, stack_offset, .{ .immediate = 1 }, .{});
        try self.genSetStack(payload_ty, stack_offset - @intCast(i32, offset), operand, .{});
        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }

    const error_union_ty = self.air.getRefType(ty_op.ty);
    const payload_ty = error_union_ty.errorUnionPayload();
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            break :result operand;
        }

        const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
        const abi_align = error_union_ty.abiAlignment(self.target.*);
        const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        const err_off = errUnionErrorOffset(payload_ty, self.target.*);
        try self.genSetStack(payload_ty, stack_offset - @intCast(i32, payload_off), operand, .{});
        try self.genSetStack(Type.anyerror, stack_offset - @intCast(i32, err_off), .{ .immediate = 0 }, .{});

        break :result MCValue{ .stack_offset = stack_offset };
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }
    const error_union_ty = self.air.getRefType(ty_op.ty);
    const payload_ty = error_union_ty.errorUnionPayload();
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) {
            break :result operand;
        }

        const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
        const abi_align = error_union_ty.abiAlignment(self.target.*);
        const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        const err_off = errUnionErrorOffset(payload_ty, self.target.*);
        try self.genSetStack(Type.anyerror, stack_offset - @intCast(i32, err_off), operand, .{});
        try self.genSetStack(payload_ty, stack_offset - @intCast(i32, payload_off), .undef, .{});

        break :result MCValue{ .stack_offset = stack_offset };
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const dst_mcv: MCValue = blk: {
            switch (operand) {
                .stack_offset => |off| {
                    break :blk MCValue{ .stack_offset = off };
                },
                else => return self.fail("TODO implement slice_ptr for {}", .{operand}),
            }
        };
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const dst_mcv: MCValue = blk: {
            switch (operand) {
                .stack_offset => |off| {
                    break :blk MCValue{ .stack_offset = off - 8 };
                },
                else => return self.fail("TODO implement slice_len for {}", .{operand}),
            }
        };
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement ptr_slice_len_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement ptr_slice_ptr_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn elemOffset(self: *Self, index_ty: Type, index: MCValue, elem_size: u64) !Register {
    const reg: Register = blk: {
        switch (index) {
            .immediate => |imm| {
                // Optimisation: if index MCValue is an immediate, we can multiply in `comptime`
                // and set the register directly to the scaled offset as an immediate.
                const reg = try self.register_manager.allocReg(null, gp);
                try self.genSetReg(index_ty, reg, .{ .immediate = imm * elem_size });
                break :blk reg;
            },
            else => {
                const reg = try self.copyToTmpRegister(index_ty, index);
                try self.genIntMulComplexOpMir(index_ty, .{ .register = reg }, .{ .immediate = elem_size });
                break :blk reg;
            },
        }
    };
    return reg;
}

fn genSliceElemPtr(self: *Self, lhs: Air.Inst.Ref, rhs: Air.Inst.Ref) !MCValue {
    const slice_ty = self.air.typeOf(lhs);
    const slice_mcv = try self.resolveInst(lhs);
    const slice_mcv_lock: ?RegisterLock = switch (slice_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (slice_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_ty = slice_ty.childType();
    const elem_size = elem_ty.abiSize(self.target.*);
    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);

    const index_ty = self.air.typeOf(rhs);
    const index_mcv = try self.resolveInst(rhs);
    const index_mcv_lock: ?RegisterLock = switch (index_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (index_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_size);
    const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
    defer self.register_manager.unlockReg(offset_reg_lock);

    const addr_reg = try self.register_manager.allocReg(null, gp);
    switch (slice_mcv) {
        .stack_offset => |off| {
            // mov reg, [rbp - 8]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                    .flags = 0b01,
                }),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, off)) },
            });
        },
        else => return self.fail("TODO implement slice_elem_ptr when slice is {}", .{slice_mcv}),
    }
    // TODO we could allocate register here, but need to expect addr register and potentially
    // offset register.
    try self.genBinOpMir(.add, slice_ptr_field_type, .{ .register = addr_reg }, .{
        .register = offset_reg,
    });
    return MCValue{ .register = addr_reg.to64() };
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else result: {
        const slice_ty = self.air.typeOf(bin_op.lhs);
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);
        const elem_ptr = try self.genSliceElemPtr(bin_op.lhs, bin_op.rhs);
        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.load(dst_mcv, elem_ptr, slice_ptr_field_type);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genSliceElemPtr(extra.lhs, extra.rhs);
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const array_ty = self.air.typeOf(bin_op.lhs);
    const array = try self.resolveInst(bin_op.lhs);
    const array_lock: ?RegisterLock = switch (array) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (array_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_ty = array_ty.childType();
    const elem_abi_size = elem_ty.abiSize(self.target.*);

    const index_ty = self.air.typeOf(bin_op.rhs);
    const index = try self.resolveInst(bin_op.rhs);
    const index_lock: ?RegisterLock = switch (index) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

    const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
    const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
    defer self.register_manager.unlockReg(offset_reg_lock);

    const addr_reg = try self.register_manager.allocReg(null, gp);
    switch (array) {
        .register => {
            const off = @intCast(i32, try self.allocMem(
                inst,
                @intCast(u32, array_ty.abiSize(self.target.*)),
                array_ty.abiAlignment(self.target.*),
            ));
            try self.genSetStack(array_ty, off, array, .{});
            // lea reg, [rbp]
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .stack_offset => |off| {
            // lea reg, [rbp]
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .memory,
        .got_load,
        .direct_load,
        => {
            try self.loadMemPtrIntoRegister(addr_reg, Type.usize, array);
        },
        else => return self.fail("TODO implement array_elem_val when array is {}", .{array}),
    }

    // TODO we could allocate register here, but need to expect addr register and potentially
    // offset register.
    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.genBinOpMir(.add, Type.usize, .{ .register = addr_reg }, .{ .register = offset_reg });
    try self.load(dst_mcv, .{ .register = addr_reg.to64() }, array_ty);

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (!is_volatile and self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    // this is identical to the `airPtrElemPtr` codegen expect here an
    // additional `mov` is needed at the end to get the actual value

    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_lock: ?RegisterLock = switch (ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_ty = ptr_ty.elemType2();
    const elem_abi_size = elem_ty.abiSize(self.target.*);
    const index_ty = self.air.typeOf(bin_op.rhs);
    const index = try self.resolveInst(bin_op.rhs);
    const index_lock: ?RegisterLock = switch (index) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

    const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
    const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
    defer self.register_manager.unlockReg(offset_reg_lock);

    const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, ptr);
    try self.genBinOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });

    const result: MCValue = result: {
        if (elem_abi_size > 8) {
            return self.fail("TODO copy value with size {} from pointer", .{elem_abi_size});
        } else {
            // mov dst_mcv, [dst_mcv]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(dst_mcv.register, @intCast(u32, elem_abi_size)),
                    .reg2 = dst_mcv.register,
                    .flags = 0b01,
                }),
                .data = .{ .imm = 0 },
            });
            break :result .{ .register = registerAlias(dst_mcv.register, @intCast(u32, elem_abi_size)) };
        }
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ extra.lhs, extra.rhs, .none });
    }

    const ptr_ty = self.air.typeOf(extra.lhs);
    const ptr = try self.resolveInst(extra.lhs);
    const ptr_lock: ?RegisterLock = switch (ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_ty = ptr_ty.elemType2();
    const elem_abi_size = elem_ty.abiSize(self.target.*);
    const index_ty = self.air.typeOf(extra.rhs);
    const index = try self.resolveInst(extra.rhs);
    const index_lock: ?RegisterLock = switch (index) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

    const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
    const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
    defer self.register_manager.unlockReg(offset_reg_lock);

    const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, ptr);
    try self.genBinOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });

    return self.finishAir(inst, dst_mcv, .{ extra.lhs, extra.rhs, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const union_ty = ptr_ty.childType();
    const tag_ty = self.air.typeOf(bin_op.rhs);
    const layout = union_ty.unionGetLayout(self.target.*);

    if (layout.tag_size == 0) {
        return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_lock: ?RegisterLock = switch (ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const tag = try self.resolveInst(bin_op.rhs);
    const tag_lock: ?RegisterLock = switch (tag) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (tag_lock) |lock| self.register_manager.unlockReg(lock);

    const adjusted_ptr: MCValue = if (layout.payload_size > 0 and layout.tag_align < layout.payload_align) blk: {
        // TODO reusing the operand
        const reg = try self.copyToTmpRegister(ptr_ty, ptr);
        try self.genBinOpMir(.add, ptr_ty, .{ .register = reg }, .{ .immediate = layout.payload_size });
        break :blk MCValue{ .register = reg };
    } else ptr;

    try self.store(adjusted_ptr, tag, ptr_ty, tag_ty);

    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }

    const tag_ty = self.air.typeOfIndex(inst);
    const union_ty = self.air.typeOf(ty_op.operand);
    const layout = union_ty.unionGetLayout(self.target.*);

    if (layout.tag_size == 0) {
        return self.finishAir(inst, .none, .{ ty_op.operand, .none, .none });
    }

    // TODO reusing the operand
    const operand = try self.resolveInst(ty_op.operand);
    const operand_lock: ?RegisterLock = switch (operand) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

    const tag_abi_size = tag_ty.abiSize(self.target.*);
    const dst_mcv: MCValue = blk: {
        switch (operand) {
            .stack_offset => |off| {
                if (tag_abi_size <= 8) {
                    const offset: i32 = if (layout.tag_align < layout.payload_align) @intCast(i32, layout.payload_size) else 0;
                    break :blk try self.copyToRegisterWithInstTracking(inst, tag_ty, .{
                        .stack_offset = off - offset,
                    });
                }

                return self.fail("TODO implement get_union_tag for ABI larger than 8 bytes and operand {}", .{operand});
            },
            .register => {
                const shift: u6 = if (layout.tag_align < layout.payload_align)
                    @intCast(u6, layout.payload_size * @sizeOf(usize))
                else
                    0;
                const result = try self.copyToRegisterWithInstTracking(inst, union_ty, operand);
                try self.genShiftBinOpMir(.shr, Type.usize, result.register, .{ .immediate = shift });
                break :blk MCValue{
                    .register = registerAlias(result.register, @intCast(u32, layout.tag_size)),
                };
            },
            else => return self.fail("TODO implement get_union_tag for {}", .{operand}),
        }
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airByteSwap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
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

fn reuseOperand(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    op_index: Liveness.OperandInt,
    mcv: MCValue,
) bool {
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
    const abi_size = elem_ty.abiSize(self.target.*);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm });
        },
        .stack_offset => {
            const reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
        .ptr_stack_offset => |off| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off });
        },
        .register => |reg| {
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |lock| self.register_manager.unlockReg(lock);

            switch (dst_mcv) {
                .dead => unreachable,
                .undef => unreachable,
                .eflags => unreachable,
                .register => |dst_reg| {
                    // mov dst_reg, [reg]
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(dst_reg, @intCast(u32, abi_size)),
                            .reg2 = reg,
                            .flags = 0b01,
                        }),
                        .data = .{ .imm = 0 },
                    });
                },
                .stack_offset => |off| {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        try self.load(.{ .register = tmp_reg }, ptr, ptr_ty);
                        return self.genSetStack(elem_ty, off, MCValue{ .register = tmp_reg }, .{});
                    }

                    try self.genInlineMemcpy(dst_mcv, ptr, .{ .immediate = abi_size }, .{});
                },
                else => return self.fail("TODO implement loading from register into {}", .{dst_mcv}),
            }
        },
        .memory,
        .got_load,
        .direct_load,
        => {
            const reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const elem_ty = self.air.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBitsIgnoreComptime())
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

fn loadMemPtrIntoRegister(self: *Self, reg: Register, ptr_ty: Type, ptr: MCValue) InnerError!void {
    switch (ptr) {
        .got_load,
        .direct_load,
        => |sym_index| {
            const abi_size = @intCast(u32, ptr_ty.abiSize(self.target.*));
            const flags: u2 = switch (ptr) {
                .got_load => 0b00,
                .direct_load => 0b01,
                else => unreachable,
            };
            const mod = self.bin_file.options.module.?;
            const fn_owner_decl = mod.declPtr(self.mod_fn.owner_decl);
            _ = try self.addInst(.{
                .tag = .lea_pie,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(reg, abi_size),
                    .flags = flags,
                }),
                .data = .{
                    .load_reloc = .{
                        .atom_index = fn_owner_decl.link.macho.local_sym_index,
                        .sym_index = sym_index,
                    },
                },
            });
        },
        .memory => |addr| {
            // TODO: in case the address fits in an imm32 we can use [ds:imm32]
            // instead of wasting an instruction copying the address to a register
            try self.genSetReg(ptr_ty, reg, .{ .immediate = addr });
        },
        else => unreachable,
    }
}

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    const abi_size = value_ty.abiSize(self.target.*);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(value_ty, .{ .memory = imm }, value);
        },
        .stack_offset => {
            const reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.store(.{ .register = reg }, value, ptr_ty, value_ty);
        },
        .ptr_stack_offset => |off| {
            try self.genSetStack(value_ty, off, value, .{});
        },
        .register => |reg| {
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |lock| self.register_manager.unlockReg(lock);

            switch (value) {
                .none => unreachable,
                .undef => unreachable,
                .dead => unreachable,
                .unreach => unreachable,
                .eflags => unreachable,
                .immediate => |imm| {
                    switch (abi_size) {
                        1, 2, 4 => {
                            // TODO this is wasteful!
                            // introduce new MIR tag specifically for mov [reg + 0], imm
                            const payload = try self.addExtra(Mir.ImmPair{
                                .dest_off = 0,
                                .operand = @truncate(u32, imm),
                            });
                            _ = try self.addInst(.{
                                .tag = .mov_mem_imm,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = reg.to64(),
                                    .flags = switch (abi_size) {
                                        1 => 0b00,
                                        2 => 0b01,
                                        4 => 0b10,
                                        else => unreachable,
                                    },
                                }),
                                .data = .{ .payload = payload },
                            });
                        },
                        8 => {
                            // TODO: optimization: if the imm is only using the lower
                            // 4 bytes and can be sign extended we can use a normal mov
                            // with indirect addressing (mov [reg64], imm32).

                            // movabs does not support indirect register addressing
                            // so we need an extra register and an extra mov.
                            const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                            return self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                        },
                        else => {
                            return self.fail("TODO implement set pointee with immediate of ABI size {d}", .{abi_size});
                        },
                    }
                },
                .register => |src_reg| {
                    try self.genInlineMemcpyRegisterRegister(value_ty, reg, src_reg, 0);
                },
                .got_load,
                .direct_load,
                .memory,
                .stack_offset,
                => {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                        return self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                    }

                    try self.genInlineMemcpy(.{ .stack_offset = 0 }, value, .{ .immediate = abi_size }, .{
                        .source_stack_base = .rbp,
                        .dest_stack_base = reg.to64(),
                    });
                },
                else => |other| {
                    return self.fail("TODO implement set pointee with {}", .{other});
                },
            }
        },
        .got_load,
        .direct_load,
        .memory,
        => {
            const value_lock: ?RegisterLock = switch (value) {
                .register => |reg| self.register_manager.lockReg(reg),
                else => null,
            };
            defer if (value_lock) |lock| self.register_manager.unlockReg(lock);

            const addr_reg = try self.register_manager.allocReg(null, gp);
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.loadMemPtrIntoRegister(addr_reg, ptr_ty, ptr);

            // to get the actual address of the value we want to modify we have to go through the GOT
            // mov reg, [reg]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = addr_reg.to64(),
                    .reg2 = addr_reg.to64(),
                    .flags = 0b01,
                }),
                .data = .{ .imm = 0 },
            });

            const new_ptr = MCValue{ .register = addr_reg.to64() };

            switch (value) {
                .immediate => |imm| {
                    if (abi_size > 8) {
                        return self.fail("TODO saving imm to memory for abi_size {}", .{abi_size});
                    }

                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = 0,
                        // TODO check if this logic is correct
                        .operand = @truncate(u32, imm),
                    });
                    const flags: u2 = switch (abi_size) {
                        1 => 0b00,
                        2 => 0b01,
                        4 => 0b10,
                        8 => 0b11,
                        else => unreachable,
                    };
                    if (flags == 0b11) {
                        const top_bits: u32 = @intCast(u32, imm >> 32);
                        const can_extend = if (value_ty.isUnsignedInt())
                            (top_bits == 0) and (imm & 0x8000_0000) == 0
                        else
                            top_bits == 0xffff_ffff;

                        if (!can_extend) {
                            return self.fail("TODO imm64 would get incorrectly sign extended", .{});
                        }
                    }
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = addr_reg.to64(),
                            .flags = flags,
                        }),
                        .data = .{ .payload = payload },
                    });
                },
                .register => {
                    return self.store(new_ptr, value, ptr_ty, value_ty);
                },
                .got_load,
                .direct_load,
                .memory,
                => {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        const tmp_reg_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                        defer self.register_manager.unlockReg(tmp_reg_lock);

                        try self.loadMemPtrIntoRegister(tmp_reg, value_ty, value);

                        _ = try self.addInst(.{
                            .tag = .mov,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = tmp_reg,
                                .reg2 = tmp_reg,
                                .flags = 0b01,
                            }),
                            .data = .{ .imm = 0 },
                        });
                        return self.store(new_ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                    }

                    try self.genInlineMemcpy(new_ptr, value, .{ .immediate = abi_size }, .{});
                },
                .stack_offset => {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                        return self.store(new_ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                    }

                    try self.genInlineMemcpy(new_ptr, value, .{ .immediate = abi_size }, .{});
                },
                else => return self.fail("TODO implement storing {} to MCValue.memory", .{value}),
            }
        },
    }
}

fn airStore(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const value = try self.resolveInst(bin_op.rhs);
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
    if (self.liveness.isUnused(inst)) {
        return MCValue.dead;
    }

    const mcv = try self.resolveInst(operand);
    const ptr_ty = self.air.typeOf(operand);
    const struct_ty = ptr_ty.childType();
    const struct_field_offset = @intCast(u32, struct_ty.structFieldOffset(index, self.target.*));

    const dst_mcv: MCValue = result: {
        switch (mcv) {
            .stack_offset => {
                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = struct_field_offset,
                });
                const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
                defer self.register_manager.unlockReg(offset_reg_lock);

                const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, mcv);
                try self.genBinOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });
                break :result dst_mcv;
            },
            .ptr_stack_offset => |off| {
                const ptr_stack_offset = off - @intCast(i32, struct_field_offset);
                break :result MCValue{ .ptr_stack_offset = ptr_stack_offset };
            },
            .register => |reg| {
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);

                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = struct_field_offset,
                });
                const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
                defer self.register_manager.unlockReg(offset_reg_lock);

                const can_reuse_operand = self.reuseOperand(inst, operand, 0, mcv);
                const result_reg: Register = blk: {
                    if (can_reuse_operand) {
                        break :blk reg;
                    } else {
                        const result_reg = try self.register_manager.allocReg(inst, gp);
                        try self.genSetReg(ptr_ty, result_reg, mcv);
                        break :blk result_reg;
                    }
                };
                const result_reg_lock = self.register_manager.lockReg(result_reg);
                defer if (result_reg_lock) |lock| self.register_manager.unlockReg(lock);

                try self.genBinOpMir(.add, ptr_ty, .{ .register = result_reg }, .{ .register = offset_reg });
                break :result MCValue{ .register = result_reg };
            },
            else => return self.fail("TODO implement codegen struct_field_ptr for {}", .{mcv}),
        }
    };
    return dst_mcv;
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ extra.struct_operand, .none, .none });
    }

    const mcv = try self.resolveInst(operand);
    const struct_ty = self.air.typeOf(operand);
    const struct_field_offset = struct_ty.structFieldOffset(index, self.target.*);
    const struct_field_ty = struct_ty.structFieldType(index);

    const result: MCValue = result: {
        switch (mcv) {
            .stack_offset => |off| {
                const stack_offset = off - @intCast(i32, struct_field_offset);
                break :result MCValue{ .stack_offset = stack_offset };
            },
            .register => |reg| {
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);

                const dst_mcv: MCValue = blk: {
                    if (self.reuseOperand(inst, operand, 0, mcv)) {
                        break :blk mcv;
                    } else {
                        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, Type.usize, .{
                            .register = reg.to64(),
                        });
                        break :blk dst_mcv;
                    }
                };
                const dst_mcv_lock: ?RegisterLock = switch (dst_mcv) {
                    .register => |a_reg| self.register_manager.lockReg(a_reg),
                    else => null,
                };
                defer if (dst_mcv_lock) |lock| self.register_manager.unlockReg(lock);

                // Shift by struct_field_offset.
                const shift = @intCast(u8, struct_field_offset * @sizeOf(usize));
                try self.genShiftBinOpMir(.shr, Type.usize, dst_mcv.register, .{ .immediate = shift });

                // Mask with reg.size() - struct_field_size
                const max_reg_bit_width = Register.rax.size();
                const mask_shift = @intCast(u6, (max_reg_bit_width - struct_field_ty.bitSize(self.target.*)));
                const mask = (~@as(u64, 0)) >> mask_shift;

                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinOpMir(.@"and", Type.usize, dst_mcv, .{ .register = tmp_reg });

                const signedness: std.builtin.Signedness = blk: {
                    if (struct_field_ty.zigTypeTag() != .Int) break :blk .unsigned;
                    break :blk struct_field_ty.intInfo(self.target.*).signedness;
                };
                const field_size = @intCast(u32, struct_field_ty.abiSize(self.target.*));
                if (signedness == .signed and field_size < 8) {
                    _ = try self.addInst(.{
                        .tag = .mov_sign_extend,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = dst_mcv.register,
                            .reg2 = registerAlias(dst_mcv.register, field_size),
                        }),
                        .data = undefined,
                    });
                }

                break :result dst_mcv;
            },
            .register_overflow => |ro| {
                switch (index) {
                    0 => {
                        // Get wrapped value for overflow operation.
                        break :result MCValue{ .register = ro.reg };
                    },
                    1 => {
                        // Get overflow bit.
                        const reg_lock = self.register_manager.lockRegAssumeUnused(ro.reg);
                        defer self.register_manager.unlockReg(reg_lock);

                        const dst_reg = try self.register_manager.allocReg(inst, gp);
                        _ = try self.addInst(.{
                            .tag = .cond_set_byte,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = dst_reg.to8(),
                            }),
                            .data = .{ .cc = ro.eflags },
                        });
                        break :result MCValue{ .register = dst_reg.to8() };
                    },
                    else => unreachable,
                }
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airFieldParentPtr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// Clobbers .rcx for non-immediate shift value.
fn genShiftBinOpMir(self: *Self, tag: Mir.Inst.Tag, ty: Type, reg: Register, shift: MCValue) !void {
    assert(reg.to64() != .rcx);

    switch (tag) {
        .sal, .sar, .shl, .shr => {},
        else => unreachable,
    }

    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    blk: {
        switch (shift) {
            .immediate => |imm| switch (imm) {
                0 => return,
                1 => {
                    _ = try self.addInst(.{
                        .tag = tag,
                        .ops = Mir.Inst.Ops.encode(.{ .reg1 = registerAlias(reg, abi_size) }),
                        .data = undefined,
                    });
                    return;
                },
                else => {
                    _ = try self.addInst(.{
                        .tag = tag,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(reg, abi_size),
                            .flags = 0b10,
                        }),
                        .data = .{ .imm = @intCast(u8, imm) },
                    });
                    return;
                },
            },
            .register => |shift_reg| {
                if (shift_reg == .rcx) break :blk;
            },
            else => {},
        }
        assert(self.register_manager.isRegFree(.rcx));
        try self.register_manager.getReg(.rcx, null);
        try self.genSetReg(Type.u8, .rcx, shift);
    }

    _ = try self.addInst(.{
        .tag = tag,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = registerAlias(reg, abi_size),
            .flags = 0b01,
        }),
        .data = undefined,
    });
}

/// Result is always a register.
/// Clobbers .rcx for non-immediate rhs, therefore care is needed to spill .rcx upfront.
/// Asserts .rcx is free.
fn genShiftBinOp(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs: MCValue,
    rhs: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    if (lhs_ty.zigTypeTag() == .Vector or lhs_ty.zigTypeTag() == .Float) {
        return self.fail("TODO implement genShiftBinOp for {}", .{lhs_ty.fmtDebug()});
    }
    if (lhs_ty.abiSize(self.target.*) > 8) {
        return self.fail("TODO implement genShiftBinOp for {}", .{lhs_ty.fmtDebug()});
    }

    assert(rhs_ty.abiSize(self.target.*) == 1);

    const lhs_lock: ?RegisterLock = switch (lhs) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_lock: ?RegisterLock = switch (rhs) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    assert(self.register_manager.isRegFree(.rcx));
    try self.register_manager.getReg(.rcx, null);
    const rcx_lock = self.register_manager.lockRegAssumeUnused(.rcx);
    defer self.register_manager.unlockReg(rcx_lock);

    const dst: MCValue = blk: {
        if (maybe_inst) |inst| {
            const bin_op = self.air.instructions.items(.data)[inst].bin_op;
            // TODO dst can also be a memory location
            if (self.reuseOperand(inst, bin_op.lhs, 0, lhs) and lhs.isRegister()) {
                break :blk lhs;
            }
            break :blk try self.copyToRegisterWithInstTracking(inst, lhs_ty, lhs);
        }
        break :blk MCValue{ .register = try self.copyToTmpRegister(lhs_ty, lhs) };
    };

    const signedness = lhs_ty.intInfo(self.target.*).signedness;
    switch (tag) {
        .shl => try self.genShiftBinOpMir(switch (signedness) {
            .signed => .sal,
            .unsigned => .shl,
        }, lhs_ty, dst.register, rhs),

        .shl_exact => try self.genShiftBinOpMir(.shl, lhs_ty, dst.register, rhs),

        .shr,
        .shr_exact,
        => try self.genShiftBinOpMir(switch (signedness) {
            .signed => .sar,
            .unsigned => .shr,
        }, lhs_ty, dst.register, rhs),

        else => unreachable,
    }

    return dst;
}

/// Result is always a register.
/// Clobbers .rax and .rdx therefore care is needed to spill .rax and .rdx upfront.
/// Asserts .rax and .rdx are free.
fn genMulDivBinOp(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    ty: Type,
    lhs: MCValue,
    rhs: MCValue,
) !MCValue {
    if (ty.zigTypeTag() == .Vector or ty.zigTypeTag() == .Float) {
        return self.fail("TODO implement genBinOp for {}", .{ty.fmtDebug()});
    }
    if (ty.abiSize(self.target.*) > 8) {
        return self.fail("TODO implement genBinOp for {}", .{ty.fmtDebug()});
    }
    if (tag == .div_float) {
        return self.fail("TODO implement genMulDivBinOp for div_float", .{});
    }

    assert(self.register_manager.isRegFree(.rax));
    assert(self.register_manager.isRegFree(.rdx));

    const reg_locks = self.register_manager.lockRegsAssumeUnused(2, .{ .rax, .rdx });
    defer for (reg_locks) |reg| {
        self.register_manager.unlockReg(reg);
    };

    const int_info = ty.intInfo(self.target.*);
    const signedness = int_info.signedness;

    switch (tag) {
        .mul,
        .mulwrap,
        .rem,
        .div_trunc,
        .div_exact,
        => {
            const track_inst_rax: ?Air.Inst.Index = switch (tag) {
                .mul, .mulwrap, .div_exact, .div_trunc => maybe_inst,
                else => null,
            };
            const track_inst_rdx: ?Air.Inst.Index = switch (tag) {
                .rem => maybe_inst,
                else => null,
            };
            try self.register_manager.getReg(.rax, track_inst_rax);
            try self.register_manager.getReg(.rdx, track_inst_rdx);

            const mir_tag: Mir.Inst.Tag = switch (signedness) {
                .signed => switch (tag) {
                    .mul, .mulwrap => Mir.Inst.Tag.imul,
                    .div_trunc, .div_exact, .rem => Mir.Inst.Tag.idiv,
                    else => unreachable,
                },
                .unsigned => switch (tag) {
                    .mul, .mulwrap => Mir.Inst.Tag.mul,
                    .div_trunc, .div_exact, .rem => Mir.Inst.Tag.div,
                    else => unreachable,
                },
            };

            try self.genIntMulDivOpMir(mir_tag, ty, .signed, lhs, rhs);

            switch (signedness) {
                .signed => switch (tag) {
                    .mul, .mulwrap, .div_trunc, .div_exact => return MCValue{ .register = .rax },
                    .rem => return MCValue{ .register = .rdx },
                    else => unreachable,
                },
                .unsigned => switch (tag) {
                    .mul, .mulwrap, .div_trunc, .div_exact => return MCValue{
                        .register = registerAlias(.rax, @intCast(u32, ty.abiSize(self.target.*))),
                    },
                    .rem => return MCValue{
                        .register = registerAlias(.rdx, @intCast(u32, ty.abiSize(self.target.*))),
                    },
                    else => unreachable,
                },
            }
        },

        .mod => {
            try self.register_manager.getReg(.rax, null);
            try self.register_manager.getReg(.rdx, if (signedness == .unsigned) maybe_inst else null);

            switch (signedness) {
                .signed => {
                    const div_floor = try self.genInlineIntDivFloor(ty, lhs, rhs);
                    try self.genIntMulComplexOpMir(ty, div_floor, rhs);
                    const div_floor_lock = self.register_manager.lockReg(div_floor.register);
                    defer if (div_floor_lock) |lock| self.register_manager.unlockReg(lock);

                    const result: MCValue = if (maybe_inst) |inst|
                        try self.copyToRegisterWithInstTracking(inst, ty, lhs)
                    else
                        MCValue{ .register = try self.copyToTmpRegister(ty, lhs) };
                    try self.genBinOpMir(.sub, ty, result, div_floor);

                    return result;
                },
                .unsigned => {
                    try self.genIntMulDivOpMir(.div, ty, .unsigned, lhs, rhs);
                    return MCValue{ .register = registerAlias(.rdx, @intCast(u32, ty.abiSize(self.target.*))) };
                },
            }
        },

        .div_floor => {
            try self.register_manager.getReg(.rax, if (signedness == .unsigned) maybe_inst else null);
            try self.register_manager.getReg(.rdx, null);

            const lhs_lock: ?RegisterLock = switch (lhs) {
                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                else => null,
            };
            defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

            const actual_rhs: MCValue = blk: {
                switch (signedness) {
                    .signed => {
                        const rhs_lock: ?RegisterLock = switch (rhs) {
                            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                            else => null,
                        };
                        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                        if (maybe_inst) |inst| {
                            break :blk try self.copyToRegisterWithInstTracking(inst, ty, rhs);
                        }
                        break :blk MCValue{ .register = try self.copyToTmpRegister(ty, rhs) };
                    },
                    .unsigned => break :blk rhs,
                }
            };
            const rhs_lock: ?RegisterLock = switch (actual_rhs) {
                .register => |reg| self.register_manager.lockReg(reg),
                else => null,
            };
            defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

            const result: MCValue = result: {
                switch (signedness) {
                    .signed => break :result try self.genInlineIntDivFloor(ty, lhs, actual_rhs),
                    .unsigned => {
                        try self.genIntMulDivOpMir(.div, ty, .unsigned, lhs, actual_rhs);
                        break :result MCValue{
                            .register = registerAlias(.rax, @intCast(u32, ty.abiSize(self.target.*))),
                        };
                    },
                }
            };
            return result;
        },

        else => unreachable,
    }
}

/// Result is always a register.
fn genBinOp(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    tag: Air.Inst.Tag,
    lhs_air: Air.Inst.Ref,
    rhs_air: Air.Inst.Ref,
) !MCValue {
    const lhs = try self.resolveInst(lhs_air);
    const rhs = try self.resolveInst(rhs_air);
    const lhs_ty = self.air.typeOf(lhs_air);
    const rhs_ty = self.air.typeOf(rhs_air);
    if (lhs_ty.zigTypeTag() == .Vector) {
        return self.fail("TODO implement genBinOp for {}", .{lhs_ty.fmtDebug()});
    }
    if (lhs_ty.abiSize(self.target.*) > 8) {
        return self.fail("TODO implement genBinOp for {}", .{lhs_ty.fmtDebug()});
    }

    const is_commutative: bool = switch (tag) {
        .add,
        .addwrap,
        .bool_or,
        .bit_or,
        .bool_and,
        .bit_and,
        .xor,
        => true,

        else => false,
    };

    const lhs_lock: ?RegisterLock = switch (lhs) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_lock: ?RegisterLock = switch (rhs) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    var flipped: bool = false;
    const dst_mcv: MCValue = blk: {
        if (maybe_inst) |inst| {
            if (self.reuseOperand(inst, lhs_air, 0, lhs) and lhs.isRegister()) {
                break :blk lhs;
            }
            if (is_commutative and self.reuseOperand(inst, rhs_air, 1, rhs) and rhs.isRegister()) {
                flipped = true;
                break :blk rhs;
            }
            break :blk try self.copyToRegisterWithInstTracking(inst, lhs_ty, lhs);
        }
        break :blk MCValue{ .register = try self.copyToTmpRegister(lhs_ty, lhs) };
    };
    const dst_mcv_lock: ?RegisterLock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const src_mcv: MCValue = blk: {
        const mcv = if (flipped) lhs else rhs;
        if (mcv.isRegister() or mcv.isMemory()) break :blk mcv;
        break :blk MCValue{ .register = try self.copyToTmpRegister(rhs_ty, mcv) };
    };
    const src_mcv_lock: ?RegisterLock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (src_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    switch (tag) {
        .add,
        .addwrap,
        => try self.genBinOpMir(.add, lhs_ty, dst_mcv, src_mcv),

        .sub,
        .subwrap,
        => try self.genBinOpMir(.sub, lhs_ty, dst_mcv, src_mcv),

        .ptr_add,
        .ptr_sub,
        => {
            const mir_tag: Mir.Inst.Tag = switch (tag) {
                .ptr_add => .add,
                .ptr_sub => .sub,
                else => unreachable,
            };
            const elem_size = lhs_ty.elemType2().abiSize(self.target.*);
            try self.genIntMulComplexOpMir(rhs_ty, src_mcv, .{ .immediate = elem_size });
            try self.genBinOpMir(mir_tag, lhs_ty, dst_mcv, src_mcv);
        },

        .bool_or,
        .bit_or,
        => try self.genBinOpMir(.@"or", lhs_ty, dst_mcv, src_mcv),

        .bool_and,
        .bit_and,
        => try self.genBinOpMir(.@"and", lhs_ty, dst_mcv, src_mcv),

        .xor => try self.genBinOpMir(.xor, lhs_ty, dst_mcv, src_mcv),

        else => unreachable,
    }
    return dst_mcv;
}

fn genBinOpMir(self: *Self, mir_tag: Mir.Inst.Tag, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .register_overflow => unreachable,
                .ptr_stack_offset => {
                    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
                    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

                    const reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                    return self.genBinOpMir(mir_tag, dst_ty, dst_mcv, .{ .register = reg });
                },
                .register => |src_reg| switch (dst_ty.zigTypeTag()) {
                    .Float => {
                        if (intrinsicsAllowed(self.target.*, dst_ty)) {
                            const actual_tag: Mir.Inst.Tag = switch (dst_ty.tag()) {
                                .f32 => switch (mir_tag) {
                                    .add => if (hasAvxSupport(self.target.*))
                                        Mir.Inst.Tag.add_f32_avx
                                    else
                                        Mir.Inst.Tag.add_f32_sse,
                                    .cmp => if (hasAvxSupport(self.target.*))
                                        Mir.Inst.Tag.cmp_f32_avx
                                    else
                                        Mir.Inst.Tag.cmp_f32_sse,
                                    else => return self.fail("TODO genBinOpMir for f32 register-register with MIR tag {}", .{mir_tag}),
                                },
                                .f64 => switch (mir_tag) {
                                    .add => if (hasAvxSupport(self.target.*))
                                        Mir.Inst.Tag.add_f64_avx
                                    else
                                        Mir.Inst.Tag.add_f64_sse,
                                    .cmp => if (hasAvxSupport(self.target.*))
                                        Mir.Inst.Tag.cmp_f64_avx
                                    else
                                        Mir.Inst.Tag.cmp_f64_sse,
                                    else => return self.fail("TODO genBinOpMir for f64 register-register with MIR tag {}", .{mir_tag}),
                                },
                                else => return self.fail("TODO genBinOpMir for float register-register and type {}", .{dst_ty.fmtDebug()}),
                            };
                            _ = try self.addInst(.{
                                .tag = actual_tag,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = dst_reg.to128(),
                                    .reg2 = src_reg.to128(),
                                }),
                                .data = undefined,
                            });
                            return;
                        }

                        return self.fail("TODO genBinOpMir for float register-register and no intrinsics", .{});
                    },
                    else => {
                        _ = try self.addInst(.{
                            .tag = mir_tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = registerAlias(dst_reg, abi_size),
                                .reg2 = registerAlias(src_reg, abi_size),
                            }),
                            .data = undefined,
                        });
                    },
                },
                .immediate => |imm| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = Mir.Inst.Ops.encode(.{ .reg1 = registerAlias(dst_reg, abi_size) }),
                        .data = .{ .imm = @truncate(u32, imm) },
                    });
                },
                .memory,
                .got_load,
                .direct_load,
                .eflags,
                => {
                    assert(abi_size <= 8);
                    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
                    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

                    const reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                    return self.genBinOpMir(mir_tag, dst_ty, dst_mcv, .{ .register = reg });
                },
                .stack_offset => |off| {
                    if (off > math.maxInt(i32)) {
                        return self.fail("stack offset too large", .{});
                    }
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }),
                        .data = .{ .imm = @bitCast(u32, -off) },
                    });
                },
            }
        },
        .ptr_stack_offset, .stack_offset => |off| {
            if (off > math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            if (abi_size > 8) {
                return self.fail("TODO implement {} for stack dst with large ABI", .{mir_tag});
            }

            switch (src_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = .rbp,
                            .reg2 = registerAlias(src_reg, abi_size),
                            .flags = 0b10,
                        }),
                        .data = .{ .imm = @bitCast(u32, -off) },
                    });
                },
                .immediate => |imm| {
                    const tag: Mir.Inst.Tag = switch (mir_tag) {
                        .add => .add_mem_imm,
                        .@"or" => .or_mem_imm,
                        .@"and" => .and_mem_imm,
                        .sub => .sub_mem_imm,
                        .xor => .xor_mem_imm,
                        .cmp => .cmp_mem_imm,
                        else => unreachable,
                    };
                    const flags: u2 = switch (abi_size) {
                        1 => 0b00,
                        2 => 0b01,
                        4 => 0b10,
                        8 => 0b11,
                        else => unreachable,
                    };
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -off),
                        .operand = @truncate(u32, imm),
                    });
                    _ = try self.addInst(.{
                        .tag = tag,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = .rbp,
                            .flags = flags,
                        }),
                        .data = .{ .payload = payload },
                    });
                },
                .memory,
                .stack_offset,
                .ptr_stack_offset,
                => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source memory", .{});
                },
                .got_load, .direct_load => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source symbol at index in linker", .{});
                },
                .eflags => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source eflags", .{});
                },
            }
        },
        .memory => {
            return self.fail("TODO implement x86 ADD/SUB/CMP destination memory", .{});
        },
        .got_load, .direct_load => {
            return self.fail("TODO implement x86 ADD/SUB/CMP destination symbol at index", .{});
        },
    }
}

/// Performs multi-operand integer multiplication between dst_mcv and src_mcv, storing the result in dst_mcv.
/// Does not support byte-size operands.
fn genIntMulComplexOpMir(self: *Self, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .eflags => unreachable,
        .ptr_stack_offset => unreachable,
        .register_overflow => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => try self.genSetReg(dst_ty, dst_reg, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| {
                    // register, register
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = registerAlias(src_reg, abi_size),
                        }),
                        .data = undefined,
                    });
                },
                .immediate => |imm| {
                    // TODO take into account the type's ABI size when selecting the register alias
                    // register, immediate
                    if (math.minInt(i32) <= imm and imm <= math.maxInt(i32)) {
                        _ = try self.addInst(.{
                            .tag = .imul_complex,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = dst_reg.to32(),
                                .reg2 = dst_reg.to32(),
                                .flags = 0b10,
                            }),
                            .data = .{ .imm = @truncate(u32, imm) },
                        });
                    } else {
                        // TODO verify we don't spill and assign to the same register as dst_mcv
                        const src_reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                        return self.genIntMulComplexOpMir(dst_ty, dst_mcv, MCValue{ .register = src_reg });
                    }
                },
                .stack_offset => |off| {
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }),
                        .data = .{ .imm = @bitCast(u32, -off) },
                    });
                },
                .memory => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .got_load, .direct_load => {
                    return self.fail("TODO implement x86 multiply source symbol at index in linker", .{});
                },
                .eflags => {
                    return self.fail("TODO implement x86 multiply source eflags", .{});
                },
            }
        },
        .stack_offset => |off| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => return self.genSetStack(dst_ty, off, .undef, .{}),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| {
                    // copy dst to a register
                    const dst_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
                    // multiply into dst_reg
                    // register, register
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = registerAlias(src_reg, abi_size),
                        }),
                        .data = undefined,
                    });
                    // copy dst_reg back out
                    return self.genSetStack(dst_ty, off, .{ .register = dst_reg }, .{});
                },
                .immediate => {
                    // copy dst to a register
                    const dst_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
                    const dst_reg_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                    defer self.register_manager.unlockReg(dst_reg_lock);

                    try self.genIntMulComplexOpMir(dst_ty, .{ .register = dst_reg }, src_mcv);

                    return self.genSetStack(dst_ty, off, .{ .register = dst_reg }, .{});
                },
                .memory, .stack_offset => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .got_load, .direct_load => {
                    return self.fail("TODO implement x86 multiply source symbol at index in linker", .{});
                },
                .eflags => {
                    return self.fail("TODO implement x86 multiply source eflags", .{});
                },
            }
        },
        .memory => {
            return self.fail("TODO implement x86 multiply destination memory", .{});
        },
        .got_load, .direct_load => {
            return self.fail("TODO implement x86 multiply destination symbol at index in linker", .{});
        },
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.air.typeOfIndex(inst);
    const mcv = self.args[arg_index];
    const name = self.mod_fn.getParamName(arg_index);
    const name_with_null = name.ptr[0 .. name.len + 1];

    if (self.liveness.isUnused(inst))
        return self.finishAirBookkeeping();

    const dst_mcv: MCValue = blk: {
        switch (mcv) {
            .register => |reg| {
                self.register_manager.getRegAssumeFree(reg.to64(), inst);
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
                break :blk mcv;
            },
            .stack_offset => |off| {
                const offset = @intCast(i32, self.max_end_stack) - off + 16;
                switch (self.debug_output) {
                    .dwarf => |dw| {
                        const dbg_info = &dw.dbg_info;
                        try dbg_info.ensureUnusedCapacity(8);
                        dbg_info.appendAssumeCapacity(@enumToInt(link.File.Dwarf.AbbrevKind.parameter));
                        const fixup = dbg_info.items.len;
                        dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                            1, // we will backpatch it after we encode the displacement in LEB128
                            DW.OP.breg6, // .rbp TODO handle -fomit-frame-pointer
                        });
                        leb128.writeILEB128(dbg_info.writer(), offset) catch unreachable;
                        dbg_info.items[fixup] += @intCast(u8, dbg_info.items.len - fixup - 2);
                        try dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                        try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                        dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string

                    },
                    .plan9 => {},
                    .none => {},
                }
                break :blk MCValue{ .stack_offset = -offset };
            },
            else => return self.fail("TODO implement arg for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airBreakpoint(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .interrupt,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = undefined,
    });
    return self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airRetAddr for x86_64", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airFrameAddress for x86_64", .{});
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for x86_64", .{});
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

    try self.spillEflagsIfOccupied();

    for (caller_preserved_regs) |reg| {
        try self.register_manager.getReg(reg, null);
    }

    const rdi_lock: ?RegisterLock = blk: {
        if (info.return_value == .stack_offset) {
            const ret_ty = fn_ty.fnReturnType();
            const ret_abi_size = @intCast(u32, ret_ty.abiSize(self.target.*));
            const ret_abi_align = @intCast(u32, ret_ty.abiAlignment(self.target.*));
            const stack_offset = @intCast(i32, try self.allocMem(inst, ret_abi_size, ret_abi_align));
            log.debug("airCall: return value on stack at offset {}", .{stack_offset});

            try self.register_manager.getReg(.rdi, null);
            try self.genSetReg(Type.usize, .rdi, .{ .ptr_stack_offset = stack_offset });
            const rdi_lock = self.register_manager.lockRegAssumeUnused(.rdi);

            info.return_value.stack_offset = stack_offset;

            break :blk rdi_lock;
        }
        break :blk null;
    };
    defer if (rdi_lock) |lock| self.register_manager.unlockReg(lock);

    for (args) |arg, arg_i| {
        const mc_arg = info.args[arg_i];
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(args[arg_i]);
        // Here we do not use setRegOrMem even though the logic is similar, because
        // the function call will move the stack pointer, so the offsets are different.
        switch (mc_arg) {
            .none => continue,
            .register => |reg| {
                try self.register_manager.getReg(reg, null);
                try self.genSetReg(arg_ty, reg, arg_mcv);
            },
            .stack_offset => |off| {
                // TODO rewrite using `genSetStack`
                try self.genSetStackArg(arg_ty, off, arg_mcv);
            },
            .ptr_stack_offset => {
                return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
            },
            .undef => unreachable,
            .immediate => unreachable,
            .unreach => unreachable,
            .dead => unreachable,
            .memory => unreachable,
            .got_load => unreachable,
            .direct_load => unreachable,
            .eflags => unreachable,
            .register_overflow => unreachable,
        }
    }

    if (info.stack_byte_count > 0) {
        // Adjust the stack
        _ = try self.addInst(.{
            .tag = .sub,
            .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rsp }),
            .data = .{ .imm = info.stack_byte_count },
        });
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    const mod = self.bin_file.options.module.?;
    if (self.bin_file.tag == link.File.Elf.base_tag or self.bin_file.tag == link.File.Coff.base_tag) {
        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const fn_owner_decl = mod.declPtr(func.owner_decl);
                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                    break :blk @intCast(u32, got.p_vaddr + fn_owner_decl.link.elf.offset_table_index * ptr_bytes);
                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                    @intCast(u32, coff_file.offset_table_virtual_address + fn_owner_decl.link.coff.offset_table_index * ptr_bytes)
                else
                    unreachable;
                _ = try self.addInst(.{
                    .tag = .call,
                    .ops = Mir.Inst.Ops.encode(.{ .flags = 0b01 }),
                    .data = .{ .imm = @truncate(u32, got_addr) },
                });
            } else if (func_value.castTag(.extern_fn)) |_| {
                return self.fail("TODO implement calling extern functions", .{});
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else {
            assert(ty.zigTypeTag() == .Pointer);
            const mcv = try self.resolveInst(callee);
            try self.genSetReg(Type.initTag(.usize), .rax, mcv);
            _ = try self.addInst(.{
                .tag = .call,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = .rax,
                    .flags = 0b01,
                }),
                .data = undefined,
            });
        }
    } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;
                const fn_owner_decl = mod.declPtr(func.owner_decl);
                try self.genSetReg(Type.initTag(.usize), .rax, .{
                    .got_load = fn_owner_decl.link.macho.local_sym_index,
                });
                // callq *%rax
                _ = try self.addInst(.{
                    .tag = .call,
                    .ops = Mir.Inst.Ops.encode(.{
                        .reg1 = .rax,
                        .flags = 0b01,
                    }),
                    .data = undefined,
                });
            } else if (func_value.castTag(.extern_fn)) |func_payload| {
                const extern_fn = func_payload.data;
                const decl_name = mod.declPtr(extern_fn.owner_decl).name;
                if (extern_fn.lib_name) |lib_name| {
                    log.debug("TODO enforce that '{s}' is expected in '{s}' library", .{
                        decl_name,
                        lib_name,
                    });
                }
                const n_strx = try macho_file.getGlobalSymbol(mem.sliceTo(decl_name, 0));
                _ = try self.addInst(.{
                    .tag = .call_extern,
                    .ops = undefined,
                    .data = .{
                        .extern_fn = .{
                            .atom_index = mod.declPtr(self.mod_fn.owner_decl).link.macho.local_sym_index,
                            .sym_name = n_strx,
                        },
                    },
                });
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else {
            assert(ty.zigTypeTag() == .Pointer);
            const mcv = try self.resolveInst(callee);
            try self.genSetReg(Type.initTag(.usize), .rax, mcv);
            _ = try self.addInst(.{
                .tag = .call,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = .rax,
                    .flags = 0b01,
                }),
                .data = undefined,
            });
        }
    } else if (self.bin_file.cast(link.File.Plan9)) |p9| {
        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                try p9.seeDecl(func_payload.data.owner_decl);
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const got_addr = p9.bases.data;
                const got_index = mod.declPtr(func_payload.data.owner_decl).link.plan9.got_index.?;
                const fn_got_addr = got_addr + got_index * ptr_bytes;
                _ = try self.addInst(.{
                    .tag = .call,
                    .ops = Mir.Inst.Ops.encode(.{ .flags = 0b01 }),
                    .data = .{ .imm = @intCast(u32, fn_got_addr) },
                });
            } else return self.fail("TODO implement calling extern fn on plan9", .{});
        } else {
            assert(ty.zigTypeTag() == .Pointer);
            const mcv = try self.resolveInst(callee);
            try self.genSetReg(Type.initTag(.usize), .rax, mcv);
            _ = try self.addInst(.{
                .tag = .call,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = .rax,
                    .flags = 0b01,
                }),
                .data = undefined,
            });
        }
    } else unreachable;

    if (info.stack_byte_count > 0) {
        // Readjust the stack
        _ = try self.addInst(.{
            .tag = .add,
            .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rsp }),
            .data = .{ .imm = info.stack_byte_count },
        });
    }

    const result: MCValue = result: {
        switch (info.return_value) {
            .register => {
                // Save function return value in a new register
                break :result try self.copyToRegisterWithInstTracking(
                    inst,
                    self.air.typeOfIndex(inst),
                    info.return_value,
                );
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
        .immediate => {
            assert(ret_ty.isError());
        },
        .stack_offset => {
            const reg = try self.copyToTmpRegister(Type.usize, self.ret_mcv);
            const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
            defer self.register_manager.unlockReg(reg_lock);

            try self.genSetStack(ret_ty, 0, operand, .{
                .source_stack_base = .rbp,
                .dest_stack_base = reg,
            });
        },
        else => {
            try self.setRegOrMem(ret_ty, self.ret_mcv, operand);
        },
    }
    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = undefined },
    });
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ptr = try self.resolveInst(un_op);
    const ptr_ty = self.air.typeOf(un_op);
    const elem_ty = ptr_ty.elemType();
    switch (self.ret_mcv) {
        .immediate => {
            assert(elem_ty.isError());
        },
        .stack_offset => {
            const reg = try self.copyToTmpRegister(Type.usize, self.ret_mcv);
            const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
            defer self.register_manager.unlockReg(reg_lock);

            try self.genInlineMemcpy(.{ .stack_offset = 0 }, ptr, .{ .immediate = elem_ty.abiSize(self.target.*) }, .{
                .source_stack_base = .rbp,
                .dest_stack_base = reg,
            });
        },
        else => {
            try self.load(self.ret_mcv, ptr, ptr_ty);
            try self.setRegOrMem(elem_ty, self.ret_mcv, self.ret_mcv);
        },
    }
    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = undefined },
    });
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOf(bin_op.lhs);
    const signedness: std.builtin.Signedness = blk: {
        // For non-int types, we treat the values as unsigned
        if (ty.zigTypeTag() != .Int) break :blk .unsigned;

        // Otherwise, we take the signedness of the actual int
        break :blk ty.intInfo(self.target.*).signedness;
    };

    try self.spillEflagsIfOccupied();
    self.eflags_inst = inst;

    const result: MCValue = result: {
        // There are 2 operands, destination and source.
        // Either one, but not both, can be a memory operand.
        // Source operand can be an immediate, 8 bits or 32 bits.
        // TODO look into reusing the operand
        const lhs = try self.resolveInst(bin_op.lhs);
        const lhs_lock: ?RegisterLock = switch (lhs) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_reg = try self.copyToTmpRegister(ty, lhs);
        const dst_reg_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_reg_lock);

        const dst_mcv = MCValue{ .register = dst_reg };

        const rhs_ty = self.air.typeOf(bin_op.rhs);
        // This instruction supports only signed 32-bit immediates at most.
        const src_mcv: MCValue = blk: {
            switch (rhs_ty.zigTypeTag()) {
                .Float => {
                    const rhs = try self.resolveInst(bin_op.rhs);
                    const rhs_lock: ?RegisterLock = switch (rhs) {
                        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                        else => null,
                    };
                    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);
                    const src_reg = try self.copyToTmpRegister(rhs_ty, rhs);
                    break :blk MCValue{ .register = src_reg };
                },
                else => break :blk try self.limitImmediateType(bin_op.rhs, i32),
            }
        };
        const src_lock: ?RegisterLock = switch (src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        try self.genBinOpMir(.cmp, ty, dst_mcv, src_mcv);

        break :result switch (signedness) {
            .signed => MCValue{ .eflags = Condition.fromCompareOperatorSigned(op) },
            .unsigned => MCValue{ .eflags = Condition.fromCompareOperatorUnsigned(op) },
        };
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = self.air.typeOf(pl_op.operand);
    const err_union = try self.resolveInst(pl_op.operand);
    const result = try self.genTry(inst, err_union, body, err_union_ty, false);
    return self.finishAir(inst, result, .{ pl_op.operand, .none, .none });
}

fn airTryPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = self.air.typeOf(extra.data.ptr).childType();
    const err_union_ptr = try self.resolveInst(extra.data.ptr);
    const result = try self.genTry(inst, err_union_ptr, body, err_union_ty, true);
    return self.finishAir(inst, result, .{ extra.data.ptr, .none, .none });
}

fn genTry(
    self: *Self,
    inst: Air.Inst.Index,
    err_union: MCValue,
    body: []const Air.Inst.Index,
    err_union_ty: Type,
    operand_is_ptr: bool,
) !MCValue {
    if (operand_is_ptr) {
        return self.fail("TODO genTry for pointers", .{});
    }
    const is_err_mcv = try self.isErr(null, err_union_ty, err_union);
    const reloc = try self.genCondBrMir(Type.anyerror, is_err_mcv);
    try self.genBody(body);
    try self.performReloc(reloc);
    const result = try self.genUnwrapErrorUnionPayloadMir(inst, err_union_ty, err_union);
    return result;
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
    const payload = try self.addExtra(Mir.DbgLineColumn{
        .line = dbg_stmt.line,
        .column = dbg_stmt.column,
    });
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .ops = undefined,
        .data = .{ .payload = payload },
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
    const operand = pl_op.operand;
    const ty = self.air.typeOf(operand);
    const mcv = try self.resolveInst(operand);

    log.debug("airDbgVar: %{d}: {}, {}", .{ inst, ty.fmtDebug(), mcv });

    const name = self.air.nullTerminatedString(pl_op.payload);

    const tag = self.air.instructions.items(.tag)[inst];
    switch (tag) {
        .dbg_var_ptr => try self.genVarDbgInfo(tag, ty.childType(), mcv, name),
        .dbg_var_val => try self.genVarDbgInfo(tag, ty, mcv, name),
        else => unreachable,
    }

    return self.finishAir(inst, .dead, .{ operand, .none, .none });
}

fn genVarDbgInfo(
    self: *Self,
    tag: Air.Inst.Tag,
    ty: Type,
    mcv: MCValue,
    name: [:0]const u8,
) !void {
    const name_with_null = name.ptr[0 .. name.len + 1];
    switch (self.debug_output) {
        .dwarf => |dw| {
            const dbg_info = &dw.dbg_info;
            try dbg_info.append(@enumToInt(link.File.Dwarf.AbbrevKind.variable));

            switch (mcv) {
                .register => |reg| {
                    try dbg_info.ensureUnusedCapacity(2);
                    dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1, // ULEB128 dwarf expression length
                        reg.dwarfLocOp(),
                    });
                },
                .ptr_stack_offset, .stack_offset => |off| {
                    try dbg_info.ensureUnusedCapacity(7);
                    const fixup = dbg_info.items.len;
                    dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1, // we will backpatch it after we encode the displacement in LEB128
                        DW.OP.breg6, // .rbp TODO handle -fomit-frame-pointer
                    });
                    leb128.writeILEB128(dbg_info.writer(), -off) catch unreachable;
                    dbg_info.items[fixup] += @intCast(u8, dbg_info.items.len - fixup - 2);
                },
                .memory, .got_load, .direct_load => {
                    const endian = self.target.cpu.arch.endian();
                    const ptr_width = @intCast(u8, @divExact(self.target.cpu.arch.ptrBitWidth(), 8));
                    const is_ptr = switch (tag) {
                        .dbg_var_ptr => true,
                        .dbg_var_val => false,
                        else => unreachable,
                    };
                    try dbg_info.ensureUnusedCapacity(2 + ptr_width);
                    dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1 + ptr_width + @boolToInt(is_ptr),
                        DW.OP.addr, // literal address
                    });
                    const offset = @intCast(u32, dbg_info.items.len);
                    const addr = switch (mcv) {
                        .memory => |addr| addr,
                        else => 0,
                    };
                    switch (ptr_width) {
                        0...4 => {
                            try dbg_info.writer().writeInt(u32, @intCast(u32, addr), endian);
                        },
                        5...8 => {
                            try dbg_info.writer().writeInt(u64, addr, endian);
                        },
                        else => unreachable,
                    }
                    if (is_ptr) {
                        // We need deref the address as we point to the value via GOT entry.
                        try dbg_info.append(DW.OP.deref);
                    }
                    switch (mcv) {
                        .got_load, .direct_load => |index| try dw.addExprlocReloc(index, offset, is_ptr),
                        else => {},
                    }
                },
                else => {
                    log.debug("TODO generate debug info for {}", .{mcv});
                },
            }

            try dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
            try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
            dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
        },
        .plan9 => {},
        .none => {},
    }
}

/// Adds a Type to the .debug_info at the current position. The bytes will be populated later,
/// after codegen for this symbol is done.
fn addDbgInfoTypeReloc(self: *Self, ty: Type) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            const dbg_info = &dw.dbg_info;
            const index = dbg_info.items.len;
            try dbg_info.resize(index + 4); // DW.AT.type,  DW.FORM.ref4
            const mod = self.bin_file.options.module.?;
            const fn_owner_decl = mod.declPtr(self.mod_fn.owner_decl);
            const atom = switch (self.bin_file.tag) {
                .elf => &fn_owner_decl.link.elf.dbg_info_atom,
                .macho => &fn_owner_decl.link.macho.dbg_info_atom,
                else => unreachable,
            };
            try dw.addTypeRelocGlobal(atom, ty, @intCast(u32, index));
        },
        .plan9 => {},
        .none => {},
    }
}

fn genCondBrMir(self: *Self, ty: Type, mcv: MCValue) !u32 {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .eflags => |cc| {
            return self.addInst(.{
                .tag = .cond_jmp,
                .ops = Mir.Inst.Ops.encode(.{}),
                .data = .{
                    .inst_cc = .{
                        .inst = undefined,
                        // Here we map the opposites since the jump is to the false branch.
                        .cc = cc.negate(),
                    },
                },
            });
        },
        .register => |reg| {
            try self.spillEflagsIfOccupied();
            _ = try self.addInst(.{
                .tag = .@"test",
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = reg }),
                .data = .{ .imm = 1 },
            });
            return self.addInst(.{
                .tag = .cond_jmp,
                .ops = Mir.Inst.Ops.encode(.{}),
                .data = .{ .inst_cc = .{
                    .inst = undefined,
                    .cc = .e,
                } },
            });
        },
        .immediate,
        .stack_offset,
        => {
            try self.spillEflagsIfOccupied();
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genCondBrMir(ty, .{ .register = reg });
            }
            return self.fail("TODO implement condbr when condition is {} with abi larger than 8 bytes", .{mcv});
        },
        else => return self.fail("TODO implement condbr when condition is {s}", .{@tagName(mcv)}),
    }
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const cond_ty = self.air.typeOf(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc = try self.genCondBrMir(cond_ty, cond);

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
    const saved_state = try self.captureState();

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

    self.revertState(saved_state);

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
        log.debug("then_value = {}", .{then_value});
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

fn isNull(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    try self.spillEflagsIfOccupied();
    self.eflags_inst = inst;

    const cmp_ty: Type = if (!ty.isPtrLikeOptional()) blk: {
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = ty.optionalChild(&buf);
        break :blk if (payload_ty.hasRuntimeBitsIgnoreComptime()) Type.bool else ty;
    } else ty;

    try self.genBinOpMir(.cmp, cmp_ty, operand, MCValue{ .immediate = 0 });

    return MCValue{ .eflags = .e };
}

fn isNonNull(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const is_null_res = try self.isNull(inst, ty, operand);
    assert(is_null_res.eflags == .e);
    return MCValue{ .eflags = is_null_res.eflags.negate() };
}

fn isErr(self: *Self, maybe_inst: ?Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const err_type = ty.errorUnionSet();

    if (err_type.errorSetIsEmpty()) {
        return MCValue{ .immediate = 0 }; // always false
    }

    try self.spillEflagsIfOccupied();
    if (maybe_inst) |inst| {
        self.eflags_inst = inst;
    }

    const err_off = errUnionErrorOffset(ty.errorUnionPayload(), self.target.*);
    switch (operand) {
        .stack_offset => |off| {
            const offset = off - @intCast(i32, err_off);
            try self.genBinOpMir(.cmp, Type.anyerror, .{ .stack_offset = offset }, .{ .immediate = 0 });
        },
        .register => |reg| {
            const maybe_lock = self.register_manager.lockReg(reg);
            defer if (maybe_lock) |lock| self.register_manager.unlockReg(lock);
            const tmp_reg = try self.copyToTmpRegister(ty, operand);
            if (err_off > 0) {
                const shift = @intCast(u6, err_off * 8);
                try self.genShiftBinOpMir(.shr, ty, tmp_reg, .{ .immediate = shift });
            } else {
                try self.truncateRegister(Type.anyerror, tmp_reg);
            }
            try self.genBinOpMir(.cmp, Type.anyerror, .{ .register = tmp_reg }, .{ .immediate = 0 });
        },
        else => return self.fail("TODO implement isErr for {}", .{operand}),
    }

    return MCValue{ .eflags = .a };
}

fn isNonErr(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const is_err_res = try self.isErr(inst, ty, operand);
    switch (is_err_res) {
        .eflags => |cc| {
            assert(cc == .a);
            return MCValue{ .eflags = cc.negate() };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNull(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ un_op, .none, .none });
    }

    const operand_ptr = try self.resolveInst(un_op);
    const operand_ptr_lock: ?RegisterLock = switch (operand_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const operand: MCValue = blk: {
        if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
            // The MCValue that holds the pointer can be re-used as the value.
            break :blk operand_ptr;
        } else {
            break :blk try self.allocRegOrMem(inst, true);
        }
    };
    const ptr_ty = self.air.typeOf(un_op);
    try self.load(operand, operand_ptr, ptr_ty);

    const result = try self.isNull(inst, ptr_ty.elemType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNonNull(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ un_op, .none, .none });
    }

    const operand_ptr = try self.resolveInst(un_op);
    const operand_ptr_lock: ?RegisterLock = switch (operand_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const operand: MCValue = blk: {
        if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
            // The MCValue that holds the pointer can be re-used as the value.
            break :blk operand_ptr;
        } else {
            break :blk try self.allocRegOrMem(inst, true);
        }
    };
    const ptr_ty = self.air.typeOf(un_op);
    try self.load(operand, operand_ptr, ptr_ty);

    const result = try self.isNonNull(inst, ptr_ty.elemType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isErr(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ un_op, .none, .none });
    }

    const operand_ptr = try self.resolveInst(un_op);
    const operand_ptr_lock: ?RegisterLock = switch (operand_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const operand: MCValue = blk: {
        if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
            // The MCValue that holds the pointer can be re-used as the value.
            break :blk operand_ptr;
        } else {
            break :blk try self.allocRegOrMem(inst, true);
        }
    };
    const ptr_ty = self.air.typeOf(un_op);
    try self.load(operand, operand_ptr, ptr_ty);

    const result = try self.isErr(inst, ptr_ty.elemType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNonErr(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ un_op, .none, .none });
    }

    const operand_ptr = try self.resolveInst(un_op);
    const operand_ptr_lock: ?RegisterLock = switch (operand_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (operand_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const operand: MCValue = blk: {
        if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
            // The MCValue that holds the pointer can be re-used as the value.
            break :blk operand_ptr;
        } else {
            break :blk try self.allocRegOrMem(inst, true);
        }
    };
    const ptr_ty = self.air.typeOf(un_op);
    try self.load(operand, operand_ptr, ptr_ty);

    const result = try self.isNonErr(inst, ptr_ty.elemType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[loop.end..][0..loop.data.body_len];
    const jmp_target = @intCast(u32, self.mir_instructions.len);
    try self.genBody(body);
    _ = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = jmp_target },
    });
    return self.finishAirBookkeeping();
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

fn genCondSwitchMir(self: *Self, ty: Type, condition: MCValue, case: MCValue) !u32 {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (condition) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach => unreachable,
        .eflags => unreachable,
        .register => |cond_reg| {
            try self.spillEflagsIfOccupied();

            const cond_reg_lock = self.register_manager.lockReg(cond_reg);
            defer if (cond_reg_lock) |lock| self.register_manager.unlockReg(lock);

            switch (case) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .immediate => |imm| {
                    _ = try self.addInst(.{
                        .tag = .xor,
                        .ops = Mir.Inst.Ops.encode(.{ .reg1 = registerAlias(cond_reg, abi_size) }),
                        .data = .{ .imm = @intCast(u32, imm) },
                    });
                },
                .register => |reg| {
                    _ = try self.addInst(.{
                        .tag = .xor,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(cond_reg, abi_size),
                            .reg2 = registerAlias(reg, abi_size),
                        }),
                        .data = undefined,
                    });
                },
                .stack_offset => {
                    if (abi_size <= 8) {
                        const reg = try self.copyToTmpRegister(ty, case);
                        return self.genCondSwitchMir(ty, condition, .{ .register = reg });
                    }

                    return self.fail("TODO implement switch mir when case is stack offset with abi larger than 8 bytes", .{});
                },
                else => {
                    return self.fail("TODO implement switch mir when case is {}", .{case});
                },
            }

            _ = try self.addInst(.{
                .tag = .@"test",
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(cond_reg, abi_size),
                    .reg2 = registerAlias(cond_reg, abi_size),
                }),
                .data = undefined,
            });
            return self.addInst(.{
                .tag = .cond_jmp,
                .ops = Mir.Inst.Ops.encode(.{}),
                .data = .{ .inst_cc = .{
                    .inst = undefined,
                    .cc = .ne,
                } },
            });
        },
        .stack_offset => {
            try self.spillEflagsIfOccupied();

            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, condition);
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);
                return self.genCondSwitchMir(ty, .{ .register = reg }, case);
            }

            return self.fail("TODO implement switch mir when condition is stack offset with abi larger than 8 bytes", .{});
        },
        else => {
            return self.fail("TODO implemenent switch mir when condition is {}", .{condition});
        },
    }
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition = try self.resolveInst(pl_op.operand);
    const condition_ty = self.air.typeOf(pl_op.operand);
    const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
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

    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;

        var relocs = try self.gpa.alloc(u32, items.len);
        defer self.gpa.free(relocs);

        for (items) |item, item_i| {
            const item_mcv = try self.resolveInst(item);
            relocs[item_i] = try self.genCondSwitchMir(condition_ty, condition, item_mcv);
        }

        // Capture the state of register and stack allocation state so that we can revert to it.
        const saved_state = try self.captureState();

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

        self.revertState(saved_state);

        for (relocs) |reloc| {
            try self.performReloc(reloc);
        }
    }

    if (switch_br.data.else_body_len > 0) {
        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];
        try self.branch_stack.append(.{});
        defer {
            var item = self.branch_stack.pop();
            item.deinit(self.gpa);
        }

        const else_deaths = liveness.deaths.len - 1;
        try self.ensureProcessDeathCapacity(liveness.deaths[else_deaths].len);
        for (liveness.deaths[else_deaths]) |operand| {
            self.processDeath(operand);
        }

        try self.genBody(else_body);

        // TODO consolidate returned MCValues between prongs and else branch like we do
        // in airCondBr.
    }

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn performReloc(self: *Self, reloc: Mir.Inst.Index) !void {
    const next_inst = @intCast(u32, self.mir_instructions.len);
    switch (self.mir_instructions.items(.tag)[reloc]) {
        .cond_jmp => {
            self.mir_instructions.items(.data)[reloc].inst_cc.inst = next_inst;
        },
        .jmp => {
            self.mir_instructions.items(.data)[reloc].inst = next_inst;
        },
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
                .eflags, .immediate => blk: {
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
    try block_data.relocs.ensureUnusedCapacity(self.gpa, 1);
    // Leave the jump offset undefined
    const jmp_reloc = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = undefined },
    });
    block_data.relocs.appendAssumeCapacity(jmp_reloc);
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

        {
            var iter = std.mem.tokenize(u8, asm_source, "\n\r");
            while (iter.next()) |ins| {
                if (mem.eql(u8, ins, "syscall")) {
                    _ = try self.addInst(.{
                        .tag = .syscall,
                        .ops = undefined,
                        .data = undefined,
                    });
                } else if (mem.indexOf(u8, ins, "push")) |_| {
                    const arg = ins[4..];
                    if (mem.indexOf(u8, arg, "$")) |l| {
                        const n = std.fmt.parseInt(u8, ins[4 + l + 1 ..], 10) catch {
                            return self.fail("TODO implement more inline asm int parsing", .{});
                        };
                        _ = try self.addInst(.{
                            .tag = .push,
                            .ops = Mir.Inst.Ops.encode(.{ .flags = 0b10 }),
                            .data = .{ .imm = n },
                        });
                    } else if (mem.indexOf(u8, arg, "%%")) |l| {
                        const reg_name = ins[4 + l + 2 ..];
                        const reg = parseRegName(reg_name) orelse
                            return self.fail("unrecognized register: '{s}'", .{reg_name});
                        _ = try self.addInst(.{
                            .tag = .push,
                            .ops = Mir.Inst.Ops.encode(.{ .reg1 = reg }),
                            .data = undefined,
                        });
                    } else return self.fail("TODO more push operands", .{});
                } else if (mem.indexOf(u8, ins, "pop")) |_| {
                    const arg = ins[3..];
                    if (mem.indexOf(u8, arg, "%%")) |l| {
                        const reg_name = ins[3 + l + 2 ..];
                        const reg = parseRegName(reg_name) orelse
                            return self.fail("unrecognized register: '{s}'", .{reg_name});
                        _ = try self.addInst(.{
                            .tag = .pop,
                            .ops = Mir.Inst.Ops.encode(.{ .reg1 = reg }),
                            .data = undefined,
                        });
                    } else return self.fail("TODO more pop operands", .{});
                } else {
                    return self.fail("TODO implement support for more x86 assembly instructions", .{});
                }
            }
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
        .immediate => unreachable,
        .register => |reg| return self.genSetReg(ty, reg, val),
        .stack_offset => |off| return self.genSetStack(ty, off, val, .{}),
        .memory => {
            return self.fail("TODO implement setRegOrMem for memory", .{});
        },
        else => {
            return self.fail("TODO implement setRegOrMem for {}", .{loc});
        },
    }
}

fn genSetStackArg(self: *Self, ty: Type, stack_offset: i32, mcv: MCValue) InnerError!void {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return,
        .undef => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }
            try self.genInlineMemset(
                .{ .stack_offset = stack_offset },
                .{ .immediate = 0xaa },
                .{ .immediate = abi_size },
                .{ .dest_stack_base = .rsp },
            );
        },
        .register_overflow => return self.fail("TODO genSetStackArg for register with overflow bit", .{}),
        .eflags => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStackArg(ty, stack_offset, .{ .register = reg });
        },
        .immediate => |imm| {
            switch (abi_size) {
                1, 2, 4 => {
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    // mov [rbp+offset], immediate
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -stack_offset),
                        .operand = @truncate(u32, imm),
                    });
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = .rsp,
                            .flags = switch (abi_size) {
                                1 => 0b00,
                                2 => 0b01,
                                4 => 0b10,
                                else => unreachable,
                            },
                        }),
                        .data = .{ .payload = payload },
                    });
                },
                8 => {
                    const reg = try self.copyToTmpRegister(ty, mcv);
                    return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
                },
                else => return self.fail("TODO implement inputs on stack for {} with abi size > 8", .{mcv}),
            }
        },
        .memory,
        .direct_load,
        .got_load,
        => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }

            try self.genInlineMemcpy(.{ .stack_offset = stack_offset }, mcv, .{ .immediate = abi_size }, .{
                .source_stack_base = .rbp,
                .dest_stack_base = .rsp,
            });
        },
        .register => |reg| {
            switch (ty.zigTypeTag()) {
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f32_avx
                            else
                                Mir.Inst.Tag.mov_f32_sse,
                            .f64 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f64_avx
                            else
                                Mir.Inst.Tag.mov_f64_sse,
                            else => return self.fail("TODO genSetStackArg for register for type {}", .{ty.fmtDebug()}),
                        };
                        _ = try self.addInst(.{
                            .tag = tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = switch (ty.tag()) {
                                    .f32 => .esp,
                                    .f64 => .rsp,
                                    else => unreachable,
                                },
                                .reg2 = reg.to128(),
                                .flags = 0b01,
                            }),
                            .data = .{ .imm = @bitCast(u32, -stack_offset) },
                        });
                        return;
                    }

                    return self.fail("TODO genSetStackArg for register with no intrinsics", .{});
                },
                else => {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = .rsp,
                            .reg2 = registerAlias(reg, @intCast(u32, abi_size)),
                            .flags = 0b10,
                        }),
                        .data = .{ .imm = @bitCast(u32, -stack_offset) },
                    });
                },
            }
        },
        .ptr_stack_offset => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
        },
        .stack_offset => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }

            try self.genInlineMemcpy(.{ .stack_offset = stack_offset }, mcv, .{ .immediate = abi_size }, .{
                .source_stack_base = .rbp,
                .dest_stack_base = .rsp,
            });
        },
    }
}

fn genSetStack(self: *Self, ty: Type, stack_offset: i32, mcv: MCValue, opts: InlineMemcpyOpts) InnerError!void {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (ty.abiSize(self.target.*)) {
                1 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaa }, opts),
                2 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaa }, opts),
                4 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }, opts),
                8 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }, opts),
                else => |x| return self.genInlineMemset(
                    .{ .stack_offset = stack_offset },
                    .{ .immediate = 0xaa },
                    .{ .immediate = x },
                    opts,
                ),
            }
        },
        .register_overflow => |ro| {
            const reg_lock = self.register_manager.lockReg(ro.reg);
            defer if (reg_lock) |lock| self.register_manager.unlockReg(lock);

            const wrapped_ty = ty.structFieldType(0);
            try self.genSetStack(wrapped_ty, stack_offset, .{ .register = ro.reg }, .{});

            const overflow_bit_ty = ty.structFieldType(1);
            const overflow_bit_offset = ty.structFieldOffset(1, self.target.*);
            const tmp_reg = try self.register_manager.allocReg(null, gp);
            _ = try self.addInst(.{
                .tag = .cond_set_byte,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = tmp_reg.to8(),
                }),
                .data = .{ .cc = ro.eflags },
            });

            return self.genSetStack(
                overflow_bit_ty,
                stack_offset - @intCast(i32, overflow_bit_offset),
                .{ .register = tmp_reg.to8() },
                .{},
            );
        },
        .eflags => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, .{ .register = reg }, opts);
        },
        .immediate => |x_big| {
            const base_reg = opts.dest_stack_base orelse .rbp;
            switch (abi_size) {
                0 => {
                    assert(ty.isError());
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -stack_offset),
                        .operand = @truncate(u32, x_big),
                    });
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = base_reg,
                            .flags = 0b00,
                        }),
                        .data = .{ .payload = payload },
                    });
                },
                1, 2, 4 => {
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -stack_offset),
                        .operand = @truncate(u32, x_big),
                    });
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = base_reg,
                            .flags = switch (abi_size) {
                                1 => 0b00,
                                2 => 0b01,
                                4 => 0b10,
                                else => unreachable,
                            },
                        }),
                        .data = .{ .payload = payload },
                    });
                },
                8 => {
                    // 64 bit write to memory would take two mov's anyways so we
                    // insted just use two 32 bit writes to avoid register allocation
                    {
                        const payload = try self.addExtra(Mir.ImmPair{
                            .dest_off = @bitCast(u32, -stack_offset + 4),
                            .operand = @truncate(u32, x_big >> 32),
                        });
                        _ = try self.addInst(.{
                            .tag = .mov_mem_imm,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = base_reg,
                                .flags = 0b10,
                            }),
                            .data = .{ .payload = payload },
                        });
                    }
                    {
                        const payload = try self.addExtra(Mir.ImmPair{
                            .dest_off = @bitCast(u32, -stack_offset),
                            .operand = @truncate(u32, x_big),
                        });
                        _ = try self.addInst(.{
                            .tag = .mov_mem_imm,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = base_reg,
                                .flags = 0b10,
                            }),
                            .data = .{ .payload = payload },
                        });
                    }
                },
                else => {
                    return self.fail("TODO implement set abi_size=large stack variable with immediate", .{});
                },
            }
        },
        .register => |reg| {
            if (stack_offset > math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }

            const base_reg = opts.dest_stack_base orelse .rbp;

            switch (ty.zigTypeTag()) {
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f32_avx
                            else
                                Mir.Inst.Tag.mov_f32_sse,
                            .f64 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f64_avx
                            else
                                Mir.Inst.Tag.mov_f64_sse,
                            else => return self.fail("TODO genSetStack for register for type {}", .{ty.fmtDebug()}),
                        };
                        _ = try self.addInst(.{
                            .tag = tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = switch (ty.tag()) {
                                    .f32 => base_reg.to32(),
                                    .f64 => base_reg.to64(),
                                    else => unreachable,
                                },
                                .reg2 = reg.to128(),
                                .flags = 0b01,
                            }),
                            .data = .{ .imm = @bitCast(u32, -stack_offset) },
                        });
                        return;
                    }

                    return self.fail("TODO genSetStack for register for type float with no intrinsics", .{});
                },
                else => {
                    try self.genInlineMemcpyRegisterRegister(ty, base_reg, reg, stack_offset);
                },
            }
        },
        .memory,
        .got_load,
        .direct_load,
        => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg }, opts);
            }

            try self.genInlineMemcpy(.{ .stack_offset = stack_offset }, mcv, .{ .immediate = abi_size }, opts);
        },
        .ptr_stack_offset => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg }, opts);
        },
        .stack_offset => |off| {
            if (stack_offset == off) {
                // Copy stack variable to itself; nothing to do.
                return;
            }

            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg }, opts);
            }

            try self.genInlineMemcpy(.{ .stack_offset = stack_offset }, mcv, .{ .immediate = abi_size }, opts);
        },
    }
}

/// Like `genInlineMemcpy` but copies value from a register to an address via dereferencing
/// of destination register.
/// Boils down to MOV r/m64, r64.
fn genInlineMemcpyRegisterRegister(
    self: *Self,
    ty: Type,
    dst_reg: Register,
    src_reg: Register,
    offset: i32,
) InnerError!void {
    assert(dst_reg.size() == 64);

    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

    const src_reg_lock = self.register_manager.lockReg(src_reg);
    defer if (src_reg_lock) |lock| self.register_manager.unlockReg(lock);

    const abi_size = @intCast(u32, ty.abiSize(self.target.*));

    if (!math.isPowerOfTwo(abi_size)) {
        const tmp_reg = try self.copyToTmpRegister(ty, .{ .register = src_reg });

        var next_offset = offset;
        var remainder = abi_size;
        while (remainder > 0) {
            const nearest_power_of_two = @as(u6, 1) << math.log2_int(u3, @intCast(u3, remainder));

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = dst_reg,
                    .reg2 = registerAlias(tmp_reg, nearest_power_of_two),
                    .flags = 0b10,
                }),
                .data = .{ .imm = @bitCast(u32, -next_offset) },
            });

            if (nearest_power_of_two > 1) {
                try self.genShiftBinOpMir(.shr, ty, tmp_reg, .{
                    .immediate = nearest_power_of_two * 8,
                });
            }

            remainder -= nearest_power_of_two;
            next_offset -= nearest_power_of_two;
        }
    } else {
        _ = try self.addInst(.{
            .tag = .mov,
            .ops = Mir.Inst.Ops.encode(.{
                .reg1 = dst_reg,
                .reg2 = registerAlias(src_reg, @intCast(u32, abi_size)),
                .flags = 0b10,
            }),
            .data = .{ .imm = @bitCast(u32, -offset) },
        });
    }
}

const InlineMemcpyOpts = struct {
    source_stack_base: ?Register = null,
    dest_stack_base: ?Register = null,
};

/// Spills .rax and .rcx.
fn genInlineMemcpy(
    self: *Self,
    dst_ptr: MCValue,
    src_ptr: MCValue,
    len: MCValue,
    opts: InlineMemcpyOpts,
) InnerError!void {
    // TODO preserve contents of .rax and .rcx if not free, and then restore
    try self.register_manager.getReg(.rax, null);
    try self.register_manager.getReg(.rcx, null);

    const reg_locks = self.register_manager.lockRegsAssumeUnused(2, .{ .rax, .rcx });
    defer for (reg_locks) |lock| {
        self.register_manager.unlockReg(lock);
    };

    const ssbase_lock: ?RegisterLock = if (opts.source_stack_base) |reg|
        self.register_manager.lockReg(reg)
    else
        null;
    defer if (ssbase_lock) |reg| self.register_manager.unlockReg(reg);

    const dsbase_lock: ?RegisterLock = if (opts.dest_stack_base) |reg|
        self.register_manager.lockReg(reg)
    else
        null;
    defer if (dsbase_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_addr_reg = try self.register_manager.allocReg(null, gp);
    switch (dst_ptr) {
        .memory,
        .got_load,
        .direct_load,
        => {
            try self.loadMemPtrIntoRegister(dst_addr_reg, Type.usize, dst_ptr);
        },
        .ptr_stack_offset, .stack_offset => |off| {
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = dst_addr_reg.to64(),
                    .reg2 = opts.dest_stack_base orelse .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(dst_addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when dest is {}", .{dst_ptr});
        },
    }
    const dst_addr_reg_lock = self.register_manager.lockRegAssumeUnused(dst_addr_reg);
    defer self.register_manager.unlockReg(dst_addr_reg_lock);

    const src_addr_reg = try self.register_manager.allocReg(null, gp);
    switch (src_ptr) {
        .memory,
        .got_load,
        .direct_load,
        => {
            try self.loadMemPtrIntoRegister(src_addr_reg, Type.usize, src_ptr);
        },
        .ptr_stack_offset, .stack_offset => |off| {
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = src_addr_reg.to64(),
                    .reg2 = opts.source_stack_base orelse .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(src_addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when src is {}", .{src_ptr});
        },
    }
    const src_addr_reg_lock = self.register_manager.lockRegAssumeUnused(src_addr_reg);
    defer self.register_manager.unlockReg(src_addr_reg_lock);

    const regs = try self.register_manager.allocRegs(2, .{ null, null }, gp);
    const count_reg = regs[0].to64();
    const tmp_reg = regs[1].to8();

    try self.genSetReg(Type.usize, count_reg, len);

    // mov rcx, 0
    _ = try self.addInst(.{
        .tag = .mov,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rcx }),
        .data = .{ .imm = 0 },
    });

    // mov rax, 0
    _ = try self.addInst(.{
        .tag = .mov,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rax }),
        .data = .{ .imm = 0 },
    });

    // loop:
    // cmp count, 0
    const loop_start = try self.addInst(.{
        .tag = .cmp,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = count_reg }),
        .data = .{ .imm = 0 },
    });

    // je end
    const loop_reloc = try self.addInst(.{
        .tag = .cond_jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst_cc = .{
            .inst = undefined,
            .cc = .e,
        } },
    });

    // mov tmp, [addr + rcx]
    _ = try self.addInst(.{
        .tag = .mov_scale_src,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = tmp_reg.to8(),
            .reg2 = src_addr_reg,
        }),
        .data = .{ .imm = 0 },
    });

    // mov [stack_offset + rax], tmp
    _ = try self.addInst(.{
        .tag = .mov_scale_dst,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = dst_addr_reg,
            .reg2 = tmp_reg.to8(),
        }),
        .data = .{ .imm = 0 },
    });

    // add rcx, 1
    _ = try self.addInst(.{
        .tag = .add,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rcx }),
        .data = .{ .imm = 1 },
    });

    // add rax, 1
    _ = try self.addInst(.{
        .tag = .add,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rax }),
        .data = .{ .imm = 1 },
    });

    // sub count, 1
    _ = try self.addInst(.{
        .tag = .sub,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = count_reg }),
        .data = .{ .imm = 1 },
    });

    // jmp loop
    _ = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = loop_start },
    });

    // end:
    try self.performReloc(loop_reloc);
}

/// Spills .rax register.
fn genInlineMemset(
    self: *Self,
    dst_ptr: MCValue,
    value: MCValue,
    len: MCValue,
    opts: InlineMemcpyOpts,
) InnerError!void {
    // TODO preserve contents of .rax and then restore
    try self.register_manager.getReg(.rax, null);
    const rax_lock = self.register_manager.lockRegAssumeUnused(.rax);
    defer self.register_manager.unlockReg(rax_lock);

    const addr_reg = try self.register_manager.allocReg(null, gp);
    switch (dst_ptr) {
        .memory,
        .got_load,
        .direct_load,
        => {
            try self.loadMemPtrIntoRegister(addr_reg, Type.usize, dst_ptr);
        },
        .ptr_stack_offset, .stack_offset => |off| {
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = addr_reg.to64(),
                    .reg2 = opts.dest_stack_base orelse .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when dest is {}", .{dst_ptr});
        },
    }
    const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
    defer self.register_manager.unlockReg(addr_reg_lock);

    try self.genSetReg(Type.usize, .rax, len);
    try self.genBinOpMir(.sub, Type.usize, .{ .register = .rax }, .{ .immediate = 1 });

    // loop:
    // cmp rax, -1
    const loop_start = try self.addInst(.{
        .tag = .cmp,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rax }),
        .data = .{ .imm = @bitCast(u32, @as(i32, -1)) },
    });

    // je end
    const loop_reloc = try self.addInst(.{
        .tag = .cond_jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst_cc = .{
            .inst = undefined,
            .cc = .e,
        } },
    });

    switch (value) {
        .immediate => |x| {
            if (x > math.maxInt(i32)) {
                return self.fail("TODO inline memset for value immediate larger than 32bits", .{});
            }
            // mov byte ptr [rbp + rax + stack_offset], imm
            const payload = try self.addExtra(Mir.ImmPair{
                .dest_off = 0,
                .operand = @truncate(u32, x),
            });
            _ = try self.addInst(.{
                .tag = .mov_mem_index_imm,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = addr_reg }),
                .data = .{ .payload = payload },
            });
        },
        else => return self.fail("TODO inline memset for value of type {}", .{value}),
    }

    // sub rax, 1
    _ = try self.addInst(.{
        .tag = .sub,
        .ops = Mir.Inst.Ops.encode(.{ .reg1 = .rax }),
        .data = .{ .imm = 1 },
    });

    // jmp loop
    _ = try self.addInst(.{
        .tag = .jmp,
        .ops = Mir.Inst.Ops.encode(.{}),
        .data = .{ .inst = loop_start },
    });

    // end:
    try self.performReloc(loop_reloc);
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .register_overflow => unreachable,
        .ptr_stack_offset => |off| {
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = .rbp,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            switch (registerAlias(reg, abi_size).size()) {
                8 => return self.genSetReg(ty, reg, .{ .immediate = 0xaa }),
                16 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaa }),
                32 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaa }),
                64 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => unreachable,
            }
        },
        .eflags => |cc| {
            _ = try self.addInst(.{
                .tag = .cond_set_byte,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = reg.to8(),
                }),
                .data = .{ .cc = cc },
            });
        },
        .immediate => |x| {
            // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
            // register is the fastest way to zero a register.
            if (x == 0) {
                _ = try self.addInst(.{
                    .tag = .xor,
                    .ops = Mir.Inst.Ops.encode(.{
                        .reg1 = reg.to32(),
                        .reg2 = reg.to32(),
                    }),
                    .data = undefined,
                });
                return;
            }
            if (x <= math.maxInt(i32)) {
                // Next best case: if we set the lower four bytes, the upper four will be zeroed.
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = Mir.Inst.Ops.encode(.{ .reg1 = registerAlias(reg, abi_size) }),
                    .data = .{ .imm = @truncate(u32, x) },
                });
                return;
            }
            // Worst case: we need to load the 64-bit register with the IMM. GNU's assemblers calls
            // this `movabs`, though this is officially just a different variant of the plain `mov`
            // instruction.
            //
            // This encoding is, in fact, the *same* as the one used for 32-bit loads. The only
            // difference is that we set REX.W before the instruction, which extends the load to
            // 64-bit and uses the full bit-width of the register.
            const payload = try self.addExtra(Mir.Imm64.encode(x));
            _ = try self.addInst(.{
                .tag = .movabs,
                .ops = Mir.Inst.Ops.encode(.{ .reg1 = reg.to64() }),
                .data = .{ .payload = payload },
            });
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            switch (ty.zigTypeTag()) {
                .Int => switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        if (abi_size <= 4) {
                            _ = try self.addInst(.{
                                .tag = .mov_sign_extend,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = reg.to64(),
                                    .reg2 = registerAlias(src_reg, abi_size),
                                }),
                                .data = undefined,
                            });
                            return;
                        }
                    },
                    .unsigned => {
                        if (abi_size <= 2) {
                            _ = try self.addInst(.{
                                .tag = .mov_zero_extend,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = reg.to64(),
                                    .reg2 = registerAlias(src_reg, abi_size),
                                }),
                                .data = undefined,
                            });
                            return;
                        }
                    },
                },
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f32_avx
                            else
                                Mir.Inst.Tag.mov_f32_sse,
                            .f64 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f64_avx
                            else
                                Mir.Inst.Tag.mov_f64_sse,
                            else => return self.fail("TODO genSetReg from register for {}", .{ty.fmtDebug()}),
                        };
                        _ = try self.addInst(.{
                            .tag = tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = reg.to128(),
                                .reg2 = src_reg.to128(),
                                .flags = 0b10,
                            }),
                            .data = undefined,
                        });
                        return;
                    }

                    return self.fail("TODO genSetReg from register for float with no intrinsics", .{});
                },
                else => {},
            }

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = registerAlias(src_reg, abi_size),
                }),
                .data = undefined,
            });
        },
        .direct_load,
        .got_load,
        => {
            switch (ty.zigTypeTag()) {
                .Float => {
                    const base_reg = try self.register_manager.allocReg(null, gp);
                    try self.loadMemPtrIntoRegister(base_reg, Type.usize, mcv);

                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f32_avx
                            else
                                Mir.Inst.Tag.mov_f32_sse,
                            .f64 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f64_avx
                            else
                                Mir.Inst.Tag.mov_f64_sse,
                            else => return self.fail("TODO genSetReg from memory for {}", .{ty.fmtDebug()}),
                        };

                        _ = try self.addInst(.{
                            .tag = tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = reg.to128(),
                                .reg2 = switch (ty.tag()) {
                                    .f32 => base_reg.to32(),
                                    .f64 => base_reg.to64(),
                                    else => unreachable,
                                },
                            }),
                            .data = .{ .imm = 0 },
                        });
                        return;
                    }

                    return self.fail("TODO genSetReg from memory for float with no intrinsics", .{});
                },
                else => {
                    try self.loadMemPtrIntoRegister(reg, Type.usize, mcv);
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(reg, abi_size),
                            .reg2 = reg.to64(),
                            .flags = 0b01,
                        }),
                        .data = .{ .imm = 0 },
                    });
                },
            }
        },
        .memory => |x| switch (ty.zigTypeTag()) {
            .Float => {
                const base_reg = try self.register_manager.allocReg(null, gp);
                try self.loadMemPtrIntoRegister(base_reg, Type.usize, mcv);

                if (intrinsicsAllowed(self.target.*, ty)) {
                    const tag: Mir.Inst.Tag = switch (ty.tag()) {
                        .f32 => if (hasAvxSupport(self.target.*))
                            Mir.Inst.Tag.mov_f32_avx
                        else
                            Mir.Inst.Tag.mov_f32_sse,
                        .f64 => if (hasAvxSupport(self.target.*))
                            Mir.Inst.Tag.mov_f64_avx
                        else
                            Mir.Inst.Tag.mov_f64_sse,
                        else => return self.fail("TODO genSetReg from memory for {}", .{ty.fmtDebug()}),
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = reg.to128(),
                            .reg2 = switch (ty.tag()) {
                                .f32 => base_reg.to32(),
                                .f64 => base_reg.to64(),
                                else => unreachable,
                            },
                        }),
                        .data = .{ .imm = 0 },
                    });
                    return;
                }

                return self.fail("TODO genSetReg from memory for float with no intrinsics", .{});
            },
            else => {
                if (x <= math.maxInt(i32)) {
                    // mov reg, [ds:imm32]
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = Mir.Inst.Ops.encode(.{
                            .reg1 = registerAlias(reg, abi_size),
                            .flags = 0b01,
                        }),
                        .data = .{ .imm = @truncate(u32, x) },
                    });
                } else {
                    // If this is RAX, we can use a direct load.
                    // Otherwise, we need to load the address, then indirectly load the value.
                    if (reg.id() == 0) {
                        // movabs rax, ds:moffs64
                        const payload = try self.addExtra(Mir.Imm64.encode(x));
                        _ = try self.addInst(.{
                            .tag = .movabs,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = .rax,
                                .flags = 0b01, // imm64 will become moffs64
                            }),
                            .data = .{ .payload = payload },
                        });
                    } else {
                        // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                        try self.genSetReg(ty, reg, MCValue{ .immediate = x });

                        // mov reg, [reg + 0x0]
                        _ = try self.addInst(.{
                            .tag = .mov,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = registerAlias(reg, abi_size),
                                .reg2 = reg.to64(),
                                .flags = 0b01,
                            }),
                            .data = .{ .imm = 0 },
                        });
                    }
                }
            },
        },
        .stack_offset => |off| {
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }

            switch (ty.zigTypeTag()) {
                .Int => switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        if (abi_size <= 4) {
                            const flags: u2 = switch (abi_size) {
                                1 => 0b01,
                                2 => 0b10,
                                4 => 0b11,
                                else => unreachable,
                            };
                            _ = try self.addInst(.{
                                .tag = .mov_sign_extend,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = reg.to64(),
                                    .reg2 = .rbp,
                                    .flags = flags,
                                }),
                                .data = .{ .imm = @bitCast(u32, -off) },
                            });
                            return;
                        }
                    },
                    .unsigned => {
                        if (abi_size <= 2) {
                            const flags: u2 = switch (abi_size) {
                                1 => 0b01,
                                2 => 0b10,
                                else => unreachable,
                            };
                            _ = try self.addInst(.{
                                .tag = .mov_zero_extend,
                                .ops = Mir.Inst.Ops.encode(.{
                                    .reg1 = reg.to64(),
                                    .reg2 = .rbp,
                                    .flags = flags,
                                }),
                                .data = .{ .imm = @bitCast(u32, -off) },
                            });
                            return;
                        }
                    },
                },
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f32_avx
                            else
                                Mir.Inst.Tag.mov_f32_sse,
                            .f64 => if (hasAvxSupport(self.target.*))
                                Mir.Inst.Tag.mov_f64_avx
                            else
                                Mir.Inst.Tag.mov_f64_sse,
                            else => return self.fail("TODO genSetReg from stack offset for {}", .{ty.fmtDebug()}),
                        };
                        _ = try self.addInst(.{
                            .tag = tag,
                            .ops = Mir.Inst.Ops.encode(.{
                                .reg1 = reg.to128(),
                                .reg2 = switch (ty.tag()) {
                                    .f32 => .ebp,
                                    .f64 => .rbp,
                                    else => unreachable,
                                },
                            }),
                            .data = .{ .imm = @bitCast(u32, -off) },
                        });
                        return;
                    }
                    return self.fail("TODO genSetReg from stack offset for float with no intrinsics", .{});
                },
                else => {},
            }

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = Mir.Inst.Ops.encode(.{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = .rbp,
                    .flags = 0b01,
                }),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
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
    const ptr_ty = self.air.typeOf(ty_op.operand);
    const ptr = try self.resolveInst(ty_op.operand);
    const array_ty = ptr_ty.childType();
    const array_len = array_ty.arrayLen();
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        const stack_offset = @intCast(i32, try self.allocMem(inst, 16, 16));
        try self.genSetStack(ptr_ty, stack_offset, ptr, .{});
        try self.genSetStack(Type.initTag(.u64), stack_offset - 8, .{ .immediate = array_len }, .{});
        break :blk .{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntToFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airIntToFloat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFloatToInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const src_ty = self.air.typeOf(ty_op.operand);
    const dst_ty = self.air.typeOfIndex(inst);
    const operand = try self.resolveInst(ty_op.operand);

    // move float src to ST(0)
    const stack_offset = switch (operand) {
        .stack_offset, .ptr_stack_offset => |offset| offset,
        else => blk: {
            const offset = @intCast(i32, try self.allocMem(
                inst,
                @intCast(u32, src_ty.abiSize(self.target.*)),
                src_ty.abiAlignment(self.target.*),
            ));
            try self.genSetStack(src_ty, offset, operand, .{});
            break :blk offset;
        },
    };
    _ = try self.addInst(.{
        .tag = .fld,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = .rbp,
            .flags = switch (src_ty.abiSize(self.target.*)) {
                4 => 0b01,
                8 => 0b10,
                else => |size| return self.fail("TODO load ST(0) with abiSize={}", .{size}),
            },
        }),
        .data = .{ .imm = @bitCast(u32, -stack_offset) },
    });

    // convert
    const stack_dst = try self.allocRegOrMem(inst, false);
    _ = try self.addInst(.{
        .tag = .fisttp,
        .ops = Mir.Inst.Ops.encode(.{
            .reg1 = .rbp,
            .flags = switch (dst_ty.abiSize(self.target.*)) {
                1...2 => 0b00,
                3...4 => 0b01,
                5...8 => 0b10,
                else => |size| return self.fail("TODO convert float with abiSize={}", .{size}),
            },
        }),
        .data = .{ .imm = @bitCast(u32, -stack_dst.stack_offset) },
    });

    return self.finishAir(inst, stack_dst, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    _ = ty_pl;
    _ = extra;
    return self.fail("TODO implement airCmpxchg for {}", .{self.target.cpu.arch});
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
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

    const dst_ptr = try self.resolveInst(pl_op.operand);
    const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const src_val = try self.resolveInst(extra.lhs);
    const src_val_lock: ?RegisterLock = switch (src_val) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_val_lock) |lock| self.register_manager.unlockReg(lock);

    const len = try self.resolveInst(extra.rhs);
    const len_lock: ?RegisterLock = switch (len) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genInlineMemset(dst_ptr, src_val, len, .{});

    return self.finishAir(inst, .none, .{ pl_op.operand, .none, .none });
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

    const dst_ptr = try self.resolveInst(pl_op.operand);
    const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const src_ty = self.air.typeOf(extra.lhs);
    const src_ptr = try self.resolveInst(extra.lhs);
    const src_ptr_lock: ?RegisterLock = switch (src_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const len = try self.resolveInst(extra.rhs);
    const len_lock: ?RegisterLock = switch (len) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

    // TODO Is this the only condition for pointer dereference for memcpy?
    const src: MCValue = blk: {
        switch (src_ptr) {
            .got_load, .direct_load, .memory => {
                const reg = try self.register_manager.allocReg(null, gp);
                try self.loadMemPtrIntoRegister(reg, src_ty, src_ptr);
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = Mir.Inst.Ops.encode(.{
                        .reg1 = reg,
                        .reg2 = reg,
                        .flags = 0b01,
                    }),
                    .data = .{ .imm = 0 },
                });
                break :blk MCValue{ .register = reg };
            },
            else => break :blk src_ptr,
        }
    };
    const src_lock: ?RegisterLock = switch (src) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genInlineMemcpy(dst_ptr, src, len, .{});

    return self.finishAir(inst, .none, .{ pl_op.operand, .none, .none });
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airTagName for x86_64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for x86_64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for x86_64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSelect for x86_64", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airShuffle for x86_64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[inst].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airReduce for x86_64", .{});
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const result_ty = self.air.typeOfIndex(inst);
    const len = @intCast(usize, result_ty.arrayLen());
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
    const abi_size = @intCast(u32, result_ty.abiSize(self.target.*));
    const abi_align = result_ty.abiAlignment(self.target.*);
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        switch (result_ty.zigTypeTag()) {
            .Struct => {
                const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
                for (elements) |elem, elem_i| {
                    if (result_ty.structFieldValueComptime(elem_i) != null) continue; // comptime elem

                    const elem_ty = result_ty.structFieldType(elem_i);
                    const elem_off = result_ty.structFieldOffset(elem_i, self.target.*);
                    const elem_mcv = try self.resolveInst(elem);
                    try self.genSetStack(elem_ty, stack_offset - @intCast(i32, elem_off), elem_mcv, .{});
                }
                break :res MCValue{ .stack_offset = stack_offset };
            },
            .Array => {
                const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
                const elem_ty = result_ty.childType();
                const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

                for (elements) |elem, elem_i| {
                    const elem_mcv = try self.resolveInst(elem);
                    const elem_off = @intCast(i32, elem_size * elem_i);
                    try self.genSetStack(elem_ty, stack_offset - elem_off, elem_mcv, .{});
                }
                break :res MCValue{ .stack_offset = stack_offset };
            },
            .Vector => return self.fail("TODO implement aggregate_init for vectors", .{}),
            else => unreachable,
        }
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
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airAggregateInit for x86_64", .{});
    };
    return self.finishAir(inst, result, .{ extra.init, .none, .none });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        return self.fail("TODO implement airMulAdd for x86_64", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

pub fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
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

/// If the MCValue is an immediate, and it does not fit within this type,
/// we put it in a register.
/// A potential opportunity for future optimization here would be keeping track
/// of the fact that the instruction is available both as an immediate
/// and as a register.
fn limitImmediateType(self: *Self, operand: Air.Inst.Ref, comptime T: type) !MCValue {
    const mcv = try self.resolveInst(operand);
    const ti = @typeInfo(T).Int;
    switch (mcv) {
        .immediate => |imm| {
            // This immediate is unsigned.
            const U = std.meta.Int(.unsigned, ti.bits - @boolToInt(ti.signedness == .signed));
            if (imm >= math.maxInt(U)) {
                return MCValue{ .register = try self.copyToTmpRegister(Type.initTag(.usize), mcv) };
            }
        },
        else => {},
    }
    return mcv;
}

fn lowerDeclRef(self: *Self, tv: TypedValue, decl_index: Module.Decl.Index) InnerError!MCValue {
    log.debug("lowerDeclRef: ty = {}, val = {}", .{ tv.ty.fmtDebug(), tv.val.fmtDebug() });
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);

    // TODO this feels clunky. Perhaps we should check for it in `genTypedValue`?
    if (tv.ty.zigTypeTag() == .Pointer) blk: {
        if (tv.ty.castPtrToFn()) |_| break :blk;
        if (!tv.ty.elemType2().hasRuntimeBits()) {
            return MCValue.none;
        }
    }

    const module = self.bin_file.options.module.?;
    const decl = module.declPtr(decl_index);
    module.markDeclAlive(decl);

    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
        const got_addr = got.p_vaddr + decl.link.elf.offset_table_index * ptr_bytes;
        return MCValue{ .memory = got_addr };
    } else if (self.bin_file.cast(link.File.MachO)) |_| {
        // Because MachO is PIE-always-on, we defer memory address resolution until
        // the linker has enough info to perform relocations.
        assert(decl.link.macho.local_sym_index != 0);
        return MCValue{ .got_load = decl.link.macho.local_sym_index };
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
}

fn lowerUnnamedConst(self: *Self, tv: TypedValue) InnerError!MCValue {
    log.debug("lowerUnnamedConst: ty = {}, val = {}", .{ tv.ty.fmtDebug(), tv.val.fmtDebug() });
    const local_sym_index = self.bin_file.lowerUnnamedConst(tv, self.mod_fn.owner_decl) catch |err| {
        return self.fail("lowering unnamed constant failed: {s}", .{@errorName(err)});
    };
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const vaddr = elf_file.local_symbols.items[local_sym_index].st_value;
        return MCValue{ .memory = vaddr };
    } else if (self.bin_file.cast(link.File.MachO)) |_| {
        return MCValue{ .direct_load = local_sym_index };
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
        .Void => return MCValue{ .none = {} },
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {},
            else => {
                switch (typed_value.val.tag()) {
                    .int_u64 => {
                        return MCValue{ .immediate = typed_value.val.toUnsignedInt(target) };
                    },
                    else => {},
                }
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits <= ptr_bits and info.signedness == .signed) {
                return MCValue{ .immediate = @bitCast(u64, typed_value.val.toSignedInt()) };
            }
            if (!(info.bits > ptr_bits or info.signedness == .signed)) {
                return MCValue{ .immediate = typed_value.val.toUnsignedInt(target) };
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
                return MCValue{ .immediate = @boolToInt(!typed_value.val.isNull()) };
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

        .ComptimeInt => unreachable,
        .ComptimeFloat => unreachable,
        .Type => unreachable,
        .EnumLiteral => unreachable,
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
        .Unspecified, .C => {
            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime() and !ret_ty.isError()) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                if (ret_ty_size == 0) {
                    assert(ret_ty.isError());
                    result.return_value = .{ .immediate = 0 };
                } else if (ret_ty_size <= 8) {
                    const aliased_reg = registerAlias(c_abi_int_return_regs[0], ret_ty_size);
                    result.return_value = .{ .register = aliased_reg };
                } else {
                    // We simply make the return MCValue a stack offset. However, the actual value
                    // for the offset will be populated later. We will also push the stack offset
                    // value into .rdi register when we resolve the offset.
                    result.return_value = .{ .stack_offset = 0 };
                }
            }

            // Input params
            // First, split into args that can be passed via registers.
            // This will make it easier to then push the rest of args in reverse
            // order on the stack.
            var next_int_reg: usize = 0;
            var by_reg = std.AutoHashMap(usize, usize).init(self.bin_file.allocator);
            defer by_reg.deinit();

            // If we want debug output, we store all args on stack for better liveness of args
            // in debugging contexts such as previewing the args in the debugger anywhere in
            // the procedure. Passing the args via registers can lead to reusing the register
            // for local ops thus clobbering the input arg forever.
            // This of course excludes C ABI calls.
            const omit_args_in_registers = blk: {
                if (cc == .C) break :blk false;
                switch (self.bin_file.options.optimize_mode) {
                    .Debug => break :blk true,
                    else => break :blk false,
                }
            };
            if (!omit_args_in_registers) {
                for (param_types) |ty, i| {
                    if (!ty.hasRuntimeBits()) continue;
                    const param_size = @intCast(u32, ty.abiSize(self.target.*));
                    // For simplicity of codegen, slices and other types are always pushed onto the stack.
                    // TODO: look into optimizing this by passing things as registers sometimes,
                    // such as ptr and len of slices as separate registers.
                    // TODO: also we need to honor the C ABI for relevant types rather than passing on
                    // the stack here.
                    const pass_in_reg = switch (ty.zigTypeTag()) {
                        .Bool => true,
                        .Int, .Enum => param_size <= 8,
                        .Pointer => ty.ptrSize() != .Slice,
                        .Optional => ty.isPtrLikeOptional(),
                        else => false,
                    };
                    if (pass_in_reg) {
                        if (next_int_reg >= c_abi_int_param_regs.len) break;
                        try by_reg.putNoClobber(i, next_int_reg);
                        next_int_reg += 1;
                    }
                }
            }

            var next_stack_offset: u32 = switch (result.return_value) {
                .stack_offset => |off| @intCast(u32, off),
                else => 0,
            };
            var count: usize = param_types.len;
            while (count > 0) : (count -= 1) {
                const i = count - 1;
                const ty = param_types[i];
                if (!ty.hasRuntimeBits()) {
                    assert(cc != .C);
                    result.args[i] = .{ .none = {} };
                    continue;
                }
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                const param_align = @intCast(u32, ty.abiAlignment(self.target.*));
                if (by_reg.get(i)) |int_reg| {
                    const aliased_reg = registerAlias(c_abi_int_param_regs[int_reg], param_size);
                    result.args[i] = .{ .register = aliased_reg };
                    next_int_reg += 1;
                } else {
                    const offset = mem.alignForwardGeneric(u32, next_stack_offset + param_size, param_align);
                    result.args[i] = .{ .stack_offset = @intCast(i32, offset) };
                    next_stack_offset = offset;
                }
            }

            result.stack_align = 16;
            // TODO fix this so that the 16byte alignment padding is at the current value of $rsp, and push
            // the args onto the stack so that there is no padding between the first argument and
            // the standard preamble.
            // alignment padding | args ... | ret addr | $rbp |
            result.stack_byte_count = mem.alignForwardGeneric(u32, next_stack_offset, result.stack_align);
        },
        else => return self.fail("TODO implement function parameters and return values for {} on x86_64", .{cc}),
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

/// Returns register wide enough to hold at least `size_bytes`.
fn registerAlias(reg: Register, size_bytes: u32) Register {
    if (size_bytes == 0) {
        unreachable; // should be comptime known
    } else if (size_bytes <= 1) {
        return reg.to8();
    } else if (size_bytes <= 2) {
        return reg.to16();
    } else if (size_bytes <= 4) {
        return reg.to32();
    } else if (size_bytes <= 8) {
        return reg.to64();
    } else if (size_bytes <= 16) {
        return reg.to128();
    } else if (size_bytes <= 32) {
        return reg.to256();
    } else unreachable;
}

/// Truncates the value in the register in place.
/// Clobbers any remaining bits.
fn truncateRegister(self: *Self, ty: Type, reg: Register) !void {
    const int_info = ty.intInfo(self.target.*);
    const max_reg_bit_width = Register.rax.size();
    switch (int_info.signedness) {
        .signed => {
            const shift = @intCast(u6, max_reg_bit_width - int_info.bits);
            try self.genShiftBinOpMir(.sal, Type.isize, reg, .{ .immediate = shift });
            try self.genShiftBinOpMir(.sar, Type.isize, reg, .{ .immediate = shift });
        },
        .unsigned => {
            const shift = @intCast(u6, max_reg_bit_width - int_info.bits);
            const mask = (~@as(u64, 0)) >> shift;
            if (int_info.bits <= 32) {
                try self.genBinOpMir(.@"and", Type.usize, .{ .register = reg }, .{ .immediate = mask });
            } else {
                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinOpMir(.@"and", Type.usize, .{ .register = reg }, .{ .register = tmp_reg });
            }
        },
    }
}

fn intrinsicsAllowed(target: Target, ty: Type) bool {
    return switch (ty.tag()) {
        .f32,
        .f64,
        => Target.x86.featureSetHasAny(target.cpu.features, .{ .sse2, .avx, .avx2 }),
        else => unreachable, // TODO finish this off
    };
}

fn hasAvxSupport(target: Target) bool {
    return Target.x86.featureSetHasAny(target.cpu.features, .{ .avx, .avx2 });
}
