const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Air = @import("../../Air.zig");
const Zir = @import("../../Zir.zig");
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
const RegisterManager = @import("../../register_manager.zig").RegisterManager;

const FnResult = @import("../../codegen.zig").FnResult;
const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;

const InnerError = error{
    OutOfMemory,
    CodegenFail,
};

gpa: Allocator,
air: Air,
liveness: Liveness,
bin_file: *link.File,
target: *const std.Target,
mod_fn: *const Module.Fn,
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

register_manager: RegisterManager(Self, Register, &callee_preserved_regs) = .{},
/// Maps offset to what is stored there.
stack: std.AutoHashMapUnmanaged(u32, StackAllocation) = .{},
/// Tracks the current instruction allocated to the compare flags
compare_flags_inst: ?Air.Inst.Index = null,

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
    /// The constant was emitted into the code, at this offset.
    /// If the type is a pointer, it means the pointer address is embedded in the code.
    embedded_in_code: usize,
    /// The value is a pointer to a constant which was emitted into the code, at this offset.
    ptr_embedded_in_code: usize,
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
    /// The value is in the compare flags assuming an unsigned operation,
    /// with this operator applied on top of it.
    compare_flags_unsigned: math.CompareOperator,
    /// The value is in the compare flags assuming a signed operation,
    /// with this operator applied on top of it.
    compare_flags_signed: math.CompareOperator,
    /// The value is a function argument passed via the stack.
    stack_argument_offset: u32,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .embedded_in_code, .memory, .stack_offset, .stack_argument_offset => true,
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
            .embedded_in_code,
            .memory,
            .compare_flags_unsigned,
            .compare_flags_signed,
            .ptr_stack_offset,
            .ptr_embedded_in_code,
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
    tomb_bits: Liveness.Bpi,
    big_tomb_bits: u32,
    bit_index: usize,

    fn feed(bt: *BigTomb, op_ref: Air.Inst.Ref) void {
        const this_bit_index = bt.bit_index;
        bt.bit_index += 1;

        const op_int = @enumToInt(op_ref);
        if (op_int < Air.Inst.Ref.typed_value_map.len) return;
        const op_index = @intCast(Air.Inst.Index, op_int - Air.Inst.Ref.typed_value_map.len);

        if (this_bit_index < Liveness.bpi - 1) {
            const dies = @truncate(u1, bt.tomb_bits >> @intCast(Liveness.OperandInt, this_bit_index)) != 0;
            if (!dies) return;
        } else {
            const big_bit_index = @intCast(u5, this_bit_index - (Liveness.bpi - 1));
            const dies = @truncate(u1, bt.big_tomb_bits >> big_bit_index) != 0;
            if (!dies) return;
        }
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

    assert(module_fn.owner_decl.has_tv);
    const fn_type = module_fn.owner_decl.ty;

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
        else => |e| return e,
    };
    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.stack_align = call_info.stack_align;
    function.max_end_stack = call_info.stack_byte_count;

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return FnResult{ .fail = function.err_msg.? },
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
        .cond = .al,
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
            .cond = .al,
            .data = .{ .rr_op = .{
                .rd = .fp,
                .rn = .r0,
                .op = Instruction.Operand.reg(.sp, Instruction.Operand.Shift.none),
            } },
        });

        // sub sp, sp, #reloc
        const sub_reloc = try self.addNop();

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
            .cond = .al,
            .data = .{ .register_list = saved_regs },
        });

        // Backpatch stack offset
        const total_stack_size = self.max_end_stack + self.saved_regs_stack_space;
        const aligned_total_stack_end = mem.alignForwardGeneric(u32, total_stack_size, self.stack_align);
        const stack_size = aligned_total_stack_end - self.saved_regs_stack_space;
        if (Instruction.Operand.fromU32(stack_size)) |op| {
            self.mir_instructions.set(sub_reloc, .{
                .tag = .sub,
                .cond = .al,
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
        if (self.exitlude_jump_relocs.items.len == 1) {
            // There is only one relocation. Hence,
            // this relocation must be at the end of
            // the code. Therefore, we can just delete
            // the space initially reserved for the
            // jump
            self.mir_instructions.len -= 1;
        } else for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.set(jmp_reloc, .{
                .tag = .b,
                .cond = .al,
                .data = .{ .inst = @intCast(u32, self.mir_instructions.len) },
            });
        }

        // Epilogue: pop callee saved registers (swap lr with pc in saved_regs)
        saved_regs.r14 = false; // lr
        saved_regs.r15 = true; // pc

        // mov sp, fp
        _ = try self.addInst(.{
            .tag = .mov,
            .cond = .al,
            .data = .{ .rr_op = .{
                .rd = .sp,
                .rn = .r0,
                .op = Instruction.Operand.reg(.fp, Instruction.Operand.Shift.none),
            } },
        });

        // pop {fp, pc}
        _ = try self.addInst(.{
            .tag = .pop,
            .cond = .al,
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
                    .add, .ptr_add   => try self.airAdd(inst),
                    .addwrap         => try self.airAddWrap(inst),
                    .add_sat         => try self.airAddSat(inst),
                    .sub, .ptr_sub   => try self.airSub(inst),
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

                    .div_float, .div_trunc, .div_floor, .div_exact => try self.airDiv(inst),

                    .cmp_lt  => try self.airCmp(inst, .lt),
                    .cmp_lte => try self.airCmp(inst, .lte),
                    .cmp_eq  => try self.airCmp(inst, .eq),
                    .cmp_gte => try self.airCmp(inst, .gte),
                    .cmp_gt  => try self.airCmp(inst, .gt),
                    .cmp_neq => try self.airCmp(inst, .neq),

                    .bool_and => try self.airBoolOp(inst),
                    .bool_or  => try self.airBoolOp(inst),
                    .bit_and  => try self.airBitAnd(inst),
                    .bit_or   => try self.airBitOr(inst),
                    .xor      => try self.airXor(inst),
                    .shr      => try self.airShr(inst),

                    .alloc           => try self.airAlloc(inst),
                    .ret_ptr         => try self.airRetPtr(inst),
                    .arg             => try self.airArg(inst),
                    .assembly        => try self.airAsm(inst),
                    .bitcast         => try self.airBitCast(inst),
                    .block           => try self.airBlock(inst),
                    .br              => try self.airBr(inst),
                    .breakpoint      => try self.airBreakpoint(),
                    .fence           => try self.airFence(),
                    .call            => try self.airCall(inst),
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

                    .atomic_store_unordered => try self.airAtomicStore(inst, .Unordered),
                    .atomic_store_monotonic => try self.airAtomicStore(inst, .Monotonic),
                    .atomic_store_release   => try self.airAtomicStore(inst, .Release),
                    .atomic_store_seq_cst   => try self.airAtomicStore(inst, .SeqCst),

                    .struct_field_ptr_index_0 => try self.airStructFieldPtrIndex(inst, 0),
                    .struct_field_ptr_index_1 => try self.airStructFieldPtrIndex(inst, 1),
                    .struct_field_ptr_index_2 => try self.airStructFieldPtrIndex(inst, 2),
                    .struct_field_ptr_index_3 => try self.airStructFieldPtrIndex(inst, 3),

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

                    .wrap_optional         => try self.airWrapOptional(inst),
                    .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
                    .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),
                    // zig fmt: on
        }
        if (std.debug.runtime_safety) {
            if (self.air_bookkeeping < old_air_bookkeeping + 1) {
                std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, air_tags[inst] });
            }
        }
    }
}

