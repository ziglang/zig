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
const Alignment = InternPool.Alignment;

const Result = codegen.Result;
const CodeGenError = codegen.CodeGenError;
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

const InnerError = CodeGenError || error{OutOfRegisters};

gpa: Allocator,
air: Air,
liveness: Liveness,
bin_file: *link.File,
debug_output: DebugInfoOutput,
target: *const std.Target,
func_index: InternPool.Index,
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

/// We postpone the creation of debug info for function args and locals
/// until after all Mir instructions have been generated. Only then we
/// will know saved_regs_stack_space which is necessary in order to
/// calculate the right stack offsest with respect to the `.fp` register.
dbg_info_relocs: std.ArrayListUnmanaged(DbgInfoReloc) = .{},

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

            switch (result) {
                .register => |reg| {
                    // In some cases (such as bitcast), an operand
                    // may be the same MCValue as the result. If
                    // that operand died and was a register, it
                    // was freed by processDeath. We have to
                    // "re-allocate" the register.
                    if (bt.function.register_manager.isRegFree(reg)) {
                        bt.function.register_manager.getRegAssumeFree(reg, bt.inst);
                    }
                },
                .register_c_flag,
                .register_v_flag,
                => |reg| {
                    if (bt.function.register_manager.isRegFree(reg)) {
                        bt.function.register_manager.getRegAssumeFree(reg, bt.inst);
                    }
                    bt.function.cpsr_flags_inst = bt.inst;
                },
                .cpsr_flags => {
                    bt.function.cpsr_flags_inst = bt.inst;
                },
                else => {},
            }
        }
        bt.function.finishAirBookkeeping();
    }
};

