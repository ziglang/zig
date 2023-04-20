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
const CodeGenError = codegen.CodeGenError;
const Compilation = @import("../../Compilation.zig");
const DebugInfoOutput = codegen.DebugInfoOutput;
const DW = std.dwarf;
const ErrorMsg = Module.ErrorMsg;
const Result = codegen.Result;
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Lower = @import("Lower.zig");
const Mir = @import("Mir.zig");
const Module = @import("../../Module.zig");
const Target = std.Target;
const Type = @import("../../type.zig").Type;
const TypedValue = @import("../../TypedValue.zig");
const Value = @import("../../value.zig").Value;

const abi = @import("abi.zig");
const bits = @import("bits.zig");
const encoder = @import("encoder.zig");
const errUnionErrorOffset = codegen.errUnionErrorOffset;
const errUnionPayloadOffset = codegen.errUnionPayloadOffset;

const Condition = bits.Condition;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;

const gp = abi.RegisterClass.gp;
const sse = abi.RegisterClass.sse;

const InnerError = CodeGenError || error{OutOfRegisters};

const debug_wip_mir = false;

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
    /// The value is in memory.
    /// Payload is a symbol index.
    load_direct: u32,
    /// The value is a pointer to value in memory.
    /// Payload is a symbol index.
    lea_direct: u32,
    /// The value is in memory referenced indirectly via GOT.
    /// Payload is a symbol index.
    load_got: u32,
    /// The value is a threadlocal variable.
    /// Payload is a symbol index.
    load_tlv: u32,
    /// The value is a pointer to threadlocal variable.
    /// Payload is a symbol index.
    lea_tlv: u32,
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
            .load_direct,
            .lea_direct,
            .load_got,
            .load_tlv,
            .lea_tlv,
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

    const FormatContext = struct {
        insts: []const Air.Inst.Index,
        mcvs: []const MCValue,
    };

    fn fmt(
        ctx: FormatContext,
        comptime unused_format_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        comptime assert(unused_format_string.len == 0);
        try writer.writeAll("Branch {\n");
        for (ctx.insts, ctx.mcvs) |inst, mcv| {
            try writer.print("  %{d} => {}\n", .{ inst, mcv });
        }
        try writer.writeAll("}");
    }

    fn format(branch: Branch, comptime unused_format_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = branch;
        _ = unused_format_string;
        _ = options;
        _ = writer;
        @compileError("do not format Branch directly; use ty.fmtDebug()");
    }

    fn fmtDebug(self: @This()) std.fmt.Formatter(fmt) {
        return .{ .data = .{
            .insts = self.inst_table.keys(),
            .mcvs = self.inst_table.values(),
        } };
    }
};

const StackAllocation = struct {
    inst: ?Air.Inst.Index,
    /// TODO do we need size? should be determined by inst.ty.abiSize(self.target.*)
    size: u32,
};

const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .{},
    branch: Branch = .{},
    branch_depth: u32,

    fn deinit(self: *BlockData, gpa: Allocator) void {
        self.branch.deinit(gpa);
        self.relocs.deinit(gpa);
        self.* = undefined;
    }
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
            log.debug("  (saving %{d} => {})", .{ bt.inst, result });
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
) CodeGenError!Result {
    if (build_options.skip_non_native and builtin.cpu.arch != bin_file.options.target.cpu.arch) {
        @panic("Attempted to compile for architecture that was disabled by build configuration");
    }

    const mod = bin_file.options.module.?;
    const fn_owner_decl = mod.declPtr(module_fn.owner_decl);
    assert(fn_owner_decl.has_tv);
    const fn_type = fn_owner_decl.ty;

    if (debug_wip_mir) {
        const stderr = std.io.getStdErr().writer();
        fn_owner_decl.renderFullyQualifiedName(mod, stderr) catch {};
        stderr.writeAll(":\n") catch {};
    }

    var branch_stack = std.ArrayList(Branch).init(bin_file.allocator);
    try branch_stack.ensureUnusedCapacity(2);
    // The outermost branch is used for constants only.
    branch_stack.appendAssumeCapacity(.{});
    branch_stack.appendAssumeCapacity(.{});
    defer {
        assert(branch_stack.items.len == 2);
        for (branch_stack.items) |*branch| branch.deinit(bin_file.allocator);
        branch_stack.deinit();
    }

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

    var call_info = function.resolveCallingConventionValues(fn_type, &.{}) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(
                bin_file.allocator,
                src_loc,
                "CodeGen ran out of registers. This is a bug in the Zig compiler.",
                .{},
            ),
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
            .fail = try ErrorMsg.create(bin_file.allocator, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(bin_file.allocator),
    };
    defer mir.deinit(bin_file.allocator);

    var emit = Emit{
        .lower = .{
            .allocator = bin_file.allocator,
            .mir = mir,
            .target = &bin_file.options.target,
            .src_loc = src_loc,
        },
        .bin_file = bin_file,
        .debug_output = debug_output,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = module_fn.lbrace_line,
        .prev_di_column = module_fn.lbrace_column,
    };
    defer emit.deinit();
    emit.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return Result{ .fail = emit.lower.err_msg.? },
        error.InvalidInstruction, error.CannotEncode => |e| {
            const msg = switch (e) {
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
                error.CannotEncode => "CodeGen failed to encode the instruction.",
            };
            return Result{
                .fail = try ErrorMsg.create(
                    bin_file.allocator,
                    src_loc,
                    "{s} This is a bug in the Zig compiler.",
                    .{msg},
                ),
            };
        },
        else => |e| return e,
    };

    if (function.err_msg) |em| {
        return Result{ .fail = em };
    } else {
        return Result.ok;
    }
}

fn dumpWipMir(self: *Self, inst: Mir.Inst) !void {
    if (!debug_wip_mir) return;
    const stderr = std.io.getStdErr().writer();

    var lower = Lower{
        .allocator = self.gpa,
        .mir = .{
            .instructions = self.mir_instructions.slice(),
            .extra = self.mir_extra.items,
        },
        .target = self.target,
        .src_loc = self.src_loc,
    };
    for (lower.lowerMir(inst) catch |err| switch (err) {
        error.LowerFail => {
            defer {
                lower.err_msg.?.deinit(self.gpa);
                lower.err_msg = null;
            }
            try stderr.print("{s}\n", .{lower.err_msg.?.msg});
            return;
        },
        error.InvalidInstruction, error.CannotEncode => |e| {
            try stderr.writeAll(switch (e) {
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.\n",
                error.CannotEncode => "CodeGen failed to encode the instruction.\n",
            });
            return;
        },
        else => |e| return e,
    }) |lower_inst| {
        try stderr.print("  | {}\n", .{lower_inst});
    }
}

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;
    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index = @intCast(Mir.Inst.Index, self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    self.dumpWipMir(inst) catch {};
    return result_index;
}

fn addExtra(self: *Self, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try self.mir_extra.ensureUnusedCapacity(self.gpa, fields.len);
    return self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Self, extra: anytype) u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    const result = @intCast(u32, self.mir_extra.items.len);
    inline for (fields) |field| {
        self.mir_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            i32 => @bitCast(u32, @field(extra, field.name)),
            else => @compileError("bad field type: " ++ field.name ++ ": " ++ @typeName(field.type)),
        });
    }
    return result;
}

fn asmSetccRegister(self: *Self, reg: Register, cc: bits.Condition) !void {
    _ = try self.addInst(.{
        .tag = .setcc,
        .ops = .r_cc,
        .data = .{ .r_cc = .{ .r = reg, .cc = cc } },
    });
}

fn asmSetccMemory(self: *Self, m: Memory, cc: bits.Condition) !void {
    _ = try self.addInst(.{
        .tag = .setcc,
        .ops = switch (m) {
            .sib => .m_sib_cc,
            .rip => .m_rip_cc,
            else => unreachable,
        },
        .data = .{ .x_cc = .{ .cc = cc, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmCmovccRegisterRegister(self: *Self, reg1: Register, reg2: Register, cc: bits.Condition) !void {
    _ = try self.addInst(.{
        .tag = .cmovcc,
        .ops = .rr_cc,
        .data = .{ .rr_cc = .{ .r1 = reg1, .r2 = reg2, .cc = cc } },
    });
}

fn asmCmovccRegisterMemory(self: *Self, reg: Register, m: Memory, cc: bits.Condition) !void {
    _ = try self.addInst(.{
        .tag = .cmovcc,
        .ops = switch (m) {
            .sib => .rm_sib_cc,
            .rip => .rm_rip_cc,
            else => unreachable,
        },
        .data = .{ .rx_cc = .{ .r = reg, .cc = cc, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmJmpReloc(self: *Self, target: Mir.Inst.Index) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .jmp_reloc,
        .ops = undefined,
        .data = .{ .inst = target },
    });
}

fn asmJccReloc(self: *Self, target: Mir.Inst.Index, cc: bits.Condition) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .jcc,
        .ops = .inst_cc,
        .data = .{ .inst_cc = .{ .inst = target, .cc = cc } },
    });
}

fn asmOpOnly(self: *Self, tag: Mir.Inst.Tag) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = .none,
        .data = undefined,
    });
}

fn asmRegister(self: *Self, tag: Mir.Inst.Tag, reg: Register) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = .r,
        .data = .{ .r = reg },
    });
}

fn asmImmediate(self: *Self, tag: Mir.Inst.Tag, imm: Immediate) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (imm) {
            .signed => .i_s,
            .unsigned => .i_u,
        },
        .data = .{ .i = switch (imm) {
            .signed => |s| @bitCast(u32, s),
            .unsigned => |u| @intCast(u32, u),
        } },
    });
}

fn asmRegisterRegister(self: *Self, tag: Mir.Inst.Tag, reg1: Register, reg2: Register) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = .rr,
        .data = .{ .rr = .{ .r1 = reg1, .r2 = reg2 } },
    });
}

fn asmRegisterImmediate(self: *Self, tag: Mir.Inst.Tag, reg: Register, imm: Immediate) !void {
    const ops: Mir.Inst.Ops = switch (imm) {
        .signed => .ri_s,
        .unsigned => |u| if (math.cast(u32, u)) |_| .ri_u else .ri64,
    };
    _ = try self.addInst(.{
        .tag = tag,
        .ops = ops,
        .data = switch (ops) {
            .ri_s, .ri_u => .{ .ri = .{ .r = reg, .i = switch (imm) {
                .signed => |s| @bitCast(u32, s),
                .unsigned => |u| @intCast(u32, u),
            } } },
            .ri64 => .{ .rx = .{
                .r = reg,
                .payload = try self.addExtra(Mir.Imm64.encode(imm.unsigned)),
            } },
            else => unreachable,
        },
    });
}

fn asmRegisterRegisterRegister(
    self: *Self,
    tag: Mir.Inst.Tag,
    reg1: Register,
    reg2: Register,
    reg3: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = .rrr,
        .data = .{ .rrr = .{ .r1 = reg1, .r2 = reg2, .r3 = reg3 } },
    });
}

fn asmRegisterRegisterImmediate(
    self: *Self,
    tag: Mir.Inst.Tag,
    reg1: Register,
    reg2: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (imm) {
            .signed => .rri_s,
            .unsigned => .rri_u,
        },
        .data = .{ .rri = .{ .r1 = reg1, .r2 = reg2, .i = switch (imm) {
            .signed => |s| @bitCast(u32, s),
            .unsigned => |u| @intCast(u32, u),
        } } },
    });
}

fn asmMemory(self: *Self, tag: Mir.Inst.Tag, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .m_sib,
            .rip => .m_rip,
            else => unreachable,
        },
        .data = .{ .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } },
    });
}

fn asmRegisterMemory(self: *Self, tag: Mir.Inst.Tag, reg: Register, m: Memory) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .rm_sib,
            .rip => .rm_rip,
            else => unreachable,
        },
        .data = .{ .rx = .{ .r = reg, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmMemoryRegister(self: *Self, tag: Mir.Inst.Tag, m: Memory, reg: Register) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .mr_sib,
            .rip => .mr_rip,
            else => unreachable,
        },
        .data = .{ .rx = .{ .r = reg, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmMemoryImmediate(self: *Self, tag: Mir.Inst.Tag, m: Memory, imm: Immediate) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => switch (imm) {
                .signed => .mi_sib_s,
                .unsigned => .mi_sib_u,
            },
            .rip => switch (imm) {
                .signed => .mi_rip_s,
                .unsigned => .mi_rip_u,
            },
            else => unreachable,
        },
        .data = .{ .ix = .{ .i = switch (imm) {
            .signed => |s| @bitCast(u32, s),
            .unsigned => |u| @intCast(u32, u),
        }, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmMemoryRegisterRegister(
    self: *Self,
    tag: Mir.Inst.Tag,
    m: Memory,
    reg1: Register,
    reg2: Register,
) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .mrr_sib,
            .rip => .mrr_rip,
            else => unreachable,
        },
        .data = .{ .rrx = .{ .r1 = reg1, .r2 = reg2, .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn asmMemoryRegisterImmediate(
    self: *Self,
    tag: Mir.Inst.Tag,
    m: Memory,
    reg: Register,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .mri_sib,
            .rip => .mri_rip,
            else => unreachable,
        },
        .data = .{ .rix = .{ .r = reg, .i = @intCast(u8, imm.unsigned), .payload = switch (m) {
            .sib => try self.addExtra(Mir.MemorySib.encode(m)),
            .rip => try self.addExtra(Mir.MemoryRip.encode(m)),
            else => unreachable,
        } } },
    });
}

fn gen(self: *Self) InnerError!void {
    const cc = self.fn_type.fnCallingConvention();
    if (cc != .Naked) {
        try self.asmRegister(.push, .rbp);
        try self.asmRegisterRegister(.mov, .rbp, .rsp);

        // We want to subtract the aligned stack frame size from rsp here, but we don't
        // yet know how big it will be, so we leave room for a 4-byte stack size.
        // TODO During semantic analysis, check if there are no function calls. If there
        // are none, here we can omit the part where we subtract and then add rsp.
        const backpatch_stack_sub = try self.addInst(.{
            .tag = .dead,
            .ops = undefined,
            .data = undefined,
        });

        if (self.ret_mcv == .stack_offset) {
            // The address where to store the return value for the caller is in a
            // register which the callee is free to clobber. Therefore, we purposely
            // spill it to stack immediately.
            const stack_offset = mem.alignForwardGeneric(u32, self.next_stack_offset + 8, 8);
            self.next_stack_offset = stack_offset;
            self.max_end_stack = @max(self.max_end_stack, self.next_stack_offset);

            const ret_reg = abi.getCAbiIntParamRegs(self.target.*)[0];
            try self.genSetStack(Type.usize, @intCast(i32, stack_offset), MCValue{ .register = ret_reg }, .{});
            self.ret_mcv = MCValue{ .stack_offset = @intCast(i32, stack_offset) };
            log.debug("gen: spilling {s} to stack at offset {}", .{ @tagName(ret_reg), stack_offset });
        }

        _ = try self.addInst(.{
            .tag = .dbg_prologue_end,
            .ops = undefined,
            .data = undefined,
        });

        // Push callee-preserved regs that were used actually in use.
        const backpatch_push_callee_preserved_regs = try self.addInst(.{
            .tag = .dead,
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
        var reg_list = Mir.RegisterList{};
        const callee_preserved_regs = abi.getCalleePreservedRegs(self.target.*);
        for (callee_preserved_regs) |reg| {
            if (self.register_manager.isRegAllocated(reg)) {
                reg_list.push(callee_preserved_regs, reg);
            }
        }
        const saved_regs_stack_space: u32 = reg_list.count() * 8;

        // Pop saved callee-preserved regs.
        const backpatch_pop_callee_preserved_regs = try self.addInst(.{
            .tag = .dead,
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
            .tag = .dead,
            .ops = undefined,
            .data = undefined,
        });

        try self.asmRegister(.pop, .rbp);
        try self.asmOpOnly(.ret);

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
                .ops = .ri_u,
                .data = .{ .ri = .{ .r = .rsp, .i = aligned_stack_end } },
            });
            self.mir_instructions.set(backpatch_stack_add, .{
                .tag = .add,
                .ops = .ri_u,
                .data = .{ .ri = .{ .r = .rsp, .i = aligned_stack_end } },
            });

            const save_reg_list = try self.addExtra(Mir.SaveRegisterList{
                .base_reg = @enumToInt(Register.rbp),
                .register_list = reg_list.asInt(),
                .stack_end = aligned_stack_end,
            });
            self.mir_instructions.set(backpatch_push_callee_preserved_regs, .{
                .tag = .push_regs,
                .ops = undefined,
                .data = .{ .payload = save_reg_list },
            });
            self.mir_instructions.set(backpatch_pop_callee_preserved_regs, .{
                .tag = .pop_regs,
                .ops = undefined,
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
            try self.mir_to_air_map.put(@intCast(Mir.Inst.Index, self.mir_instructions.len), inst);
        }
        if (debug_wip_mir) @import("../../print_air.zig").dumpInst(
            inst,
            self.bin_file.options.module.?,
            self.air,
            self.liveness,
        );

        switch (air_tags[inst]) {
            // zig fmt: off
            .not,
            => |tag| try self.airUnOp(inst, tag),

            .add,
            .addwrap,
            .sub,
            .subwrap,
            .bool_and,
            .bool_or,
            .bit_and,
            .bit_or,
            .xor,
            .min,
            .max,
            => |tag| try self.airBinOp(inst, tag),

            .ptr_add, .ptr_sub => |tag| try self.airPtrArithmetic(inst, tag),

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

            .add_with_overflow => try self.airAddSubWithOverflow(inst),
            .sub_with_overflow => try self.airAddSubWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

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
            .trap            => try self.airTrap(),
            .breakpoint      => try self.airBreakpoint(),
            .ret_addr        => try self.airRetAddr(inst),
            .frame_addr      => try self.airFrameAddress(inst),
            .fence           => try self.airFence(inst),
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
            .addrspace_cast  => return self.fail("TODO implement addrspace_cast", .{}),

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
            .unreach  => if (self.wantSafety()) try self.airTrap() else self.finishAirBookkeeping(),

            .optional_payload           => try self.airOptionalPayload(inst),
            .optional_payload_ptr       => try self.airOptionalPayloadPtr(inst),
            .optional_payload_ptr_set   => try self.airOptionalPayloadPtrSet(inst),
            .unwrap_errunion_err        => try self.airUnwrapErrUnionErr(inst),
            .unwrap_errunion_payload    => try self.airUnwrapErrUnionPayload(inst),
            .unwrap_errunion_err_ptr    => try self.airUnwrapErrUnionErrPtr(inst),
            .unwrap_errunion_payload_ptr=> try self.airUnwrapErrUnionPayloadPtr(inst),
            .errunion_payload_ptr_set   => try self.airErrUnionPayloadPtrSet(inst),
            .err_return_trace           => try self.airErrReturnTrace(inst),
            .set_err_return_trace       => try self.airSetErrReturnTrace(inst),
            .save_err_return_trace_index=> try self.airSaveErrReturnTraceIndex(inst),

            .wrap_optional         => try self.airWrapOptional(inst),
            .wrap_errunion_payload => try self.airWrapErrUnionPayload(inst),
            .wrap_errunion_err     => try self.airWrapErrUnionErr(inst),

            .add_optimized,
            .addwrap_optimized,
            .sub_optimized,
            .subwrap_optimized,
            .mul_optimized,
            .mulwrap_optimized,
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
            .float_to_int_optimized,
            => return self.fail("TODO implement optimized float mode", .{}),

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
                std.debug.panic("in codegen.zig, handling of AIR instruction %{d} ('{}') did not do proper bookkeeping. Look for a missing call to finishAir.", .{ inst, air_tags[inst] });
            }

            { // check consistency of tracked registers
                var it = self.register_manager.free_registers.iterator(.{ .kind = .unset });
                while (it.next()) |index| {
                    const tracked_inst = self.register_manager.registers[index];
                    const tracked_mcv = self.getResolvedInstValue(tracked_inst).?.*;
                    assert(RegisterManager.indexOfRegIntoTracked(switch (tracked_mcv) {
                        .register => |reg| reg,
                        .register_overflow => |ro| ro.reg,
                        else => unreachable,
                    }).? == index);
                }
            }
        }
    }
}

fn getValue(self: *Self, value: MCValue, inst: ?Air.Inst.Index) void {
    const reg = switch (value) {
        .register => |reg| reg,
        .register_overflow => |ro| ro.reg,
        else => return,
    };
    if (self.register_manager.isRegFree(reg)) {
        self.register_manager.getRegAssumeFree(reg, inst);
    }
}

fn freeValue(self: *Self, value: MCValue) void {
    switch (value) {
        .register => |reg| {
            self.register_manager.freeReg(reg);
        },
        .register_overflow => |ro| {
            self.register_manager.freeReg(ro.reg);
            self.eflags_inst = null;
        },
        .eflags => {
            self.eflags_inst = null;
        },
        else => {}, // TODO process stack allocation death
    }
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) void {
    const air_tags = self.air.instructions.items(.tag);
    if (air_tags[inst] == .constant) return; // Constants are immortal.
    const prev_value = (self.getResolvedInstValue(inst) orelse return).*;
    log.debug("%{d} => {}", .{ inst, MCValue.dead });
    // When editing this function, note that the logic must synchronize with `reuseOperand`.
    const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
    branch.inst_table.putAssumeCapacity(inst, .dead);
    self.freeValue(prev_value);
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
        // In some cases, an operand may be reused as the result.
        // If that operand died and was a register, it was freed by
        // processDeath, so we have to "re-allocate" the register.
        self.getValue(result, inst);
    } else switch (result) {
        .none, .dead, .unreach => {},
        else => unreachable, // Why didn't the result die?
    }
    self.finishAirBookkeeping();
}

fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
    // In addition to the caller's needs, we need enough space to spill every register and eflags.
    const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
    try table.ensureUnusedCapacity(self.gpa, additional_count + self.register_manager.registers.len + 1);
}

fn allocMem(self: *Self, inst: ?Air.Inst.Index, abi_size: u32, abi_align: u32) !u32 {
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;
    // TODO find a free slot instead of always appending
    const offset = mem.alignForwardGeneric(u32, self.next_stack_offset + abi_size, abi_align);
    self.next_stack_offset = offset;
    self.max_end_stack = @max(self.max_end_stack, self.next_stack_offset);
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
    return self.allocRegOrMemAdvanced(self.air.typeOfIndex(inst), inst, reg_ok);
}

fn allocTempRegOrMem(self: *Self, elem_ty: Type, reg_ok: bool) !MCValue {
    return self.allocRegOrMemAdvanced(elem_ty, null, reg_ok);
}

fn allocRegOrMemAdvanced(self: *Self, elem_ty: Type, inst: ?Air.Inst.Index, reg_ok: bool) !MCValue {
    const abi_size = math.cast(u32, elem_ty.abiSize(self.target.*)) orelse {
        const mod = self.bin_file.options.module.?;
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(mod)});
    };

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

    const abi_align = elem_ty.abiAlignment(self.target.*);
    if (abi_align > self.stack_align)
        self.stack_align = abi_align;
    const stack_offset = try self.allocMem(inst, abi_size, abi_align);
    return MCValue{ .stack_offset = @intCast(i32, stack_offset) };
}

const State = struct {
    registers: abi.RegisterManager.TrackedRegisters,
    free_registers: abi.RegisterManager.RegisterBitSet,
    eflags_inst: ?Air.Inst.Index,
};

fn captureState(self: *Self) State {
    return State{
        .registers = self.register_manager.registers,
        .free_registers = self.register_manager.free_registers,
        .eflags_inst = self.eflags_inst,
    };
}

fn revertState(self: *Self, state: State) void {
    self.eflags_inst = state.eflags_inst;
    self.register_manager.free_registers = state.free_registers;
    self.register_manager.registers = state.registers;
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const stack_mcv = try self.allocRegOrMem(inst, false);
    log.debug("spilling %{d} to stack mcv {any}", .{ inst, stack_mcv });
    const reg_mcv = self.getResolvedInstValue(inst).?.*;
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
    branch.inst_table.putAssumeCapacity(inst, stack_mcv);
    try self.genSetStack(self.air.typeOfIndex(inst), stack_mcv.stack_offset, reg_mcv, .{});
}

pub fn spillEflagsIfOccupied(self: *Self) !void {
    if (self.eflags_inst) |inst_to_save| {
        const mcv = self.getResolvedInstValue(inst_to_save).?.*;
        const new_mcv = switch (mcv) {
            .register_overflow => try self.allocRegOrMem(inst_to_save, false),
            .eflags => try self.allocRegOrMem(inst_to_save, true),
            else => unreachable,
        };

        try self.setRegOrMem(self.air.typeOfIndex(inst_to_save), new_mcv, mcv);
        log.debug("spilling %{d} to mcv {any}", .{ inst_to_save, new_mcv });

        const branch = &self.branch_stack.items[self.branch_stack.items.len - 1];
        branch.inst_table.putAssumeCapacity(inst_to_save, new_mcv);

        self.eflags_inst = null;

        // TODO consolidate with register manager and spillInstruction
        // this call should really belong in the register manager!
        switch (mcv) {
            .register_overflow => |ro| self.register_manager.freeReg(ro.reg),
            else => {},
        }
    }
}

