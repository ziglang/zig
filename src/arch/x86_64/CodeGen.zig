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
        .function = &function,
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
        w.print("# Begin Function MIR: {s}:\n", .{module_fn.owner_decl.name}) catch {};
        const PrintMir = @import("PrintMir.zig");
        const print = PrintMir{
            .mir = mir,
            .bin_file = bin_file,
        };
        print.printMir(w, function.mir_to_air_map, air) catch {}; // we don't care if the debug printing fails
        w.print("# End Function MIR: {s}\n\n", .{module_fn.owner_decl.name}) catch {};
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
            inline for (callee_preserved_regs) |reg, i| {
                if (self.register_manager.isRegAllocated(reg)) {
                    data.regs |= 1 << @intCast(u5, i);
                    self.max_end_stack += 8;
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
        const stack_end = self.max_end_stack;
        if (stack_end > math.maxInt(i32)) {
            return self.failSymbol("too much stack used in call parameters", .{});
        }
        // TODO we should reuse this mechanism to align the stack when calling any function even if
        // we do not pass any args on the stack BUT we still push regs to stack with `push` inst.
        const aligned_stack_end = @intCast(u32, mem.alignForward(stack_end, self.stack_align));
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
            .ret_addr        => try self.airRetAddr(),
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
            .tag_name        => try self.airTagName(inst),
            .error_name      => try self.airErrorName(inst),
            .splat           => try self.airSplat(inst),
            .vector_init     => try self.airVectorInit(inst),
            .prefetch        => try self.airPrefetch(inst),

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

/// Like `copyToNewRegister` but allows to specify a list of excluded registers which
/// will not be selected for allocation. This can be done via `exceptions` slice.
fn copyToNewRegisterWithExceptions(
    self: *Self,
    reg_owner: Air.Inst.Index,
    mcv: MCValue,
    exceptions: []const Register,
) !MCValue {
    const reg = try self.register_manager.allocReg(reg_owner, exceptions);
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
        const reg = switch (operand) {
            .register => |src_reg| try self.register_manager.allocReg(inst, &.{src_reg}),
            else => try self.register_manager.allocReg(inst, &.{}),
        };
        try self.genSetReg(dest_ty, reg, .{ .immediate = 0 });
        try self.genSetReg(dest_ty, reg, operand);
        break :blk .{ .register = registerAlias(reg, @intCast(u32, dest_abi_size)) };
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
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
        break :result try self.genBinMathOp(inst, ty_op.operand, .bool_true);
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
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
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
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
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
        try self.genBinMathOp(inst, bin_op.lhs, bin_op.rhs);
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, operand)) {
            break :result operand;
        }
        break :result try self.copyToNewRegister(inst, operand);
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const err_union_ty = self.air.typeOf(ty_op.operand);
        const payload_ty = err_union_ty.errorUnionPayload();
        const mcv = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasCodeGenBits()) break :result mcv;
        return self.fail("TODO implement unwrap error union error for non-empty payloads", .{});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const err_union_ty = self.air.typeOf(ty_op.operand);
        const payload_ty = err_union_ty.errorUnionPayload();
        if (!payload_ty.hasCodeGenBits()) break :result MCValue.none;
        return self.fail("TODO implement unwrap error union payload for non-empty payloads", .{});
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const error_union_ty = self.air.getRefType(ty_op.ty);
        const payload_ty = error_union_ty.errorUnionPayload();
        const mcv = try self.resolveInst(ty_op.operand);
        if (!payload_ty.hasCodeGenBits()) break :result mcv;

        return self.fail("TODO implement wrap errunion error for non-empty payloads", .{});
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
                    break :blk MCValue{ .stack_offset = off + 8 };
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
                    break :blk MCValue{ .stack_offset = off };
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
    const reg = try self.register_manager.allocReg(null, &.{});
    try self.genSetReg(index_ty, reg, index);
    try self.genIMulOpMir(index_ty, .{ .register = reg }, .{ .immediate = elem_size });
    return reg;
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .dead else result: {
        const slice_mcv = try self.resolveInst(bin_op.lhs);
        const slice_ty = self.air.typeOf(bin_op.lhs);
        const elem_ty = slice_ty.childType();
        const elem_size = elem_ty.abiSize(self.target.*);
        var buf: Type.SlicePtrFieldTypeBuffer = undefined;
        const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);
        const index_ty = self.air.typeOf(bin_op.rhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);
        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_size);
        const addr_reg = try self.register_manager.allocReg(null, &.{offset_reg});
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
                    .data = .{ .imm = @bitCast(u32, -@intCast(i32, off + 16)) },
                });
            },
            else => return self.fail("TODO implement slice_elem_val when slice is {}", .{slice_mcv}),
        }
        // TODO we could allocate register here, but need to except addr register and potentially
        // offset register.
        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genBinMathOpMir(.add, slice_ptr_field_type, .unsigned, .{ .register = addr_reg.to64() }, .{
            .register = offset_reg.to64(),
        });
        try self.load(dst_mcv, .{ .register = addr_reg.to64() }, slice_ptr_field_type);
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
        return self.fail("TODO implement slice_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const array_ty = self.air.typeOf(bin_op.lhs);
        const array = try self.resolveInst(bin_op.lhs);
        const array_abi_size = array_ty.abiSize(self.target.*);
        const elem_ty = array_ty.childType();
        const elem_abi_size = elem_ty.abiSize(self.target.*);
        const index_ty = self.air.typeOf(bin_op.rhs);
        const index = try self.resolveInst(bin_op.rhs);
        const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
        const addr_reg = try self.register_manager.allocReg(null, &.{offset_reg});
        switch (array) {
            .stack_offset => |off| {
                // lea reg, [rbp]
                _ = try self.addInst(.{
                    .tag = .lea,
                    .ops = (Mir.Ops{
                        .reg1 = addr_reg.to64(),
                        .reg2 = .rbp,
                    }).encode(),
                    .data = .{ .imm = @bitCast(u32, -@intCast(i32, off + array_abi_size)) },
                });
            },
            else => return self.fail("TODO implement array_elem_val when array is {}", .{array}),
        }
        // TODO we could allocate register here, but need to except addr register and potentially
        // offset register.
        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genBinMathOpMir(
            .add,
            array_ty,
            .unsigned,
            .{ .register = addr_reg.to64() },
            .{ .register = offset_reg.to64() },
        );
        try self.load(dst_mcv, .{ .register = addr_reg.to64() }, array_ty);
        break :result dst_mcv;
    };
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ptr_ty = self.air.typeOf(extra.lhs);
        const ptr = try self.resolveInst(extra.lhs);
        const elem_ty = ptr_ty.elemType2();
        const elem_abi_size = elem_ty.abiSize(self.target.*);
        const index_ty = self.air.typeOf(extra.rhs);
        const index = try self.resolveInst(extra.rhs);
        const offset_reg = try self.elemOffset(index_ty, index, elem_abi_size);
        const dst_mcv = blk: {
            switch (ptr) {
                .ptr_stack_offset => {
                    const reg = try self.register_manager.allocReg(inst, &.{offset_reg});
                    try self.genSetReg(ptr_ty, reg, ptr);
                    break :blk .{ .register = reg };
                },
                else => return self.fail("TODO implement ptr_elem_ptr when ptr is {}", .{ptr}),
            }
        };
        try self.genBinMathOpMir(.add, ptr_ty, .unsigned, dst_mcv, .{ .register = offset_reg });
        break :result dst_mcv;
    };
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
    const abi_size = elem_ty.abiSize(self.target.*);
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .memory = imm });
        },
        .ptr_stack_offset => |off| {
            try self.setRegOrMem(elem_ty, dst_mcv, .{ .stack_offset = off });
        },
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
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .embedded_in_code => unreachable,
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
                        const tmp_reg = try self.register_manager.allocReg(null, &.{reg});
                        try self.load(.{ .register = tmp_reg }, ptr, ptr_ty);
                        return self.genSetStack(elem_ty, off, MCValue{ .register = tmp_reg });
                    }

                    const regs = try self.register_manager.allocRegs(
                        3,
                        .{ null, null, null },
                        &.{ reg, .rax, .rcx },
                    );
                    const addr_reg = regs[0];
                    const count_reg = regs[1];
                    const tmp_reg = regs[2];

                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(addr_reg, @divExact(reg.size(), 8)),
                            .reg2 = reg,
                        }).encode(),
                        .data = undefined,
                    });

                    try self.register_manager.getReg(.rax, null);
                    try self.register_manager.getReg(.rcx, null);

                    // TODO allow for abi size to be u64
                    try self.genSetReg(Type.initTag(.u32), count_reg, .{ .immediate = @intCast(u32, abi_size) });

                    return self.genInlineMemcpy(
                        @bitCast(u32, -@intCast(i32, off + abi_size)),
                        .rbp,
                        registerAlias(addr_reg, @divExact(reg.size(), 8)),
                        count_reg.to64(),
                        tmp_reg.to8(),
                    );
                },
                else => return self.fail("TODO implement loading from register into {}", .{dst_mcv}),
            }
        },
        .memory => |addr| {
            const reg = try self.copyToTmpRegister(ptr_ty, .{ .memory = addr });
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

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    _ = ptr_ty;
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .compare_flags_unsigned => unreachable,
        .compare_flags_signed => unreachable,
        .immediate => |imm| {
            try self.setRegOrMem(value_ty, .{ .memory = imm }, value);
        },
        .ptr_stack_offset => |off| {
            try self.genSetStack(value_ty, off, value);
        },
        .ptr_embedded_in_code => |off| {
            try self.setRegOrMem(value_ty, .{ .embedded_in_code = off }, value);
        },
        .embedded_in_code => {
            return self.fail("TODO implement storing to MCValue.embedded_in_code", .{});
        },
        .register => |reg| {
            switch (value) {
                .none => unreachable,
                .undef => unreachable,
                .dead => unreachable,
                .unreach => unreachable,
                .compare_flags_unsigned => unreachable,
                .compare_flags_signed => unreachable,
                .immediate => |imm| {
                    const abi_size = value_ty.abiSize(self.target.*);
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
                        else => {
                            return self.fail("TODO implement set pointee with immediate of ABI size {d}", .{abi_size});
                        },
                    }
                },
                .register => |src_reg| {
                    const abi_size = value_ty.abiSize(self.target.*);
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
                else => |other| {
                    return self.fail("TODO implement set pointee with {}", .{other});
                },
            }
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
    return if (self.liveness.isUnused(inst)) .dead else result: {
        const mcv = try self.resolveInst(operand);
        const struct_ty = self.air.typeOf(operand).childType();
        const struct_size = @intCast(u32, struct_ty.abiSize(self.target.*));
        const struct_field_offset = @intCast(u32, struct_ty.structFieldOffset(index, self.target.*));
        const struct_field_ty = struct_ty.structFieldType(index);
        const struct_field_size = @intCast(u32, struct_field_ty.abiSize(self.target.*));

        switch (mcv) {
            .ptr_stack_offset => |off| {
                const ptr_stack_offset = off + struct_size - struct_field_offset - struct_field_size;
                break :result MCValue{ .ptr_stack_offset = ptr_stack_offset };
            },
            else => return self.fail("TODO implement codegen struct_field_ptr for {}", .{mcv}),
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
        const struct_size = @intCast(u32, struct_ty.abiSize(self.target.*));
        const struct_field_offset = @intCast(u32, struct_ty.structFieldOffset(index, self.target.*));
        const struct_field_ty = struct_ty.structFieldType(index);
        const struct_field_size = @intCast(u32, struct_field_ty.abiSize(self.target.*));

        switch (mcv) {
            .stack_offset => |off| {
                const stack_offset = off + struct_size - struct_field_offset - struct_field_size;
                break :result MCValue{ .stack_offset = stack_offset };
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{mcv}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

/// Perform "binary" operators, excluding comparisons.
/// Currently, the following ops are supported:
/// ADD, SUB, XOR, OR, AND
fn genBinMathOp(self: *Self, inst: Air.Inst.Index, op_lhs: Air.Inst.Ref, op_rhs: Air.Inst.Ref) !MCValue {
    // We'll handle these ops in two steps.
    // 1) Prepare an output location (register or memory)
    //    This location will be the location of the operand that dies (if one exists)
    //    or just a temporary register (if one doesn't exist)
    // 2) Perform the op with the other argument
    // 3) Sometimes, the output location is memory but the op doesn't support it.
    //    In this case, copy that location to a register, then perform the op to that register instead.
    //
    // TODO: make this algorithm less bad
    const lhs = try self.resolveInst(op_lhs);
    const rhs = try self.resolveInst(op_rhs);

    // There are 2 operands, destination and source.
    // Either one, but not both, can be a memory operand.
    // Source operand can be an immediate, 8 bits or 32 bits.
    // So, if either one of the operands dies with this instruction, we can use it
    // as the result MCValue.
    var dst_mcv: MCValue = undefined;
    var src_mcv: MCValue = undefined;
    if (self.reuseOperand(inst, op_lhs, 0, lhs)) {
        // LHS dies; use it as the destination.
        // Both operands cannot be memory.
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
        if (lhs.isMemory() and rhs.isMemory()) {
            dst_mcv = try self.copyToNewRegister(inst, rhs);
            src_mcv = lhs;
        } else {
            dst_mcv = rhs;
            src_mcv = lhs;
        }
    } else {
        if (lhs.isMemory()) {
            dst_mcv = if (rhs.isRegister())
                // If the allocated register is the same as the rhs register, don't allocate that one
                // and instead spill a subsequent one. Otherwise, this can result in a miscompilation
                // in the presence of several binary operations performed in a single block.
                try self.copyToNewRegisterWithExceptions(inst, lhs, &.{rhs.register})
            else
                try self.copyToNewRegister(inst, lhs);
            src_mcv = rhs;
        } else {
            dst_mcv = if (lhs.isRegister())
                // If the allocated register is the same as the rhs register, don't allocate that one
                // and instead spill a subsequent one. Otherwise, this can result in a miscompilation
                // in the presence of several binary operations performed in a single block.
                try self.copyToNewRegisterWithExceptions(inst, rhs, &.{lhs.register})
            else
                try self.copyToNewRegister(inst, rhs);
            src_mcv = lhs;
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

    // Now for step 2, we assing an MIR instruction
    const dst_ty = self.air.typeOfIndex(inst);
    const air_tags = self.air.instructions.items(.tag);
    switch (air_tags[inst]) {
        .add, .addwrap, .ptr_add => try self.genBinMathOpMir(.add, dst_ty, .unsigned, dst_mcv, src_mcv),
        .bool_or, .bit_or => try self.genBinMathOpMir(.@"or", dst_ty, .unsigned, dst_mcv, src_mcv),
        .bool_and, .bit_and => try self.genBinMathOpMir(.@"and", dst_ty, .unsigned, dst_mcv, src_mcv),
        .sub, .subwrap => try self.genBinMathOpMir(.sub, dst_ty, .unsigned, dst_mcv, src_mcv),
        .xor, .not => try self.genBinMathOpMir(.xor, dst_ty, .unsigned, dst_mcv, src_mcv),
        .mul, .mulwrap => try self.genIMulOpMir(dst_ty, dst_mcv, src_mcv),
        else => unreachable,
    }

    return dst_mcv;
}

fn genBinMathOpMir(
    self: *Self,
    mir_tag: Mir.Inst.Tag,
    dst_ty: Type,
    signedness: std.builtin.Signedness,
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
                    // TODO think more carefully about this: is this actually correct?
                    const reg_size = if (mir_tag == .cmp and signedness == .signed)
                        @divExact(dst_reg.size(), 8)
                    else
                        @divExact(src_reg.size(), 8);
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, reg_size),
                            .reg2 = registerAlias(src_reg, reg_size),
                        }).encode(),
                        .data = undefined,
                    });
                },
                .immediate => |imm| {
                    const abi_size = dst_ty.abiSize(self.target.*);
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @intCast(u32, abi_size)),
                        }).encode(),
                        .data = .{ .imm = @truncate(u32, imm) },
                    });
                },
                .embedded_in_code, .memory => {
                    return self.fail("TODO implement x86 ADD/SUB/CMP source memory", .{});
                },
                .stack_offset => |off| {
                    if (off > math.maxInt(i32)) {
                        return self.fail("stack offset too large", .{});
                    }
                    const abi_size = dst_ty.abiSize(self.target.*);
                    const adj_off = off + abi_size;
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @intCast(u32, abi_size)),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = @bitCast(u32, -@intCast(i32, adj_off)) },
                    });
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
            if (off > math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            const abi_size = dst_ty.abiSize(self.target.*);
            if (abi_size > 8) {
                return self.fail("TODO implement ADD/SUB/CMP for stack dst with large ABI", .{});
            }
            const adj_off = off + abi_size;

            switch (src_mcv) {
                .none => unreachable,
                .undef => return self.genSetStack(dst_ty, off, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .ptr_embedded_in_code => unreachable,
                .register => |src_reg| {
                    _ = try self.addInst(.{
                        .tag = mir_tag,
                        .ops = (Mir.Ops{
                            .reg1 = .rbp,
                            .reg2 = registerAlias(src_reg, @intCast(u32, abi_size)),
                            .flags = 0b10,
                        }).encode(),
                        .data = .{ .imm = @bitCast(u32, -@intCast(i32, adj_off)) },
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
                        .dest_off = @bitCast(u32, -@intCast(i32, adj_off)),
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

// Performs integer multiplication between dst_mcv and src_mcv, storing the result in dst_mcv.
fn genIMulOpMir(self: *Self, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
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
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @divExact(src_reg.size(), 8)),
                            .reg2 = src_reg,
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
                        return self.genIMulOpMir(dst_ty, dst_mcv, MCValue{ .register = src_reg });
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
                    _ = try self.addInst(.{
                        .tag = .imul_complex,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(dst_reg, @divExact(src_reg.size(), 8)),
                            .reg2 = src_reg,
                        }).encode(),
                        .data = undefined,
                    });
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

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const mcv = self.args[arg_index];
    const payload = try self.addExtra(Mir.ArgDbgInfo{
        .air_inst = inst,
        .arg_index = @truncate(u32, arg_index), // TODO can arg_index: u32?
    });
    _ = try self.addInst(.{
        .tag = .arg_dbg_info,
        .ops = undefined,
        .data = .{ .payload = payload },
    });
    if (self.liveness.isUnused(inst))
        return self.finishAirBookkeeping();

    const dst_mcv: MCValue = blk: {
        switch (mcv) {
            .register => |reg| {
                self.register_manager.getRegAssumeFree(reg.to64(), inst);
                break :blk mcv;
            },
            .stack_offset => |off| {
                const ty = self.air.typeOfIndex(inst);
                const abi_size = ty.abiSize(self.target.*);

                if (abi_size <= 8) {
                    const reg = try self.register_manager.allocReg(inst, &.{});
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = registerAlias(reg, @intCast(u32, abi_size)),
                            .reg2 = .rbp,
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = off + 16 },
                    });
                    break :blk .{ .register = reg };
                }

                // TODO copy ellision
                const dst_mcv = try self.allocRegOrMem(inst, false);
                const regs = try self.register_manager.allocRegs(3, .{ null, null, null }, &.{ .rax, .rcx });
                const addr_reg = regs[0];
                const count_reg = regs[1];
                const tmp_reg = regs[2];

                try self.register_manager.getReg(.rax, null);
                try self.register_manager.getReg(.rcx, null);

                _ = try self.addInst(.{
                    .tag = .lea,
                    .ops = (Mir.Ops{
                        .reg1 = addr_reg.to64(),
                        .reg2 = .rbp,
                    }).encode(),
                    .data = .{ .imm = off + 16 },
                });

                // TODO allow for abi_size to be u64
                try self.genSetReg(Type.initTag(.u32), count_reg, .{ .immediate = @intCast(u32, abi_size) });
                try self.genInlineMemcpy(
                    @bitCast(u32, -@intCast(i32, dst_mcv.stack_offset + abi_size)),
                    .rbp,
                    addr_reg.to64(),
                    count_reg.to64(),
                    tmp_reg.to8(),
                );

                break :blk dst_mcv;
            },
            else => unreachable,
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

fn airRetAddr(self: *Self) !void {
    return self.fail("TODO implement airRetAddr for {}", .{self.target.cpu.arch});
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn genSetStackArg(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .dead => unreachable,
        .ptr_embedded_in_code => unreachable,
        .unreach, .none => return,
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = .rsp,
                    .reg2 = registerAlias(reg, @intCast(u32, abi_size)),
                    .flags = 0b10,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, stack_offset + abi_size)) },
            });
        },
        .ptr_stack_offset => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
        },
        .stack_offset => |unadjusted_off| {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }

            const regs = try self.register_manager.allocRegs(3, .{ null, null, null }, &.{ .rax, .rcx });
            const addr_reg = regs[0];
            const count_reg = regs[1];
            const tmp_reg = regs[2];

            try self.register_manager.getReg(.rax, null);
            try self.register_manager.getReg(.rcx, null);

            _ = try self.addInst(.{
                .tag = .lea,
                .ops = (Mir.Ops{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, unadjusted_off + abi_size)) },
            });

            // TODO allow for abi_size to be u64
            try self.genSetReg(Type.initTag(.u32), count_reg, .{ .immediate = @intCast(u32, abi_size) });
            try self.genInlineMemcpy(
                @bitCast(u32, -@intCast(i32, stack_offset + abi_size)),
                .rsp,
                addr_reg.to64(),
                count_reg.to64(),
                tmp_reg.to8(),
            );
        },
        else => return self.fail("TODO implement args on stack for {}", .{mcv}),
    }
}

