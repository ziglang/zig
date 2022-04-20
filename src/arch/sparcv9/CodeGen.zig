//! SPARCv9 codegen.
//! This lowers AIR into MIR.
const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.codegen);
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const TypedValue = @import("../../TypedValue.zig");
const ErrorMsg = Module.ErrorMsg;
const Air = @import("../../Air.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Type = @import("../../type.zig").Type;
const GenerateSymbolError = @import("../../codegen.zig").GenerateSymbolError;
const FnResult = @import("../../codegen.zig").FnResult;
const DebugInfoOutput = @import("../../codegen.zig").DebugInfoOutput;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const RegisterManager = RegisterManagerFn(Self, Register, &abi.allocatable_regs);

const build_options = @import("build_options");

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const Register = bits.Register;

const Self = @This();

const InnerError = error{
    OutOfMemory,
    CodegenFail,
    OutOfRegisters,
};

const RegisterView = enum(u1) {
    caller,
    callee,
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
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index),
    /// The first break instruction encounters `null` here and chooses a
    /// machine code value for the block result, populating this field.
    /// Following break instructions encounter that value and use it for
    /// the location to store their block results.
    mcv: MCValue,
};

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

    var call_info = function.resolveCallingConventionValues(fn_type, .callee) catch |err| switch (err) {
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

fn gen(self: *Self) !void {
    const cc = self.fn_type.fnCallingConvention();
    if (cc != .Naked) {
        // TODO Finish function prologue and epilogue for sparcv9.

        // TODO Backpatch stack offset
        // save %sp, -176, %sp
        _ = try self.addInst(.{
            .tag = .save,
            .data = .{
                .arithmetic_3op = .{
                    .is_imm = true,
                    .rd = .sp,
                    .rs1 = .sp,
                    .rs2_or_imm = .{ .imm = -176 },
                },
            },
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
            return self.fail("TODO add branches in sparcv9", .{});
        }

        // return %i7 + 8
        _ = try self.addInst(.{
            .tag = .@"return",
            .data = .{
                .arithmetic_2op = .{
                    .is_imm = true,
                    .rs1 = .@"i7",
                    .rs2_or_imm = .{ .imm = 8 },
                },
            },
        });

        // TODO Find a way to fill this slot
        // nop
        _ = try self.addInst(.{
            .tag = .nop,
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
            .add, .ptr_add   => @panic("TODO try self.airBinOp(inst)"),
            .addwrap         => @panic("TODO try self.airAddWrap(inst)"),
            .add_sat         => @panic("TODO try self.airAddSat(inst)"),
            .sub, .ptr_sub   => @panic("TODO try self.airBinOp(inst)"),
            .subwrap         => @panic("TODO try self.airSubWrap(inst)"),
            .sub_sat         => @panic("TODO try self.airSubSat(inst)"),
            .mul             => @panic("TODO try self.airMul(inst)"),
            .mulwrap         => @panic("TODO try self.airMulWrap(inst)"),
            .mul_sat         => @panic("TODO try self.airMulSat(inst)"),
            .rem             => @panic("TODO try self.airRem(inst)"),
            .mod             => @panic("TODO try self.airMod(inst)"),
            .shl, .shl_exact => @panic("TODO try self.airShl(inst)"),
            .shl_sat         => @panic("TODO try self.airShlSat(inst)"),
            .min             => @panic("TODO try self.airMin(inst)"),
            .max             => @panic("TODO try self.airMax(inst)"),
            .slice           => @panic("TODO try self.airSlice(inst)"),

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
            => @panic("TODO try self.airUnaryMath(inst)"),

            .add_with_overflow => @panic("TODO try self.airAddWithOverflow(inst)"),
            .sub_with_overflow => @panic("TODO try self.airSubWithOverflow(inst)"),
            .mul_with_overflow => @panic("TODO try self.airMulWithOverflow(inst)"),
            .shl_with_overflow => @panic("TODO try self.airShlWithOverflow(inst)"),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airDiv(inst),

            .cmp_lt  => @panic("TODO try self.airCmp(inst, .lt)"),
            .cmp_lte => @panic("TODO try self.airCmp(inst, .lte)"),
            .cmp_eq  => @panic("TODO try self.airCmp(inst, .eq)"),
            .cmp_gte => @panic("TODO try self.airCmp(inst, .gte)"),
            .cmp_gt  => @panic("TODO try self.airCmp(inst, .gt)"),
            .cmp_neq => @panic("TODO try self.airCmp(inst, .neq)"),
            .cmp_vector => @panic("TODO try self.airCmpVector(inst)"),
            .cmp_lt_errors_len => @panic("TODO try self.airCmpLtErrorsLen(inst)"),

            .bool_and        => @panic("TODO try self.airBoolOp(inst)"),
            .bool_or         => @panic("TODO try self.airBoolOp(inst)"),
            .bit_and         => @panic("TODO try self.airBitAnd(inst)"),
            .bit_or          => @panic("TODO try self.airBitOr(inst)"),
            .xor             => @panic("TODO try self.airXor(inst)"),
            .shr, .shr_exact => @panic("TODO try self.airShr(inst)"),

            .alloc           => @panic("TODO try self.airAlloc(inst)"),
            .ret_ptr         => try self.airRetPtr(inst),
            .arg             => try self.airArg(inst),
            .assembly        => try self.airAsm(inst),
            .bitcast         => @panic("TODO try self.airBitCast(inst)"),
            .block           => try self.airBlock(inst),
            .br              => @panic("TODO try self.airBr(inst)"),
            .breakpoint      => try self.airBreakpoint(),
            .ret_addr        => @panic("TODO try self.airRetAddr(inst)"),
            .frame_addr      => @panic("TODO try self.airFrameAddress(inst)"),
            .fence           => @panic("TODO try self.airFence()"),
            .cond_br         => @panic("TODO try self.airCondBr(inst)"),
            .dbg_stmt        => try self.airDbgStmt(inst),
            .fptrunc         => @panic("TODO try self.airFptrunc(inst)"),
            .fpext           => @panic("TODO try self.airFpext(inst)"),
            .intcast         => @panic("TODO try self.airIntCast(inst)"),
            .trunc           => @panic("TODO try self.airTrunc(inst)"),
            .bool_to_int     => @panic("TODO try self.airBoolToInt(inst)"),
            .is_non_null     => @panic("TODO try self.airIsNonNull(inst)"),
            .is_non_null_ptr => @panic("TODO try self.airIsNonNullPtr(inst)"),
            .is_null         => @panic("TODO try self.airIsNull(inst)"),
            .is_null_ptr     => @panic("TODO try self.airIsNullPtr(inst)"),
            .is_non_err      => @panic("TODO try self.airIsNonErr(inst)"),
            .is_non_err_ptr  => @panic("TODO try self.airIsNonErrPtr(inst)"),
            .is_err          => @panic("TODO try self.airIsErr(inst)"),
            .is_err_ptr      => @panic("TODO try self.airIsErrPtr(inst)"),
            .load            => @panic("TODO try self.airLoad(inst)"),
            .loop            => @panic("TODO try self.airLoop(inst)"),
            .not             => @panic("TODO try self.airNot(inst)"),
            .ptrtoint        => @panic("TODO try self.airPtrToInt(inst)"),
            .ret             => try self.airRet(inst),
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst),
            .struct_field_ptr=> @panic("TODO try self.airStructFieldPtr(inst)"),
            .struct_field_val=> @panic("TODO try self.airStructFieldVal(inst)"),
            .array_to_slice  => @panic("TODO try self.airArrayToSlice(inst)"),
            .int_to_float    => @panic("TODO try self.airIntToFloat(inst)"),
            .float_to_int    => @panic("TODO try self.airFloatToInt(inst)"),
            .cmpxchg_strong  => @panic("TODO try self.airCmpxchg(inst)"),
            .cmpxchg_weak    => @panic("TODO try self.airCmpxchg(inst)"),
            .atomic_rmw      => @panic("TODO try self.airAtomicRmw(inst)"),
            .atomic_load     => @panic("TODO try self.airAtomicLoad(inst)"),
            .memcpy          => @panic("TODO try self.airMemcpy(inst)"),
            .memset          => @panic("TODO try self.airMemset(inst)"),
            .set_union_tag   => @panic("TODO try self.airSetUnionTag(inst)"),
            .get_union_tag   => @panic("TODO try self.airGetUnionTag(inst)"),
            .clz             => @panic("TODO try self.airClz(inst)"),
            .ctz             => @panic("TODO try self.airCtz(inst)"),
            .popcount        => @panic("TODO try self.airPopcount(inst)"),
            .byte_swap       => @panic("TODO try self.airByteSwap(inst)"),
            .bit_reverse     => @panic("TODO try self.airBitReverse(inst)"),
            .tag_name        => @panic("TODO try self.airTagName(inst)"),
            .error_name      => @panic("TODO try self.airErrorName(inst)"),
            .splat           => @panic("TODO try self.airSplat(inst)"),
            .select          => @panic("TODO try self.airSelect(inst)"),
            .shuffle         => @panic("TODO try self.airShuffle(inst)"),
            .reduce          => @panic("TODO try self.airReduce(inst)"),
            .aggregate_init  => @panic("TODO try self.airAggregateInit(inst)"),
            .union_init      => @panic("TODO try self.airUnionInit(inst)"),
            .prefetch        => @panic("TODO try self.airPrefetch(inst)"),
            .mul_add         => @panic("TODO try self.airMulAdd(inst)"),

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

            .atomic_store_unordered => @panic("TODO try self.airAtomicStore(inst, .Unordered)"),
            .atomic_store_monotonic => @panic("TODO try self.airAtomicStore(inst, .Monotonic)"),
            .atomic_store_release   => @panic("TODO try self.airAtomicStore(inst, .Release)"),
            .atomic_store_seq_cst   => @panic("TODO try self.airAtomicStore(inst, .SeqCst)"),

            .struct_field_ptr_index_0 => @panic("TODO try self.airStructFieldPtrIndex(inst, 0)"),
            .struct_field_ptr_index_1 => @panic("TODO try self.airStructFieldPtrIndex(inst, 1)"),
            .struct_field_ptr_index_2 => @panic("TODO try self.airStructFieldPtrIndex(inst, 2)"),
            .struct_field_ptr_index_3 => @panic("TODO try self.airStructFieldPtrIndex(inst, 3)"),

            .field_parent_ptr => @panic("TODO try self.airFieldParentPtr(inst)"),

            .switch_br       => try self.airSwitch(inst),
            .slice_ptr       => @panic("TODO try self.airSlicePtr(inst)"),
            .slice_len       => @panic("TODO try self.airSliceLen(inst)"),

            .ptr_slice_len_ptr => @panic("TODO try self.airPtrSliceLenPtr(inst)"),
            .ptr_slice_ptr_ptr => @panic("TODO try self.airPtrSlicePtrPtr(inst)"),

            .array_elem_val      => @panic("TODO try self.airArrayElemVal(inst)"),
            .slice_elem_val      => @panic("TODO try self.airSliceElemVal(inst)"),
            .slice_elem_ptr      => @panic("TODO try self.airSliceElemPtr(inst)"),
            .ptr_elem_val        => @panic("TODO try self.airPtrElemVal(inst)"),
            .ptr_elem_ptr        => @panic("TODO try self.airPtrElemPtr(inst)"),

            .constant => unreachable, // excluded from function bodies
            .const_ty => unreachable, // excluded from function bodies
            .unreach  => self.finishAirBookkeeping(),

            .optional_payload           => @panic("TODO try self.airOptionalPayload(inst)"),
            .optional_payload_ptr       => @panic("TODO try self.airOptionalPayloadPtr(inst)"),
            .optional_payload_ptr_set   => @panic("TODO try self.airOptionalPayloadPtrSet(inst)"),
            .unwrap_errunion_err        => @panic("TODO try self.airUnwrapErrErr(inst)"),
            .unwrap_errunion_payload    => @panic("TODO try self.airUnwrapErrPayload(inst)"),
            .unwrap_errunion_err_ptr    => @panic("TODO try self.airUnwrapErrErrPtr(inst)"),
            .unwrap_errunion_payload_ptr=> @panic("TODO try self.airUnwrapErrPayloadPtr(inst)"),
            .errunion_payload_ptr_set   => @panic("TODO try self.airErrUnionPayloadPtrSet(inst)"),

            .wrap_optional         => @panic("TODO try self.airWrapOptional(inst)"),
            .wrap_errunion_payload => @panic("TODO try self.airWrapErrUnionPayload(inst)"),
            .wrap_errunion_err     => @panic("TODO try self.airWrapErrUnionErr(inst)"),

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

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = (extra.data.flags & 0x80000000) != 0;
    const clobbers_len = @truncate(u31, extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i .. extra_i + extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i .. extra_i + extra.data.inputs_len]);
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

        if (mem.eql(u8, asm_source, "ta 0x6d")) {
            _ = try self.addInst(.{
                .tag = .tcc,
                .data = .{
                    .trap = .{
                        .is_imm = true,
                        .cond = 0b1000, // TODO need to look into changing this into an enum
                        .rs2_or_imm = .{ .imm = 0x6d },
                    },
                },
            });
        } else {
            return self.fail("TODO implement a full SPARCv9 assembly parsing", .{});
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

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const arg_index = self.arg_index;
    self.arg_index += 1;

    const ty = self.air.typeOfIndex(inst);
    _ = ty;

    const result = self.args[arg_index];
    // TODO support stack-only arguments
    // TODO Copy registers to the stack
    const mcv = result;

    _ = try self.addInst(.{
        .tag = .dbg_arg,
        .data = .{
            .dbg_arg_info = .{
                .air_inst = inst,
                .arg_index = arg_index,
            },
        },
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

    // relocations for `bpcc` instructions
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

fn airBreakpoint(self: *Self) !void {
    // ta 0x01
    _ = try self.addInst(.{
        .tag = .tcc,
        .data = .{
            .trap = .{
                .is_imm = true,
                .cond = 0b1000, // TODO need to look into changing this into an enum
                .rs2_or_imm = .{ .imm = 0x01 },
            },
        },
    });
    return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallOptions.Modifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for {}", .{self.target.cpu.arch});

    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const args = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra.end .. extra.end + extra.data.args_len]);
    const ty = self.air.typeOf(callee);
    const fn_ty = switch (ty.zigTypeTag()) {
        .Fn => ty,
        .Pointer => ty.childType(),
        else => unreachable,
    };

    var info = try self.resolveCallingConventionValues(fn_ty, .caller);
    defer info.deinit(self);
    for (info.args) |mc_arg, arg_i| {
        const arg = args[arg_i];
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);

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

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    if (self.air.value(callee)) |func_value| {
        if (self.bin_file.tag == link.File.Elf.base_tag) {
            if (func_value.castTag(.function)) |func_payload| {
                const func = func_payload.data;
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const got_addr = if (self.bin_file.cast(link.File.Elf)) |elf_file| blk: {
                    const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
                    const mod = self.bin_file.options.module.?;
                    break :blk @intCast(u32, got.p_vaddr + mod.declPtr(func.owner_decl).link.elf.offset_table_index * ptr_bytes);
                } else unreachable;

                try self.genSetReg(Type.initTag(.usize), .o7, .{ .memory = got_addr });

                _ = try self.addInst(.{
                    .tag = .jmpl,
                    .data = .{ .branch_link_indirect = .{ .reg = .o7 } },
                });
            } else if (func_value.castTag(.extern_fn)) |_| {
                return self.fail("TODO implement calling extern functions", .{});
            } else {
                return self.fail("TODO implement calling bitcasted functions", .{});
            }
        } else @panic("TODO SPARCv9 currently does not support non-ELF binaries");
    } else {
        assert(ty.zigTypeTag() == .Pointer);
        const mcv = try self.resolveInst(callee);
        try self.genSetReg(ty, .o7, mcv);

        _ = try self.addInst(.{
            .tag = .jmpl,
            .data = .{ .branch_link_indirect = .{ .reg = .o7 } },
        });
    }

    const result = info.return_value;

    if (args.len + 1 <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        buf[0] = callee;
        std.mem.copy(Air.Inst.Ref, buf[1..], args);
        return self.finishAir(inst, result, buf);
    }

    @panic("TODO handle return value with BigTomb");
}

fn airDbgBlock(self: *Self, inst: Air.Inst.Index) !void {
    // TODO emit debug info lexical block
    return self.finishAir(inst, .dead, .{ .none, .none, .none });
}

fn airDbgInline(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const function = self.air.values[ty_pl.payload].castTag(.function).?.data;
    // TODO emit debug info for function change
    _ = function;
    return self.finishAir(inst, .dead, .{ .none, .none, .none });
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;

    _ = try self.addInst(.{
        .tag = .dbg_line,
        .data = .{
            .dbg_line_column = .{
                .line = dbg_stmt.line,
                .column = dbg_stmt.column,
            },
        },
    });

    return self.finishAirBookkeeping();
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const name = self.air.nullTerminatedString(pl_op.payload);
    const operand = pl_op.operand;
    // TODO emit debug info for this variable
    _ = name;
    return self.finishAir(inst, .dead, .{ operand, .none, .none });
}

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const stack_offset = try self.allocMemPtr(inst);
    return self.finishAir(inst, .{ .ptr_stack_offset = stack_offset }, .{ .none, .none, .none });
}

fn airStore(self: *Self, inst: Air.Inst.Index) !void {
    _ = self;
    _ = inst;

    return self.fail("TODO implement store for {}", .{self.target.cpu.arch});
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    _ = self;
    _ = inst;

    return self.fail("TODO implement switch for {}", .{self.target.cpu.arch});
}

// Common helper functions

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;

    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);

    const result_index = @intCast(Air.Inst.Index, self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
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

    if (!elem_ty.hasRuntimeBits()) {
        // As this stack item will never be dereferenced at runtime,
        // return the stack offset 0. Stack offset 0 will be where all
        // zero-sized stack allocations live as non-zero-sized
        // allocations will always have an offset > 0.
        return @as(u32, 0);
    }

    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) catch {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };
    // TODO swap this for inst.ty.ptrAlign
    const abi_align = elem_ty.abiAlignment(self.target.*);
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
        if (abi_size <= 8) {
            if (self.register_manager.tryAllocReg(inst)) |reg| {
                return MCValue{ .register = reg };
            }
        }
    }
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = stack_offset };
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
    const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
    try table.ensureUnusedCapacity(self.gpa, additional_count);
}