pub fn spillRegisters(self: *Self, registers: []const Register) !void {
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
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const stack_offset = try self.allocMemPtr(inst);
        break :result .{ .ptr_stack_offset = @intCast(i32, stack_offset) };
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const stack_offset = try self.allocMemPtr(inst);
        break :result .{ .ptr_stack_offset = @intCast(i32, stack_offset) };
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
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
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const src_ty = self.air.typeOf(ty_op.operand);
        const src_int_info = src_ty.intInfo(self.target.*);
        const src_abi_size = @intCast(u32, src_ty.abiSize(self.target.*));
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_lock = switch (src_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_ty = self.air.typeOfIndex(inst);
        const dst_int_info = dst_ty.intInfo(self.target.*);
        const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
        const dst_mcv = if (dst_abi_size <= src_abi_size and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.allocRegOrMem(inst, true);

        const min_ty = if (dst_int_info.bits < src_int_info.bits) dst_ty else src_ty;
        const signedness: std.builtin.Signedness = if (dst_int_info.signedness == .signed and
            src_int_info.signedness == .signed) .signed else .unsigned;
        switch (dst_mcv) {
            .register => |dst_reg| {
                const min_abi_size = @min(dst_abi_size, src_abi_size);
                const tag: Mir.Inst.Tag = switch (signedness) {
                    .signed => .movsx,
                    .unsigned => if (min_abi_size > 2) .mov else .movzx,
                };
                const dst_alias = switch (tag) {
                    .movsx => dst_reg.to64(),
                    .mov, .movzx => if (min_abi_size > 4) dst_reg.to64() else dst_reg.to32(),
                    else => unreachable,
                };
                switch (src_mcv) {
                    .register => |src_reg| {
                        try self.asmRegisterRegister(
                            tag,
                            dst_alias,
                            registerAlias(src_reg, min_abi_size),
                        );
                    },
                    .stack_offset => |src_off| {
                        try self.asmRegisterMemory(tag, dst_alias, Memory.sib(
                            Memory.PtrSize.fromSize(min_abi_size),
                            .{ .base = .rbp, .disp = -src_off },
                        ));
                    },
                    else => return self.fail("TODO airIntCast from {s} to {s}", .{
                        @tagName(src_mcv),
                        @tagName(dst_mcv),
                    }),
                }
                if (self.regExtraBits(min_ty) > 0) try self.truncateRegister(min_ty, dst_reg);
            },
            else => {
                try self.setRegOrMem(min_ty, dst_mcv, src_mcv);
                const extra = dst_abi_size * 8 - dst_int_info.bits;
                if (extra > 0) {
                    try self.genShiftBinOpMir(switch (signedness) {
                        .signed => .sal,
                        .unsigned => .shl,
                    }, dst_ty, dst_mcv, .{ .immediate = extra });
                    try self.genShiftBinOpMir(switch (signedness) {
                        .signed => .sar,
                        .unsigned => .shr,
                    }, dst_ty, dst_mcv, .{ .immediate = extra });
                }
            },
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const dst_ty = self.air.typeOfIndex(inst);
        const dst_abi_size = dst_ty.abiSize(self.target.*);
        if (dst_abi_size > 8) {
            return self.fail("TODO implement trunc for abi sizes larger than 8", .{});
        }

        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_lock = switch (src_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);

        // when truncating a `u16` to `u5`, for example, those top 3 bits in the result
        // have to be removed. this only happens if the dst if not a power-of-two size.
        if (self.regExtraBits(dst_ty) > 0) try self.truncateRegister(dst_ty, dst_mcv.register.to64());
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
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

fn airUnOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genUnOp(inst, tag, ty_op.operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn activeIntBits(self: *Self, dst_air: Air.Inst.Ref) u16 {
    const air_tag = self.air.instructions.items(.tag);
    const air_data = self.air.instructions.items(.data);

    const dst_ty = self.air.typeOf(dst_air);
    const dst_info = dst_ty.intInfo(self.target.*);
    if (Air.refToIndex(dst_air)) |inst| {
        switch (air_tag[inst]) {
            .constant => {
                const src_val = self.air.values[air_data[inst].ty_pl.payload];
                var space: Value.BigIntSpace = undefined;
                const src_int = src_val.toBigInt(&space, self.target.*);
                return @intCast(u16, src_int.bitCountTwosComp()) +
                    @boolToInt(src_int.positive and dst_info.signedness == .signed);
            },
            .intcast => {
                const src_ty = self.air.typeOf(air_data[inst].ty_op.operand);
                const src_info = src_ty.intInfo(self.target.*);
                return @min(switch (src_info.signedness) {
                    .signed => switch (dst_info.signedness) {
                        .signed => src_info.bits,
                        .unsigned => src_info.bits - 1,
                    },
                    .unsigned => switch (dst_info.signedness) {
                        .signed => src_info.bits + 1,
                        .unsigned => src_info.bits,
                    },
                }, dst_info.bits);
            },
            else => {},
        }
    }
    return dst_info.bits;
}

fn airMulDivBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const tag = self.air.instructions.items(.tag)[inst];
        const dst_ty = self.air.typeOfIndex(inst);
        if (dst_ty.zigTypeTag() == .Float)
            break :result try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);

        const dst_info = dst_ty.intInfo(self.target.*);
        var src_pl = Type.Payload.Bits{ .base = .{ .tag = switch (dst_info.signedness) {
            .signed => .int_signed,
            .unsigned => .int_unsigned,
        } }, .data = switch (tag) {
            else => unreachable,
            .mul, .mulwrap => math.max3(
                self.activeIntBits(bin_op.lhs),
                self.activeIntBits(bin_op.rhs),
                dst_info.bits / 2,
            ),
            .div_trunc, .div_floor, .div_exact, .rem, .mod => dst_info.bits,
        } };
        const src_ty = Type.initPayload(&src_pl.base);

        try self.spillRegisters(&.{ .rax, .rdx });
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        break :result try self.genMulDivBinOp(tag, inst, dst_ty, src_ty, lhs, rhs);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const dst_mcv = if (lhs_mcv.isRegister() and self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
            lhs_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, ty, lhs_mcv);
        const dst_reg = dst_mcv.register;
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const limit_reg = try self.register_manager.allocReg(null, gp);
        const limit_mcv = MCValue{ .register = limit_reg };
        const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
        defer self.register_manager.unlockReg(limit_lock);

        const reg_bits = self.regBitSize(ty);
        const cc: Condition = if (ty.isSignedInt()) cc: {
            try self.genSetReg(ty, limit_reg, dst_mcv);
            try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
            try self.genBinOpMir(.xor, ty, limit_mcv, .{
                .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
            });
            break :cc .o;
        } else cc: {
            try self.genSetReg(ty, limit_reg, .{
                .immediate = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - reg_bits),
            });
            break :cc .c;
        };
        try self.genBinOpMir(.add, ty, dst_mcv, rhs_mcv);

        const cmov_abi_size = @max(@intCast(u32, ty.abiSize(self.target.*)), 2);
        try self.asmCmovccRegisterRegister(
            registerAlias(dst_reg, cmov_abi_size),
            registerAlias(limit_reg, cmov_abi_size),
            cc,
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const dst_mcv = if (lhs_mcv.isRegister() and self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv))
            lhs_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, ty, lhs_mcv);
        const dst_reg = dst_mcv.register;
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const limit_reg = try self.register_manager.allocReg(null, gp);
        const limit_mcv = MCValue{ .register = limit_reg };
        const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
        defer self.register_manager.unlockReg(limit_lock);

        const reg_bits = self.regBitSize(ty);
        const cc: Condition = if (ty.isSignedInt()) cc: {
            try self.genSetReg(ty, limit_reg, dst_mcv);
            try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
            try self.genBinOpMir(.xor, ty, limit_mcv, .{
                .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
            });
            break :cc .o;
        } else cc: {
            try self.genSetReg(ty, limit_reg, .{ .immediate = 0 });
            break :cc .c;
        };
        try self.genBinOpMir(.sub, ty, dst_mcv, rhs_mcv);

        const cmov_abi_size = @max(@intCast(u32, ty.abiSize(self.target.*)), 2);
        try self.asmCmovccRegisterRegister(
            registerAlias(dst_reg, cmov_abi_size),
            registerAlias(limit_reg, cmov_abi_size),
            cc,
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);

        try self.spillRegisters(&.{ .rax, .rdx });
        const reg_locks = self.register_manager.lockRegs(2, .{ .rax, .rdx });
        defer for (reg_locks) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const lhs_lock = switch (lhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const limit_reg = try self.register_manager.allocReg(null, gp);
        const limit_mcv = MCValue{ .register = limit_reg };
        const limit_lock = self.register_manager.lockRegAssumeUnused(limit_reg);
        defer self.register_manager.unlockReg(limit_lock);

        const reg_bits = self.regBitSize(ty);
        const cc: Condition = if (ty.isSignedInt()) cc: {
            try self.genSetReg(ty, limit_reg, lhs_mcv);
            try self.genBinOpMir(.xor, ty, limit_mcv, rhs_mcv);
            try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
            try self.genBinOpMir(.xor, ty, limit_mcv, .{
                .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
            });
            break :cc .o;
        } else cc: {
            try self.genSetReg(ty, limit_reg, .{
                .immediate = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - reg_bits),
            });
            break :cc .c;
        };

        const dst_mcv = try self.genMulDivBinOp(.mul, inst, ty, ty, lhs_mcv, rhs_mcv);
        const cmov_abi_size = @max(@intCast(u32, ty.abiSize(self.target.*)), 2);
        try self.asmCmovccRegisterRegister(
            registerAlias(dst_mcv.register, cmov_abi_size),
            registerAlias(limit_reg, cmov_abi_size),
            cc,
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const tag = self.air.instructions.items(.tag)[inst];
        const ty = self.air.typeOf(bin_op.lhs);
        switch (ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement add/sub with overflow for Vector type", .{}),
            .Int => {
                try self.spillEflagsIfOccupied();

                const partial_mcv = switch (tag) {
                    .add_with_overflow => try self.genBinOp(null, .add, bin_op.lhs, bin_op.rhs),
                    .sub_with_overflow => try self.genBinOp(null, .sub, bin_op.lhs, bin_op.rhs),
                    else => unreachable,
                };
                const int_info = ty.intInfo(self.target.*);
                const cc: Condition = switch (int_info.signedness) {
                    .unsigned => .c,
                    .signed => .o,
                };

                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const abi_size = @intCast(i32, ty.abiSize(self.target.*));
                    const dst_mcv = try self.allocRegOrMem(inst, false);
                    try self.genSetStack(
                        Type.u1,
                        dst_mcv.stack_offset - abi_size,
                        .{ .eflags = cc },
                        .{},
                    );
                    try self.genSetStack(ty, dst_mcv.stack_offset, partial_mcv, .{});
                    break :result dst_mcv;
                }

                const tuple_ty = self.air.typeOfIndex(inst);
                const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
                const tuple_align = tuple_ty.abiAlignment(self.target.*);
                const overflow_bit_offset = @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*));
                const stack_offset = @intCast(i32, try self.allocMem(inst, tuple_size, tuple_align));

                try self.genSetStackTruncatedOverflowCompare(ty, stack_offset, overflow_bit_offset, partial_mcv.register, cc);

                break :result .{ .stack_offset = stack_offset };
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const lhs_ty = self.air.typeOf(bin_op.lhs);
        const rhs_ty = self.air.typeOf(bin_op.rhs);
        switch (lhs_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement shl with overflow for Vector type", .{}),
            .Int => {
                try self.spillEflagsIfOccupied();

                try self.register_manager.getReg(.rcx, null);
                const lhs = try self.resolveInst(bin_op.lhs);
                const rhs = try self.resolveInst(bin_op.rhs);

                const int_info = lhs_ty.intInfo(self.target.*);

                const partial_mcv = try self.genShiftBinOp(.shl, null, lhs, rhs, lhs_ty, rhs_ty);
                const partial_lock = switch (partial_mcv) {
                    .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                    else => null,
                };
                defer if (partial_lock) |lock| self.register_manager.unlockReg(lock);

                const tmp_mcv = try self.genShiftBinOp(.shr, null, partial_mcv, rhs, lhs_ty, rhs_ty);
                const tmp_lock = switch (tmp_mcv) {
                    .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                    else => null,
                };
                defer if (tmp_lock) |lock| self.register_manager.unlockReg(lock);

                try self.genBinOpMir(.cmp, lhs_ty, tmp_mcv, lhs);
                const cc = Condition.ne;

                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const abi_size = @intCast(i32, lhs_ty.abiSize(self.target.*));
                    const dst_mcv = try self.allocRegOrMem(inst, false);
                    try self.genSetStack(
                        Type.u1,
                        dst_mcv.stack_offset - abi_size,
                        .{ .eflags = cc },
                        .{},
                    );
                    try self.genSetStack(lhs_ty, dst_mcv.stack_offset, partial_mcv, .{});
                    break :result dst_mcv;
                }

                const tuple_ty = self.air.typeOfIndex(inst);
                const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
                const tuple_align = tuple_ty.abiAlignment(self.target.*);
                const overflow_bit_offset = @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*));
                const stack_offset = @intCast(i32, try self.allocMem(inst, tuple_size, tuple_align));

                try self.genSetStackTruncatedOverflowCompare(lhs_ty, stack_offset, overflow_bit_offset, partial_mcv.register, cc);

                break :result .{ .stack_offset = stack_offset };
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
    cc: Condition,
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
    try self.asmSetccRegister(overflow_reg.to8(), cc);

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
    try self.asmSetccRegister(eq_reg.to8(), .ne);
    try self.genBinOpMir(
        .@"or",
        Type.u8,
        .{ .register = overflow_reg },
        .{ .register = eq_reg },
    );

    try self.genSetStack(ty, stack_offset, .{ .register = scratch_reg }, .{});
    try self.genSetStack(Type.u1, stack_offset - overflow_bit_offset, .{
        .register = overflow_reg.to8(),
    }, .{});
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const dst_ty = self.air.typeOf(bin_op.lhs);
        switch (dst_ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement mul_with_overflow for Vector type", .{}),
            .Int => {
                try self.spillEflagsIfOccupied();

                const dst_info = dst_ty.intInfo(self.target.*);
                const cc: Condition = switch (dst_info.signedness) {
                    .unsigned => .c,
                    .signed => .o,
                };
                if (dst_info.bits >= 8 and math.isPowerOfTwo(dst_info.bits)) {
                    var src_pl = Type.Payload.Bits{ .base = .{ .tag = switch (dst_info.signedness) {
                        .signed => .int_signed,
                        .unsigned => .int_unsigned,
                    } }, .data = math.max3(
                        self.activeIntBits(bin_op.lhs),
                        self.activeIntBits(bin_op.rhs),
                        dst_info.bits / 2,
                    ) };
                    const src_ty = Type.initPayload(&src_pl.base);

                    try self.spillRegisters(&.{ .rax, .rdx });
                    const lhs = try self.resolveInst(bin_op.lhs);
                    const rhs = try self.resolveInst(bin_op.rhs);

                    const partial_mcv = try self.genMulDivBinOp(.mul, null, dst_ty, src_ty, lhs, rhs);
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    // For now, this is the only supported multiply that doesn't fit in a register.
                    assert(dst_info.bits == 128 and src_pl.data == 64);
                    const dst_abi_size = @intCast(i32, dst_ty.abiSize(self.target.*));
                    const dst_mcv = try self.allocRegOrMem(inst, false);
                    try self.genSetStack(
                        Type.u1,
                        dst_mcv.stack_offset - dst_abi_size,
                        .{ .immediate = 0 }, // 64x64 -> 128 never overflows
                        .{},
                    );
                    try self.genSetStack(dst_ty, dst_mcv.stack_offset, partial_mcv, .{});
                    break :result dst_mcv;
                }

                const dst_reg: Register = dst_reg: {
                    switch (dst_info.signedness) {
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
                                break :blk try self.copyToTmpRegister(dst_ty, lhs);
                            };
                            const dst_reg_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
                            defer self.register_manager.unlockReg(dst_reg_lock);

                            const rhs_mcv: MCValue = blk: {
                                if (rhs.isRegister() or rhs.isMemory()) break :blk rhs;
                                break :blk MCValue{ .register = try self.copyToTmpRegister(dst_ty, rhs) };
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
                            try self.spillRegisters(&.{ .rax, .rdx });

                            const lhs = try self.resolveInst(bin_op.lhs);
                            const rhs = try self.resolveInst(bin_op.rhs);

                            const dst_mcv = try self.genMulDivBinOp(.mul, null, dst_ty, dst_ty, lhs, rhs);
                            break :dst_reg dst_mcv.register;
                        },
                    }
                };

                const tuple_ty = self.air.typeOfIndex(inst);
                const tuple_size = @intCast(u32, tuple_ty.abiSize(self.target.*));
                const tuple_align = tuple_ty.abiAlignment(self.target.*);
                const overflow_bit_offset = @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*));
                const stack_offset = @intCast(i32, try self.allocMem(inst, tuple_size, tuple_align));

                try self.genSetStackTruncatedOverflowCompare(dst_ty, stack_offset, overflow_bit_offset, dst_reg, cc);

                break :result .{ .stack_offset = stack_offset };
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

    switch (tag) {
        else => unreachable,
        .mul, .imul => {},
        .div => try self.asmRegisterRegister(.xor, .edx, .edx),
        .idiv => try self.asmOpOnly(.cqo),
    }

    const factor: MCValue = switch (rhs) {
        .register, .stack_offset => rhs,
        else => .{ .register = try self.copyToTmpRegister(ty, rhs) },
    };
    switch (factor) {
        .register => |reg| try self.asmRegister(tag, reg),
        .stack_offset => |off| try self.asmMemory(tag, Memory.sib(
            Memory.PtrSize.fromSize(abi_size),
            .{ .base = .rbp, .disp = -off },
        )),
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
    }, Type.isize, .{ .register = dividend }, .{ .register = divisor });

    try self.asmRegisterRegister(.xor, divisor.to64(), dividend.to64());
    try self.asmRegisterImmediate(.sar, divisor.to64(), Immediate.u(63));
    try self.asmRegisterRegister(.@"test", .rdx, .rdx);
    try self.asmCmovccRegisterRegister(divisor.to64(), .rdx, .e);
    try self.genBinOpMir(.add, Type.isize, .{ .register = divisor }, .{ .register = .rax });
    return MCValue{ .register = divisor };
}

fn airShlShrBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    if (self.liveness.isUnused(inst)) {
        return self.finishAir(inst, .dead, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    try self.spillRegisters(&.{.rcx});

    const tag = self.air.instructions.items(.tag)[inst];
    try self.register_manager.getReg(.rcx, null);
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
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .none;

        const pl_ty = self.air.typeOfIndex(inst);
        const opt_mcv = try self.resolveInst(ty_op.operand);

        if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv)) {
            switch (opt_mcv) {
                .register => |reg| try self.truncateRegister(pl_ty, reg),
                .register_overflow => |ro| try self.truncateRegister(pl_ty, ro.reg),
                else => {},
            }
            break :result opt_mcv;
        }

        const pl_mcv = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(pl_ty, pl_mcv, switch (opt_mcv) {
            else => opt_mcv,
            .register_overflow => |ro| .{ .register = ro.reg },
        });
        break :result pl_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_ty = self.air.typeOfIndex(inst);
        const opt_mcv = try self.resolveInst(ty_op.operand);

        break :result if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
            opt_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
        const dst_ty = self.air.typeOfIndex(inst);
        const src_ty = self.air.typeOf(ty_op.operand);
        const opt_ty = src_ty.childType();
        const src_mcv = try self.resolveInst(ty_op.operand);

        if (opt_ty.optionalReprIsPayload()) {
            break :result if (self.liveness.isUnused(inst))
                .dead
            else if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                src_mcv
            else
                try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
        }

        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);

        const pl_ty = dst_ty.childType();
        const pl_abi_size = @intCast(i32, pl_ty.abiSize(self.target.*));
        try self.asmMemoryImmediate(
            .mov,
            Memory.sib(.byte, .{ .base = dst_mcv.register, .disp = pl_abi_size }),
            Immediate.u(1),
        );
        break :result if (self.liveness.isUnused(inst)) .dead else dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
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
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                const result = try self.copyToRegisterWithInstTracking(inst, err_union_ty, operand);
                if (err_off > 0) {
                    const shift = @intCast(u6, err_off * 8);
                    try self.genShiftBinOpMir(.shr, err_union_ty, result, .{ .immediate = shift });
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

fn airUnwrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
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
        if (!payload_ty.hasRuntimeBitsIgnoreComptime()) break :result .none;

        const payload_off = errUnionPayloadOffset(payload_ty, self.target.*);
        switch (err_union) {
            .stack_offset => |off| {
                const offset = off - @intCast(i32, payload_off);
                break :result MCValue{ .stack_offset = offset };
            },
            .register => |reg| {
                // TODO reuse operand
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                const result_mcv: MCValue = if (maybe_inst) |inst|
                    try self.copyToRegisterWithInstTracking(inst, err_union_ty, err_union)
                else
                    .{ .register = try self.copyToTmpRegister(err_union_ty, err_union) };
                if (payload_off > 0) {
                    const shift = @intCast(u6, payload_off * 8);
                    try self.genShiftBinOpMir(.shr, err_union_ty, result_mcv, .{ .immediate = shift });
                } else {
                    try self.truncateRegister(payload_ty, result_mcv.register);
                }
                break :result result_mcv;
            },
            else => return self.fail("TODO implement genUnwrapErrorUnionPayloadMir for {}", .{err_union}),
        }
    };

    return result;
}

