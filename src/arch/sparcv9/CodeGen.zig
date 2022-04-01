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

/// Caller must call `CallMCValues.deinit`.
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
            .arg => @panic("TODO implement arg"),
            .add => @panic("TODO implement add"),
            .addwrap => @panic("TODO implement addwrap"),
            .add_sat => @panic("TODO implement add_sat"),
            .sub => @panic("TODO implement sub"),
            .subwrap => @panic("TODO implement subwrap"),
            .sub_sat => @panic("TODO implement sub_sat"),
            .mul => @panic("TODO implement mul"),
            .mulwrap => @panic("TODO implement mulwrap"),
            .mul_sat => @panic("TODO implement mul_sat"),
            .div_float => @panic("TODO implement div_float"),
            .div_trunc => @panic("TODO implement div_trunc"),
            .div_floor => @panic("TODO implement div_floor"),
            .div_exact => @panic("TODO implement div_exact"),
            .rem => @panic("TODO implement rem"),
            .mod => @panic("TODO implement mod"),
            .ptr_add => @panic("TODO implement ptr_add"),
            .ptr_sub => @panic("TODO implement ptr_sub"),
            .max => @panic("TODO implement max"),
            .min => @panic("TODO implement min"),
            .add_with_overflow => @panic("TODO implement add_with_overflow"),
            .sub_with_overflow => @panic("TODO implement sub_with_overflow"),
            .mul_with_overflow => @panic("TODO implement mul_with_overflow"),
            .shl_with_overflow => @panic("TODO implement shl_with_overflow"),
            .alloc => @panic("TODO implement alloc"),
            .ret_ptr => @panic("TODO implement ret_ptr"),
            .assembly => @panic("TODO implement assembly"),
            .bit_and => @panic("TODO implement bit_and"),
            .bit_or => @panic("TODO implement bit_or"),
            .shr => @panic("TODO implement shr"),
            .shr_exact => @panic("TODO implement shr_exact"),
            .shl => @panic("TODO implement shl"),
            .shl_exact => @panic("TODO implement shl_exact"),
            .shl_sat => @panic("TODO implement shl_sat"),
            .xor => @panic("TODO implement xor"),
            .not => @panic("TODO implement not"),
            .bitcast => @panic("TODO implement bitcast"),
            .block => @panic("TODO implement block"),
            .loop => @panic("TODO implement loop"),
            .br => @panic("TODO implement br"),
            .breakpoint => @panic("TODO implement breakpoint"),
            .ret_addr => @panic("TODO implement ret_addr"),
            .frame_addr => @panic("TODO implement frame_addr"),
            .call => @panic("TODO implement call"),
            .call_always_tail => @panic("TODO implement call_always_tail"),
            .call_never_tail => @panic("TODO implement call_never_tail"),
            .call_never_inline => @panic("TODO implement call_never_inline"),
            .clz => @panic("TODO implement clz"),
            .ctz => @panic("TODO implement ctz"),
            .popcount => @panic("TODO implement popcount"),
            .byte_swap => @panic("TODO implement byte_swap"),
            .bit_reverse => @panic("TODO implement bit_reverse"),
            .sqrt => @panic("TODO implement sqrt"),
            .sin => @panic("TODO implement sin"),
            .cos => @panic("TODO implement cos"),
            .exp => @panic("TODO implement exp"),
            .exp2 => @panic("TODO implement exp2"),
            .log => @panic("TODO implement log"),
            .log2 => @panic("TODO implement log2"),
            .log10 => @panic("TODO implement log10"),
            .fabs => @panic("TODO implement fabs"),
            .floor => @panic("TODO implement floor"),
            .ceil => @panic("TODO implement ceil"),
            .round => @panic("TODO implement round"),
            .trunc_float => @panic("TODO implement trunc_float"),
            .cmp_lt => @panic("TODO implement cmp_lt"),
            .cmp_lte => @panic("TODO implement cmp_lte"),
            .cmp_eq => @panic("TODO implement cmp_eq"),
            .cmp_gte => @panic("TODO implement cmp_gte"),
            .cmp_gt => @panic("TODO implement cmp_gt"),
            .cmp_neq => @panic("TODO implement cmp_neq"),
            .cmp_vector => @panic("TODO implement cmp_vector"),
            .cond_br => @panic("TODO implement cond_br"),
            .switch_br => @panic("TODO implement switch_br"),
            .constant => @panic("TODO implement constant"),
            .const_ty => @panic("TODO implement const_ty"),
            .dbg_stmt => @panic("TODO implement dbg_stmt"),
            .dbg_block_begin => @panic("TODO implement dbg_block_begin"),
            .dbg_block_end => @panic("TODO implement dbg_block_end"),
            .dbg_inline_begin => @panic("TODO implement dbg_inline_begin"),
            .dbg_inline_end => @panic("TODO implement dbg_inline_end"),
            .dbg_var_ptr => @panic("TODO implement dbg_var_ptr"),
            .dbg_var_val => @panic("TODO implement dbg_var_val"),
            .is_null => @panic("TODO implement is_null"),
            .is_non_null => @panic("TODO implement is_non_null"),
            .is_null_ptr => @panic("TODO implement is_null_ptr"),
            .is_non_null_ptr => @panic("TODO implement is_non_null_ptr"),
            .is_err => @panic("TODO implement is_err"),
            .is_non_err => @panic("TODO implement is_non_err"),
            .is_err_ptr => @panic("TODO implement is_err_ptr"),
            .is_non_err_ptr => @panic("TODO implement is_non_err_ptr"),
            .bool_and => @panic("TODO implement bool_and"),
            .bool_or => @panic("TODO implement bool_or"),
            .load => @panic("TODO implement load"),
            .ptrtoint => @panic("TODO implement ptrtoint"),
            .bool_to_int => @panic("TODO implement bool_to_int"),
            .ret => @panic("TODO implement ret"),
            .ret_load => @panic("TODO implement ret_load"),
            .store => @panic("TODO implement store"),
            .unreach => @panic("TODO implement unreach"),
            .fptrunc => @panic("TODO implement fptrunc"),
            .fpext => @panic("TODO implement fpext"),
            .intcast => @panic("TODO implement intcast"),
            .trunc => @panic("TODO implement trunc"),
            .optional_payload => @panic("TODO implement optional_payload"),
            .optional_payload_ptr => @panic("TODO implement optional_payload_ptr"),
            .optional_payload_ptr_set => @panic("TODO implement optional_payload_ptr_set"),
            .wrap_optional => @panic("TODO implement wrap_optional"),
            .unwrap_errunion_payload => @panic("TODO implement unwrap_errunion_payload"),
            .unwrap_errunion_err => @panic("TODO implement unwrap_errunion_err"),
            .unwrap_errunion_payload_ptr => @panic("TODO implement unwrap_errunion_payload_ptr"),
            .unwrap_errunion_err_ptr => @panic("TODO implement unwrap_errunion_err_ptr"),
            .errunion_payload_ptr_set => @panic("TODO implement errunion_payload_ptr_set"),
            .wrap_errunion_payload => @panic("TODO implement wrap_errunion_payload"),
            .wrap_errunion_err => @panic("TODO implement wrap_errunion_err"),
            .struct_field_ptr => @panic("TODO implement struct_field_ptr"),
            .struct_field_ptr_index_0 => @panic("TODO implement struct_field_ptr_index_0"),
            .struct_field_ptr_index_1 => @panic("TODO implement struct_field_ptr_index_1"),
            .struct_field_ptr_index_2 => @panic("TODO implement struct_field_ptr_index_2"),
            .struct_field_ptr_index_3 => @panic("TODO implement struct_field_ptr_index_3"),
            .struct_field_val => @panic("TODO implement struct_field_val"),
            .set_union_tag => @panic("TODO implement set_union_tag"),
            .get_union_tag => @panic("TODO implement get_union_tag"),
            .slice => @panic("TODO implement slice"),
            .slice_len => @panic("TODO implement slice_len"),
            .slice_ptr => @panic("TODO implement slice_ptr"),
            .ptr_slice_len_ptr => @panic("TODO implement ptr_slice_len_ptr"),
            .ptr_slice_ptr_ptr => @panic("TODO implement ptr_slice_ptr_ptr"),
            .array_elem_val => @panic("TODO implement array_elem_val"),
            .slice_elem_val => @panic("TODO implement slice_elem_val"),
            .slice_elem_ptr => @panic("TODO implement slice_elem_ptr"),
            .ptr_elem_val => @panic("TODO implement ptr_elem_val"),
            .ptr_elem_ptr => @panic("TODO implement ptr_elem_ptr"),
            .array_to_slice => @panic("TODO implement array_to_slice"),
            .float_to_int => @panic("TODO implement float_to_int"),
            .int_to_float => @panic("TODO implement int_to_float"),
            .reduce => @panic("TODO implement reduce"),
            .splat => @panic("TODO implement splat"),
            .shuffle => @panic("TODO implement shuffle"),
            .select => @panic("TODO implement select"),
            .memset => @panic("TODO implement memset"),
            .memcpy => @panic("TODO implement memcpy"),
            .cmpxchg_weak => @panic("TODO implement cmpxchg_weak"),
            .cmpxchg_strong => @panic("TODO implement cmpxchg_strong"),
            .fence => @panic("TODO implement fence"),
            .atomic_load => @panic("TODO implement atomic_load"),
            .atomic_store_unordered => @panic("TODO implement atomic_store_unordered"),
            .atomic_store_monotonic => @panic("TODO implement atomic_store_monotonic"),
            .atomic_store_release => @panic("TODO implement atomic_store_release"),
            .atomic_store_seq_cst => @panic("TODO implement atomic_store_seq_cst"),
            .atomic_rmw => @panic("TODO implement atomic_rmw"),
            .tag_name => @panic("TODO implement tag_name"),
            .error_name => @panic("TODO implement error_name"),
            .aggregate_init => @panic("TODO implement aggregate_init"),
            .union_init => @panic("TODO implement union_init"),
            .prefetch => @panic("TODO implement prefetch"),
            .mul_add => @panic("TODO implement mul_add"),
            .field_parent_ptr => @panic("TODO implement field_parent_ptr"),

            .wasm_memory_size, .wasm_memory_grow => unreachable,
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
