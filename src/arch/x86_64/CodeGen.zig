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
const Encoder = @import("bits.zig").Encoder;
const ErrorMsg = Module.ErrorMsg;
const FnResult = @import("../../codegen.zig").FnResult;
const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const Liveness = @import("../../Liveness.zig");
const Module = @import("../../Module.zig");
const RegisterManager = @import("../../register_manager.zig").RegisterManager;
const Target = std.Target;
const Type = @import("../../type.zig").Type;
const TypedValue = @import("../../TypedValue.zig");
const Value = @import("../../value.zig").Value;
const Zir = @import("../../Zir.zig");

const InnerError = error{
    OutOfMemory,
    CodegenFail,
};

arch: std.Target.Cpu.Arch,
gpa: *Allocator,
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

prev_di_line: u32,
prev_di_column: u32,
/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,
/// Relative to the beginning of `code`.
prev_di_pc: usize,

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

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .embedded_in_code, .memory, .stack_offset => true,
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
            => false,

            .register,
            .stack_offset,
            => true,
        };
    }
};

const Branch = struct {
    inst_table: std.AutoArrayHashMapUnmanaged(Air.Inst.Index, MCValue) = .{},

    fn deinit(self: *Branch, gpa: *Allocator) void {
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
        cond: @import("../../arch/arm/bits.zig").Condition,
    },
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
    arch: std.Target.Cpu.Arch,
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    module_fn: *Module.Fn,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) GenerateSymbolError!FnResult {
    if (build_options.skip_non_native and builtin.cpu.arch != arch) {
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
        .arch = arch,
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
        .prev_di_pc = 0,
        .prev_di_line = module_fn.lbrace_line,
        .prev_di_column = module_fn.lbrace_column,
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

    if (function.err_msg) |em| {
        return FnResult{ .fail = em };
    } else {
        return FnResult{ .appended = {} };
    }
}

fn gen(self: *Self) !void {
    try self.code.ensureUnusedCapacity(11);

    const cc = self.fn_type.fnCallingConvention();
    if (cc != .Naked) {
        // We want to subtract the aligned stack frame size from rsp here, but we don't
        // yet know how big it will be, so we leave room for a 4-byte stack size.
        // TODO During semantic analysis, check if there are no function calls. If there
        // are none, here we can omit the part where we subtract and then add rsp.
        self.code.appendSliceAssumeCapacity(&[_]u8{
            0x55, // push rbp
            0x48, 0x89, 0xe5, // mov rbp, rsp
            0x48, 0x81, 0xec, // sub rsp, imm32 (with reloc)
        });
        const reloc_index = self.code.items.len;
        self.code.items.len += 4;

        try self.dbgSetPrologueEnd();
        try self.genBody(self.air.getMainBody());

        const stack_end = self.max_end_stack;
        if (stack_end > math.maxInt(i32))
            return self.failSymbol("too much stack used in call parameters", .{});
        const aligned_stack_end = mem.alignForward(stack_end, self.stack_align);
        mem.writeIntLittle(u32, self.code.items[reloc_index..][0..4], @intCast(u32, aligned_stack_end));

        if (self.code.items.len >= math.maxInt(i32)) {
            return self.failSymbol("unable to perform relocation: jump too far", .{});
        }
        if (self.exitlude_jump_relocs.items.len == 1) {
            self.code.items.len -= 5;
        } else for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            const amt = self.code.items.len - (jmp_reloc + 4);
            const s32_amt = @intCast(i32, amt);
            mem.writeIntLittle(i32, self.code.items[jmp_reloc..][0..4], s32_amt);
        }

        // Important to be after the possible self.code.items.len -= 5 above.
        try self.dbgSetEpilogueBegin();

        try self.code.ensureUnusedCapacity(9);
        // add rsp, x
        if (aligned_stack_end > math.maxInt(i8)) {
            // example: 48 81 c4 ff ff ff 7f  add    rsp,0x7fffffff
            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x81, 0xc4 });
            const x = @intCast(u32, aligned_stack_end);
            mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), x);
        } else if (aligned_stack_end != 0) {
            // example: 48 83 c4 7f           add    rsp,0x7f
            const x = @intCast(u8, aligned_stack_end);
            self.code.appendSliceAssumeCapacity(&[_]u8{ 0x48, 0x83, 0xc4, x });
        }

        self.code.appendSliceAssumeCapacity(&[_]u8{
            0x5d, // pop rbp
            0xc3, // ret
        });
    } else {
        try self.dbgSetPrologueEnd();
        try self.genBody(self.air.getMainBody());
        try self.dbgSetEpilogueBegin();
    }

    // Drop them off at the rbrace.
    try self.dbgAdvancePCAndLine(self.end_di_line, self.end_di_column);
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

fn dbgSetPrologueEnd(self: *Self) InnerError!void {
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_prologue_end);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn dbgSetEpilogueBegin(self: *Self) InnerError!void {
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            try dbg_out.dbg_line.append(DW.LNS.set_epilogue_begin);
            try self.dbgAdvancePCAndLine(self.prev_di_line, self.prev_di_column);
        },
        .plan9 => {},
        .none => {},
    }
}