fn fail(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.bin_file.allocator, self.src_loc, format, args);
    return error.CodegenFail;
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

fn genLoad(self: *Self, value_reg: Register, addr_reg: Register, comptime off_type: type, off: off_type, abi_size: u64) !void {
    assert(off_type == Register or off_type == i13);

    const is_imm = (off_type == i13);
    const rs2_or_imm = if (is_imm) .{ .imm = off } else .{ .rs2 = off };

    switch (abi_size) {
        1 => {
            _ = try self.addInst(.{
                .tag = .ldub,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = rs2_or_imm,
                    },
                },
            });
        },
        2 => {
            _ = try self.addInst(.{
                .tag = .lduh,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = rs2_or_imm,
                    },
                },
            });
        },
        4 => {
            _ = try self.addInst(.{
                .tag = .lduw,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = rs2_or_imm,
                    },
                },
            });
        },
        8 => {
            _ = try self.addInst(.{
                .tag = .ldx,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = is_imm,
                        .rd = value_reg,
                        .rs1 = addr_reg,
                        .rs2_or_imm = rs2_or_imm,
                    },
                },
            });
        },
        3, 5, 6, 7 => return self.fail("TODO: genLoad for more abi_sizes", .{}),
        else => unreachable,
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
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .ptr_stack_offset => |off| {
            const simm13 = math.cast(u12, off) catch
                return self.fail("TODO larger stack offsets", .{});

            _ = try self.addInst(.{
                .tag = .add,
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = true,
                        .rd = reg,
                        .rs1 = .sp,
                        .rs2_or_imm = .{ .imm = simm13 },
                    },
                },
            });
        },
        .immediate => |x| {
            if (x <= math.maxInt(u12)) {
                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = .g0,
                            .rs2_or_imm = .{ .imm = @truncate(u12, x) },
                        },
                    },
                });
            } else if (x <= math.maxInt(u32)) {
                _ = try self.addInst(.{
                    .tag = .sethi,
                    .data = .{
                        .sethi = .{
                            .rd = reg,
                            .imm = @truncate(u22, x >> 10),
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = @truncate(u10, x) },
                        },
                    },
                });
            } else if (x <= math.maxInt(u44)) {
                try self.genSetReg(ty, reg, .{ .immediate = @truncate(u32, x >> 12) });

                _ = try self.addInst(.{
                    .tag = .sllx,
                    .data = .{
                        .shift = .{
                            .is_imm = true,
                            .width = .shift64,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = 12 },
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = true,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = @truncate(u12, x) },
                        },
                    },
                });
            } else {
                // Need to allocate a temporary register to load 64-bit immediates.
                const tmp_reg = try self.register_manager.allocReg(null);

                try self.genSetReg(ty, tmp_reg, .{ .immediate = @truncate(u32, x) });
                try self.genSetReg(ty, reg, .{ .immediate = @truncate(u32, x >> 32) });

                _ = try self.addInst(.{
                    .tag = .sllx,
                    .data = .{
                        .shift = .{
                            .is_imm = true,
                            .width = .shift64,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .imm = 32 },
                        },
                    },
                });

                _ = try self.addInst(.{
                    .tag = .@"or",
                    .data = .{
                        .arithmetic_3op = .{
                            .is_imm = false,
                            .rd = reg,
                            .rs1 = reg,
                            .rs2_or_imm = .{ .rs2 = tmp_reg },
                        },
                    },
                });
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // or %g0, src, dst (aka mov src, dst)
            _ = try self.addInst(.{
                .tag = .@"or",
                .data = .{
                    .arithmetic_3op = .{
                        .is_imm = false,
                        .rd = reg,
                        .rs1 = .g0,
                        .rs2_or_imm = .{ .rs2 = src_reg },
                    },
                },
            });
        },
        .memory => |addr| {
            // The value is in memory at a hard-coded address.
            // If the type is a pointer, it means the pointer address is at this memory location.
            try self.genSetReg(ty, reg, .{ .immediate = addr });
            try self.genLoad(reg, reg, i13, 0, ty.abiSize(self.target.*));
        },
        .stack_offset => |off| {
            const simm13 = math.cast(u12, off) catch
                return self.fail("TODO larger stack offsets", .{});
            try self.genLoad(reg, .sp, i13, simm13, ty.abiSize(self.target.*));
        },
    }
}