fn writeInt(self: *Self, comptime T: type, buf: *[@divExact(@typeInfo(T).Int.bits, 8)]u8, value: T) void {
    const endian = self.target.cpu.arch.endian();
    std.mem.writeInt(T, buf, value, endian);
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
        .dwarf => |dbg_out| {
            assert(ty.hasCodeGenBits());
            const index = dbg_out.dbg_info.items.len;
            try dbg_out.dbg_info.resize(index + 4); // DW.AT.type,  DW.FORM.ref4

            const gop = try dbg_out.dbg_info_type_relocs.getOrPut(self.gpa, ty);
            if (!gop.found_existing) {
                gop.value_ptr.* = .{
                    .off = undefined,
                    .relocs = .{},
                };
            }
            try gop.value_ptr.relocs.append(self.gpa, @intCast(u32, index));
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
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(self.target.*);
    return self.allocMem(inst, abi_size, abi_align);
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const elem_ty = self.air.typeOfIndex(inst);
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty});
    };
    const abi_align = elem_ty.abiAlignment(self.target.*);
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        if (abi_size <= ptr_bytes) {
            if (self.register_manager.tryAllocReg(inst, &.{})) |reg| {
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

/// Save the current instruction stored in the compare flags if
/// occupied
fn spillCompareFlagsIfOccupied(self: *Self) !void {
    if (self.compare_flags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save);
        assert(mcv == .compare_flags_signed or mcv == .compare_flags_unsigned);

        const new_mcv = try self.allocRegOrMem(inst_to_save, true);
        switch (new_mcv) {
            .register => |reg| try self.genSetReg(self.air.typeOfIndex(inst_to_save), reg, mcv),
            .stack_offset => |offset| try self.genSetStack(self.air.typeOfIndex(inst_to_save), offset, mcv),
            else => unreachable,
        }
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
    const reg = try self.register_manager.allocReg(null, &.{});
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToNewRegister(self: *Self, reg_owner: Air.Inst.Index, mcv: MCValue) !MCValue {
    const reg = try self.register_manager.allocReg(reg_owner, &.{});
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
            else => {
                break :result try self.genArmBinOp(inst, ty_op.operand, .bool_true, .not);
            },
        }
    };
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

fn airAdd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .add);
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

fn airSub(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .sub);
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmMul(inst, bin_op.lhs, bin_op.rhs);
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .bit_and);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .bit_or);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .xor);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .shl);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .shr);
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

fn reuseOperand(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, op_index: Liveness.OperandInt, mcv: MCValue) bool {
    if (!self.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register => |reg| {
            // If it's in the registers table, need to associate the register with the
            // new instruction.
            if (reg.allocIndex()) |index| {
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
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .immediate => |imm| try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm }),
        .ptr_stack_offset => |off| try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off }),
        .ptr_embedded_in_code => |off| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .embedded_in_code = off });
        },
        .embedded_in_code => {
            return self.fail("TODO implement loading from MCValue.embedded_in_code", .{});
        },
        .register => |reg| {
            switch (dst_mcv) {
                .dead => unreachable,
                .undef => unreachable,
                .compare_flags_signed, .compare_flags_unsigned => unreachable,
                .embedded_in_code => unreachable,
                .register => |dst_reg| {
                    _ = try self.addInst(.{
                        .tag = .ldr,
                        .cond = .al,
                        .data = .{ .rr_offset = .{
                            .rt = dst_reg,
                            .rn = reg,
                            .offset = .{ .offset = Instruction.Offset.none },
                        } },
                    });
                },
                else => return self.fail("TODO load from register into {}", .{dst_mcv}),
            }
        },
        .memory => |addr| {
            const reg = try self.register_manager.allocReg(null, &.{});
            try self.genSetReg(ptr_ty, reg, .{ .memory = addr });
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
        .stack_offset => {
            return self.fail("TODO implement loading from MCValue.stack_offset", .{});
        },
        .stack_argument_offset => {
            return self.fail("TODO implement loading from MCValue.stack_argument_offset", .{});
        },
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const elem_ty = self.air.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasCodeGenBits())
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