fn airCall(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @bitCast([]const Air.Inst.Ref, self.air.extra[extra.end..][0..extra.data.args_len]);
    const ty = self.air.typeOf(callee);

    const fn_ty = switch (ty.zigTypeTag()) {
        .Fn => ty,
        .Pointer => ty.childType(),
        else => unreachable,
    };

    var info = try self.resolveCallingConventionValues(fn_ty);
    defer info.deinit(self);

    var count: usize = info.args.len;
    var stack_adjustment: u32 = 0;
    while (count > 0) : (count -= 1) {
        const arg_i = count - 1;
        const mc_arg = info.args[arg_i];
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
                const abi_size = arg_ty.abiSize(self.target.*);
                try self.genSetStackArg(arg_ty, off, arg_mcv);
                stack_adjustment += @intCast(u32, abi_size);
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

    if (stack_adjustment > 0) {
        // Adjust the stack
        _ = try self.addInst(.{
            .tag = .sub,
            .ops = (Mir.Ops{
                .reg1 = .rsp,
            }).encode(),
            .data = .{ .imm = stack_adjustment },
        });
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (self.bin_file.tag == link.File.Elf.base_tag or self.bin_file.tag == link.File.Coff.base_tag) {
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
                // TODO I'm hacking my way through here by repurposing .memory for storing
                // index to the GOT target symbol index.
                try self.genSetReg(Type.initTag(.usize), .rax, .{
                    .memory = func.owner_decl.link.macho.local_sym_index,
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
                const decl = func_payload.data;
                const n_strx = try macho_file.addExternFn(mem.sliceTo(decl.name, 0));
                _ = try self.addInst(.{
                    .tag = .call_extern,
                    .ops = undefined,
                    .data = .{ .extern_fn = n_strx },
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
                const got_index = func_payload.data.owner_decl.link.plan9.got_index.?;
                const fn_got_addr = got_addr + got_index * ptr_bytes;
                _ = try self.addInst(.{
                    .tag = .call,
                    .ops = (Mir.Ops{
                        .flags = 0b01,
                    }).encode(),
                    .data = .{ .imm = @bitCast(i32, @intCast(u32, fn_got_addr)) },
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

    if (stack_adjustment > 0) {
        // Readjust the stack
        _ = try self.addInst(.{
            .tag = .add,
            .ops = (Mir.Ops{
                .reg1 = .rsp,
            }).encode(),
            .data = .{ .imm = stack_adjustment },
        });
    }

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
    const jmp_reloc = try self.addInst(.{
        .tag = .jmp,
        .ops = (Mir.Ops{
            .flags = 0b00,
        }).encode(),
        .data = .{ .inst = undefined },
    });
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
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
    // we can reuse self.ret_mcv because it just gets returned
    try self.load(self.ret_mcv, ptr, self.air.typeOf(un_op));
    try self.ret(self.ret_mcv);
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

    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const result: MCValue = result: {
        // There are 2 operands, destination and source.
        // Either one, but not both, can be a memory operand.
        // Source operand can be an immediate, 8 bits or 32 bits.
        const dst_mcv = if (lhs.isImmediate() or (lhs.isMemory() and rhs.isMemory()))
            try self.copyToNewRegister(inst, lhs)
        else
            lhs;
        // This instruction supports only signed 32-bit immediates at most.
        const src_mcv = try self.limitImmediateType(bin_op.rhs, i32);

        try self.genBinMathOpMir(.cmp, ty, signedness, dst_mcv, src_mcv);
        break :result switch (signedness) {
            .signed => MCValue{ .compare_flags_signed = op },
            .unsigned => MCValue{ .compare_flags_unsigned = op },
        };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const cond_ty = self.air.typeOf(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body = self.air.extra[extra.end..][0..extra.data.then_body_len];
    const else_body = self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
    const liveness_condbr = self.liveness.getCondBr(inst);

    const reloc: Mir.Inst.Index = reloc: {
        switch (cond) {
            .compare_flags_signed => |cmp_op| {
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
                else
                    .cond_jmp_greater_less;
                const reloc = try self.addInst(.{
                    .tag = tag,
                    .ops = (Mir.Ops{
                        .flags = flags,
                    }).encode(),
                    .data = .{ .inst = undefined },
                });
                break :reloc reloc;
            },
            .compare_flags_unsigned => |cmp_op| {
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
                else
                    .cond_jmp_above_below;
                const reloc = try self.addInst(.{
                    .tag = tag,
                    .ops = (Mir.Ops{
                        .flags = flags,
                    }).encode(),
                    .data = .{ .inst = undefined },
                });
                break :reloc reloc;
            },
            .register => |reg| {
                _ = try self.addInst(.{
                    .tag = .@"test",
                    .ops = (Mir.Ops{
                        .reg1 = reg,
                        .flags = 0b00,
                    }).encode(),
                    .data = .{ .imm = 1 },
                });
                const reloc = try self.addInst(.{
                    .tag = .cond_jmp_eq_ne,
                    .ops = (Mir.Ops{
                        .flags = 0b01,
                    }).encode(),
                    .data = .{ .inst = undefined },
                });
                break :reloc reloc;
            },
            .immediate => |imm| {
                if (cond_ty.abiSize(self.target.*) <= 4) {
                    const reg = try self.copyToTmpRegister(cond_ty, .{ .immediate = imm });
                    _ = try self.addInst(.{
                        .tag = .@"test",
                        .ops = (Mir.Ops{
                            .reg1 = reg,
                            .flags = 0b00,
                        }).encode(),
                        .data = .{ .imm = 1 },
                    });
                    const reloc = try self.addInst(.{
                        .tag = .cond_jmp_eq_ne,
                        .ops = (Mir.Ops{
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .inst = undefined },
                    });
                    break :reloc reloc;
                }
                return self.fail("TODO implement condbr when condition is immediate larger than 4 bytes", .{});
            },
            else => return self.fail("TODO implement condbr when condition is {s}", .{@tagName(cond)}),
        }
    };

    // Capture the state of register and stack allocation state so that we can revert to it.
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

fn isNull(self: *Self, ty: Type, operand: MCValue) !MCValue {
    try self.genBinMathOpMir(.cmp, ty, .unsigned, operand, MCValue{ .immediate = 0 });
    return MCValue{ .compare_flags_unsigned = .eq };
}

fn isNonNull(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const is_null_res = try self.isNull(ty, operand);
    assert(is_null_res.compare_flags_unsigned == .eq);
    return MCValue{ .compare_flags_unsigned = .neq };
}

fn isErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const err_type = ty.errorUnionSet();
    const payload_type = ty.errorUnionPayload();
    if (!err_type.hasCodeGenBits()) {
        return MCValue{ .immediate = 0 }; // always false
    } else if (!payload_type.hasCodeGenBits()) {
        if (err_type.abiSize(self.target.*) <= 8) {
            try self.genBinMathOpMir(.cmp, err_type, .unsigned, operand, MCValue{ .immediate = 0 });
            return MCValue{ .compare_flags_unsigned = .gt };
        } else {
            return self.fail("TODO isErr for errors with size larger than register size", .{});
        }
    } else {
        return self.fail("TODO isErr for non-empty payloads", .{});
    }
}

fn isNonErr(self: *Self, ty: Type, operand: MCValue) !MCValue {
    const is_err_res = try self.isErr(ty, operand);
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
        break :result try self.isNull(ty, operand);
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
        const ptr_ty = self.air.typeOf(un_op);
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
        break :result try self.isNonErr(ptr_ty.elemType(), operand);
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

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition = pl_op.operand;
    _ = condition;
    return self.fail("TODO airSwitch for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, .dead, .{ condition, .none, .none });
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

    if (self.air.typeOf(operand).hasCodeGenBits()) {
        const operand_mcv = try self.resolveInst(operand);
        const block_mcv = block_data.mcv;
        if (block_mcv == .none) {
            block_data.mcv = switch (operand_mcv) {
                .none, .dead, .unreach => unreachable,
                .register, .stack_offset, .memory => operand_mcv,
                .immediate => blk: {
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
    const args = @bitCast([]const Air.Inst.Ref, self.air.extra[air_extra.end..][0..args_len]);

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
    if (args.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        std.mem.copy(Air.Inst.Ref, &buf, args);
        return self.finishAir(inst, result, buf);
    }
    var bt = try self.iterateBigTomb(inst, args.len);
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
        .immediate => unreachable,
        .register => |reg| return self.genSetReg(ty, reg, val),
        .stack_offset => |off| return self.genSetStack(ty, off, val),
        .memory => {
            return self.fail("TODO implement setRegOrMem for memory", .{});
        },
        else => {
            return self.fail("TODO implement setRegOrMem for {}", .{loc});
        },
    }
}

fn genSetStack(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    switch (mcv) {
        .dead => unreachable,
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
                else => return self.genInlineMemset(ty, stack_offset, .{ .immediate = 0xaa }),
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
            switch (abi_size) {
                1, 2, 4 => {
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    // mov [rbp+offset], immediate
                    const payload = try self.addExtra(Mir.ImmPair{
                        .dest_off = @bitCast(u32, -@intCast(i32, adj_off)),
                        .operand = @truncate(u32, x_big),
                    });
                    _ = try self.addInst(.{
                        .tag = .mov_mem_imm,
                        .ops = (Mir.Ops{
                            .reg1 = .rbp,
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
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    const negative_offset = -@intCast(i32, adj_off);

                    // 64 bit write to memory would take two mov's anyways so we
                    // insted just use two 32 bit writes to avoid register allocation
                    {
                        const payload = try self.addExtra(Mir.ImmPair{
                            .dest_off = @bitCast(u32, negative_offset + 4),
                            .operand = @truncate(u32, x_big >> 32),
                        });
                        _ = try self.addInst(.{
                            .tag = .mov_mem_imm,
                            .ops = (Mir.Ops{
                                .reg1 = .rbp,
                                .flags = 0b10,
                            }).encode(),
                            .data = .{ .payload = payload },
                        });
                    }
                    {
                        const payload = try self.addExtra(Mir.ImmPair{
                            .dest_off = @bitCast(u32, negative_offset),
                            .operand = @truncate(u32, x_big),
                        });
                        _ = try self.addInst(.{
                            .tag = .mov_mem_imm,
                            .ops = (Mir.Ops{
                                .reg1 = .rbp,
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
            const abi_size = ty.abiSize(self.target.*);
            const adj_off = stack_offset + abi_size;
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = .rbp,
                    .reg2 = registerAlias(reg, @intCast(u32, abi_size)),
                    .flags = 0b10,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, adj_off)) },
            });
        },
        .memory, .embedded_in_code => {
            if (ty.abiSize(self.target.*) <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            }
            return self.fail("TODO implement memcpy for setting stack from {}", .{mcv});
        },
        .ptr_stack_offset => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .stack_offset => |off| {
            if (stack_offset == off) {
                // Copy stack variable to itself; nothing to do.
                return;
            }

            const abi_size = ty.abiSize(self.target.*);
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
            }

            const regs = try self.register_manager.allocRegs(3, .{ null, null, null }, &.{ .rax, .rcx });
            const addr_reg = regs[0];
            const count_reg = regs[1];
            const tmp_reg = regs[2];

            try self.register_manager.getReg(.rax, null);
            try self.register_manager.getReg(.rcx, null);

            _ = try self.addInst(.{
                .tag = .lea,
                .ops = (Mir.Ops{
                    .reg1 = addr_reg.to64(),
                    .reg2 = .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, off + abi_size)) },
            });

            // TODO allow for abi_size to be u64
            try self.genSetReg(Type.initTag(.u32), count_reg, .{ .immediate = @intCast(u32, abi_size) });

            return self.genInlineMemcpy(
                @bitCast(u32, -@intCast(i32, stack_offset + abi_size)),
                .rbp,
                addr_reg.to64(),
                count_reg.to64(),
                tmp_reg.to8(),
            );
        },
    }
}

fn genInlineMemcpy(
    self: *Self,
    stack_offset: u32,
    stack_reg: Register,
    addr_reg: Register,
    count_reg: Register,
    tmp_reg: Register,
) InnerError!void {
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
            .reg2 = addr_reg,
        }).encode(),
        .data = .{ .imm = 0 },
    });

    // mov [stack_offset + rax], tmp
    _ = try self.addInst(.{
        .tag = .mov_scale_dst,
        .ops = (Mir.Ops{
            .reg1 = stack_reg,
            .reg2 = tmp_reg.to8(),
        }).encode(),
        .data = .{ .imm = stack_offset },
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

fn genInlineMemset(self: *Self, ty: Type, stack_offset: u32, value: MCValue) InnerError!void {
    try self.register_manager.getReg(.rax, null);
    const abi_size = ty.abiSize(self.target.*);
    const adj_off = stack_offset + abi_size;
    if (adj_off > 128) {
        return self.fail("TODO inline memset with large stack offset", .{});
    }
    const negative_offset = @bitCast(u32, -@intCast(i32, adj_off));

    // We are actually counting `abi_size` bytes; however, we reuse the index register
    // as both the counter and offset scaler, hence we need to subtract one from `abi_size`
    // and count until -1.
    if (abi_size > math.maxInt(i32)) {
        // movabs rax, abi_size - 1
        const payload = try self.addExtra(Mir.Imm64.encode(abi_size - 1));
        _ = try self.addInst(.{
            .tag = .movabs,
            .ops = (Mir.Ops{
                .reg1 = .rax,
            }).encode(),
            .data = .{ .payload = payload },
        });
    } else {
        // mov rax, abi_size - 1
        _ = try self.addInst(.{
            .tag = .mov,
            .ops = (Mir.Ops{
                .reg1 = .rax,
            }).encode(),
            .data = .{ .imm = @truncate(u32, abi_size - 1) },
        });
    }

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
                .dest_off = negative_offset,
                .operand = @truncate(u32, x),
            });
            _ = try self.addInst(.{
                .tag = .mov_mem_index_imm,
                .ops = (Mir.Ops{
                    .reg1 = .rbp,
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
    switch (mcv) {
        .dead => unreachable,
        .ptr_stack_offset => |unadjusted_off| {
            const ptr_abi_size = ty.abiSize(self.target.*);
            const elem_ty = ty.childType();
            const elem_abi_size = elem_ty.abiSize(self.target.*);
            const off = unadjusted_off + elem_abi_size;
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, @intCast(u32, ptr_abi_size)),
                    .reg2 = .rbp,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, off)) },
            });
        },
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
        .compare_flags_unsigned,
        .compare_flags_signed,
        => |op| {
            const tag: Mir.Inst.Tag = switch (op) {
                .gte, .gt, .lt, .lte => .cond_set_byte_above_below,
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
                        .reg1 = reg.to64(),
                        .reg2 = reg.to64(),
                    }).encode(),
                    .data = undefined,
                });
                return;
            }
            if (x <= math.maxInt(i32)) {
                const abi_size = ty.abiSize(self.target.*);
                // Next best case: if we set the lower four bytes, the upper four will be zeroed.
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = registerAlias(reg, @intCast(u32, abi_size)),
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
        .embedded_in_code => |code_offset| {
            // We need the offset from RIP in a signed i32 twos complement.
            const payload = try self.addExtra(Mir.Imm64.encode(code_offset));
            _ = try self.addInst(.{
                .tag = .lea,
                .ops = (Mir.Ops{
                    .reg1 = reg,
                    .flags = 0b01,
                }).encode(),
                .data = .{ .payload = payload },
            });
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, @divExact(src_reg.size(), 8)),
                    .reg2 = src_reg,
                }).encode(),
                .data = undefined,
            });
        },
        .memory => |x| {
            // TODO can we move this entire logic into Emit.zig like with aarch64?
            if (self.bin_file.options.pie) {
                // TODO we should flag up `x` as GOT symbol entry explicitly rather than as a hack.
                _ = try self.addInst(.{
                    .tag = .lea,
                    .ops = (Mir.Ops{
                        .reg1 = reg,
                        .flags = 0b10,
                    }).encode(),
                    .data = .{ .got_entry = @truncate(u32, x) },
                });
                // MOV reg, [reg]
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = reg,
                        .reg2 = reg,
                        .flags = 0b01,
                    }).encode(),
                    .data = .{ .imm = 0 },
                });
            } else if (x <= math.maxInt(i32)) {
                // mov reg, [ds:imm32]
                _ = try self.addInst(.{
                    .tag = .mov,
                    .ops = (Mir.Ops{
                        .reg1 = reg,
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

                    // mov reg, [reg + 0x0]
                    _ = try self.addInst(.{
                        .tag = .mov,
                        .ops = (Mir.Ops{
                            .reg1 = reg,
                            .reg2 = reg,
                            .flags = 0b01,
                        }).encode(),
                        .data = .{ .imm = 0 },
                    });
                }
            }
        },
        .stack_offset => |unadjusted_off| {
            const abi_size = ty.abiSize(self.target.*);
            const off = unadjusted_off + abi_size;
            if (off < std.math.minInt(i32) or off > std.math.maxInt(i32)) {
                return self.fail("stack offset too large", .{});
            }
            _ = try self.addInst(.{
                .tag = .mov,
                .ops = (Mir.Ops{
                    .reg1 = registerAlias(reg, @intCast(u32, abi_size)),
                    .reg2 = .rbp,
                    .flags = 0b01,
                }).encode(),
                .data = .{ .imm = @bitCast(u32, -@intCast(i32, off)) },
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
    const array_len = array_ty.arrayLenIncludingSentinel();
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else blk: {
        const stack_offset = try self.allocMem(inst, 16, 16);
        try self.genSetStack(ptr_ty, stack_offset + 8, ptr);
        try self.genSetStack(Type.initTag(.u64), stack_offset, .{ .immediate = array_len });
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

fn airVectorInit(self: *Self, inst: Air.Inst.Index) !void {
    const vector_ty = self.air.typeOfIndex(inst);
    const len = vector_ty.vectorLen();
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const elements = @bitCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = res: {
        if (self.liveness.isUnused(inst)) break :res MCValue.dead;
        return self.fail("TODO implement airVectorInit for x86_64", .{});
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

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    return self.finishAir(inst, MCValue.dead, .{ prefetch.ptr, .none, .none });
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
                return self.fail("TODO codegen more kinds of const pointers: {}", .{typed_value.val.tag()});
            },
        },
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits <= ptr_bits and info.signedness == .signed) {
                return MCValue{ .immediate = @bitCast(u64, typed_value.val.toSignedInt()) };
            }
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
            const err_name = typed_value.val.castTag(.@"error").?.data.name;
            const module = self.bin_file.options.module.?;
            const global_error_set = module.global_error_set;
            const error_index = global_error_set.get(err_name).?;
            return MCValue{ .immediate = error_index };
        },
        .ErrorUnion => {
            const error_type = typed_value.ty.errorUnionSet();
            const payload_type = typed_value.ty.errorUnionPayload();

            if (typed_value.val.castTag(.eu_payload)) |pl| {
                if (!payload_type.hasCodeGenBits()) {
                    // We use the error type directly as the type.
                    return MCValue{ .immediate = 0 };
                }

                _ = pl;
                return self.fail("TODO implement error union const of type '{}' (non-error)", .{typed_value.ty});
            } else {
                if (!payload_type.hasCodeGenBits()) {
                    // We use the error type directly as the type.
                    return self.genTypedValue(.{ .ty = error_type, .val = typed_value.val });
                }
            }

            return self.fail("TODO implement error union const of type '{}' (error)", .{typed_value.ty});
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
            // First, split into args that can be passed via registers.
            // This will make it easier to then push the rest of args in reverse
            // order on the stack.
            var next_int_reg: usize = 0;
            var by_reg = std.AutoHashMap(usize, usize).init(self.bin_file.allocator);
            defer by_reg.deinit();
            for (param_types) |ty, i| {
                if (!ty.hasCodeGenBits()) continue;
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
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

            var next_stack_offset: u32 = 0;
            var count: usize = param_types.len;
            while (count > 0) : (count -= 1) {
                const i = count - 1;
                const ty = param_types[i];
                if (!ty.hasCodeGenBits()) {
                    assert(cc != .C);
                    result.args[i] = .{ .none = {} };
                    continue;
                }
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                if (by_reg.get(i)) |int_reg| {
                    const aliased_reg = registerAlias(c_abi_int_param_regs[int_reg], param_size);
                    result.args[i] = .{ .register = aliased_reg };
                    next_int_reg += 1;
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
            if (ret_ty_size <= 8) {
                const aliased_reg = registerAlias(c_abi_int_return_regs[0], ret_ty_size);
                result.return_value = .{ .register = aliased_reg };
            } else {
                return self.fail("TODO support more return types for x86_64 backend", .{});
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