// *(E!T) -> E
fn airUnwrapErrUnionErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = switch (src_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(src_ty, src_mcv),
        };
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const dst_reg = try self.register_manager.allocReg(inst, gp);
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const eu_ty = src_ty.childType();
        const pl_ty = eu_ty.errorUnionPayload();
        const err_ty = eu_ty.errorUnionSet();
        const err_off = @intCast(i32, errUnionErrorOffset(pl_ty, self.target.*));
        const err_abi_size = @intCast(u32, err_ty.abiSize(self.target.*));
        try self.asmRegisterMemory(
            .mov,
            registerAlias(dst_reg, err_abi_size),
            Memory.sib(Memory.PtrSize.fromSize(err_abi_size), .{ .base = src_reg, .disp = err_off }),
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrUnionPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = switch (src_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(src_ty, src_mcv),
        };
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const dst_ty = self.air.typeOfIndex(inst);
        const dst_reg = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_reg
        else
            try self.register_manager.allocReg(inst, gp);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const eu_ty = src_ty.childType();
        const pl_ty = eu_ty.errorUnionPayload();
        const pl_off = @intCast(i32, errUnionPayloadOffset(pl_ty, self.target.*));
        const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
        try self.asmRegisterMemory(
            .lea,
            registerAlias(dst_reg, dst_abi_size),
            Memory.sib(.qword, .{ .base = src_reg, .disp = pl_off }),
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        const src_ty = self.air.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = switch (src_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(src_ty, src_mcv),
        };
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const eu_ty = src_ty.childType();
        const pl_ty = eu_ty.errorUnionPayload();
        const err_ty = eu_ty.errorUnionSet();
        const err_off = @intCast(i32, errUnionErrorOffset(pl_ty, self.target.*));
        const err_abi_size = @intCast(u32, err_ty.abiSize(self.target.*));
        try self.asmMemoryImmediate(
            .mov,
            Memory.sib(Memory.PtrSize.fromSize(err_abi_size), .{ .base = src_reg, .disp = err_off }),
            Immediate.u(0),
        );

        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_ty = self.air.typeOfIndex(inst);
        const dst_reg = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_reg
        else
            try self.register_manager.allocReg(inst, gp);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const pl_off = @intCast(i32, errUnionPayloadOffset(pl_ty, self.target.*));
        const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
        try self.asmRegisterMemory(
            .lea,
            registerAlias(dst_reg, dst_abi_size),
            Memory.sib(.qword, .{ .base = src_reg, .disp = pl_off }),
        );
        break :result .{ .register = dst_reg };
    };
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

fn airWrapOptional(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const pl_ty = self.air.typeOf(ty_op.operand);
        if (!pl_ty.hasRuntimeBits()) break :result .{ .immediate = 1 };

        const opt_ty = self.air.typeOfIndex(inst);
        const pl_mcv = try self.resolveInst(ty_op.operand);
        const same_repr = opt_ty.optionalReprIsPayload();
        if (same_repr and self.reuseOperand(inst, ty_op.operand, 0, pl_mcv)) break :result pl_mcv;

        const pl_lock: ?RegisterLock = switch (pl_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (pl_lock) |lock| self.register_manager.unlockReg(lock);

        const opt_mcv = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(pl_ty, opt_mcv, pl_mcv);

        if (!same_repr) {
            const pl_abi_size = @intCast(i32, pl_ty.abiSize(self.target.*));
            switch (opt_mcv) {
                else => unreachable,

                .register => |opt_reg| try self.asmRegisterImmediate(
                    .bts,
                    opt_reg,
                    Immediate.u(@intCast(u6, pl_abi_size * 8)),
                ),

                .stack_offset => |off| try self.asmMemoryImmediate(
                    .mov,
                    Memory.sib(.byte, .{ .base = .rbp, .disp = pl_abi_size - off }),
                    Immediate.u(1),
                ),
            }
        }
        break :result opt_mcv;
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
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.air.typeOfIndex(inst);
        try self.setRegOrMem(dst_ty, dst_mcv, src_mcv);
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
    log.debug("airSliceLen(%{d}): {}", .{ inst, result });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);
        const src_reg = switch (src_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(src_ty, src_mcv),
        };
        const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
        defer self.register_manager.unlockReg(src_lock);

        const dst_ty = self.air.typeOfIndex(inst);
        const dst_reg = if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_reg
        else
            try self.register_manager.allocReg(inst, gp);
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
        try self.asmRegisterMemory(
            .lea,
            registerAlias(dst_reg, dst_abi_size),
            Memory.sib(.qword, .{
                .base = src_reg,
                .disp = @divExact(self.target.cpu.arch.ptrBitWidth(), 8),
            }),
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_ty = self.air.typeOfIndex(inst);
        const opt_mcv = try self.resolveInst(ty_op.operand);

        break :result if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
            opt_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    };
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
        .stack_offset => |off| try self.asmRegisterMemory(.mov, addr_reg.to64(), Memory.sib(.qword, .{
            .base = .rbp,
            .disp = -off,
        })),
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
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const slice_ty = self.air.typeOf(bin_op.lhs);
    const result = if (!slice_ty.isVolatilePtr() and self.liveness.isUnused(inst)) .dead else result: {
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

    const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
    switch (array) {
        .register => {
            const off = @intCast(i32, try self.allocMem(
                inst,
                @intCast(u32, array_ty.abiSize(self.target.*)),
                array_ty.abiAlignment(self.target.*),
            ));
            try self.genSetStack(array_ty, off, array, .{});
            try self.asmRegisterMemory(.lea, addr_reg, Memory.sib(.qword, .{
                .base = .rbp,
                .disp = -off,
            }));
        },
        .stack_offset => |off| {
            try self.asmRegisterMemory(.lea, addr_reg, Memory.sib(.qword, .{
                .base = .rbp,
                .disp = -off,
            }));
        },
        .load_got => try self.genSetReg(array_ty, addr_reg, array),
        .memory, .load_direct, .load_tlv => try self.genSetReg(Type.usize, addr_reg, switch (array) {
            .memory => |addr| .{ .immediate = addr },
            .load_direct => |sym_index| .{ .lea_direct = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
            else => unreachable,
        }),
        .lea_direct, .lea_tlv => unreachable,
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
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const result = if (!ptr_ty.isVolatilePtr() and self.liveness.isUnused(inst)) .dead else result: {
        // this is identical to the `airPtrElemPtr` codegen expect here an
        // additional `mov` is needed at the end to get the actual value

        const elem_ty = ptr_ty.elemType2();
        const elem_abi_size = @intCast(u32, elem_ty.abiSize(self.target.*));
        const index_ty = self.air.typeOf(bin_op.rhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);
        const index_lock = switch (index_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (index_lock) |lock| self.register_manager.unlockReg(lock);

        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_abi_size);
        const offset_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
        defer self.register_manager.unlockReg(offset_lock);

        const ptr_mcv = try self.resolveInst(bin_op.lhs);
        const elem_ptr_reg = if (ptr_mcv.isRegister() and self.liveness.operandDies(inst, 0))
            ptr_mcv.register
        else
            try self.copyToTmpRegister(ptr_ty, ptr_mcv);
        const elem_ptr_lock = self.register_manager.lockRegAssumeUnused(elem_ptr_reg);
        defer self.register_manager.unlockReg(elem_ptr_lock);
        try self.asmRegisterRegister(.add, elem_ptr_reg, offset_reg);

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_lock = switch (dst_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);
        try self.load(dst_mcv, .{ .register = elem_ptr_reg }, ptr_ty);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const result = if (self.liveness.isUnused(inst)) .dead else result: {
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
                    @intCast(u6, layout.payload_size * 8)
                else
                    0;
                const result = try self.copyToRegisterWithInstTracking(inst, union_ty, operand);
                try self.genShiftBinOpMir(.shr, Type.usize, result, .{ .immediate = shift });
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
    const result = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_ty = self.air.typeOfIndex(inst);
        const src_ty = self.air.typeOf(ty_op.operand);

        const src_mcv = try self.resolveInst(ty_op.operand);
        const mat_src_mcv = switch (src_mcv) {
            .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
            else => src_mcv,
        };
        const mat_src_lock = switch (mat_src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_reg = try self.register_manager.allocReg(inst, gp);
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        if (Target.x86.featureSetHas(self.target.cpu.features, .lzcnt)) {
            try self.genBinOpMir(.lzcnt, src_ty, dst_mcv, mat_src_mcv);
            const extra_bits = self.regExtraBits(src_ty);
            if (extra_bits > 0) {
                try self.genBinOpMir(.sub, dst_ty, dst_mcv, .{ .immediate = extra_bits });
            }
            break :result dst_mcv;
        }

        const src_bits = src_ty.bitSize(self.target.*);
        if (math.isPowerOfTwo(src_bits)) {
            const imm_reg = try self.copyToTmpRegister(dst_ty, .{
                .immediate = src_bits ^ (src_bits - 1),
            });
            try self.genBinOpMir(.bsr, src_ty, dst_mcv, mat_src_mcv);

            const cmov_abi_size = @max(@intCast(u32, dst_ty.abiSize(self.target.*)), 2);
            try self.asmCmovccRegisterRegister(
                registerAlias(dst_reg, cmov_abi_size),
                registerAlias(imm_reg, cmov_abi_size),
                .z,
            );

            try self.genBinOpMir(.xor, dst_ty, dst_mcv, .{ .immediate = src_bits - 1 });
        } else {
            const imm_reg = try self.copyToTmpRegister(dst_ty, .{
                .immediate = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - self.regBitSize(dst_ty)),
            });
            try self.genBinOpMir(.bsr, src_ty, dst_mcv, mat_src_mcv);

            const cmov_abi_size = @max(@intCast(u32, dst_ty.abiSize(self.target.*)), 2);
            try self.asmCmovccRegisterRegister(
                registerAlias(imm_reg, cmov_abi_size),
                registerAlias(dst_reg, cmov_abi_size),
                .nz,
            );

            try self.genSetReg(dst_ty, dst_reg, .{ .immediate = src_bits - 1 });
            try self.genBinOpMir(.sub, dst_ty, dst_mcv, .{ .register = imm_reg });
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_ty = self.air.typeOfIndex(inst);
        const src_ty = self.air.typeOf(ty_op.operand);
        const src_bits = src_ty.bitSize(self.target.*);

        const src_mcv = try self.resolveInst(ty_op.operand);
        const mat_src_mcv = switch (src_mcv) {
            .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
            else => src_mcv,
        };
        const mat_src_lock = switch (mat_src_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_reg = try self.register_manager.allocReg(inst, gp);
        const dst_mcv = MCValue{ .register = dst_reg };
        const dst_lock = self.register_manager.lockReg(dst_reg);
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        if (Target.x86.featureSetHas(self.target.cpu.features, .bmi)) {
            const extra_bits = self.regExtraBits(src_ty);
            const masked_mcv = if (extra_bits > 0) masked: {
                const mask_mcv = MCValue{
                    .immediate = ((@as(u64, 1) << @intCast(u6, extra_bits)) - 1) <<
                        @intCast(u6, src_bits),
                };
                const tmp_mcv = tmp: {
                    if (src_mcv.isImmediate() or self.liveness.operandDies(inst, 0)) break :tmp src_mcv;
                    try self.genSetReg(src_ty, dst_reg, src_mcv);
                    break :tmp dst_mcv;
                };
                try self.genBinOpMir(.@"or", src_ty, tmp_mcv, mask_mcv);
                break :masked tmp_mcv;
            } else mat_src_mcv;
            try self.genBinOpMir(.tzcnt, src_ty, dst_mcv, masked_mcv);
            break :result dst_mcv;
        }

        const width_reg = try self.copyToTmpRegister(dst_ty, .{ .immediate = src_bits });
        try self.genBinOpMir(.bsf, src_ty, dst_mcv, mat_src_mcv);

        const cmov_abi_size = @max(@intCast(u32, dst_ty.abiSize(self.target.*)), 2);
        try self.asmCmovccRegisterRegister(
            registerAlias(dst_reg, cmov_abi_size),
            registerAlias(width_reg, cmov_abi_size),
            .z,
        );
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_abi_size = @intCast(u32, src_ty.abiSize(self.target.*));
        const src_mcv = try self.resolveInst(ty_op.operand);

        if (Target.x86.featureSetHas(self.target.cpu.features, .popcnt)) {
            const mat_src_mcv = switch (src_mcv) {
                .immediate => MCValue{ .register = try self.copyToTmpRegister(src_ty, src_mcv) },
                else => src_mcv,
            };
            const mat_src_lock = switch (mat_src_mcv) {
                .register => |reg| self.register_manager.lockReg(reg),
                else => null,
            };
            defer if (mat_src_lock) |lock| self.register_manager.unlockReg(lock);

            const dst_mcv: MCValue =
                if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
                src_mcv
            else
                .{ .register = try self.register_manager.allocReg(inst, gp) };

            const popcnt_ty = if (src_abi_size > 1) src_ty else Type.u16;
            try self.genBinOpMir(.popcnt, popcnt_ty, dst_mcv, mat_src_mcv);
            break :result dst_mcv;
        }

        const mask = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - src_abi_size * 8);
        const imm_0_1 = Immediate.u(mask / 0b1_1);
        const imm_00_11 = Immediate.u(mask / 0b01_01);
        const imm_0000_1111 = Immediate.u(mask / 0b0001_0001);
        const imm_0000_0001 = Immediate.u(mask / 0b1111_1111);

        const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, src_ty, src_mcv);
        const dst_reg = dst_mcv.register;
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const tmp_reg = try self.register_manager.allocReg(null, gp);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        {
            const dst = registerAlias(dst_reg, src_abi_size);
            const tmp = registerAlias(tmp_reg, src_abi_size);
            const imm = if (src_abi_size > 4)
                try self.register_manager.allocReg(null, gp)
            else
                undefined;

            // dst = operand
            try self.asmRegisterRegister(.mov, tmp, dst);
            // tmp = operand
            try self.asmRegisterImmediate(.shr, tmp, Immediate.u(1));
            // tmp = operand >> 1
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_0_1);
                try self.asmRegisterRegister(.@"and", tmp, imm);
            } else try self.asmRegisterImmediate(.@"and", tmp, imm_0_1);
            // tmp = (operand >> 1) & 0x55...55
            try self.asmRegisterRegister(.sub, dst, tmp);
            // dst = temp1 = operand - ((operand >> 1) & 0x55...55)
            try self.asmRegisterRegister(.mov, tmp, dst);
            // tmp = temp1
            try self.asmRegisterImmediate(.shr, dst, Immediate.u(2));
            // dst = temp1 >> 2
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_00_11);
                try self.asmRegisterRegister(.@"and", tmp, imm);
                try self.asmRegisterRegister(.@"and", dst, imm);
            } else {
                try self.asmRegisterImmediate(.@"and", tmp, imm_00_11);
                try self.asmRegisterImmediate(.@"and", dst, imm_00_11);
            }
            // tmp = temp1 & 0x33...33
            // dst = (temp1 >> 2) & 0x33...33
            try self.asmRegisterRegister(.add, tmp, dst);
            // tmp = temp2 = (temp1 & 0x33...33) + ((temp1 >> 2) & 0x33...33)
            try self.asmRegisterRegister(.mov, dst, tmp);
            // dst = temp2
            try self.asmRegisterImmediate(.shr, tmp, Immediate.u(4));
            // tmp = temp2 >> 4
            try self.asmRegisterRegister(.add, dst, tmp);
            // dst = temp2 + (temp2 >> 4)
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_0000_1111);
                try self.asmRegisterImmediate(.mov, tmp, imm_0000_0001);
                try self.asmRegisterRegister(.@"and", dst, imm);
                try self.asmRegisterRegister(.imul, dst, tmp);
            } else {
                try self.asmRegisterImmediate(.@"and", dst, imm_0000_1111);
                if (src_abi_size > 1) {
                    try self.asmRegisterRegisterImmediate(.imul, dst, dst, imm_0000_0001);
                }
            }
            // dst = temp3 = (temp2 + (temp2 >> 4)) & 0x0f...0f
            // dst = temp3 * 0x01...01
            if (src_abi_size > 1) {
                try self.asmRegisterImmediate(.shr, dst, Immediate.u((src_abi_size - 1) * 8));
            }
            // dst = (temp3 * 0x01...01) >> (bits - 8)
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn byteSwap(self: *Self, inst: Air.Inst.Index, src_ty: Type, src_mcv: MCValue, mem_ok: bool) !MCValue {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const src_bits = self.regBitSize(src_ty);
    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    switch (src_bits) {
        else => unreachable,
        8 => return if ((mem_ok or src_mcv.isRegister()) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, src_ty, src_mcv),
        16 => if ((mem_ok or src_mcv.isRegister()) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
        {
            try self.genBinOpMir(.rol, src_ty, src_mcv, .{ .immediate = 8 });
            return src_mcv;
        },
        32, 64 => if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) {
            try self.genUnOpMir(.bswap, src_ty, src_mcv);
            return src_mcv;
        },
    }

    if (src_mcv.isRegister()) {
        const dst_mcv: MCValue = if (mem_ok)
            try self.allocRegOrMem(inst, true)
        else
            .{ .register = try self.register_manager.allocReg(inst, gp) };
        if (dst_mcv.isRegister()) {
            const dst_lock = self.register_manager.lockRegAssumeUnused(dst_mcv.register);
            defer self.register_manager.unlockReg(dst_lock);

            try self.genSetReg(src_ty, dst_mcv.register, src_mcv);
            switch (src_bits) {
                else => unreachable,
                16 => try self.genBinOpMir(.rol, src_ty, dst_mcv, .{ .immediate = 8 }),
                32, 64 => try self.genUnOpMir(.bswap, src_ty, dst_mcv),
            }
        } else try self.genBinOpMir(.movbe, src_ty, dst_mcv, src_mcv);
        return dst_mcv;
    }

    const dst_reg = try self.register_manager.allocReg(inst, gp);
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
    defer self.register_manager.unlockReg(dst_lock);

    try self.genBinOpMir(.movbe, src_ty, dst_mcv, src_mcv);
    return dst_mcv;
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_mcv = try self.resolveInst(ty_op.operand);

        const dst_mcv = try self.byteSwap(inst, src_ty, src_mcv, true);
        switch (self.regExtraBits(src_ty)) {
            0 => {},
            else => |extra| try self.genBinOpMir(
                if (src_ty.isSignedInt()) .sar else .shr,
                src_ty,
                dst_mcv,
                .{ .immediate = extra },
            ),
        }
        break :result dst_mcv;
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const src_ty = self.air.typeOf(ty_op.operand);
        const src_abi_size = @intCast(u32, src_ty.abiSize(self.target.*));
        const src_mcv = try self.resolveInst(ty_op.operand);

        const dst_mcv = try self.byteSwap(inst, src_ty, src_mcv, false);
        const dst_reg = dst_mcv.register;
        const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
        defer self.register_manager.unlockReg(dst_lock);

        const tmp_reg = try self.register_manager.allocReg(null, gp);
        const tmp_lock = self.register_manager.lockReg(tmp_reg);
        defer if (tmp_lock) |lock| self.register_manager.unlockReg(lock);

        {
            const dst = registerAlias(dst_reg, src_abi_size);
            const tmp = registerAlias(tmp_reg, src_abi_size);
            const imm = if (src_abi_size > 4)
                try self.register_manager.allocReg(null, gp)
            else
                undefined;

            const mask = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - src_abi_size * 8);
            const imm_0000_1111 = Immediate.u(mask / 0b0001_0001);
            const imm_00_11 = Immediate.u(mask / 0b01_01);
            const imm_0_1 = Immediate.u(mask / 0b1_1);

            // dst = temp1 = bswap(operand)
            try self.asmRegisterRegister(.mov, tmp, dst);
            // tmp = temp1
            try self.asmRegisterImmediate(.shr, dst, Immediate.u(4));
            // dst = temp1 >> 4
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_0000_1111);
                try self.asmRegisterRegister(.@"and", tmp, imm);
                try self.asmRegisterRegister(.@"and", dst, imm);
            } else {
                try self.asmRegisterImmediate(.@"and", tmp, imm_0000_1111);
                try self.asmRegisterImmediate(.@"and", dst, imm_0000_1111);
            }
            // tmp = temp1 & 0x0F...0F
            // dst = (temp1 >> 4) & 0x0F...0F
            try self.asmRegisterImmediate(.shl, tmp, Immediate.u(4));
            // tmp = (temp1 & 0x0F...0F) << 4
            try self.asmRegisterRegister(.@"or", dst, tmp);
            // dst = temp2 = ((temp1 >> 4) & 0x0F...0F) | ((temp1 & 0x0F...0F) << 4)
            try self.asmRegisterRegister(.mov, tmp, dst);
            // tmp = temp2
            try self.asmRegisterImmediate(.shr, dst, Immediate.u(2));
            // dst = temp2 >> 2
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_00_11);
                try self.asmRegisterRegister(.@"and", tmp, imm);
                try self.asmRegisterRegister(.@"and", dst, imm);
            } else {
                try self.asmRegisterImmediate(.@"and", tmp, imm_00_11);
                try self.asmRegisterImmediate(.@"and", dst, imm_00_11);
            }
            // tmp = temp2 & 0x33...33
            // dst = (temp2 >> 2) & 0x33...33
            try self.asmRegisterMemory(
                .lea,
                if (src_abi_size > 4) tmp.to64() else tmp.to32(),
                Memory.sib(.qword, .{
                    .base = dst.to64(),
                    .scale_index = .{ .index = tmp.to64(), .scale = 1 << 2 },
                }),
            );
            // tmp = temp3 = ((temp2 >> 2) & 0x33...33) + ((temp2 & 0x33...33) << 2)
            try self.asmRegisterRegister(.mov, dst, tmp);
            // dst = temp3
            try self.asmRegisterImmediate(.shr, tmp, Immediate.u(1));
            // tmp = temp3 >> 1
            if (src_abi_size > 4) {
                try self.asmRegisterImmediate(.mov, imm, imm_0_1);
                try self.asmRegisterRegister(.@"and", dst, imm);
                try self.asmRegisterRegister(.@"and", tmp, imm);
            } else {
                try self.asmRegisterImmediate(.@"and", dst, imm_0_1);
                try self.asmRegisterImmediate(.@"and", tmp, imm_0_1);
            }
            // dst = temp3 & 0x55...55
            // tmp = (temp3 >> 1) & 0x55...55
            try self.asmRegisterMemory(
                .lea,
                if (src_abi_size > 4) dst.to64() else dst.to32(),
                Memory.sib(.qword, .{
                    .base = tmp.to64(),
                    .scale_index = .{ .index = dst.to64(), .scale = 1 << 1 },
                }),
            );
            // dst = ((temp3 >> 1) & 0x55...55) + ((temp3 & 0x55...55) << 1)
        }

        switch (self.regExtraBits(src_ty)) {
            0 => {},
            else => |extra| try self.genBinOpMir(
                if (src_ty.isSignedInt()) .sar else .shr,
                src_ty,
                dst_mcv,
                .{ .immediate = extra },
            ),
        }
        break :result dst_mcv;
    };

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
            if (!self.register_manager.isRegFree(reg)) {
                if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
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

fn packedLoad(self: *Self, dst_mcv: MCValue, ptr_mcv: MCValue, ptr_ty: Type) InnerError!void {
    const ptr_info = ptr_ty.ptrInfo().data;

    const val_ty = ptr_info.pointee_type;
    const val_abi_size = @intCast(u32, val_ty.abiSize(self.target.*));
    const limb_abi_size = @min(val_abi_size, 8);
    const limb_abi_bits = limb_abi_size * 8;
    const val_byte_off = @intCast(i32, ptr_info.bit_offset / limb_abi_bits * limb_abi_size);
    const val_bit_off = ptr_info.bit_offset % limb_abi_bits;
    const val_extra_bits = self.regExtraBits(val_ty);

    if (val_abi_size > 8) return self.fail("TODO implement packed load of {}", .{
        val_ty.fmt(self.bin_file.options.module.?),
    });

    const ptr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
    const ptr_lock = self.register_manager.lockRegAssumeUnused(ptr_reg);
    defer self.register_manager.unlockReg(ptr_lock);

    const dst_reg = switch (dst_mcv) {
        .register => |reg| reg,
        else => try self.register_manager.allocReg(null, gp),
    };
    const dst_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const load_abi_size =
        if (val_bit_off < val_extra_bits) val_abi_size else val_abi_size * 2;
    if (load_abi_size <= 8) {
        const load_reg = registerAlias(dst_reg, load_abi_size);
        try self.asmRegisterMemory(.mov, load_reg, Memory.sib(
            Memory.PtrSize.fromSize(load_abi_size),
            .{ .base = ptr_reg, .disp = val_byte_off },
        ));
        try self.asmRegisterImmediate(.shr, load_reg, Immediate.u(val_bit_off));
    } else {
        const tmp_reg = registerAlias(try self.register_manager.allocReg(null, gp), val_abi_size);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        const dst_alias = registerAlias(dst_reg, val_abi_size);
        try self.asmRegisterMemory(.mov, dst_alias, Memory.sib(
            Memory.PtrSize.fromSize(val_abi_size),
            .{ .base = ptr_reg, .disp = val_byte_off },
        ));
        try self.asmRegisterMemory(.mov, tmp_reg, Memory.sib(
            Memory.PtrSize.fromSize(val_abi_size),
            .{ .base = ptr_reg, .disp = val_byte_off + 1 },
        ));
        try self.asmRegisterRegisterImmediate(.shrd, dst_alias, tmp_reg, Immediate.u(val_bit_off));
    }

    if (val_extra_bits > 0) try self.truncateRegister(val_ty, dst_reg);
    try self.setRegOrMem(val_ty, dst_mcv, .{ .register = dst_reg });
}

fn load(self: *Self, dst_mcv: MCValue, ptr: MCValue, ptr_ty: Type) InnerError!void {
    const elem_ty = ptr_ty.elemType();
    const abi_size = @intCast(u32, elem_ty.abiSize(self.target.*));
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
                    try self.asmRegisterMemory(
                        .mov,
                        registerAlias(dst_reg, abi_size),
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg }),
                    );
                },
                .stack_offset => |off| {
                    if (abi_size <= 8) {
                        const tmp_reg = try self.register_manager.allocReg(null, gp);
                        try self.load(.{ .register = tmp_reg }, ptr, ptr_ty);
                        return self.genSetStack(elem_ty, off, MCValue{ .register = tmp_reg }, .{});
                    }

                    try self.genInlineMemcpy(
                        .{ .ptr_stack_offset = off },
                        ptr,
                        .{ .immediate = abi_size },
                        .{},
                    );
                },
                else => return self.fail("TODO implement loading from register into {}", .{dst_mcv}),
            }
        },
        .load_direct => |sym_index| {
            const addr_reg = try self.copyToTmpRegister(Type.usize, .{ .lea_direct = sym_index });
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);
            // Load the pointer, which is stored in memory
            try self.asmRegisterMemory(.mov, addr_reg, Memory.sib(.qword, .{ .base = addr_reg }));
            try self.load(dst_mcv, .{ .register = addr_reg }, ptr_ty);
        },
        .load_tlv => |sym_index| try self.load(dst_mcv, .{ .lea_tlv = sym_index }, ptr_ty),
        .memory, .load_got, .lea_direct, .lea_tlv => {
            const reg = try self.copyToTmpRegister(ptr_ty, ptr);
            try self.load(dst_mcv, .{ .register = reg }, ptr_ty);
        },
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const elem_ty = self.air.typeOfIndex(inst);
    const elem_size = elem_ty.abiSize(self.target.*);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBitsIgnoreComptime()) break :result .none;

        try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rdi, .rsi, .rcx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const ptr = try self.resolveInst(ty_op.operand);
        const is_volatile = self.air.typeOf(ty_op.operand).isVolatilePtr();
        if (self.liveness.isUnused(inst) and !is_volatile) break :result .dead;

        const dst_mcv: MCValue = if (elem_size <= 8 and self.reuseOperand(inst, ty_op.operand, 0, ptr))
            // The MCValue that holds the pointer can be re-used as the value.
            ptr
        else
            try self.allocRegOrMem(inst, true);

        const ptr_ty = self.air.typeOf(ty_op.operand);
        if (ptr_ty.ptrInfo().data.host_size > 0) {
            try self.packedLoad(dst_mcv, ptr, ptr_ty);
        } else {
            try self.load(dst_mcv, ptr, ptr_ty);
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn packedStore(
    self: *Self,
    ptr_mcv: MCValue,
    val_mcv: MCValue,
    ptr_ty: Type,
    val_ty: Type,
) InnerError!void {
    const ptr_info = ptr_ty.ptrInfo().data;

    const limb_abi_size = @min(ptr_info.host_size, 8);
    const limb_abi_bits = limb_abi_size * 8;

    const val_bit_size = val_ty.bitSize(self.target.*);
    const val_byte_off = @intCast(i32, ptr_info.bit_offset / limb_abi_bits * limb_abi_size);
    const val_bit_off = ptr_info.bit_offset % limb_abi_bits;

    const ptr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
    const ptr_lock = self.register_manager.lockRegAssumeUnused(ptr_reg);
    defer self.register_manager.unlockReg(ptr_lock);

    var limb_i: u16 = 0;
    while (limb_i * limb_abi_bits < val_bit_off + val_bit_size) : (limb_i += 1) {
        const part_bit_off = if (limb_i == 0) val_bit_off else 0;
        const part_bit_size =
            @min(val_bit_off + val_bit_size - limb_i * limb_abi_bits, limb_abi_bits) - part_bit_off;
        const limb_mem = Memory.sib(
            Memory.PtrSize.fromSize(limb_abi_size),
            .{ .base = ptr_reg, .disp = val_byte_off + limb_i * limb_abi_bits },
        );

        const part_mask = (@as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - part_bit_size)) <<
            @intCast(u6, part_bit_off);
        const part_mask_not = part_mask ^
            (@as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - limb_abi_bits));
        if (limb_abi_size <= 4) {
            try self.asmMemoryImmediate(.@"and", limb_mem, Immediate.u(part_mask_not));
        } else if (math.cast(i32, @bitCast(i64, part_mask_not))) |small| {
            try self.asmMemoryImmediate(.@"and", limb_mem, Immediate.s(small));
        } else {
            const part_mask_reg = try self.register_manager.allocReg(null, gp);
            try self.asmRegisterImmediate(.mov, part_mask_reg, Immediate.u(part_mask_not));
            try self.asmMemoryRegister(.@"and", limb_mem, part_mask_reg);
        }

        if (val_bit_size <= 64) {
            const tmp_reg = try self.register_manager.allocReg(null, gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetReg(val_ty, tmp_reg, val_mcv);
            switch (limb_i) {
                0 => try self.genShiftBinOpMir(.shl, val_ty, tmp_mcv, .{ .immediate = val_bit_off }),
                1 => try self.genShiftBinOpMir(.shr, val_ty, tmp_mcv, .{
                    .immediate = limb_abi_bits - val_bit_off,
                }),
                else => unreachable,
            }
            try self.genBinOpMir(.@"and", val_ty, tmp_mcv, .{ .immediate = part_mask });
            try self.asmMemoryRegister(.@"or", limb_mem, registerAlias(tmp_reg, limb_abi_size));
        } else return self.fail("TODO: implement packed store of {}", .{
            val_ty.fmt(self.bin_file.options.module.?),
        });
    }
}

fn store(self: *Self, ptr: MCValue, value: MCValue, ptr_ty: Type, value_ty: Type) InnerError!void {
    const abi_size = @intCast(u32, value_ty.abiSize(self.target.*));
    switch (ptr) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .immediate, .stack_offset => {
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
                .dead => unreachable,
                .unreach => unreachable,
                .eflags => |cc| try self.asmSetccMemory(
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                    cc,
                ),
                .undef => if (self.wantSafety()) switch (abi_size) {
                    1 => try self.store(ptr, .{ .immediate = 0xaa }, ptr_ty, value_ty),
                    2 => try self.store(ptr, .{ .immediate = 0xaaaa }, ptr_ty, value_ty),
                    4 => try self.store(ptr, .{ .immediate = 0xaaaaaaaa }, ptr_ty, value_ty),
                    8 => try self.store(ptr, .{ .immediate = 0xaaaaaaaaaaaaaaaa }, ptr_ty, value_ty),
                    else => try self.genInlineMemset(
                        ptr,
                        .{ .immediate = 0xaa },
                        .{ .immediate = abi_size },
                        .{},
                    ),
                },
                .immediate => |imm| switch (self.regBitSize(value_ty)) {
                    8 => try self.asmMemoryImmediate(
                        .mov,
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                        if (math.cast(i8, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u8, imm)),
                    ),
                    16 => try self.asmMemoryImmediate(
                        .mov,
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                        if (math.cast(i16, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u16, imm)),
                    ),
                    32 => try self.asmMemoryImmediate(
                        .mov,
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                        if (math.cast(i32, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u32, imm)),
                    ),
                    64 => if (math.cast(i32, @bitCast(i64, imm))) |small|
                        try self.asmMemoryImmediate(
                            .mov,
                            Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                            Immediate.s(small),
                        )
                    else
                        try self.asmMemoryRegister(
                            .mov,
                            Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                            registerAlias(try self.copyToTmpRegister(value_ty, value), abi_size),
                        ),
                    else => unreachable,
                },
                .register => |src_reg| try self.genInlineMemcpyRegisterRegister(
                    value_ty,
                    reg,
                    src_reg,
                    0,
                ),
                .register_overflow => |ro| {
                    const ro_reg_lock = self.register_manager.lockReg(ro.reg);
                    defer if (ro_reg_lock) |lock| self.register_manager.unlockReg(lock);

                    const wrapped_ty = value_ty.structFieldType(0);
                    try self.genInlineMemcpyRegisterRegister(wrapped_ty, reg, ro.reg, 0);

                    const overflow_bit_ty = value_ty.structFieldType(1);
                    const overflow_bit_offset = value_ty.structFieldOffset(1, self.target.*);
                    const tmp_reg = try self.register_manager.allocReg(null, gp);
                    try self.asmSetccRegister(tmp_reg.to8(), ro.eflags);
                    try self.genInlineMemcpyRegisterRegister(
                        overflow_bit_ty,
                        reg,
                        tmp_reg,
                        -@intCast(i32, overflow_bit_offset),
                    );
                },
                .memory, .load_tlv, .load_direct => if (abi_size <= 8) {
                    const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                } else {
                    const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
                    defer self.register_manager.unlockReg(addr_lock);

                    try self.genSetReg(Type.usize, addr_reg, switch (value) {
                        .memory => |addr| .{ .immediate = addr },
                        .load_direct => |sym_index| .{ .lea_direct = sym_index },
                        .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                        else => unreachable,
                    });
                    try self.genInlineMemcpy(
                        ptr,
                        .{ .register = addr_reg },
                        .{ .immediate = abi_size },
                        .{},
                    );
                },
                .stack_offset => |off| if (abi_size <= 8) {
                    const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                } else try self.genInlineMemcpy(
                    ptr,
                    .{ .ptr_stack_offset = off },
                    .{ .immediate = abi_size },
                    .{},
                ),
                .ptr_stack_offset, .load_got, .lea_direct, .lea_tlv => {
                    const tmp_reg = try self.copyToTmpRegister(value_ty, value);
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    try self.store(ptr, .{ .register = tmp_reg }, ptr_ty, value_ty);
                },
            }
        },
        .memory, .load_direct, .load_tlv => {
            const value_lock: ?RegisterLock = switch (value) {
                .register => |reg| self.register_manager.lockReg(reg),
                else => null,
            };
            defer if (value_lock) |lock| self.register_manager.unlockReg(lock);

            const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            switch (ptr) {
                .memory => |addr| try self.genSetReg(ptr_ty, addr_reg, .{ .immediate = addr }),
                .load_direct => |sym_index| try self.genSetReg(ptr_ty, addr_reg, .{ .lea_direct = sym_index }),
                .load_tlv => |sym_index| try self.genSetReg(ptr_ty, addr_reg, .{ .lea_tlv = sym_index }),
                else => unreachable,
            }
            if (ptr != .load_tlv) {
                // Load the pointer, which is stored in memory
                try self.asmRegisterMemory(.mov, addr_reg, Memory.sib(.qword, .{ .base = addr_reg }));
            }

            const new_ptr = MCValue{ .register = addr_reg };
            try self.store(new_ptr, value, ptr_ty, value_ty);
        },
        .load_got, .lea_direct, .lea_tlv => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr);
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            const new_ptr = MCValue{ .register = addr_reg };
            try self.store(new_ptr, value, ptr_ty, value_ty);
        },
    }
}