fn genSetStack(self: *Self, ty: Type, stack_offset: u32, mcv: MCValue) InnerError!void {
    const abi_size = ty.abiSize(self.target.*);
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
                8 => return self.genSetStack(ty, stack_offset, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => return self.fail("TODO implement memset", .{}),
            }
        },
        .immediate,
        .ptr_stack_offset,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg });
        },
        .register => return self.fail("TODO implement storing types abi_size={}", .{abi_size}),
        .memory, .stack_offset => return self.fail("TODO implement memcpy", .{}),
    }
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

    switch (typed_value.ty.zigTypeTag()) {
        .Int => {
            const info = typed_value.ty.intInfo(self.target.*);
            if (info.bits <= 64) {
                const unsigned = switch (info.signedness) {
                    .signed => blk: {
                        const signed = typed_value.val.toSignedInt();
                        break :blk @bitCast(u64, signed);
                    },
                    .unsigned => typed_value.val.toUnsignedInt(target),
                };

                return MCValue{ .immediate = unsigned };
            } else {
                return self.fail("TODO implement int genTypedValue of > 64 bits", .{});
            }
        },
        .ComptimeInt => unreachable, // semantic analysis prevents this
        .ComptimeFloat => unreachable, // semantic analysis prevents this
        else => return self.fail("TODO implement const of type '{}'", .{typed_value.ty.fmtDebug()}),
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

fn lowerDeclRef(self: *Self, tv: TypedValue, decl_index: Module.Decl.Index) InnerError!MCValue {
    const ptr_bits = self.target.cpu.arch.ptrBitWidth();
    const ptr_bytes: u64 = @divExact(ptr_bits, 8);

    // TODO this feels clunky. Perhaps we should check for it in `genTypedValue`?
    if (tv.ty.zigTypeTag() == .Pointer) blk: {
        if (tv.ty.castPtrToFn()) |_| break :blk;
        if (!tv.ty.elemType2().hasRuntimeBits()) {
            return MCValue.none;
        }
    }

    const mod = self.bin_file.options.module.?;
    const decl = mod.declPtr(decl_index);

    mod.markDeclAlive(decl);
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const got = &elf_file.program_headers.items[elf_file.phdr_got_index.?];
        const got_addr = got.p_vaddr + decl.link.elf.offset_table_index * ptr_bytes;
        return MCValue{ .memory = got_addr };
    } else {
        return self.fail("TODO codegen non-ELF const Decl pointer", .{});
    }
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

fn performReloc(self: *Self, inst: Mir.Inst.Index) !void {
    const tag = self.mir_instructions.items(.tag)[inst];
    switch (tag) {
        .bpcc => self.mir_instructions.items(.data)[inst].branch_predict.inst = @intCast(Mir.Inst.Index, self.mir_instructions.len),
        else => unreachable,
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

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(self: *Self, fn_ty: Type, role: RegisterView) !CallMCValues {
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
            // SPARC Compliance Definition 2.4.1, Chapter 3
            // Low-Level System Information (64-bit psABI) - Function Calling Sequence

            var next_register: usize = 0;
            var next_stack_offset: u32 = 0;

            // The caller puts the argument in %o0-%o5, which becomes %i0-%i5 inside the callee.
            const argument_registers = switch (role) {
                .caller => abi.c_abi_int_param_regs_caller_view,
                .callee => abi.c_abi_int_param_regs_callee_view,
            };

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

            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .{ .unreach = {} };
            } else if (!ret_ty.hasRuntimeBits()) {
                result.return_value = .{ .none = {} };
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                // The callee puts the return values in %i0-%i3, which becomes %o0-%o3 inside the caller.
                if (ret_ty_size <= 8) {
                    result.return_value = switch (role) {
                        .caller => .{ .register = abi.c_abi_int_return_regs_caller_view[0] },
                        .callee => .{ .register = abi.c_abi_int_return_regs_callee_view[0] },
                    };
                } else {
                    return self.fail("TODO support more return values for sparcv9", .{});
                }
            }
        },
        else => return self.fail("TODO implement function parameters for {} on sparcv9", .{cc}),
    }

    return result;
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

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(inst, false);
    log.debug("spilling {d} to stack mcv {any}", .{ inst, stack_mcv });
    const reg_mcv = self.getResolvedInstValue(inst);
    assert(reg == reg_mcv.register);
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    try branch.inst_table.put(self.gpa, inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv);
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