fn dbgAdvancePCAndLine(self: *Self, line: u32, column: u32) InnerError!void {
    const delta_line = @intCast(i32, line) - @intCast(i32, self.prev_di_line);
    const delta_pc: usize = self.code.items.len - self.prev_di_pc;
    switch (self.debug_output) {
        .dwarf => |dbg_out| {
            // TODO Look into using the DWARF special opcodes to compress this data.
            // It lets you emit single-byte opcodes that add different numbers to
            // both the PC and the line number at the same time.
            try dbg_out.dbg_line.ensureUnusedCapacity(11);
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_pc);
            leb128.writeULEB128(dbg_out.dbg_line.writer(), delta_pc) catch unreachable;
            if (delta_line != 0) {
                dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.advance_line);
                leb128.writeILEB128(dbg_out.dbg_line.writer(), delta_line) catch unreachable;
            }
            dbg_out.dbg_line.appendAssumeCapacity(DW.LNS.copy);
            self.prev_di_pc = self.code.items.len;
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .plan9 => |dbg_out| {
            if (delta_pc <= 0) return; // only do this when the pc changes
            // we have already checked the target in the linker to make sure it is compatable
            const quant = @import("../../link/Plan9/aout.zig").getPCQuant(self.target.cpu.arch) catch unreachable;

            // increasing the line number
            try @import("../../link/Plan9.zig").changeLine(dbg_out.dbg_line, delta_line);
            // increasing the pc
            const d_pc_p9 = @intCast(i64, delta_pc) - quant;
            if (d_pc_p9 > 0) {
                // minus one because if its the last one, we want to leave space to change the line which is one quanta
                try dbg_out.dbg_line.append(@intCast(u8, @divExact(d_pc_p9, quant) + 128) - quant);
                if (dbg_out.pcop_change_index.*) |pci|
                    dbg_out.dbg_line.items[pci] += 1;
                dbg_out.pcop_change_index.* = @intCast(u32, dbg_out.dbg_line.items.len - 1);
            } else if (d_pc_p9 == 0) {
                // we don't need to do anything, because adding the quant does it for us
            } else unreachable;
            if (dbg_out.start_line.* == null)
                dbg_out.start_line.* = self.prev_di_line;
            dbg_out.end_line.* = line;
            // only do this if the pc changed
            self.prev_di_line = line;
            self.prev_di_column = column;
            self.prev_di_pc = self.code.items.len;
        },
        .none => {},
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
            const canon_reg = reg.to64();
            self.register_manager.freeReg(canon_reg);
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
                return MCValue{ .register = registerAlias(reg, abi_size) };
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
    assert(reg == reg_mcv.register.to64());
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
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
    if (info_a.signedness != info_b.signedness)
        return self.fail("TODO gen intcast sign safety in semantic analysis", .{});

    if (info_a.bits == info_b.bits)
        return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });

    return self.fail("TODO implement intCast for {}", .{self.target.cpu.arch});
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .dead, .{ ty_op.operand, .none, .none });

    const operand = try self.resolveInst(ty_op.operand);
    _ = operand;
    return self.fail("TODO implement trunc for {}", .{self.target.cpu.arch});
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
        break :result try self.genX8664BinMath(inst, ty_op.operand, .bool_true);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airMin(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement min for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement slice for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAdd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement addwrap for {}", .{self.target.cpu.arch});
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

fn airSub(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement subwrap for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement mulwrap for {}", .{self.target.cpu.arch});
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

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement rem for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement mod for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitAnd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement xor for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement shl for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement .optional_payload for {}", .{self.target.cpu.arch});
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

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement unwrap error union error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement unwrap error union payload for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement wrap errunion payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement wrap errunion error for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement slice_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement slice_len for {}", .{self.target.cpu.arch});
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

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement slice_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement slice_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement array_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement ptr_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement ptr_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    _ = bin_op;
    return self.fail("TODO implement airSetUnionTag for {}", .{self.target.cpu.arch});
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
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
        .register => {
            return self.fail("TODO implement loading from MCValue.register for {}", .{self.target.cpu.arch});
        },
        .memory => |addr| {
            const reg = try self.register_manager.allocReg(null, &.{});
            try self.genSetReg(ptr_ty, reg, .{ .memory = addr });
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
        .stack_offset => {
            return self.fail("TODO implement loading from MCValue.stack_offset", .{});
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

/// Perform "binary" operators, excluding comparisons.
/// Currently, the following ops are supported:
/// ADD, SUB, XOR, OR, AND
fn genX8664BinMath(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    // We'll handle these ops in two steps.
    // 1) Prepare an output location (register or memory)
    //    This location will be the location of the operand that dies (if one exists)
    //    or just a temporary register (if one doesn't exist)
    // 2) Perform the op with the other argument
    // 3) Sometimes, the output location is memory but the op doesn't support it.
    //    In this case, copy that location to a register, then perform the op to that register instead.
    //
    // TODO: make this algorithm less bad

    try self.code.ensureUnusedCapacity(8);

    const lhs = try self.resolveInst(op_lhs);
    const rhs = try self.resolveInst(op_rhs);

    // There are 2 operands, destination and source.
    // Either one, but not both, can be a memory operand.
    // Source operand can be an immediate, 8 bits or 32 bits.
    // So, if either one of the operands dies with this instruction, we can use it
    // as the result MCValue.
    var dst_mcv: MCValue = undefined;
    var src_mcv: MCValue = undefined;
    var src_inst: Air.Inst.Ref = undefined;
    if (self.reuseOperand(inst, op_lhs, 0, lhs)) {
        // LHS dies; use it as the destination.
        // Both operands cannot be memory.
        src_inst = op_rhs;
        if (lhs.isMemory() and rhs.isMemory()) {
            dst_mcv = try self.copyToNewRegister(inst, lhs);
            src_mcv = rhs;
        } else {
            dst_mcv = lhs;
            src_mcv = rhs;
        }
    } else if (self.reuseOperand(inst, op_rhs, 1, rhs)) {
        // RHS dies; use it as the destination.
        // Both operands cannot be memory.
        src_inst = op_lhs;
        if (lhs.isMemory() and rhs.isMemory()) {
            dst_mcv = try self.copyToNewRegister(inst, rhs);
            src_mcv = lhs;
        } else {
            dst_mcv = rhs;
            src_mcv = lhs;
        }
    } else {
        if (lhs.isMemory()) {
            dst_mcv = try self.copyToNewRegister(inst, lhs);
            src_mcv = rhs;
            src_inst = op_rhs;
        } else {
            dst_mcv = try self.copyToNewRegister(inst, rhs);
            src_mcv = lhs;
            src_inst = op_lhs;
        }
    }
    // This instruction supports only signed 32-bit immediates at most. If the immediate
    // value is larger than this, we put it in a register.
    // A potential opportunity for future optimization here would be keeping track
    // of the fact that the instruction is available both as an immediate
    // and as a register.
    switch (src_mcv) {
        .immediate => |imm| {
            if (imm > math.maxInt(u31)) {
                src_mcv = MCValue{ .register = try self.copyToTmpRegister(Type.initTag(.u64), src_mcv) };
            }
        },
        else => {},
    }

    // Now for step 2, we perform the actual op
    const inst_ty = self.air.typeOfIndex(inst);
    const air_tags = self.air.instructions.items(.tag);
    switch (air_tags[inst]) {
        // TODO: Generate wrapping and non-wrapping versions separately
        .add, .addwrap => try self.genX8664BinMathCode(inst_ty, dst_mcv, src_mcv, 0, 0x00),
        .bool_or, .bit_or => try self.genX8664BinMathCode(inst_ty, dst_mcv, src_mcv, 1, 0x08),
        .bool_and, .bit_and => try self.genX8664BinMathCode(inst_ty, dst_mcv, src_mcv, 4, 0x20),
        .sub, .subwrap => try self.genX8664BinMathCode(inst_ty, dst_mcv, src_mcv, 5, 0x28),
        .xor, .not => try self.genX8664BinMathCode(inst_ty, dst_mcv, src_mcv, 6, 0x30),

        .mul, .mulwrap => try self.genX8664Imul(inst_ty, dst_mcv, src_mcv),
        else => unreachable,
    }

    return dst_mcv;
}

/// Wrap over Instruction.encodeInto to translate errors
fn encodeX8664Instruction(self: *Self, inst: Instruction) !void {
    inst.encodeInto(self.code) catch |err| {
        if (err == error.OutOfMemory)
            return error.OutOfMemory
        else
            return self.fail("Instruction.encodeInto failed because {s}", .{@errorName(err)});
    };
}

/// This function encodes a binary operation for x86_64
/// intended for use with the following opcode ranges
/// because they share the same structure.
///
/// Thus not all binary operations can be used here
/// -- multiplication needs to be done with imul,
/// which doesn't have as convenient an interface.
///
/// "opx"-style instructions use the opcode extension field to indicate which instruction to execute:
///
/// opx = /0: add
/// opx = /1: or
/// opx = /2: adc
/// opx = /3: sbb
/// opx = /4: and
/// opx = /5: sub
/// opx = /6: xor
/// opx = /7: cmp
///
/// opcode  | operand shape
/// --------+----------------------
/// 80 /opx | *r/m8*,        imm8
/// 81 /opx | *r/m16/32/64*, imm16/32
/// 83 /opx | *r/m16/32/64*, imm8
///
/// "mr"-style instructions use the low bits of opcode to indicate shape of instruction:
///
/// mr = 00: add
/// mr = 08: or
/// mr = 10: adc
/// mr = 18: sbb
/// mr = 20: and
/// mr = 28: sub
/// mr = 30: xor
/// mr = 38: cmp
///
/// opcode | operand shape
/// -------+-------------------------
/// mr + 0 | *r/m8*,        r8
/// mr + 1 | *r/m16/32/64*, r16/32/64
/// mr + 2 | *r8*,          r/m8
/// mr + 3 | *r16/32/64*,   r/m16/32/64
/// mr + 4 | *AL*,          imm8
/// mr + 5 | *rAX*,         imm16/32
///
/// TODO: rotates and shifts share the same structure, so we can potentially implement them
///       at a later date with very similar code.
///       They have "opx"-style instructions, but no "mr"-style instructions.
///
/// opx = /0: rol,
/// opx = /1: ror,
/// opx = /2: rcl,
/// opx = /3: rcr,
/// opx = /4: shl sal,
/// opx = /5: shr,
/// opx = /6: sal shl,
/// opx = /7: sar,
///
/// opcode  | operand shape
/// --------+------------------
/// c0 /opx | *r/m8*,        imm8
/// c1 /opx | *r/m16/32/64*, imm8
/// d0 /opx | *r/m8*,        1
/// d1 /opx | *r/m16/32/64*, 1
/// d2 /opx | *r/m8*,        CL    (for context, CL is register 1)
/// d3 /opx | *r/m16/32/64*, CL    (for context, CL is register 1)
fn genX8664BinMathCode(
    self: *Self,
    dst_ty: Type,
    dst_mcv: MCValue,
    src_mcv: MCValue,
    opx: u3,
    mr: u8,
) !void {
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => try self.genSetReg(dst_ty, dst_reg, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |src_reg| {
                    // for register, register use mr + 1
                    // addressing mode: *r/m16/32/64*, r16/32/64
                    const abi_size = dst_ty.abiSize(self.target.*);
                    const encoder = try Encoder.init(self.code, 3);
                    encoder.rex(.{
                        .w = abi_size == 8,
                        .r = src_reg.isExtended(),
                        .b = dst_reg.isExtended(),
                    });
                    encoder.opcode_1byte(mr + 1);
                    encoder.modRm_direct(
                        src_reg.low_id(),
                        dst_reg.low_id(),
                    );
                },
                .immediate => |imm| {
                    // register, immediate use opx = 81 or 83 addressing modes:
                    // opx = 81: r/m16/32/64, imm16/32
                    // opx = 83: r/m16/32/64, imm8
                    const imm32 = @intCast(i32, imm); // This case must be handled before calling genX8664BinMathCode.
                    if (imm32 <= math.maxInt(i8)) {
                        const abi_size = dst_ty.abiSize(self.target.*);
                        const encoder = try Encoder.init(self.code, 4);
                        encoder.rex(.{
                            .w = abi_size == 8,
                            .b = dst_reg.isExtended(),
                        });
                        encoder.opcode_1byte(0x83);
                        encoder.modRm_direct(
                            opx,
                            dst_reg.low_id(),
                        );
                        encoder.imm8(@intCast(i8, imm32));
                    } else {
                        const abi_size = dst_ty.abiSize(self.target.*);
                        const encoder = try Encoder.init(self.code, 7);
                        encoder.rex(.{
                            .w = abi_size == 8,
                            .b = dst_reg.isExtended(),
                        });
                        encoder.opcode_1byte(0x81);
                        encoder.modRm_direct(
                            opx,
                            dst_reg.low_id(),
                        );
                        encoder.imm32(@intCast(i32, imm32));
                    }
                },
                .embedded_in_code, .memory => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source memory", .{});
                },
                .stack_offset => |off| {
                    // register, indirect use mr + 3
                    // addressing mode: *r16/32/64*, r/m16/32/64
                    const abi_size = dst_ty.abiSize(self.target.*);
                    const adj_off = off + abi_size;
                    if (off > math.maxInt(i32)) {
                        return self.fail("stack offset too large", .{});
                    }
                    const encoder = try Encoder.init(self.code, 7);
                    encoder.rex(.{
                        .w = abi_size == 8,
                        .r = dst_reg.isExtended(),
                    });
                    encoder.opcode_1byte(mr + 3);
                    if (adj_off <= std.math.maxInt(i8)) {
                        encoder.modRm_indirectDisp8(
                            dst_reg.low_id(),
                            Register.ebp.low_id(),
                        );
                        encoder.disp8(-@intCast(i8, adj_off));
                    } else {
                        encoder.modRm_indirectDisp32(
                            dst_reg.low_id(),
                            Register.ebp.low_id(),
                        );
                        encoder.disp32(-@intCast(i32, adj_off));
                    }
                },
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (signed)", .{});
                },
            }
        },
        .stack_offset => |off| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => return self.genSetStack(dst_ty, off, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |src_reg| {
                    try self.genX8664ModRMRegToStack(dst_ty, off, src_reg, mr + 0x1);
                },
                .immediate => |imm| {
                    _ = imm;
                    return self.fail("TODO implement x86 ADD/SUB/CMP source immediate", .{});
                },
                .embedded_in_code, .memory, .stack_offset => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source memory", .{});
                },
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source compare flag (signed)", .{});
                },
            }
        },
        .embedded_in_code, .memory => {
            return self.fail("TODO implement x86 ADD/SUB/CMP destination memory", .{});
        },
    }
}