fn airStore(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const value = try self.resolveInst(bin_op.rhs);
    const value_ty = self.air.typeOf(bin_op.rhs);
    log.debug("airStore(%{d}): {} <- {}", .{ inst, ptr, value });
    if (ptr_ty.ptrInfo().data.host_size > 0) {
        try self.packedStore(ptr, value, ptr_ty, value_ty);
    } else {
        try self.store(ptr, value, ptr_ty, value_ty);
    }
    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airStructFieldPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result = try self.fieldPtr(inst, extra.struct_operand, extra.field_index);
    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airStructFieldPtrIndex(self: *Self, inst: Air.Inst.Index, index: u8) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = try self.fieldPtr(inst, ty_op.operand, index);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn fieldPtr(self: *Self, inst: Air.Inst.Index, operand: Air.Inst.Ref, index: u32) !MCValue {
    if (self.liveness.isUnused(inst)) {
        return MCValue.dead;
    }

    const mcv = try self.resolveInst(operand);
    const ptr_ty = self.air.typeOf(operand);
    const container_ty = ptr_ty.childType();
    const field_offset = switch (container_ty.containerLayout()) {
        .Auto, .Extern => @intCast(u32, container_ty.structFieldOffset(index, self.target.*)),
        .Packed => if (container_ty.zigTypeTag() == .Struct and ptr_ty.ptrInfo().data.host_size == 0)
            container_ty.packedStructFieldByteOffset(index, self.target.*)
        else
            0,
    };

    const dst_mcv: MCValue = result: {
        switch (mcv) {
            .stack_offset, .lea_tlv, .load_tlv => {
                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = field_offset,
                });
                const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
                defer self.register_manager.unlockReg(offset_reg_lock);

                const dst_mcv = try self.copyToRegisterWithInstTracking(inst, ptr_ty, switch (mcv) {
                    .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                    else => mcv,
                });
                try self.genBinOpMir(.add, ptr_ty, dst_mcv, .{ .register = offset_reg });
                break :result dst_mcv;
            },
            .ptr_stack_offset => |off| {
                const ptr_stack_offset = off - @intCast(i32, field_offset);
                break :result MCValue{ .ptr_stack_offset = ptr_stack_offset };
            },
            .register => |reg| {
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);

                const offset_reg = try self.copyToTmpRegister(ptr_ty, .{
                    .immediate = field_offset,
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
            else => return self.fail("TODO implement fieldPtr for {}", .{mcv}),
        }
    };
    return dst_mcv;
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = extra.struct_operand;
        const index = extra.field_index;

        const container_ty = self.air.typeOf(operand);
        const field_ty = container_ty.structFieldType(index);
        if (!field_ty.hasRuntimeBitsIgnoreComptime()) break :result .none;

        const src_mcv = try self.resolveInst(operand);
        const field_off = switch (container_ty.containerLayout()) {
            .Auto, .Extern => @intCast(u32, container_ty.structFieldOffset(index, self.target.*) * 8),
            .Packed => if (container_ty.castTag(.@"struct")) |struct_obj|
                struct_obj.data.packedFieldBitOffset(self.target.*, index)
            else
                0,
        };

        switch (src_mcv) {
            .stack_offset => |src_off| {
                const field_abi_size = @intCast(u32, field_ty.abiSize(self.target.*));
                const limb_abi_size = @min(field_abi_size, 8);
                const limb_abi_bits = limb_abi_size * 8;
                const field_byte_off = @intCast(i32, field_off / limb_abi_bits * limb_abi_size);
                const field_bit_off = field_off % limb_abi_bits;

                if (field_bit_off == 0) {
                    const off_mcv = MCValue{ .stack_offset = src_off - field_byte_off };
                    if (self.reuseOperand(inst, operand, 0, src_mcv)) break :result off_mcv;

                    const dst_mcv = try self.allocRegOrMem(inst, true);
                    try self.setRegOrMem(field_ty, dst_mcv, off_mcv);
                    break :result dst_mcv;
                }

                if (field_abi_size > 8) {
                    return self.fail("TODO implement struct_field_val with large packed field", .{});
                }

                const dst_reg = try self.register_manager.allocReg(inst, gp);
                const field_extra_bits = self.regExtraBits(field_ty);
                const load_abi_size =
                    if (field_bit_off < field_extra_bits) field_abi_size else field_abi_size * 2;
                if (load_abi_size <= 8) {
                    const load_reg = registerAlias(dst_reg, load_abi_size);
                    try self.asmRegisterMemory(.mov, load_reg, Memory.sib(
                        Memory.PtrSize.fromSize(load_abi_size),
                        .{ .base = .rbp, .disp = field_byte_off - src_off },
                    ));
                    try self.asmRegisterImmediate(.shr, load_reg, Immediate.u(field_bit_off));
                } else {
                    const tmp_reg = registerAlias(
                        try self.register_manager.allocReg(null, gp),
                        field_abi_size,
                    );
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const dst_alias = registerAlias(dst_reg, field_abi_size);
                    try self.asmRegisterMemory(.mov, dst_alias, Memory.sib(
                        Memory.PtrSize.fromSize(field_abi_size),
                        .{ .base = .rbp, .disp = field_byte_off - src_off },
                    ));
                    try self.asmRegisterMemory(.mov, tmp_reg, Memory.sib(
                        Memory.PtrSize.fromSize(field_abi_size),
                        .{ .base = .rbp, .disp = field_byte_off + 1 - src_off },
                    ));
                    try self.asmRegisterRegisterImmediate(
                        .shrd,
                        dst_alias,
                        tmp_reg,
                        Immediate.u(field_bit_off),
                    );
                }

                if (field_extra_bits > 0) try self.truncateRegister(field_ty, dst_reg);
                break :result .{ .register = dst_reg };
            },
            .register => |reg| {
                const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(reg_lock);

                const dst_mcv = if (self.reuseOperand(inst, operand, 0, src_mcv))
                    src_mcv
                else
                    try self.copyToRegisterWithInstTracking(
                        inst,
                        Type.usize,
                        .{ .register = reg.to64() },
                    );
                const dst_mcv_lock: ?RegisterLock = switch (dst_mcv) {
                    .register => |a_reg| self.register_manager.lockReg(a_reg),
                    else => null,
                };
                defer if (dst_mcv_lock) |lock| self.register_manager.unlockReg(lock);

                // Shift by struct_field_offset.
                try self.genShiftBinOpMir(.shr, Type.usize, dst_mcv, .{ .immediate = field_off });

                // Mask to field_bit_size bits
                const field_bit_size = field_ty.bitSize(self.target.*);
                const mask = ~@as(u64, 0) >> @intCast(u6, 64 - field_bit_size);

                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinOpMir(.@"and", Type.usize, dst_mcv, .{ .register = tmp_reg });

                const signedness =
                    if (field_ty.isAbiInt()) field_ty.intInfo(self.target.*).signedness else .unsigned;
                const field_byte_size = @intCast(u32, field_ty.abiSize(self.target.*));
                if (signedness == .signed and field_byte_size < 8) {
                    try self.asmRegisterRegister(
                        .movsx,
                        dst_mcv.register,
                        registerAlias(dst_mcv.register, field_byte_size),
                    );
                }
                break :result dst_mcv;
            },
            .register_overflow => |ro| {
                switch (index) {
                    // Get wrapped value for overflow operation.
                    0 => break :result if (self.liveness.operandDies(inst, 0))
                        .{ .register = ro.reg }
                    else
                        try self.copyToRegisterWithInstTracking(
                            inst,
                            Type.usize,
                            .{ .register = ro.reg },
                        ),
                    // Get overflow bit.
                    1 => if (self.liveness.operandDies(inst, 0)) {
                        self.eflags_inst = inst;
                        break :result .{ .eflags = ro.eflags };
                    } else {
                        const dst_reg = try self.register_manager.allocReg(inst, gp);
                        try self.asmSetccRegister(dst_reg.to8(), ro.eflags);
                        break :result .{ .register = dst_reg.to8() };
                    },
                    else => unreachable,
                }
            },
            else => return self.fail("TODO implement codegen struct_field_val for {}", .{src_mcv}),
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

fn genUnOp(self: *Self, maybe_inst: ?Air.Inst.Index, tag: Air.Inst.Tag, src_air: Air.Inst.Ref) !MCValue {
    const src_ty = self.air.typeOf(src_air);
    const src_mcv = try self.resolveInst(src_air);
    if (src_ty.zigTypeTag() == .Vector) {
        return self.fail("TODO implement genUnOp for {}", .{src_ty.fmt(self.bin_file.options.module.?)});
    }
    if (src_ty.abiSize(self.target.*) > 8) {
        return self.fail("TODO implement genUnOp for {}", .{src_ty.fmt(self.bin_file.options.module.?)});
    }

    switch (src_mcv) {
        .eflags => |cc| switch (tag) {
            .not => return .{ .eflags = cc.negate() },
            else => {},
        },
        else => {},
    }

    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_mcv: MCValue = if (maybe_inst) |inst|
        if (self.reuseOperand(inst, src_air, 0, src_mcv))
            src_mcv
        else
            try self.copyToRegisterWithInstTracking(inst, src_ty, src_mcv)
    else
        .{ .register = try self.copyToTmpRegister(src_ty, src_mcv) };
    const dst_lock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    switch (tag) {
        .not => {
            const int_info = if (src_ty.tag() == .bool)
                std.builtin.Type.Int{ .signedness = .unsigned, .bits = 1 }
            else
                src_ty.intInfo(self.target.*);
            const extra_bits = self.regExtraBits(src_ty);
            if (int_info.signedness == .unsigned and extra_bits > 0) {
                const mask = (@as(u64, 1) << @intCast(u6, src_ty.bitSize(self.target.*))) - 1;
                try self.genBinOpMir(.xor, src_ty, dst_mcv, .{ .immediate = mask });
            } else try self.genUnOpMir(.not, src_ty, dst_mcv);
        },

        .neg => try self.genUnOpMir(.neg, src_ty, dst_mcv),

        else => unreachable,
    }
    return dst_mcv;
}

fn genUnOpMir(self: *Self, mir_tag: Mir.Inst.Tag, dst_ty: Type, dst_mcv: MCValue) !void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .register => |dst_reg| try self.asmRegister(mir_tag, registerAlias(dst_reg, abi_size)),
        .stack_offset => |off| {
            if (abi_size > 8) {
                return self.fail("TODO implement {} for stack dst with large ABI", .{mir_tag});
            }

            try self.asmMemory(mir_tag, Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                .base = .rbp,
                .disp = -off,
            }));
        },
        .ptr_stack_offset => unreachable,
        .load_got, .lea_direct, .lea_tlv => unreachable,
        .memory, .load_direct, .load_tlv => {
            const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.genSetReg(Type.usize, addr_reg, switch (dst_mcv) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => unreachable,
            });
            try self.asmMemory(
                mir_tag,
                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = addr_reg }),
            );
        },
    }
}

/// Clobbers .rcx for non-immediate shift value.
fn genShiftBinOpMir(
    self: *Self,
    tag: Mir.Inst.Tag,
    ty: Type,
    lhs_mcv: MCValue,
    shift_mcv: MCValue,
) !void {
    const rhs_mcv: MCValue = rhs: {
        switch (shift_mcv) {
            .immediate => |imm| switch (imm) {
                0 => return,
                else => break :rhs shift_mcv,
            },
            .register => |shift_reg| if (shift_reg == .rcx) break :rhs shift_mcv,
            else => {},
        }
        self.register_manager.getRegAssumeFree(.rcx, null);
        try self.genSetReg(Type.u8, .rcx, shift_mcv);
        break :rhs .{ .register = .rcx };
    };

    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    if (abi_size <= 8) {
        switch (lhs_mcv) {
            .register => |lhs_reg| switch (rhs_mcv) {
                .immediate => |rhs_imm| try self.asmRegisterImmediate(
                    tag,
                    registerAlias(lhs_reg, abi_size),
                    Immediate.u(rhs_imm),
                ),
                .register => |rhs_reg| try self.asmRegisterRegister(
                    tag,
                    registerAlias(lhs_reg, abi_size),
                    registerAlias(rhs_reg, 1),
                ),
                else => return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                    @tagName(lhs_mcv),
                    @tagName(rhs_mcv),
                }),
            },
            .stack_offset => |lhs_off| switch (rhs_mcv) {
                .immediate => |rhs_imm| try self.asmMemoryImmediate(
                    tag,
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -lhs_off }),
                    Immediate.u(rhs_imm),
                ),
                .register => |rhs_reg| try self.asmMemoryRegister(
                    tag,
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -lhs_off }),
                    registerAlias(rhs_reg, 1),
                ),
                else => return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                    @tagName(lhs_mcv),
                    @tagName(rhs_mcv),
                }),
            },
            else => return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                @tagName(lhs_mcv),
                @tagName(rhs_mcv),
            }),
        }
    } else if (abi_size <= 16) {
        const tmp_reg = try self.register_manager.allocReg(null, gp);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        const info: struct { offsets: [2]i32, double_tag: Mir.Inst.Tag } = switch (tag) {
            .shl, .sal => .{ .offsets = .{ 0, 8 }, .double_tag = .shld },
            .shr, .sar => .{ .offsets = .{ 8, 0 }, .double_tag = .shrd },
            else => unreachable,
        };
        switch (lhs_mcv) {
            .stack_offset => |dst_off| switch (rhs_mcv) {
                .immediate => |rhs_imm| if (rhs_imm == 0) {} else if (rhs_imm < 64) {
                    try self.asmRegisterMemory(
                        .mov,
                        tmp_reg,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                    );
                    try self.asmMemoryRegisterImmediate(
                        info.double_tag,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[1] - dst_off }),
                        tmp_reg,
                        Immediate.u(rhs_imm),
                    );
                    try self.asmMemoryImmediate(
                        tag,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                        Immediate.u(rhs_imm),
                    );
                } else {
                    assert(rhs_imm < 128);
                    try self.asmRegisterMemory(
                        .mov,
                        tmp_reg,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                    );
                    if (rhs_imm > 64) {
                        try self.asmRegisterImmediate(tag, tmp_reg, Immediate.u(rhs_imm - 64));
                    }
                    try self.asmMemoryRegister(
                        .mov,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[1] - dst_off }),
                        tmp_reg,
                    );
                    switch (tag) {
                        .shl, .sal, .shr => {
                            try self.asmRegisterRegister(.xor, tmp_reg.to32(), tmp_reg.to32());
                            try self.asmMemoryRegister(
                                .mov,
                                Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                                tmp_reg,
                            );
                        },
                        .sar => try self.asmMemoryImmediate(
                            tag,
                            Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                            Immediate.u(63),
                        ),
                        else => unreachable,
                    }
                },
                else => {
                    const first_reg = try self.register_manager.allocReg(null, gp);
                    const first_lock = self.register_manager.lockRegAssumeUnused(first_reg);
                    defer self.register_manager.unlockReg(first_lock);

                    const second_reg = try self.register_manager.allocReg(null, gp);
                    const second_lock = self.register_manager.lockRegAssumeUnused(second_reg);
                    defer self.register_manager.unlockReg(second_lock);

                    try self.genSetReg(Type.u8, .cl, rhs_mcv);
                    try self.asmRegisterMemory(
                        .mov,
                        first_reg,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                    );
                    try self.asmRegisterMemory(
                        .mov,
                        second_reg,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[1] - dst_off }),
                    );
                    switch (tag) {
                        .shl, .sal, .shr => try self.asmRegisterRegister(
                            .xor,
                            tmp_reg.to32(),
                            tmp_reg.to32(),
                        ),
                        .sar => {
                            try self.asmRegisterRegister(.mov, tmp_reg, first_reg);
                            try self.asmRegisterImmediate(tag, tmp_reg, Immediate.u(63));
                        },
                        else => unreachable,
                    }
                    try self.asmRegisterRegisterRegister(info.double_tag, second_reg, first_reg, .cl);
                    try self.asmRegisterRegister(tag, first_reg, .cl);
                    try self.asmRegisterImmediate(.cmp, .cl, Immediate.u(64));
                    try self.asmCmovccRegisterRegister(second_reg, first_reg, .ae);
                    try self.asmCmovccRegisterRegister(first_reg, tmp_reg, .ae);
                    try self.asmMemoryRegister(
                        .mov,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[1] - dst_off }),
                        second_reg,
                    );
                    try self.asmMemoryRegister(
                        .mov,
                        Memory.sib(.qword, .{ .base = .rbp, .disp = info.offsets[0] - dst_off }),
                        first_reg,
                    );
                },
            },
            else => return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                @tagName(lhs_mcv),
                @tagName(rhs_mcv),
            }),
        }
    } else return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
        @tagName(lhs_mcv),
        @tagName(rhs_mcv),
    });
}

/// Result is always a register.
/// Clobbers .rcx for non-immediate rhs, therefore care is needed to spill .rcx upfront.
/// Asserts .rcx is free.
fn genShiftBinOp(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    lhs_mcv: MCValue,
    rhs_mcv: MCValue,
    lhs_ty: Type,
    rhs_ty: Type,
) !MCValue {
    if (lhs_ty.zigTypeTag() == .Vector) {
        return self.fail("TODO implement genShiftBinOp for {}", .{lhs_ty.fmtDebug()});
    }

    assert(rhs_ty.abiSize(self.target.*) == 1);

    const lhs_abi_size = lhs_ty.abiSize(self.target.*);
    if (lhs_abi_size > 16) {
        return self.fail("TODO implement genShiftBinOp for {}", .{lhs_ty.fmtDebug()});
    }

    try self.register_manager.getReg(.rcx, null);
    const rcx_lock = self.register_manager.lockRegAssumeUnused(.rcx);
    defer self.register_manager.unlockReg(rcx_lock);

    const lhs_lock = switch (lhs_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_lock = switch (rhs_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_mcv: MCValue = dst: {
        if (maybe_inst) |inst| {
            const bin_op = self.air.instructions.items(.data)[inst].bin_op;
            if (self.reuseOperand(inst, bin_op.lhs, 0, lhs_mcv)) break :dst lhs_mcv;
        }
        const dst_mcv = try self.allocRegOrMemAdvanced(lhs_ty, maybe_inst, true);
        try self.setRegOrMem(lhs_ty, dst_mcv, lhs_mcv);
        break :dst dst_mcv;
    };

    const signedness = lhs_ty.intInfo(self.target.*).signedness;
    try self.genShiftBinOpMir(switch (tag) {
        .shl, .shl_exact => switch (signedness) {
            .signed => .sal,
            .unsigned => .shl,
        },
        .shr, .shr_exact => switch (signedness) {
            .signed => .sar,
            .unsigned => .shr,
        },
        else => unreachable,
    }, lhs_ty, dst_mcv, rhs_mcv);
    return dst_mcv;
}

/// Result is always a register.
/// Clobbers .rax and .rdx therefore care is needed to spill .rax and .rdx upfront.
/// Asserts .rax and .rdx are free.
fn genMulDivBinOp(
    self: *Self,
    tag: Air.Inst.Tag,
    maybe_inst: ?Air.Inst.Index,
    dst_ty: Type,
    src_ty: Type,
    lhs: MCValue,
    rhs: MCValue,
) !MCValue {
    if (dst_ty.zigTypeTag() == .Vector or dst_ty.zigTypeTag() == .Float) {
        return self.fail("TODO implement genMulDivBinOp for {}", .{dst_ty.fmtDebug()});
    }
    const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    const src_abi_size = @intCast(u32, src_ty.abiSize(self.target.*));
    if (switch (tag) {
        else => unreachable,
        .mul, .mulwrap => dst_abi_size != src_abi_size and dst_abi_size != src_abi_size * 2,
        .div_trunc, .div_floor, .div_exact, .rem, .mod => dst_abi_size != src_abi_size,
    } or src_abi_size > 8) return self.fail("TODO implement genMulDivBinOp from {} to {}", .{
        src_ty.fmt(self.bin_file.options.module.?),
        dst_ty.fmt(self.bin_file.options.module.?),
    });
    const ty = if (dst_abi_size <= 8) dst_ty else src_ty;
    const abi_size = if (dst_abi_size <= 8) dst_abi_size else src_abi_size;

    assert(self.register_manager.isRegFree(.rax));
    assert(self.register_manager.isRegFree(.rdx));

    const reg_locks = self.register_manager.lockRegs(2, .{ .rax, .rdx });
    defer for (reg_locks) |reg_lock| if (reg_lock) |lock| self.register_manager.unlockReg(lock);

    const signedness = ty.intInfo(self.target.*).signedness;
    switch (tag) {
        .mul,
        .mulwrap,
        .rem,
        .div_trunc,
        .div_exact,
        => {
            const track_inst_rax = switch (tag) {
                .mul, .mulwrap => if (dst_abi_size <= 8) maybe_inst else null,
                .div_exact, .div_trunc => maybe_inst,
                else => null,
            };
            const track_inst_rdx = switch (tag) {
                .rem => maybe_inst,
                else => null,
            };
            try self.register_manager.getReg(.rax, track_inst_rax);
            try self.register_manager.getReg(.rdx, track_inst_rdx);

            const mir_tag: Mir.Inst.Tag = switch (signedness) {
                .signed => switch (tag) {
                    .mul, .mulwrap => .imul,
                    .div_trunc, .div_exact, .rem => .idiv,
                    else => unreachable,
                },
                .unsigned => switch (tag) {
                    .mul, .mulwrap => .mul,
                    .div_trunc, .div_exact, .rem => .div,
                    else => unreachable,
                },
            };

            try self.genIntMulDivOpMir(mir_tag, ty, lhs, rhs);

            if (dst_abi_size <= 8) return .{ .register = registerAlias(switch (tag) {
                .mul, .mulwrap, .div_trunc, .div_exact => .rax,
                .rem => .rdx,
                else => unreachable,
            }, dst_abi_size) };

            const dst_mcv = try self.allocRegOrMemAdvanced(dst_ty, maybe_inst, false);
            try self.asmMemoryRegister(.mov, Memory.sib(.qword, .{
                .base = .rbp,
                .disp = 0 - dst_mcv.stack_offset,
            }), .rax);
            try self.asmMemoryRegister(.mov, Memory.sib(.qword, .{
                .base = .rbp,
                .disp = 8 - dst_mcv.stack_offset,
            }), .rdx);
            return dst_mcv;
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
                        .{ .register = try self.copyToTmpRegister(ty, lhs) };
                    try self.genBinOpMir(.sub, ty, result, div_floor);

                    return result;
                },
                .unsigned => {
                    try self.genIntMulDivOpMir(.div, ty, lhs, rhs);
                    return .{ .register = registerAlias(.rdx, abi_size) };
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

            switch (signedness) {
                .signed => return try self.genInlineIntDivFloor(ty, lhs, actual_rhs),
                .unsigned => {
                    try self.genIntMulDivOpMir(.div, ty, lhs, actual_rhs);
                    return .{ .register = registerAlias(.rax, abi_size) };
                },
            }
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
        return self.fail("TODO implement genBinOp for {}", .{lhs_ty.fmt(self.bin_file.options.module.?)});
    }

    switch (lhs) {
        .immediate => |imm| switch (imm) {
            0 => switch (tag) {
                .sub, .subwrap => return self.genUnOp(maybe_inst, .neg, rhs_air),
                else => {},
            },
            else => {},
        },
        else => {},
    }

    const is_commutative = switch (tag) {
        .add,
        .addwrap,
        .bool_or,
        .bit_or,
        .bool_and,
        .bit_and,
        .xor,
        .min,
        .max,
        => true,

        else => false,
    };
    const dst_mem_ok = switch (tag) {
        .add,
        .addwrap,
        .sub,
        .subwrap,
        .mul,
        .div_float,
        .div_exact,
        .div_trunc,
        .div_floor,
        => !lhs_ty.isRuntimeFloat(),

        else => true,
    };

    const lhs_lock: ?RegisterLock = switch (lhs) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_lock: ?RegisterLock = switch (rhs) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    var flipped: bool = false;
    const dst_mcv: MCValue = dst: {
        if (maybe_inst) |inst| {
            if ((dst_mem_ok or lhs.isRegister()) and self.reuseOperand(inst, lhs_air, 0, lhs)) {
                break :dst lhs;
            }
            if (is_commutative and (dst_mem_ok or rhs.isRegister()) and
                self.reuseOperand(inst, rhs_air, 1, rhs))
            {
                flipped = true;
                break :dst rhs;
            }
        }
        const dst_mcv = try self.allocRegOrMemAdvanced(lhs_ty, maybe_inst, true);
        try self.setRegOrMem(lhs_ty, dst_mcv, switch (lhs) {
            .load_direct => |sym_index| .{ .lea_direct = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
            else => lhs,
        });
        break :dst dst_mcv;
    };
    const dst_mcv_lock: ?RegisterLock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_mcv_lock) |lock| self.register_manager.unlockReg(lock);

    const src_mcv = if (flipped) lhs else rhs;
    switch (tag) {
        .add,
        .addwrap,
        => try self.genBinOpMir(switch (lhs_ty.tag()) {
            else => .add,
            .f32 => .addss,
            .f64 => .addsd,
        }, lhs_ty, dst_mcv, src_mcv),

        .sub,
        .subwrap,
        => try self.genBinOpMir(switch (lhs_ty.tag()) {
            else => .sub,
            .f32 => .subss,
            .f64 => .subsd,
        }, lhs_ty, dst_mcv, src_mcv),

        .mul => try self.genBinOpMir(switch (lhs_ty.tag()) {
            .f32 => .mulss,
            .f64 => .mulsd,
            else => return self.fail("TODO implement genBinOp for {s} {}", .{ @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?) }),
        }, lhs_ty, dst_mcv, src_mcv),

        .div_float,
        .div_exact,
        .div_trunc,
        .div_floor,
        => {
            try self.genBinOpMir(switch (lhs_ty.tag()) {
                .f32 => .divss,
                .f64 => .divsd,
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
            }, lhs_ty, dst_mcv, src_mcv);
            switch (tag) {
                .div_float,
                .div_exact,
                => {},
                .div_trunc,
                .div_floor,
                => if (Target.x86.featureSetHas(self.target.cpu.features, .sse4_1)) {
                    const abi_size = @intCast(u32, lhs_ty.abiSize(self.target.*));
                    const dst_alias = registerAlias(dst_mcv.register, abi_size);
                    try self.asmRegisterRegisterImmediate(switch (lhs_ty.tag()) {
                        .f32 => .roundss,
                        .f64 => .roundsd,
                        else => unreachable,
                    }, dst_alias, dst_alias, Immediate.u(switch (tag) {
                        .div_trunc => 0b1_0_11,
                        .div_floor => 0b1_0_01,
                        else => unreachable,
                    }));
                } else return self.fail("TODO implement round without sse4_1", .{}),
                else => unreachable,
            }
        },

        .ptr_add,
        .ptr_sub,
        => {
            const tmp_reg = try self.copyToTmpRegister(rhs_ty, src_mcv);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            const elem_size = lhs_ty.elemType2().abiSize(self.target.*);
            try self.genIntMulComplexOpMir(rhs_ty, tmp_mcv, .{ .immediate = elem_size });
            try self.genBinOpMir(switch (tag) {
                .ptr_add => .add,
                .ptr_sub => .sub,
                else => unreachable,
            }, lhs_ty, dst_mcv, tmp_mcv);
        },

        .bool_or,
        .bit_or,
        => try self.genBinOpMir(.@"or", lhs_ty, dst_mcv, src_mcv),

        .bool_and,
        .bit_and,
        => try self.genBinOpMir(.@"and", lhs_ty, dst_mcv, src_mcv),

        .xor => try self.genBinOpMir(.xor, lhs_ty, dst_mcv, src_mcv),

        .min,
        .max,
        => switch (lhs_ty.zigTypeTag()) {
            .Int => {
                const mat_src_mcv = switch (src_mcv) {
                    .immediate => MCValue{ .register = try self.copyToTmpRegister(rhs_ty, src_mcv) },
                    else => src_mcv,
                };
                const mat_mcv_lock = switch (mat_src_mcv) {
                    .register => |reg| self.register_manager.lockReg(reg),
                    else => null,
                };
                defer if (mat_mcv_lock) |lock| self.register_manager.unlockReg(lock);

                try self.genBinOpMir(.cmp, lhs_ty, dst_mcv, mat_src_mcv);

                const int_info = lhs_ty.intInfo(self.target.*);
                const cc: Condition = switch (int_info.signedness) {
                    .unsigned => switch (tag) {
                        .min => .a,
                        .max => .b,
                        else => unreachable,
                    },
                    .signed => switch (tag) {
                        .min => .g,
                        .max => .l,
                        else => unreachable,
                    },
                };

                const cmov_abi_size = @max(@intCast(u32, lhs_ty.abiSize(self.target.*)), 2);
                const tmp_reg = switch (dst_mcv) {
                    .register => |reg| reg,
                    else => try self.copyToTmpRegister(lhs_ty, dst_mcv),
                };
                const tmp_lock = self.register_manager.lockReg(tmp_reg);
                defer if (tmp_lock) |lock| self.register_manager.unlockReg(lock);
                switch (mat_src_mcv) {
                    .none,
                    .undef,
                    .dead,
                    .unreach,
                    .immediate,
                    .eflags,
                    .register_overflow,
                    .ptr_stack_offset,
                    .load_got,
                    .lea_direct,
                    .lea_tlv,
                    => unreachable,
                    .register => |src_reg| try self.asmCmovccRegisterRegister(
                        registerAlias(tmp_reg, cmov_abi_size),
                        registerAlias(src_reg, cmov_abi_size),
                        cc,
                    ),
                    .stack_offset => |off| try self.asmCmovccRegisterMemory(
                        registerAlias(tmp_reg, cmov_abi_size),
                        Memory.sib(Memory.PtrSize.fromSize(cmov_abi_size), .{
                            .base = .rbp,
                            .disp = -off,
                        }),
                        cc,
                    ),
                    .memory, .load_direct, .load_tlv => {
                        const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                        const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
                        defer self.register_manager.unlockReg(addr_reg_lock);

                        try self.genSetReg(Type.usize, addr_reg, switch (mat_src_mcv) {
                            .memory => |addr| .{ .immediate = addr },
                            .load_direct => |sym_index| .{ .lea_direct = sym_index },
                            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                            else => unreachable,
                        });
                        try self.asmCmovccRegisterMemory(
                            registerAlias(tmp_reg, cmov_abi_size),
                            Memory.sib(Memory.PtrSize.fromSize(cmov_abi_size), .{ .base = addr_reg }),
                            cc,
                        );
                    },
                }
                try self.setRegOrMem(lhs_ty, dst_mcv, .{ .register = tmp_reg });
            },
            .Float => try self.genBinOpMir(switch (lhs_ty.tag()) {
                .f32 => switch (tag) {
                    .min => .minss,
                    .max => .maxss,
                    else => unreachable,
                },
                .f64 => switch (tag) {
                    .min => .minsd,
                    .max => .maxsd,
                    else => unreachable,
                },
                else => return self.fail("TODO implement genBinOp for {s} {}", .{ @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?) }),
            }, lhs_ty, dst_mcv, src_mcv),
            else => return self.fail("TODO implement genBinOp for {s} {}", .{ @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?) }),
        },

        else => unreachable,
    }
    return dst_mcv;
}