fn airStore(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const value = try self.resolveInst(bin_op.rhs);
    const elem_ty = self.air.typeOf(bin_op.rhs);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .stack_argument_offset => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(elem_ty, .{ .memory = imm }, value);
        },
        .ptr_stack_offset => |off| {
            try self.genSetStack(elem_ty, off, value);
        },
        .ptr_embedded_in_code => |off| {
            try self.setRegOrMem(elem_ty, .{ .embedded_in_code = off }, value);
        },
        .embedded_in_code => {
            return self.fail("TODO implement storing to MCValue.embedded_in_code", .{});
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

fn armOperandShouldBeRegister(self: *Self, mcv: MCValue) !bool {
    return switch (mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .immediate => |imm| blk: {
            if (imm > std.math.maxInt(u32)) return self.fail("TODO ARM binary arithmetic immediate larger than u32", .{});

            // Load immediate into register if it doesn't fit
            // in an operand
            break :blk Instruction.Operand.fromU32(@intCast(u32, imm)) == null;
        },
        .register => true,
        .stack_offset,
        .stack_argument_offset,
        .embedded_in_code,
        .memory,
        => true,
    };
}

fn genArmBinOp(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref, op: Air.Inst.Tag) !MCValue {
    // In the case of bitshifts, the type of rhs is different
    // from the resulting type
    const ty = self.air.typeOf(op_lhs);

    switch (ty.zigTypeTag()) {
        .Float => return self.fail("TODO ARM binary operations on floats", .{}),
        .Vector => return self.fail("TODO ARM binary operations on vectors", .{}),
        .Bool => {
            return self.genArmBinIntOp(inst, op_lhs, op_rhs, op, 1, .unsigned);
        },
        .Int => {
            const int_info = ty.intInfo(self.target.*);
            return self.genArmBinIntOp(inst, op_lhs, op_rhs, op, int_info.bits, int_info.signedness);
        },
        else => unreachable,
    }
}

fn genArmBinIntOp(
    self: *Self,
    inst: Air.Inst.Index,
    op_lhs: Air.Inst.Ref,
    op_rhs: Air.Inst.Ref,
    op: Air.Inst.Tag,
    bits: u16,
    signedness: std.builtin.Signedness,
) !MCValue {
    if (bits > 32) {
        return self.fail("TODO ARM binary operations on integers > u32/i32", .{});
    }

    const lhs = try self.resolveInst(op_lhs);
    const rhs = try self.resolveInst(op_rhs);

    const lhs_is_register = lhs == .register;
    const rhs_is_register = rhs == .register;
    const lhs_should_be_register = switch (op) {
        .shr, .shl => true,
        else => try self.armOperandShouldBeRegister(lhs),
    };
    const rhs_should_be_register = try self.armOperandShouldBeRegister(rhs);
    const reuse_lhs = lhs_is_register and self.reuseOperand(inst, op_lhs, 0, lhs);
    const reuse_rhs = !reuse_lhs and rhs_is_register and self.reuseOperand(inst, op_rhs, 1, rhs);
    const can_swap_lhs_and_rhs = switch (op) {
        .shr, .shl => false,
        else => true,
    };

    // Destination must be a register
    var dst_mcv: MCValue = undefined;
    var lhs_mcv = lhs;
    var rhs_mcv = rhs;
    var swap_lhs_and_rhs = false;

    // Allocate registers for operands and/or destination
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    if (reuse_lhs) {
        // Allocate 0 or 1 registers
        if (!rhs_is_register and rhs_should_be_register) {
            rhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(op_rhs).?, &.{lhs.register}) };
            branch.inst_table.putAssumeCapacity(Air.refToIndex(op_rhs).?, rhs_mcv);
        }
        dst_mcv = lhs;
    } else if (reuse_rhs and can_swap_lhs_and_rhs) {
        // Allocate 0 or 1 registers
        if (!lhs_is_register and lhs_should_be_register) {
            lhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(op_lhs).?, &.{rhs.register}) };
            branch.inst_table.putAssumeCapacity(Air.refToIndex(op_lhs).?, lhs_mcv);
        }
        dst_mcv = rhs;

        swap_lhs_and_rhs = true;
    } else {
        // Allocate 1 or 2 registers
        if (lhs_should_be_register and rhs_should_be_register) {
            if (lhs_is_register and rhs_is_register) {
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{ lhs.register, rhs.register }) };
            } else if (lhs_is_register) {
                // Move RHS to register
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{lhs.register}) };
                rhs_mcv = dst_mcv;
            } else if (rhs_is_register) {
                // Move LHS to register
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{rhs.register}) };
                lhs_mcv = dst_mcv;
            } else {
                // Move LHS and RHS to register
                const regs = try self.register_manager.allocRegs(2, .{ inst, Air.refToIndex(op_rhs).? }, &.{});
                lhs_mcv = MCValue{ .register = regs[0] };
                rhs_mcv = MCValue{ .register = regs[1] };
                dst_mcv = lhs_mcv;

                branch.inst_table.putAssumeCapacity(Air.refToIndex(op_rhs).?, rhs_mcv);
            }
        } else if (lhs_should_be_register) {
            // RHS is immediate
            if (lhs_is_register) {
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{lhs.register}) };
            } else {
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{}) };
                lhs_mcv = dst_mcv;
            }
        } else if (rhs_should_be_register and can_swap_lhs_and_rhs) {
            // LHS is immediate
            if (rhs_is_register) {
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{rhs.register}) };
            } else {
                dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{}) };
                rhs_mcv = dst_mcv;
            }

            swap_lhs_and_rhs = true;
        } else unreachable; // binary operation on two immediates
    }

    // Move the operands to the newly allocated registers
    if (lhs_mcv == .register and !lhs_is_register) {
        try self.genSetReg(self.air.typeOf(op_lhs), lhs_mcv.register, lhs);
    }
    if (rhs_mcv == .register and !rhs_is_register) {
        try self.genSetReg(self.air.typeOf(op_rhs), rhs_mcv.register, rhs);
    }

    try self.genArmBinOpCode(
        dst_mcv.register,
        lhs_mcv,
        rhs_mcv,
        swap_lhs_and_rhs,
        op,
        signedness,
    );
    return dst_mcv;
}

