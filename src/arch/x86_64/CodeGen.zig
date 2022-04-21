const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;
const trace = @import("../../tracy.zig").trace;

const Air = @import("../../Air.zig");
const Allocator = mem.Allocator;
const Compilation = @import("../../Compilation.zig");
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const DW = std.dwarf;
const ErrorMsg = Module.ErrorMsg;
const FnResult = @import("../../codegen.zig").FnResult;
const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Target = std.Target;
const Type = @import("../../type.zig").Type;
const TypedValue = @import("../../TypedValue.zig");
const Value = @import("../../value.zig").Value;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const Register = bits.Register;
const callee_preserved_regs = abi.callee_preserved_regs;
const caller_preserved_regs = abi.caller_preserved_regs;
const allocatable_registers = abi.allocatable_registers;
const c_abi_int_param_regs = abi.c_abi_int_param_regs;
const c_abi_int_return_regs = abi.c_abi_int_return_regs;

const InnerError = error{
    OutOfMemory,
    CodegenFail,
    OutOfRegisters,
};

const RegisterManager = RegisterManagerFn(Self, Register, &allocatable_registers);

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

compare_flags_inst: ?Air.Inst.Index = null,

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
    /// The value is in a target-specific register.
    register: Register,
    /// The value is a tuple { wrapped, overflow } where wrapped value is stored in the register,
    /// and the operation is an unsigned operation.
    register_overflow_unsigned: Register,
    /// The value is a tuple { wrapped, overflow } where wrapped value is stored in the register,
    /// and the operation is a signed operation.
    register_overflow_signed: Register,
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
    /// The value is in the compare flags assuming an unsigned operation,
    /// with this operator applied on top of it.
    compare_flags_unsigned: math.CompareOperator,
    /// The value is in the compare flags assuming a signed operation,
    /// with this operator applied on top of it.
    compare_flags_signed: math.CompareOperator,

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
            .compare_flags_unsigned,
            .compare_flags_signed,
            .ptr_stack_offset,
            .undef,
            .register_overflow_unsigned,
            .register_overflow_signed,
            => false,

            .register,
            .stack_offset,
            => true,
        };
    }

    fn usesCompareFlags(mcv: MCValue) bool {
        return switch (mcv) {
            .compare_flags_unsigned,
            .compare_flags_signed,
            .register_overflow_unsigned,
            .register_overflow_signed,
            => true,
            else => false,
        };
    }

    fn isRegister(mcv: MCValue) bool {
        return switch (mcv) {
            .register,
            .register_overflow_unsigned,
            .register_overflow_signed,
            => true,
            else => false,
        };
    }

    fn freezeIfRegister(mcv: MCValue, mgr: *RegisterManager) void {
        switch (mcv) {
            .register,
            .register_overflow_signed,
            .register_overflow_unsigned,
            => |reg| {
                mgr.freezeRegs(&.{reg});
            },
            else => {},
        }
    }

    fn unfreezeIfRegister(mcv: MCValue, mgr: *RegisterManager) void {
        switch (mcv) {
            .register,
            .register_overflow_signed,
            .register_overflow_unsigned,
            => |reg| {
                mgr.unfreezeRegs(&.{reg});
            },
            else => {},
        }
    }

    fn asRegister(mcv: MCValue) ?Register {
        return switch (mcv) {
            .register,
            .register_overflow_signed,
            .register_overflow_unsigned,
            => |reg| reg,
            else => null,
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

    if (builtin.mode == .Debug and bin_file.options.module.?.comp.verbose_mir) {
        const w = std.io.getStdErr().writer();
        w.print("# Begin Function MIR: {s}:\n", .{fn_owner_decl.name}) catch {};
        const PrintMir = @import("PrintMir.zig");
        const print = PrintMir{
            .mir = mir,
            .bin_file = bin_file,
        };
        print.printMir(w, function.mir_to_air_map, air) catch {}; // we don't care if the debug printing fails
        w.print("# End Function MIR: {s}\n\n", .{fn_owner_decl.name}) catch {};
    }

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
            .ops = (Mir.Ops{
                .reg1 = .rbp,
            }).encode(),
            .data = undefined, // unused for push reg,
        });
        _ = try self.addInst(.{
            .tag = .mov,
            .ops = (Mir.Ops{
                .reg1 = .rbp,
                .reg2 = .rsp,
            }).encode(),
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
            const ptr_ty = Type.usize;
            const abi_size = @intCast(u32, ptr_ty.abiSize(self.target.*));
            const abi_align = ptr_ty.abiAlignment(self.target.*);
            const stack_offset = mem.alignForwardGeneric(u32, self.next_stack_offset + abi_size, abi_align);
            self.next_stack_offset = stack_offset;
            self.max_end_stack = @maximum(self.max_end_stack, self.next_stack_offset);
            try self.genSetStack(ptr_ty, @intCast(i32, stack_offset), MCValue{ .register = .rdi }, .{});
            self.ret_mcv = MCValue{ .stack_offset = @intCast(i32, stack_offset) };
            log.debug("gen: spilling .rdi to stack at offset {}", .{stack_offset});
        }

        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .ops = undefined,
            .data = undefined,
        });

        // push the callee_preserved_regs that were used
        const backpatch_push_callee_preserved_regs_i = try self.addInst(.{
            .tag = .push_regs_from_callee_preserved_regs,
            .ops = (Mir.Ops{
                .reg1 = .rbp,
            }).encode(),
            .data = .{ .payload = undefined }, // to be backpatched
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

        // calculate the data for callee_preserved_regs to be pushed and popped
        const callee_preserved_regs_payload = blk: {
            var data = Mir.RegsToPushOrPop{
                .regs = 0,
                .disp = mem.alignForwardGeneric(u32, self.next_stack_offset, 8),
            };
            var disp = data.disp + 8;
            inline for (callee_preserved_regs) |reg, i| {
                if (self.register_manager.isRegAllocated(reg)) {
                    data.regs |= 1 << @intCast(u5, i);
                    self.max_end_stack += 8;
                    disp += 8;
                }
            }
            break :blk try self.addExtra(data);
        };

        const data = self.mir_instructions.items(.data);
        // backpatch the push instruction
        data[backpatch_push_callee_preserved_regs_i].payload = callee_preserved_regs_payload;
        // pop the callee_preserved_regs
        _ = try self.addInst(.{
            .tag = .pop_regs_from_callee_preserved_regs,
            .ops = (Mir.Ops{
                .reg1 = .rbp,
            }).encode(),
            .data = .{ .payload = callee_preserved_regs_payload },
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
            .ops = (Mir.Ops{
                .reg1 = .rbp,
            }).encode(),
            .data = undefined,
        });

        _ = try self.addInst(.{
            .tag = .ret,
            .ops = (Mir.Ops{
                .flags = 0b11,
            }).encode(),
            .data = undefined,
        });

        // Adjust the stack
        if (self.max_end_stack > math.maxInt(i32)) {
            return self.failSymbol("too much stack used in call parameters", .{});
        }
        // TODO we should reuse this mechanism to align the stack when calling any function even if
        // we do not pass any args on the stack BUT we still push regs to stack with `push` inst.
        const aligned_stack_end = @intCast(u32, mem.alignForward(self.max_end_stack, self.stack_align));
        if (aligned_stack_end > 0) {
            self.mir_instructions.set(backpatch_stack_sub, .{
                .tag = .sub,
                .ops = (Mir.Ops{
                    .reg1 = .rsp,
                }).encode(),
                .data = .{ .imm = aligned_stack_end },
            });
            self.mir_instructions.set(backpatch_stack_add, .{
                .tag = .add,
                .ops = (Mir.Ops{
                    .reg1 = .rsp,
                }).encode(),
                .data = .{ .imm = aligned_stack_end },
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
            .add             => try self.airAdd(inst),
            .addwrap         => try self.airAdd(inst),
            .add_sat         => try self.airAddSat(inst),
            .sub             => try self.airSub(inst),
            .subwrap         => try self.airSub(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul             => try self.airMul(inst),
            .mulwrap         => try self.airMul(inst),
            .mul_sat         => try self.airMulSat(inst),
            .rem             => try self.airRem(inst),
            .mod             => try self.airMod(inst),
            .shl, .shl_exact => try self.airShl(inst),
            .shl_sat         => try self.airShlSat(inst),
            .min             => try self.airMin(inst),
            .max             => try self.airMax(inst),
            .ptr_add         => try self.airPtrAdd(inst),
            .ptr_sub         => try self.airPtrSub(inst),
            .slice           => try self.airSlice(inst),

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

            .wrap_optional         => try self.airWrapOptional(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
            .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

            .wasm_memory_size => unreachable,
            .wasm_memory_grow => unreachable,
            // zig fmt: on
        }

        assert(!self.register_manager.frozenRegsExist());

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
        .register_overflow_signed, .register_overflow_unsigned => |reg| {
            self.register_manager.freeReg(reg.to64());
            self.compare_flags_inst = null;
        },
        .compare_flags_signed, .compare_flags_unsigned => {
            self.compare_flags_inst = null;
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

        if (result.asRegister()) |reg| {
            // In some cases (such as bitcast), an operand
            // may be the same MCValue as the result. If
            // that operand died and was a register, it
            // was freed by processDeath. We have to
            // "re-allocate" the register.
            if (self.register_manager.isRegFree(reg)) {
                self.register_manager.getRegAssumeFree(reg, inst);
            }
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

    if (!elem_ty.hasRuntimeBits()) {
        return self.allocMem(inst, @sizeOf(usize), @alignOf(usize));
    }

    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = ptr_ty.ptrAlignment(self.target.*);
    return self.allocMem(inst, abi_size, abi_align);
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const elem_ty = self.air.typeOfIndex(inst);
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
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
            if (self.register_manager.tryAllocReg(inst)) |reg| {
                return MCValue{ .register = registerAlias(reg, abi_size) };
            }
        }
    }
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = @intCast(i32, stack_offset) };
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(inst, false);
    log.debug("spilling {d} to stack mcv {any}", .{ inst, stack_mcv });
    const reg_mcv = self.getResolvedInstValue(inst);
    assert(reg.to64() == reg_mcv.asRegister().?.to64());
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv, .{});
}

pub fn spillCompareFlagsIfOccupied(self: *Self) !void {
    if (self.compare_flags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save);
        assert(mcv.usesCompareFlags());

        const new_mcv = try self.allocRegOrMem(inst_to_save, true);
        try self.setRegOrMem(self.air.typeOfIndex(inst_to_save), new_mcv, mcv);
        log.debug("spilling {d} to mcv {any}", .{ inst_to_save, new_mcv });

        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        try branch.inst_table.put(self.gpa, inst_to_save, new_mcv);

        self.compare_flags_inst = null;
    }
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
/// WARNING make sure that the allocated register matches the returned MCValue from an instruction!
fn copyToRegisterWithInstTracking(self: *Self, reg_owner: Air.Inst.Index, ty: Type, mcv: MCValue) !MCValue {
    const reg = try self.register_manager.allocReg(reg_owner);
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

        operand.freezeIfRegister(&self.register_manager);
        defer operand.unfreezeIfRegister(&self.register_manager);

        const reg = try self.register_manager.allocReg(inst);
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

    operand.freezeIfRegister(&self.register_manager);
    defer operand.unfreezeIfRegister(&self.register_manager);

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
    const is_power_of_two = (dst_bit_size & (dst_bit_size - 1)) == 0;
    if (!is_power_of_two or dst_bit_size < 8) {
        const max_reg_bit_width = Register.rax.size();
        const shift = @intCast(u6, max_reg_bit_width - dst_ty.bitSize(self.target.*));
        const mask = (~@as(u64, 0)) >> shift;
        try self.genBinMathOpMir(.@"and", Type.usize, .{ .register = reg }, .{ .immediate = mask });

        if (src_ty.intInfo(self.target.*).signedness == .signed) {
            _ = try self.addInst(.{
                .tag = .sal,
                .ops = (Mir.Ops{
                    .reg1 = reg,
                    .flags = 0b10,
                }).encode(),
                .data = .{ .imm = shift },
            });
            _ = try self.addInst(.{
                .tag = .sar,
                .ops = (Mir.Ops{
                    .reg1 = reg,
                    .flags = 0b10,
                }).encode(),
                .data = .{ .imm = shift },
            });
        }
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        switch (operand) {
            .dead => unreachable,
            .unreach => unreachable,
            .compare_flags_unsigned => |op| {
                const r = MCValue{
                    .compare_flags_unsigned = switch (op) {
                        .gte => .lt,
                        .gt => .lte,
                        .neq => .eq,
                        .lt => .gte,
                        .lte => .gt,
                        .eq => .neq,
                    },
                };
                break :result r;
            },
            .compare_flags_signed => |op| {
                const r = MCValue{
                    .compare_flags_signed = switch (op) {
                        .gte => .lt,
                        .gt => .lte,
                        .neq => .eq,
                        .lt => .gte,
                        .lte => .gt,
                        .eq => .neq,
                    },
                };
                break :result r;
            },
            else => {},
        }
        break :result try self.genBinMathOp(inst, ty_op.operand, .bool_true);
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
        lhs.freezeIfRegister(&self.register_manager);
        defer lhs.unfreezeIfRegister(&self.register_manager);

        const lhs_reg = try self.copyToTmpRegister(ty, lhs);
        self.register_manager.freezeRegs(&.{lhs_reg});
        defer self.register_manager.unfreezeRegs(&.{lhs_reg});

        const rhs_mcv = try self.limitImmediateType(bin_op.rhs, i32);
        rhs_mcv.freezeIfRegister(&self.register_manager);
        defer rhs_mcv.unfreezeIfRegister(&self.register_manager);

        try self.genBinMathOpMir(.cmp, ty, .{ .register = lhs_reg }, rhs_mcv);

        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ty, rhs_mcv);
        _ = try self.addInst(.{
            .tag = if (signedness == .signed) .cond_mov_lt else .cond_mov_below,
            .ops = (Mir.Ops{
                .reg1 = dst_mcv.register,
                .reg2 = lhs_reg,
            }).encode(),
            .data = undefined,
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

fn genPtrBinMathOp(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    const dst_ty = self.air.typeOfIndex(inst);
    const elem_size = dst_ty.elemType2().abiSize(self.target.*);
    const ptr = try self.resolveInst(op_lhs);
    const offset = try self.resolveInst(op_rhs);
    const offset_ty = self.air.typeOf(op_rhs);

    offset.freezeIfRegister(&self.register_manager);
    defer offset.unfreezeIfRegister(&self.register_manager);

    const dst_mcv = blk: {
        if (self.reuseOperand(inst, op_lhs, 0, ptr)) {
            if (ptr.isMemory() or ptr.isRegister()) break :blk ptr;
        }
        break :blk MCValue{ .register = try self.copyToTmpRegister(dst_ty, ptr) };
    };

    dst_mcv.freezeIfRegister(&self.register_manager);
    defer dst_mcv.unfreezeIfRegister(&self.register_manager);

    const offset_mcv = blk: {
        if (self.reuseOperand(inst, op_rhs, 1, offset)) {
            if (offset.isRegister()) break :blk offset;
        }
        break :blk MCValue{ .register = try self.copyToTmpRegister(offset_ty, offset) };
    };

    offset_mcv.freezeIfRegister(&self.register_manager);
    defer offset_mcv.unfreezeIfRegister(&self.register_manager);

    try self.genIntMulComplexOpMir(offset_ty, offset_mcv, .{ .immediate = elem_size });

    const tag = self.air.instructions.items(.tag)[inst];
    switch (tag) {
        .ptr_add => try self.genBinMathOpMir(.add, dst_ty, dst_mcv, offset_mcv),
        .ptr_sub => try self.genBinMathOpMir(.sub, dst_ty, dst_mcv, offset_mcv),
        else => unreachable,
    }

    return dst_mcv;
}

fn airPtrAdd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genPtrBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrSub(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genPtrBinMathOp(inst, bin_op.lhs, bin_op.rhs);
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

fn airAdd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
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

/// Result is always a register.
fn genSubOp(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    const dst_ty = self.air.typeOf(op_lhs);

    const lhs = try self.resolveInst(op_lhs);
    lhs.freezeIfRegister(&self.register_manager);
    defer lhs.unfreezeIfRegister(&self.register_manager);

    const rhs = try self.resolveInst(op_rhs);
    rhs.freezeIfRegister(&self.register_manager);
    defer rhs.unfreezeIfRegister(&self.register_manager);

    const dst_mcv = blk: {
        if (self.reuseOperand(inst, op_lhs, 0, lhs) and lhs.isRegister()) {
            break :blk lhs;
        }
        break :blk try self.copyToRegisterWithInstTracking(inst, dst_ty, lhs);
    };

    dst_mcv.freezeIfRegister(&self.register_manager);
    defer dst_mcv.unfreezeIfRegister(&self.register_manager);

    const rhs_mcv = blk: {
        if (rhs.isMemory() or rhs.isRegister()) break :blk rhs;
        break :blk MCValue{ .register = try self.copyToTmpRegister(dst_ty, rhs) };
    };

    rhs_mcv.freezeIfRegister(&self.register_manager);
    defer rhs_mcv.unfreezeIfRegister(&self.register_manager);

    try self.genBinMathOpMir(.sub, dst_ty, dst_mcv, rhs_mcv);

    return dst_mcv;
}

fn airSub(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genSubOp(inst, bin_op.lhs, bin_op.rhs);
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

fn airMul(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOfIndex(inst);

        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement 'mul' for operands of dst type {}", .{ty.zigTypeTag()});
        }

        // Spill .rax and .rdx upfront to ensure we don't spill the operands too late.
        try self.register_manager.getReg(.rax, inst);
        try self.register_manager.getReg(.rdx, null);
        self.register_manager.freezeRegs(&.{ .rax, .rdx });
        defer self.register_manager.unfreezeRegs(&.{ .rax, .rdx });

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const signedness = ty.intInfo(self.target.*).signedness;
        try self.genIntMulDivOpMir(switch (signedness) {
            .signed => .imul,
            .unsigned => .mul,
        }, ty, signedness, lhs, rhs);
        break :result MCValue{ .register = .rax };
    };
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

fn airAddWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOf(bin_op.lhs);
    const signedness: std.builtin.Signedness = blk: {
        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement airAddWithOverflow for type {}", .{ty.fmtDebug()});
        }
        break :blk ty.intInfo(self.target.*).signedness;
    };

    const partial = try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    const result: MCValue = switch (signedness) {
        .signed => .{ .register_overflow_signed = partial.register },
        .unsigned => .{ .register_overflow_unsigned = partial.register },
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOf(bin_op.lhs);
    const signedness: std.builtin.Signedness = blk: {
        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement airSubWithOverflow for type {}", .{ty.fmtDebug()});
        }
        break :blk ty.intInfo(self.target.*).signedness;
    };

    const partial = try self.genSubOp(inst, bin_op.lhs, bin_op.rhs);
    const result: MCValue = switch (signedness) {
        .signed => .{ .register_overflow_signed = partial.register },
        .unsigned => .{ .register_overflow_unsigned = partial.register },
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);
        const signedness: std.builtin.Signedness = blk: {
            if (ty.zigTypeTag() != .Int) {
                return self.fail("TODO implement airMulWithOverflow for type {}", .{ty.fmtDebug()});
            }
            break :blk ty.intInfo(self.target.*).signedness;
        };

        // Spill .rax and .rdx upfront to ensure we don't spill the operands too late.
        try self.register_manager.getReg(.rax, inst);
        try self.register_manager.getReg(.rdx, null);
        self.register_manager.freezeRegs(&.{ .rax, .rdx });
        defer self.register_manager.unfreezeRegs(&.{ .rax, .rdx });

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        try self.genIntMulDivOpMir(switch (signedness) {
            .signed => .imul,
            .unsigned => .mul,
        }, ty, signedness, lhs, rhs);

        switch (signedness) {
            .signed => break :result MCValue{ .register_overflow_signed = .rax },
            .unsigned => break :result MCValue{ .register_overflow_unsigned = .rax },
        }
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airShlWithOverflow for {}", .{self.target.cpu.arch});
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

    try self.genSetReg(ty, .rax, lhs);

    switch (signedness) {
        .signed => {
            _ = try self.addInst(.{
                .tag = .cwd,
                .ops = (Mir.Ops{
                    .flags = 0b11,
                }).encode(),
                .data = undefined,
            });
        },
        .unsigned => {
            _ = try self.addInst(.{
                .tag = .xor,
                .ops = (Mir.Ops{
                    .reg1 = .rdx,
                    .reg2 = .rdx,
                }).encode(),
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
                .ops = (Mir.Ops{
                    .reg1 = reg,
                }).encode(),
                .data = undefined,
            });
        },
        .stack_offset => |off| {
            _ = try self.addInst(.{
                .tag = tag,
                .ops = (Mir.Ops{
                    .reg2 = .rbp,
                    .flags = switch (abi_size) {
                        1 => 0b00,
                        2 => 0b01,
                        4 => 0b10,
                        8 => 0b11,
                        else => unreachable,
                    },
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        else => unreachable,
    }
}

/// Clobbers .rax and .rdx registers.
fn genInlineIntDivFloor(self: *Self, ty: Type, lhs: MCValue, rhs: MCValue) !MCValue {
    const signedness = ty.intInfo(self.target.*).signedness;
    const dividend = switch (lhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, lhs),
    };
    self.register_manager.freezeRegs(&.{dividend});

    const divisor = switch (rhs) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ty, rhs),
    };
    self.register_manager.freezeRegs(&.{divisor});
    defer self.register_manager.unfreezeRegs(&.{ dividend, divisor });

    try self.genIntMulDivOpMir(switch (signedness) {
        .signed => .idiv,
        .unsigned => .div,
    }, Type.isize, signedness, .{ .register = dividend }, .{ .register = divisor });

    _ = try self.addInst(.{
        .tag = .xor,
        .ops = (Mir.Ops{
            .reg1 = divisor.to64(),
            .reg2 = dividend.to64(),
        }).encode(),
        .data = undefined,
    });
    _ = try self.addInst(.{
        .tag = .sar,
        .ops = (Mir.Ops{
            .reg1 = divisor.to64(),
            .flags = 0b10,
        }).encode(),
        .data = .{ .imm = 63 },
    });
    _ = try self.addInst(.{
        .tag = .@"test",
        .ops = (Mir.Ops{
            .reg1 = .rdx,
            .reg2 = .rdx,
        }).encode(),
        .data = undefined,
    });
    _ = try self.addInst(.{
        .tag = .cond_mov_eq,
        .ops = (Mir.Ops{
            .reg1 = divisor.to64(),
            .reg2 = .rdx,
        }).encode(),
        .data = undefined,
    });
    try self.genBinMathOpMir(.add, Type.isize, .{ .register = divisor.to64() }, .{ .register = .rax });
    return MCValue{ .register = divisor };
}

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const tag = self.air.instructions.items(.tag)[inst];
        const ty = self.air.typeOfIndex(inst);

        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement {} for operands of dst type {}", .{ tag, ty.zigTypeTag() });
        }

        if (tag == .div_float) {
            return self.fail("TODO implement {}", .{tag});
        }

        const signedness = ty.intInfo(self.target.*).signedness;

        // Spill .rax and .rdx upfront to ensure we don't spill the operands too late.
        const track_rax: ?Air.Inst.Index = blk: {
            if (signedness == .unsigned) break :blk inst;
            switch (tag) {
                .div_exact, .div_trunc => break :blk inst,
                else => break :blk null,
            }
        };
        try self.register_manager.getReg(.rax, track_rax);
        try self.register_manager.getReg(.rdx, null);
        self.register_manager.freezeRegs(&.{ .rax, .rdx });
        defer self.register_manager.unfreezeRegs(&.{ .rax, .rdx });

        const lhs = try self.resolveInst(bin_op.lhs);
        lhs.freezeIfRegister(&self.register_manager);
        defer lhs.unfreezeIfRegister(&self.register_manager);

        const rhs = blk: {
            const rhs = try self.resolveInst(bin_op.rhs);
            if (signedness == .signed) {
                switch (tag) {
                    .div_floor => {
                        rhs.freezeIfRegister(&self.register_manager);
                        defer rhs.unfreezeIfRegister(&self.register_manager);
                        break :blk try self.copyToRegisterWithInstTracking(inst, ty, rhs);
                    },
                    else => {},
                }
            }
            break :blk rhs;
        };
        rhs.freezeIfRegister(&self.register_manager);
        defer rhs.unfreezeIfRegister(&self.register_manager);

        if (signedness == .unsigned) {
            try self.genIntMulDivOpMir(.div, ty, signedness, lhs, rhs);
            break :result MCValue{ .register = .rax };
        }

        switch (tag) {
            .div_exact, .div_trunc => {
                try self.genIntMulDivOpMir(switch (signedness) {
                    .signed => .idiv,
                    .unsigned => .div,
                }, ty, signedness, lhs, rhs);
                break :result MCValue{ .register = .rax };
            },
            .div_floor => {
                break :result try self.genInlineIntDivFloor(ty, lhs, rhs);
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOfIndex(inst);
        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement .rem for operands of dst type {}", .{ty.zigTypeTag()});
        }
        // Spill .rax and .rdx upfront to ensure we don't spill the operands too late.
        try self.register_manager.getReg(.rax, null);
        try self.register_manager.getReg(.rdx, inst);
        self.register_manager.freezeRegs(&.{ .rax, .rdx });
        defer self.register_manager.unfreezeRegs(&.{ .rax, .rdx });

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        const signedness = ty.intInfo(self.target.*).signedness;
        try self.genIntMulDivOpMir(switch (signedness) {
            .signed => .idiv,
            .unsigned => .div,
        }, ty, signedness, lhs, rhs);
        break :result MCValue{ .register = .rdx };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOfIndex(inst);
        if (ty.zigTypeTag() != .Int) {
            return self.fail("TODO implement .mod for operands of dst type {}", .{ty.zigTypeTag()});
        }
        const signedness = ty.intInfo(self.target.*).signedness;

        // Spill .rax and .rdx upfront to ensure we don't spill the operands too late.
        try self.register_manager.getReg(.rax, null);
        try self.register_manager.getReg(.rdx, if (signedness == .unsigned) inst else null);
        self.register_manager.freezeRegs(&.{ .rax, .rdx });
        defer self.register_manager.unfreezeRegs(&.{ .rax, .rdx });

        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);

        switch (signedness) {
            .unsigned => {
                try self.genIntMulDivOpMir(switch (signedness) {
                    .signed => .idiv,
                    .unsigned => .div,
                }, ty, signedness, lhs, rhs);
                break :result MCValue{ .register = .rdx };
            },
            .signed => {
                const div_floor = try self.genInlineIntDivFloor(ty, lhs, rhs);
                try self.genIntMulComplexOpMir(ty, div_floor, rhs);

                const result = try self.copyToRegisterWithInstTracking(inst, ty, lhs);
                try self.genBinMathOpMir(.sub, ty, result, div_floor);

                break :result result;
            },
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitAnd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    const ty = self.air.typeOfIndex(inst);
    const tag = self.air.instructions.items(.tag)[inst];
    switch (tag) {
        .shl_exact => return self.fail("TODO implement {} for type {}", .{ tag, ty.fmtDebug() }),
        .shl => {},
        else => unreachable,
    }

    if (ty.zigTypeTag() != .Int) {
        return self.fail("TODO implement .shl for type {}", .{ty.fmtDebug()});
    }
    if (ty.abiSize(self.target.*) > 8) {
        return self.fail("TODO implement .shl for integers larger than 8 bytes", .{});
    }

    // TODO look into reusing the operands
    // TODO audit register allocation mechanics
    const shift = try self.resolveInst(bin_op.rhs);
    const shift_ty = self.air.typeOf(bin_op.rhs);

    blk: {
        switch (shift) {
            .register => |reg| {
                if (reg.to64() == .rcx) break :blk;
            },
            else => {},
        }
        try self.register_manager.getReg(.rcx, null);
        try self.genSetReg(shift_ty, .rcx, shift);
    }
    self.register_manager.freezeRegs(&.{.rcx});
    defer self.register_manager.unfreezeRegs(&.{.rcx});

    const value = try self.resolveInst(bin_op.lhs);
    value.freezeIfRegister(&self.register_manager);
    defer value.unfreezeIfRegister(&self.register_manager);

    const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ty, value);
    _ = try self.addInst(.{
        .tag = .sal,
        .ops = (Mir.Ops{
            .reg1 = dst_mcv.register,
            .flags = 0b01,
        }).encode(),
        .data = undefined,
    });

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement shr for {}", .{self.target.cpu.arch});
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
                try self.shiftRegister(result.register, @intCast(u8, shift));
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
    operand.freezeIfRegister(&self.register_manager);
    defer operand.unfreezeIfRegister(&self.register_manager);

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBits()) break :result operand;
        switch (operand) {
            .stack_offset => |off| {
                break :result MCValue{ .stack_offset = off };
            },
            .register => {
                // TODO reuse operand
                break :result try self.copyToRegisterWithInstTracking(inst, err_ty, operand);
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
    const payload_ty = err_union_ty.errorUnionPayload();
    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBits()) break :result MCValue.none;

        const operand = try self.resolveInst(ty_op.operand);
        operand.freezeIfRegister(&self.register_manager);
        defer operand.unfreezeIfRegister(&self.register_manager);

        const abi_align = err_union_ty.abiAlignment(self.target.*);
        const err_ty = err_union_ty.errorUnionSet();
        const err_abi_size = mem.alignForwardGeneric(u32, @intCast(u32, err_ty.abiSize(self.target.*)), abi_align);
        switch (operand) {
            .stack_offset => |off| {
                const offset = off - @intCast(i32, err_abi_size);
                break :result MCValue{ .stack_offset = offset };
            },
            .register => {
                // TODO reuse operand
                const shift = @intCast(u6, err_abi_size * @sizeOf(usize));
                const result = try self.copyToRegisterWithInstTracking(inst, err_union_ty, operand);
                try self.shiftRegister(result.register.to64(), shift);
                break :result MCValue{
                    .register = registerAlias(result.register, @intCast(u32, payload_ty.abiSize(self.target.*))),
                };
            },
            else => return self.fail("TODO implement unwrap_err_payload for {}", .{operand}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
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
        operand.freezeIfRegister(&self.register_manager);
        defer operand.unfreezeIfRegister(&self.register_manager);

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
    const error_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();
    const operand = try self.resolveInst(ty_op.operand);
    assert(payload_ty.hasRuntimeBits());

    const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
    const abi_align = error_union_ty.abiAlignment(self.target.*);
    const err_abi_size = @intCast(u32, error_ty.abiSize(self.target.*));
    const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
    const offset = mem.alignForwardGeneric(u32, err_abi_size, abi_align);
    try self.genSetStack(error_ty, stack_offset, .{ .immediate = 0 }, .{});
    try self.genSetStack(payload_ty, stack_offset - @intCast(i32, offset), operand, .{});

    return self.finishAir(inst, .{ .stack_offset = stack_offset }, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });
    }
    const error_union_ty = self.air.getRefType(ty_op.ty);
    const error_ty = error_union_ty.errorUnionSet();
    const payload_ty = error_union_ty.errorUnionPayload();
    const err = try self.resolveInst(ty_op.operand);
    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBits()) break :result err;

        const abi_size = @intCast(u32, error_union_ty.abiSize(self.target.*));
        const abi_align = error_union_ty.abiAlignment(self.target.*);
        const err_abi_size = @intCast(u32, error_ty.abiSize(self.target.*));
        const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
        const offset = mem.alignForwardGeneric(u32, err_abi_size, abi_align);
        try self.genSetStack(error_ty, stack_offset, err, .{});
        try self.genSetStack(payload_ty, stack_offset - @intCast(i32, offset), .undef, .{});
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
    const reg = try self.copyToTmpRegister(index_ty, index);
    try self.genIntMulComplexOpMir(index_ty, .{ .register = reg }, .{ .immediate = elem_size });
    return reg;
}

fn genSliceElemPtr(self: *Self, lhs: Air.Inst.Ref, rhs: Air.Inst.Ref) !MCValue {
    const slice_ty = self.air.typeOf(lhs);
    const slice_mcv = try self.resolveInst(lhs);
    slice_mcv.freezeIfRegister(&self.register_manager);
    defer slice_mcv.unfreezeIfRegister(&self.register_manager);

    const elem_ty = slice_ty.childType();
    const elem_size = elem_ty.abiSize(self.target.*);
    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);

    const index_ty = self.air.typeOf(rhs);
    const index_mcv = try self.resolveInst(rhs);
    index_mcv.freezeIfRegister(&self.register_manager);
    defer index_mcv.unfreezeIfRegister(&self.register_manager);

    const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_size);
    self.register_manager.freezeRegs(&.{offset_reg});
    defer self.register_manager.unfreezeRegs(&.{offset_reg});

    const addr_reg = try self.register_manager.allocReg(null);
    switch (slice_mcv) {
        .stack_offset => |off| {
            // mov reg, [rbp - 8]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                    .flags = 0b01,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, off)) },
            });
        },
        else => return self.fail("TODO implement slice_elem_ptr when slice is {}", .{slice_mcv}),
    }
    // TODO we could allocate register here, but need to expect addr register and potentially
    // offset register.
    try self.genBinMathOpMir(.add, slice_ptr_field_type, .{ .register = addr_reg.to64() }, .{
        .register = offset_reg.to64(),
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const array_ty = self.air.typeOf(bin_op.lhs);
        const array = try self.resolveInst(bin_op.lhs);
        array.freezeIfRegister(&self.register_manager);
        defer array.unfreezeIfRegister(&self.register_manager);

        const elem_ty = array_ty.childType();
        const elem_abi_size = elem_ty.abiSize(self.target.*);

        const index_ty = self.air.typeOf(bin_op.rhs);
        const index = try self.resolveInst(bin_op.rhs);
        index.freezeIfRegister(&self.register_manager);
        defer index.unfreezeIfRegister(&self.register_manager);

        const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
        self.register_manager.freezeRegs(&.{offset_reg});
        defer self.register_manager.unfreezeRegs(&.{offset_reg});

        const addr_reg = try self.register_manager.allocReg(null);
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
                    .ops = (Mir.Ops{
                        .reg1 = addr_reg.to64(),
                        .reg2 = .rbp,
                    }).encode(),
                    .data = .{ .imm = @bitCast(u32, -off) },
                });
            },
            .stack_offset => |off| {
                // lea reg, [rbp]
                _ = try self.addInst(.{
                    .tag = .lea,
                    .ops = (Mir.Ops{
                        .reg1 = addr_reg.to64(),
                        .reg2 = .rbp,
                    }).encode(),
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
        try self.genBinMathOpMir(.add, array_ty, .{ .register = addr_reg.to64() }, .{ .register = offset_reg.to64() });
        try self.load(dst_mcv, .{ .register = addr_reg.to64() }, array_ty);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else result: {
        // this is identical to the `airPtrElemPtr` codegen expect here an
        // additional `mov` is needed at the end to get the actual value

        const ptr_ty = self.air.typeOf(bin_op.lhs);
        const ptr = try self.resolveInst(bin_op.lhs);
        ptr.freezeIfRegister(&self.register_manager);
        defer ptr.unfreezeIfRegister(&self.register_manager);

        const elem_ty = ptr_ty.elemType2();
        const elem_abi_size = elem_ty.abiSize(self.target.*);
        const index_ty = self.air.typeOf(bin_op.rhs);
        const index = try self.resolveInst(bin_op.rhs);
        index.freezeIfRegister(&self.register_manager);
        defer index.unfreezeIfRegister(&self.register_manager);

        const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
        self.register_manager.freezeRegs(&.{offset_reg});
        defer self.register_manager.unfreezeRegs(&.{offset_reg});

        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, ptr);
        try self.genBinMathOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });
        if (elem_abi_size > 8) {
            return self.fail("TODO copy value with size {} from pointer", .{elem_abi_size});
        } else {
            // mov dst_mcv, [dst_mcv]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .flags = 0b01,
                    .reg1 = registerAlias(dst_mcv.register, @intCast(u32, elem_abi_size)),
                    .reg2 = dst_mcv.register,
                }).encode(),
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = self.air.typeOf(extra.lhs);
        const ptr = try self.resolveInst(extra.lhs);
        ptr.freezeIfRegister(&self.register_manager);
        defer ptr.unfreezeIfRegister(&self.register_manager);

        const elem_ty = ptr_ty.elemType2();
        const elem_abi_size = elem_ty.abiSize(self.target.*);
        const index_ty = self.air.typeOf(extra.rhs);
        const index = try self.resolveInst(extra.rhs);
        index.freezeIfRegister(&self.register_manager);
        defer index.unfreezeIfRegister(&self.register_manager);

        const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
        self.register_manager.freezeRegs(&.{offset_reg});
        defer self.register_manager.unfreezeRegs(&.{offset_reg});

        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, ptr);
        try self.genBinMathOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
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
    ptr.freezeIfRegister(&self.register_manager);
    defer ptr.unfreezeIfRegister(&self.register_manager);

    const tag = try self.resolveInst(bin_op.rhs);
    tag.freezeIfRegister(&self.register_manager);
    defer tag.unfreezeIfRegister(&self.register_manager);

    const adjusted_ptr: MCValue = if (layout.payload_size > 0 and layout.tag_align < layout.payload_align) blk: {
        // TODO reusing the operand
        const reg = try self.copyToTmpRegister(ptr_ty, ptr);
        try self.genBinMathOpMir(.add, ptr_ty, .{ .register = reg }, .{ .immediate = layout.payload_size });
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
    operand.freezeIfRegister(&self.register_manager);
    defer operand.unfreezeIfRegister(&self.register_manager);

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
                try self.shiftRegister(result.register.to64(), shift);
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
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .register_overflow_unsigned => unreachable,
        .register_overflow_signed => unreachable,
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
            self.register_manager.freezeRegs(&.{reg});
            defer self.register_manager.unfreezeRegs(&.{reg});

            switch (dst_mcv) {
                .dead => unreachable,
                .undef => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .register => |dst_reg| {
                    // mov dst_reg, [reg]
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @intCast(u32, abi_size)),
                            .reg2 = reg,
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = 0 },
                    });
                },
                .stack_offset => |off| {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null);
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
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, abi_size),
                    .flags = flags,
                }).encode(),
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
    _ = ptr_ty;
    const abi_size = value_ty.abiSize(self.target.*);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .register_overflow_unsigned => unreachable,
        .register_overflow_signed => unreachable,
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
            self.register_manager.freezeRegs(&.{reg});
            defer self.register_manager.unfreezeRegs(&.{reg});

            switch (value) {
                .none => unreachable,
                .undef => unreachable,
                .dead => unreachable,
                .unreach => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
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
                                .ops = (Mir.Ops{
                                    .reg1 = reg.to64(),
                                    .flags = switch (abi_size) {
                                        1 => 0b00,
                                        2 => 0b01,
                                        4 => 0b10,
                                        else => unreachable,
                                    },
                                }).encode(),
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
                            _ = try self.addInst(.{
                                .tag = .mov,
                                .ops = (Mir.Ops{
                                    .reg1 = reg.to64(),
                                    .reg2 = tmp_reg.to64(),
                                    .flags = 0b10,
                                }).encode(),
                                .data = .{ .imm = 0 },
                            });
                        },
                        else => {
                            return self.fail("TODO implement set pointee with immediate of ABI size {d}", .{abi_size});
                        },
                    }
                },
                .register => |src_reg| {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = reg.to64(),
                            .reg2 = registerAlias(src_reg, @intCast(u32, abi_size)),
                            .flags = 0b10,
                        }).encode(),
                        .data = .{ .imm = 0 },
                    });
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
            value.freezeIfRegister(&self.register_manager);
            defer value.unfreezeIfRegister(&self.register_manager);

            const addr_reg = try self.register_manager.allocReg(null);
            self.register_manager.freezeRegs(&.{addr_reg});
            defer self.register_manager.unfreezeRegs(&.{addr_reg});

            try self.loadMemPtrIntoRegister(addr_reg, ptr_ty, ptr);

            // to get the actual address of the value we want to modify we have to go through the GOT
            // mov reg, [reg]
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = addr_reg.to64(),
                    .reg2 = addr_reg.to64(),
                    .flags = 0b01,
                }).encode(),
                .data = .{ .imm = 0 },
            });

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
                        .ops = (Mir.Ops{
                            .reg1 = addr_reg.to64(),
                            .flags = flags,
                        }).encode(),
                        .data = .{ .payload = payload },
                    });
                },
                .register => |reg| {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = addr_reg.to64(),
                            .reg2 = reg,
                            .flags = 0b10,
                        }).encode(),
                        .data = .{ .imm = 0 },
                    });
                },
                .got_load,
                .direct_load,
                .memory,
                => {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null);
                        self.register_manager.freezeRegs(&.{tmp_reg});
                        defer self.register_manager.unfreezeRegs(&.{tmp_reg});

                        try self.loadMemPtrIntoRegister(tmp_reg, value_ty, value);

                        _ = try self.addInst(.{
                            .tag = .mov,
                            .ops = (Mir.Ops{
                                .reg1 = tmp_reg,
                                .reg2 = tmp_reg,
                                .flags = 0b01,
                            }).encode(),
                            .data = .{ .imm = 0 },
                        });
                        _ = try self.addInst(.{
                            .tag = .mov,
                            .ops = (Mir.Ops{
                                .reg1 = addr_reg.to64(),
                                .reg2 = tmp_reg,
                                .flags = 0b10,
                            }).encode(),
                            .data = .{ .imm = 0 },
                        });
                        return;
                    }

                    try self.genInlineMemcpy(.{ .register = addr_reg.to64() }, value, .{ .immediate = abi_size }, .{});
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
                self.register_manager.freezeRegs(&.{offset_reg});
                defer self.register_manager.unfreezeRegs(&.{offset_reg});

                const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, mcv);
                try self.genBinMathOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });
                break :result dst_mcv;
            },
            .ptr_stack_offset => |off| {
                const ptr_stack_offset = off - @intCast(i32, struct_field_offset);
                break :result MCValue{ .ptr_stack_offset = ptr_stack_offset };
            },
            .register => |reg| {
                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = struct_field_offset,
                });
                self.register_manager.freezeRegs(&.{offset_reg});
                defer self.register_manager.unfreezeRegs(&.{offset_reg});

                const can_reuse_operand = self.reuseOperand(inst, operand, 0, mcv);
                const result_reg = blk: {
                    if (can_reuse_operand) {
                        break :blk reg;
                    } else {
                        self.register_manager.freezeRegs(&.{reg});
                        const result_reg = try self.register_manager.allocReg(inst);
                        try self.genSetReg(ptr_ty, result_reg, mcv);
                        break :blk result_reg;
                    }
                };
                defer if (!can_reuse_operand) self.register_manager.unfreezeRegs(&.{reg});

                try self.genBinMathOpMir(.add, ptr_ty, .{ .register = result_reg }, .{ .register = offset_reg });
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(operand);
        const struct_ty = self.air.typeOf(operand);
        const struct_field_offset = struct_ty.structFieldOffset(index, self.target.*);
        const struct_field_ty = struct_ty.structFieldType(index);

        switch (mcv) {
            .stack_offset => |off| {
                const stack_offset = off - @intCast(i32, struct_field_offset);
                break :result MCValue{ .stack_offset = stack_offset };
            },
            .register => |reg| {
                self.register_manager.freezeRegs(&.{reg});
                defer self.register_manager.unfreezeRegs(&.{reg});

                const dst_mcv = blk: {
                    if (self.reuseOperand(inst, operand, 0, mcv)) {
                        break :blk mcv;
                    } else {
                        const dst_mcv = try self.copyToRegisterWithInstTracking(inst, Type.usize, .{
                            .register = reg.to64(),
                        });
                        break :blk dst_mcv;
                    }
                };
                dst_mcv.freezeIfRegister(&self.register_manager);
                defer dst_mcv.unfreezeIfRegister(&self.register_manager);

                // Shift by struct_field_offset.
                const shift = @intCast(u8, struct_field_offset * @sizeOf(usize));
                try self.shiftRegister(dst_mcv.register, shift);

                // Mask with reg.size() - struct_field_size
                const max_reg_bit_width = Register.rax.size();
                const mask_shift = @intCast(u6, (max_reg_bit_width - struct_field_ty.bitSize(self.target.*)));
                const mask = (~@as(u64, 0)) >> mask_shift;

                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinMathOpMir(.@"and", Type.usize, dst_mcv, .{ .register = tmp_reg });

                const signedness: std.builtin.Signedness = blk: {
                    if (struct_field_ty.zigTypeTag() != .Int) break :blk .unsigned;
                    break :blk struct_field_ty.intInfo(self.target.*).signedness;
                };
                const field_size = @intCast(u32, struct_field_ty.abiSize(self.target.*));
                if (signedness == .signed and field_size < 8) {
                    _ = try self.addInst(.{
                        .tag = .mov_sign_extend,
                        .ops = (Mir.Ops{
                            .reg1 = dst_mcv.register,
                            .reg2 = registerAlias(dst_mcv.register, field_size),
                        }).encode(),
                        .data = undefined,
                    });
                }

                break :result dst_mcv;
            },
            .register_overflow_unsigned,
            .register_overflow_signed,
            => |reg| {
                switch (index) {
                    0 => {
                        // Get wrapped value for overflow operation.
                        break :result MCValue{ .register = reg };
                    },
                    1 => {
                        // Get overflow bit.
                        mcv.freezeIfRegister(&self.register_manager);
                        defer mcv.unfreezeIfRegister(&self.register_manager);

                        const dst_reg = try self.register_manager.allocReg(inst);
                        const flags: u2 = switch (mcv) {
                            .register_overflow_unsigned => 0b10,
                            .register_overflow_signed => 0b00,
                            else => unreachable,
                        };
                        _ = try self.addInst(.{
                            .tag = .cond_set_byte_overflow,
                            .ops = (Mir.Ops{
                                .reg1 = dst_reg.to8(),
                                .flags = flags,
                            }).encode(),
                            .data = undefined,
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

/// Result is always a register.
fn genBinMathOp(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    const dst_ty = self.air.typeOf(op_lhs);

    const lhs = try self.resolveInst(op_lhs);
    lhs.freezeIfRegister(&self.register_manager);
    defer lhs.unfreezeIfRegister(&self.register_manager);

    const rhs = try self.resolveInst(op_rhs);
    rhs.freezeIfRegister(&self.register_manager);
    defer rhs.unfreezeIfRegister(&self.register_manager);

    var flipped: bool = false;
    const dst_mcv = blk: {
        if (self.reuseOperand(inst, op_lhs, 0, lhs) and lhs.isRegister()) {
            break :blk lhs;
        }
        if (self.reuseOperand(inst, op_rhs, 1, rhs) and rhs.isRegister()) {
            flipped = true;
            break :blk rhs;
        }
        break :blk try self.copyToRegisterWithInstTracking(inst, dst_ty, lhs);
    };
    dst_mcv.freezeIfRegister(&self.register_manager);
    defer dst_mcv.unfreezeIfRegister(&self.register_manager);

    const src_mcv = blk: {
        const mcv = if (flipped) lhs else rhs;
        if (mcv.isRegister() or mcv.isMemory()) break :blk mcv;
        break :blk MCValue{ .register = try self.copyToTmpRegister(dst_ty, mcv) };
    };
    src_mcv.freezeIfRegister(&self.register_manager);
    defer src_mcv.unfreezeIfRegister(&self.register_manager);

    const tag = self.air.instructions.items(.tag)[inst];
    switch (tag) {
        .add, .addwrap, .add_with_overflow => try self.genBinMathOpMir(.add, dst_ty, dst_mcv, src_mcv),
        .bool_or, .bit_or => try self.genBinMathOpMir(.@"or", dst_ty, dst_mcv, src_mcv),
        .bool_and, .bit_and => try self.genBinMathOpMir(.@"and", dst_ty, dst_mcv, src_mcv),
        .xor, .not => try self.genBinMathOpMir(.xor, dst_ty, dst_mcv, src_mcv),
        else => unreachable,
    }
    return dst_mcv;
}

fn genBinMathOpMir(self: *Self, mir_tag: Mir.Inst.Tag, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .register_overflow_unsigned => unreachable,
        .register_overflow_signed => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .register_overflow_unsigned => unreachable,
                .register_overflow_signed => unreachable,
                .ptr_stack_offset => {
                    self.register_manager.freezeRegs(&.{dst_reg});
                    defer self.register_manager.unfreezeRegs(&.{dst_reg});
                    const reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                    return self.genBinMathOpMir(mir_tag, dst_ty, dst_mcv, .{ .register = reg });
                },
                .register => |src_reg| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @divExact(src_reg.size(), 8)),
                            .reg2 = src_reg,
                        }).encode(),
                        .data = undefined,
                    });
                },
                .immediate => |imm| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, abi_size),
                        }).encode(),
                        .data = .{ .imm = @truncate(u32, imm) },
                    });
                },
                .memory,
                .got_load,
                .direct_load,
                .compare_flags_signed,
                .compare_flags_unsigned,
                => {
                    assert(abi_size <= 8);
                    self.register_manager.freezeRegs(&.{dst_reg});
                    defer self.register_manager.unfreezeRegs(&.{dst_reg});
                    const reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                    return self.genBinMathOpMir(mir_tag, dst_ty, dst_mcv, .{ .register = reg });
                },
                .stack_offset => |off| {
                    if (off > math.maxInt(i32)) {
                        return self.fail("stack offset too large", .{});
                    }
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }).encode(),
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
                .register_overflow_unsigned => unreachable,
                .register_overflow_signed => unreachable,
                .register => |src_reg| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = .rbp,
                            .reg2 = registerAlias(src_reg, abi_size),
                            .flags = 0b10,
                        }).encode(),
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
                        .ops = (Mir.Ops{
                            .reg1 = .rbp,
                            .flags = flags,
                        }).encode(),
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
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (signed)", .{});
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
fn genIntMulComplexOpMir(self: *Self, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .ptr_stack_offset => unreachable,
        .register_overflow_unsigned => unreachable,
        .register_overflow_signed => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => try self.genSetReg(dst_ty, dst_reg, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .register_overflow_unsigned => unreachable,
                .register_overflow_signed => unreachable,
                .register => |src_reg| {
                    // register, register
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = registerAlias(src_reg, abi_size),
                        }).encode(),
                        .data = undefined,
                    });
                },
                .immediate => |imm| {
                    // TODO take into account the type's ABI size when selecting the register alias
                    // register, immediate
                    if (math.minInt(i32) <= imm and imm <= math.maxInt(i32)) {
                        _ = try self.addInst(.{
                            .tag = .imul_complex,
                            .ops = (Mir.Ops{
                                .reg1 = dst_reg.to32(),
                                .reg2 = dst_reg.to32(),
                                .flags = 0b10,
                            }).encode(),
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
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = @bitCast(u32, -off) },
                    });
                },
                .memory => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .got_load, .direct_load => {
                    return self.fail("TODO implement x86 multiply source symbol at index in linker", .{});
                },
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 multiply source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 multiply source compare flag (signed)", .{});
                },
            }
        },
        .stack_offset => |off| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => return self.genSetStack(dst_ty, off, .undef, .{}),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .register_overflow_unsigned => unreachable,
                .register_overflow_signed => unreachable,
                .register => |src_reg| {
                    // copy dst to a register
                    const dst_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
                    // multiply into dst_reg
                    // register, register
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, abi_size),
                            .reg2 = registerAlias(src_reg, abi_size),
                        }).encode(),
                        .data = undefined,
                    });
                    // copy dst_reg back out
                    return self.genSetStack(dst_ty, off, MCValue{ .register = dst_reg }, .{});
                },
                .immediate => |imm| {
                    _ = imm;
                    return self.fail("TODO implement x86 multiply source immediate", .{});
                },
                .memory, .stack_offset => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .got_load, .direct_load => {
                    return self.fail("TODO implement x86 multiply source symbol at index in linker", .{});
                },
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 multiply source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 multiply source compare flag (signed)", .{});
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
        .tag = .brk,
        .ops = undefined,
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

    try self.spillCompareFlagsIfOccupied();

    for (caller_preserved_regs) |reg| {
        try self.register_manager.getReg(reg, null);
    }

    if (info.return_value == .stack_offset) {
        const ret_ty = fn_ty.fnReturnType();
        const ret_abi_size = @intCast(u32, ret_ty.abiSize(self.target.*));
        const ret_abi_align = @intCast(u32, ret_ty.abiAlignment(self.target.*));
        const stack_offset = @intCast(i32, try self.allocMem(inst, ret_abi_size, ret_abi_align));
        log.debug("airCall: return value on stack at offset {}", .{stack_offset});

        try self.register_manager.getReg(.rdi, null);
        try self.genSetReg(Type.usize, .rdi, .{ .ptr_stack_offset = stack_offset });
        self.register_manager.freezeRegs(&.{.rdi});

        info.return_value.stack_offset = stack_offset;
    }
    defer if (info.return_value == .stack_offset) self.register_manager.unfreezeRegs(&.{.rdi});

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
            .compare_flags_signed => unreachable,
            .compare_flags_unsigned => unreachable,
            .register_overflow_signed => unreachable,
            .register_overflow_unsigned => unreachable,
        }
    }

    if (info.stack_byte_count > 0) {
        // Adjust the stack
        _ = try self.addInst(.{
            .tag = .sub,
            .ops = (Mir.Ops{
                .reg1 = .rsp,
            }).encode(),
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
                    .ops = (Mir.Ops{
                        .flags = 0b01,
                    }).encode(),
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
                .ops = (Mir.Ops{
                    .reg1 = .rax,
                    .flags = 0b01,
                }).encode(),
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
                    .ops = (Mir.Ops{
                        .reg1 = .rax,
                        .flags = 0b01,
                    }).encode(),
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
                const n_strx = try macho_file.addExternFn(mem.sliceTo(decl_name, 0));
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
                .ops = (Mir.Ops{
                    .reg1 = .rax,
                    .flags = 0b01,
                }).encode(),
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
                    .ops = (Mir.Ops{
                        .flags = 0b01,
                    }).encode(),
                    .data = .{ .imm = @intCast(u32, fn_got_addr) },
                });
            } else return self.fail("TODO implement calling extern fn on plan9", .{});
        } else {
            assert(ty.zigTypeTag() == .Pointer);
            const mcv = try self.resolveInst(callee);
            try self.genSetReg(Type.initTag(.usize), .rax, mcv);
            _ = try self.addInst(.{
                .tag = .call,
                .ops = (Mir.Ops{
                    .reg1 = .rax,
                    .flags = 0b01,
                }).encode(),
                .data = undefined,
            });
        }
    } else unreachable;

    if (info.stack_byte_count > 0) {
        // Readjust the stack
        _ = try self.addInst(.{
            .tag = .add,
            .ops = (Mir.Ops{
                .reg1 = .rsp,
            }).encode(),
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
        .stack_offset => {
            self.register_manager.freezeRegs(&.{ .rax, .rcx });
            defer self.register_manager.unfreezeRegs(&.{ .rax, .rcx });
            const reg = try self.copyToTmpRegister(Type.usize, self.ret_mcv);
            self.register_manager.freezeRegs(&.{reg});
            defer self.register_manager.unfreezeRegs(&.{reg});
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
        .ops = (Mir.Ops{
            .flags = 0b00,
        }).encode(),
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
        .stack_offset => {
            self.register_manager.freezeRegs(&.{ .rax, .rcx });
            defer self.register_manager.unfreezeRegs(&.{ .rax, .rcx });
            const reg = try self.copyToTmpRegister(Type.usize, self.ret_mcv);
            self.register_manager.freezeRegs(&.{reg});
            defer self.register_manager.unfreezeRegs(&.{reg});
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
        .ops = (Mir.Ops{
            .flags = 0b00,
        }).encode(),
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

    try self.spillCompareFlagsIfOccupied();
    self.compare_flags_inst = inst;

    const result: MCValue = result: {
        // There are 2 operands, destination and source.
        // Either one, but not both, can be a memory operand.
        // Source operand can be an immediate, 8 bits or 32 bits.
        // TODO look into reusing the operand
        const lhs = try self.resolveInst(bin_op.lhs);
        lhs.freezeIfRegister(&self.register_manager);
        defer lhs.unfreezeIfRegister(&self.register_manager);

        const dst_reg = try self.copyToTmpRegister(ty, lhs);
        self.register_manager.freezeRegs(&.{dst_reg});
        defer self.register_manager.unfreezeRegs(&.{dst_reg});

        const dst_mcv = MCValue{ .register = dst_reg };

        // This instruction supports only signed 32-bit immediates at most.
        const src_mcv = try self.limitImmediateType(bin_op.rhs, i32);

        try self.genBinMathOpMir(.cmp, ty, dst_mcv, src_mcv);
        break :result switch (signedness) {
            .signed => MCValue{ .compare_flags_signed = op },
            .unsigned => MCValue{ .compare_flags_unsigned = op },
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
            assert(ty.hasRuntimeBits());
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
            try dw.addTypeReloc(atom, ty, @intCast(u32, index), null);
        },
        .plan9 => {},
        .none => {},
    }
}

fn genCondBrMir(self: *Self, ty: Type, mcv: MCValue) !u32 {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .compare_flags_unsigned,
        .compare_flags_signed,
        => |cmp_op| {
            // Here we map the opposites since the jump is to the false branch.
            const flags: u2 = switch (cmp_op) {
                .gte => 0b10,
                .gt => 0b11,
                .neq => 0b01,
                .lt => 0b00,
                .lte => 0b01,
                .eq => 0b00,
            };
            const tag: Mir.Inst.Tag = if (cmp_op == .neq or cmp_op == .eq)
                .cond_jmp_eq_ne
            else if (mcv == .compare_flags_unsigned)
                Mir.Inst.Tag.cond_jmp_above_below
            else
                Mir.Inst.Tag.cond_jmp_greater_less;
            return self.addInst(.{
                .tag = tag,
                .ops = (Mir.Ops{
                    .flags = flags,
                }).encode(),
                .data = .{ .inst = undefined },
            });
        },
        .register => |reg| {
            try self.spillCompareFlagsIfOccupied();
            _ = try self.addInst(.{
                .tag = .@"test",
                .ops = (Mir.Ops{
                    .reg1 = reg,
                    .flags = 0b00,
                }).encode(),
                .data = .{ .imm = 1 },
            });
            return self.addInst(.{
                .tag = .cond_jmp_eq_ne,
                .ops = (Mir.Ops{
                    .flags = 0b01,
                }).encode(),
                .data = .{ .inst = undefined },
            });
        },
        .immediate,
        .stack_offset,
        => {
            try self.spillCompareFlagsIfOccupied();
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
    const parent_next_stack_offset = self.next_stack_offset;
    const parent_free_registers = self.register_manager.free_registers;
    const parent_compare_flags_inst = self.compare_flags_inst;
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

    // Revert to the previous register and stack allocation state.

    var saved_then_branch = self.branch_stack.pop();
    defer saved_then_branch.deinit(self.gpa);

    self.register_manager.registers = parent_registers;
    self.compare_flags_inst = parent_compare_flags_inst;

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
    try self.spillCompareFlagsIfOccupied();
    self.compare_flags_inst = inst;

    const cmp_ty: Type = if (!ty.isPtrLikeOptional()) blk: {
        var buf: Type.Payload.ElemType = undefined;
        const payload_ty = ty.optionalChild(&buf);
        break :blk if (payload_ty.hasRuntimeBits()) Type.bool else ty;
    } else ty;

    try self.genBinMathOpMir(.cmp, cmp_ty, operand, MCValue{ .immediate = 0 });

    return MCValue{ .compare_flags_unsigned = .eq };
}

fn isNonNull(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const is_null_res = try self.isNull(inst, ty, operand);
    assert(is_null_res.compare_flags_unsigned == .eq);
    return MCValue{ .compare_flags_unsigned = .neq };
}

fn isErr(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const err_type = ty.errorUnionSet();
    const payload_type = ty.errorUnionPayload();
    if (!err_type.hasRuntimeBits()) {
        return MCValue{ .immediate = 0 }; // always false
    }

    try self.spillCompareFlagsIfOccupied();
    self.compare_flags_inst = inst;

    if (!payload_type.hasRuntimeBits()) {
        if (err_type.abiSize(self.target.*) <= 8) {
            try self.genBinMathOpMir(.cmp, err_type, operand, MCValue{ .immediate = 0 });
            return MCValue{ .compare_flags_unsigned = .gt };
        } else {
            return self.fail("TODO isErr for errors with size larger than register size", .{});
        }
    } else {
        try self.genBinMathOpMir(.cmp, err_type, operand, MCValue{ .immediate = 0 });
        return MCValue{ .compare_flags_unsigned = .gt };
    }
}

fn isNonErr(self: *Self, inst: Air.Inst.Index, ty: Type, operand: MCValue) !MCValue {
    const is_err_res = try self.isErr(inst, ty, operand);
    switch (is_err_res) {
        .compare_flags_unsigned => |op| {
            assert(op == .gt);
            return MCValue{ .compare_flags_unsigned = .lte };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        operand_ptr.freezeIfRegister(&self.register_manager);
        defer operand_ptr.unfreezeIfRegister(&self.register_manager);
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
        break :result try self.isNull(inst, ptr_ty.elemType(), operand);
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        operand_ptr.freezeIfRegister(&self.register_manager);
        defer operand_ptr.unfreezeIfRegister(&self.register_manager);
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
        break :result try self.isNonNull(inst, ptr_ty.elemType(), operand);
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        operand_ptr.freezeIfRegister(&self.register_manager);
        defer operand_ptr.unfreezeIfRegister(&self.register_manager);
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
        break :result try self.isErr(inst, ptr_ty.elemType(), operand);
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand_ptr = try self.resolveInst(un_op);
        operand_ptr.freezeIfRegister(&self.register_manager);
        defer operand_ptr.unfreezeIfRegister(&self.register_manager);
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
        break :result try self.isNonErr(inst, ptr_ty.elemType(), operand);
    };
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
        .ops = (Mir.Ops{
            .flags = 0b00,
        }).encode(),
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
        .compare_flags_signed => unreachable,
        .compare_flags_unsigned => unreachable,
        .register => |cond_reg| {
            try self.spillCompareFlagsIfOccupied();

            self.register_manager.freezeRegs(&.{cond_reg});
            defer self.register_manager.unfreezeRegs(&.{cond_reg});

            switch (case) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .immediate => |imm| {
                    _ = try self.addInst(.{
                        .tag = .xor,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(cond_reg, abi_size),
                        }).encode(),
                        .data = .{ .imm = @intCast(u32, imm) },
                    });
                },
                .register => |reg| {
                    _ = try self.addInst(.{
                        .tag = .xor,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(cond_reg, abi_size),
                            .reg2 = registerAlias(reg, abi_size),
                        }).encode(),
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
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(cond_reg, abi_size),
                    .reg2 = registerAlias(cond_reg, abi_size),
                }).encode(),
                .data = undefined,
            });
            return self.addInst(.{
                .tag = .cond_jmp_eq_ne,
                .ops = (Mir.Ops{
                    .flags = 0b00,
                }).encode(),
                .data = .{ .inst = undefined },
            });
        },
        .stack_offset => {
            try self.spillCompareFlagsIfOccupied();

            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, condition);
                self.register_manager.freezeRegs(&.{reg});
                defer self.register_manager.unfreezeRegs(&.{reg});
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
        const parent_next_stack_offset = self.next_stack_offset;
        const parent_free_registers = self.register_manager.free_registers;
        const parent_compare_flags_inst = self.compare_flags_inst;
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
        self.compare_flags_inst = parent_compare_flags_inst;
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
    self.mir_instructions.items(.data)[reloc].inst = next_inst;
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const branch = self.air.instructions.items(.data)[inst].br;
    try self.br(branch.block_inst, branch.operand);
    return self.finishAir(inst, .dead, .{ branch.operand, .none, .none });
}

fn airBoolOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const air_tags = self.air.instructions.items(.tag);
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else switch (air_tags[inst]) {
        // lhs AND rhs
        .bool_and => try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs),
        // lhs OR rhs
        .bool_or => try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs),
        else => unreachable, // Not a boolean operation
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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
                .compare_flags_signed, .compare_flags_unsigned, .immediate => blk: {
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
        .ops = (Mir.Ops{
            .flags = 0b00,
        }).encode(),
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
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += constraint.len / 4 + 1;

            break constraint;
        } else null;

        for (inputs) |input| {
            const input_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(input_bytes, 0);
            const input_name = std.mem.sliceTo(input_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + input_name.len + 1) / 4 + 1;

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
                            .ops = (Mir.Ops{
                                .flags = 0b10,
                            }).encode(),
                            .data = .{ .imm = n },
                        });
                    } else if (mem.indexOf(u8, arg, "%%")) |l| {
                        const reg_name = ins[4 + l + 2 ..];
                        const reg = parseRegName(reg_name) orelse
                            return self.fail("unrecognized register: '{s}'", .{reg_name});
                        _ = try self.addInst(.{
                            .tag = .push,
                            .ops = (Mir.Ops{
                                .reg1 = reg,
                            }).encode(),
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
                            .ops = (Mir.Ops{
                                .reg1 = reg,
                            }).encode(),
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
        .register_overflow_unsigned,
        .register_overflow_signed,
        => return self.fail("TODO genSetStackArg for register with overflow bit", .{}),
        .compare_flags_unsigned,
        .compare_flags_signed,
        => {
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
                        .ops = (Mir.Ops{
                            .reg1 = .rsp,
                            .flags = switch (abi_size) {
                                1 => 0b00,
                                2 => 0b01,
                                4 => 0b10,
                                else => unreachable,
                            },
                        }).encode(),
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
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = .rsp,
                    .reg2 = registerAlias(reg, @intCast(u32, abi_size)),
                    .flags = 0b10,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -stack_offset) },
            });
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
        .register_overflow_unsigned,
        .register_overflow_signed,
        => |reg| {
            self.register_manager.freezeRegs(&.{reg});
            defer self.register_manager.unfreezeRegs(&.{reg});

            const wrapped_ty = ty.structFieldType(0);
            try self.genSetStack(wrapped_ty, stack_offset, .{ .register = reg }, .{});

            const overflow_bit_ty = ty.structFieldType(1);
            const overflow_bit_offset = ty.structFieldOffset(1, self.target.*);
            const tmp_reg = try self.register_manager.allocReg(null);
            const flags: u2 = switch (mcv) {
                .register_overflow_unsigned => 0b10,
                .register_overflow_signed => 0b00,
                else => unreachable,
            };
            _ = try self.addInst(.{
                .tag = .cond_set_byte_overflow,
                .ops = (Mir.Ops{
                    .reg1 = tmp_reg.to8(),
                    .flags = flags,
                }).encode(),
                .data = undefined,
            });

            return self.genSetStack(
                overflow_bit_ty,
                stack_offset - @intCast(i32, overflow_bit_offset),
                .{ .register = tmp_reg.to8() },
                .{},
            );
        },
        .compare_flags_unsigned,
        .compare_flags_signed,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, .{ .register = reg }, opts);
        },
        .immediate => |x_big| {
            const base_reg = opts.dest_stack_base orelse .rbp;
            switch (abi_size) {
                1, 2, 4 => {
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -stack_offset),
                        .operand = @truncate(u32, x_big),
                    });
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = (Mir.Ops{
                            .reg1 = base_reg,
                            .flags = switch (abi_size) {
                                1 => 0b00,
                                2 => 0b01,
                                4 => 0b10,
                                else => unreachable,
                            },
                        }).encode(),
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
                            .ops = (Mir.Ops{
                                .reg1 = base_reg,
                                .flags = 0b10,
                            }).encode(),
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
                            .ops = (Mir.Ops{
                                .reg1 = base_reg,
                                .flags = 0b10,
                            }).encode(),
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
            const is_power_of_two = (abi_size % 2) == 0;
            if (!is_power_of_two) {
                self.register_manager.freezeRegs(&.{reg});
                defer self.register_manager.unfreezeRegs(&.{reg});

                const tmp_reg = try self.copyToTmpRegister(ty, mcv);

                var next_offset = stack_offset;
                var remainder = abi_size;
                while (remainder > 0) {
                    const closest_power_of_two = @as(u6, 1) << @intCast(u3, math.log2(remainder));

                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = base_reg,
                            .reg2 = registerAlias(tmp_reg, closest_power_of_two),
                            .flags = 0b10,
                        }).encode(),
                        .data = .{ .imm = @bitCast(u32, -next_offset) },
                    });

                    if (closest_power_of_two > 1) {
                        _ = try self.addInst(.{
                            .tag = .shr,
                            .ops = (Mir.Ops{
                                .reg1 = tmp_reg,
                                .flags = 0b10,
                            }).encode(),
                            .data = .{ .imm = closest_power_of_two * 8 },
                        });
                    }

                    remainder -= closest_power_of_two;
                    next_offset -= closest_power_of_two;
                }
            } else {
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = base_reg,
                        .reg2 = registerAlias(reg, @intCast(u32, abi_size)),
                        .flags = 0b10,
                    }).encode(),
                    .data = .{ .imm = @bitCast(u32, -stack_offset) },
                });
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
    self.register_manager.freezeRegs(&.{ .rax, .rcx });

    if (opts.source_stack_base) |reg| self.register_manager.freezeRegs(&.{reg});
    defer if (opts.source_stack_base) |reg| self.register_manager.unfreezeRegs(&.{reg});

    if (opts.dest_stack_base) |reg| self.register_manager.freezeRegs(&.{reg});
    defer if (opts.dest_stack_base) |reg| self.register_manager.unfreezeRegs(&.{reg});

    const dst_addr_reg = try self.register_manager.allocReg(null);
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
                .ops = (Mir.Ops{
                    .reg1 = dst_addr_reg.to64(),
                    .reg2 = opts.dest_stack_base orelse .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(dst_addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }).encode(),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when dest is {}", .{dst_ptr});
        },
    }
    self.register_manager.freezeRegs(&.{dst_addr_reg});
    defer self.register_manager.unfreezeRegs(&.{dst_addr_reg});

    const src_addr_reg = try self.register_manager.allocReg(null);
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
                .ops = (Mir.Ops{
                    .reg1 = src_addr_reg.to64(),
                    .reg2 = opts.source_stack_base orelse .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(src_addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }).encode(),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when src is {}", .{src_ptr});
        },
    }
    self.register_manager.freezeRegs(&.{src_addr_reg});
    defer self.register_manager.unfreezeRegs(&.{src_addr_reg});

    const regs = try self.register_manager.allocRegs(2, .{ null, null });
    const count_reg = regs[0].to64();
    const tmp_reg = regs[1].to8();

    self.register_manager.unfreezeRegs(&.{ .rax, .rcx });

    try self.register_manager.getReg(.rax, null);
    try self.register_manager.getReg(.rcx, null);

    try self.genSetReg(Type.usize, count_reg, len);

    // mov rcx, 0
    _ = try self.addInst(.{
        .tag = .mov,
        .ops = (Mir.Ops{
            .reg1 = .rcx,
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // mov rax, 0
    _ = try self.addInst(.{
        .tag = .mov,
        .ops = (Mir.Ops{
            .reg1 = .rax,
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // loop:
    // cmp count, 0
    const loop_start = try self.addInst(.{
        .tag = .cmp,
        .ops = (Mir.Ops{
            .reg1 = count_reg,
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // je end
    const loop_reloc = try self.addInst(.{
        .tag = .cond_jmp_eq_ne,
        .ops = (Mir.Ops{ .flags = 0b01 }).encode(),
        .data = .{ .inst = undefined },
    });

    // mov tmp, [addr + rcx]
    _ = try self.addInst(.{
        .tag = .mov_scale_src,
        .ops = (Mir.Ops{
            .reg1 = tmp_reg.to8(),
            .reg2 = src_addr_reg,
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // mov [stack_offset + rax], tmp
    _ = try self.addInst(.{
        .tag = .mov_scale_dst,
        .ops = (Mir.Ops{
            .reg1 = dst_addr_reg,
            .reg2 = tmp_reg.to8(),
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // add rcx, 1
    _ = try self.addInst(.{
        .tag = .add,
        .ops = (Mir.Ops{
            .reg1 = .rcx,
        }).encode(),
        .data = .{ .imm = 1 },
    });

    // add rax, 1
    _ = try self.addInst(.{
        .tag = .add,
        .ops = (Mir.Ops{
            .reg1 = .rax,
        }).encode(),
        .data = .{ .imm = 1 },
    });

    // sub count, 1
    _ = try self.addInst(.{
        .tag = .sub,
        .ops = (Mir.Ops{
            .reg1 = count_reg,
        }).encode(),
        .data = .{ .imm = 1 },
    });

    // jmp loop
    _ = try self.addInst(.{
        .tag = .jmp,
        .ops = (Mir.Ops{ .flags = 0b00 }).encode(),
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
    self.register_manager.freezeRegs(&.{.rax});

    const addr_reg = try self.register_manager.allocReg(null);
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
                .ops = (Mir.Ops{
                    .reg1 = addr_reg.to64(),
                    .reg2 = opts.dest_stack_base orelse .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -off) },
            });
        },
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(addr_reg, @divExact(reg.size(), 8)),
                    .reg2 = reg,
                }).encode(),
                .data = undefined,
            });
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when dest is {}", .{dst_ptr});
        },
    }
    self.register_manager.freezeRegs(&.{addr_reg});
    defer self.register_manager.unfreezeRegs(&.{addr_reg});

    self.register_manager.unfreezeRegs(&.{.rax});
    try self.register_manager.getReg(.rax, null);

    try self.genSetReg(Type.usize, .rax, len);
    try self.genBinMathOpMir(.sub, Type.usize, .{ .register = .rax }, .{ .immediate = 1 });

    // loop:
    // cmp rax, -1
    const loop_start = try self.addInst(.{
        .tag = .cmp,
        .ops = (Mir.Ops{
            .reg1 = .rax,
        }).encode(),
        .data = .{ .imm = @bitCast(u32, @as(i32, -1)) },
    });

    // je end
    const loop_reloc = try self.addInst(.{
        .tag = .cond_jmp_eq_ne,
        .ops = (Mir.Ops{ .flags = 0b01 }).encode(),
        .data = .{ .inst = undefined },
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
                .ops = (Mir.Ops{
                    .reg1 = addr_reg,
                }).encode(),
                .data = .{ .payload = payload },
            });
        },
        else => return self.fail("TODO inline memset for value of type {}", .{value}),
    }

    // sub rax, 1
    _ = try self.addInst(.{
        .tag = .sub,
        .ops = (Mir.Ops{
            .reg1 = .rax,
        }).encode(),
        .data = .{ .imm = 1 },
    });

    // jmp loop
    _ = try self.addInst(.{
        .tag = .jmp,
        .ops = (Mir.Ops{ .flags = 0b00 }).encode(),
        .data = .{ .inst = loop_start },
    });

    // end:
    try self.performReloc(loop_reloc);
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .register_overflow_unsigned,
        .register_overflow_signed,
        => unreachable,
        .ptr_stack_offset => |off| {
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = .rbp,
                }).encode(),
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
        .compare_flags_unsigned,
        .compare_flags_signed,
        => |op| {
            const tag: Mir.Inst.Tag = switch (op) {
                .gte, .gt, .lt, .lte => if (mcv == .compare_flags_unsigned)
                    Mir.Inst.Tag.cond_set_byte_above_below
                else
                    Mir.Inst.Tag.cond_set_byte_greater_less,
                .eq, .neq => .cond_set_byte_eq_ne,
            };
            const flags: u2 = switch (op) {
                .gte => 0b00,
                .gt => 0b01,
                .lt => 0b10,
                .lte => 0b11,
                .eq => 0b01,
                .neq => 0b00,
            };
            _ = try self.addInst(.{
                .tag = tag,
                .ops = (Mir.Ops{
                    .reg1 = reg.to8(),
                    .flags = flags,
                }).encode(),
                .data = undefined,
            });
        },
        .immediate => |x| {
            // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
            // register is the fastest way to zero a register.
            if (x == 0) {
                _ = try self.addInst(.{
                    .tag = .xor,
                    .ops = (Mir.Ops{
                        .reg1 = reg.to32(),
                        .reg2 = reg.to32(),
                    }).encode(),
                    .data = undefined,
                });
                return;
            }
            if (x <= math.maxInt(i32)) {
                // Next best case: if we set the lower four bytes, the upper four will be zeroed.
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = registerAlias(reg, abi_size),
                    }).encode(),
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
                .ops = (Mir.Ops{
                    .reg1 = reg.to64(),
                }).encode(),
                .data = .{ .payload = payload },
            });
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            if (ty.zigTypeTag() == .Int) blk: {
                switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        if (abi_size > 4) break :blk;
                        _ = try self.addInst(.{
                            .tag = .mov_sign_extend,
                            .ops = (Mir.Ops{
                                .reg1 = reg.to64(),
                                .reg2 = registerAlias(src_reg, abi_size),
                            }).encode(),
                            .data = undefined,
                        });
                    },
                    .unsigned => {
                        if (abi_size > 2) break :blk;
                        _ = try self.addInst(.{
                            .tag = .mov_zero_extend,
                            .ops = (Mir.Ops{
                                .reg1 = reg.to64(),
                                .reg2 = registerAlias(src_reg, abi_size),
                            }).encode(),
                            .data = undefined,
                        });
                    },
                }
                return;
            }

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = registerAlias(src_reg, abi_size),
                }).encode(),
                .data = undefined,
            });
        },
        .direct_load,
        .got_load,
        => {
            try self.loadMemPtrIntoRegister(reg, Type.usize, mcv);
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = reg.to64(),
                    .flags = 0b01,
                }).encode(),
                .data = .{ .imm = 0 },
            });
        },
        .memory => |x| {
            if (x <= math.maxInt(i32)) {
                // mov reg, [ds:imm32]
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = registerAlias(reg, abi_size),
                        .flags = 0b01,
                    }).encode(),
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
                        .ops = (Mir.Ops{
                            .reg1 = .rax,
                            .flags = 0b01, // imm64 will become moffs64
                        }).encode(),
                        .data = .{ .payload = payload },
                    });
                } else {
                    // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                    try self.genSetReg(ty, reg, MCValue{ .immediate = x });

                    // mov reg, [reg + 0x0]
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(reg, abi_size),
                            .reg2 = reg.to64(),
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = 0 },
                    });
                }
            }
        },
        .stack_offset => |off| {
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }

            if (ty.zigTypeTag() == .Int) blk: {
                switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        const flags: u2 = switch (abi_size) {
                            1 => 0b01,
                            2 => 0b10,
                            4 => 0b11,
                            else => break :blk,
                        };
                        _ = try self.addInst(.{
                            .tag = .mov_sign_extend,
                            .ops = (Mir.Ops{
                                .reg1 = reg.to64(),
                                .reg2 = .rbp,
                                .flags = flags,
                            }).encode(),
                            .data = .{ .imm = @bitCast(u32, -off) },
                        });
                    },
                    .unsigned => {
                        const flags: u2 = switch (abi_size) {
                            1 => 0b01,
                            2 => 0b10,
                            else => break :blk,
                        };
                        _ = try self.addInst(.{
                            .tag = .mov_zero_extend,
                            .ops = (Mir.Ops{
                                .reg1 = reg.to64(),
                                .reg2 = .rbp,
                                .flags = flags,
                            }).encode(),
                            .data = .{ .imm = @bitCast(u32, -off) },
                        });
                    },
                }
                return;
            }

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, abi_size),
                    .reg2 = .rbp,
                    .flags = 0b01,
                }).encode(),
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
        .ops = (Mir.Ops{
            .flags = switch (src_ty.abiSize(self.target.*)) {
                4 => 0b01,
                8 => 0b10,
                else => |size| return self.fail("TODO load ST(0) with abiSize={}", .{size}),
            },
            .reg1 = .rbp,
        }).encode(),
        .data = .{ .imm = @bitCast(u32, -stack_offset) },
    });

    // convert
    const stack_dst = try self.allocRegOrMem(inst, false);
    _ = try self.addInst(.{
        .tag = .fisttp,
        .ops = (Mir.Ops{
            .flags = switch (dst_ty.abiSize(self.target.*)) {
                1...2 => 0b00,
                3...4 => 0b01,
                5...8 => 0b10,
                else => |size| return self.fail("TODO convert float with abiSize={}", .{size}),
            },
            .reg1 = .rbp,
        }).encode(),
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
    dst_ptr.freezeIfRegister(&self.register_manager);
    defer dst_ptr.unfreezeIfRegister(&self.register_manager);

    const src_val = try self.resolveInst(extra.lhs);
    src_val.freezeIfRegister(&self.register_manager);
    defer src_val.unfreezeIfRegister(&self.register_manager);

    const len = try self.resolveInst(extra.rhs);
    len.freezeIfRegister(&self.register_manager);
    defer len.unfreezeIfRegister(&self.register_manager);

    try self.genInlineMemset(dst_ptr, src_val, len, .{});

    return self.finishAir(inst, .none, .{ pl_op.operand, .none, .none });
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;

    const dst_ptr = try self.resolveInst(pl_op.operand);
    dst_ptr.freezeIfRegister(&self.register_manager);
    defer dst_ptr.unfreezeIfRegister(&self.register_manager);

    const src_ty = self.air.typeOf(extra.lhs);
    const src_ptr = try self.resolveInst(extra.lhs);
    src_ptr.freezeIfRegister(&self.register_manager);
    defer src_ptr.unfreezeIfRegister(&self.register_manager);

    const len = try self.resolveInst(extra.rhs);
    len.freezeIfRegister(&self.register_manager);
    defer len.unfreezeIfRegister(&self.register_manager);

    // TODO Is this the only condition for pointer dereference for memcpy?
    const src: MCValue = blk: {
        switch (src_ptr) {
            .got_load, .direct_load, .memory => {
                const reg = try self.register_manager.allocReg(null);
                try self.loadMemPtrIntoRegister(reg, src_ty, src_ptr);
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = reg,
                        .reg2 = reg,
                        .flags = 0b01,
                    }).encode(),
                    .data = .{ .imm = 0 },
                });
                break :blk MCValue{ .register = reg };
            },
            else => break :blk src_ptr,
        }
    };
    src.freezeIfRegister(&self.register_manager);
    defer src.unfreezeIfRegister(&self.register_manager);

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
            const err_name = typed_value.val.castTag(.@"error").?.data.name;
            const module = self.bin_file.options.module.?;
            const global_error_set = module.global_error_set;
            const error_index = global_error_set.get(err_name).?;
            return MCValue{ .immediate = error_index };
        },
        .ErrorUnion => {
            const error_type = typed_value.ty.errorUnionSet();
            const payload_type = typed_value.ty.errorUnionPayload();

            if (typed_value.val.castTag(.eu_payload)) |_| {
                if (!payload_type.hasRuntimeBits()) {
                    // We use the error type directly as the type.
                    return MCValue{ .immediate = 0 };
                }
            } else {
                if (!payload_type.hasRuntimeBits()) {
                    // We use the error type directly as the type.
                    return self.genTypedValue(.{ .ty = error_type, .val = typed_value.val });
                }
            }
        },

        .ComptimeInt => unreachable,
        .ComptimeFloat => unreachable,
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
        .Unspecified, .C => {
            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBits()) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                if (ret_ty_size <= 8) {
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
    } else {
        unreachable; // TODO handle floating-point registers
    }
}

fn shiftRegister(self: *Self, reg: Register, shift: u8) !void {
    if (shift == 0) return;
    if (shift == 1) {
        _ = try self.addInst(.{
            .tag = .shr,
            .ops = (Mir.Ops{
                .reg1 = reg,
            }).encode(),
            .data = undefined,
        });
    } else {
        _ = try self.addInst(.{
            .tag = .shr,
            .ops = (Mir.Ops{
                .reg1 = reg,
                .flags = 0b10,
            }).encode(),
            .data = .{ .imm = shift },
        });
    }
}