fn genBinOpMir(self: *Self, mir_tag: Mir.Inst.Tag, ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .dead, .unreach, .immediate => unreachable,
        .eflags => unreachable,
        .register_overflow => unreachable,
        .register => |dst_reg| {
            const dst_alias = registerAlias(dst_reg, abi_size);
            switch (src_mcv) {
                .none => unreachable,
                .undef => unreachable,
                .dead, .unreach => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| switch (ty.zigTypeTag()) {
                    .Float => {
                        if (intrinsicsAllowed(self.target.*, ty)) {
                            return self.asmRegisterRegister(mir_tag, dst_reg.to128(), src_reg.to128());
                        }

                        return self.fail("TODO genBinOpMir for float register-register and no intrinsics", .{});
                    },
                    else => try self.asmRegisterRegister(
                        mir_tag,
                        dst_alias,
                        registerAlias(src_reg, abi_size),
                    ),
                },
                .immediate => |imm| switch (self.regBitSize(ty)) {
                    8 => try self.asmRegisterImmediate(
                        mir_tag,
                        dst_alias,
                        if (math.cast(i8, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u8, imm)),
                    ),
                    16 => try self.asmRegisterImmediate(
                        mir_tag,
                        dst_alias,
                        if (math.cast(i16, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u16, imm)),
                    ),
                    32 => try self.asmRegisterImmediate(
                        mir_tag,
                        dst_alias,
                        if (math.cast(i32, @bitCast(i64, imm))) |small|
                            Immediate.s(small)
                        else
                            Immediate.u(@intCast(u32, imm)),
                    ),
                    64 => if (math.cast(i32, @bitCast(i64, imm))) |small|
                        try self.asmRegisterImmediate(mir_tag, dst_alias, Immediate.s(small))
                    else
                        try self.asmRegisterRegister(mir_tag, dst_alias, registerAlias(
                            try self.copyToTmpRegister(ty, src_mcv),
                            abi_size,
                        )),
                    else => unreachable,
                },
                .ptr_stack_offset,
                .memory,
                .load_got,
                .lea_direct,
                .load_direct,
                .lea_tlv,
                .load_tlv,
                .eflags,
                => {
                    assert(abi_size <= 8);
                    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
                    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

                    const reg = try self.copyToTmpRegister(ty, src_mcv);
                    return self.genBinOpMir(mir_tag, ty, dst_mcv, .{ .register = reg });
                },
                .stack_offset => |off| try self.asmRegisterMemory(
                    mir_tag,
                    registerAlias(dst_reg, abi_size),
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -off }),
                ),
            }
        },
        .memory, .load_got, .load_direct, .load_tlv, .stack_offset => {
            const dst: ?struct {
                addr_reg: Register,
                addr_lock: RegisterLock,
            } = switch (dst_mcv) {
                else => unreachable,
                .memory, .load_got, .load_direct, .load_tlv => dst: {
                    const dst_addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    const dst_addr_lock = self.register_manager.lockRegAssumeUnused(dst_addr_reg);
                    errdefer self.register_manager.unlockReg(dst_addr_lock);

                    try self.genSetReg(Type.usize, dst_addr_reg, switch (dst_mcv) {
                        .memory => |addr| .{ .immediate = addr },
                        .load_direct => |sym_index| .{ .lea_direct = sym_index },
                        .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                        else => dst_mcv,
                    });

                    break :dst .{
                        .addr_reg = dst_addr_reg,
                        .addr_lock = dst_addr_lock,
                    };
                },
                .stack_offset => null,
            };
            defer if (dst) |lock| self.register_manager.unlockReg(lock.addr_lock);

            const src: ?struct {
                limb_reg: Register,
                limb_lock: RegisterLock,
                addr_reg: Register,
                addr_lock: RegisterLock,
            } = switch (src_mcv) {
                else => null,
                .memory, .load_got, .load_direct, .load_tlv => src: {
                    const src_limb_reg = try self.register_manager.allocReg(null, gp);
                    const src_limb_lock = self.register_manager.lockRegAssumeUnused(src_limb_reg);
                    errdefer self.register_manager.unlockReg(src_limb_lock);

                    const src_addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    const src_addr_lock = self.register_manager.lockRegAssumeUnused(src_addr_reg);
                    errdefer self.register_manager.unlockReg(src_addr_lock);

                    try self.genSetReg(Type.usize, src_addr_reg, switch (src_mcv) {
                        .memory => |addr| .{ .immediate = addr },
                        .load_direct => |sym_index| .{ .lea_direct = sym_index },
                        .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                        else => src_mcv,
                    });

                    break :src .{
                        .addr_reg = src_addr_reg,
                        .addr_lock = src_addr_lock,
                        .limb_reg = src_limb_reg,
                        .limb_lock = src_limb_lock,
                    };
                },
            };
            defer if (src) |locks| {
                self.register_manager.unlockReg(locks.limb_lock);
                self.register_manager.unlockReg(locks.addr_lock);
            };

            const ty_signedness =
                if (ty.isAbiInt()) ty.intInfo(self.target.*).signedness else .unsigned;
            const limb_ty = if (abi_size <= 8) ty else switch (ty_signedness) {
                .signed => Type.usize,
                .unsigned => Type.isize,
            };
            const limb_abi_size = @min(abi_size, 8);
            var off: i32 = 0;
            while (off < abi_size) : (off += 8) {
                const mir_limb_tag = switch (off) {
                    0 => mir_tag,
                    else => switch (mir_tag) {
                        .add => .adc,
                        .sub, .cmp => .sbb,
                        .@"or", .@"and", .xor => mir_tag,
                        else => return self.fail("TODO genBinOpMir implement large ABI for {s}", .{
                            @tagName(mir_tag),
                        }),
                    },
                };
                const dst_limb_mem = Memory.sib(
                    Memory.PtrSize.fromSize(limb_abi_size),
                    switch (dst_mcv) {
                        else => unreachable,
                        .stack_offset => |dst_off| .{
                            .base = .rbp,
                            .disp = off - dst_off,
                        },
                        .memory,
                        .load_got,
                        .load_direct,
                        .load_tlv,
                        => .{ .base = dst.?.addr_reg, .disp = off },
                    },
                );
                switch (src_mcv) {
                    .none => unreachable,
                    .undef => unreachable,
                    .dead, .unreach => unreachable,
                    .register_overflow => unreachable,
                    .register => |src_reg| {
                        assert(off == 0);
                        try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src_reg, limb_abi_size),
                        );
                    },
                    .immediate => |src_imm| {
                        const imm = if (off == 0) src_imm else switch (ty_signedness) {
                            .signed => @bitCast(u64, @bitCast(i64, src_imm) >> 63),
                            .unsigned => 0,
                        };
                        switch (self.regBitSize(limb_ty)) {
                            8 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i8, @bitCast(i64, imm))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@intCast(u8, imm)),
                            ),
                            16 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i16, @bitCast(i64, imm))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@intCast(u16, imm)),
                            ),
                            32 => try self.asmMemoryImmediate(
                                mir_limb_tag,
                                dst_limb_mem,
                                if (math.cast(i32, @bitCast(i64, imm))) |small|
                                    Immediate.s(small)
                                else
                                    Immediate.u(@intCast(u32, imm)),
                            ),
                            64 => if (math.cast(i32, @bitCast(i64, imm))) |small|
                                try self.asmMemoryImmediate(
                                    mir_limb_tag,
                                    dst_limb_mem,
                                    Immediate.s(small),
                                )
                            else
                                try self.asmMemoryRegister(
                                    mir_limb_tag,
                                    dst_limb_mem,
                                    registerAlias(
                                        try self.copyToTmpRegister(limb_ty, .{ .immediate = imm }),
                                        limb_abi_size,
                                    ),
                                ),
                            else => unreachable,
                        }
                    },
                    .memory,
                    .load_got,
                    .load_direct,
                    .load_tlv,
                    => {
                        try self.asmRegisterMemory(
                            .mov,
                            registerAlias(src.?.limb_reg, limb_abi_size),
                            Memory.sib(
                                Memory.PtrSize.fromSize(limb_abi_size),
                                .{ .base = src.?.addr_reg, .disp = off },
                            ),
                        );
                        try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src.?.limb_reg, limb_abi_size),
                        );
                    },
                    .stack_offset,
                    .ptr_stack_offset,
                    .eflags,
                    .lea_direct,
                    .lea_tlv,
                    => {
                        const src_limb_reg = try self.copyToTmpRegister(limb_ty, switch (src_mcv) {
                            .stack_offset => |src_off| .{ .stack_offset = src_off - off },
                            .ptr_stack_offset,
                            .eflags,
                            .load_got,
                            .lea_direct,
                            .lea_tlv,
                            => off: {
                                assert(off == 0);
                                break :off src_mcv;
                            },
                            else => unreachable,
                        });
                        const src_limb_lock = self.register_manager.lockReg(src_limb_reg);
                        defer if (src_limb_lock) |lock| self.register_manager.unlockReg(lock);

                        try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src_limb_reg, limb_abi_size),
                        );
                    },
                }
            }
        },
        .ptr_stack_offset => unreachable,
        .lea_tlv => unreachable,
        .lea_direct => unreachable,
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
        .lea_direct => unreachable,
        .lea_tlv => unreachable,
        .register_overflow => unreachable,
        .register => |dst_reg| {
            const dst_alias = registerAlias(dst_reg, abi_size);
            const dst_lock = self.register_manager.lockReg(dst_reg);
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            switch (src_mcv) {
                .none => unreachable,
                .undef => try self.genSetReg(dst_ty, dst_reg, .undef),
                .dead, .unreach => unreachable,
                .ptr_stack_offset => unreachable,
                .lea_direct => unreachable,
                .lea_tlv => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| try self.asmRegisterRegister(
                    .imul,
                    dst_alias,
                    registerAlias(src_reg, abi_size),
                ),
                .immediate => |imm| {
                    if (math.cast(i32, imm)) |small| {
                        try self.asmRegisterRegisterImmediate(
                            .imul,
                            dst_alias,
                            dst_alias,
                            Immediate.s(small),
                        );
                    } else {
                        const src_reg = try self.copyToTmpRegister(dst_ty, src_mcv);
                        return self.genIntMulComplexOpMir(dst_ty, dst_mcv, MCValue{ .register = src_reg });
                    }
                },
                .stack_offset => |off| {
                    try self.asmRegisterMemory(
                        .imul,
                        dst_alias,
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -off }),
                    );
                },
                .memory,
                .load_got,
                .load_direct,
                .load_tlv,
                => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
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
                .lea_direct => unreachable,
                .lea_tlv => unreachable,
                .register_overflow => unreachable,
                .register => |src_reg| {
                    // copy dst to a register
                    const dst_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
                    try self.asmRegisterRegister(
                        .imul,
                        registerAlias(dst_reg, abi_size),
                        registerAlias(src_reg, abi_size),
                    );
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
                .memory,
                .load_got,
                .load_direct,
                .load_tlv,
                .stack_offset,
                => {
                    return self.fail("TODO implement x86 multiply source memory", .{});
                },
                .eflags => {
                    return self.fail("TODO implement x86 multiply source eflags", .{});
                },
            }
        },
        .memory,
        .load_got,
        .load_direct,
        .load_tlv,
        => {
            return self.fail("TODO implement x86 multiply destination memory", .{});
        },
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    // skip zero-bit arguments as they don't have a corresponding arg instruction
    var arg_index = self.arg_index;
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const ty = self.air.typeOfIndex(inst);
    const mcv = self.args[arg_index];
    const src_index = self.air.instructions.items(.data)[inst].arg.src_index;
    const name = self.mod_fn.getParamName(self.bin_file.options.module.?, src_index);

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const dst_mcv: MCValue = switch (mcv) {
            .register => |reg| blk: {
                self.register_manager.getRegAssumeFree(reg.to64(), inst);
                break :blk MCValue{ .register = reg };
            },
            .stack_offset => |off| blk: {
                const offset = @intCast(i32, self.max_end_stack) - off + 16;
                break :blk MCValue{ .stack_offset = -offset };
            },
            else => return self.fail("TODO implement arg for {}", .{mcv}),
        };
        try self.genArgDbgInfo(ty, name, dst_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn genArgDbgInfo(self: Self, ty: Type, name: [:0]const u8, mcv: MCValue) !void {
    switch (self.debug_output) {
        .dwarf => |dw| {
            const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (mcv) {
                .register => |reg| .{ .register = reg.dwarfLocOp() },
                .stack_offset => |off| .{
                    .stack = .{
                        // TODO handle -fomit-frame-pointer
                        .fp_register = Register.rbp.dwarfLocOpDeref(),
                        .offset = -off,
                    },
                },
                else => unreachable, // not a valid function parameter
            };
            try dw.genArgDbgInfo(name, ty, self.mod_fn.owner_decl, loc);
        },
        .plan9 => {},
        .none => {},
    }
}

fn genVarDbgInfo(
    self: Self,
    tag: Air.Inst.Tag,
    ty: Type,
    mcv: MCValue,
    name: [:0]const u8,
) !void {
    const is_ptr = switch (tag) {
        .dbg_var_ptr => true,
        .dbg_var_val => false,
        else => unreachable,
    };

    switch (self.debug_output) {
        .dwarf => |dw| {
            const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (mcv) {
                .register => |reg| .{ .register = reg.dwarfLocOp() },
                .ptr_stack_offset,
                .stack_offset,
                => |off| .{ .stack = .{
                    .fp_register = Register.rbp.dwarfLocOpDeref(),
                    .offset = -off,
                } },
                .memory => |address| .{ .memory = address },
                .load_got => |sym_index| .{ .linker_load = .{ .type = .got, .sym_index = sym_index } },
                .load_direct => |sym_index| .{ .linker_load = .{ .type = .direct, .sym_index = sym_index } },
                .immediate => |x| .{ .immediate = x },
                .undef => .undef,
                .none => .none,
                else => blk: {
                    log.debug("TODO generate debug info for {}", .{mcv});
                    break :blk .nop;
                },
            };
            try dw.genVarDbgInfo(name, ty, self.mod_fn.owner_decl, is_ptr, loc);
        },
        .plan9 => {},
        .none => {},
    }
}

fn airTrap(self: *Self) !void {
    try self.asmOpOnly(.ud2);
    return self.finishAirBookkeeping();
}

fn airBreakpoint(self: *Self) !void {
    try self.asmOpOnly(.int3);
    return self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const dst_mcv = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(Type.usize, dst_mcv, .{
            .stack_offset = -@as(i32, @divExact(self.target.cpu.arch.ptrBitWidth(), 8)),
        });
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const dst_mcv = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(Type.usize, dst_mcv, .{ .register = .rbp });
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFence(self: *Self, inst: Air.Inst.Index) !void {
    const order = self.air.instructions.items(.data)[inst].fence;
    switch (order) {
        .Unordered, .Monotonic => unreachable,
        .Acquire, .Release, .AcqRel => {},
        .SeqCst => try self.asmOpOnly(.mfence),
    }
    return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
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

    var info = try self.resolveCallingConventionValues(fn_ty, args[fn_ty.fnParamLen()..]);
    defer info.deinit(self);

    try self.spillEflagsIfOccupied();
    try self.spillRegisters(abi.getCallerPreservedRegs(self.target.*));

    // set stack arguments first because this can clobber registers
    // also clobber spill arguments as we go
    if (info.return_value == .stack_offset) {
        try self.spillRegisters(&.{abi.getCAbiIntParamRegs(self.target.*)[0]});
    }
    for (args, info.args) |arg, mc_arg| {
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);
        // Here we do not use setRegOrMem even though the logic is similar, because
        // the function call will move the stack pointer, so the offsets are different.
        switch (mc_arg) {
            .none => {},
            .register => |reg| try self.spillRegisters(&.{reg}),
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
            .eflags => unreachable,
            .register_overflow => unreachable,
            .load_got => unreachable,
            .lea_direct => unreachable,
            .load_direct => unreachable,
            .lea_tlv => unreachable,
            .load_tlv => unreachable,
        }
    }

    // now we are free to set register arguments
    const ret_reg_lock: ?RegisterLock = blk: {
        if (info.return_value == .stack_offset) {
            const ret_ty = fn_ty.fnReturnType();
            const ret_abi_size = @intCast(u32, ret_ty.abiSize(self.target.*));
            const ret_abi_align = @intCast(u32, ret_ty.abiAlignment(self.target.*));
            const stack_offset = @intCast(i32, try self.allocMem(inst, ret_abi_size, ret_abi_align));
            log.debug("airCall: return value on stack at offset {}", .{stack_offset});

            const ret_reg = abi.getCAbiIntParamRegs(self.target.*)[0];
            try self.genSetReg(Type.usize, ret_reg, .{ .ptr_stack_offset = stack_offset });
            const ret_reg_lock = self.register_manager.lockRegAssumeUnused(ret_reg);

            info.return_value.stack_offset = stack_offset;

            break :blk ret_reg_lock;
        }
        break :blk null;
    };
    defer if (ret_reg_lock) |lock| self.register_manager.unlockReg(lock);

    for (args, info.args) |arg, mc_arg| {
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);
        switch (mc_arg) {
            .none, .stack_offset, .ptr_stack_offset => {},
            .register => |reg| try self.genSetReg(arg_ty, reg, arg_mcv),
            .undef => unreachable,
            .immediate => unreachable,
            .unreach => unreachable,
            .dead => unreachable,
            .memory => unreachable,
            .eflags => unreachable,
            .register_overflow => unreachable,
            .load_got => unreachable,
            .lea_direct => unreachable,
            .load_direct => unreachable,
            .lea_tlv => unreachable,
            .load_tlv => unreachable,
        }
    }

    if (info.stack_byte_count > 0) {
        // Adjust the stack
        try self.asmRegisterImmediate(.sub, .rsp, Immediate.u(info.stack_byte_count));
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    const mod = self.bin_file.options.module.?;
    if (self.air.value(callee)) |func_value| {
        if (func_value.castTag(.function)) |func_payload| {
            const func = func_payload.data;

            if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                const atom_index = try elf_file.getOrCreateAtomForDecl(func.owner_decl);
                const got_addr = elf_file.getAtom(atom_index).getOffsetTableAddress(elf_file);
                try self.asmMemory(.call, Memory.sib(.qword, .{
                    .base = .ds,
                    .disp = @intCast(i32, got_addr),
                }));
            } else if (self.bin_file.cast(link.File.Coff)) |_| {
                const sym_index = try self.getSymbolIndexForDecl(func.owner_decl);
                try self.genSetReg(Type.usize, .rax, .{ .load_got = sym_index });
                try self.asmRegister(.call, .rax);
            } else if (self.bin_file.cast(link.File.MachO)) |_| {
                const sym_index = try self.getSymbolIndexForDecl(func.owner_decl);
                try self.genSetReg(Type.usize, .rax, .{ .load_got = sym_index });
                try self.asmRegister(.call, .rax);
            } else if (self.bin_file.cast(link.File.Plan9)) |p9| {
                const decl_block_index = try p9.seeDecl(func.owner_decl);
                const decl_block = p9.getDeclBlock(decl_block_index);
                const ptr_bits = self.target.cpu.arch.ptrBitWidth();
                const ptr_bytes: u64 = @divExact(ptr_bits, 8);
                const got_addr = p9.bases.data;
                const got_index = decl_block.got_index.?;
                const fn_got_addr = got_addr + got_index * ptr_bytes;
                try self.asmMemory(.call, Memory.sib(.qword, .{
                    .base = .ds,
                    .disp = @intCast(i32, fn_got_addr),
                }));
            } else unreachable;
        } else if (func_value.castTag(.extern_fn)) |func_payload| {
            const extern_fn = func_payload.data;
            const decl_name = mem.sliceTo(mod.declPtr(extern_fn.owner_decl).name, 0);
            const lib_name = mem.sliceTo(extern_fn.lib_name, 0);
            if (self.bin_file.cast(link.File.Coff)) |coff_file| {
                const atom_index = try self.getSymbolIndexForDecl(self.mod_fn.owner_decl);
                const sym_index = try coff_file.getGlobalSymbol(decl_name, lib_name);
                _ = try self.addInst(.{
                    .tag = .mov_linker,
                    .ops = .import_reloc,
                    .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                        .reg = @enumToInt(Register.rax),
                        .atom_index = atom_index,
                        .sym_index = sym_index,
                    }) },
                });
                try self.asmRegister(.call, .rax);
            } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                const sym_index = try macho_file.getGlobalSymbol(decl_name, lib_name);
                const atom_index = try self.getSymbolIndexForDecl(self.mod_fn.owner_decl);
                _ = try self.addInst(.{
                    .tag = .call_extern,
                    .ops = undefined,
                    .data = .{ .relocation = .{
                        .atom_index = atom_index,
                        .sym_index = sym_index,
                    } },
                });
            } else {
                return self.fail("TODO implement calling extern functions", .{});
            }
        } else {
            return self.fail("TODO implement calling bitcasted functions", .{});
        }
    } else {
        assert(ty.zigTypeTag() == .Pointer);
        const mcv = try self.resolveInst(callee);
        try self.genSetReg(Type.usize, .rax, mcv);
        try self.asmRegister(.call, .rax);
    }

    if (info.stack_byte_count > 0) {
        // Readjust the stack
        try self.asmRegisterImmediate(.add, .rsp, Immediate.u(info.stack_byte_count));
    }

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

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
            try self.store(self.ret_mcv, operand, Type.usize, ret_ty);
        },
        else => {
            try self.setRegOrMem(ret_ty, self.ret_mcv, operand);
        },
    }
    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ptr = try self.resolveInst(un_op);
    const ptr_ty = self.air.typeOf(un_op);
    const elem_ty = ptr_ty.elemType();
    const abi_size = elem_ty.abiSize(self.target.*);
    switch (self.ret_mcv) {
        .immediate => {
            assert(elem_ty.isError());
        },
        .stack_offset => {
            const reg = try self.copyToTmpRegister(Type.usize, self.ret_mcv);
            const reg_lock = self.register_manager.lockRegAssumeUnused(reg);
            defer self.register_manager.unlockReg(reg_lock);

            try self.genInlineMemcpy(.{ .register = reg }, ptr, .{ .immediate = abi_size }, .{});
        },
        else => {
            try self.load(self.ret_mcv, ptr, ptr_ty);
            try self.setRegOrMem(elem_ty, self.ret_mcv, self.ret_mcv);
        },
    }
    // TODO when implementing defer, this will need to jump to the appropriate defer expression.
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .dead, .{ un_op, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const ty = self.air.typeOf(bin_op.lhs);
        const ty_abi_size = ty.abiSize(self.target.*);
        const can_reuse = ty_abi_size <= 8;

        try self.spillEflagsIfOccupied();
        self.eflags_inst = inst;

        const lhs_mcv = try self.resolveInst(bin_op.lhs);
        const lhs_lock = switch (lhs_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_mcv = try self.resolveInst(bin_op.rhs);
        const rhs_lock = switch (rhs_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mem_ok = !ty.isRuntimeFloat();
        var flipped = false;
        const dst_mcv: MCValue = if (can_reuse and !lhs_mcv.isImmediate() and
            (dst_mem_ok or lhs_mcv.isRegister()) and self.liveness.operandDies(inst, 0))
            lhs_mcv
        else if (can_reuse and !rhs_mcv.isImmediate() and
            (dst_mem_ok or rhs_mcv.isRegister()) and self.liveness.operandDies(inst, 1))
        dst: {
            flipped = true;
            break :dst rhs_mcv;
        } else if (dst_mem_ok) dst: {
            const dst_mcv = try self.allocTempRegOrMem(ty, true);
            try self.setRegOrMem(ty, dst_mcv, lhs_mcv);
            break :dst dst_mcv;
        } else .{ .register = try self.copyToTmpRegister(ty, lhs_mcv) };
        const dst_lock = switch (dst_mcv) {
            .register => |reg| self.register_manager.lockReg(reg),
            else => null,
        };
        defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

        const src_mcv = if (flipped) lhs_mcv else rhs_mcv;
        try self.genBinOpMir(switch (ty.tag()) {
            else => .cmp,
            .f32 => .ucomiss,
            .f64 => .ucomisd,
        }, ty, dst_mcv, src_mcv);

        const signedness = if (ty.isAbiInt()) ty.intInfo(self.target.*).signedness else .unsigned;
        break :result .{
            .eflags = Condition.fromCompareOperator(signedness, if (flipped) op.reverse() else op),
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const addr_reg = try self.register_manager.allocReg(null, gp);
        const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
        defer self.register_manager.unlockReg(addr_lock);

        if (self.bin_file.cast(link.File.Elf)) |elf_file| {
            const atom_index = try elf_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const got_addr = elf_file.getAtom(atom_index).getOffsetTableAddress(elf_file);
            try self.asmRegisterMemory(.mov, addr_reg.to64(), Memory.sib(.qword, .{
                .base = .ds,
                .disp = @intCast(i32, got_addr),
            }));
        } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
            const atom_index = try coff_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
            try self.genSetReg(Type.usize, addr_reg, .{ .load_got = sym_index });
        } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
            const atom_index = try macho_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const sym_index = macho_file.getAtom(atom_index).getSymbolIndex().?;
            try self.genSetReg(Type.usize, addr_reg, .{ .load_got = sym_index });
        } else {
            return self.fail("TODO implement airErrorName for x86_64 {s}", .{@tagName(self.bin_file.tag)});
        }

        try self.spillEflagsIfOccupied();
        self.eflags_inst = inst;

        const op_ty = self.air.typeOf(un_op);
        const op_abi_size = @intCast(u32, op_ty.abiSize(self.target.*));
        const op_mcv = try self.resolveInst(un_op);
        const dst_reg = switch (op_mcv) {
            .register => |reg| reg,
            else => try self.copyToTmpRegister(op_ty, op_mcv),
        };
        try self.asmRegisterMemory(
            .cmp,
            registerAlias(dst_reg, op_abi_size),
            Memory.sib(Memory.PtrSize.fromSize(op_abi_size), .{ .base = addr_reg }),
        );
        break :result .{ .eflags = .b };
    };
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
    const result = if (self.liveness.isUnused(inst))
        .dead
    else
        try self.genUnwrapErrorUnionPayloadMir(inst, err_union_ty, err_union);
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
    try self.genVarDbgInfo(tag, ty, mcv, name);

    return self.finishAir(inst, .dead, .{ operand, .none, .none });
}