fn genArmBinOpCode(
    self: *Self,
    dst_reg: Register,
    lhs_mcv: MCValue,
    rhs_mcv: MCValue,
    swap_lhs_and_rhs: bool,
    op: Air.Inst.Tag,
    signedness: std.builtin.Signedness,
) !void {
    assert(lhs_mcv == .register or rhs_mcv == .register);

    const op1 = if (swap_lhs_and_rhs) rhs_mcv.register else lhs_mcv.register;
    const op2 = if (swap_lhs_and_rhs) lhs_mcv else rhs_mcv;

    const operand = switch (op2) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .immediate => |imm| Instruction.Operand.fromU32(@intCast(u32, imm)).?,
        .register => |reg| Instruction.Operand.reg(reg, Instruction.Operand.Shift.none),
        .stack_offset,
        .stack_argument_offset,
        .embedded_in_code,
        .memory,
        => unreachable,
    };

    switch (op) {
        .add,
        .bool_and,
        .bit_and,
        .bool_or,
        .bit_or,
        .not,
        .xor,
        => {
            const tag: Mir.Inst.Tag = switch (op) {
                .add => .add,
                .bool_and, .bit_and => .@"and",
                .bool_or, .bit_or => .orr,
                .not, .xor => .eor,
                else => unreachable,
            };

            _ = try self.addInst(.{
                .tag = tag,
                .cond = .al,
                .data = .{ .rr_op = .{
                    .rd = dst_reg,
                    .rn = op1,
                    .op = operand,
                } },
            });
        },
        .sub => {
            const tag: Mir.Inst.Tag = if (swap_lhs_and_rhs) .rsb else .sub;

            _ = try self.addInst(.{
                .tag = tag,
                .cond = .al,
                .data = .{ .rr_op = .{
                    .rd = dst_reg,
                    .rn = op1,
                    .op = operand,
                } },
            });
        },
        .cmp_eq => {
            _ = try self.addInst(.{
                .tag = .cmp,
                .cond = .al,
                .data = .{ .rr_op = .{
                    .rd = .r0,
                    .rn = op1,
                    .op = operand,
                } },
            });
        },
        .shl, .shr => {
            assert(!swap_lhs_and_rhs);
            const shift_amount = switch (operand) {
                .Register => |reg_op| Instruction.ShiftAmount.reg(@intToEnum(Register, reg_op.rm)),
                .Immediate => |imm_op| Instruction.ShiftAmount.imm(@intCast(u5, imm_op.imm)),
            };

            const tag: Mir.Inst.Tag = switch (op) {
                .shl => .lsl,
                .shr => switch (signedness) {
                    .signed => Mir.Inst.Tag.asr,
                    .unsigned => Mir.Inst.Tag.lsr,
                },
                else => unreachable,
            };

            _ = try self.addInst(.{
                .tag = tag,
                .cond = .al,
                .data = .{ .rr_shift = .{
                    .rd = dst_reg,
                    .rm = op1,
                    .shift_amount = shift_amount,
                } },
            });
        },
        else => unreachable, // not a binary instruction
    }
}

fn genArmMul(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    const lhs = try self.resolveInst(op_lhs);
    const rhs = try self.resolveInst(op_rhs);

    const lhs_is_register = lhs == .register;
    const rhs_is_register = rhs == .register;
    const reuse_lhs = lhs_is_register and self.reuseOperand(inst, op_lhs, 0, lhs);
    const reuse_rhs = !reuse_lhs and rhs_is_register and self.reuseOperand(inst, op_rhs, 1, rhs);

    // Destination must be a register
    // LHS must be a register
    // RHS must be a register
    var dst_mcv: MCValue = undefined;
    var lhs_mcv: MCValue = lhs;
    var rhs_mcv: MCValue = rhs;

    // Allocate registers for operands and/or destination
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    if (reuse_lhs) {
        // Allocate 0 or 1 registers
        if (!rhs_is_register) {
            rhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(op_rhs).?, &.{lhs.register}) };
            branch.inst_table.putAssumeCapacity(Air.refToIndex(op_rhs).?, rhs_mcv);
        }
        dst_mcv = lhs;
    } else if (reuse_rhs) {
        // Allocate 0 or 1 registers
        if (!lhs_is_register) {
            lhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(op_lhs).?, &.{rhs.register}) };
            branch.inst_table.putAssumeCapacity(Air.refToIndex(op_lhs).?, lhs_mcv);
        }
        dst_mcv = rhs;
    } else {
        // Allocate 1 or 2 registers
        if (lhs_is_register and rhs_is_register) {
            dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{ lhs.register, rhs.register }) };
        } else if (lhs_is_register) {
            // Move RHS to register
            dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{lhs.register}) };
            rhs_mcv = dst_mcv;
        } else if (rhs_is_register) {
            // Move LHS to register
            dst_mcv = MCValue{ .register = try self.register_manager.allocReg(inst, &.{rhs.register}) };
            lhs_mcv = dst_mcv;
        } else {
            // Move LHS and RHS to register
            const regs = try self.register_manager.allocRegs(2, .{ inst, Air.refToIndex(op_rhs).? }, &.{});
            lhs_mcv = MCValue{ .register = regs[0] };
            rhs_mcv = MCValue{ .register = regs[1] };
            dst_mcv = lhs_mcv;

            branch.inst_table.putAssumeCapacity(Air.refToIndex(op_rhs).?, rhs_mcv);
        }
    }

    // Move the operands to the newly allocated registers
    if (!lhs_is_register) {
        try self.genSetReg(self.air.typeOf(op_lhs), lhs_mcv.register, lhs);
    }
    if (!rhs_is_register) {
        try self.genSetReg(self.air.typeOf(op_rhs), rhs_mcv.register, rhs);
    }

    _ = try self.addInst(.{
        .tag = .mul,
        .cond = .al,
        .data = .{ .rrr = .{
            .rd = dst_mcv.register,
            .rn = lhs_mcv.register,
            .rm = rhs_mcv.register,
        } },
    });
    return dst_mcv;
}