const DbgInfoReloc = struct {
    tag: Air.Inst.Tag,
    ty: Type,
    name: [:0]const u8,
    mcv: MCValue,

    fn genDbgInfo(reloc: DbgInfoReloc, function: Self) !void {
        switch (reloc.tag) {
            .arg => try reloc.genArgDbgInfo(function),

            .dbg_var_ptr,
            .dbg_var_val,
            => try reloc.genVarDbgInfo(function),

            else => unreachable,
        }
    }

    fn genArgDbgInfo(reloc: DbgInfoReloc, function: Self) error{OutOfMemory}!void {
        const mod = function.bin_file.comp.module.?;
        switch (function.debug_output) {
            .dwarf => |dw| {
                const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (reloc.mcv) {
                    .register => |reg| .{ .register = reg.dwarfLocOp() },
                    .stack_offset,
                    .stack_argument_offset,
                    => blk: {
                        const adjusted_stack_offset = switch (reloc.mcv) {
                            .stack_offset => |offset| -@as(i32, @intCast(offset)),
                            .stack_argument_offset => |offset| @as(i32, @intCast(function.saved_regs_stack_space + offset)),
                            else => unreachable,
                        };
                        break :blk .{ .stack = .{
                            .fp_register = DW.OP.breg11,
                            .offset = adjusted_stack_offset,
                        } };
                    },
                    else => unreachable, // not a possible argument
                };

                try dw.genArgDbgInfo(reloc.name, reloc.ty, mod.funcOwnerDeclIndex(function.func_index), loc);
            },
            .plan9 => {},
            .none => {},
        }
    }

    fn genVarDbgInfo(reloc: DbgInfoReloc, function: Self) !void {
        const mod = function.bin_file.comp.module.?;
        const is_ptr = switch (reloc.tag) {
            .dbg_var_ptr => true,
            .dbg_var_val => false,
            else => unreachable,
        };

        switch (function.debug_output) {
            .dwarf => |dw| {
                const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (reloc.mcv) {
                    .register => |reg| .{ .register = reg.dwarfLocOp() },
                    .ptr_stack_offset,
                    .stack_offset,
                    .stack_argument_offset,
                    => |offset| blk: {
                        const adjusted_offset = switch (reloc.mcv) {
                            .ptr_stack_offset,
                            .stack_offset,
                            => -@as(i32, @intCast(offset)),
                            .stack_argument_offset => @as(i32, @intCast(function.saved_regs_stack_space + offset)),
                            else => unreachable,
                        };
                        break :blk .{ .stack = .{
                            .fp_register = DW.OP.breg11,
                            .offset = adjusted_offset,
                        } };
                    },
                    .memory => |address| .{ .memory = address },
                    .immediate => |x| .{ .immediate = x },
                    .undef => .undef,
                    .none => .none,
                    else => blk: {
                        log.debug("TODO generate debug info for {}", .{reloc.mcv});
                        break :blk .nop;
                    },
                };
                try dw.genVarDbgInfo(reloc.name, reloc.ty, mod.funcOwnerDeclIndex(function.func_index), is_ptr, loc);
            },
            .plan9 => {},
            .none => {},
        }
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

    var function: Self = .{
        .gpa = gpa,
        .air = air,
        .liveness = liveness,
        .target = target,
        .bin_file = lf,
        .debug_output = debug_output,
        .func_index = func_index,
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
    defer function.dbg_info_relocs.deinit(gpa);

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

    for (function.dbg_info_relocs.items) |reloc| {
        try reloc.genDbgInfo(function);
    }

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
        .stack_size = function.max_end_stack,
        .saved_regs_stack_space = function.saved_regs_stack_space,
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
    const mod = self.bin_file.comp.module.?;
    const cc = self.fn_type.fnCallingConvention(mod);
    if (cc != .Naked) {
        // push {fp, lr}
        const push_reloc = try self.addNop();

        // mov fp, sp
        _ = try self.addInst(.{
            .tag = .mov,
            .data = .{ .r_op_mov = .{
                .rd = .fp,
                .op = Instruction.Operand.reg(.sp, Instruction.Operand.Shift.none),
            } },
        });

        // sub sp, sp, #reloc
        const sub_reloc = try self.addNop();

        // The sub_sp_scratch_r4 instruction may use r4, so we mark r4
        // as allocated by this function.
        const index = RegisterManager.indexOfRegIntoTracked(.r4).?;
        self.register_manager.allocated_registers.set(index);

        if (self.ret_mcv == .stack_offset) {
            // The address of where to store the return value is in
            // r0. As this register might get overwritten along the
            // way, save the address to the stack.
            const stack_offset = try self.allocMem(4, .@"4", null);

            try self.genSetStack(Type.usize, stack_offset, MCValue{ .register = .r0 });
            self.ret_mcv = MCValue{ .stack_offset = stack_offset };
        }

        for (self.args, 0..) |*arg, arg_index| {
            // Copy register arguments to the stack
            switch (arg.*) {
                .register => |reg| {
                    // The first AIR instructions of the main body are guaranteed
                    // to be the functions arguments
                    const inst = self.air.getMainBody()[arg_index];
                    assert(self.air.instructions.items(.tag)[@intFromEnum(inst)] == .arg);

                    const ty = self.typeOfIndex(inst);

                    const abi_size: u32 = @intCast(ty.abiSize(mod));
                    const abi_align = ty.abiAlignment(mod);
                    const stack_offset = try self.allocMem(abi_size, abi_align, inst);
                    try self.genSetStack(ty, stack_offset, MCValue{ .register = reg });

                    arg.* = MCValue{ .stack_offset = stack_offset };
                },
                else => {},
            }
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
        const aligned_total_stack_end = mem.alignForward(u32, total_stack_size, self.stack_align);
        const stack_size = aligned_total_stack_end - self.saved_regs_stack_space;
        self.max_end_stack = stack_size;
        self.mir_instructions.set(sub_reloc, .{
            .tag = .sub_sp_scratch_r4,
            .data = .{ .imm32 = stack_size },
        });

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
                .data = .{ .inst = @intCast(self.mir_instructions.len) },
            });
        }

        // Epilogue: pop callee saved registers (swap lr with pc in saved_regs)
        saved_regs.r14 = false; // lr
        saved_regs.r15 = true; // pc

        // mov sp, fp
        _ = try self.addInst(.{
            .tag = .mov,
            .data = .{ .r_op_mov = .{
                .rd = .sp,
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
            .add,            => try self.airBinOp(inst, .add),
            .add_wrap        => try self.airBinOp(inst, .add_wrap),
            .sub,            => try self.airBinOp(inst, .sub),
            .sub_wrap        => try self.airBinOp(inst, .sub_wrap),
            .mul             => try self.airBinOp(inst, .mul),
            .mul_wrap        => try self.airBinOp(inst, .mul_wrap),
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
            .addrspace_cast  => return self.fail("TODO implement addrspace_cast", .{}),

            .@"try"          => try self.airTry(inst),
            .try_ptr         => try self.airTryPtr(inst),

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

            .add_safe,
            .sub_safe,
            .mul_safe,
            => return self.fail("TODO implement safety_checked_instructions", .{}),

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

        assert(!self.register_manager.lockedRegsExist());

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

fn allocMem(
    self: *Self,
    abi_size: u32,
    abi_align: Alignment,
    maybe_inst: ?Air.Inst.Index,
) !u32 {
    assert(abi_size > 0);
    assert(abi_align != .none);

    // TODO find a free slot instead of always appending
    const offset: u32 = @intCast(abi_align.forward(self.next_stack_offset) + abi_size);
    self.next_stack_offset = offset;
    self.max_end_stack = @max(self.max_end_stack, self.next_stack_offset);

    if (maybe_inst) |inst| {
        try self.stack.putNoClobber(self.gpa, offset, .{
            .inst = inst,
            .size = abi_size,
        });
    }

    return offset;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !u32 {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = self.typeOfIndex(inst).childType(mod);

    if (!elem_ty.hasRuntimeBits(mod)) {
        // As this stack item will never be dereferenced at runtime,
        // return the stack offset 0. Stack offset 0 will be where all
        // zero-sized stack allocations live as non-zero-sized
        // allocations will always have an offset > 0.
        return 0;
    }

    const abi_size = math.cast(u32, elem_ty.abiSize(mod)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(mod);

    return self.allocMem(abi_size, abi_align, inst);
}

fn allocRegOrMem(self: *Self, elem_ty: Type, reg_ok: bool, maybe_inst: ?Air.Inst.Index) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const abi_size = math.cast(u32, elem_ty.abiSize(mod)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    const abi_align = elem_ty.abiAlignment(mod);

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        if (abi_size <= ptr_bytes) {
            if (self.register_manager.tryAllocReg(maybe_inst, gp)) |reg| {
                return MCValue{ .register = reg };
            }
        }
    }

    const stack_offset = try self.allocMem(abi_size, abi_align, maybe_inst);
    return MCValue{ .stack_offset = stack_offset };
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(self.typeOfIndex(inst), false, inst);
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
    try self.genSetStack(self.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
}

/// Save the current instruction stored in the compare flags if
/// occupied
fn spillCompareFlagsIfOccupied(self: *Self) !void {
    if (self.cpsr_flags_inst) |inst_to_save| {
        const ty = self.typeOfIndex(inst_to_save);
        const mcv = self.getResolvedInstValue(inst_to_save);
        const new_mcv = switch (mcv) {
            .cpsr_flags => try self.allocRegOrMem(ty, true, inst_to_save),
            .register_c_flag,
            .register_v_flag,
            => try self.allocRegOrMem(ty, false, inst_to_save),
            else => unreachable, // mcv doesn't occupy the compare flags
        };

        try self.setRegOrMem(self.typeOfIndex(inst_to_save), new_mcv, mcv);
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
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = switch (self.ret_mcv) {
        .none, .register => .{ .ptr_stack_offset = try self.allocMemPtr(inst) },
        .stack_offset => blk: {
            // self.ret_mcv is an address to where this function
            // should store its result into
            const ret_ty = self.fn_type.fnReturnType(mod);
            const ptr_ty = try mod.singleMutPtrType(ret_ty);

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
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand = try self.resolveInst(ty_op.operand);
    const operand_ty = self.typeOf(ty_op.operand);
    const dest_ty = self.typeOfIndex(inst);

    const operand_abi_size = operand_ty.abiSize(mod);
    const dest_abi_size = dest_ty.abiSize(mod);
    const info_a = operand_ty.intInfo(mod);
    const info_b = dest_ty.intInfo(mod);

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
            .width = @intCast(int_bits),
        } },
    });
}

/// Asserts that both operand_ty and dest_ty are integer types
fn trunc(
    self: *Self,
    maybe_inst: ?Air.Inst.Index,
    operand_bind: ReadArg.Bind,
    operand_ty: Type,
    dest_ty: Type,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const info_a = operand_ty.intInfo(mod);
    const info_b = dest_ty.intInfo(mod);

    if (info_b.bits <= 32) {
        if (info_a.bits > 32) {
            return self.fail("TODO load least significant word into register", .{});
        }

        var operand_reg: Register = undefined;
        var dest_reg: Register = undefined;

        const read_args = [_]ReadArg{
            .{ .ty = operand_ty, .bind = operand_bind, .class = gp, .reg = &operand_reg },
        };
        const write_args = [_]WriteArg{
            .{ .ty = dest_ty, .bind = .none, .class = gp, .reg = &dest_reg },
        };
        try self.allocRegs(
            &read_args,
            &write_args,
            if (maybe_inst) |inst| .{
                .corresponding_inst = inst,
                .operand_mapping = &.{0},
            } else null,
        );

        switch (info_b.bits) {
            32 => {
                try self.genSetReg(operand_ty, dest_reg, .{ .register = operand_reg });
            },
            else => {
                try self.truncRegister(operand_reg, dest_reg, info_b.signedness, info_b.bits);
            },
        }

        return MCValue{ .register = dest_reg };
    } else {
        return self.fail("TODO: truncate to ints > 32 bits", .{});
    }
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_bind: ReadArg.Bind = .{ .inst = ty_op.operand };
    const operand_ty = self.typeOf(ty_op.operand);
    const dest_ty = self.typeOfIndex(inst);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        break :blk try self.trunc(inst, operand_bind, operand_ty, dest_ty);
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromBool(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_bind: ReadArg.Bind = .{ .inst = ty_op.operand };
        const operand_ty = self.typeOf(ty_op.operand);
        switch (try operand_bind.resolveToMcv(self)) {
            .dead => unreachable,
            .unreach => unreachable,
            .cpsr_flags => |cond| break :result MCValue{ .cpsr_flags = cond.negate() },
            else => {
                switch (operand_ty.zigTypeTag(mod)) {
                    .Bool => {
                        var op_reg: Register = undefined;
                        var dest_reg: Register = undefined;

                        const read_args = [_]ReadArg{
                            .{ .ty = operand_ty, .bind = operand_bind, .class = gp, .reg = &op_reg },
                        };
                        const write_args = [_]WriteArg{
                            .{ .ty = operand_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                        };
                        try self.allocRegs(
                            &read_args,
                            &write_args,
                            ReuseMetadata{
                                .corresponding_inst = inst,
                                .operand_mapping = &.{0},
                            },
                        );

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
                        const int_info = operand_ty.intInfo(mod);
                        if (int_info.bits <= 32) {
                            var op_reg: Register = undefined;
                            var dest_reg: Register = undefined;

                            const read_args = [_]ReadArg{
                                .{ .ty = operand_ty, .bind = operand_bind, .class = gp, .reg = &op_reg },
                            };
                            const write_args = [_]WriteArg{
                                .{ .ty = operand_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                            };
                            try self.allocRegs(
                                &read_args,
                                &write_args,
                                ReuseMetadata{
                                    .corresponding_inst = inst,
                                    .operand_mapping = &.{0},
                                },
                            );

                            _ = try self.addInst(.{
                                .tag = .mvn,
                                .data = .{ .r_op_mov = .{
                                    .rd = dest_reg,
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
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM min/max on floats", .{}),
        .Vector => return self.fail("TODO ARM min/max on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                var lhs_reg: Register = undefined;
                var rhs_reg: Register = undefined;
                var dest_reg: Register = undefined;

                const read_args = [_]ReadArg{
                    .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
                    .{ .ty = rhs_ty, .bind = rhs_bind, .class = gp, .reg = &rhs_reg },
                };
                const write_args = [_]WriteArg{
                    .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                };
                try self.allocRegs(
                    &read_args,
                    &write_args,
                    if (maybe_inst) |inst| .{
                        .corresponding_inst = inst,
                        .operand_mapping = &.{ 0, 1 },
                    } else null,
                );

                // lhs == reg should have been checked by airMinMax
                //
                // By guaranteeing lhs != rhs, we guarantee (dst !=
                // lhs) or (dst != rhs), which is a property we use to
                // omit generating one instruction when we reuse a
                // register.
                assert(lhs_reg != rhs_reg); // see note above

                _ = try self.addInst(.{
                    .tag = .cmp,
                    .data = .{ .r_op_cmp = .{
                        .rn = lhs_reg,
                        .op = Instruction.Operand.reg(rhs_reg, Instruction.Operand.Shift.none),
                    } },
                });

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
                        .data = .{ .r_op_mov = .{
                            .rd = dest_reg,
                            .op = Instruction.Operand.reg(lhs_reg, Instruction.Operand.Shift.none),
                        } },
                    });
                }
                if (dest_reg != rhs_reg) {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = cond_choose_rhs,
                        .data = .{ .r_op_mov = .{
                            .rd = dest_reg,
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
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs_bind: ReadArg.Bind = .{ .inst = bin_op.lhs };
        const rhs_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };

        const lhs = try self.resolveInst(bin_op.lhs);
        if (bin_op.lhs == bin_op.rhs) break :result lhs;

        break :result try self.minMax(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr = try self.resolveInst(bin_op.lhs);
        const ptr_ty = self.typeOf(bin_op.lhs);
        const len = try self.resolveInst(bin_op.rhs);
        const len_ty = self.typeOf(bin_op.rhs);

        const stack_offset = try self.allocMem(8, .@"4", inst);
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(len_ty, stack_offset - 4, len);
        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs_bind: ReadArg.Bind = .{ .inst = bin_op.lhs };
        const rhs_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };

        break :result switch (tag) {
            .add => try self.addSub(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .sub => try self.addSub(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .mul => try self.mul(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .div_float => try self.divFloat(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .div_trunc => try self.divTrunc(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .div_floor => try self.divFloor(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .div_exact => try self.divExact(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .rem => try self.rem(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .mod => try self.modulo(lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .add_wrap => try self.wrappingArithmetic(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .sub_wrap => try self.wrappingArithmetic(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .mul_wrap => try self.wrappingArithmetic(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .bit_and => try self.bitwise(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .bit_or => try self.bitwise(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .xor => try self.bitwise(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .shl_exact => try self.shiftExact(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .shr_exact => try self.shiftExact(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .shl => try self.shiftNormal(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .shr => try self.shiftNormal(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            .bool_and => try self.booleanOp(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),
            .bool_or => try self.booleanOp(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst),

            else => unreachable,
        };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs_bind: ReadArg.Bind = .{ .inst = bin_op.lhs };
        const rhs_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };

        break :result try self.ptrArithmetic(tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, inst);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs_bind: ReadArg.Bind = .{ .inst = extra.lhs };
        const rhs_bind: ReadArg.Bind = .{ .inst = extra.rhs };
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        const tuple_ty = self.typeOfIndex(inst);
        const tuple_size: u32 = @intCast(tuple_ty.abiSize(mod));
        const tuple_align = tuple_ty.abiAlignment(mod);
        const overflow_bit_offset: u32 = @intCast(tuple_ty.structFieldOffset(1, mod));

        switch (lhs_ty.zigTypeTag(mod)) {
            .Vector => return self.fail("TODO implement add_with_overflow/sub_with_overflow for vectors", .{}),
            .Int => {
                assert(lhs_ty.eql(rhs_ty, mod));
                const int_info = lhs_ty.intInfo(mod);
                if (int_info.bits < 32) {
                    const stack_offset = try self.allocMem(tuple_size, tuple_align, inst);

                    try self.spillCompareFlagsIfOccupied();

                    const base_tag: Air.Inst.Tag = switch (tag) {
                        .add_with_overflow => .add,
                        .sub_with_overflow => .sub,
                        else => unreachable,
                    };
                    const dest = try self.addSub(base_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_reg_lock);

                    const truncated_reg = try self.register_manager.allocReg(null, gp);
                    const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                    defer self.register_manager.unlockReg(truncated_reg_lock);

                    // sbfx/ubfx truncated, dest, #0, #bits
                    try self.truncRegister(dest_reg, truncated_reg, int_info.signedness, int_info.bits);

                    // cmp dest, truncated
                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .r_op_cmp = .{
                            .rn = dest_reg,
                            .op = Instruction.Operand.reg(truncated_reg, Instruction.Operand.Shift.none),
                        } },
                    });

                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = truncated_reg });
                    try self.genSetStack(Type.u1, stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else if (int_info.bits == 32) {
                    const lhs_immediate = try lhs_bind.resolveToImmediate(self);
                    const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                    // Only say yes if the operation is
                    // commutative, i.e. we can swap both of the
                    // operands
                    const lhs_immediate_ok = switch (tag) {
                        .add_with_overflow => if (lhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false,
                        .sub_with_overflow => false,
                        else => unreachable,
                    };
                    const rhs_immediate_ok = switch (tag) {
                        .add_with_overflow,
                        .sub_with_overflow,
                        => if (rhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false,
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
                            break :blk try self.binOpImmediate(mir_tag, lhs_bind, rhs_immediate.?, lhs_ty, false, null);
                        } else if (lhs_immediate_ok) {
                            // swap lhs and rhs
                            break :blk try self.binOpImmediate(mir_tag, rhs_bind, lhs_immediate.?, rhs_ty, true, null);
                        } else {
                            break :blk try self.binOpRegister(mir_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, null);
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
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    if (self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ extra.lhs, extra.rhs, .none });
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = result: {
        const lhs_bind: ReadArg.Bind = .{ .inst = extra.lhs };
        const rhs_bind: ReadArg.Bind = .{ .inst = extra.rhs };
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        const tuple_ty = self.typeOfIndex(inst);
        const tuple_size: u32 = @intCast(tuple_ty.abiSize(mod));
        const tuple_align = tuple_ty.abiAlignment(mod);
        const overflow_bit_offset: u32 = @intCast(tuple_ty.structFieldOffset(1, mod));

        switch (lhs_ty.zigTypeTag(mod)) {
            .Vector => return self.fail("TODO implement mul_with_overflow for vectors", .{}),
            .Int => {
                assert(lhs_ty.eql(rhs_ty, mod));
                const int_info = lhs_ty.intInfo(mod);
                if (int_info.bits <= 16) {
                    const stack_offset = try self.allocMem(tuple_size, tuple_align, inst);

                    try self.spillCompareFlagsIfOccupied();

                    const base_tag: Mir.Inst.Tag = switch (int_info.signedness) {
                        .signed => .smulbb,
                        .unsigned => .mul,
                    };

                    const dest = try self.binOpRegister(base_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, null);
                    const dest_reg = dest.register;
                    const dest_reg_lock = self.register_manager.lockRegAssumeUnused(dest_reg);
                    defer self.register_manager.unlockReg(dest_reg_lock);

                    const truncated_reg = try self.register_manager.allocReg(null, gp);
                    const truncated_reg_lock = self.register_manager.lockRegAssumeUnused(truncated_reg);
                    defer self.register_manager.unlockReg(truncated_reg_lock);

                    // sbfx/ubfx truncated, dest, #0, #bits
                    try self.truncRegister(dest_reg, truncated_reg, int_info.signedness, int_info.bits);

                    // cmp dest, truncated
                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .r_op_cmp = .{
                            .rn = dest_reg,
                            .op = Instruction.Operand.reg(truncated_reg, Instruction.Operand.Shift.none),
                        } },
                    });

                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = truncated_reg });
                    try self.genSetStack(Type.u1, stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

                    break :result MCValue{ .stack_offset = stack_offset };
                } else if (int_info.bits <= 32) {
                    const stack_offset = try self.allocMem(tuple_size, tuple_align, inst);

                    try self.spillCompareFlagsIfOccupied();

                    const base_tag: Mir.Inst.Tag = switch (int_info.signedness) {
                        .signed => .smull,
                        .unsigned => .umull,
                    };

                    var lhs_reg: Register = undefined;
                    var rhs_reg: Register = undefined;
                    var rdhi: Register = undefined;
                    var rdlo: Register = undefined;
                    var truncated_reg: Register = undefined;

                    const read_args = [_]ReadArg{
                        .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
                        .{ .ty = rhs_ty, .bind = rhs_bind, .class = gp, .reg = &rhs_reg },
                    };
                    const write_args = [_]WriteArg{
                        .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &rdhi },
                        .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &rdlo },
                        .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &truncated_reg },
                    };
                    try self.allocRegs(
                        &read_args,
                        &write_args,
                        null,
                    );

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
                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .r_op_cmp = .{
                            .rn = truncated_reg,
                            .op = Instruction.Operand.reg(rdlo, Instruction.Operand.Shift.none),
                        } },
                    });

                    // mov rdlo, #0
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .data = .{ .r_op_mov = .{
                            .rd = rdlo,
                            .op = Instruction.Operand.fromU32(0).?,
                        } },
                    });

                    // movne rdlo, #1
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = .ne,
                        .data = .{ .r_op_mov = .{
                            .rd = rdlo,
                            .op = Instruction.Operand.fromU32(1).?,
                        } },
                    });

                    // cmp rdhi, #0
                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .r_op_cmp = .{
                            .rn = rdhi,
                            .op = Instruction.Operand.fromU32(0).?,
                        } },
                    });

                    // movne rdlo, #1
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = .ne,
                        .data = .{ .r_op_mov = .{
                            .rd = rdlo,
                            .op = Instruction.Operand.fromU32(1).?,
                        } },
                    });

                    // strb rdlo, [...]
                    try self.genSetStack(Type.u1, stack_offset - overflow_bit_offset, .{ .register = rdlo });

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
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    if (self.liveness.isUnused(inst)) return self.finishAir(inst, .dead, .{ extra.lhs, extra.rhs, .none });
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = result: {
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        const tuple_ty = self.typeOfIndex(inst);
        const tuple_size: u32 = @intCast(tuple_ty.abiSize(mod));
        const tuple_align = tuple_ty.abiAlignment(mod);
        const overflow_bit_offset: u32 = @intCast(tuple_ty.structFieldOffset(1, mod));

        switch (lhs_ty.zigTypeTag(mod)) {
            .Vector => return self.fail("TODO implement shl_with_overflow for vectors", .{}),
            .Int => {
                const int_info = lhs_ty.intInfo(mod);
                if (int_info.bits <= 32) {
                    const stack_offset = try self.allocMem(tuple_size, tuple_align, inst);

                    try self.spillCompareFlagsIfOccupied();

                    const shr_mir_tag: Mir.Inst.Tag = switch (int_info.signedness) {
                        .signed => Mir.Inst.Tag.asr,
                        .unsigned => Mir.Inst.Tag.lsr,
                    };

                    var lhs_reg: Register = undefined;
                    var rhs_reg: Register = undefined;
                    var dest_reg: Register = undefined;
                    var reconstructed_reg: Register = undefined;

                    const rhs_mcv = try self.resolveInst(extra.rhs);
                    const rhs_immediate_ok = rhs_mcv == .immediate and Instruction.Operand.fromU32(rhs_mcv.immediate) != null;

                    const lhs_bind: ReadArg.Bind = .{ .inst = extra.lhs };
                    const rhs_bind: ReadArg.Bind = .{ .inst = extra.rhs };

                    if (rhs_immediate_ok) {
                        const read_args = [_]ReadArg{
                            .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
                        };
                        const write_args = [_]WriteArg{
                            .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                            .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &reconstructed_reg },
                        };
                        try self.allocRegs(
                            &read_args,
                            &write_args,
                            null,
                        );

                        // lsl dest, lhs, rhs
                        _ = try self.addInst(.{
                            .tag = .lsl,
                            .data = .{ .rr_shift = .{
                                .rd = dest_reg,
                                .rm = lhs_reg,
                                .shift_amount = Instruction.ShiftAmount.imm(@intCast(rhs_mcv.immediate)),
                            } },
                        });

                        try self.truncRegister(dest_reg, dest_reg, int_info.signedness, int_info.bits);

                        // asr/lsr reconstructed, dest, rhs
                        _ = try self.addInst(.{
                            .tag = shr_mir_tag,
                            .data = .{ .rr_shift = .{
                                .rd = reconstructed_reg,
                                .rm = dest_reg,
                                .shift_amount = Instruction.ShiftAmount.imm(@intCast(rhs_mcv.immediate)),
                            } },
                        });
                    } else {
                        const read_args = [_]ReadArg{
                            .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
                            .{ .ty = rhs_ty, .bind = rhs_bind, .class = gp, .reg = &rhs_reg },
                        };
                        const write_args = [_]WriteArg{
                            .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                            .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &reconstructed_reg },
                        };
                        try self.allocRegs(
                            &read_args,
                            &write_args,
                            null,
                        );

                        // lsl dest, lhs, rhs
                        _ = try self.addInst(.{
                            .tag = .lsl,
                            .data = .{ .rr_shift = .{
                                .rd = dest_reg,
                                .rm = lhs_reg,
                                .shift_amount = Instruction.ShiftAmount.reg(rhs_reg),
                            } },
                        });

                        try self.truncRegister(dest_reg, dest_reg, int_info.signedness, int_info.bits);

                        // asr/lsr reconstructed, dest, rhs
                        _ = try self.addInst(.{
                            .tag = shr_mir_tag,
                            .data = .{ .rr_shift = .{
                                .rd = reconstructed_reg,
                                .rm = dest_reg,
                                .shift_amount = Instruction.ShiftAmount.reg(rhs_reg),
                            } },
                        });
                    }

                    // cmp lhs, reconstructed
                    _ = try self.addInst(.{
                        .tag = .cmp,
                        .data = .{ .r_op_cmp = .{
                            .rn = lhs_reg,
                            .op = Instruction.Operand.reg(reconstructed_reg, Instruction.Operand.Shift.none),
                        } },
                    });

                    try self.genSetStack(lhs_ty, stack_offset, .{ .register = dest_reg });
                    try self.genSetStack(Type.u1, stack_offset - overflow_bit_offset, .{ .cpsr_flags = .ne });

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
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
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

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const optional_ty = self.typeOfIndex(inst);
        const abi_size: u32 = @intCast(optional_ty.abiSize(mod));

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
fn errUnionErr(
    self: *Self,
    error_union_bind: ReadArg.Bind,
    error_union_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const err_ty = error_union_ty.errorUnionSet(mod);
    const payload_ty = error_union_ty.errorUnionPayload(mod);
    if (err_ty.errorSetIsEmpty(mod)) {
        return MCValue{ .immediate = 0 };
    }
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return try error_union_bind.resolveToMcv(self);
    }

    const err_offset: u32 = @intCast(errUnionErrorOffset(payload_ty, mod));
    switch (try error_union_bind.resolveToMcv(self)) {
        .register => {
            var operand_reg: Register = undefined;
            var dest_reg: Register = undefined;

            const read_args = [_]ReadArg{
                .{ .ty = error_union_ty, .bind = error_union_bind, .class = gp, .reg = &operand_reg },
            };
            const write_args = [_]WriteArg{
                .{ .ty = err_ty, .bind = .none, .class = gp, .reg = &dest_reg },
            };
            try self.allocRegs(
                &read_args,
                &write_args,
                if (maybe_inst) |inst| .{
                    .corresponding_inst = inst,
                    .operand_mapping = &.{0},
                } else null,
            );

            const err_bit_offset = err_offset * 8;
            const err_bit_size: u32 = @intCast(err_ty.abiSize(mod) * 8);

            _ = try self.addInst(.{
                .tag = .ubfx, // errors are unsigned integers
                .data = .{ .rr_lsb_width = .{
                    .rd = dest_reg,
                    .rn = operand_reg,
                    .lsb = @intCast(err_bit_offset),
                    .width = @intCast(err_bit_size),
                } },
            });

            return MCValue{ .register = dest_reg };
        },
        .stack_argument_offset => |off| {
            return MCValue{ .stack_argument_offset = off + err_offset };
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
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_bind: ReadArg.Bind = .{ .inst = ty_op.operand };
        const error_union_ty = self.typeOf(ty_op.operand);

        break :result try self.errUnionErr(error_union_bind, error_union_ty, inst);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// Given an error union, returns the payload
fn errUnionPayload(
    self: *Self,
    error_union_bind: ReadArg.Bind,
    error_union_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const err_ty = error_union_ty.errorUnionSet(mod);
    const payload_ty = error_union_ty.errorUnionPayload(mod);
    if (err_ty.errorSetIsEmpty(mod)) {
        return try error_union_bind.resolveToMcv(self);
    }
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
        return MCValue.none;
    }

    const payload_offset: u32 = @intCast(errUnionPayloadOffset(payload_ty, mod));
    switch (try error_union_bind.resolveToMcv(self)) {
        .register => {
            var operand_reg: Register = undefined;
            var dest_reg: Register = undefined;

            const read_args = [_]ReadArg{
                .{ .ty = error_union_ty, .bind = error_union_bind, .class = gp, .reg = &operand_reg },
            };
            const write_args = [_]WriteArg{
                .{ .ty = err_ty, .bind = .none, .class = gp, .reg = &dest_reg },
            };
            try self.allocRegs(
                &read_args,
                &write_args,
                if (maybe_inst) |inst| .{
                    .corresponding_inst = inst,
                    .operand_mapping = &.{0},
                } else null,
            );

            const payload_bit_offset = payload_offset * 8;
            const payload_bit_size: u32 = @intCast(payload_ty.abiSize(mod) * 8);

            _ = try self.addInst(.{
                .tag = if (payload_ty.isSignedInt(mod)) Mir.Inst.Tag.sbfx else .ubfx,
                .data = .{ .rr_lsb_width = .{
                    .rd = dest_reg,
                    .rn = operand_reg,
                    .lsb = @intCast(payload_bit_offset),
                    .width = @intCast(payload_bit_size),
                } },
            });

            return MCValue{ .register = dest_reg };
        },
        .stack_argument_offset => |off| {
            return MCValue{ .stack_argument_offset = off + payload_offset };
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
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_bind: ReadArg.Bind = .{ .inst = ty_op.operand };
        const error_union_ty = self.typeOf(ty_op.operand);

        break :result try self.errUnionPayload(error_union_bind, error_union_ty, inst);
    };
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

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = ty_op.ty.toType();
        const error_ty = error_union_ty.errorUnionSet(mod);
        const payload_ty = error_union_ty.errorUnionPayload(mod);
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) break :result operand;

        const abi_size: u32 = @intCast(error_union_ty.abiSize(mod));
        const abi_align = error_union_ty.abiAlignment(mod);
        const stack_offset: u32 = @intCast(try self.allocMem(abi_size, abi_align, inst));
        const payload_off = errUnionPayloadOffset(payload_ty, mod);
        const err_off = errUnionErrorOffset(payload_ty, mod);
        try self.genSetStack(payload_ty, stack_offset - @as(u32, @intCast(payload_off)), operand);
        try self.genSetStack(error_ty, stack_offset - @as(u32, @intCast(err_off)), .{ .immediate = 0 });

        break :result MCValue{ .stack_offset = stack_offset };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = ty_op.ty.toType();
        const error_ty = error_union_ty.errorUnionSet(mod);
        const payload_ty = error_union_ty.errorUnionPayload(mod);
        const operand = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) break :result operand;

        const abi_size: u32 = @intCast(error_union_ty.abiSize(mod));
        const abi_align = error_union_ty.abiAlignment(mod);
        const stack_offset: u32 = @intCast(try self.allocMem(abi_size, abi_align, inst));
        const payload_off = errUnionPayloadOffset(payload_ty, mod);
        const err_off = errUnionErrorOffset(payload_ty, mod);
        try self.genSetStack(error_ty, stack_offset - @as(u32, @intCast(err_off)), operand);
        try self.genSetStack(payload_ty, stack_offset - @as(u32, @intCast(payload_off)), .undef);

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
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        break :result slicePtr(mcv);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .register => unreachable, // a slice doesn't fit in one register
            .stack_argument_offset => |off| {
                break :result MCValue{ .stack_argument_offset = off + 4 };
            },
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off - 4 };
            },
            .memory => |addr| {
                break :result MCValue{ .memory = addr + 4 };
            },
            else => unreachable, // invalid MCValue for a slice
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off - 4 };
            },
            else => {
                const lhs_bind: ReadArg.Bind = .{ .mcv = mcv };
                const rhs_bind: ReadArg.Bind = .{ .mcv = .{ .immediate = 4 } };

                break :result try self.addSub(.add, lhs_bind, rhs_bind, Type.usize, Type.usize, null);
            },
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(ty_op.operand);
        switch (mcv) {
            .dead, .unreach => unreachable,
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off };
            },
            else => {
                if (self.reuseOperand(inst, ty_op.operand, 0, mcv)) {
                    break :result mcv;
                } else {
                    break :result MCValue{ .register = try self.copyToTmpRegister(Type.usize, mcv) };
                }
            },
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn ptrElemVal(
    self: *Self,
    ptr_bind: ReadArg.Bind,
    index_bind: ReadArg.Bind,
    ptr_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = ptr_ty.childType(mod);
    const elem_size: u32 = @intCast(elem_ty.abiSize(mod));

    switch (elem_size) {
        1, 4 => {
            var base_reg: Register = undefined;
            var index_reg: Register = undefined;
            var dest_reg: Register = undefined;

            const read_args = [_]ReadArg{
                .{ .ty = ptr_ty, .bind = ptr_bind, .class = gp, .reg = &base_reg },
                .{ .ty = Type.usize, .bind = index_bind, .class = gp, .reg = &index_reg },
            };
            const write_args = [_]WriteArg{
                .{ .ty = elem_ty, .bind = .none, .class = gp, .reg = &dest_reg },
            };
            try self.allocRegs(
                &read_args,
                &write_args,
                if (maybe_inst) |inst| .{
                    .corresponding_inst = inst,
                    .operand_mapping = &.{ 0, 1 },
                } else null,
            );

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
                    .rt = dest_reg,
                    .rn = base_reg,
                    .offset = .{ .offset = Instruction.Offset.reg(index_reg, .{ .lsl = shift }) },
                } },
            });

            return MCValue{ .register = dest_reg };
        },
        else => {
            const addr = try self.ptrArithmetic(.ptr_add, ptr_bind, index_bind, ptr_ty, Type.usize, null);

            const dest = try self.allocRegOrMem(elem_ty, true, maybe_inst);
            try self.load(dest, addr, ptr_ty);
            return dest;
        },
    }
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const slice_ty = self.typeOf(bin_op.lhs);
    const result: MCValue = if (!slice_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = slice_ty.slicePtrFieldType(mod);

        const slice_mcv = try self.resolveInst(bin_op.lhs);
        const base_mcv = slicePtr(slice_mcv);

        const base_bind: ReadArg.Bind = .{ .mcv = base_mcv };
        const index_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };

        break :result try self.ptrElemVal(base_bind, index_bind, ptr_ty, inst);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const slice_mcv = try self.resolveInst(extra.lhs);
        const base_mcv = slicePtr(slice_mcv);

        const base_bind: ReadArg.Bind = .{ .mcv = base_mcv };
        const index_bind: ReadArg.Bind = .{ .inst = extra.rhs };

        const slice_ty = self.typeOf(extra.lhs);
        const index_ty = self.typeOf(extra.rhs);

        const addr = try self.ptrArithmetic(.ptr_add, base_bind, index_bind, slice_ty, index_ty, null);
        break :result addr;
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn arrayElemVal(
    self: *Self,
    array_bind: ReadArg.Bind,
    index_bind: ReadArg.Bind,
    array_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = array_ty.childType(mod);

    const mcv = try array_bind.resolveToMcv(self);
    switch (mcv) {
        .stack_offset,
        .memory,
        .stack_argument_offset,
        => {
            const ptr_to_mcv = switch (mcv) {
                .stack_offset => |off| MCValue{ .ptr_stack_offset = off },
                .memory => |addr| MCValue{ .immediate = @intCast(addr) },
                .stack_argument_offset => |off| blk: {
                    const reg = try self.register_manager.allocReg(null, gp);

                    _ = try self.addInst(.{
                        .tag = .ldr_ptr_stack_argument,
                        .data = .{ .r_stack_offset = .{
                            .rt = reg,
                            .stack_offset = off,
                        } },
                    });

                    break :blk MCValue{ .register = reg };
                },
                else => unreachable,
            };
            const ptr_to_mcv_lock: ?RegisterLock = switch (ptr_to_mcv) {
                .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                else => null,
            };
            defer if (ptr_to_mcv_lock) |lock| self.register_manager.unlockReg(lock);

            const base_bind: ReadArg.Bind = .{ .mcv = ptr_to_mcv };

            const ptr_ty = try mod.singleMutPtrType(elem_ty);

            return try self.ptrElemVal(base_bind, index_bind, ptr_ty, maybe_inst);
        },
        else => return self.fail("TODO implement array_elem_val for {}", .{mcv}),
    }
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const array_bind: ReadArg.Bind = .{ .inst = bin_op.lhs };
        const index_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };
        const array_ty = self.typeOf(bin_op.lhs);

        break :result try self.arrayElemVal(array_bind, index_bind, array_ty, inst);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const ptr_ty = self.typeOf(bin_op.lhs);
    const result: MCValue = if (!ptr_ty.isVolatilePtr(mod) and self.liveness.isUnused(inst)) .dead else result: {
        const base_bind: ReadArg.Bind = .{ .inst = bin_op.lhs };
        const index_bind: ReadArg.Bind = .{ .inst = bin_op.rhs };

        break :result try self.ptrElemVal(base_bind, index_bind, ptr_ty, inst);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_bind: ReadArg.Bind = .{ .inst = extra.lhs };
        const index_bind: ReadArg.Bind = .{ .inst = extra.rhs };

        const ptr_ty = self.typeOf(extra.lhs);
        const index_ty = self.typeOf(extra.rhs);

        const addr = try self.ptrArithmetic(.ptr_add, ptr_bind, index_bind, ptr_ty, index_ty, null);
        break :result addr;
    };
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
    _ = ty_op;
    return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airCtz for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airAbs(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airAbs for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airByteSwap for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
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
    branch.inst_table.putAssumeCapacity(operand.toIndex().?, .dead);

    return true;
}

fn load(self: *Self, dst_mcv: MCValue, ptr: MCValue, ptr_ty: Type) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const elem_ty = ptr_ty.childType(mod);
    const elem_size: u32 = @intCast(elem_ty.abiSize(mod));

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
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm });
        },
        .ptr_stack_offset => |off| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off });
        },
        .register => |reg| {
            const reg_lock = self.register_manager.lockReg(reg);
            defer if (reg_lock) |reg_locked| self.register_manager.unlockReg(reg_locked);

            switch (dst_mcv) {
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
                else => unreachable, // attempting to load into non-register or non-stack MCValue
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

        const dest_mcv: MCValue = blk: {
            const ptr_fits_dest = elem_ty.abiSize(mod) <= 4;
            if (ptr_fits_dest and self.reuseOperand(inst, ty_op.operand, 0, ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk ptr;
            } else {
                break :blk try self.allocRegOrMem(elem_ty, true, inst);
            }
        };
        try self.load(dest_mcv, ptr, self.typeOf(ty_op.operand));

        break :result dest_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    const mod = self.bin_file.comp.module.?;
    const elem_size: u32 = @intCast(value_ty.abiSize(mod));

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
                .undef => {
                    try self.genSetReg(value_ty, addr_reg, value);
                },
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
                            .memory => |addr| try self.genSetReg(ptr_ty, src_reg, .{ .immediate = @intCast(addr) }),
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

fn structFieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, index: u32) !MCValue {
    return if (self.liveness.isUnused(inst)) .dead else result: {
        const mod = self.bin_file.comp.module.?;
        const mcv = try self.resolveInst(operand);
        const ptr_ty = self.typeOf(operand);
        const struct_ty = ptr_ty.childType(mod);
        const struct_field_offset: u32 = @intCast(struct_ty.structFieldOffset(index, mod));
        switch (mcv) {
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off - struct_field_offset };
            },
            else => {
                const lhs_bind: ReadArg.Bind = .{ .mcv = mcv };
                const rhs_bind: ReadArg.Bind = .{ .mcv = .{ .immediate = struct_field_offset } };

                break :result try self.addSub(.add, lhs_bind, rhs_bind, Type.usize, Type.usize, null);
            },
        }
    };
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;
    const mod = self.bin_file.comp.module.?;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(operand);
        const struct_ty = self.typeOf(operand);
        const struct_field_offset: u32 = @intCast(struct_ty.structFieldOffset(index, mod));
        const struct_field_ty = struct_ty.structFieldType(index, mod);

        switch (mcv) {
            .dead, .unreach => unreachable,
            .stack_argument_offset => |off| {
                break :result MCValue{ .stack_argument_offset = off + struct_field_offset };
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
                    try self.genSetReg(struct_field_ty, dest_reg, field);

                    break :result MCValue{ .register = dest_reg };
                }
            },
            .register => {
                var operand_reg: Register = undefined;
                var dest_reg: Register = undefined;

                const read_args = [_]ReadArg{
                    .{ .ty = struct_ty, .bind = .{ .mcv = mcv }, .class = gp, .reg = &operand_reg },
                };
                const write_args = [_]WriteArg{
                    .{ .ty = struct_field_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                };
                try self.allocRegs(
                    &read_args,
                    &write_args,
                    ReuseMetadata{
                        .corresponding_inst = inst,
                        .operand_mapping = &.{0},
                    },
                );

                const field_bit_offset = struct_field_offset * 8;
                const field_bit_size: u32 = @intCast(struct_field_ty.abiSize(mod) * 8);

                _ = try self.addInst(.{
                    .tag = if (struct_field_ty.isSignedInt(mod)) Mir.Inst.Tag.sbfx else .ubfx,
                    .data = .{ .rr_lsb_width = .{
                        .rd = dest_reg,
                        .rn = operand_reg,
                        .lsb = @intCast(field_bit_offset),
                        .width = @intCast(field_bit_size),
                    } },
                });

                break :result MCValue{ .register = dest_reg };
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const field_ptr = try self.resolveInst(extra.field_ptr);
        const struct_ty = ty_pl.ty.toType().childType(mod);

        if (struct_ty.zigTypeTag(mod) == .Union) {
            return self.fail("TODO implement @fieldParentPtr codegen for unions", .{});
        }

        const struct_field_offset: u32 = @intCast(struct_ty.structFieldOffset(extra.field_index, mod));
        switch (field_ptr) {
            .ptr_stack_offset => |off| {
                break :result MCValue{ .ptr_stack_offset = off + struct_field_offset };
            },
            else => {
                const lhs_bind: ReadArg.Bind = .{ .mcv = field_ptr };
                const rhs_bind: ReadArg.Bind = .{ .mcv = .{ .immediate = struct_field_offset } };

                break :result try self.addSub(.sub, lhs_bind, rhs_bind, Type.usize, Type.usize, null);
            },
        }
    };
    return self.finishAir(inst, result, .{ extra.field_ptr, .none, .none });
}

/// An argument to a Mir instruction which is read (and possibly also
/// written to) by the respective instruction
const ReadArg = struct {
    ty: Type,
    bind: Bind,
    class: RegisterManager.RegisterBitSet,
    reg: *Register,

    const Bind = union(enum) {
        inst: Air.Inst.Ref,
        mcv: MCValue,

        fn resolveToMcv(bind: Bind, function: *Self) InnerError!MCValue {
            return switch (bind) {
                .inst => |inst| try function.resolveInst(inst),
                .mcv => |mcv| mcv,
            };
        }

        fn resolveToImmediate(bind: Bind, function: *Self) InnerError!?u32 {
            switch (bind) {
                .inst => |inst| {
                    // TODO resolve independently of inst_table
                    const mcv = try function.resolveInst(inst);
                    switch (mcv) {
                        .immediate => |imm| return imm,
                        else => return null,
                    }
                },
                .mcv => |mcv| {
                    switch (mcv) {
                        .immediate => |imm| return imm,
                        else => return null,
                    }
                },
            }
        }
    };
};

/// An argument to a Mir instruction which is written to (but not read
/// from) by the respective instruction
const WriteArg = struct {
    ty: Type,
    bind: Bind,
    class: RegisterManager.RegisterBitSet,
    reg: *Register,

    const Bind = union(enum) {
        reg: Register,
        none: void,
    };
};

/// Holds all data necessary for enabling the potential reuse of
/// operand registers as destinations
const ReuseMetadata = struct {
    corresponding_inst: Air.Inst.Index,

    /// Maps every element index of read_args to the corresponding
    /// index in the Air instruction
    ///
    /// When the order of read_args corresponds exactly to the order
    /// of the inputs of the Air instruction, this would be e.g.
    /// &.{ 0, 1 }. However, when the order is not the same or some
    /// inputs to the Air instruction are omitted (e.g. when they can
    /// be represented as immediates to the Mir instruction),
    /// operand_mapping should reflect that fact.
    operand_mapping: []const Liveness.OperandInt,
};

/// Allocate a set of registers for use as arguments for a Mir
/// instruction
///
/// If the Mir instruction these registers are allocated for
/// corresponds exactly to a single Air instruction, populate
/// reuse_metadata in order to enable potential reuse of an operand as
/// the destination (provided that that operand dies in this
/// instruction).
///
/// Reusing an operand register as destination is the only time two
/// arguments may share the same register. In all other cases,
/// allocRegs guarantees that a register will never be allocated to
/// more than one argument.
///
/// Furthermore, allocReg guarantees that all arguments which are
/// already bound to registers before calling allocRegs will not
/// change their register binding. This is done by locking these
/// registers.
fn allocRegs(
    self: *Self,
    read_args: []const ReadArg,
    write_args: []const WriteArg,
    reuse_metadata: ?ReuseMetadata,
) InnerError!void {
    // Air instructions have exactly one output
    assert(!(reuse_metadata != null and write_args.len != 1)); // see note above

    // The operand mapping is a 1:1 mapping of read args to their
    // corresponding operand index in the Air instruction
    assert(!(reuse_metadata != null and reuse_metadata.?.operand_mapping.len != read_args.len)); // see note above

    const locks = try self.gpa.alloc(?RegisterLock, read_args.len + write_args.len);
    defer self.gpa.free(locks);
    const read_locks = locks[0..read_args.len];
    const write_locks = locks[read_args.len..];

    @memset(locks, null);
    defer for (locks) |lock| {
        if (lock) |locked_reg| self.register_manager.unlockReg(locked_reg);
    };

    // When we reuse a read_arg as a destination, the corresponding
    // MCValue of the read_arg will be set to .dead. In that case, we
    // skip allocating this read_arg.
    var reused_read_arg: ?usize = null;

    // Lock all args which are already allocated to registers
    for (read_args, 0..) |arg, i| {
        const mcv = try arg.bind.resolveToMcv(self);
        if (mcv == .register) {
            read_locks[i] = self.register_manager.lockReg(mcv.register);
        }
    }

    for (write_args, 0..) |arg, i| {
        if (arg.bind == .reg) {
            write_locks[i] = self.register_manager.lockReg(arg.bind.reg);
        }
    }

    // Allocate registers for all args which aren't allocated to
    // registers yet
    for (read_args, 0..) |arg, i| {
        const mcv = try arg.bind.resolveToMcv(self);
        if (mcv == .register) {
            arg.reg.* = mcv.register;
        } else {
            const track_inst: ?Air.Inst.Index = switch (arg.bind) {
                .inst => |inst| inst.toIndex().?,
                else => null,
            };
            arg.reg.* = try self.register_manager.allocReg(track_inst, arg.class);
            read_locks[i] = self.register_manager.lockReg(arg.reg.*);
        }
    }

    if (reuse_metadata != null) {
        const inst = reuse_metadata.?.corresponding_inst;
        const operand_mapping = reuse_metadata.?.operand_mapping;
        const arg = write_args[0];
        if (arg.bind == .reg) {
            arg.reg.* = arg.bind.reg;
        } else {
            reuse_operand: for (read_args, 0..) |read_arg, i| {
                if (read_arg.bind == .inst) {
                    const operand = read_arg.bind.inst;
                    const mcv = try self.resolveInst(operand);
                    if (mcv == .register and
                        std.meta.eql(arg.class, read_arg.class) and
                        self.reuseOperand(inst, operand, operand_mapping[i], mcv))
                    {
                        arg.reg.* = mcv.register;
                        write_locks[0] = null;
                        reused_read_arg = i;
                        break :reuse_operand;
                    }
                }
            } else {
                arg.reg.* = try self.register_manager.allocReg(inst, arg.class);
                write_locks[0] = self.register_manager.lockReg(arg.reg.*);
            }
        }
    } else {
        for (write_args, 0..) |arg, i| {
            if (arg.bind == .reg) {
                arg.reg.* = arg.bind.reg;
            } else {
                arg.reg.* = try self.register_manager.allocReg(null, arg.class);
                write_locks[i] = self.register_manager.lockReg(arg.reg.*);
            }
        }
    }

    // For all read_args which need to be moved from non-register to
    // register, perform the move
    for (read_args, 0..) |arg, i| {
        if (reused_read_arg) |j| {
            // Check whether this read_arg was reused
            if (i == j) continue;
        }

        const mcv = try arg.bind.resolveToMcv(self);
        if (mcv != .register) {
            if (arg.bind == .inst) {
                const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
                const inst = arg.bind.inst.toIndex().?;

                // Overwrite the MCValue associated with this inst
                branch.inst_table.putAssumeCapacity(inst, .{ .register = arg.reg.* });

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

            try self.genSetReg(arg.ty, arg.reg.*, mcv);
        }
    }
}

/// Wrapper around allocRegs and addInst tailored for specific Mir
/// instructions which are binary operations acting on two registers
///
/// Returns the destination register
fn binOpRegister(
    self: *Self,
    mir_tag: Mir.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    var lhs_reg: Register = undefined;
    var rhs_reg: Register = undefined;
    var dest_reg: Register = undefined;

    const read_args = [_]ReadArg{
        .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
        .{ .ty = rhs_ty, .bind = rhs_bind, .class = gp, .reg = &rhs_reg },
    };
    const write_args = [_]WriteArg{
        .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
    };
    try self.allocRegs(
        &read_args,
        &write_args,
        if (maybe_inst) |inst| .{
            .corresponding_inst = inst,
            .operand_mapping = &.{ 0, 1 },
        } else null,
    );

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .adds,
        .sub,
        .subs,
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

/// Wrapper around allocRegs and addInst tailored for specific Mir
/// instructions which are binary operations acting on a register and
/// an immediate
///
/// Returns the destination register
fn binOpImmediate(
    self: *Self,
    mir_tag: Mir.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_immediate: u32,
    lhs_ty: Type,
    lhs_and_rhs_swapped: bool,
    maybe_inst: ?Air.Inst.Index,
) !MCValue {
    var lhs_reg: Register = undefined;
    var dest_reg: Register = undefined;

    const read_args = [_]ReadArg{
        .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
    };
    const write_args = [_]WriteArg{
        .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
    };
    const operand_mapping: []const Liveness.OperandInt = if (lhs_and_rhs_swapped) &.{1} else &.{0};
    try self.allocRegs(
        &read_args,
        &write_args,
        if (maybe_inst) |inst| .{
            .corresponding_inst = inst,
            .operand_mapping = operand_mapping,
        } else null,
    );

    const mir_data: Mir.Inst.Data = switch (mir_tag) {
        .add,
        .adds,
        .sub,
        .subs,
        .@"and",
        .orr,
        .eor,
        => .{ .rr_op = .{
            .rd = dest_reg,
            .rn = lhs_reg,
            .op = Instruction.Operand.fromU32(rhs_immediate).?,
        } },
        .lsl,
        .asr,
        .lsr,
        => .{ .rr_shift = .{
            .rd = dest_reg,
            .rm = lhs_reg,
            .shift_amount = Instruction.ShiftAmount.imm(@intCast(rhs_immediate)),
        } },
        else => unreachable,
    };

    _ = try self.addInst(.{
        .tag = mir_tag,
        .data = mir_data,
    });

    return MCValue{ .register = dest_reg };
}

fn addSub(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                const lhs_immediate = try lhs_bind.resolveToImmediate(self);
                const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                // Only say yes if the operation is
                // commutative, i.e. we can swap both of the
                // operands
                const lhs_immediate_ok = switch (tag) {
                    .add => if (lhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false,
                    .sub => false,
                    else => unreachable,
                };
                const rhs_immediate_ok = switch (tag) {
                    .add,
                    .sub,
                    => if (rhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false,
                    else => unreachable,
                };

                const mir_tag: Mir.Inst.Tag = switch (tag) {
                    .add => .add,
                    .sub => .sub,
                    else => unreachable,
                };

                if (rhs_immediate_ok) {
                    return try self.binOpImmediate(mir_tag, lhs_bind, rhs_immediate.?, lhs_ty, false, maybe_inst);
                } else if (lhs_immediate_ok) {
                    // swap lhs and rhs
                    return try self.binOpImmediate(mir_tag, rhs_bind, lhs_immediate.?, rhs_ty, true, maybe_inst);
                } else {
                    return try self.binOpRegister(mir_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst);
                }
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn mul(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                // TODO add optimisations for multiplication
                // with immediates, for example a * 2 can be
                // lowered to a << 1
                return try self.binOpRegister(.mul, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst);
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn divFloat(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    _ = lhs_bind;
    _ = rhs_bind;
    _ = rhs_ty;
    _ = maybe_inst;

    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        else => unreachable,
    }
}

fn divTrunc(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                switch (int_info.signedness) {
                    .signed => {
                        return self.fail("TODO ARM signed integer division", .{});
                    },
                    .unsigned => {
                        const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                        if (rhs_immediate) |imm| {
                            if (std.math.isPowerOfTwo(imm)) {
                                const shift = std.math.log2_int(u32, imm);
                                return try self.binOpImmediate(.lsr, lhs_bind, shift, lhs_ty, false, maybe_inst);
                            } else {
                                return self.fail("TODO ARM integer division by constants", .{});
                            }
                        } else {
                            return self.fail("TODO ARM integer division", .{});
                        }
                    },
                }
            } else {
                return self.fail("TODO ARM integer division for integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn divFloor(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                switch (int_info.signedness) {
                    .signed => {
                        return self.fail("TODO ARM signed integer division", .{});
                    },
                    .unsigned => {
                        const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                        if (rhs_immediate) |imm| {
                            if (std.math.isPowerOfTwo(imm)) {
                                const shift = std.math.log2_int(u32, imm);
                                return try self.binOpImmediate(.lsr, lhs_bind, shift, lhs_ty, false, maybe_inst);
                            } else {
                                return self.fail("TODO ARM integer division by constants", .{});
                            }
                        } else {
                            return self.fail("TODO ARM integer division", .{});
                        }
                    },
                }
            } else {
                return self.fail("TODO ARM integer division for integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn divExact(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    _ = lhs_bind;
    _ = rhs_bind;
    _ = rhs_ty;
    _ = maybe_inst;

    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => return self.fail("TODO ARM div_exact", .{}),
        else => unreachable,
    }
}

fn rem(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                switch (int_info.signedness) {
                    .signed => {
                        return self.fail("TODO ARM signed integer mod", .{});
                    },
                    .unsigned => {
                        const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                        if (rhs_immediate) |imm| {
                            if (std.math.isPowerOfTwo(imm)) {
                                const log2 = std.math.log2_int(u32, imm);

                                var lhs_reg: Register = undefined;
                                var dest_reg: Register = undefined;

                                const read_args = [_]ReadArg{
                                    .{ .ty = lhs_ty, .bind = lhs_bind, .class = gp, .reg = &lhs_reg },
                                };
                                const write_args = [_]WriteArg{
                                    .{ .ty = lhs_ty, .bind = .none, .class = gp, .reg = &dest_reg },
                                };
                                try self.allocRegs(
                                    &read_args,
                                    &write_args,
                                    if (maybe_inst) |inst| .{
                                        .corresponding_inst = inst,
                                        .operand_mapping = &.{0},
                                    } else null,
                                );

                                try self.truncRegister(lhs_reg, dest_reg, int_info.signedness, log2);

                                return MCValue{ .register = dest_reg };
                            } else {
                                return self.fail("TODO ARM integer mod by constants", .{});
                            }
                        } else {
                            return self.fail("TODO ARM integer mod", .{});
                        }
                    },
                }
            } else {
                return self.fail("TODO ARM integer division for integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn modulo(
    self: *Self,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    _ = lhs_bind;
    _ = rhs_bind;
    _ = rhs_ty;
    _ = maybe_inst;

    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => return self.fail("TODO ARM mod", .{}),
        else => unreachable,
    }
}

fn wrappingArithmetic(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                // Generate an add/sub/mul
                const result: MCValue = switch (tag) {
                    .add_wrap => try self.addSub(.add, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst),
                    .sub_wrap => try self.addSub(.sub, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst),
                    .mul_wrap => try self.mul(lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst),
                    else => unreachable,
                };

                // Truncate if necessary
                const result_reg = result.register;
                if (int_info.bits < 32) {
                    try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                }

                return result;
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn bitwise(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            assert(lhs_ty.eql(rhs_ty, mod));
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                const lhs_immediate = try lhs_bind.resolveToImmediate(self);
                const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                const lhs_immediate_ok = if (lhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false;
                const rhs_immediate_ok = if (rhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false;

                const mir_tag: Mir.Inst.Tag = switch (tag) {
                    .bit_and => .@"and",
                    .bit_or => .orr,
                    .xor => .eor,
                    else => unreachable,
                };

                if (rhs_immediate_ok) {
                    return try self.binOpImmediate(mir_tag, lhs_bind, rhs_immediate.?, lhs_ty, false, maybe_inst);
                } else if (lhs_immediate_ok) {
                    // swap lhs and rhs
                    return try self.binOpImmediate(mir_tag, rhs_bind, lhs_immediate.?, rhs_ty, true, maybe_inst);
                } else {
                    return try self.binOpRegister(mir_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst);
                }
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn shiftExact(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                const rhs_immediate = try rhs_bind.resolveToImmediate(self);

                const mir_tag: Mir.Inst.Tag = switch (tag) {
                    .shl_exact => .lsl,
                    .shr_exact => switch (lhs_ty.intInfo(mod).signedness) {
                        .signed => Mir.Inst.Tag.asr,
                        .unsigned => Mir.Inst.Tag.lsr,
                    },
                    else => unreachable,
                };

                if (rhs_immediate) |imm| {
                    return try self.binOpImmediate(mir_tag, lhs_bind, imm, lhs_ty, false, maybe_inst);
                } else {
                    return try self.binOpRegister(mir_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst);
                }
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn shiftNormal(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Int => {
            const int_info = lhs_ty.intInfo(mod);
            if (int_info.bits <= 32) {
                // Generate a shl_exact/shr_exact
                const result: MCValue = switch (tag) {
                    .shl => try self.shiftExact(.shl_exact, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst),
                    .shr => try self.shiftExact(.shr_exact, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst),
                    else => unreachable,
                };

                // Truncate if necessary
                switch (tag) {
                    .shr => return result,
                    .shl => {
                        const result_reg = result.register;
                        if (int_info.bits < 32) {
                            try self.truncRegister(result_reg, result_reg, int_info.signedness, int_info.bits);
                        }

                        return result;
                    },
                    else => unreachable,
                }
            } else {
                return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
            }
        },
        else => unreachable,
    }
}

fn booleanOp(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Bool => {
            const lhs_immediate = try lhs_bind.resolveToImmediate(self);
            const rhs_immediate = try rhs_bind.resolveToImmediate(self);

            const mir_tag: Mir.Inst.Tag = switch (tag) {
                .bool_and => .@"and",
                .bool_or => .orr,
                else => unreachable,
            };

            if (rhs_immediate) |imm| {
                return try self.binOpImmediate(mir_tag, lhs_bind, imm, lhs_ty, false, maybe_inst);
            } else if (lhs_immediate) |imm| {
                // swap lhs and rhs
                return try self.binOpImmediate(mir_tag, rhs_bind, imm, rhs_ty, true, maybe_inst);
            } else {
                return try self.binOpRegister(mir_tag, lhs_bind, rhs_bind, lhs_ty, rhs_ty, maybe_inst);
            }
        },
        else => unreachable,
    }
}

fn ptrArithmetic(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs_bind: ReadArg.Bind,
    rhs_bind: ReadArg.Bind,
    lhs_ty: Type,
    rhs_ty: Type,
    maybe_inst: ?Air.Inst.Index,
) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;
    switch (lhs_ty.zigTypeTag(mod)) {
        .Pointer => {
            assert(rhs_ty.eql(Type.usize, mod));

            const ptr_ty = lhs_ty;
            const elem_ty = switch (ptr_ty.ptrSize(mod)) {
                .One => ptr_ty.childType(mod).childType(mod), // ptr to array, so get array element type
                else => ptr_ty.childType(mod),
            };
            const elem_size: u32 = @intCast(elem_ty.abiSize(mod));

            const base_tag: Air.Inst.Tag = switch (tag) {
                .ptr_add => .add,
                .ptr_sub => .sub,
                else => unreachable,
            };

            if (elem_size == 1) {
                return try self.addSub(base_tag, lhs_bind, rhs_bind, Type.usize, Type.usize, maybe_inst);
            } else {
                // convert the offset into a byte offset by
                // multiplying it with elem_size
                const imm_bind = ReadArg.Bind{ .mcv = .{ .immediate = elem_size } };

                const offset = try self.mul(rhs_bind, imm_bind, Type.usize, Type.usize, null);
                const offset_bind = ReadArg.Bind{ .mcv = offset };

                const addr = try self.addSub(base_tag, lhs_bind, offset_bind, Type.usize, Type.usize, null);
                return addr;
            }
        },
        else => unreachable,
    }
}

fn genLdrRegister(self: *Self, dest_reg: Register, addr_reg: Register, ty: Type) !void {
    const mod = self.bin_file.comp.module.?;
    const abi_size = ty.abiSize(mod);

    const tag: Mir.Inst.Tag = switch (abi_size) {
        1 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsb else .ldrb,
        2 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsh else .ldrh,
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
        1 => if (ty.isSignedInt(mod)) rr_extra_offset else rr_offset,
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
    const mod = self.bin_file.comp.module.?;
    const abi_size = ty.abiSize(mod);

    const tag: Mir.Inst.Tag = switch (abi_size) {
        1 => .strb,
        2 => .strh,
        4 => .str,
        3 => return self.fail("TODO: genStrRegister for abi_size={}", .{abi_size}),
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
        1, 4 => rr_offset,
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
        .data = .{ .r_op_mov = .{
            .rd = count,
            .op = Instruction.Operand.imm(0, 0),
        } },
    });

    // loop:
    // cmp count, len
    _ = try self.addInst(.{
        .tag = .cmp,
        .data = .{ .r_op_cmp = .{
            .rn = count,
            .op = Instruction.Operand.reg(len, Instruction.Operand.Shift.none),
        } },
    });

    // bge end
    _ = try self.addInst(.{
        .tag = .b,
        .cond = .ge,
        .data = .{ .inst = @intCast(self.mir_instructions.len + 5) },
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
        .data = .{ .inst = @intCast(self.mir_instructions.len - 5) },
    });

    // end:
}

fn genInlineMemset(
    self: *Self,
    dst: MCValue,
    val: MCValue,
    len: MCValue,
) !void {
    const dst_reg = switch (dst) {
        .register => |r| r,
        else => try self.copyToTmpRegister(Type.manyptr_u8, dst),
    };
    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

    const val_reg = switch (val) {
        .register => |r| r,
        else => try self.copyToTmpRegister(Type.u8, val),
    };
    const val_reg_lock = self.register_manager.lockReg(val_reg);
    defer if (val_reg_lock) |lock| self.register_manager.unlockReg(lock);

    const len_reg = switch (len) {
        .register => |r| r,
        else => try self.copyToTmpRegister(Type.usize, len),
    };
    const len_reg_lock = self.register_manager.lockReg(len_reg);
    defer if (len_reg_lock) |lock| self.register_manager.unlockReg(lock);

    const count_reg = try self.register_manager.allocReg(null, gp);

    try self.genInlineMemsetCode(dst_reg, val_reg, len_reg, count_reg);
}

fn genInlineMemsetCode(
    self: *Self,
    dst: Register,
    val: Register,
    len: Register,
    count: Register,
) !void {
    // mov count, #0
    _ = try self.addInst(.{
        .tag = .mov,
        .data = .{ .r_op_mov = .{
            .rd = count,
            .op = Instruction.Operand.imm(0, 0),
        } },
    });

    // loop:
    // cmp count, len
    _ = try self.addInst(.{
        .tag = .cmp,
        .data = .{ .r_op_cmp = .{
            .rn = count,
            .op = Instruction.Operand.reg(len, Instruction.Operand.Shift.none),
        } },
    });

    // bge end
    _ = try self.addInst(.{
        .tag = .b,
        .cond = .ge,
        .data = .{ .inst = @intCast(self.mir_instructions.len + 4) },
    });

    // strb val, [src, count]
    _ = try self.addInst(.{
        .tag = .strb,
        .data = .{ .rr_offset = .{
            .rt = val,
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
        .data = .{ .inst = @intCast(self.mir_instructions.len - 4) },
    });

    // end:
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    // skip zero-bit arguments as they don't have a corresponding arg instruction
    var arg_index = self.arg_index;
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const mod = self.bin_file.comp.module.?;
    const ty = self.typeOfIndex(inst);
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const src_index = self.air.instructions.items(.data)[@intFromEnum(inst)].arg.src_index;
    const name = mod.getParamName(self.func_index, src_index);

    try self.dbg_info_relocs.append(self.gpa, .{
        .tag = tag,
        .ty = ty,
        .name = name,
        .mcv = self.args[arg_index],
    });

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else self.args[arg_index];
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airTrap(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .undefined_instruction,
        .data = .{ .nop = {} },
    });
    return self.finishAirBookkeeping();
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

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for arm", .{});
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);
    const ty = self.typeOf(callee);
    const mod = self.bin_file.comp.module.?;

    const fn_ty = switch (ty.zigTypeTag(mod)) {
        .Fn => ty,
        .Pointer => ty.childType(mod),
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

    // If returning by reference, r0 will contain the address of where
    // to put the result into. In that case, make sure that r0 remains
    // untouched by the parameter passing code
    const r0_lock: ?RegisterLock = if (info.return_value == .stack_offset) blk: {
        log.debug("airCall: return by reference", .{});
        const ret_ty = fn_ty.fnReturnType(mod);
        const ret_abi_size: u32 = @intCast(ret_ty.abiSize(mod));
        const ret_abi_align = ret_ty.abiAlignment(mod);
        const stack_offset = try self.allocMem(ret_abi_size, ret_abi_align, inst);

        const ptr_ty = try mod.singleMutPtrType(ret_ty);
        try self.register_manager.getReg(.r0, null);
        try self.genSetReg(ptr_ty, .r0, .{ .ptr_stack_offset = stack_offset });

        info.return_value = .{ .stack_offset = stack_offset };

        break :blk self.register_manager.lockRegAssumeUnused(.r0);
    } else null;
    defer if (r0_lock) |reg| self.register_manager.unlockReg(reg);

    // Make space for the arguments passed via the stack
    self.max_end_stack += info.stack_byte_count;

    for (info.args, 0..) |mc_arg, arg_i| {
        const arg = args[arg_i];
        const arg_ty = self.typeOf(arg);
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
                offset,
                arg_mcv,
            ),
            else => unreachable,
        }
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (try self.air.value(callee, mod)) |func_value| {
        if (func_value.getFunction(mod)) |func| {
            if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                const sym_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, func.owner_decl);
                const sym = elf_file.symbol(sym_index);
                _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);
                const got_addr: u32 = @intCast(sym.zigGotAddress(elf_file));
                try self.genSetReg(Type.usize, .lr, .{ .memory = got_addr });
            } else if (self.bin_file.cast(link.File.MachO)) |_| {
                unreachable; // unsupported architecture for MachO
            } else {
                return self.fail("TODO implement call on {s} for {s}", .{
                    @tagName(self.bin_file.tag),
                    @tagName(self.target.cpu.arch),
                });
            }
        } else if (func_value.getExternFunc(mod)) |_| {
            return self.fail("TODO implement calling extern functions", .{});
        } else {
            return self.fail("TODO implement calling bitcasted functions", .{});
        }
    } else {
        assert(ty.zigTypeTag(mod) == .Pointer);
        const mcv = try self.resolveInst(callee);

        try self.genSetReg(Type.usize, .lr, mcv);
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

    const result: MCValue = result: {
        switch (info.return_value) {
            .register => |reg| {
                if (RegisterManager.indexOfRegIntoTracked(reg) == null) {
                    // Save function return value into a tracked register
                    log.debug("airCall: copying {} as it is not tracked", .{reg});
                    const new_reg = try self.copyToTmpRegister(fn_ty.fnReturnType(mod), info.return_value);
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

fn airRet(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const ret_ty = self.fn_type.fnReturnType(mod);

    switch (self.ret_mcv) {
        .none => {},
        .immediate => {
            assert(ret_ty.isError(mod));
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
            const ptr_ty = try mod.singleMutPtrType(ret_ty);
            try self.store(self.ret_mcv, operand, ptr_ty, ret_ty);
        },
        else => unreachable, // invalid return result
    }

    // Just add space for an instruction, patch this later
    try self.exitlude_jump_relocs.append(self.gpa, try self.addNop());

    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ptr = try self.resolveInst(un_op);
    const ptr_ty = self.typeOf(un_op);
    const ret_ty = self.fn_type.fnReturnType(mod);

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
            const op_inst = un_op.toIndex().?;
            if (self.air.instructions.items(.tag)[@intFromEnum(op_inst)] != .ret_ptr) {
                const abi_size: u32 = @intCast(ret_ty.abiSize(mod));
                const abi_align = ret_ty.abiAlignment(mod);

                const offset = try self.allocMem(abi_size, abi_align, null);

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
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs_ty = self.typeOf(bin_op.lhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        break :blk try self.cmp(.{ .inst = bin_op.lhs }, .{ .inst = bin_op.rhs }, lhs_ty, op);
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn cmp(
    self: *Self,
    lhs: ReadArg.Bind,
    rhs: ReadArg.Bind,
    lhs_ty: Type,
    op: math.CompareOperator,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const int_ty = switch (lhs_ty.zigTypeTag(mod)) {
        .Optional => blk: {
            const payload_ty = lhs_ty.optionalChild(mod);
            if (!payload_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                break :blk Type.u1;
            } else if (lhs_ty.isPtrLikeOptional(mod)) {
                break :blk Type.usize;
            } else {
                return self.fail("TODO ARM cmp non-pointer optionals", .{});
            }
        },
        .Float => return self.fail("TODO ARM cmp floats", .{}),
        .Enum => lhs_ty.intTagType(mod),
        .Int => lhs_ty,
        .Bool => Type.u1,
        .Pointer => Type.usize,
        .ErrorSet => Type.u16,
        else => unreachable,
    };

    const int_info = int_ty.intInfo(mod);
    if (int_info.bits <= 32) {
        try self.spillCompareFlagsIfOccupied();

        var lhs_reg: Register = undefined;
        var rhs_reg: Register = undefined;

        const rhs_immediate = try rhs.resolveToImmediate(self);
        const rhs_immediate_ok = if (rhs_immediate) |imm| Instruction.Operand.fromU32(imm) != null else false;

        if (rhs_immediate_ok) {
            const read_args = [_]ReadArg{
                .{ .ty = int_ty, .bind = lhs, .class = gp, .reg = &lhs_reg },
            };
            try self.allocRegs(
                &read_args,
                &.{},
                null, // we won't be able to reuse a register as there are no write_regs
            );

            _ = try self.addInst(.{
                .tag = .cmp,
                .data = .{ .r_op_cmp = .{
                    .rn = lhs_reg,
                    .op = Instruction.Operand.fromU32(rhs_immediate.?).?,
                } },
            });
        } else {
            const read_args = [_]ReadArg{
                .{ .ty = int_ty, .bind = lhs, .class = gp, .reg = &lhs_reg },
                .{ .ty = int_ty, .bind = rhs, .class = gp, .reg = &rhs_reg },
            };
            try self.allocRegs(
                &read_args,
                &.{},
                null, // we won't be able to reuse a register as there are no write_regs
            );

            _ = try self.addInst(.{
                .tag = .cmp,
                .data = .{ .r_op_cmp = .{
                    .rn = lhs_reg,
                    .op = Instruction.Operand.reg(rhs_reg, Instruction.Operand.Shift.none),
                } },
            });
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
        .cond = undefined,
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
    const operand = pl_op.operand;
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const ty = self.typeOf(operand);
    const mcv = try self.resolveInst(operand);
    const name = self.air.nullTerminatedString(pl_op.payload);

    log.debug("airDbgVar: %{d}: {}, {}", .{ inst, ty.fmtDebug(), mcv });

    try self.dbg_info_relocs.append(self.gpa, .{
        .tag = tag,
        .ty = ty,
        .name = name,
        .mcv = mcv,
    });

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
                .data = .{ .r_op_cmp = .{
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
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond_inst = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc: Mir.Inst.Index = try self.condBr(cond_inst);

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
    for (else_keys, 0..) |else_key, else_idx| {
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
            var i: usize = self.branch_stack.items.len - 1;
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
            var i: usize = self.branch_stack.items.len - 1;
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
        var item = self.branch_stack.pop();
        item.deinit(self.gpa);
    }

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn isNull(
    self: *Self,
    operand_bind: ReadArg.Bind,
    operand_ty: Type,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    if (operand_ty.isPtrLikeOptional(mod)) {
        assert(operand_ty.abiSize(mod) == 4);

        const imm_bind: ReadArg.Bind = .{ .mcv = .{ .immediate = 0 } };
        return self.cmp(operand_bind, imm_bind, Type.usize, .eq);
    } else {
        return self.fail("TODO implement non-pointer optionals", .{});
    }
}

fn isNonNull(
    self: *Self,
    operand_bind: ReadArg.Bind,
    operand_ty: Type,
) !MCValue {
    const is_null_result = try self.isNull(operand_bind, operand_ty);
    assert(is_null_result.cpsr_flags == .eq);

    return MCValue{ .cpsr_flags = .ne };
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_bind: ReadArg.Bind = .{ .inst = un_op };
        const operand_ty = self.typeOf(un_op);

        break :result try self.isNull(operand_bind, operand_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.typeOf(un_op);
        const elem_ty = ptr_ty.childType(mod);

        const operand = try self.allocRegOrMem(elem_ty, true, null);
        try self.load(operand, operand_ptr, ptr_ty);

        break :result try self.isNull(.{ .mcv = operand }, elem_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_bind: ReadArg.Bind = .{ .inst = un_op };
        const operand_ty = self.typeOf(un_op);

        break :result try self.isNonNull(operand_bind, operand_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.typeOf(un_op);
        const elem_ty = ptr_ty.childType(mod);

        const operand = try self.allocRegOrMem(elem_ty, true, null);
        try self.load(operand, operand_ptr, ptr_ty);

        break :result try self.isNonNull(.{ .mcv = operand }, elem_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn isErr(
    self: *Self,
    error_union_bind: ReadArg.Bind,
    error_union_ty: Type,
) !MCValue {
    const mod = self.bin_file.comp.module.?;
    const error_type = error_union_ty.errorUnionSet(mod);

    if (error_type.errorSetIsEmpty(mod)) {
        return MCValue{ .immediate = 0 }; // always false
    }

    const error_mcv = try self.errUnionErr(error_union_bind, error_union_ty, null);
    return try self.cmp(.{ .mcv = error_mcv }, .{ .mcv = .{ .immediate = 0 } }, error_type, .gt);
}

fn isNonErr(
    self: *Self,
    error_union_bind: ReadArg.Bind,
    error_union_ty: Type,
) !MCValue {
    const is_err_result = try self.isErr(error_union_bind, error_union_ty);
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

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_bind: ReadArg.Bind = .{ .inst = un_op };
        const error_union_ty = self.typeOf(un_op);

        break :result try self.isErr(error_union_bind, error_union_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.typeOf(un_op);
        const elem_ty = ptr_ty.childType(mod);

        const operand = try self.allocRegOrMem(elem_ty, true, null);
        try self.load(operand, operand_ptr, ptr_ty);

        break :result try self.isErr(.{ .mcv = operand }, elem_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_bind: ReadArg.Bind = .{ .inst = un_op };
        const error_union_ty = self.typeOf(un_op);

        break :result try self.isNonErr(error_union_bind, error_union_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const ptr_ty = self.typeOf(un_op);
        const elem_ty = ptr_ty.childType(mod);

        const operand = try self.allocRegOrMem(elem_ty, true, null);
        try self.load(operand, operand_ptr, ptr_ty);

        break :result try self.isNonErr(.{ .mcv = operand }, elem_ty);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);
    const start_index: Mir.Inst.Index = @intCast(self.mir_instructions.len);

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
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition_ty = self.typeOf(pl_op.operand);
    const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
    const liveness = try self.liveness.getSwitchBr(
        self.gpa,
        inst,
        switch_br.data.cases_len + 1,
    );
    defer self.gpa.free(liveness.deaths);

    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items: []const Air.Inst.Ref = @ptrCast(self.air.extra[case.end..][0..case.data.items_len]);
        assert(items.len > 0);
        const case_body: []const Air.Inst.Index = @ptrCast(self.air.extra[case.end + items.len ..][0..case.data.body_len]);
        extra_index = case.end + items.len + case_body.len;

        // For every item, we compare it to condition and branch into
        // the prong if they are equal. After we compared to all
        // items, we branch into the next prong (or if no other prongs
        // exist out of the switch statement).
        //
        //             cmp condition, item1
        //             beq prong
        //             cmp condition, item2
        //             beq prong
        //             cmp condition, item3
        //             beq prong
        //             b out
        // prong:      ...
        //             ...
        // out:        ...
        const branch_into_prong_relocs = try self.gpa.alloc(u32, items.len);
        defer self.gpa.free(branch_into_prong_relocs);

        for (items, 0..) |item, idx| {
            const cmp_result = try self.cmp(.{ .inst = pl_op.operand }, .{ .inst = item }, condition_ty, .neq);
            branch_into_prong_relocs[idx] = try self.condBr(cmp_result);
        }

        const branch_away_from_prong_reloc = try self.addInst(.{
            .tag = .b,
            .data = .{ .inst = undefined }, // populated later through performReloc
        });

        for (branch_into_prong_relocs) |reloc| {
            try self.performReloc(reloc);
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

        try self.performReloc(branch_away_from_prong_reloc);
    }

    if (switch_br.data.else_body_len > 0) {
        const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra_index..][0..switch_br.data.else_body_len]);

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

    return self.finishAir(inst, .unreach, .{ pl_op.operand, .none, .none });
}

fn performReloc(self: *Self, inst: Mir.Inst.Index) !void {
    const tag = self.mir_instructions.items(.tag)[inst];
    switch (tag) {
        .b => self.mir_instructions.items(.data)[inst].inst = @intCast(self.mir_instructions.len),
        else => unreachable,
    }
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const branch = self.air.instructions.items(.data)[@intFromEnum(inst)].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const mod = self.bin_file.comp.module.?;
    const block_data = self.blocks.getPtr(block).?;

    if (self.typeOf(operand).hasRuntimeBits(mod)) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = switch (operand_mcv) {
                .none, .dead, .unreach => unreachable,
                .register, .stack_offset, .memory => operand_mcv,
                .immediate, .stack_argument_offset, .cpsr_flags => blk: {
                    const new_mcv = try self.allocRegOrMem(self.typeOfIndex(block), true, block);
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
    try block_data.relocs.append(self.gpa, try self.addInst(.{
        .tag = .b,
        .data = .{ .inst = undefined }, // populated later through performReloc
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
    const mod = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(mod));
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (abi_size) {
                1 => try self.genSetStack(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => try self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => try self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                else => try self.genInlineMemset(
                    .{ .ptr_stack_offset = stack_offset },
                    .{ .immediate = 0xaa },
                    .{ .immediate = abi_size },
                ),
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
                    } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.u32, MCValue{ .immediate = stack_offset }), .none);

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
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(stack_offset));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.u32, MCValue{ .immediate = stack_offset }));

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

            const wrapped_ty = ty.structFieldType(0, mod);
            try self.genSetStack(wrapped_ty, stack_offset, .{ .register = reg });

            const overflow_bit_ty = ty.structFieldType(1, mod);
            const overflow_bit_offset: u32 = @intCast(ty.structFieldOffset(1, mod));
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
                .data = .{ .r_op_mov = .{
                    .rd = cond_reg,
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
                const ptr_ty = try mod.singleMutPtrType(ty);

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
                    .memory => |addr| try self.genSetReg(ptr_ty, src_reg, .{ .immediate = @intCast(addr) }),
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
    const mod = self.bin_file.comp.module.?;
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
                .data = .{ .r_op_mov = .{
                    .rd = reg,
                    .op = zero,
                } },
            });

            // moveq reg, 1
            _ = try self.addInst(.{
                .tag = .mov,
                .cond = condition,
                .data = .{ .r_op_mov = .{
                    .rd = reg,
                    .op = one,
                } },
            });
        },
        .immediate => |x| {
            if (Instruction.Operand.fromU32(x)) |op| {
                _ = try self.addInst(.{
                    .tag = .mov,
                    .data = .{ .r_op_mov = .{
                        .rd = reg,
                        .op = op,
                    } },
                });
            } else if (Instruction.Operand.fromU32(~x)) |op| {
                _ = try self.addInst(.{
                    .tag = .mvn,
                    .data = .{ .r_op_mov = .{
                        .rd = reg,
                        .op = op,
                    } },
                });
            } else if (x <= math.maxInt(u16)) {
                if (Target.arm.featureSetHas(self.target.cpu.features, .has_v7)) {
                    _ = try self.addInst(.{
                        .tag = .movw,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @intCast(x),
                        } },
                    });
                } else {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .data = .{ .r_op_mov = .{
                            .rd = reg,
                            .op = Instruction.Operand.imm(@truncate(x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(x >> 8), 12),
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
                            .imm16 = @truncate(x),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .movt,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @truncate(x >> 16),
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
                        .data = .{ .r_op_mov = .{
                            .rd = reg,
                            .op = Instruction.Operand.imm(@truncate(x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(x >> 8), 12),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(x >> 16), 8),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(x >> 24), 4),
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
                .data = .{ .r_op_mov = .{
                    .rd = reg,
                    .op = Instruction.Operand.reg(src_reg, Instruction.Operand.Shift.none),
                } },
            });
        },
        .register_c_flag => unreachable, // doesn't fit into a register
        .register_v_flag => unreachable, // doesn't fit into a register
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = @intCast(addr) });
            try self.genLdrRegister(reg, reg, ty);
        },
        .stack_offset => |off| {
            // TODO: maybe addressing from sp instead of fp
            const abi_size: u32 = @intCast(ty.abiSize(mod));

            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsb else .ldrb,
                2 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsh else .ldrh,
                3, 4 => .ldr,
                else => unreachable,
            };

            const extra_offset = switch (abi_size) {
                1 => ty.isSignedInt(mod),
                2 => true,
                3, 4 => false,
                else => unreachable,
            };

            if (extra_offset) {
                const offset = if (off <= math.maxInt(u8)) blk: {
                    break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(off));
                } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.usize, MCValue{ .immediate = off }));

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
                    break :blk Instruction.Offset.imm(@intCast(off));
                } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.usize, MCValue{ .immediate = off }), .none);

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
            const abi_size = ty.abiSize(mod);

            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsb_stack_argument else .ldrb_stack_argument,
                2 => if (ty.isSignedInt(mod)) Mir.Inst.Tag.ldrsh_stack_argument else .ldrh_stack_argument,
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
    const mod = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(mod));
    switch (mcv) {
        .dead => unreachable,
        .none, .unreach => return,
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (abi_size) {
                1 => try self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => try self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => try self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .register => |reg| {
            switch (abi_size) {
                1, 4 => {
                    const offset = if (math.cast(u12, stack_offset)) |imm| blk: {
                        break :blk Instruction.Offset.imm(imm);
                    } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.u32, MCValue{ .immediate = stack_offset }), .none);

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
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(stack_offset));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.u32, MCValue{ .immediate = stack_offset }));

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
                const ptr_ty = try mod.singleMutPtrType(ty);

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
                    .memory => |addr| try self.genSetReg(ptr_ty, src_reg, .{ .immediate = @intCast(addr) }),
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
            .register,
            .register_c_flag,
            .register_v_flag,
            => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dest_ty = self.typeOfIndex(inst);
        const dest = try self.allocRegOrMem(dest_ty, true, inst);
        try self.setRegOrMem(dest_ty, dest, operand);
        break :result dest;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = self.typeOf(ty_op.operand);
        const ptr = try self.resolveInst(ty_op.operand);
        const array_ty = ptr_ty.childType(mod);
        const array_len: u32 = @intCast(array_ty.arrayLen(mod));

        const stack_offset = try self.allocMem(8, .@"8", inst);
        try self.genSetStack(ptr_ty, stack_offset, ptr);
        try self.genSetStack(Type.usize, stack_offset - 4, .{ .immediate = array_len });
        break :result MCValue{ .stack_offset = stack_offset };
    };
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
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    _ = inst;
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
        return self.fail("TODO implement airTagName for arm", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        _ = operand;
        return self.fail("TODO implement airErrorName for arm", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSplat for arm", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airSelect for arm", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airShuffle for arm", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement airReduce for arm", .{});
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
        return self.fail("TODO implement airAggregateInit for arm", .{});
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

    return self.fail("TODO implement airUnionInit for arm", .{});
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else {
        return self.fail("TODO implement airMulAdd for arm", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    const result: MCValue = result: {
        const error_union_bind: ReadArg.Bind = .{ .inst = pl_op.operand };
        const error_union_ty = self.typeOf(pl_op.operand);
        const mod = self.bin_file.comp.module.?;
        const error_union_size: u32 = @intCast(error_union_ty.abiSize(mod));
        const error_union_align = error_union_ty.abiAlignment(mod);

        // The error union will die in the body. However, we need the
        // error union after the body in order to extract the payload
        // of the error union, so we create a copy of it
        const error_union_copy = try self.allocMem(error_union_size, error_union_align, null);
        try self.genSetStack(error_union_ty, error_union_copy, try error_union_bind.resolveToMcv(self));

        const is_err_result = try self.isErr(error_union_bind, error_union_ty);
        const reloc = try self.condBr(is_err_result);

        try self.genBody(body);
        try self.performReloc(reloc);

        break :result try self.errUnionPayload(.{ .mcv = .{ .stack_offset = error_union_copy } }, error_union_ty, null);
    };
    return self.finishAir(inst, result, .{ pl_op.operand, .none, .none });
}

fn airTryPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    _ = body;
    return self.fail("TODO implement airTryPtr for arm", .{});
    // return self.finishAir(inst, result, .{ extra.data.ptr, .none, .none });
}

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    const mod = self.bin_file.comp.module.?;

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.typeOf(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime(mod) and !inst_ty.isError(mod))
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
            .immediate => |imm| .{ .immediate = @truncate(imm) },
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
    stack_align: u32,

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
            result.stack_align = 1;
            return result;
        },
        .C => {
            // ARM Procedure Call Standard, Chapter 6.5
            var ncrn: usize = 0; // Next Core Register Number
            var nsaa: u32 = 0; // Next stacked argument address

            if (ret_ty.zigTypeTag(mod) == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod)) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size: u32 = @intCast(ret_ty.abiSize(mod));
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

            for (fn_info.param_types.get(ip), result.args) |ty, *result_arg| {
                if (Type.fromInterned(ty).abiAlignment(mod) == .@"8")
                    ncrn = std.mem.alignForward(usize, ncrn, 2);

                const param_size: u32 = @intCast(Type.fromInterned(ty).abiSize(mod));
                if (std.math.divCeil(u32, param_size, 4) catch unreachable <= 4 - ncrn) {
                    if (param_size <= 4) {
                        result_arg.* = .{ .register = c_abi_int_param_regs[ncrn] };
                        ncrn += 1;
                    } else {
                        return self.fail("TODO MCValues with multiple registers", .{});
                    }
                } else if (ncrn < 4 and nsaa == 0) {
                    return self.fail("TODO MCValues split between registers and stack", .{});
                } else {
                    ncrn = 4;
                    if (Type.fromInterned(ty).abiAlignment(mod) == .@"8")
                        nsaa = std.mem.alignForward(u32, nsaa, 8);

                    result_arg.* = .{ .stack_argument_offset = nsaa };
                    nsaa += param_size;
                }
            }

            result.stack_byte_count = nsaa;
            result.stack_align = 8;
        },
        .Unspecified => {
            if (ret_ty.zigTypeTag(mod) == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime(mod) and !ret_ty.isError(mod)) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size: u32 = @intCast(ret_ty.abiSize(mod));
                if (ret_ty_size == 0) {
                    assert(ret_ty.isError(mod));
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

            for (fn_info.param_types.get(ip), result.args) |ty, *result_arg| {
                if (Type.fromInterned(ty).abiSize(mod) > 0) {
                    const param_size: u32 = @intCast(Type.fromInterned(ty).abiSize(mod));
                    const param_alignment = Type.fromInterned(ty).abiAlignment(mod);

                    stack_offset = @intCast(param_alignment.forward(stack_offset));
                    result_arg.* = .{ .stack_argument_offset = stack_offset };
                    stack_offset += param_size;
                } else {
                    result_arg.* = .{ .none = {} };
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
    const gpa = self.gpa;
    self.err_msg = try ErrorMsg.create(gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn failSymbol(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    const gpa = self.gpa;
    self.err_msg = try ErrorMsg.create(gpa, self.src_loc, format, args);
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