fn genCondBrMir(self: *Self, ty: Type, mcv: MCValue) !u32 {
    const abi_size = ty.abiSize(self.target.*);
    switch (mcv) {
        .eflags => |cc| {
            // Here we map the opposites since the jump is to the false branch.
            return self.asmJccReloc(undefined, cc.negate());
        },
        .register => |reg| {
            try self.spillEflagsIfOccupied();
            try self.asmRegisterImmediate(.@"test", reg, Immediate.u(1));
            return self.asmJccReloc(undefined, .e);
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
    return 0; // TODO
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
        if (Air.refToIndex(pl_op.operand)) |op_inst| self.processDeath(op_inst);
    }

    // Capture the state of register and stack allocation state so that we can revert to it.
    const saved_state = self.captureState();

    {
        try self.branch_stack.append(.{});
        errdefer _ = self.branch_stack.pop();

        try self.ensureProcessDeathCapacity(liveness_condbr.then_deaths.len);
        for (liveness_condbr.then_deaths) |operand| {
            self.processDeath(operand);
        }
        try self.genBody(then_body);
    }

    // Revert to the previous register and stack allocation state.

    var then_branch = self.branch_stack.pop();
    defer then_branch.deinit(self.gpa);

    self.revertState(saved_state);

    try self.performReloc(reloc);

    {
        try self.branch_stack.append(.{});
        errdefer _ = self.branch_stack.pop();

        try self.ensureProcessDeathCapacity(liveness_condbr.else_deaths.len);
        for (liveness_condbr.else_deaths) |operand| {
            self.processDeath(operand);
        }
        try self.genBody(else_body);
    }

    var else_branch = self.branch_stack.pop();
    defer else_branch.deinit(self.gpa);

    // At this point, each branch will possibly have conflicting values for where
    // each instruction is stored. They agree, however, on which instructions are alive/dead.
    // We use the first ("then") branch as canonical, and here emit
    // instructions into the second ("else") branch to make it conform.
    // We continue respect the data structure semantic guarantees of the else_branch so
    // that we can use all the code emitting abstractions. This is why at the bottom we
    // assert that parent_branch.free_registers equals the saved_then_branch.free_registers
    // rather than assigning it.
    log.debug("airCondBr: %{d}", .{inst});
    log.debug("Upper branches:", .{});
    for (self.branch_stack.items) |bs| {
        log.debug("{}", .{bs.fmtDebug()});
    }
    log.debug("Then branch: {}", .{then_branch.fmtDebug()});
    log.debug("Else branch: {}", .{else_branch.fmtDebug()});

    try self.canonicaliseBranches(true, &then_branch, &else_branch, true, true);

    // We already took care of pl_op.operand earlier, so we're going
    // to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn isNull(self: *Self, inst: Air.Inst.Index, opt_ty: Type, opt_mcv: MCValue) !MCValue {
    switch (opt_mcv) {
        .register_overflow => |ro| return .{ .eflags = ro.eflags.negate() },
        else => {},
    }

    try self.spillEflagsIfOccupied();
    self.eflags_inst = inst;

    var pl_buf: Type.Payload.ElemType = undefined;
    const pl_ty = opt_ty.optionalChild(&pl_buf);

    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const some_info: struct { off: i32, ty: Type } = if (opt_ty.optionalReprIsPayload())
        .{ .off = 0, .ty = if (pl_ty.isSlice()) pl_ty.slicePtrFieldType(&ptr_buf) else pl_ty }
    else
        .{ .off = @intCast(i32, pl_ty.abiSize(self.target.*)), .ty = Type.bool };

    switch (opt_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .register_overflow,
        .ptr_stack_offset,
        .eflags,
        .lea_direct,
        .lea_tlv,
        => unreachable,

        .register => |opt_reg| {
            if (some_info.off == 0) {
                const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
                const alias_reg = registerAlias(opt_reg, some_abi_size);
                assert(some_abi_size * 8 == alias_reg.bitSize());
                try self.asmRegisterRegister(.@"test", alias_reg, alias_reg);
                return .{ .eflags = .z };
            }
            assert(some_info.ty.tag() == .bool);
            const opt_abi_size = @intCast(u32, opt_ty.abiSize(self.target.*));
            try self.asmRegisterImmediate(
                .bt,
                registerAlias(opt_reg, opt_abi_size),
                Immediate.u(@intCast(u6, some_info.off * 8)),
            );
            return .{ .eflags = .nc };
        },

        .memory,
        .load_got,
        .load_direct,
        .load_tlv,
        => {
            const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.genSetReg(Type.usize, addr_reg, switch (opt_mcv) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => opt_mcv,
            });

            const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
            try self.asmMemoryImmediate(.cmp, Memory.sib(
                Memory.PtrSize.fromSize(some_abi_size),
                .{ .base = addr_reg, .disp = some_info.off },
            ), Immediate.u(0));
            return .{ .eflags = .e };
        },

        .stack_offset => |off| {
            const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
            try self.asmMemoryImmediate(.cmp, Memory.sib(
                Memory.PtrSize.fromSize(some_abi_size),
                .{ .base = .rbp, .disp = some_info.off - off },
            ), Immediate.u(0));
            return .{ .eflags = .e };
        },
    }
}

fn isNullPtr(self: *Self, inst: Air.Inst.Index, ptr_ty: Type, ptr_mcv: MCValue) !MCValue {
    try self.spillEflagsIfOccupied();
    self.eflags_inst = inst;

    const opt_ty = ptr_ty.childType();
    var pl_buf: Type.Payload.ElemType = undefined;
    const pl_ty = opt_ty.optionalChild(&pl_buf);

    var ptr_buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const some_info: struct { off: i32, ty: Type } = if (opt_ty.optionalReprIsPayload())
        .{ .off = 0, .ty = if (pl_ty.isSlice()) pl_ty.slicePtrFieldType(&ptr_buf) else pl_ty }
    else
        .{ .off = @intCast(i32, pl_ty.abiSize(self.target.*)), .ty = Type.bool };

    const ptr_reg = switch (ptr_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(ptr_ty, ptr_mcv),
    };
    const ptr_lock = self.register_manager.lockReg(ptr_reg);
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
    try self.asmMemoryImmediate(.cmp, Memory.sib(
        Memory.PtrSize.fromSize(some_abi_size),
        .{ .base = ptr_reg, .disp = some_info.off },
    ), Immediate.u(0));
    return .{ .eflags = .e };
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
            const eu_lock = self.register_manager.lockReg(reg);
            defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

            const tmp_reg = try self.copyToTmpRegister(ty, operand);
            if (err_off > 0) {
                const shift = @intCast(u6, err_off * 8);
                try self.genShiftBinOpMir(.shr, ty, .{ .register = tmp_reg }, .{ .immediate = shift });
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result try self.isNullPtr(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result switch (try self.isNull(inst, ty, operand)) {
            .eflags => |cc| .{ .eflags = cc.negate() },
            else => unreachable,
        };
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.air.typeOf(un_op);
        break :result switch (try self.isNullPtr(inst, ty, operand)) {
            .eflags => |cc| .{ .eflags = cc.negate() },
            else => unreachable,
        };
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
    const liveness_loop = self.liveness.getLoop(inst);

    {
        try self.branch_stack.append(.{});
        errdefer _ = self.branch_stack.pop();

        try self.genBody(body);
    }

    var branch = self.branch_stack.pop();
    defer branch.deinit(self.gpa);

    log.debug("airLoop: %{d}", .{inst});
    log.debug("Upper branches:", .{});
    for (self.branch_stack.items) |bs| {
        log.debug("{}", .{bs.fmtDebug()});
    }
    log.debug("Loop branch: {}", .{branch.fmtDebug()});

    var dummy_branch = Branch{};
    defer dummy_branch.deinit(self.gpa);
    try self.canonicaliseBranches(true, &dummy_branch, &branch, true, false);

    _ = try self.asmJmpReloc(jmp_target);

    try self.ensureProcessDeathCapacity(liveness_loop.deaths.len);
    for (liveness_loop.deaths) |operand| {
        self.processDeath(operand);
    }

    return self.finishAirBookkeeping();
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
    // A block is a setup to be able to jump to the end.
    const branch_depth = @intCast(u32, self.branch_stack.items.len);
    try self.blocks.putNoClobber(self.gpa, inst, .{ .branch_depth = branch_depth });
    defer {
        var block_data = self.blocks.fetchRemove(inst).?.value;
        block_data.deinit(self.gpa);
    }

    const ty = self.air.typeOfIndex(inst);
    const unused = !ty.hasRuntimeBitsIgnoreComptime() or self.liveness.isUnused(inst);

    {
        // Here we use `.none` to represent a null value so that the first break
        // instruction will choose a MCValue for the block result and overwrite
        // this field. Following break instructions will use that MCValue to put
        // their block results.
        const result: MCValue = if (unused) .dead else .none;
        const branch = &self.branch_stack.items[branch_depth - 1];
        try branch.inst_table.putNoClobber(self.gpa, inst, result);
    }

    {
        try self.branch_stack.append(.{});
        errdefer _ = self.branch_stack.pop();

        const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
        const extra = self.air.extraData(Air.Block, ty_pl.payload);
        const body = self.air.extra[extra.end..][0..extra.data.body_len];
        try self.genBody(body);
    }

    const block_data = self.blocks.getPtr(inst).?;
    const target_branch = self.branch_stack.pop();

    log.debug("airBlock: %{d}", .{inst});
    log.debug("Upper branches:", .{});
    for (self.branch_stack.items) |bs| {
        log.debug("{}", .{bs.fmtDebug()});
    }
    log.debug("Block branch: {}", .{block_data.branch.fmtDebug()});
    log.debug("Target branch: {}", .{target_branch.fmtDebug()});

    try self.canonicaliseBranches(true, &block_data.branch, &target_branch, false, false);

    for (block_data.relocs.items) |reloc| try self.performReloc(reloc);

    const result = if (unused) .dead else self.getResolvedInstValue(inst).?.*;
    self.getValue(result, inst);
    self.finishAirBookkeeping();
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
        if (Air.refToIndex(pl_op.operand)) |op_inst| self.processDeath(op_inst);
    }

    log.debug("airSwitch: %{d}", .{inst});
    log.debug("Upper branches:", .{});
    for (self.branch_stack.items) |bs| {
        log.debug("{}", .{bs.fmtDebug()});
    }

    var prev_branch: ?Branch = null;
    defer if (prev_branch) |*branch| branch.deinit(self.gpa);

    // Capture the state of register and stack allocation state so that we can revert to it.
    const saved_state = self.captureState();

    const cases_len = switch_br.data.cases_len + @boolToInt(switch_br.data.else_body_len > 0);
    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast([]const Air.Inst.Ref, self.air.extra[case.end..][0..case.data.items_len]);
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;

        // Revert to the previous register and stack allocation state.
        if (prev_branch) |_| self.revertState(saved_state);

        var relocs = try self.gpa.alloc(u32, items.len);
        defer self.gpa.free(relocs);

        for (items, relocs) |item, *reloc| {
            try self.spillEflagsIfOccupied();
            const item_mcv = try self.resolveInst(item);
            try self.genBinOpMir(.cmp, condition_ty, condition, item_mcv);
            reloc.* = try self.asmJccReloc(undefined, .ne);
        }

        {
            if (cases_len > 1) try self.branch_stack.append(.{});
            errdefer _ = if (cases_len > 1) self.branch_stack.pop();

            try self.ensureProcessDeathCapacity(liveness.deaths[case_i].len);
            for (liveness.deaths[case_i]) |operand| {
                self.processDeath(operand);
            }

            try self.genBody(case_body);
        }

        // Consolidate returned MCValues between prongs like we do in airCondBr.
        if (cases_len > 1) {
            var case_branch = self.branch_stack.pop();
            errdefer case_branch.deinit(self.gpa);

            log.debug("Case-{d} branch: {}", .{ case_i, case_branch.fmtDebug() });
            const final = case_i == cases_len - 1;
            if (prev_branch) |*canon_branch| {
                try self.canonicaliseBranches(final, canon_branch, &case_branch, true, true);
                canon_branch.deinit(self.gpa);
            }
            prev_branch = case_branch;
        }

        for (relocs) |reloc| try self.performReloc(reloc);
    }

    if (switch_br.data.else_body_len > 0) {
        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];

        // Revert to the previous register and stack allocation state.
        if (prev_branch) |_| self.revertState(saved_state);

        {
            if (cases_len > 1) try self.branch_stack.append(.{});
            errdefer _ = if (cases_len > 1) self.branch_stack.pop();

            const else_deaths = liveness.deaths.len - 1;
            try self.ensureProcessDeathCapacity(liveness.deaths[else_deaths].len);
            for (liveness.deaths[else_deaths]) |operand| {
                self.processDeath(operand);
            }

            try self.genBody(else_body);
        }

        // Consolidate returned MCValues between a prong and the else branch like we do in airCondBr.
        if (cases_len > 1) {
            var else_branch = self.branch_stack.pop();
            errdefer else_branch.deinit(self.gpa);

            log.debug("Else branch: {}", .{else_branch.fmtDebug()});
            if (prev_branch) |*canon_branch| {
                try self.canonicaliseBranches(true, canon_branch, &else_branch, true, true);
                canon_branch.deinit(self.gpa);
            }
            prev_branch = else_branch;
        }
    }

    // We already took care of pl_op.operand earlier, so we're going to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn canonicaliseBranches(
    self: *Self,
    update_parent: bool,
    canon_branch: *Branch,
    target_branch: *const Branch,
    comptime set_values: bool,
    comptime assert_same_deaths: bool,
) !void {
    var hazard_map = std.AutoHashMap(MCValue, void).init(self.gpa);
    defer hazard_map.deinit();

    const parent_branch =
        if (update_parent) &self.branch_stack.items[self.branch_stack.items.len - 1] else undefined;

    if (update_parent) try self.ensureProcessDeathCapacity(target_branch.inst_table.count());
    var target_it = target_branch.inst_table.iterator();
    while (target_it.next()) |target_entry| {
        const target_key = target_entry.key_ptr.*;
        const target_value = target_entry.value_ptr.*;
        const canon_mcv = if (canon_branch.inst_table.fetchSwapRemove(target_key)) |canon_entry| blk: {
            // The instruction's MCValue is overridden in both branches.
            if (target_value == .dead) {
                if (update_parent) {
                    parent_branch.inst_table.putAssumeCapacity(target_key, .dead);
                }
                if (assert_same_deaths) assert(canon_entry.value == .dead);
                continue;
            }
            if (update_parent) {
                parent_branch.inst_table.putAssumeCapacity(target_key, canon_entry.value);
            }
            break :blk canon_entry.value;
        } else blk: {
            if (target_value == .dead) {
                if (update_parent) {
                    parent_branch.inst_table.putAssumeCapacity(target_key, .dead);
                }
                continue;
            }
            // The instruction is only overridden in the else branch.
            // If integer overflow occurs, the question is: why wasn't the instruction marked dead?
            break :blk self.getResolvedInstValue(target_key).?.*;
        };
        log.debug("consolidating target_entry %{d} {}=>{}", .{ target_key, target_value, canon_mcv });
        // TODO handle the case where the destination stack offset / register has something
        // going on there.
        assert(!hazard_map.contains(target_value));
        try hazard_map.putNoClobber(canon_mcv, {});
        if (set_values) {
            try self.setRegOrMem(self.air.typeOfIndex(target_key), canon_mcv, target_value);
        } else self.getValue(canon_mcv, target_key);
        self.freeValue(target_value);
        // TODO track the new register / stack allocation
    }

    if (update_parent) try self.ensureProcessDeathCapacity(canon_branch.inst_table.count());
    var canon_it = canon_branch.inst_table.iterator();
    while (canon_it.next()) |canon_entry| {
        const canon_key = canon_entry.key_ptr.*;
        const canon_value = canon_entry.value_ptr.*;
        // We already deleted the items from this table that matched the target_branch.
        // So these are all instructions that are only overridden in the canon branch.
        const parent_mcv =
            if (canon_value != .dead) self.getResolvedInstValue(canon_key).?.* else undefined;
        if (canon_value != .dead) {
            log.debug("consolidating canon_entry %{d} {}=>{}", .{ canon_key, parent_mcv, canon_value });
            // TODO handle the case where the destination stack offset / register has something
            // going on there.
            assert(!hazard_map.contains(parent_mcv));
            try hazard_map.putNoClobber(canon_value, {});
            if (set_values) {
                try self.setRegOrMem(self.air.typeOfIndex(canon_key), canon_value, parent_mcv);
            } else self.getValue(canon_value, canon_key);
            self.freeValue(parent_mcv);
            // TODO track the new register / stack allocation
        }
        if (update_parent) {
            parent_branch.inst_table.putAssumeCapacity(canon_key, canon_value);
        }
    }
}

fn performReloc(self: *Self, reloc: Mir.Inst.Index) !void {
    const next_inst = @intCast(u32, self.mir_instructions.len);
    switch (self.mir_instructions.items(.tag)[reloc]) {
        .jcc => {
            self.mir_instructions.items(.data)[reloc].inst_cc.inst = next_inst;
        },
        .jmp_reloc => {
            self.mir_instructions.items(.data)[reloc].inst = next_inst;
        },
        else => unreachable,
    }
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const br = self.air.instructions.items(.data)[inst].br;
    const block = br.block_inst;

    // The first break instruction encounters `.none` here and chooses a
    // machine code value for the block result, populating this field.
    // Following break instructions encounter that value and use it for
    // the location to store their block results.
    if (self.getResolvedInstValue(block)) |dst_mcv| {
        const src_mcv = try self.resolveInst(br.operand);
        switch (dst_mcv.*) {
            .none => {
                const result = result: {
                    if (self.reuseOperand(inst, br.operand, 0, src_mcv)) break :result src_mcv;

                    const new_mcv = try self.allocRegOrMem(block, true);
                    try self.setRegOrMem(self.air.typeOfIndex(block), new_mcv, src_mcv);
                    break :result new_mcv;
                };
                dst_mcv.* = result;
                self.freeValue(result);
            },
            else => try self.setRegOrMem(self.air.typeOfIndex(block), dst_mcv.*, src_mcv),
        }
    }

    // Process operand death early so that it is properly accounted for in the Branch below.
    if (self.liveness.operandDies(inst, 0)) {
        if (Air.refToIndex(br.operand)) |op_inst| self.processDeath(op_inst);
    }

    const block_data = self.blocks.getPtr(block).?;
    {
        var branch = Branch{};
        errdefer branch.deinit(self.gpa);

        var branch_i = self.branch_stack.items.len - 1;
        while (branch_i >= block_data.branch_depth) : (branch_i -= 1) {
            const table = &self.branch_stack.items[branch_i].inst_table;
            try branch.inst_table.ensureUnusedCapacity(self.gpa, table.count());
            var it = table.iterator();
            while (it.next()) |entry| {
                // This loop could be avoided by tracking inst depth, which
                // will be needed later anyway for reusing loop deaths.
                var parent_branch_i = block_data.branch_depth - 1;
                while (parent_branch_i > 0) : (parent_branch_i -= 1) {
                    const parent_table = &self.branch_stack.items[parent_branch_i].inst_table;
                    if (parent_table.contains(entry.key_ptr.*)) break;
                } else continue;
                const gop = branch.inst_table.getOrPutAssumeCapacity(entry.key_ptr.*);
                if (!gop.found_existing) gop.value_ptr.* = entry.value_ptr.*;
            }
        }

        log.debug("airBr: %{d}", .{inst});
        log.debug("Upper branches:", .{});
        for (self.branch_stack.items) |bs| {
            log.debug("{}", .{bs.fmtDebug()});
        }
        log.debug("Prev branch: {}", .{block_data.branch.fmtDebug()});
        log.debug("Cur branch: {}", .{branch.fmtDebug()});

        try self.canonicaliseBranches(false, &block_data.branch, &branch, true, false);
        block_data.branch.deinit(self.gpa);
        block_data.branch = branch;
    }

    // Emit a jump with a relocation. It will be patched up after the block ends.
    try block_data.relocs.ensureUnusedCapacity(self.gpa, 1);
    // Leave the jump offset undefined
    const jmp_reloc = try self.asmJmpReloc(undefined);
    block_data.relocs.appendAssumeCapacity(jmp_reloc);

    self.finishAirBookkeeping();
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

    var result: MCValue = .none;
    if (!is_volatile and self.liveness.isUnused(inst)) result = .dead else {
        var args = std.StringArrayHashMap(MCValue).init(self.gpa);
        try args.ensureTotalCapacity(outputs.len + inputs.len + clobbers_len);
        defer {
            for (args.values()) |arg| switch (arg) {
                .register => |reg| self.register_manager.unlockReg(.{ .register = reg }),
                else => {},
            };
            args.deinit();
        }

        if (outputs.len > 1) {
            return self.fail("TODO implement codegen for asm with more than 1 output", .{});
        }

        for (outputs) |output| {
            if (output != .none) {
                return self.fail("TODO implement codegen for non-expr asm", .{});
            }
            const extra_bytes = std.mem.sliceAsBytes(self.air.extra[extra_i..]);
            const constraint = std.mem.sliceTo(std.mem.sliceAsBytes(self.air.extra[extra_i..]), 0);
            const name = std.mem.sliceTo(extra_bytes[constraint.len + 1 ..], 0);
            // This equation accounts for the fact that even if we have exactly 4 bytes
            // for the string, we still use the next u32 for the null terminator.
            extra_i += (constraint.len + name.len + (2 + 3)) / 4;

            const mcv: MCValue = if (mem.eql(u8, constraint, "=r"))
                .{ .register = self.register_manager.tryAllocReg(inst, gp) orelse
                    return self.fail("ran out of registers lowering inline asm", .{}) }
            else if (mem.startsWith(u8, constraint, "={") and mem.endsWith(u8, constraint, "}"))
                .{ .register = parseRegName(constraint["={".len .. constraint.len - "}".len]) orelse
                    return self.fail("unrecognized register constraint: '{s}'", .{constraint}) }
            else
                return self.fail("unrecognized constraint: '{s}'", .{constraint});
            args.putAssumeCapacity(name, mcv);
            switch (mcv) {
                .register => |reg| _ = if (RegisterManager.indexOfRegIntoTracked(reg)) |_|
                    self.register_manager.lockRegAssumeUnused(reg),
                else => {},
            }
            if (output == .none) result = mcv;
        }

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

        const asm_source = mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];
        var line_it = mem.tokenize(u8, asm_source, "\n\r;");
        while (line_it.next()) |line| {
            var mnem_it = mem.tokenize(u8, line, " \t");
            const mnem_str = mnem_it.next() orelse continue;
            if (mem.startsWith(u8, mnem_str, "#")) continue;

            const mnem_size: ?Memory.PtrSize = if (mem.endsWith(u8, mnem_str, "b"))
                .byte
            else if (mem.endsWith(u8, mnem_str, "w"))
                .word
            else if (mem.endsWith(u8, mnem_str, "l"))
                .dword
            else if (mem.endsWith(u8, mnem_str, "q"))
                .qword
            else
                null;
            const mnem = std.meta.stringToEnum(Mir.Inst.Tag, mnem_str) orelse
                (if (mnem_size) |_|
                std.meta.stringToEnum(Mir.Inst.Tag, mnem_str[0 .. mnem_str.len - 1])
            else
                null) orelse return self.fail("Invalid mnemonic: '{s}'", .{mnem_str});

            var op_it = mem.tokenize(u8, mnem_it.rest(), ",");
            var ops = [1]encoder.Instruction.Operand{.none} ** 4;
            for (&ops) |*op| {
                const op_str = mem.trim(u8, op_it.next() orelse break, " \t");
                if (mem.startsWith(u8, op_str, "#")) break;
                if (mem.startsWith(u8, op_str, "%%")) {
                    const colon = mem.indexOfScalarPos(u8, op_str, "%%".len + 2, ':');
                    const reg = parseRegName(op_str["%%".len .. colon orelse op_str.len]) orelse
                        return self.fail("Invalid register: '{s}'", .{op_str});
                    if (colon) |colon_pos| {
                        const disp = std.fmt.parseInt(i32, op_str[colon_pos + 1 ..], 0) catch
                            return self.fail("Invalid displacement: '{s}'", .{op_str});
                        op.* = .{ .mem = Memory.sib(
                            mnem_size orelse return self.fail("Unknown size: '{s}'", .{op_str}),
                            .{ .base = reg, .disp = disp },
                        ) };
                    } else {
                        if (mnem_size) |size| if (reg.bitSize() != size.bitSize())
                            return self.fail("Invalid register size: '{s}'", .{op_str});
                        op.* = .{ .reg = reg };
                    }
                } else if (mem.startsWith(u8, op_str, "%[") and mem.endsWith(u8, op_str, "]")) {
                    switch (args.get(op_str["%[".len .. op_str.len - "]".len]) orelse
                        return self.fail("No matching constraint: '{s}'", .{op_str})) {
                        .register => |reg| op.* = .{ .reg = reg },
                        else => return self.fail("Invalid constraint: '{s}'", .{op_str}),
                    }
                } else if (mem.startsWith(u8, op_str, "$")) {
                    if (std.fmt.parseInt(i32, op_str["$".len..], 0)) |s| {
                        if (mnem_size) |size| {
                            const max = @as(u64, math.maxInt(u64)) >>
                                @intCast(u6, 64 - (size.bitSize() - 1));
                            if ((if (s < 0) ~s else s) > max)
                                return self.fail("Invalid immediate size: '{s}'", .{op_str});
                        }
                        op.* = .{ .imm = Immediate.s(s) };
                    } else |_| if (std.fmt.parseInt(u64, op_str["$".len..], 0)) |u| {
                        if (mnem_size) |size| {
                            const max = @as(u64, math.maxInt(u64)) >>
                                @intCast(u6, 64 - size.bitSize());
                            if (u > max)
                                return self.fail("Invalid immediate size: '{s}'", .{op_str});
                        }
                        op.* = .{ .imm = Immediate.u(u) };
                    } else |_| return self.fail("Invalid immediate: '{s}'", .{op_str});
                } else return self.fail("Invalid operand: '{s}'", .{op_str});
            } else if (op_it.next()) |op_str| return self.fail("Extra operand: '{s}'", .{op_str});

            (switch (ops[0]) {
                .none => self.asmOpOnly(mnem),
                .reg => |reg0| switch (ops[1]) {
                    .none => self.asmRegister(mnem, reg0),
                    .reg => |reg1| switch (ops[2]) {
                        .none => self.asmRegisterRegister(mnem, reg1, reg0),
                        .reg => |reg2| switch (ops[3]) {
                            .none => self.asmRegisterRegisterRegister(mnem, reg2, reg1, reg0),
                            else => error.InvalidInstruction,
                        },
                        .mem => |mem2| switch (ops[3]) {
                            .none => self.asmMemoryRegisterRegister(mnem, mem2, reg1, reg0),
                            else => error.InvalidInstruction,
                        },
                        else => error.InvalidInstruction,
                    },
                    .mem => |mem1| switch (ops[2]) {
                        .none => self.asmMemoryRegister(mnem, mem1, reg0),
                        else => error.InvalidInstruction,
                    },
                    else => error.InvalidInstruction,
                },
                .mem => |mem0| switch (ops[1]) {
                    .none => self.asmMemory(mnem, mem0),
                    .reg => |reg1| switch (ops[2]) {
                        .none => self.asmRegisterMemory(mnem, reg1, mem0),
                        else => error.InvalidInstruction,
                    },
                    else => error.InvalidInstruction,
                },
                .imm => |imm0| switch (ops[1]) {
                    .none => self.asmImmediate(mnem, imm0),
                    .reg => |reg1| switch (ops[2]) {
                        .none => self.asmRegisterImmediate(mnem, reg1, imm0),
                        .reg => |reg2| switch (ops[3]) {
                            .none => self.asmRegisterRegisterImmediate(mnem, reg2, reg1, imm0),
                            else => error.InvalidInstruction,
                        },
                        .mem => |mem2| switch (ops[3]) {
                            .none => self.asmMemoryRegisterImmediate(mnem, mem2, reg1, imm0),
                            else => error.InvalidInstruction,
                        },
                        else => error.InvalidInstruction,
                    },
                    .mem => |mem1| switch (ops[2]) {
                        .none => self.asmMemoryImmediate(mnem, mem1, imm0),
                        else => error.InvalidInstruction,
                    },
                    else => error.InvalidInstruction,
                },
            }) catch |err| switch (err) {
                error.InvalidInstruction => return self.fail(
                    "Invalid instruction: '{s} {s} {s} {s} {s}'",
                    .{
                        @tagName(mnem),
                        @tagName(ops[0]),
                        @tagName(ops[1]),
                        @tagName(ops[2]),
                        @tagName(ops[3]),
                    },
                ),
                else => |e| return e,
            };
        }
    }

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
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return,
        .undef => {
            if (!self.wantSafety()) return; // The already existing value will do just fine.
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }
            try self.genInlineMemset(
                .{ .ptr_stack_offset = stack_offset },
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
                    // TODO
                    // We have a positive stack offset value but we want a twos complement negative
                    // offset from rbp, which is at the top of the stack frame.
                    const immediate = if (ty.isSignedInt())
                        Immediate.s(@intCast(i32, @bitCast(i64, imm)))
                    else
                        Immediate.u(@intCast(u32, imm));
                    try self.asmMemoryImmediate(.mov, Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                        .base = .rsp,
                        .disp = -stack_offset,
                    }), immediate);
                },
                8 => {
                    const reg = try self.copyToTmpRegister(ty, mcv);
                    return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
                },
                else => return self.fail("TODO implement inputs on stack for {} with abi size > 8", .{mcv}),
            }
        },
        .memory,
        .load_direct,
        .load_tlv,
        => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }

            const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genSetReg(Type.usize, addr_reg, switch (mcv) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => unreachable,
            });
            try self.genInlineMemcpy(
                .{ .ptr_stack_offset = stack_offset },
                .{ .register = addr_reg },
                .{ .immediate = abi_size },
                .{ .dest_stack_base = .rsp },
            );
        },
        .register => |reg| {
            switch (ty.zigTypeTag()) {
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail(
                                "TODO genSetStackArg for register for type {}",
                                .{ty.fmtDebug()},
                            ),
                        };
                        // TODO verify this
                        const ptr_size: Memory.PtrSize = switch (ty.tag()) {
                            .f32 => .dword,
                            .f64 => .qword,
                            else => unreachable,
                        };
                        return self.asmMemoryRegister(tag, Memory.sib(ptr_size, .{
                            .base = .rsp,
                            .disp = -stack_offset,
                        }), reg.to128());
                    }

                    return self.fail("TODO genSetStackArg for register with no intrinsics", .{});
                },
                else => {
                    try self.asmMemoryRegister(.mov, Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                        .base = .rsp,
                        .disp = -stack_offset,
                    }), registerAlias(reg, abi_size));
                },
            }
        },
        .ptr_stack_offset,
        .load_got,
        .lea_direct,
        .lea_tlv,
        => {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
        },
        .stack_offset => |mcv_off| {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, mcv);
                return self.genSetStackArg(ty, stack_offset, MCValue{ .register = reg });
            }

            try self.genInlineMemcpy(
                .{ .ptr_stack_offset = stack_offset },
                .{ .ptr_stack_offset = mcv_off },
                .{ .immediate = abi_size },
                .{ .dest_stack_base = .rsp },
            );
        },
    }
}