fn genArgDbgInfo(self: *Self, inst: Air.Inst.Index, mcv: MCValue) !void {
    const ty_str = self.air.instructions.items(.data)[inst].ty_str;
    const zir = &self.mod_fn.owner_decl.getFileScope().zir;
    const name = zir.nullTerminatedString(ty_str.str);
    const name_with_null = name.ptr[0 .. name.len + 1];
    const ty = self.air.getRefType(ty_str.ty);

    switch (mcv) {
        .register => |reg| {
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    try dbg_out.dbg_info.ensureUnusedCapacity(3);
                    dbg_out.dbg_info.appendAssumeCapacity(link.File.Elf.abbrev_parameter);
                    dbg_out.dbg_info.appendSliceAssumeCapacity(&[2]u8{ // DW.AT.location, DW.FORM.exprloc
                        1, // ULEB128 dwarf expression length
                        reg.dwarfLocOp(),
                    });
                    try dbg_out.dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                    try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                    dbg_out.dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
                },
                .plan9 => {},
                .none => {},
            }
        },
        .stack_offset => |offset| {
            switch (self.debug_output) {
                .dwarf => |dbg_out| {
                    const abi_size = math.cast(u32, ty.abiSize(self.target.*)) catch {
                        return self.fail("type '{}' too big to fit into stack frame", .{ty});
                    };
                    const adjusted_stack_offset = math.negateCast(offset + abi_size) catch {
                        return self.fail("Stack offset too large for arguments", .{});
                    };

                    try dbg_out.dbg_info.append(link.File.Elf.abbrev_parameter);

                    // Get length of the LEB128 stack offset
                    var counting_writer = std.io.countingWriter(std.io.null_writer);
                    leb128.writeILEB128(counting_writer.writer(), adjusted_stack_offset) catch unreachable;

                    // DW.AT.location, DW.FORM.exprloc
                    // ULEB128 dwarf expression length
                    try leb128.writeULEB128(dbg_out.dbg_info.writer(), counting_writer.bytes_written + 1);
                    try dbg_out.dbg_info.append(DW.OP.breg11);
                    try leb128.writeILEB128(dbg_out.dbg_info.writer(), adjusted_stack_offset);

                    try dbg_out.dbg_info.ensureUnusedCapacity(5 + name_with_null.len);
                    try self.addDbgInfoTypeReloc(ty); // DW.AT.type,  DW.FORM.ref4
                    dbg_out.dbg_info.appendSliceAssumeCapacity(name_with_null); // DW.AT.name, DW.FORM.string
                },
                .plan9 => {},
                .none => {},
            }
        },
        .stack_argument_offset => return self.fail("TODO genArgDbgInfo for stack_argument_offset", .{}),
        else => {},
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
            const abi_size = math.cast(u32, ty.abiSize(self.target.*)) catch {
                return self.fail("type '{}' too big to fit into stack frame", .{ty});
            };
            const abi_align = ty.abiAlignment(self.target.*);
            const stack_offset = try self.allocMem(inst, abi_size, abi_align);
            try self.genSetStack(ty, stack_offset, MCValue{ .register = reg });

            break :blk MCValue{ .stack_offset = stack_offset };
        },
        else => result,
    };
    // TODO generate debug info
    // try self.genArgDbgInfo(inst, mcv);

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
        .cond = .al,
        .data = .{ .imm16 = 0 },
    });
    return self.finishAirBookkeeping();
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const fn_ty = self.air.typeOf(pl_op.operand);
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @bitCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);

    var info = try self.resolveCallingConventionValues(fn_ty);
    defer info.deinit(self);

    // According to the Procedure Call Standard for the ARM
    // Architecture, compare flags are not preserved across
    // calls. Therefore, if some value is currently stored there, we
    // need to save it.
    //
    // TODO once caller-saved registers are implemented, save them
    // here too, but crucially *after* we save the compare flags as
    // saving compare flags may require a new caller-saved register
    try self.spillCompareFlagsIfOccupied();

    // Make space for the arguments passed via the stack
    self.max_end_stack += info.stack_byte_count;

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
                .embedded_in_code => unreachable,
                .memory => unreachable,
                .compare_flags_signed => unreachable,
                .compare_flags_unsigned => unreachable,
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
                .ptr_stack_offset => {
                    return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                },
                .ptr_embedded_in_code => {
                    return self.fail("TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                },
            }
        }

        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                    break :blk @intCast(u32, got.p_vaddr + func.owner_decl.link.elf.offset_table_index * ptr_bytes);
                } else if (self.bin_file.cast(link.File.Coff)) |coff_file|
                    coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes
                else
                    unreachable;

                try self.genSetReg(Type.initTag(.usize), .lr, .{ .memory = got_addr });

                // TODO: add Instruction.supportedOn
                // function for ARM
                if (Target.arm.featureSetHas(self.target.cpu.features, .has_v5t)) {
                    _ = try self.addInst(.{
                        .tag = .blx,
                        .cond = .al,
                        .data = .{ .reg = .lr },
                    });
                } else {
                    return self.fail("TODO fix blx emulatio for ARM <v5", .{});
                    // _ = try self.addInst(.{
                    //     .tag = .mov,
                    //     .cond = .al,
                    //     .data = .{ .rr_op = .{
                    //         .rd = .lr,
                    //         .rn = .r0,
                    //         .op = Instruction.Operand.reg(.pc, Instruction.Operand.Shift.none),
                    //     } },
                    // });
                    // _ = try self.addInst(.{
                    //     .tag = .bx,
                    //     .cond = .al,
                    //     .data = .{ .reg = .lr },
                    // });
                }
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
                if (Register.allocIndex(reg) == null) {
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
    try self.exitlude_jump_relocs.append(self.gpa, try self.addNop());
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
    assert(ty.eql(self.air.typeOf(bin_op.rhs)));
    if (ty.zigTypeTag() == .ErrorSet)
        return self.fail("TODO implement cmp for errors", .{});

    try self.spillCompareFlagsIfOccupied();
    self.compare_flags_inst = inst;

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const result: MCValue = result: {
        const lhs_is_register = lhs == .register;
        const rhs_is_register = rhs == .register;
        // lhs should always be a register
        const rhs_should_be_register = try self.armOperandShouldBeRegister(rhs);

        var lhs_mcv = lhs;
        var rhs_mcv = rhs;

        // Allocate registers
        if (rhs_should_be_register) {
            if (!lhs_is_register and !rhs_is_register) {
                const regs = try self.register_manager.allocRegs(2, .{
                    Air.refToIndex(bin_op.rhs).?, Air.refToIndex(bin_op.lhs).?,
                }, &.{});
                lhs_mcv = MCValue{ .register = regs[0] };
                rhs_mcv = MCValue{ .register = regs[1] };
            } else if (!rhs_is_register) {
                rhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(bin_op.rhs).?, &.{}) };
            }
        }
        if (!lhs_is_register) {
            lhs_mcv = MCValue{ .register = try self.register_manager.allocReg(Air.refToIndex(bin_op.lhs).?, &.{}) };
        }

        // Move the operands to the newly allocated registers
        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        if (lhs_mcv == .register and !lhs_is_register) {
            try self.genSetReg(ty, lhs_mcv.register, lhs);
            branch.inst_table.putAssumeCapacity(Air.refToIndex(bin_op.lhs).?, lhs);
        }
        if (rhs_mcv == .register and !rhs_is_register) {
            try self.genSetReg(ty, rhs_mcv.register, rhs);
            branch.inst_table.putAssumeCapacity(Air.refToIndex(bin_op.rhs).?, rhs);
        }

        // The destination register is not present in the cmp instruction
        // The signedness of the integer does not matter for the cmp instruction
        try self.genArmBinOpCode(undefined, lhs_mcv, rhs_mcv, false, .cmp_eq, undefined);

        break :result switch (ty.isSignedInt()) {
            true => MCValue{ .compare_flags_signed = op },
            false => MCValue{ .compare_flags_unsigned = op },
        };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc: Mir.Inst.Index = reloc: {
        const condition: Condition = switch (cond) {
            .compare_flags_signed => |cmp_op| blk: {
                // Here we map to the opposite condition because the jump is to the false branch.
                const condition = Condition.fromCompareOperatorSigned(cmp_op);
                break :blk condition.negate();
            },
            .compare_flags_unsigned => |cmp_op| blk: {
                // Here we map to the opposite condition because the jump is to the false branch.
                const condition = Condition.fromCompareOperatorUnsigned(cmp_op);
                break :blk condition.negate();
            },
            .register => |reg| blk: {
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
            else => return self.fail("TODO implement condbr {} when condition is {s}", .{ self.target.cpu.arch, @tagName(cond) }),
        };

        break :reloc try self.addInst(.{
            .tag = .b,
            .cond = condition,
            .data = .{ .inst = undefined }, // populated later through performReloc
        });
    };

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
    const parent_compare_flags_inst = self.compare_flags_inst;

    try self.branch_stack.append(.{});

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

    self.branch_stack.pop().deinit(self.gpa);

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
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
    const start_index = @intCast(Mir.Inst.Index, self.mir_instructions.len);
    try self.genBody(body);
    try self.jump(start_index);
    return self.finishAirBookkeeping();
}