/// Performs integer multiplication between dst_mcv and src_mcv, storing the result in dst_mcv.
fn genX8664Imul(
    self: *Self,
    dst_ty: Type,
    dst_mcv: MCValue,
    src_mcv: MCValue,
) !void {
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .ptr_stack_offset => unreachable,
        .ptr_embedded_in_code => unreachable,
        .register => |dst_reg| {
            switch (src_mcv) {
                .none => unreachable,
                .undef => try self.genSetReg(dst_ty, dst_reg, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |src_reg| {
                    // register, register
                    //
                    // Use the following imul opcode
                    // 0F AF /r: IMUL r32/64, r/m32/64
                    const abi_size = dst_ty.abiSize(self.target.*);
                    const encoder = try Encoder.init(self.code, 4);
                    encoder.rex(.{
                        .w = abi_size == 8,
                        .r = dst_reg.isExtended(),
                        .b = src_reg.isExtended(),
                    });
                    encoder.opcode_2byte(0x0f, 0xaf);
                    encoder.modRm_direct(
                        dst_reg.low_id(),
                        src_reg.low_id(),
                    );
                },
                .immediate => |imm| {
                    // register, immediate:
                    // depends on size of immediate.
                    //
                    // immediate fits in i8:
                    // 6B /r ib: IMUL r32/64, r/m32/64, imm8
                    //
                    // immediate fits in i32:
                    // 69 /r id: IMUL r32/64, r/m32/64, imm32
                    //
                    // immediate is huge:
                    // split into 2 instructions
                    // 1) copy the 64 bit immediate into a tmp register
                    // 2) perform register,register mul
                    // 0F AF /r: IMUL r32/64, r/m32/64
                    if (math.minInt(i8) <= imm and imm <= math.maxInt(i8)) {
                        const abi_size = dst_ty.abiSize(self.target.*);
                        const encoder = try Encoder.init(self.code, 4);
                        encoder.rex(.{
                            .w = abi_size == 8,
                            .r = dst_reg.isExtended(),
                            .b = dst_reg.isExtended(),
                        });
                        encoder.opcode_1byte(0x6B);
                        encoder.modRm_direct(
                            dst_reg.low_id(),
                            dst_reg.low_id(),
                        );
                        encoder.imm8(@intCast(i8, imm));
                    } else if (math.minInt(i32) <= imm and imm <= math.maxInt(i32)) {
                        const abi_size = dst_ty.abiSize(self.target.*);
                        const encoder = try Encoder.init(self.code, 7);
                        encoder.rex(.{
                            .w = abi_size == 8,
                            .r = dst_reg.isExtended(),
                            .b = dst_reg.isExtended(),
                        });
                        encoder.opcode_1byte(0x69);
                        encoder.modRm_direct(
                            dst_reg.low_id(),
                            dst_reg.low_id(),
                        );
                        encoder.imm32(@intCast(i32, imm));
                    } else {
                        const src_reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                        return self.genX8664Imul(dst_ty, dst_mcv, MCValue{ .register = src_reg });
                    }
                },
                .embedded_in_code, .memory, .stack_offset => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
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
                .undef => return self.genSetStack(dst_ty, off, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |src_reg| {
                    // copy dst to a register
                    const dst_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
                    // multiply into dst_reg
                    // register, register
                    // Use the following imul opcode
                    // 0F AF /r: IMUL r32/64, r/m32/64
                    const abi_size = dst_ty.abiSize(self.target.*);
                    const encoder = try Encoder.init(self.code, 4);
                    encoder.rex(.{
                        .w = abi_size == 8,
                        .r = dst_reg.isExtended(),
                        .b = src_reg.isExtended(),
                    });
                    encoder.opcode_2byte(0x0f, 0xaf);
                    encoder.modRm_direct(
                        dst_reg.low_id(),
                        src_reg.low_id(),
                    );
                    // copy dst_reg back out
                    return self.genSetStack(dst_ty, off, MCValue{ .register = dst_reg });
                },
                .immediate => |imm| {
                    _ = imm;
                    return self.fail("TODO implement x86 multiply source immediate", .{});
                },
                .embedded_in_code, .memory, .stack_offset => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .compare_flags_unsigned => {
                    return self.fail("TODO implement x86 multiply source compare flag (unsigned)", .{});
                },
                .compare_flags_signed => {
                    return self.fail("TODO implement x86 multiply source compare flag (signed)", .{});
                },
            }
        },
        .embedded_in_code, .memory => {
            return self.fail("TODO implement x86 multiply destination memory", .{});
        },
    }
}

fn genX8664ModRMRegToStack(self: *Self, ty: Type, off: u32, reg: Register, opcode: u8) !void {
    const abi_size = ty.abiSize(self.target.*);
    const adj_off = off + abi_size;
    if (off > math.maxInt(i32)) {
        return self.fail("stack offset too large", .{});
    }

    const i_adj_off = -@intCast(i32, adj_off);
    const encoder = try Encoder.init(self.code, 7);
    encoder.rex(.{
        .w = abi_size == 8,
        .r = reg.isExtended(),
    });
    encoder.opcode_1byte(opcode);
    if (i_adj_off < std.math.maxInt(i8)) {
        // example: 48 89 55 7f           mov    QWORD PTR [rbp+0x7f],rdx
        encoder.modRm_indirectDisp8(
            reg.low_id(),
            Register.ebp.low_id(),
        );
        encoder.disp8(@intCast(i8, i_adj_off));
    } else {
        // example: 48 89 95 80 00 00 00  mov    QWORD PTR [rbp+0x80],rdx
        encoder.modRm_indirectDisp32(
            reg.low_id(),
            Register.ebp.low_id(),
        );
        encoder.disp32(i_adj_off);
    }
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
        .stack_offset => {
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

    const mcv = self.args[arg_index];
    try self.genArgDbgInfo(inst, mcv);

    if (self.liveness.isUnused(inst))
        return self.finishAirBookkeeping();

    switch (mcv) {
        .register => |reg| {
            self.register_manager.getRegAssumeFree(reg.to64(), inst);
        },
        else => {},
    }

    return self.finishAir(inst, mcv, .{ .none, .none, .none });
}

fn airBreakpoint(self: *Self) !void {
    try self.code.append(0xcc); // int3
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

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (self.bin_file.tag == link.File.Elf.base_tag or self.bin_file.tag == link.File.Coff.base_tag) {
        for (info.args) |mc_arg, arg_i| {
            const arg = args[arg_i];
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
                    // Here we need to emit instructions like this:
                    // mov     qword ptr [rsp + stack_offset], x
                    try self.genSetStack(arg_ty, off, arg_mcv);
                },
                .ptr_stack_offset => {
                    return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                },
                .ptr_embedded_in_code => {
                    return self.fail("TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                },
                .undef => unreachable,
                .immediate => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .embedded_in_code => unreachable,
                .memory => unreachable,
                .compare_flags_signed => unreachable,
                .compare_flags_unsigned => unreachable,
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
                    @intCast(u32, coff_file.offset_table_virtual_address + func.owner_decl.link.coff.offset_table_index * ptr_bytes)
                else
                    unreachable;

                // ff 14 25 xx xx xx xx    call [addr]
                try self.code.ensureUnusedCapacity(7);
                self.code.appendSliceAssumeCapacity(&[3]u8{ 0xff, 0x14, 0x25 });
                mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), got_addr);
            } else if (func_value.castTag(.extern_fn)) |_| {
                return self.fail("TODO implement calling extern functions", .{});
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else {
            return self.fail("TODO implement calling runtime known function pointer", .{});
        }
    } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
        for (info.args) |mc_arg, arg_i| {
            const arg = args[arg_i];
            const arg_ty = self.air.typeOf(arg);
            const arg_mcv = try self.resolveInst(args[arg_i]);
            // Here we do not use setRegOrMem even though the logic is similar, because
            // the function call will move the stack pointer, so the offsets are different.
            switch (mc_arg) {
                .none => continue,
                .register => |reg| {
                    // TODO prevent this macho if block to be generated for all archs
                    try self.register_manager.getReg(reg, null);
                    try self.genSetReg(arg_ty, reg, arg_mcv);
                },
                .stack_offset => {
                    // Here we need to emit instructions like this:
                    // mov     qword ptr [rsp + stack_offset], x
                    return self.fail("TODO implement calling with parameters in memory", .{});
                },
                .ptr_stack_offset => {
                    return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                },
                .ptr_embedded_in_code => {
                    return self.fail("TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                },
                .undef => unreachable,
                .immediate => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .embedded_in_code => unreachable,
                .memory => unreachable,
                .compare_flags_signed => unreachable,
                .compare_flags_unsigned => unreachable,
            }
        }

        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;
                // TODO I'm hacking my way through here by repurposing .memory for storing
                // index to the GOT target symbol index.
                try self.genSetReg(Type.initTag(.u64), .rax, .{
                    .memory = func.owner_decl.link.macho.local_sym_index,
                });
                // callq *%rax
                try self.code.ensureUnusedCapacity(2);
                self.code.appendSliceAssumeCapacity(&[2]u8{ 0xff, 0xd0 });
            } else if (func_value.castTag(.extern_fn)) |func_payload| {
                const decl = func_payload.data;
                const n_strx = try macho_file.addExternFn(mem.spanZ(decl.name));
                const offset = blk: {
                    // callq
                    try self.code.ensureUnusedCapacity(5);
                    self.code.appendSliceAssumeCapacity(&[5]u8{ 0xe8, 0x0, 0x0, 0x0, 0x0 });
                    break :blk @intCast(u32, self.code.items.len) - 4;
                };
                // Add relocation to the decl.
                try macho_file.active_decl.?.link.macho.relocs.append(self.bin_file.allocator, .{
                    .offset = offset,
                    .target = .{ .global = n_strx },
                    .addend = 0,
                    .subtractor = null,
                    .pcrel = true,
                    .length = 2,
                    .@"type" = @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_BRANCH),
                });
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else {
            return self.fail("TODO implement calling runtime known function pointer", .{});
        }
    } else if (self.bin_file.cast(link.File.Plan9)) |p9| {
        for (info.args) |mc_arg, arg_i| {
            const arg = args[arg_i];
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
                .stack_offset => {
                    // Here we need to emit instructions like this:
                    // mov     qword ptr [rsp + stack_offset], x
                    return self.fail("TODO implement calling with parameters in memory", .{});
                },
                .ptr_stack_offset => {
                    return self.fail("TODO implement calling with MCValue.ptr_stack_offset arg", .{});
                },
                .ptr_embedded_in_code => {
                    return self.fail("TODO implement calling with MCValue.ptr_embedded_in_code arg", .{});
                },
                .undef => unreachable,
                .immediate => unreachable,
                .unreach => unreachable,
                .dead => unreachable,
                .embedded_in_code => unreachable,
                .memory => unreachable,
                .compare_flags_signed => unreachable,
                .compare_flags_unsigned => unreachable,
            }
        }
        if (self.air.value(callee)) |func_value| {
            if (func_value.castTag(.function)) |func_payload| {
                try p9.seeDecl(func_payload.data.owner_decl);
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const got_addr = p9.bases.data;
                const got_index = func_payload.data.owner_decl.link.plan9.got_index.?;
                // ff 14 25 xx xx xx xx    call [addr]
                try self.code.ensureUnusedCapacity(7);
                self.code.appendSliceAssumeCapacity(&[3]u8{ 0xff, 0x14, 0x25 });
                const fn_got_addr = got_addr + got_index * ptr_bytes;
                mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), @intCast(u32, fn_got_addr));
            } else return self.fail("TODO implement calling extern fn on plan9", .{});
        } else {
            return self.fail("TODO implement calling runtime known function pointer", .{});
        }
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
    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    try self.code.resize(self.code.items.len + 5);
    self.code.items[self.code.items.len - 5] = 0xe9; // jmp rel32
    try self.exitlude_jump_relocs.append(self.gpa, self.code.items.len - 4);
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

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const result: MCValue = result: {
        try self.code.ensureUnusedCapacity(8);

        // There are 2 operands, destination and source.
        // Either one, but not both, can be a memory operand.
        // Source operand can be an immediate, 8 bits or 32 bits.
        const dst_mcv = if (lhs.isImmediate() or (lhs.isMemory() and rhs.isMemory()))
            try self.copyToNewRegister(inst, lhs)
        else
            lhs;
        // This instruction supports only signed 32-bit immediates at most.
        const src_mcv = try self.limitImmediateType(bin_op.rhs, i32);

        try self.genX8664BinMathCode(Type.initTag(.bool), dst_mcv, src_mcv, 7, 0x38);
        break :result switch (ty.isSignedInt()) {
            true => MCValue{ .compare_flags_signed = op },
            false => MCValue{ .compare_flags_unsigned = op },
        };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
    try self.dbgAdvancePCAndLine(dbg_stmt.line, dbg_stmt.column);
    return self.finishAirBookkeeping();
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc: Reloc = reloc: {
        try self.code.ensureUnusedCapacity(6);

        const opcode: u8 = switch (cond) {
            .compare_flags_signed => |cmp_op| blk: {
                // Here we map to the opposite opcode because the jump is to the false branch.
                const opcode: u8 = switch (cmp_op) {
                    .gte => 0x8c,
                    .gt => 0x8e,
                    .neq => 0x84,
                    .lt => 0x8d,
                    .lte => 0x8f,
                    .eq => 0x85,
                };
                break :blk opcode;
            },
            .compare_flags_unsigned => |cmp_op| blk: {
                // Here we map to the opposite opcode because the jump is to the false branch.
                const opcode: u8 = switch (cmp_op) {
                    .gte => 0x82,
                    .gt => 0x86,
                    .neq => 0x84,
                    .lt => 0x83,
                    .lte => 0x87,
                    .eq => 0x85,
                };
                break :blk opcode;
            },
            .register => |reg| blk: {
                // test reg, 1
                // TODO detect al, ax, eax
                const encoder = try Encoder.init(self.code, 4);
                encoder.rex(.{
                    // TODO audit this codegen: we force w = true here to make
                    // the value affect the big register
                    .w = true,
                    .b = reg.isExtended(),
                });
                encoder.opcode_1byte(0xf6);
                encoder.modRm_direct(
                    0,
                    reg.low_id(),
                );
                encoder.disp8(1);
                break :blk 0x84;
            },
            else => return self.fail("TODO implement condbr {s} when condition is {s}", .{ self.target.cpu.arch, @tagName(cond) }),
        };
        self.code.appendSliceAssumeCapacity(&[_]u8{ 0x0f, opcode });
        const reloc = Reloc{ .rel32 = self.code.items.len };
        self.code.items.len += 4;
        break :reloc reloc;
    };

    // Capture the state of register and stack allocation state so that we can revert to it.
    const parent_next_stack_offset = self.next_stack_offset;
    const parent_free_registers = self.register_manager.free_registers;
    var parent_stack = try self.stack.clone(self.gpa);
    defer parent_stack.deinit(self.gpa);
    const parent_registers = self.register_manager.registers;

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

    return self.finishAir(inst, .unreach, .{ pl_op.operand, .none, .none });
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
    try self.code.ensureUnusedCapacity(5);
    if (math.cast(i8, @intCast(i32, index) - (@intCast(i32, self.code.items.len + 2)))) |delta| {
        self.code.appendAssumeCapacity(0xeb); // jmp rel8
        self.code.appendAssumeCapacity(@bitCast(u8, delta));
    } else |_| {
        const delta = @intCast(i32, index) - (@intCast(i32, self.code.items.len + 5));
        self.code.appendAssumeCapacity(0xe9); // jmp rel32
        mem.writeIntLittle(i32, self.code.addManyAsArrayAssumeCapacity(4), delta);
    }
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

fn performReloc(self: *Self, reloc: Reloc) !void {
    switch (reloc) {
        .rel32 => |pos| {
            const amt = self.code.items.len - (pos + 4);
            // Here it would be tempting to implement testing for amt == 0 and then elide the
            // jump. However, that will cause a problem because other jumps may assume that they
            // can jump to this code. Or maybe I didn't understand something when I was debugging.
            // It could be worth another look. Anyway, that's why that isn't done here. Probably the
            // best place to elide jumps will be in semantic analysis, by inlining blocks that only
            // only have 1 break instruction.
            const s32_amt = math.cast(i32, amt) catch
                return self.fail("unable to perform relocation: jump too far", .{});
            mem.writeIntLittle(i32, self.code.items[pos..][0..4], s32_amt);
        },
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else switch (air_tags[inst]) {
        // lhs AND rhs
        .bool_and => try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs),
        // lhs OR rhs
        .bool_or => try self.genX8664BinMath(inst, bin_op.lhs, bin_op.rhs),
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
    try block_data.relocs.ensureUnusedCapacity(self.gpa, 1);
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    try self.code.resize(self.code.items.len + 5);
    self.code.items[self.code.items.len - 5] = 0xe9; // jmp rel32
    // Leave the jump offset undefined
    block_data.relocs.appendAssumeCapacity(.{ .rel32 = self.code.items.len - 4 });
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
    const result: MCValue = if (dead)
        .dead
    else result: {
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

        {
            var iter = std.mem.tokenize(u8, asm_source, "\n\r");
            while (iter.next()) |ins| {
                if (mem.eql(u8, ins, "syscall")) {
                    try self.code.appendSlice(&[_]u8{ 0x0f, 0x05 });
                } else if (mem.indexOf(u8, ins, "push")) |_| {
                    const arg = ins[4..];
                    if (mem.indexOf(u8, arg, "$")) |l| {
                        const n = std.fmt.parseInt(u8, ins[4 + l + 1 ..], 10) catch return self.fail("TODO implement more inline asm int parsing", .{});
                        try self.code.appendSlice(&.{ 0x6a, n });
                    } else if (mem.indexOf(u8, arg, "%%")) |l| {
                        const reg_name = ins[4 + l + 2 ..];
                        const reg = parseRegName(reg_name) orelse
                            return self.fail("unrecognized register: '{s}'", .{reg_name});
                        const low_id: u8 = reg.low_id();
                        if (reg.isExtended()) {
                            try self.code.appendSlice(&.{ 0x41, 0b1010000 | low_id });
                        } else {
                            try self.code.append(0b1010000 | low_id);
                        }
                    } else return self.fail("TODO more push operands", .{});
                } else if (mem.indexOf(u8, ins, "pop")) |_| {
                    const arg = ins[3..];
                    if (mem.indexOf(u8, arg, "%%")) |l| {
                        const reg_name = ins[3 + l + 2 ..];
                        const reg = parseRegName(reg_name) orelse
                            return self.fail("unrecognized register: '{s}'", .{reg_name});
                        const low_id: u8 = reg.low_id();
                        if (reg.isExtended()) {
                            try self.code.appendSlice(&.{ 0x41, 0b1011000 | low_id });
                        } else {
                            try self.code.append(0b1011000 | low_id);
                        }
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
        .compare_flags_unsigned => |op| {
            _ = op;
            return self.fail("TODO implement set stack variable with compare flags value (unsigned)", .{});
        },
        .compare_flags_signed => |op| {
            _ = op;
            return self.fail("TODO implement set stack variable with compare flags value (signed)", .{});
        },
        .immediate => |x_big| {
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = stack_offset + abi_size;
            if (adj_off > 128) {
                return self.fail("TODO implement set stack variable with large stack offset", .{});
            }
            try self.code.ensureUnusedCapacity(8);
            switch (abi_size) {
                1 => {
                    return self.fail("TODO implement set abi_size=1 stack variable with immediate", .{});
                },
                2 => {
                    return self.fail("TODO implement set abi_size=2 stack variable with immediate", .{});
                },
                4 => {
                    const x = @intCast(u32, x_big);
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                    const twos_comp = @bitCast(u8, negative_offset);
                    // mov    DWORD PTR [rbp+offset], immediate
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp });
                    mem.writeIntLittle(u32, self.code.addManyAsArrayAssumeCapacity(4), x);
                },
                8 => {
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    const negative_offset = @intCast(i8, -@intCast(i32, adj_off));
                    const twos_comp = @bitCast(u8, negative_offset);

                    // 64 bit write to memory would take two mov's anyways so we
                    // insted just use two 32 bit writes to avoid register allocation
                    try self.code.ensureUnusedCapacity(14);
                    var buf: [8]u8 = undefined;
                    mem.writeIntLittle(u64, &buf, x_big);

                    // mov    DWORD PTR [rbp+offset+4], immediate
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp + 4 });
                    self.code.appendSliceAssumeCapacity(buf[4..8]);

                    // mov    DWORD PTR [rbp+offset], immediate
                    self.code.appendSliceAssumeCapacity(&[_]u8{ 0xc7, 0x45, twos_comp });
                    self.code.appendSliceAssumeCapacity(buf[0..4]);
                },
                else => {
                    return self.fail("TODO implement set abi_size=large stack variable with immediate", .{});
                },
            }
        },
        .embedded_in_code => {
            // TODO this and `.stack_offset` below need to get improved to support types greater than
            // register size, and do general memcpy
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .register => |reg| {
            try self.genX8664ModRMRegToStack(ty, stack_offset, reg, 0x89);
        },
        .memory => |vaddr| {
            _ = vaddr;
            return self.fail("TODO implement set stack variable from memory vaddr", .{});
        },
        .stack_offset => |off| {
            // TODO this and `.embedded_in_code` above need to get improved to support types greater than
            // register size, and do general memcpy

            if (stack_offset == off)
                return; // Copy stack variable to itself; nothing to do.

            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
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
            switch (reg.size()) {
                8 => return self.genSetReg(ty, reg, .{ .immediate = 0xaa }),
                16 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaa }),
                32 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaa }),
                64 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => unreachable,
            }
        },
        .compare_flags_unsigned => |op| {
            const encoder = try Encoder.init(self.code, 7);
            // TODO audit this codegen: we force w = true here to make
            // the value affect the big register
            encoder.rex(.{
                .w = true,
                .b = reg.isExtended(),
            });
            encoder.opcode_2byte(0x0f, switch (op) {
                .gte => 0x93,
                .gt => 0x97,
                .neq => 0x95,
                .lt => 0x92,
                .lte => 0x96,
                .eq => 0x94,
            });
            encoder.modRm_direct(
                0,
                reg.low_id(),
            );
        },
        .compare_flags_signed => |op| {
            _ = op;
            return self.fail("TODO set register with compare flags value (signed)", .{});
        },
        .immediate => |x| {
            // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
            // register is the fastest way to zero a register.
            if (x == 0) {
                // The encoding for `xor r32, r32` is `0x31 /r`.
                const encoder = try Encoder.init(self.code, 3);

                // If we're accessing e.g. r8d, we need to use a REX prefix before the actual operation. Since
                // this is a 32-bit operation, the W flag is set to zero. X is also zero, as we're not using a SIB.
                // Both R and B are set, as we're extending, in effect, the register bits *and* the operand.
                encoder.rex(.{
                    .r = reg.isExtended(),
                    .b = reg.isExtended(),
                });
                encoder.opcode_1byte(0x31);
                // Section 3.1.1.1 of the Intel x64 Manual states that "/r indicates that the
                // ModR/M byte of the instruction contains a register operand and an r/m operand."
                encoder.modRm_direct(
                    reg.low_id(),
                    reg.low_id(),
                );

                return;
            }
            if (x <= math.maxInt(i32)) {
                // Next best case: if we set the lower four bytes, the upper four will be zeroed.
                //
                // The encoding for `mov IMM32 -> REG` is (0xB8 + R) IMM.

                const encoder = try Encoder.init(self.code, 6);
                // Just as with XORing, we need a REX prefix. This time though, we only
                // need the B bit set, as we're extending the opcode's register field,
                // and there is no Mod R/M byte.
                encoder.rex(.{
                    .b = reg.isExtended(),
                });
                encoder.opcode_withReg(0xB8, reg.low_id());

                // no ModR/M byte

                // IMM
                encoder.imm32(@intCast(i32, x));
                return;
            }
            // Worst case: we need to load the 64-bit register with the IMM. GNU's assemblers calls
            // this `movabs`, though this is officially just a different variant of the plain `mov`
            // instruction.
            //
            // This encoding is, in fact, the *same* as the one used for 32-bit loads. The only
            // difference is that we set REX.W before the instruction, which extends the load to
            // 64-bit and uses the full bit-width of the register.
            {
                const encoder = try Encoder.init(self.code, 10);
                encoder.rex(.{
                    .w = true,
                    .b = reg.isExtended(),
                });
                encoder.opcode_withReg(0xB8, reg.low_id());
                encoder.imm64(x);
            }
        },
        .embedded_in_code => |code_offset| {
            // We need the offset from RIP in a signed i32 twos complement.
            // The instruction is 7 bytes long and RIP points to the next instruction.

            // 64-bit LEA is encoded as REX.W 8D /r.
            const rip = self.code.items.len + 7;
            const big_offset = @intCast(i64, code_offset) - @intCast(i64, rip);
            const offset = @intCast(i32, big_offset);
            const encoder = try Encoder.init(self.code, 7);

            // byte 1, always exists because w = true
            encoder.rex(.{
                .w = true,
                .r = reg.isExtended(),
            });
            // byte 2
            encoder.opcode_1byte(0x8D);
            // byte 3
            encoder.modRm_RIPDisp32(reg.low_id());
            // byte 4-7
            encoder.disp32(offset);

            // Double check that we haven't done any math errors
            assert(rip == self.code.items.len);
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // This is a variant of 8B /r.
            const abi_size = ty.abiSize(self.target.*);
            const encoder = try Encoder.init(self.code, 3);
            encoder.rex(.{
                .w = abi_size == 8,
                .r = reg.isExtended(),
                .b = src_reg.isExtended(),
            });
            encoder.opcode_1byte(0x8B);
            encoder.modRm_direct(reg.low_id(), src_reg.low_id());
        },
        .memory => |x| {
            if (self.bin_file.options.pie) {
                // RIP-relative displacement to the entry in the GOT table.
                const abi_size = ty.abiSize(self.target.*);
                const encoder = try Encoder.init(self.code, 10);

                // LEA reg, [<offset>]

                // We encode the instruction FIRST because prefixes may or may not appear.
                // After we encode the instruction, we will know that the displacement bytes
                // for [<offset>] will be at self.code.items.len - 4.
                encoder.rex(.{
                    .w = true, // force 64 bit because loading an address (to the GOT)
                    .r = reg.isExtended(),
                });
                encoder.opcode_1byte(0x8D);
                encoder.modRm_RIPDisp32(reg.low_id());
                encoder.disp32(0);

                const offset = @intCast(u32, self.code.items.len);

                if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                    // TODO I think the reloc might be in the wrong place.
                    const decl = macho_file.active_decl.?;
                    // Load reloc for LEA instruction.
                    try decl.link.macho.relocs.append(self.bin_file.allocator, .{
                        .offset = offset - 4,
                        .target = .{ .local = @intCast(u32, x) },
                        .addend = 0,
                        .subtractor = null,
                        .pcrel = true,
                        .length = 2,
                        .@"type" = @enumToInt(std.macho.reloc_type_x86_64.X86_64_RELOC_GOT),
                    });
                } else {
                    return self.fail("TODO implement genSetReg for PIE GOT indirection on this platform", .{});
                }

                // MOV reg, [reg]
                encoder.rex(.{
                    .w = abi_size == 8,
                    .r = reg.isExtended(),
                    .b = reg.isExtended(),
                });
                encoder.opcode_1byte(0x8B);
                encoder.modRm_indirectDisp0(reg.low_id(), reg.low_id());
            } else if (x <= math.maxInt(i32)) {
                // Moving from memory to a register is a variant of `8B /r`.
                // Since we're using 64-bit moves, we require a REX.
                // This variant also requires a SIB, as it would otherwise be RIP-relative.
                // We want mode zero with the lower three bits set to four to indicate an SIB with no other displacement.
                // The SIB must be 0x25, to indicate a disp32 with no scaled index.
                // 0b00RRR100, where RRR is the lower three bits of the register ID.
                // The instruction is thus eight bytes; REX 0x8B 0b00RRR100 0x25 followed by a four-byte disp32.
                const abi_size = ty.abiSize(self.target.*);
                const encoder = try Encoder.init(self.code, 8);
                encoder.rex(.{
                    .w = abi_size == 8,
                    .r = reg.isExtended(),
                });
                encoder.opcode_1byte(0x8B);
                // effective address = [SIB]
                encoder.modRm_SIBDisp0(reg.low_id());
                // SIB = disp32
                encoder.sib_disp32();
                encoder.disp32(@intCast(i32, x));
            } else {
                // If this is RAX, we can use a direct load; otherwise, we need to load the address, then indirectly load
                // the value.
                if (reg.id() == 0) {
                    // REX.W 0xA1 moffs64*
                    // moffs64* is a 64-bit offset "relative to segment base", which really just means the
                    // absolute address for all practical purposes.

                    const encoder = try Encoder.init(self.code, 10);
                    encoder.rex(.{
                        .w = true,
                    });
                    encoder.opcode_1byte(0xA1);
                    encoder.writeIntLittle(u64, x);
                } else {
                    // This requires two instructions; a move imm as used above, followed by an indirect load using the register
                    // as the address and the register as the destination.
                    //
                    // This cannot be used if the lower three bits of the id are equal to four or five, as there
                    // is no way to possibly encode it. This means that RSP, RBP, R12, and R13 cannot be used with
                    // this instruction.
                    const id3 = @truncate(u3, reg.id());
                    assert(id3 != 4 and id3 != 5);

                    // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                    try self.genSetReg(ty, reg, MCValue{ .immediate = x });

                    // Now, the register contains the address of the value to load into it
                    // Currently, we're only allowing 64-bit registers, so we need the `REX.W 8B /r` variant.
                    // TODO: determine whether to allow other sized registers, and if so, handle them properly.

                    // mov reg, [reg]
                    const abi_size = ty.abiSize(self.target.*);
                    const encoder = try Encoder.init(self.code, 3);
                    encoder.rex(.{
                        .w = abi_size == 8,
                        .r = reg.isExtended(),
                        .b = reg.isExtended(),
                    });
                    encoder.opcode_1byte(0x8B);
                    encoder.modRm_indirectDisp0(reg.low_id(), reg.low_id());
                }
            }
        },
        .stack_offset => |unadjusted_off| {
            const abi_size = ty.abiSize(self.target.*);
            const off = unadjusted_off + abi_size;
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            const ioff = -@intCast(i32, off);
            const encoder = try Encoder.init(self.code, 3);
            encoder.rex(.{
                .w = abi_size == 8,
                .r = reg.isExtended(),
            });
            encoder.opcode_1byte(0x8B);
            if (std.math.minInt(i8) <= ioff and ioff <= std.math.maxInt(i8)) {
                // Example: 48 8b 4d 7f           mov    rcx,QWORD PTR [rbp+0x7f]
                encoder.modRm_indirectDisp8(reg.low_id(), Register.ebp.low_id());
                encoder.disp8(@intCast(i8, ioff));
            } else {
                // Example: 48 8b 8d 80 00 00 00  mov    rcx,QWORD PTR [rbp+0x80]
                encoder.modRm_indirectDisp32(reg.low_id(), Register.ebp.low_id());
                encoder.disp32(ioff);
            }
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airArrayToSlice for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst))
        .dead
    else
        return self.fail("TODO implement airFloatToInt for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
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
            var next_int_reg: usize = 0;
            var next_stack_offset: u32 = 0;

            for (param_types) |ty, i| {
                if (!ty.hasCodeGenBits()) {
                    assert(cc != .C);
                    result.args[i] = .{ .none = {} };
                    continue;
                }
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                const pass_in_reg = switch (ty.zigTypeTag()) {
                    .Bool => true,
                    .Int => param_size <= 8,
                    .Pointer => ty.ptrSize() != .Slice,
                    .Optional => ty.isPtrLikeOptional(),
                    else => false,
                };
                if (pass_in_reg) {
                    if (next_int_reg >= c_abi_int_param_regs.len) {
                        result.args[i] = .{ .stack_offset = next_stack_offset };
                        next_stack_offset += param_size;
                    } else {
                        const aliased_reg = registerAlias(
                            c_abi_int_param_regs[next_int_reg],
                            param_size,
                        );
                        result.args[i] = .{ .register = aliased_reg };
                        next_int_reg += 1;
                    }
                } else {
                    // For simplicity of codegen, slices and other types are always pushed onto the stack.
                    // TODO: look into optimizing this by passing things as registers sometimes,
                    // such as ptr and len of slices as separate registers.
                    // TODO: also we need to honor the C ABI for relevant types rather than passing on
                    // the stack here.
                    result.args[i] = .{ .stack_offset = next_stack_offset };
                    next_stack_offset += param_size;
                }
            }
            result.stack_byte_count = next_stack_offset;
            result.stack_align = 16;
        },
        else => return self.fail("TODO implement function parameters for {} on x86_64", .{cc}),
    }

    if (ret_ty.zigTypeTag() == .NoReturn) {
        result.return_value = .{ .unreach = {} };
    } else if (!ret_ty.hasCodeGenBits()) {
        result.return_value = .{ .none = {} };
    } else switch (cc) {
        .Naked => unreachable,
        .Unspecified, .C => {
            const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
            const aliased_reg = registerAlias(c_abi_int_return_regs[0], ret_ty_size);
            result.return_value = .{ .register = aliased_reg };
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

const Instruction = void;

const Condition = void;

const callee_preserved_regs = @import("bits.zig").callee_preserved_regs;

const c_abi_int_param_regs = @import("bits.zig").c_abi_int_param_regs;

const c_abi_int_return_regs = @import("bits.zig").c_abi_int_return_regs;

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

fn registerAlias(reg: Register, size_bytes: u32) Register {
    // For x86_64 we have to pick a smaller register alias depending on abi size.
    switch (size_bytes) {
        1 => return reg.to8(),
        2 => return reg.to16(),
        4 => return reg.to32(),
        8 => return reg.to64(),
        else => unreachable,
    }
}