fn genSetStack(self: *Self, ty: Type, stack_offset: i32, mcv: MCValue, opts: InlineMemcpyOpts) InnerError!void {
    const base_reg = opts.dest_stack_base orelse .rbp;
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety()) return; // The already existing value will do just fine.
            // TODO Upgrade this to a memset call when we have that available.
            switch (abi_size) {
                1, 2, 4 => {
                    const value: u64 = switch (abi_size) {
                        1 => 0xaa,
                        2 => 0xaaaa,
                        4 => 0xaaaaaaaa,
                        else => unreachable,
                    };
                    return self.asmMemoryImmediate(.mov, Memory.sib(
                        Memory.PtrSize.fromSize(abi_size),
                        .{ .base = base_reg, .disp = -stack_offset },
                    ), Immediate.u(value));
                },
                8 => return self.genSetStack(
                    ty,
                    stack_offset,
                    .{ .immediate = 0xaaaaaaaaaaaaaaaa },
                    opts,
                ),
                else => |x| return self.genInlineMemset(
                    .{ .ptr_stack_offset = stack_offset },
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
            try self.asmSetccRegister(tmp_reg.to8(), ro.eflags);

            return self.genSetStack(
                overflow_bit_ty,
                stack_offset - @intCast(i32, overflow_bit_offset),
                .{ .register = tmp_reg.to8() },
                .{},
            );
        },
        .eflags => |cc| try self.asmSetccMemory(
            Memory.sib(.byte, .{ .base = base_reg, .disp = -stack_offset }),
            cc,
        ),
        .immediate => |imm| {
            // TODO
            switch (abi_size) {
                0 => {
                    assert(ty.isError());
                    try self.asmMemoryImmediate(.mov, Memory.sib(.byte, .{
                        .base = base_reg,
                        .disp = -stack_offset,
                    }), Immediate.u(@truncate(u8, imm)));
                },
                1, 2, 4 => {
                    const immediate = if (ty.isSignedInt())
                        Immediate.s(@truncate(i32, @bitCast(i64, imm)))
                    else
                        Immediate.u(@intCast(u32, imm));
                    try self.asmMemoryImmediate(.mov, Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                        .base = base_reg,
                        .disp = -stack_offset,
                    }), immediate);
                },
                3, 5...7 => unreachable,
                else => {
                    // 64 bit write to memory would take two mov's anyways so we
                    // insted just use two 32 bit writes to avoid register allocation
                    if (math.cast(i32, @bitCast(i64, imm))) |small| {
                        try self.asmMemoryImmediate(.mov, Memory.sib(
                            Memory.PtrSize.fromSize(abi_size),
                            .{ .base = base_reg, .disp = -stack_offset },
                        ), Immediate.s(small));
                    } else {
                        var offset: i32 = 0;
                        while (offset < abi_size) : (offset += 4) try self.asmMemoryImmediate(
                            .mov,
                            Memory.sib(.dword, .{ .base = base_reg, .disp = offset - stack_offset }),
                            if (ty.isSignedInt())
                                Immediate.s(@truncate(
                                    i32,
                                    @bitCast(i64, imm) >> (math.cast(u6, offset * 8) orelse 63),
                                ))
                            else
                                Immediate.u(@truncate(
                                    u32,
                                    if (math.cast(u6, offset * 8)) |shift| imm >> shift else 0,
                                )),
                        );
                    }
                },
            }
        },
        .register => |reg| {
            switch (ty.zigTypeTag()) {
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail(
                                "TODO genSetStack for register for type {}",
                                .{ty.fmtDebug()},
                            ),
                        };
                        const ptr_size: Memory.PtrSize = switch (ty.tag()) {
                            .f32 => .dword,
                            .f64 => .qword,
                            else => unreachable,
                        };
                        return self.asmMemoryRegister(tag, Memory.sib(ptr_size, .{
                            .base = base_reg.to64(),
                            .disp = -stack_offset,
                        }), reg.to128());
                    }

                    return self.fail("TODO genSetStack for register for type float with no intrinsics", .{});
                },
                else => {
                    try self.genInlineMemcpyRegisterRegister(ty, base_reg, reg, stack_offset);
                },
            }
        },
        .memory,
        .load_direct,
        .load_tlv,
        .lea_direct,
        .lea_tlv,
        => if (abi_size <= 8) {
            const reg = try self.copyToTmpRegister(ty, mcv);
            return self.genSetStack(ty, stack_offset, MCValue{ .register = reg }, opts);
        } else {
            const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genSetReg(Type.usize, addr_reg, switch (mcv) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => mcv,
            });
            try self.genInlineMemcpy(
                .{ .ptr_stack_offset = stack_offset },
                .{ .register = addr_reg },
                .{ .immediate = abi_size },
                .{},
            );
        },
        .stack_offset => |off| if (abi_size <= 8) {
            const tmp_reg = try self.copyToTmpRegister(ty, mcv);
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetStack(ty, stack_offset, .{ .register = tmp_reg }, opts);
        } else try self.genInlineMemcpy(
            .{ .ptr_stack_offset = stack_offset },
            .{ .ptr_stack_offset = off },
            .{ .immediate = abi_size },
            .{},
        ),
        .ptr_stack_offset,
        .load_got,
        => {
            const tmp_reg = try self.copyToTmpRegister(ty, mcv);
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetStack(ty, stack_offset, .{ .register = tmp_reg }, opts);
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
    assert(dst_reg.bitSize() == 64);

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
            try self.asmMemoryRegister(.mov, Memory.sib(Memory.PtrSize.fromSize(nearest_power_of_two), .{
                .base = dst_reg,
                .disp = -next_offset,
            }), registerAlias(tmp_reg, nearest_power_of_two));

            if (nearest_power_of_two > 1) {
                try self.genShiftBinOpMir(.shr, ty, .{ .register = tmp_reg }, .{
                    .immediate = nearest_power_of_two * 8,
                });
            }

            remainder -= nearest_power_of_two;
            next_offset -= nearest_power_of_two;
        }
    } else {
        try self.asmMemoryRegister(
            switch (src_reg.class()) {
                .general_purpose, .segment => .mov,
                .floating_point => .movss,
            },
            Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = dst_reg, .disp = -offset }),
            registerAlias(src_reg, abi_size),
        );
    }
}

const InlineMemcpyOpts = struct {
    source_stack_base: ?Register = null,
    dest_stack_base: ?Register = null,
};

fn genInlineMemcpy(
    self: *Self,
    dst_ptr: MCValue,
    src_ptr: MCValue,
    len: MCValue,
    opts: InlineMemcpyOpts,
) InnerError!void {
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

    try self.spillRegisters(&.{ .rdi, .rsi, .rcx });

    switch (dst_ptr) {
        .lea_tlv,
        .load_tlv,
        => {
            try self.genSetReg(Type.usize, .rdi, switch (dst_ptr) {
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => dst_ptr,
            });
        },
        .memory,
        .load_got,
        .lea_direct,
        .load_direct,
        => {
            try self.genSetReg(Type.usize, .rdi, switch (dst_ptr) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                else => dst_ptr,
            });
            // Load the pointer, which is stored in memory
            try self.asmRegisterMemory(.mov, .rdi, Memory.sib(.qword, .{ .base = .rdi }));
        },
        .stack_offset, .ptr_stack_offset => |off| {
            try self.asmRegisterMemory(switch (dst_ptr) {
                .stack_offset => .mov,
                .ptr_stack_offset => .lea,
                else => unreachable,
            }, .rdi, Memory.sib(.qword, .{
                .base = opts.dest_stack_base orelse .rbp,
                .disp = -off,
            }));
        },
        .register => |reg| {
            try self.asmRegisterRegister(
                .mov,
                registerAlias(.rdi, @intCast(u32, @divExact(reg.bitSize(), 8))),
                reg,
            );
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when dest is {}", .{dst_ptr});
        },
    }

    switch (src_ptr) {
        .lea_tlv,
        .load_tlv,
        => {
            try self.genSetReg(Type.usize, .rsi, switch (src_ptr) {
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => dst_ptr,
            });
        },
        .memory,
        .load_got,
        .lea_direct,
        .load_direct,
        => {
            try self.genSetReg(Type.usize, .rsi, switch (src_ptr) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                else => src_ptr,
            });
            // Load the pointer, which is stored in memory
            try self.asmRegisterMemory(.mov, .rsi, Memory.sib(.qword, .{ .base = .rsi }));
        },
        .stack_offset, .ptr_stack_offset => |off| {
            try self.asmRegisterMemory(switch (src_ptr) {
                .stack_offset => .mov,
                .ptr_stack_offset => .lea,
                else => unreachable,
            }, .rsi, Memory.sib(.qword, .{
                .base = opts.source_stack_base orelse .rbp,
                .disp = -off,
            }));
        },
        .register => |reg| {
            try self.asmRegisterRegister(
                .mov,
                registerAlias(.rsi, @intCast(u32, @divExact(reg.bitSize(), 8))),
                reg,
            );
        },
        else => {
            return self.fail("TODO implement memcpy for setting stack when src is {}", .{src_ptr});
        },
    }

    try self.genSetReg(Type.usize, .rcx, len);
    _ = try self.addInst(.{
        .tag = .movs,
        .ops = .string,
        .data = .{ .string = .{ .repeat = .rep, .width = .b } },
    });
}

fn genInlineMemset(
    self: *Self,
    dst_ptr: MCValue,
    value: MCValue,
    len: MCValue,
    opts: InlineMemcpyOpts,
) InnerError!void {
    const dsbase_lock: ?RegisterLock = if (opts.dest_stack_base) |reg|
        self.register_manager.lockReg(reg)
    else
        null;
    defer if (dsbase_lock) |lock| self.register_manager.unlockReg(lock);

    try self.spillRegisters(&.{ .rdi, .al, .rcx });

    switch (dst_ptr) {
        .lea_tlv,
        .load_tlv,
        => {
            try self.genSetReg(Type.usize, .rdi, switch (dst_ptr) {
                .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                else => dst_ptr,
            });
        },
        .load_got => try self.genSetReg(Type.usize, .rdi, dst_ptr),
        .memory,
        .lea_direct,
        .load_direct,
        => {
            try self.genSetReg(Type.usize, .rdi, switch (dst_ptr) {
                .memory => |addr| .{ .immediate = addr },
                .load_direct => |sym_index| .{ .lea_direct = sym_index },
                else => dst_ptr,
            });
            // Load the pointer, which is stored in memory
            try self.asmRegisterMemory(.mov, .rdi, Memory.sib(.qword, .{ .base = .rdi }));
        },
        .stack_offset, .ptr_stack_offset => |off| {
            try self.asmRegisterMemory(switch (dst_ptr) {
                .stack_offset => .mov,
                .ptr_stack_offset => .lea,
                else => unreachable,
            }, .rdi, Memory.sib(.qword, .{
                .base = opts.dest_stack_base orelse .rbp,
                .disp = -off,
            }));
        },
        .register => |reg| {
            try self.asmRegisterRegister(
                .mov,
                registerAlias(.rdi, @intCast(u32, @divExact(reg.bitSize(), 8))),
                reg,
            );
        },
        else => {
            return self.fail("TODO implement memset for setting stack when dest is {}", .{dst_ptr});
        },
    }

    try self.genSetReg(Type.u8, .al, value);
    try self.genSetReg(Type.usize, .rcx, len);
    _ = try self.addInst(.{
        .tag = .stos,
        .ops = .string,
        .data = .{ .string = .{ .repeat = .rep, .width = .b } },
    });
}

fn genSetReg(self: *Self, ty: Type, reg: Register, mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    if (abi_size > 8) return self.fail("genSetReg called with a value larger than one register", .{});
    switch (mcv) {
        .dead => unreachable,
        .register_overflow => unreachable,
        .ptr_stack_offset => |off| {
            try self.asmRegisterMemory(
                .lea,
                registerAlias(reg, abi_size),
                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -off }),
            );
        },
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety()) return; // The already existing value will do just fine.
            // Write the debug undefined value.
            switch (self.regBitSize(ty)) {
                8 => return self.genSetReg(ty, reg, .{ .immediate = 0xaa }),
                16 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaa }),
                32 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaa }),
                64 => return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
                else => unreachable,
            }
        },
        .eflags => |cc| {
            return self.asmSetccRegister(reg.to8(), cc);
        },
        .immediate => |imm| {
            if (imm == 0) {
                // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
                // register is the fastest way to zero a register.
                try self.asmRegisterRegister(.xor, reg.to32(), reg.to32());
            } else if (abi_size > 4 and math.cast(u32, imm) != null) {
                // 32-bit moves zero-extend to 64-bit.
                try self.asmRegisterImmediate(.mov, reg.to32(), Immediate.u(imm));
            } else if (abi_size <= 4 and @bitCast(i64, imm) < 0) {
                try self.asmRegisterImmediate(
                    .mov,
                    registerAlias(reg, abi_size),
                    Immediate.s(@intCast(i32, @bitCast(i64, imm))),
                );
            } else {
                try self.asmRegisterImmediate(
                    .mov,
                    registerAlias(reg, abi_size),
                    Immediate.u(imm),
                );
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            switch (ty.zigTypeTag()) {
                .Int => switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        if (abi_size <= 4) {
                            return self.asmRegisterRegister(
                                .movsx,
                                reg.to64(),
                                registerAlias(src_reg, abi_size),
                            );
                        }
                    },
                    .unsigned => {
                        if (abi_size <= 2) {
                            return self.asmRegisterRegister(
                                .movzx,
                                reg.to64(),
                                registerAlias(src_reg, abi_size),
                            );
                        }
                    },
                },
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail("TODO genSetReg from register for {}", .{ty.fmtDebug()}),
                        };
                        return self.asmRegisterRegister(tag, reg.to128(), src_reg.to128());
                    }
                    return self.fail("TODO genSetReg from register for float with no intrinsics", .{});
                },
                else => {},
            }

            try self.asmRegisterRegister(.mov, registerAlias(reg, abi_size), registerAlias(src_reg, abi_size));
        },
        .memory => |addr| switch (ty.zigTypeTag()) {
            .Float => {
                const base_reg = (try self.register_manager.allocReg(null, gp)).to64();
                try self.genSetReg(Type.usize, base_reg, .{ .immediate = addr });

                if (intrinsicsAllowed(self.target.*, ty)) {
                    return self.asmRegisterMemory(
                        switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail("TODO genSetReg from memory for {}", .{
                                ty.fmt(self.bin_file.options.module.?),
                            }),
                        },
                        reg.to128(),
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = base_reg }),
                    );
                }

                return self.fail("TODO genSetReg from memory for float with no intrinsics", .{});
            },
            else => {
                if (addr <= math.maxInt(i32)) {
                    try self.asmRegisterMemory(
                        .mov,
                        registerAlias(reg, abi_size),
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                            .base = .ds,
                            .disp = @intCast(i32, addr),
                        }),
                    );
                } else {
                    if (reg.to64() == .rax) {
                        // If this is RAX, we can use a direct load.
                        // Otherwise, we need to load the address, then indirectly load the value.
                        _ = try self.addInst(.{
                            .tag = .mov_moffs,
                            .ops = .rax_moffs,
                            .data = .{ .payload = try self.addExtra(Mir.MemoryMoffs.encode(.ds, addr)) },
                        });
                    } else {
                        // Rather than duplicate the logic used for the move, we just use a self-call with a new MCValue.
                        try self.genSetReg(Type.usize, reg, MCValue{ .immediate = addr });
                        try self.asmRegisterMemory(
                            .mov,
                            registerAlias(reg, abi_size),
                            Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = reg.to64() }),
                        );
                    }
                }
            },
        },
        .load_got, .lea_direct => |sym_index| {
            const atom_index = try self.getSymbolIndexForDecl(self.mod_fn.owner_decl);
            _ = try self.addInst(.{
                .tag = switch (mcv) {
                    .load_got => .mov_linker,
                    .lea_direct => .lea_linker,
                    else => unreachable,
                },
                .ops = switch (mcv) {
                    .load_got => .got_reloc,
                    .lea_direct => .direct_reloc,
                    else => unreachable,
                },
                .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                    .reg = @enumToInt(reg),
                    .atom_index = atom_index,
                    .sym_index = sym_index,
                }) },
            });
        },
        .load_direct => |sym_index| {
            switch (ty.zigTypeTag()) {
                .Float => {
                    const addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    try self.genSetReg(Type.usize, addr_reg, .{ .lea_direct = sym_index });

                    if (intrinsicsAllowed(self.target.*, ty)) {
                        return self.asmRegisterMemory(
                            switch (ty.tag()) {
                                .f32 => .movss,
                                .f64 => .movsd,
                                else => return self.fail("TODO genSetReg from memory for {}", .{
                                    ty.fmt(self.bin_file.options.module.?),
                                }),
                            },
                            reg.to128(),
                            Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = addr_reg }),
                        );
                    }

                    return self.fail("TODO genSetReg from memory for float with no intrinsics", .{});
                },
                else => {
                    const atom_index = try self.getSymbolIndexForDecl(self.mod_fn.owner_decl);
                    _ = try self.addInst(.{
                        .tag = .mov_linker,
                        .ops = .direct_reloc,
                        .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                            .reg = @enumToInt(registerAlias(reg, abi_size)),
                            .atom_index = atom_index,
                            .sym_index = sym_index,
                        }) },
                    });
                },
            }
        },
        .lea_tlv => |sym_index| {
            const atom_index = try self.getSymbolIndexForDecl(self.mod_fn.owner_decl);
            if (self.bin_file.cast(link.File.MachO)) |_| {
                _ = try self.addInst(.{
                    .tag = .mov_linker,
                    .ops = .tlv_reloc,
                    .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                        .reg = @enumToInt(Register.rdi),
                        .atom_index = atom_index,
                        .sym_index = sym_index,
                    }) },
                });
                // TODO: spill registers before calling
                try self.asmMemory(.call, Memory.sib(.qword, .{ .base = .rdi }));
                try self.genSetReg(Type.usize, reg, .{ .register = .rax });
            } else return self.fail("TODO emit ptr to TLV sequence on {s}", .{@tagName(self.bin_file.tag)});
        },
        .load_tlv => |sym_index| {
            const base_reg = switch (ty.zigTypeTag()) {
                .Float => (try self.register_manager.allocReg(null, gp)).to64(),
                else => reg.to64(),
            };
            try self.genSetReg(Type.usize, base_reg, .{ .lea_tlv = sym_index });
            switch (ty.zigTypeTag()) {
                .Float => if (intrinsicsAllowed(self.target.*, ty)) {
                    return self.asmRegisterMemory(
                        switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail("TODO genSetReg from memory for {}", .{
                                ty.fmt(self.bin_file.options.module.?),
                            }),
                        },
                        reg.to128(),
                        Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = base_reg }),
                    );
                } else return self.fail("TODO genSetReg from memory for float with no intrinsics", .{}),
                else => try self.asmRegisterMemory(
                    .mov,
                    registerAlias(reg, abi_size),
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = base_reg }),
                ),
            }
        },
        .stack_offset => |off| {
            switch (ty.zigTypeTag()) {
                .Int => switch (ty.intInfo(self.target.*).signedness) {
                    .signed => {
                        if (abi_size <= 4) {
                            return self.asmRegisterMemory(
                                .movsx,
                                reg.to64(),
                                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                                    .base = .rbp,
                                    .disp = -off,
                                }),
                            );
                        }
                    },
                    .unsigned => {
                        if (abi_size <= 2) {
                            return self.asmRegisterMemory(
                                .movzx,
                                reg.to64(),
                                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                                    .base = .rbp,
                                    .disp = -off,
                                }),
                            );
                        }
                    },
                },
                .Float => {
                    if (intrinsicsAllowed(self.target.*, ty)) {
                        const tag: Mir.Inst.Tag = switch (ty.tag()) {
                            .f32 => .movss,
                            .f64 => .movsd,
                            else => return self.fail(
                                "TODO genSetReg from stack offset for {}",
                                .{ty.fmtDebug()},
                            ),
                        };
                        return self.asmRegisterMemory(tag, reg.to128(), Memory.sib(
                            Memory.PtrSize.fromSize(abi_size),
                            .{ .base = .rbp, .disp = -off },
                        ));
                    }
                    return self.fail("TODO genSetReg from stack offset for float with no intrinsics", .{});
                },
                else => {},
            }

            try self.asmRegisterMemory(
                .mov,
                registerAlias(reg, abi_size),
                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .rbp, .disp = -off }),
            );
        },
    }
}