/// Send control flow to `inst`.
fn jump(self: *Self, inst: Mir.Inst.Index) !void {
    _ = try self.addInst(.{
        .tag = .b,
        .cond = .al,
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
    const block_data = self.blocks.getPtr(inst).?;
    defer block_data.relocs.deinit(self.gpa);

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    try self.genBody(body);

    for (block_data.relocs.items) |reloc| try self.performReloc(reloc);

    const result = @bitCast(MCValue, block_data.mcv);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition = pl_op.operand;
    _ = condition;
    return self.fail("TODO airSwitch for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, .dead, .{ condition, .none, .none });
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

fn airBoolOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const air_tags = self.air.instructions.items(.tag);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else switch (air_tags[inst]) {
        .bool_and => try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .bool_and),
        .bool_or => try self.genArmBinOp(inst, bin_op.lhs, bin_op.rhs, .bool_or),
        else => unreachable, // Not a boolean operation
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn br(self: *Self, block: Air.Inst.Index, operand: Air.Inst.Ref) !void {
    const block_data = self.blocks.getPtr(block).?;

    if (self.air.typeOf(operand).hasCodeGenBits()) {
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
    try block_data.relocs.append(self.gpa, try self.addInst(.{
        .tag = .b,
        .cond = .al,
        .data = .{ .inst = undefined }, // populated later through performReloc
    }));
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const air_datas = self.air.instructions.items(.data);
    const air_extra = self.air.extraData(Air.Asm, air_datas[inst].ty_pl.payload);
    const zir = self.mod_fn.owner_decl.getFileScope().zir;
    const extended = zir.instructions.items(.data)[air_extra.data.zir_index].extended;
    const zir_extra = zir.extraData(Zir.Inst.Asm, extended.operand);
    const asm_source = zir.nullTerminatedString(zir_extra.data.asm_source);
    const outputs_len = @truncate(u5, extended.small);
    const args_len = @truncate(u5, extended.small >> 5);
    const clobbers_len = @truncate(u5, extended.small >> 10);
    _ = clobbers_len; // TODO honor these
    const is_volatile = @truncate(u1, extended.small >> 15) != 0;
    const outputs = @bitCast([]const Air.Inst.Ref, self.air.extra[air_extra.end..][0..outputs_len]);
    const args = @bitCast([]const Air.Inst.Ref, self.air.extra[air_extra.end + outputs.len ..][0..args_len]);

    if (outputs_len > 1) {
        return self.fail("TODO implement codegen for asm with more than 1 output", .{});
    }
    var extra_i: usize = zir_extra.end;
    const output_constraint: ?[]const u8 = out: {
        var i: usize = 0;
        while (i < outputs_len) : (i += 1) {
            const output = zir.extraData(Zir.Inst.Asm.Output, extra_i);
            extra_i = output.end;
            break :out zir.nullTerminatedString(output.data.constraint);
        }
        break :out null;
    };

    const dead = !is_volatile and self.liveness.isUnused(inst);
    const result: MCValue = if (dead) .dead else result: {
        for (args) |arg| {
            const input = zir.extraData(Zir.Inst.Asm.Input, extra_i);
            extra_i = input.end;
            const constraint = zir.nullTerminatedString(input.data.constraint);

            if (constraint.len < 3 or constraint[0] != '{' or constraint[constraint.len - 1] != '}') {
                return self.fail("unrecognized asm input constraint: '{s}'", .{constraint});
            }
            const reg_name = constraint[1 .. constraint.len - 1];
            const reg = parseRegName(reg_name) orelse
                return self.fail("unrecognized register: '{s}'", .{reg_name});

            const arg_mcv = try self.resolveInst(arg);
            try self.register_manager.getReg(reg, null);
            try self.genSetReg(self.air.typeOf(arg), reg, arg_mcv);
        }

        if (mem.eql(u8, asm_source, "svc #0")) {
            _ = try self.addInst(.{
                .tag = .svc,
                .cond = .al,
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
    if (outputs.len + args.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        std.mem.copy(Air.Inst.Ref, &buf, outputs);
        std.mem.copy(Air.Inst.Ref, buf[outputs.len..], args);
        return self.finishAir(inst, result, buf);
    }
    var bt = try self.iterateBigTomb(inst, outputs.len + args.len);
    for (outputs) |output| {
        bt.feed(output);
    }
    for (args) |arg| {
        bt.feed(arg);
    }
    return bt.finishAir(result);
}

fn iterateBigTomb(self: *Self, inst: Air.Inst.Index, operand_count: usize) !BigTomb {
    try self.ensureProcessDeathCapacity(operand_count + 1);
    return BigTomb{
        .function = self,
        .inst = inst,
        .tomb_bits = self.liveness.getTombBits(inst),
        .big_tomb_bits = self.liveness.special.get(inst) orelse 0,
        .bit_index = 0,
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
    switch (mcv) {
        .dead => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (ty.abiSize(self.target.*)) {
                1 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                8 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .compare_flags_unsigned,
        .compare_flags_signed,
        .immediate,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .embedded_in_code => |code_offset| {
            _ = code_offset;
            return self.fail("TODO implement set stack variable from embedded_in_code", .{});
        },
        .register => |reg| {
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = stack_offset + abi_size;

            switch (abi_size) {
                1, 4 => {
                    const offset = if (math.cast(u12, adj_off)) |imm| blk: {
                        break :blk Instruction.Offset.imm(imm);
                    } else |_| Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }), 0);

                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .strb,
                        4 => .str,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .cond = .al,
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
                    const offset = if (adj_off <= math.maxInt(u8)) blk: {
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, adj_off));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }));

                    _ = try self.addInst(.{
                        .tag = .strh,
                        .cond = .al,
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
        .memory,
        .stack_argument_offset,
        => {
            if (ty.abiSize(self.target.*) <= 4) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            } else {
                return self.fail("TODO implement memcpy", .{});
            }
        },
        .stack_offset => |off| {
            if (stack_offset == off)
                return; // Copy stack variable to itself; nothing to do.

            if (ty.abiSize(self.target.*) <= 4) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            } else {
                return self.fail("TODO implement memcpy", .{});
            }
        },
    }
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    switch (mcv) {
        .dead => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaa });
        },
        .compare_flags_unsigned,
        .compare_flags_signed,
        => |op| {
            const condition = switch (mcv) {
                .compare_flags_unsigned => Condition.fromCompareOperatorUnsigned(op),
                .compare_flags_signed => Condition.fromCompareOperatorSigned(op),
                else => unreachable,
            };

            const zero = Instruction.Operand.imm(0, 0);
            const one = Instruction.Operand.imm(1, 0);

            // mov reg, 0
            _ = try self.addInst(.{
                .tag = .mov,
                .cond = .al,
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
            if (x > math.maxInt(u32)) return self.fail("ARM registers are 32-bit wide", .{});

            if (Instruction.Operand.fromU32(@intCast(u32, x))) |op| {
                _ = try self.addInst(.{
                    .tag = .mov,
                    .cond = .al,
                    .data = .{ .rr_op = .{
                        .rd = reg,
                        .rn = .r0,
                        .op = op,
                    } },
                });
            } else if (Instruction.Operand.fromU32(~@intCast(u32, x))) |op| {
                _ = try self.addInst(.{
                    .tag = .mvn,
                    .cond = .al,
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
                        .cond = .al,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @intCast(u16, x),
                        } },
                    });
                } else {
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .cond = .al,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = .r0,
                            .op = Instruction.Operand.imm(@truncate(u8, x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .cond = .al,
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
                        .cond = .al,
                        .data = .{ .r_imm16 = .{
                            .rd = reg,
                            .imm16 = @truncate(u16, x),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .movt,
                        .cond = .al,
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
                        .cond = .al,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = .r0,
                            .op = Instruction.Operand.imm(@truncate(u8, x), 0),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .cond = .al,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 8), 12),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .cond = .al,
                        .data = .{ .rr_op = .{
                            .rd = reg,
                            .rn = reg,
                            .op = Instruction.Operand.imm(@truncate(u8, x >> 16), 8),
                        } },
                    });
                    _ = try self.addInst(.{
                        .tag = .orr,
                        .cond = .al,
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
                .cond = .al,
                .data = .{ .rr_op = .{
                    .rd = reg,
                    .rn = .r0,
                    .op = Instruction.Operand.reg(src_reg, Instruction.Operand.Shift.none),
                } },
            });
        },
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = addr });
            _ = try self.addInst(.{
                .tag = .ldr,
                .cond = .al,
                .data = .{ .rr_offset = .{
                    .rt = reg,
                    .rn = reg,
                    .offset = .{ .offset = Instruction.Offset.none },
                } },
            });
        },
        .stack_offset => |unadjusted_off| {
            // TODO: maybe addressing from sp instead of fp
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = unadjusted_off + abi_size;

            switch (abi_size) {
                1, 4 => {
                    const offset = if (adj_off <= math.maxInt(u12)) blk: {
                        break :blk Instruction.Offset.imm(@intCast(u12, adj_off));
                    } else Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }), 0);

                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .ldrb,
                        4 => .ldr,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .cond = .al,
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
                    const offset = if (adj_off <= math.maxInt(u8)) blk: {
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, adj_off));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }));

                    _ = try self.addInst(.{
                        .tag = .ldrh,
                        .cond = .al,
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
                else => return self.fail("TODO a type of size {} is not allowed in a register", .{abi_size}),
            }
        },
        .stack_argument_offset => |unadjusted_off| {
            // TODO: maybe addressing from sp instead of fp
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = unadjusted_off + abi_size;

            const tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .ldrb_stack_argument,
                2 => .ldrh_stack_argument,
                4 => .ldr_stack_argument,
                else => unreachable,
            };

            _ = try self.addInst(.{
                .tag = tag,
                .cond = .al,
                .data = .{ .r_stack_offset = .{
                    .rt = reg,
                    .stack_offset = @intCast(u32, adj_off),
                } },
            });
        },
        else => return self.fail("TODO implement getSetReg for arm {}", .{mcv}),
    }
}

