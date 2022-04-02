//! SPARCv9 codegen.
//! This lowers AIR into MIR.
const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;
const builtin = @import("builtin");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
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

    var call_info = function.resolveCallingConventionValues(fn_type, false) catch |err| switch (err) {
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

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(self: *Self, fn_ty: Type, is_caller: bool) !CallMCValues {
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
            const argument_registers = if (is_caller) abi.c_abi_int_param_regs_caller_view else abi.c_abi_int_param_regs_callee_view;

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
        else => return self.fail("TODO implement function parameters for {} on sparcv9", .{cc}),
    }

    if (ret_ty.zigTypeTag() == .NoReturn) {
        result.return_value = .{ .unreach = {} };
    } else if (!ret_ty.hasRuntimeBits()) {
        result.return_value = .{ .none = {} };
    } else switch (cc) {
        .Naked => unreachable,
        .Unspecified, .C => {
            const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
            // The callee puts the return values in %i0-%i3, which becomes %o0-%o3 inside the caller.
            if (ret_ty_size <= 8) {
                result.return_value = if (is_caller) .{ .register = abi.c_abi_int_return_regs_caller_view[0] } else .{ .register = abi.c_abi_int_return_regs_callee_view[0] };
            } else {
                return self.fail("TODO support more return values for sparcv9", .{});
            }
        },
        else => return self.fail("TODO implement function return values for {} on sparcv9", .{cc}),
    }
    return result;
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

            .div_float, .div_trunc, .div_floor, .div_exact => @panic("TODO try self.airDiv(inst)"),

            .cmp_lt  => @panic("TODO try self.airCmp(inst, .lt)"),
            .cmp_lte => @panic("TODO try self.airCmp(inst, .lte)"),
            .cmp_eq  => @panic("TODO try self.airCmp(inst, .eq)"),
            .cmp_gte => @panic("TODO try self.airCmp(inst, .gte)"),
            .cmp_gt  => @panic("TODO try self.airCmp(inst, .gt)"),
            .cmp_neq => @panic("TODO try self.airCmp(inst, .neq)"),
            .cmp_vector => @panic("TODO try self.airCmpVector(inst)"),

            .bool_and        => @panic("TODO try self.airBoolOp(inst)"),
            .bool_or         => @panic("TODO try self.airBoolOp(inst)"),
            .bit_and         => @panic("TODO try self.airBitAnd(inst)"),
            .bit_or          => @panic("TODO try self.airBitOr(inst)"),
            .xor             => @panic("TODO try self.airXor(inst)"),
            .shr, .shr_exact => @panic("TODO try self.airShr(inst)"),

            .alloc           => @panic("TODO try self.airAlloc(inst)"),
            .ret_ptr         => @panic("TODO try self.airRetPtr(inst)"),
            .arg             => @panic("TODO try self.airArg(inst)"),
            .assembly        => @panic("TODO try self.airAsm(inst)"),
            .bitcast         => @panic("TODO try self.airBitCast(inst)"),
            .block           => @panic("TODO try self.airBlock(inst)"),
            .br              => @panic("TODO try self.airBr(inst)"),
            .breakpoint      => @panic("TODO try self.airBreakpoint()"),
            .ret_addr        => @panic("TODO try self.airRetAddr(inst)"),
            .frame_addr      => @panic("TODO try self.airFrameAddress(inst)"),
            .fence           => @panic("TODO try self.airFence()"),
            .cond_br         => @panic("TODO try self.airCondBr(inst)"),
            .dbg_stmt        => @panic("TODO try self.airDbgStmt(inst)"),
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
            .ret             => @panic("TODO try self.airRet(inst)"),
            .ret_load        => @panic("TODO try self.airRetLoad(inst)"),
            .store           => @panic("TODO try self.airStore(inst)"),
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
            => @panic("TODO try self.airDbgVar(inst)"),

            .dbg_inline_begin,
            .dbg_inline_end,
            => @panic("TODO try self.airDbgInline(inst)"),

            .dbg_block_begin,
            .dbg_block_end,
            => @panic("TODO try self.airDbgBlock(inst)"),

            .call              => @panic("TODO try self.airCall(inst, .auto)"),
            .call_always_tail  => @panic("TODO try self.airCall(inst, .always_tail)"),
            .call_never_tail   => @panic("TODO try self.airCall(inst, .never_tail)"),
            .call_never_inline => @panic("TODO try self.airCall(inst, .never_inline)"),

            .atomic_store_unordered => @panic("TODO try self.airAtomicStore(inst, .Unordered)"),
            .atomic_store_monotonic => @panic("TODO try self.airAtomicStore(inst, .Monotonic)"),
            .atomic_store_release   => @panic("TODO try self.airAtomicStore(inst, .Release)"),
            .atomic_store_seq_cst   => @panic("TODO try self.airAtomicStore(inst, .SeqCst)"),

            .struct_field_ptr_index_0 => @panic("TODO try self.airStructFieldPtrIndex(inst, 0)"),
            .struct_field_ptr_index_1 => @panic("TODO try self.airStructFieldPtrIndex(inst, 1)"),
            .struct_field_ptr_index_2 => @panic("TODO try self.airStructFieldPtrIndex(inst, 2)"),
            .struct_field_ptr_index_3 => @panic("TODO try self.airStructFieldPtrIndex(inst, 3)"),

            .field_parent_ptr => @panic("TODO try self.airFieldParentPtr(inst)"),

            .switch_br       => @panic("TODO try self.airSwitch(inst)"),
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
            .unreach  => @panic("TODO self.finishAirBookkeeping()"),

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

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;

    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);

    const result_index = @intCast(Air.Inst.Index, self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
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