fn airPtrToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const src_mcv = try self.resolveInst(un_op);
        if (self.reuseOperand(inst, un_op, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.air.typeOfIndex(inst);
        try self.setRegOrMem(dst_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = if (self.liveness.isUnused(inst)) .dead else result: {
        const operand = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, operand)) break :result operand;

        const operand_lock = switch (operand) {
            .register => |reg| self.register_manager.lockReg(reg),
            .register_overflow => |ro| self.register_manager.lockReg(ro.reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dest = try self.allocRegOrMem(inst, true);
        try self.setRegOrMem(self.air.typeOfIndex(inst), dest, operand);
        break :result dest;
    };
    log.debug("airBitCast(%{d}): {}", .{ inst, result });
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
        try self.genSetStack(Type.u64, stack_offset - 8, .{ .immediate = array_len }, .{});
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
    const src_abi_size = @intCast(u32, src_ty.abiSize(self.target.*));
    const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));

    switch (src_abi_size) {
        4, 8 => {},
        else => |size| return self.fail("TODO load ST(0) with abiSize={}", .{size}),
    }
    if (dst_abi_size > 8) {
        return self.fail("TODO convert float with abiSize={}", .{dst_abi_size});
    }

    // move float src to ST(0)
    const stack_offset = switch (operand) {
        .stack_offset, .ptr_stack_offset => |offset| offset,
        else => blk: {
            const offset = @intCast(i32, try self.allocMem(
                inst,
                src_abi_size,
                src_ty.abiAlignment(self.target.*),
            ));
            try self.genSetStack(src_ty, offset, operand, .{});
            break :blk offset;
        },
    };
    try self.asmMemory(.fld, Memory.sib(Memory.PtrSize.fromSize(src_abi_size), .{
        .base = .rbp,
        .disp = -stack_offset,
    }));

    // convert
    const stack_dst = try self.allocRegOrMem(inst, false);
    try self.asmMemory(.fisttp, Memory.sib(Memory.PtrSize.fromSize(dst_abi_size), .{
        .base = .rbp,
        .disp = -stack_dst.stack_offset,
    }));

    return self.finishAir(inst, stack_dst, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

    const ptr_ty = self.air.typeOf(extra.ptr);
    const ptr_mcv = try self.resolveInst(extra.ptr);
    const val_ty = self.air.typeOf(extra.expected_value);
    const val_abi_size = @intCast(u32, val_ty.abiSize(self.target.*));

    try self.spillRegisters(&.{ .rax, .rdx, .rbx, .rcx });
    const regs_lock = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdx, .rbx, .rcx });
    for (regs_lock) |lock| self.register_manager.unlockReg(lock);

    const exp_mcv = try self.resolveInst(extra.expected_value);
    if (val_abi_size > 8) switch (exp_mcv) {
        .stack_offset => |exp_off| {
            try self.genSetReg(Type.usize, .rax, .{ .stack_offset = exp_off - 0 });
            try self.genSetReg(Type.usize, .rdx, .{ .stack_offset = exp_off - 8 });
        },
        else => return self.fail("TODO implement cmpxchg for {s}", .{@tagName(exp_mcv)}),
    } else try self.genSetReg(val_ty, .rax, exp_mcv);
    const rax_lock = self.register_manager.lockRegAssumeUnused(.rax);
    defer self.register_manager.unlockReg(rax_lock);

    const new_mcv = try self.resolveInst(extra.new_value);
    const new_reg: Register = if (val_abi_size > 8) switch (new_mcv) {
        .stack_offset => |new_off| new: {
            try self.genSetReg(Type.usize, .rbx, .{ .stack_offset = new_off - 0 });
            try self.genSetReg(Type.usize, .rcx, .{ .stack_offset = new_off - 8 });
            break :new undefined;
        },
        else => return self.fail("TODO implement cmpxchg for {s}", .{@tagName(exp_mcv)}),
    } else try self.copyToTmpRegister(val_ty, new_mcv);
    const new_lock = self.register_manager.lockRegAssumeUnused(new_reg);
    defer self.register_manager.unlockReg(new_lock);

    const ptr_size = Memory.PtrSize.fromSize(val_abi_size);
    const ptr_mem = switch (ptr_mcv) {
        .register => |reg| Memory.sib(ptr_size, .{ .base = reg }),
        .ptr_stack_offset => |off| Memory.sib(ptr_size, .{ .base = .rbp, .disp = -off }),
        else => Memory.sib(ptr_size, .{ .base = try self.copyToTmpRegister(ptr_ty, ptr_mcv) }),
    };
    const mem_lock = if (ptr_mem.base()) |reg| self.register_manager.lockReg(reg) else null;
    defer if (mem_lock) |lock| self.register_manager.unlockReg(lock);

    try self.spillEflagsIfOccupied();
    if (val_abi_size <= 8) {
        _ = try self.addInst(.{ .tag = .cmpxchg, .ops = .lock_mr_sib, .data = .{ .rx = .{
            .r = registerAlias(new_reg, val_abi_size),
            .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
        } } });
    } else {
        _ = try self.addInst(.{ .tag = .cmpxchgb, .ops = .lock_m_sib, .data = .{
            .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
        } });
    }

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        if (val_abi_size <= 8) {
            self.eflags_inst = inst;
            break :result .{ .register_overflow = .{ .reg = .rax, .eflags = .ne } };
        }

        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genSetStack(Type.bool, dst_mcv.stack_offset - 16, .{ .eflags = .ne }, .{});
        try self.genSetStack(Type.usize, dst_mcv.stack_offset - 8, .{ .register = .rdx }, .{});
        try self.genSetStack(Type.usize, dst_mcv.stack_offset - 0, .{ .register = .rax }, .{});
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn atomicOp(
    self: *Self,
    ptr_mcv: MCValue,
    val_mcv: MCValue,
    ptr_ty: Type,
    val_ty: Type,
    unused: bool,
    rmw_op: ?std.builtin.AtomicRmwOp,
    order: std.builtin.AtomicOrder,
) InnerError!MCValue {
    const ptr_lock = switch (ptr_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const val_lock = switch (val_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (val_lock) |lock| self.register_manager.unlockReg(lock);

    const val_abi_size = @intCast(u32, val_ty.abiSize(self.target.*));
    const ptr_size = Memory.PtrSize.fromSize(val_abi_size);
    const ptr_mem = switch (ptr_mcv) {
        .register => |reg| Memory.sib(ptr_size, .{ .base = reg }),
        .ptr_stack_offset => |off| Memory.sib(ptr_size, .{ .base = .rbp, .disp = -off }),
        else => Memory.sib(ptr_size, .{ .base = try self.copyToTmpRegister(ptr_ty, ptr_mcv) }),
    };
    const mem_lock = if (ptr_mem.base()) |reg| self.register_manager.lockReg(reg) else null;
    defer if (mem_lock) |lock| self.register_manager.unlockReg(lock);

    const method: enum { lock, loop, libcall } = if (val_ty.isRuntimeFloat())
        .loop
    else switch (rmw_op orelse .Xchg) {
        .Xchg,
        .Add,
        .Sub,
        => if (val_abi_size <= 8) .lock else if (val_abi_size <= 16) .loop else .libcall,
        .And,
        .Or,
        .Xor,
        => if (val_abi_size <= 8 and unused) .lock else if (val_abi_size <= 16) .loop else .libcall,
        .Nand,
        .Max,
        .Min,
        => if (val_abi_size <= 16) .loop else .libcall,
    };
    switch (method) {
        .lock => {
            const tag: Mir.Inst.Tag = if (rmw_op) |op| switch (op) {
                .Xchg => if (unused) .mov else .xchg,
                .Add => if (unused) .add else .xadd,
                .Sub => if (unused) .sub else .xadd,
                .And => .@"and",
                .Or => .@"or",
                .Xor => .xor,
                else => unreachable,
            } else switch (order) {
                .Unordered, .Monotonic, .Release, .AcqRel => .mov,
                .Acquire => unreachable,
                .SeqCst => .xchg,
            };

            const dst_reg = try self.register_manager.allocReg(null, gp);
            const dst_mcv = MCValue{ .register = dst_reg };
            const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
            defer self.register_manager.unlockReg(dst_lock);

            try self.genSetReg(val_ty, dst_reg, val_mcv);
            if (rmw_op == std.builtin.AtomicRmwOp.Sub and tag == .xadd) {
                try self.genUnOpMir(.neg, val_ty, dst_mcv);
            }
            _ = try self.addInst(.{ .tag = tag, .ops = switch (tag) {
                .mov, .xchg => .mr_sib,
                .xadd, .add, .sub, .@"and", .@"or", .xor => .lock_mr_sib,
                else => unreachable,
            }, .data = .{ .rx = .{
                .r = registerAlias(dst_reg, val_abi_size),
                .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
            } } });

            return if (unused) .none else dst_mcv;
        },
        .loop => _ = if (val_abi_size <= 8) {
            const tmp_reg = try self.register_manager.allocReg(null, gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.asmRegisterMemory(.mov, registerAlias(.rax, val_abi_size), ptr_mem);
            const loop = @intCast(u32, self.mir_instructions.len);
            if (rmw_op != std.builtin.AtomicRmwOp.Xchg) {
                try self.genSetReg(val_ty, tmp_reg, .{ .register = .rax });
            }
            if (rmw_op) |op| switch (op) {
                .Xchg => try self.genSetReg(val_ty, tmp_reg, val_mcv),
                .Add => try self.genBinOpMir(.add, val_ty, tmp_mcv, val_mcv),
                .Sub => try self.genBinOpMir(.sub, val_ty, tmp_mcv, val_mcv),
                .And => try self.genBinOpMir(.@"and", val_ty, tmp_mcv, val_mcv),
                .Nand => {
                    try self.genBinOpMir(.@"and", val_ty, tmp_mcv, val_mcv);
                    try self.genUnOpMir(.not, val_ty, tmp_mcv);
                },
                .Or => try self.genBinOpMir(.@"or", val_ty, tmp_mcv, val_mcv),
                .Xor => try self.genBinOpMir(.xor, val_ty, tmp_mcv, val_mcv),
                .Min, .Max => {
                    const cc: Condition = switch (if (val_ty.isAbiInt())
                        val_ty.intInfo(self.target.*).signedness
                    else
                        .unsigned) {
                        .unsigned => switch (op) {
                            .Min => .a,
                            .Max => .b,
                            else => unreachable,
                        },
                        .signed => switch (op) {
                            .Min => .g,
                            .Max => .l,
                            else => unreachable,
                        },
                    };

                    try self.genBinOpMir(.cmp, val_ty, tmp_mcv, val_mcv);
                    const cmov_abi_size = @max(val_abi_size, 2);
                    switch (val_mcv) {
                        .register => |val_reg| try self.asmCmovccRegisterRegister(
                            registerAlias(tmp_reg, cmov_abi_size),
                            registerAlias(val_reg, cmov_abi_size),
                            cc,
                        ),
                        .stack_offset => |val_off| try self.asmCmovccRegisterMemory(
                            registerAlias(tmp_reg, cmov_abi_size),
                            Memory.sib(
                                Memory.PtrSize.fromSize(cmov_abi_size),
                                .{ .base = .rbp, .disp = -val_off },
                            ),
                            cc,
                        ),
                        else => {
                            const val_reg = try self.copyToTmpRegister(val_ty, val_mcv);
                            try self.asmCmovccRegisterRegister(
                                registerAlias(tmp_reg, cmov_abi_size),
                                registerAlias(val_reg, cmov_abi_size),
                                cc,
                            );
                        },
                    }
                },
            };
            _ = try self.addInst(.{ .tag = .cmpxchg, .ops = .lock_mr_sib, .data = .{ .rx = .{
                .r = registerAlias(tmp_reg, val_abi_size),
                .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
            } } });
            _ = try self.asmJccReloc(loop, .ne);
            return if (unused) .none else .{ .register = .rax };
        } else {
            try self.asmRegisterMemory(.mov, .rax, Memory.sib(.qword, .{
                .base = ptr_mem.sib.base,
                .scale_index = ptr_mem.sib.scale_index,
                .disp = ptr_mem.sib.disp + 0,
            }));
            try self.asmRegisterMemory(.mov, .rdx, Memory.sib(.qword, .{
                .base = ptr_mem.sib.base,
                .scale_index = ptr_mem.sib.scale_index,
                .disp = ptr_mem.sib.disp + 8,
            }));
            const loop = @intCast(u32, self.mir_instructions.len);
            switch (val_mcv) {
                .stack_offset => |val_off| {
                    const val_lo_mem = Memory.sib(.qword, .{ .base = .rbp, .disp = 0 - val_off });
                    const val_hi_mem = Memory.sib(.qword, .{ .base = .rbp, .disp = 8 - val_off });

                    if (rmw_op != std.builtin.AtomicRmwOp.Xchg) {
                        try self.asmRegisterRegister(.mov, .rbx, .rax);
                        try self.asmRegisterRegister(.mov, .rcx, .rdx);
                    }
                    if (rmw_op) |op| switch (op) {
                        .Xchg => {
                            try self.asmRegisterMemory(.mov, .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.mov, .rcx, val_hi_mem);
                        },
                        .Add => {
                            try self.asmRegisterMemory(.add, .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.adc, .rcx, val_hi_mem);
                        },
                        .Sub => {
                            try self.asmRegisterMemory(.sub, .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.sbb, .rcx, val_hi_mem);
                        },
                        .And => {
                            try self.asmRegisterMemory(.@"and", .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.@"and", .rcx, val_hi_mem);
                        },
                        .Nand => {
                            try self.asmRegisterMemory(.@"and", .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.@"and", .rcx, val_hi_mem);
                            try self.asmRegister(.not, .rbx);
                            try self.asmRegister(.not, .rcx);
                        },
                        .Or => {
                            try self.asmRegisterMemory(.@"or", .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.@"or", .rcx, val_hi_mem);
                        },
                        .Xor => {
                            try self.asmRegisterMemory(.xor, .rbx, val_lo_mem);
                            try self.asmRegisterMemory(.xor, .rcx, val_hi_mem);
                        },
                        else => return self.fail(
                            "TODO implement x86 atomic loop for large abi {s}",
                            .{@tagName(op)},
                        ),
                    };
                },
                else => return self.fail(
                    "TODO implement x86 atomic loop for large abi {s}",
                    .{@tagName(val_mcv)},
                ),
            }
            _ = try self.addInst(.{ .tag = .cmpxchgb, .ops = .lock_m_sib, .data = .{
                .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
            } });
            _ = try self.asmJccReloc(loop, .ne);

            if (unused) return .none;
            const dst_mcv = try self.allocTempRegOrMem(val_ty, false);
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{ .base = .rbp, .disp = 0 - dst_mcv.stack_offset }),
                .rax,
            );
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{ .base = .rbp, .disp = 8 - dst_mcv.stack_offset }),
                .rdx,
            );
            return dst_mcv;
        },
        .libcall => return self.fail("TODO implement x86 atomic libcall", .{}),
    }
}

fn airAtomicRmw(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.AtomicRmw, pl_op.payload).data;

    try self.spillRegisters(&.{ .rax, .rdx, .rbx, .rcx });
    const regs_lock = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdx, .rbx, .rcx });
    defer for (regs_lock) |lock| self.register_manager.unlockReg(lock);

    const unused = self.liveness.isUnused(inst);

    const ptr_ty = self.air.typeOf(pl_op.operand);
    const ptr_mcv = try self.resolveInst(pl_op.operand);

    const val_ty = self.air.typeOf(extra.operand);
    const val_mcv = try self.resolveInst(extra.operand);

    const result =
        try self.atomicOp(ptr_mcv, val_mcv, ptr_ty, val_ty, unused, extra.op(), extra.ordering());
    return self.finishAir(inst, result, .{ pl_op.operand, extra.operand, .none });
}

fn airAtomicLoad(self: *Self, inst: Air.Inst.Index) !void {
    const atomic_load = self.air.instructions.items(.data)[inst].atomic_load;

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .dead;

        const ptr_ty = self.air.typeOf(atomic_load.ptr);
        const ptr_mcv = try self.resolveInst(atomic_load.ptr);
        const ptr_lock = switch (ptr_mcv) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv =
            if (self.reuseOperand(inst, atomic_load.ptr, 0, ptr_mcv))
            ptr_mcv
        else
            try self.allocRegOrMem(inst, true);

        try self.load(dst_mcv, ptr_mcv, ptr_ty);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ atomic_load.ptr, .none, .none });
}

fn airAtomicStore(self: *Self, inst: Air.Inst.Index, order: std.builtin.AtomicOrder) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const ptr_mcv = try self.resolveInst(bin_op.lhs);

    const val_ty = self.air.typeOf(bin_op.rhs);
    const val_mcv = try self.resolveInst(bin_op.rhs);

    const result = try self.atomicOp(ptr_mcv, val_mcv, ptr_ty, val_ty, true, null, order);
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
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

    return self.finishAir(inst, .none, .{ pl_op.operand, extra.lhs, extra.rhs });
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

    try self.genInlineMemcpy(dst_ptr, src_ptr, len, .{});

    return self.finishAir(inst, .none, .{ pl_op.operand, extra.lhs, extra.rhs });
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .dead else result: {
        const err_ty = self.air.typeOf(un_op);
        const err_mcv = try self.resolveInst(un_op);
        const err_reg = try self.copyToTmpRegister(err_ty, err_mcv);
        const err_lock = self.register_manager.lockRegAssumeUnused(err_reg);
        defer self.register_manager.unlockReg(err_lock);

        const addr_reg = try self.register_manager.allocReg(null, gp);
        const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
        defer self.register_manager.unlockReg(addr_lock);

        if (self.bin_file.cast(link.File.Elf)) |elf_file| {
            const atom_index = try elf_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const got_addr = elf_file.getAtom(atom_index).getOffsetTableAddress(elf_file);
            try self.asmRegisterMemory(.mov, addr_reg.to64(), Memory.sib(.qword, .{
                .base = .ds,
                .disp = @intCast(i32, got_addr),
            }));
        } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
            const atom_index = try coff_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
            try self.genSetReg(Type.usize, addr_reg, .{ .load_got = sym_index });
        } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
            const atom_index = try macho_file.getOrCreateAtomForLazySymbol(
                .{ .kind = .const_data, .ty = Type.anyerror },
                4, // dword alignment
            );
            const sym_index = macho_file.getAtom(atom_index).getSymbolIndex().?;
            try self.genSetReg(Type.usize, addr_reg, .{ .load_got = sym_index });
        } else {
            return self.fail("TODO implement airErrorName for x86_64 {s}", .{@tagName(self.bin_file.tag)});
        }

        const start_reg = try self.register_manager.allocReg(null, gp);
        const start_lock = self.register_manager.lockRegAssumeUnused(start_reg);
        defer self.register_manager.unlockReg(start_lock);

        const end_reg = try self.register_manager.allocReg(null, gp);
        const end_lock = self.register_manager.lockRegAssumeUnused(end_reg);
        defer self.register_manager.unlockReg(end_lock);

        try self.truncateRegister(err_ty, err_reg.to32());

        try self.asmRegisterMemory(.mov, start_reg.to32(), Memory.sib(.dword, .{
            .base = addr_reg.to64(),
            .scale_index = .{ .scale = 4, .index = err_reg.to64() },
            .disp = 4,
        }));
        try self.asmRegisterMemory(.mov, end_reg.to32(), Memory.sib(.dword, .{
            .base = addr_reg.to64(),
            .scale_index = .{ .scale = 4, .index = err_reg.to64() },
            .disp = 8,
        }));
        try self.asmRegisterRegister(.sub, end_reg.to32(), start_reg.to32());
        try self.asmRegisterMemory(.lea, start_reg.to64(), Memory.sib(.byte, .{
            .base = addr_reg.to64(),
            .scale_index = .{ .scale = 1, .index = start_reg.to64() },
            .disp = 0,
        }));
        try self.asmRegisterMemory(.lea, end_reg.to32(), Memory.sib(.byte, .{
            .base = end_reg.to64(),
            .disp = -1,
        }));

        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.asmMemoryRegister(.mov, Memory.sib(.qword, .{
            .base = .rbp,
            .disp = 0 - dst_mcv.stack_offset,
        }), start_reg.to64());
        try self.asmMemoryRegister(.mov, Memory.sib(.qword, .{
            .base = .rbp,
            .disp = 8 - dst_mcv.stack_offset,
        }), end_reg.to64());
        break :result dst_mcv;
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
                if (result_ty.containerLayout() == .Packed) {
                    const struct_obj = result_ty.castTag(.@"struct").?.data;
                    try self.genInlineMemset(
                        .{ .ptr_stack_offset = stack_offset },
                        .{ .immediate = 0 },
                        .{ .immediate = abi_size },
                        .{},
                    );
                    for (elements, 0..) |elem, elem_i| {
                        if (result_ty.structFieldValueComptime(elem_i) != null) continue;

                        const elem_ty = result_ty.structFieldType(elem_i);
                        const elem_bit_size = @intCast(u32, elem_ty.bitSize(self.target.*));
                        if (elem_bit_size > 64) {
                            return self.fail("TODO airAggregateInit implement packed structs with large fields", .{});
                        }
                        const elem_abi_size = @intCast(u32, elem_ty.abiSize(self.target.*));
                        const elem_abi_bits = elem_abi_size * 8;
                        const elem_off = struct_obj.packedFieldBitOffset(self.target.*, elem_i);
                        const elem_byte_off = @intCast(i32, elem_off / elem_abi_bits * elem_abi_size);
                        const elem_bit_off = elem_off % elem_abi_bits;
                        const elem_mcv = try self.resolveInst(elem);
                        const mat_elem_mcv = switch (elem_mcv) {
                            .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                            else => elem_mcv,
                        };
                        const elem_lock = switch (mat_elem_mcv) {
                            .register => |reg| self.register_manager.lockReg(reg),
                            .immediate => |imm| lock: {
                                if (imm == 0) continue;
                                break :lock null;
                            },
                            else => null,
                        };
                        defer if (elem_lock) |lock| self.register_manager.unlockReg(lock);
                        const elem_reg = registerAlias(
                            try self.copyToTmpRegister(elem_ty, mat_elem_mcv),
                            elem_abi_size,
                        );
                        const elem_extra_bits = self.regExtraBits(elem_ty);
                        if (elem_bit_off < elem_extra_bits) {
                            try self.truncateRegister(elem_ty, elem_reg);
                        }
                        if (elem_bit_off > 0) try self.genShiftBinOpMir(
                            .shl,
                            elem_ty,
                            .{ .register = elem_reg },
                            .{ .immediate = elem_bit_off },
                        );
                        try self.genBinOpMir(
                            .@"or",
                            elem_ty,
                            .{ .stack_offset = stack_offset - elem_byte_off },
                            .{ .register = elem_reg },
                        );
                        if (elem_bit_off > elem_extra_bits) {
                            const reg = try self.copyToTmpRegister(elem_ty, mat_elem_mcv);
                            if (elem_extra_bits > 0) {
                                try self.truncateRegister(elem_ty, registerAlias(reg, elem_abi_size));
                            }
                            try self.genShiftBinOpMir(
                                .shr,
                                elem_ty,
                                .{ .register = reg },
                                .{ .immediate = elem_abi_bits - elem_bit_off },
                            );
                            try self.genBinOpMir(
                                .@"or",
                                elem_ty,
                                .{ .stack_offset = stack_offset - elem_byte_off -
                                    @intCast(i32, elem_abi_size) },
                                .{ .register = reg },
                            );
                        }
                    }
                } else for (elements, 0..) |elem, elem_i| {
                    if (result_ty.structFieldValueComptime(elem_i) != null) continue;

                    const elem_ty = result_ty.structFieldType(elem_i);
                    const elem_off = @intCast(i32, result_ty.structFieldOffset(elem_i, self.target.*));
                    const elem_mcv = try self.resolveInst(elem);
                    const mat_elem_mcv = switch (elem_mcv) {
                        .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                        else => elem_mcv,
                    };
                    try self.genSetStack(elem_ty, stack_offset - elem_off, mat_elem_mcv, .{});
                }
                break :res .{ .stack_offset = stack_offset };
            },
            .Array => {
                const stack_offset = @intCast(i32, try self.allocMem(inst, abi_size, abi_align));
                const elem_ty = result_ty.childType();
                const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

                for (elements, 0..) |elem, elem_i| {
                    const elem_mcv = try self.resolveInst(elem);
                    const mat_elem_mcv = switch (elem_mcv) {
                        .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                        else => elem_mcv,
                    };
                    const elem_off = @intCast(i32, elem_size * elem_i);
                    try self.genSetStack(elem_ty, stack_offset - elem_off, mat_elem_mcv, .{});
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

fn resolveInst(self: *Self, inst: Air.Inst.Ref) InnerError!MCValue {
    // First section of indexes correspond to a set number of constant values.
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        const tv = Air.Inst.Ref.typed_value_map[ref_int];
        if (!tv.ty.hasRuntimeBitsIgnoreComptime() and !tv.ty.isError()) {
            return .none;
        }
        return self.genTypedValue(tv);
    }

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.air.typeOf(inst);
    if (!inst_ty.hasRuntimeBitsIgnoreComptime() and !inst_ty.isError())
        return .none;

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
        else => return self.getResolvedInstValue(inst_index).?.*,
    }
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) ?*MCValue {
    // Treat each stack item as a "layer" on top of the previous one.
    var i: usize = self.branch_stack.items.len;
    while (true) {
        i -= 1;
        if (self.branch_stack.items[i].inst_table.getPtr(inst)) |mcv| {
            return if (mcv.* != .dead) mcv else null;
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
                return MCValue{ .register = try self.copyToTmpRegister(Type.usize, mcv) };
            }
        },
        else => {},
    }
    return mcv;
}

fn genTypedValue(self: *Self, arg_tv: TypedValue) InnerError!MCValue {
    const mcv: MCValue = switch (try codegen.genTypedValue(
        self.bin_file,
        self.src_loc,
        arg_tv,
        self.mod_fn.owner_decl,
    )) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_direct => |sym_index| .{ .load_direct = sym_index },
            .load_got => |sym_index| .{ .load_got = sym_index },
            .load_tlv => |sym_index| .{ .load_tlv = sym_index },
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
fn resolveCallingConventionValues(
    self: *Self,
    fn_ty: Type,
    var_args: []const Air.Inst.Ref,
) !CallMCValues {
    const cc = fn_ty.fnCallingConvention();
    const param_len = fn_ty.fnParamLen();
    const param_types = try self.gpa.alloc(Type, param_len + var_args.len);
    defer self.gpa.free(param_types);
    fn_ty.fnParamTypes(param_types);
    // TODO: promote var arg types
    for (param_types[param_len..], var_args) |*param_ty, arg| param_ty.* = self.air.typeOf(arg);
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
            result.return_value = .unreach;
            result.stack_byte_count = 0;
            result.stack_align = 1;
            return result;
        },
        .C => {
            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .unreach;
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime() and !ret_ty.isError()) {
                // TODO: is this even possible for C calling convention?
                result.return_value = .none;
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                if (ret_ty_size == 0) {
                    assert(ret_ty.isError());
                    result.return_value = .{ .immediate = 0 };
                } else if (ret_ty_size <= 8) {
                    const aliased_reg = registerAlias(abi.getCAbiIntReturnRegs(self.target.*)[0], ret_ty_size);
                    result.return_value = .{ .register = aliased_reg };
                } else {
                    // TODO: return argument cell should go first
                    result.return_value = .{ .stack_offset = 0 };
                }
            }

            // Input params
            var next_stack_offset: u32 = switch (result.return_value) {
                .stack_offset => |off| @intCast(u32, off),
                else => 0,
            };

            for (param_types, result.args, 0..) |ty, *arg, i| {
                assert(ty.hasRuntimeBits());

                const classes: []const abi.Class = switch (self.target.os.tag) {
                    .windows => &[1]abi.Class{abi.classifyWindows(ty, self.target.*)},
                    else => mem.sliceTo(&abi.classifySystemV(ty, self.target.*, .arg), .none),
                };
                if (classes.len > 1) {
                    return self.fail("TODO handle multiple classes per type", .{});
                }
                switch (classes[0]) {
                    .integer => blk: {
                        if (i >= abi.getCAbiIntParamRegs(self.target.*).len) break :blk; // fallthrough
                        arg.* = .{ .register = abi.getCAbiIntParamRegs(self.target.*)[i] };
                        continue;
                    },
                    .memory => {}, // fallthrough
                    else => |class| return self.fail("TODO handle calling convention class {s}", .{
                        @tagName(class),
                    }),
                }

                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                const param_align = @intCast(u32, ty.abiAlignment(self.target.*));
                const offset = mem.alignForwardGeneric(u32, next_stack_offset + param_size, param_align);
                arg.* = .{ .stack_offset = @intCast(i32, offset) };
                next_stack_offset = offset;
            }

            // Align the stack to 16bytes before allocating shadow stack space (if any).
            const aligned_next_stack_offset = mem.alignForwardGeneric(u32, next_stack_offset, 16);
            const padding = aligned_next_stack_offset - next_stack_offset;
            if (padding > 0) {
                for (result.args) |*arg| {
                    if (arg.isRegister()) continue;
                    arg.stack_offset += @intCast(i32, padding);
                }
            }

            const shadow_stack_space: u32 = switch (self.target.os.tag) {
                .windows => @intCast(u32, 4 * @sizeOf(u64)),
                else => 0,
            };

            // alignment padding | args ... | shadow stack space (if any) | ret addr | $rbp |
            result.stack_byte_count = aligned_next_stack_offset + shadow_stack_space;
            result.stack_align = 16;
        },
        .Unspecified => {
            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = .unreach;
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime() and !ret_ty.isError()) {
                result.return_value = .none;
            } else {
                const ret_ty_size = @intCast(u32, ret_ty.abiSize(self.target.*));
                if (ret_ty_size == 0) {
                    assert(ret_ty.isError());
                    result.return_value = .{ .immediate = 0 };
                } else if (ret_ty_size <= 8 and !ret_ty.isRuntimeFloat()) {
                    const aliased_reg = registerAlias(abi.getCAbiIntReturnRegs(self.target.*)[0], ret_ty_size);
                    result.return_value = .{ .register = aliased_reg };
                } else {
                    // We simply make the return MCValue a stack offset. However, the actual value
                    // for the offset will be populated later. We will also push the stack offset
                    // value into an appropriate register when we resolve the offset.
                    result.return_value = .{ .stack_offset = 0 };
                }
            }

            // Input params
            var next_stack_offset: u32 = switch (result.return_value) {
                .stack_offset => |off| @intCast(u32, off),
                else => 0,
            };

            for (param_types, result.args) |ty, *arg| {
                if (!ty.hasRuntimeBits()) {
                    arg.* = .none;
                    continue;
                }
                const param_size = @intCast(u32, ty.abiSize(self.target.*));
                const param_align = @intCast(u32, ty.abiAlignment(self.target.*));
                const offset = mem.alignForwardGeneric(u32, next_stack_offset + param_size, param_align);
                arg.* = .{ .stack_offset = @intCast(i32, offset) };
                next_stack_offset = offset;
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
    return switch (reg.class()) {
        .general_purpose => if (size_bytes == 0)
            unreachable // should be comptime-known
        else if (size_bytes <= 1)
            reg.to8()
        else if (size_bytes <= 2)
            reg.to16()
        else if (size_bytes <= 4)
            reg.to32()
        else if (size_bytes <= 8)
            reg.to64()
        else
            unreachable,
        .floating_point => if (size_bytes <= 16)
            reg.to128()
        else if (size_bytes <= 32)
            reg.to256()
        else
            unreachable,
        .segment => unreachable,
    };
}

/// Truncates the value in the register in place.
/// Clobbers any remaining bits.
fn truncateRegister(self: *Self, ty: Type, reg: Register) !void {
    const int_info = if (ty.isAbiInt()) ty.intInfo(self.target.*) else std.builtin.Type.Int{
        .signedness = .unsigned,
        .bits = @intCast(u16, ty.bitSize(self.target.*)),
    };
    const max_reg_bit_width = Register.rax.bitSize();
    switch (int_info.signedness) {
        .signed => {
            const shift = @intCast(u6, max_reg_bit_width - int_info.bits);
            try self.genShiftBinOpMir(.sal, Type.isize, .{ .register = reg }, .{ .immediate = shift });
            try self.genShiftBinOpMir(.sar, Type.isize, .{ .register = reg }, .{ .immediate = shift });
        },
        .unsigned => {
            const shift = @intCast(u6, max_reg_bit_width - int_info.bits);
            const mask = (~@as(u64, 0)) >> shift;
            if (int_info.bits <= 32) {
                try self.genBinOpMir(.@"and", Type.u32, .{ .register = reg }, .{ .immediate = mask });
            } else {
                const tmp_reg = try self.copyToTmpRegister(Type.usize, .{ .immediate = mask });
                try self.genBinOpMir(.@"and", Type.usize, .{ .register = reg }, .{ .register = tmp_reg });
            }
        },
    }
}

fn regBitSize(self: *Self, ty: Type) u64 {
    return switch (ty.zigTypeTag()) {
        else => switch (ty.abiSize(self.target.*)) {
            1 => 8,
            2 => 16,
            3...4 => 32,
            5...8 => 64,
            else => unreachable,
        },
        .Float => switch (ty.abiSize(self.target.*)) {
            1...16 => 128,
            17...32 => 256,
            else => unreachable,
        },
    };
}

fn regExtraBits(self: *Self, ty: Type) u64 {
    return self.regBitSize(ty) - ty.bitSize(self.target.*);
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

fn getSymbolIndexForDecl(self: *Self, decl_index: Module.Decl.Index) !u32 {
    if (self.bin_file.cast(link.File.MachO)) |macho_file| {
        const atom = try macho_file.getOrCreateAtomForDecl(decl_index);
        return macho_file.getAtom(atom).getSymbolIndex().?;
    } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
        const atom = try coff_file.getOrCreateAtomForDecl(decl_index);
        return coff_file.getAtom(atom).getSymbolIndex().?;
    } else unreachable;
}