fn genSetStackArgument(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    switch (mcv) {
        .dead => unreachable,
        .none, .unreach => return,
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (ty.abiSize(self.target.*)) {
                1 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaa }),
                2 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaa }),
                4 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaaaaaa }),
                8 => return self.genSetStackArgument(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .register => |reg| {
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = stack_offset - abi_size;

            switch (abi_size) {
                1, 4 => {
                    const offset = if (math.cast(u12, adj_off)) |imm| blk: {
                        break :blk Instruction.Offset.imm(imm);
                    } else |_| Instruction.Offset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }), 0);

                    const tag: Mir.Inst.Tag = switch (abi_size) {
                        1 => .strb,
                        4 => .str,
                        else => unreachable,
                    };

                    _ = try self.addInst(.{
                        .tag = tag,
                        .cond = .al,
                        .data = .{ .rr_offset = .{
                            .rt = reg,
                            .rn = .sp,
                            .offset = .{ .offset = offset },
                        } },
                    });
                },
                2 => {
                    const offset = if (adj_off <= math.maxInt(u8)) blk: {
                        break :blk Instruction.ExtraLoadStoreOffset.imm(@intCast(u8, adj_off));
                    } else Instruction.ExtraLoadStoreOffset.reg(try self.copyToTmpRegister(Type.initTag(.u32), MCValue{ .immediate = adj_off }));

                    _ = try self.addInst(.{
                        .tag = .strh,
                        .cond = .al,
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
        .immediate,
        .compare_flags_signed,
        .compare_flags_unsigned,
        .stack_offset,
        .memory,
        .stack_argument_offset,
        .embedded_in_code,
        => {
            if (ty.abiSize(self.target.*) <= 4) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArgument(ty, stack_offset, MCValue{ .register = reg });
            } else {
                return self.fail("TODO implement memcpy", .{});
            }
        },
        .ptr_stack_offset => {
            return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
        },
        .ptr_embedded_in_code => {
            return self.fail("TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
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

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    // First section of indexes correspond to a set number of constant values.
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        const tv = Air.Inst.Ref.typed_value_map[ref_int];
        if (!tv.ty.hasCodeGenBits()) {
            return MCValue{ .none = {} };
        }
        return self.genTypedValue(tv);
    }

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.air.typeOf(inst);
    if (!inst_ty.hasCodeGenBits())
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

fn genTypedValue(self: *Self, typed_value: TypedValue) InnerError!MCValue {
    if (typed_value.val.isUndef())
        return MCValue{ .undef = {} };
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);
    switch (typed_value.ty.zigTypeTag()) {
        .Pointer => switch (typed_value.ty.ptrSize()) {
            .Slice => {
                var buf: Type.SlicePtrFieldTypeBuffer = undefined;
                const ptr_type = typed_value.ty.slicePtrFieldType(&buf);
                const ptr_mcv = try self.genTypedValue(.{ .ty = ptr_type, .val = typed_value.val });
                const slice_len = typed_value.val.sliceLen();
                // Codegen can't handle some kinds of indirection. If the wrong union field is accessed here it may mean
                // the Sema code needs to use anonymous Decls or alloca instructions to store data.
                const ptr_imm = ptr_mcv.memory;
                _ = slice_len;
                _ = ptr_imm;
                // We need more general support for const data being stored in memory to make this work.
                return self.fail("TODO codegen for const slices", .{});
            },
            else => {
                if (typed_value.val.castTag(.decl_ref)) |payload| {
                    const decl = payload.data;
                    decl.alive = true;
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
                        try p9.seeDecl(decl);
                        const got_addr = p9.bases.data + decl.link.plan9.got_index.? * ptr_bytes;
                        return MCValue{ .memory = got_addr };
                    } else {
                        return self.fail("TODO codegen non-ELF const Decl pointer", .{});
                    }
                }
                if (typed_value.val.tag() == .int_u64) {
                    return MCValue{ .immediate = typed_value.val.toUnsignedInt() };
                }
                return self.fail("TODO codegen more kinds of const pointers", .{});
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits > ptr_bits or info.signedness == .signed) {
                return self.fail("TODO const int bigger than ptr and signed int", .{});
            }
            return MCValue{ .immediate = typed_value.val.toUnsignedInt() };
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

            if (!payload_type.hasCodeGenBits()) {
                // We use the error type directly as the type.
                return self.genTypedValue(.{ .ty = error_type, .val = sub_val });
            }

            return self.fail("TODO implement error union const of type '{}'", .{typed_value.ty});
        },
        else => return self.fail("TODO implement const of type '{}'", .{typed_value.ty}),
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
            // ARM Procedure Call Standard, Chapter 6.5
            var ncrn: usize = 0; // Next Core Register Number
            var nsaa: u32 = 0; // Next stacked argument address

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

                    result.args[i] = .{ .stack_argument_offset = nsaa };
                    nsaa += param_size;
                }
            }

            result.stack_byte_count = nsaa;
            result.stack_align = 8;
        },
        else => return self.fail("TODO implement function parameters for {} on arm", .{cc}),
    }

    if (ret_ty.zigTypeTag() == .NoReturn) {
        result.return_value = .{ .unreach = {} };
    } else if (!ret_ty.hasCodeGenBits()) {
        result.return_value = .{ .none = {} };
    } else switch (cc) {
        .Naked => unreachable,
        .Unspecified, .C => {
            const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
            if (ret_ty_size <= 4) {
                result.return_value = .{ .register = c_abi_int_return_regs[0] };
            } else {
                return self.fail("TODO support more return types for ARM backend", .{});
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

const Register = @import("bits.zig").Register;
const Instruction = @import("bits.zig").Instruction;
const Condition = @import("bits.zig").Condition;
const callee_preserved_regs = @import("bits.zig").callee_preserved_regs;
const c_abi_int_param_regs = @import("bits.zig").c_abi_int_param_regs;
const c_abi_int_return_regs = @import("bits.zig").c_abi_int_return_regs;

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}
