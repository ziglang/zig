const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Air = @import("../../Air.zig");
const Mir = @import("Mir.zig");
const Emit = @import("Emit.zig");
const Liveness = @import("../../Liveness.zig");
const Type = @import("../../type.zig").Type;
const Value = @import("../../Value.zig");
const link = @import("../../link.zig");
const Module = @import("../../Module.zig");
const Package = @import("../../Package.zig");
const InternPool = @import("../../InternPool.zig");
const Compilation = @import("../../Compilation.zig");
const ErrorMsg = Module.ErrorMsg;
const Target = std.Target;
const Allocator = mem.Allocator;
const trace = @import("../../tracy.zig").trace;
const DW = std.dwarf;
const leb128 = std.leb;
const log = std.log.scoped(.riscv_codegen);
const tracking_log = std.log.scoped(.tracking);
const build_options = @import("build_options");
const codegen = @import("../../codegen.zig");
const Alignment = InternPool.Alignment;

const CodeGenError = codegen.CodeGenError;
const Result = codegen.Result;
const DebugInfoOutput = codegen.DebugInfoOutput;

const bits = @import("bits.zig");
const abi = @import("abi.zig");
const Register = bits.Register;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const FrameIndex = bits.FrameIndex;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const callee_preserved_regs = abi.callee_preserved_regs;
/// General Purpose
const gp = abi.RegisterClass.gp;
/// Function Args
const fa = abi.RegisterClass.fa;
/// Function Returns
const fr = abi.RegisterClass.fr;
/// Temporary Use
const tp = abi.RegisterClass.tp;

const InnerError = CodeGenError || error{OutOfRegisters};

const RegisterView = enum(u1) {
    caller,
    callee,
};

gpa: Allocator,
air: Air,
mod: *Package.Module,
liveness: Liveness,
bin_file: *link.File,
target: *const std.Target,
func_index: InternPool.Index,
code: *std.ArrayList(u8),
debug_output: DebugInfoOutput,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: InstTracking,
fn_type: Type,
arg_index: usize,
src_loc: Module.SrcLoc,

/// MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .{},
/// MIR extra data
mir_extra: std.ArrayListUnmanaged(u32) = .{},

/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,

scope_generation: u32,

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

const_tracking: ConstTrackingMap = .{},
inst_tracking: InstTrackingMap = .{},

frame_allocs: std.MultiArrayList(FrameAlloc) = .{},
free_frame_indices: std.AutoArrayHashMapUnmanaged(FrameIndex, void) = .{},
frame_locs: std.MultiArrayList(Mir.FrameLoc) = .{},

/// Debug field, used to find bugs in the compiler.
air_bookkeeping: @TypeOf(air_bookkeeping_init) = air_bookkeeping_init,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const SymbolOffset = struct { sym: u32, off: i32 = 0 };
const RegisterOffset = struct { reg: Register, off: i32 = 0 };
pub const FrameAddr = struct { index: FrameIndex, off: i32 = 0 };

const MCValue = union(enum) {
    /// No runtime bits. `void` types, empty structs, u0, enums with 1 tag, etc.
    /// TODO Look into deleting this tag and using `dead` instead, since every use
    /// of MCValue.none should be instead looking at the type and noticing it is 0 bits.
    none,
    /// Control flow will not allow this value to be observed.
    unreach,
    /// No more references to this value remain.
    /// The payload is the value of scope_generation at the point where the death occurred
    dead: u32,
    /// The value is undefined.
    undef,
    /// A pointer-sized integer that fits in a register.
    /// If the type is a pointer, this is the pointer address in virtual address space.
    immediate: u64,
    /// The value doesn't exist in memory yet.
    load_symbol: SymbolOffset,
    /// The address of the memory location not-yet-allocated by the linker.
    lea_symbol: SymbolOffset,
    /// The value is in a target-specific register.
    register: Register,
    /// The value is split across two registers
    register_pair: [2]Register,
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value stored at an offset from a frame index
    /// Payload is a frame address.
    load_frame: FrameAddr,
    /// The address of an offset from a frame index
    /// Payload is a frame address.
    lea_frame: FrameAddr,
    air_ref: Air.Inst.Ref,
    /// The value is in memory at a constant offset from the address in a register.
    indirect: RegisterOffset,
    /// The value is a constant offset from the value in a register.
    register_offset: RegisterOffset,
    /// This indicates that we have already allocated a frame index for this instruction,
    /// but it has not been spilled there yet in the current control flow.
    /// Payload is a frame index.
    reserved_frame: FrameIndex,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory, .indirect, .load_frame => true,
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
            .lea_frame,
            .undef,
            .lea_symbol,
            .air_ref,
            .reserved_frame,
            => false,

            .register,
            .register_pair,
            .register_offset,
            .load_frame,
            .load_symbol,
            .indirect,
            => true,
        };
    }

    fn address(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .immediate,
            .lea_frame,
            .register_offset,
            .register_pair,
            .register,
            .undef,
            .air_ref,
            .lea_symbol,
            .reserved_frame,
            => unreachable, // not in memory

            .load_symbol => |sym_off| .{ .lea_symbol = sym_off },
            .memory => |addr| .{ .immediate = addr },
            .load_frame => |off| .{ .lea_frame = off },
            .indirect => |reg_off| switch (reg_off.off) {
                0 => .{ .register = reg_off.reg },
                else => .{ .register_offset = reg_off },
            },
        };
    }

    fn deref(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .memory,
            .indirect,
            .undef,
            .air_ref,
            .load_frame,
            .register_pair,
            .load_symbol,
            .reserved_frame,
            => unreachable, // not a pointer

            .immediate => |addr| .{ .memory = addr },
            .lea_frame => |off| .{ .load_frame = off },
            .register => |reg| .{ .indirect = .{ .reg = reg } },
            .register_offset => |reg_off| .{ .indirect = reg_off },
            .lea_symbol => |sym_off| .{ .load_symbol = sym_off },
        };
    }

    fn offset(mcv: MCValue, off: i32) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .air_ref,
            .reserved_frame,
            => unreachable, // not valid
            .register_pair,
            .memory,
            .indirect,
            .load_frame,
            .load_symbol,
            .lea_symbol,
            => switch (off) {
                0 => mcv,
                else => unreachable, // not offsettable
            },
            .immediate => |imm| .{ .immediate = @bitCast(@as(i64, @bitCast(imm)) +% off) },
            .register => |reg| .{ .register_offset = .{ .reg = reg, .off = off } },
            .register_offset => |reg_off| .{ .register_offset = .{ .reg = reg_off.reg, .off = reg_off.off + off } },
            .lea_frame => |frame_addr| .{
                .lea_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
            },
        };
    }

    fn getReg(mcv: MCValue) ?Register {
        return switch (mcv) {
            .register => |reg| reg,
            .register_offset, .indirect => |ro| ro.reg,
            else => null,
        };
    }

    fn getRegs(mcv: *const MCValue) []const Register {
        return switch (mcv.*) {
            .register => |*reg| @as(*const [1]Register, reg),
            .register_pair => |*regs| regs,
            .register_offset, .indirect => |*ro| @as(*const [1]Register, &ro.reg),
            else => &.{},
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

const InstTrackingMap = std.AutoArrayHashMapUnmanaged(Air.Inst.Index, InstTracking);
const ConstTrackingMap = std.AutoArrayHashMapUnmanaged(InternPool.Index, InstTracking);
const InstTracking = struct {
    long: MCValue,
    short: MCValue,

    fn init(result: MCValue) InstTracking {
        return .{ .long = switch (result) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_frame,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => result,
            .dead,
            .reserved_frame,
            .air_ref,
            => unreachable,
            .register,
            .register_pair,
            .register_offset,
            .indirect,
            => .none,
        }, .short = result };
    }

    fn getReg(self: InstTracking) ?Register {
        return self.short.getReg();
    }

    fn getRegs(self: *const InstTracking) []const Register {
        return self.short.getRegs();
    }

    fn spill(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        if (std.meta.eql(self.long, self.short)) return; // Already spilled
        // Allocate or reuse frame index
        switch (self.long) {
            .none => self.long = try function.allocRegOrMem(inst, false),
            .load_frame => {},
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => unreachable,
        }
        tracking_log.debug("spill %{d} from {} to {}", .{ inst, self.short, self.long });
        try function.genCopy(function.typeOfIndex(inst), self.long, self.short);
    }

    fn reuseFrame(self: *InstTracking) void {
        switch (self.long) {
            .reserved_frame => |index| self.long = .{ .load_frame = .{ .index = index } },
            else => {},
        }
        self.short = switch (self.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_frame,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => self.long,
            .dead,
            .register,
            .register_pair,
            .register_offset,
            .indirect,
            .reserved_frame,
            .air_ref,
            => unreachable,
        };
    }

    fn trackSpill(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        try function.freeValue(self.short);
        self.reuseFrame();
        tracking_log.debug("%{d} => {} (spilled)", .{ inst, self.* });
    }

    fn verifyMaterialize(self: InstTracking, target: InstTracking) void {
        switch (self.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .lea_frame,
            .load_symbol,
            .lea_symbol,
            => assert(std.meta.eql(self.long, target.long)),
            .load_frame,
            .reserved_frame,
            => switch (target.long) {
                .none,
                .load_frame,
                .reserved_frame,
                => {},
                else => unreachable,
            },
            .dead,
            .register,
            .register_pair,
            .register_offset,
            .indirect,
            .air_ref,
            => unreachable,
        }
    }

    fn materialize(
        self: *InstTracking,
        function: *Self,
        inst: Air.Inst.Index,
        target: InstTracking,
    ) !void {
        self.verifyMaterialize(target);
        try self.materializeUnsafe(function, inst, target);
    }

    fn materializeUnsafe(
        self: InstTracking,
        function: *Self,
        inst: Air.Inst.Index,
        target: InstTracking,
    ) !void {
        const ty = function.typeOfIndex(inst);
        if ((self.long == .none or self.long == .reserved_frame) and target.long == .load_frame)
            try function.genCopy(ty, target.long, self.short);
        try function.genCopy(ty, target.short, self.short);
    }

    fn trackMaterialize(self: *InstTracking, inst: Air.Inst.Index, target: InstTracking) void {
        self.verifyMaterialize(target);
        // Don't clobber reserved frame indices
        self.long = if (target.long == .none) switch (self.long) {
            .load_frame => |addr| .{ .reserved_frame = addr.index },
            .reserved_frame => self.long,
            else => target.long,
        } else target.long;
        self.short = target.short;
        tracking_log.debug("%{d} => {} (materialize)", .{ inst, self.* });
    }

    fn resurrect(self: *InstTracking, inst: Air.Inst.Index, scope_generation: u32) void {
        switch (self.short) {
            .dead => |die_generation| if (die_generation >= scope_generation) {
                self.reuseFrame();
                tracking_log.debug("%{d} => {} (resurrect)", .{ inst, self.* });
            },
            else => {},
        }
    }

    fn die(self: *InstTracking, function: *Self, inst: Air.Inst.Index) !void {
        if (self.short == .dead) return;
        try function.freeValue(self.short);
        self.short = .{ .dead = function.scope_generation };
        tracking_log.debug("%{d} => {} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        function: *Self,
        new_inst: ?Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        self.short = .{ .dead = function.scope_generation };
        if (new_inst) |inst|
            tracking_log.debug("%{d} => {} (reuse %{d})", .{ inst, self.*, old_inst })
        else
            tracking_log.debug("tmp => {} (reuse %{d})", .{ self.*, old_inst });
    }

    fn liveOut(self: *InstTracking, function: *Self, inst: Air.Inst.Index) void {
        for (self.getRegs()) |reg| {
            if (function.register_manager.isRegFree(reg)) {
                tracking_log.debug("%{d} => {} (live-out)", .{ inst, self.* });
                continue;
            }

            const index = RegisterManager.indexOfRegIntoTracked(reg).?;
            const tracked_inst = function.register_manager.registers[index];
            const tracking = function.getResolvedInstValue(tracked_inst);

            // Disable death.
            var found_reg = false;
            var remaining_reg: Register = .zero;
            for (tracking.getRegs()) |tracked_reg| if (tracked_reg.id() == reg.id()) {
                assert(!found_reg);
                found_reg = true;
            } else {
                assert(remaining_reg == .zero);
                remaining_reg = tracked_reg;
            };
            assert(found_reg);
            tracking.short = switch (remaining_reg) {
                .zero => .{ .dead = function.scope_generation },
                else => .{ .register = remaining_reg },
            };

            // Perform side-effects of freeValue manually.
            function.register_manager.freeReg(reg);

            tracking_log.debug("%{d} => {} (live-out %{d})", .{ inst, self.*, tracked_inst });
        }
    }

    pub fn format(
        self: InstTracking,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        if (!std.meta.eql(self.long, self.short)) try writer.print("|{}| ", .{self.long});
        try writer.print("{}", .{self.short});
    }
};

const FrameAlloc = struct {
    abi_size: u31,
    spill_pad: u3,
    abi_align: Alignment,
    ref_count: u16,

    fn init(alloc_abi: struct { size: u64, pad: u3 = 0, alignment: Alignment }) FrameAlloc {
        return .{
            .abi_size = @intCast(alloc_abi.size),
            .spill_pad = alloc_abi.pad,
            .abi_align = alloc_abi.alignment,
            .ref_count = 0,
        };
    }
    fn initType(ty: Type, zcu: *Module) FrameAlloc {
        return init(.{
            .size = ty.abiSize(zcu),
            .alignment = ty.abiAlignment(zcu),
        });
    }
    fn initSpill(ty: Type, zcu: *Module) FrameAlloc {
        const abi_size = ty.abiSize(zcu);
        const spill_size = if (abi_size < 8)
            math.ceilPowerOfTwoAssert(u64, abi_size)
        else
            std.mem.alignForward(u64, abi_size, 8);
        return init(.{
            .size = spill_size,
            .pad = @intCast(spill_size - abi_size),
            .alignment = ty.abiAlignment(zcu).maxStrict(
                Alignment.fromNonzeroByteUnits(@min(spill_size, 8)),
            ),
        });
    }
};

const StackAllocation = struct {
    inst: ?Air.Inst.Index,
    /// TODO: make the size inferred from the bits of the inst
    size: u32,
};

const BlockData = struct {
    relocs: std.ArrayListUnmanaged(Mir.Inst.Index) = .{},
    state: State,

    fn deinit(self: *BlockData, gpa: Allocator) void {
        self.relocs.deinit(gpa);
        self.* = undefined;
    }
};

const State = struct {
    registers: RegisterManager.TrackedRegisters,
    reg_tracking: [RegisterManager.RegisterBitSet.bit_length]InstTracking,
    free_registers: RegisterManager.RegisterBitSet,
    inst_tracking_len: u32,
    scope_generation: u32,
};

fn initRetroactiveState(self: *Self) State {
    var state: State = undefined;
    state.inst_tracking_len = @intCast(self.inst_tracking.count());
    state.scope_generation = self.scope_generation;
    return state;
}

fn saveRetroactiveState(self: *Self, state: *State) !void {
    const free_registers = self.register_manager.free_registers;
    var it = free_registers.iterator(.{ .kind = .unset });
    while (it.next()) |index| {
        const tracked_inst = self.register_manager.registers[index];
        state.registers[index] = tracked_inst;
        state.reg_tracking[index] = self.inst_tracking.get(tracked_inst).?;
    }
    state.free_registers = free_registers;
}

fn saveState(self: *Self) !State {
    var state = self.initRetroactiveState();
    try self.saveRetroactiveState(&state);
    return state;
}

fn restoreState(self: *Self, state: State, deaths: []const Air.Inst.Index, comptime opts: struct {
    emit_instructions: bool,
    update_tracking: bool,
    resurrect: bool,
    close_scope: bool,
}) !void {
    if (opts.close_scope) {
        for (
            self.inst_tracking.keys()[state.inst_tracking_len..],
            self.inst_tracking.values()[state.inst_tracking_len..],
        ) |inst, *tracking| try tracking.die(self, inst);
        self.inst_tracking.shrinkRetainingCapacity(state.inst_tracking_len);
    }

    if (opts.resurrect) for (
        self.inst_tracking.keys()[0..state.inst_tracking_len],
        self.inst_tracking.values()[0..state.inst_tracking_len],
    ) |inst, *tracking| tracking.resurrect(inst, state.scope_generation);
    for (deaths) |death| try self.processDeath(death);

    const ExpectedContents = [@typeInfo(RegisterManager.TrackedRegisters).Array.len]RegisterLock;
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        if (opts.update_tracking)
    {} else std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);

    var reg_locks = if (opts.update_tracking) {} else try std.ArrayList(RegisterLock).initCapacity(
        stack.get(),
        @typeInfo(ExpectedContents).Array.len,
    );
    defer if (!opts.update_tracking) {
        for (reg_locks.items) |lock| self.register_manager.unlockReg(lock);
        reg_locks.deinit();
    };

    for (0..state.registers.len) |index| {
        const current_maybe_inst = if (self.register_manager.free_registers.isSet(index))
            null
        else
            self.register_manager.registers[index];
        const target_maybe_inst = if (state.free_registers.isSet(index))
            null
        else
            state.registers[index];
        if (std.debug.runtime_safety) if (target_maybe_inst) |target_inst|
            assert(self.inst_tracking.getIndex(target_inst).? < state.inst_tracking_len);
        if (opts.emit_instructions) {
            if (current_maybe_inst) |current_inst| {
                try self.inst_tracking.getPtr(current_inst).?.spill(self, current_inst);
            }
            if (target_maybe_inst) |target_inst| {
                const target_tracking = self.inst_tracking.getPtr(target_inst).?;
                try target_tracking.materialize(self, target_inst, state.reg_tracking[index]);
            }
        }
        if (opts.update_tracking) {
            if (current_maybe_inst) |current_inst| {
                try self.inst_tracking.getPtr(current_inst).?.trackSpill(self, current_inst);
            }
            {
                const reg = RegisterManager.regAtTrackedIndex(@intCast(index));
                self.register_manager.freeReg(reg);
                self.register_manager.getRegAssumeFree(reg, target_maybe_inst);
            }
            if (target_maybe_inst) |target_inst| {
                self.inst_tracking.getPtr(target_inst).?.trackMaterialize(
                    target_inst,
                    state.reg_tracking[index],
                );
            }
        } else if (target_maybe_inst) |_|
            try reg_locks.append(self.register_manager.lockRegIndexAssumeUnused(@intCast(index)));
    }

    if (opts.update_tracking and std.debug.runtime_safety) {
        assert(self.register_manager.free_registers.eql(state.free_registers));
        var used_reg_it = state.free_registers.iterator(.{ .kind = .unset });
        while (used_reg_it.next()) |index|
            assert(self.register_manager.registers[index] == state.registers[index]);
    }
}

const Self = @This();

const CallView = enum(u1) {
    callee,
    caller,
};

pub fn generate(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    const comp = bin_file.comp;
    const gpa = comp.gpa;
    const zcu = comp.module.?;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const fn_owner_decl = zcu.declPtr(func.owner_decl);
    assert(fn_owner_decl.has_tv);
    const fn_type = fn_owner_decl.typeOf(zcu);
    const namespace = zcu.namespacePtr(fn_owner_decl.src_namespace);
    const target = &namespace.file_scope.mod.resolved_target.result;
    const mod = namespace.file_scope.mod;

    var branch_stack = std.ArrayList(Branch).init(gpa);
    defer {
        assert(branch_stack.items.len == 1);
        branch_stack.items[0].deinit(gpa);
        branch_stack.deinit();
    }
    try branch_stack.append(.{});

    var function = Self{
        .gpa = gpa,
        .air = air,
        .mod = mod,
        .liveness = liveness,
        .target = target,
        .bin_file = bin_file,
        .func_index = func_index,
        .code = code,
        .debug_output = debug_output,
        .err_msg = null,
        .args = undefined, // populated after `resolveCallingConventionValues`
        .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
        .fn_type = fn_type,
        .arg_index = 0,
        .branch_stack = &branch_stack,
        .src_loc = src_loc,
        .end_di_line = func.rbrace_line,
        .end_di_column = func.rbrace_column,
        .scope_generation = 0,
    };
    defer {
        function.frame_allocs.deinit(gpa);
        function.free_frame_indices.deinit(gpa);
        function.frame_locs.deinit(gpa);
        var block_it = function.blocks.valueIterator();
        while (block_it.next()) |block| block.deinit(gpa);
        function.blocks.deinit(gpa);
        function.inst_tracking.deinit(gpa);
        function.const_tracking.deinit(gpa);
        function.exitlude_jump_relocs.deinit(gpa);
        function.mir_instructions.deinit(gpa);
        function.mir_extra.deinit(gpa);
    }

    try function.frame_allocs.resize(gpa, FrameIndex.named_count);
    function.frame_allocs.set(
        @intFromEnum(FrameIndex.stack_frame),
        FrameAlloc.init(.{
            .size = 0,
            .alignment = func.analysis(ip).stack_alignment.max(.@"1"),
        }),
    );
    function.frame_allocs.set(
        @intFromEnum(FrameIndex.call_frame),
        FrameAlloc.init(.{ .size = 0, .alignment = .@"1" }),
    );

    const fn_info = zcu.typeToFunc(fn_type).?;
    var call_info = function.resolveCallingConventionValues(fn_info) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    defer call_info.deinit(&function);

    function.args = call_info.args;
    function.ret_mcv = call_info.return_value;
    function.frame_allocs.set(@intFromEnum(FrameIndex.ret_addr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = Type.usize.abiAlignment(zcu).min(call_info.stack_align),
    }));
    function.frame_allocs.set(@intFromEnum(FrameIndex.base_ptr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(zcu),
        .alignment = Alignment.min(
            call_info.stack_align,
            Alignment.fromNonzeroByteUnits(function.target.stackAlignment()),
        ),
    }));
    function.frame_allocs.set(@intFromEnum(FrameIndex.args_frame), FrameAlloc.init(.{
        .size = call_info.stack_byte_count,
        .alignment = call_info.stack_align,
    }));
    function.frame_allocs.set(@intFromEnum(FrameIndex.spill_frame), FrameAlloc.init(.{
        .size = 0,
        .alignment = Type.usize.abiAlignment(zcu),
    }));

    function.gen() catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(gpa, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(gpa),
        .frame_locs = function.frame_locs.toOwnedSlice(),
    };
    defer mir.deinit(gpa);

    var emit = Emit{
        .lower = .{
            .bin_file = bin_file,
            .allocator = gpa,
            .mir = mir,
            .cc = fn_info.cc,
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .debug_output = debug_output,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = func.lbrace_line,
        .prev_di_column = func.lbrace_column,
    };
    defer emit.deinit();

    emit.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return Result{ .fail = emit.lower.err_msg.? },
        error.InvalidInstruction => |e| {
            const msg = switch (e) {
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
            };
            return Result{
                .fail = try ErrorMsg.create(
                    gpa,
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

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;

    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);

    const result_index: Mir.Inst.Index = @intCast(self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    return result_index;
}

fn addNop(self: *Self) error{OutOfMemory}!Mir.Inst.Index {
    return self.addInst(.{
        .tag = .nop,
        .ops = .none,
        .data = undefined,
    });
}

fn addPseudoNone(self: *Self, ops: Mir.Inst.Ops) !void {
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = undefined,
    });
}

fn addPseudo(self: *Self, ops: Mir.Inst.Ops) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .pseudo,
        .ops = ops,
        .data = undefined,
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
    const fn_info = mod.typeToFunc(self.fn_type).?;

    if (fn_info.cc != .Naked) {
        try self.addPseudoNone(.pseudo_dbg_prologue_end);

        const backpatch_stack_alloc = try self.addPseudo(.pseudo_dead);
        const backpatch_ra_spill = try self.addPseudo(.pseudo_dead);
        const backpatch_fp_spill = try self.addPseudo(.pseudo_dead);
        const backpatch_fp_add = try self.addPseudo(.pseudo_dead);
        const backpatch_spill_callee_preserved_regs = try self.addPseudo(.pseudo_dead);

        try self.genBody(self.air.getMainBody());

        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.items(.data)[jmp_reloc].inst =
                @intCast(self.mir_instructions.len);
        }

        try self.addPseudoNone(.pseudo_dbg_epilogue_begin);

        const backpatch_restore_callee_preserved_regs = try self.addPseudo(.pseudo_dead);
        const backpatch_ra_restore = try self.addPseudo(.pseudo_dead);
        const backpatch_fp_restore = try self.addPseudo(.pseudo_dead);
        const backpatch_stack_alloc_restore = try self.addPseudo(.pseudo_dead);
        try self.addPseudoNone(.pseudo_ret);

        const frame_layout = try self.computeFrameLayout();
        const need_save_reg = frame_layout.save_reg_list.count() > 0;

        self.mir_instructions.set(backpatch_stack_alloc, .{
            .tag = .addi,
            .ops = .rri,
            .data = .{ .i_type = .{
                .rd = .sp,
                .rs1 = .sp,
                .imm12 = Immediate.s(-@as(i32, @intCast(frame_layout.stack_adjust))),
            } },
        });
        self.mir_instructions.set(backpatch_ra_spill, .{
            .tag = .pseudo,
            .ops = .pseudo_store_rm,
            .data = .{ .rm = .{
                .r = .ra,
                .m = .{
                    .base = .{ .frame = .ret_addr },
                    .mod = .{ .rm = .{ .size = .dword } },
                },
            } },
        });
        self.mir_instructions.set(backpatch_ra_restore, .{
            .tag = .pseudo,
            .ops = .pseudo_load_rm,
            .data = .{ .rm = .{
                .r = .ra,
                .m = .{
                    .base = .{ .frame = .ret_addr },
                    .mod = .{ .rm = .{ .size = .dword } },
                },
            } },
        });
        self.mir_instructions.set(backpatch_fp_spill, .{
            .tag = .pseudo,
            .ops = .pseudo_store_rm,
            .data = .{ .rm = .{
                .r = .s0,
                .m = .{
                    .base = .{ .frame = .base_ptr },
                    .mod = .{ .rm = .{ .size = .dword } },
                },
            } },
        });
        self.mir_instructions.set(backpatch_fp_restore, .{
            .tag = .pseudo,
            .ops = .pseudo_load_rm,
            .data = .{ .rm = .{
                .r = .s0,
                .m = .{
                    .base = .{ .frame = .base_ptr },
                    .mod = .{ .rm = .{ .size = .dword } },
                },
            } },
        });
        self.mir_instructions.set(backpatch_fp_add, .{
            .tag = .addi,
            .ops = .rri,
            .data = .{ .i_type = .{
                .rd = .s0,
                .rs1 = .sp,
                .imm12 = Immediate.s(@intCast(frame_layout.stack_adjust)),
            } },
        });
        self.mir_instructions.set(backpatch_stack_alloc_restore, .{
            .tag = .addi,
            .ops = .rri,
            .data = .{ .i_type = .{
                .rd = .sp,
                .rs1 = .sp,
                .imm12 = Immediate.s(@intCast(frame_layout.stack_adjust)),
            } },
        });

        if (need_save_reg) {
            self.mir_instructions.set(backpatch_spill_callee_preserved_regs, .{
                .tag = .pseudo,
                .ops = .pseudo_spill_regs,
                .data = .{ .reg_list = frame_layout.save_reg_list },
            });

            self.mir_instructions.set(backpatch_restore_callee_preserved_regs, .{
                .tag = .pseudo,
                .ops = .pseudo_restore_regs,
                .data = .{ .reg_list = frame_layout.save_reg_list },
            });
        }
    } else {
        try self.addPseudoNone(.pseudo_dbg_prologue_end);
        try self.genBody(self.air.getMainBody());
        try self.addPseudoNone(.pseudo_dbg_epilogue_begin);
    }

    // Drop them off at the rbrace.
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_line_column,
        .data = .{ .pseudo_dbg_line_column = .{
            .line = self.end_di_line,
            .column = self.end_di_column,
        } },
    });
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    const zcu = self.bin_file.comp.module.?;
    const ip = &zcu.intern_pool;
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst, ip)) continue;

        const old_air_bookkeeping = self.air_bookkeeping;
        try self.inst_tracking.ensureUnusedCapacity(self.gpa, 1);
        switch (air_tags[@intFromEnum(inst)]) {
            // zig fmt: off
            .ptr_add => try self.airPtrArithmetic(inst, .ptr_add),
            .ptr_sub => try self.airPtrArithmetic(inst, .ptr_sub),

            .add => try self.airBinOp(inst, .add),
            .sub => try self.airBinOp(inst, .sub),

            .add_safe,
            .sub_safe,
            .mul_safe,
            => return self.fail("TODO implement safety_checked_instructions", .{}),

            .add_wrap        => try self.airAddWrap(inst),
            .add_sat         => try self.airAddSat(inst),
            .sub_wrap        => try self.airSubWrap(inst),
            .sub_sat         => try self.airSubSat(inst),
            .mul             => try self.airMul(inst),
            .mul_wrap        => try self.airMulWrap(inst),
            .mul_sat         => try self.airMulSat(inst),
            .rem             => try self.airRem(inst),
            .mod             => try self.airMod(inst),
            .shl, .shl_exact => try self.airShl(inst),
            .shl_sat         => try self.airShlSat(inst),
            .min             => try self.airMinMax(inst, .min),
            .max             => try self.airMinMax(inst, .max),
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

            .add_with_overflow => try self.airAddWithOverflow(inst),
            .sub_with_overflow => try self.airSubWithOverflow(inst),
            .mul_with_overflow => try self.airMulWithOverflow(inst),
            .shl_with_overflow => try self.airShlWithOverflow(inst),

            .div_float, .div_trunc, .div_floor, .div_exact => try self.airDiv(inst),

            .cmp_lt  => try self.airCmp(inst),
            .cmp_lte => try self.airCmp(inst),
            .cmp_eq  => try self.airCmp(inst),
            .cmp_gte => try self.airCmp(inst),
            .cmp_gt  => try self.airCmp(inst),
            .cmp_neq => try self.airCmp(inst),

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
            .trap            => try self.airTrap(),
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
            .int_from_bool   => try self.airIntFromBool(inst),
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
            .int_from_ptr    => try self.airIntFromPtr(inst),
            .ret             => try self.airRet(inst, false),
            .ret_safe        => try self.airRet(inst, true),
            .ret_load        => try self.airRetLoad(inst),
            .store           => try self.airStore(inst, false),
            .store_safe      => try self.airStore(inst, true),
            .struct_field_ptr=> try self.airStructFieldPtr(inst),
            .struct_field_val=> try self.airStructFieldVal(inst),
            .array_to_slice  => try self.airArrayToSlice(inst),
            .float_from_int  => try self.airFloatFromInt(inst),
            .int_from_float  => try self.airIntFromFloat(inst),
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
            .addrspace_cast  => return self.fail("TODO: addrspace_cast", .{}),

            .@"try"          =>  try self.airTry(inst),
            .try_ptr         =>  return self.fail("TODO: try_ptr", .{}),

            .dbg_var_ptr,
            .dbg_var_val,
            => try self.airDbgVar(inst),

            .dbg_inline_block => try self.airDbgInlineBlock(inst),

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

            { // check consistency of tracked registers
                var it = self.register_manager.free_registers.iterator(.{ .kind = .unset });
                while (it.next()) |index| {
                    const tracked_inst = self.register_manager.registers[index];
                    const tracking = self.getResolvedInstValue(tracked_inst);
                    for (tracking.getRegs()) |reg| {
                        if (RegisterManager.indexOfRegIntoTracked(reg).? == index) break;
                    } else return self.fail(
                        \\%{} takes up these regs: {any}, however those regs don't use it
                    , .{ index, tracking.getRegs() });
                }
            }
        }
    }
}

fn getValue(self: *Self, value: MCValue, inst: ?Air.Inst.Index) !void {
    for (value.getRegs()) |reg| try self.register_manager.getReg(reg, inst);
}

fn getValueIfFree(self: *Self, value: MCValue, inst: ?Air.Inst.Index) void {
    for (value.getRegs()) |reg| if (self.register_manager.isRegFree(reg))
        self.register_manager.getRegAssumeFree(reg, inst);
}

fn freeValue(self: *Self, value: MCValue) !void {
    switch (value) {
        .register => |reg| self.register_manager.freeReg(reg),
        .register_pair => |regs| for (regs) |reg| self.register_manager.freeReg(reg),
        .register_offset => |reg_off| self.register_manager.freeReg(reg_off.reg),
        else => {}, // TODO process stack allocation death
    }
}

fn feed(self: *Self, bt: *Liveness.BigTomb, operand: Air.Inst.Ref) !void {
    if (bt.feed()) if (operand.toIndex()) |inst| {
        log.debug("feed inst: %{}", .{inst});
        try self.processDeath(inst);
    };
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) !void {
    try self.inst_tracking.getPtr(inst).?.die(self, inst);
}

/// Called when there are no operands, and the instruction is always unreferenced.
fn finishAirBookkeeping(self: *Self) void {
    if (std.debug.runtime_safety) {
        self.air_bookkeeping += 1;
    }
}

fn finishAirResult(self: *Self, inst: Air.Inst.Index, result: MCValue) void {
    if (self.liveness.isUnused(inst)) switch (result) {
        .none, .dead, .unreach => {},
        else => unreachable, // Why didn't the result die?
    } else {
        tracking_log.debug("%{d} => {} (birth)", .{ inst, result });
        self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(result));
        // In some cases, an operand may be reused as the result.
        // If that operand died and was a register, it was freed by
        // processDeath, so we have to "re-allocate" the register.
        self.getValueIfFree(result, inst);
    }
    self.finishAirBookkeeping();
}

fn finishAir(
    self: *Self,
    inst: Air.Inst.Index,
    result: MCValue,
    operands: [Liveness.bpi - 1]Air.Inst.Ref,
) !void {
    var tomb_bits = self.liveness.getTombBits(inst);
    for (operands) |op| {
        const dies = @as(u1, @truncate(tomb_bits)) != 0;
        tomb_bits >>= 1;
        if (!dies) continue;
        try self.processDeath(op.toIndexAllowNone() orelse continue);
    }
    self.finishAirResult(inst, result);
}

const FrameLayout = struct {
    stack_adjust: u32,
    save_reg_list: Mir.RegisterList,
};

fn setFrameLoc(
    self: *Self,
    frame_index: FrameIndex,
    base: Register,
    offset: *i32,
    comptime aligned: bool,
) void {
    const frame_i = @intFromEnum(frame_index);
    if (aligned) {
        const alignment: InternPool.Alignment = self.frame_allocs.items(.abi_align)[frame_i];
        offset.* = if (math.sign(offset.*) < 0)
            -1 * @as(i32, @intCast(alignment.backward(@intCast(@abs(offset.*)))))
        else
            @intCast(alignment.forward(@intCast(@abs(offset.*))));
    }
    self.frame_locs.set(frame_i, .{ .base = base, .disp = offset.* });
    offset.* += self.frame_allocs.items(.abi_size)[frame_i];
}

fn computeFrameLayout(self: *Self) !FrameLayout {
    const frame_allocs_len = self.frame_allocs.len;
    try self.frame_locs.resize(self.gpa, frame_allocs_len);
    const stack_frame_order = try self.gpa.alloc(FrameIndex, frame_allocs_len - FrameIndex.named_count);
    defer self.gpa.free(stack_frame_order);

    const frame_size = self.frame_allocs.items(.abi_size);
    const frame_align = self.frame_allocs.items(.abi_align);

    for (stack_frame_order, FrameIndex.named_count..) |*frame_order, frame_index|
        frame_order.* = @enumFromInt(frame_index);

    {
        const SortContext = struct {
            frame_align: @TypeOf(frame_align),
            pub fn lessThan(context: @This(), lhs: FrameIndex, rhs: FrameIndex) bool {
                return context.frame_align[@intFromEnum(lhs)].compare(.gt, context.frame_align[@intFromEnum(rhs)]);
            }
        };
        const sort_context = SortContext{ .frame_align = frame_align };
        mem.sort(FrameIndex, stack_frame_order, sort_context, SortContext.lessThan);
    }

    var save_reg_list = Mir.RegisterList{};
    for (callee_preserved_regs) |reg| {
        if (self.register_manager.isRegAllocated(reg)) {
            save_reg_list.push(&callee_preserved_regs, reg);
        }
    }

    const total_alloc_size: i32 = blk: {
        var i: i32 = 0;
        for (stack_frame_order) |frame_index| {
            i += frame_size[@intFromEnum(frame_index)];
        }
        break :blk i;
    };
    const saved_reg_size = save_reg_list.size();

    frame_size[@intFromEnum(FrameIndex.spill_frame)] = @intCast(saved_reg_size);

    // The total frame size is calculated by the amount of s registers you need to save * 8, as each
    // register is 8 bytes, the total allocation sizes, and 16 more register for the spilled ra and s0
    // register. Finally we align the frame size to the align of the base pointer.
    const args_frame_size = frame_size[@intFromEnum(FrameIndex.args_frame)];
    const spill_frame_size = frame_size[@intFromEnum(FrameIndex.spill_frame)];
    const call_frame_size = frame_size[@intFromEnum(FrameIndex.call_frame)];

    // TODO: this 64 should be a 16, but we were clobbering the top and bottom of the frame.
    // maybe everything can go from the bottom?
    const acc_frame_size: i32 = std.mem.alignForward(
        i32,
        total_alloc_size + 64 + args_frame_size + spill_frame_size + call_frame_size,
        @intCast(frame_align[@intFromEnum(FrameIndex.base_ptr)].toByteUnits().?),
    );
    log.debug("frame size: {}", .{acc_frame_size});

    // store the ra at total_size - 8, so it's the very first thing in the stack
    // relative to the fp
    self.frame_locs.set(
        @intFromEnum(FrameIndex.ret_addr),
        .{ .base = .sp, .disp = acc_frame_size - 8 },
    );
    self.frame_locs.set(
        @intFromEnum(FrameIndex.base_ptr),
        .{ .base = .sp, .disp = acc_frame_size - 16 },
    );

    // now we grow the stack frame from the bottom of total frame in order to
    // not need to know the size of the first allocation. Stack offsets point at the "bottom"
    // of variables.
    var s0_offset: i32 = -acc_frame_size;
    self.setFrameLoc(.stack_frame, .s0, &s0_offset, true);
    for (stack_frame_order) |frame_index| self.setFrameLoc(frame_index, .s0, &s0_offset, true);
    self.setFrameLoc(.args_frame, .s0, &s0_offset, true);
    self.setFrameLoc(.call_frame, .s0, &s0_offset, true);
    self.setFrameLoc(.spill_frame, .s0, &s0_offset, true);

    return .{
        .stack_adjust = @intCast(acc_frame_size),
        .save_reg_list = save_reg_list,
    };
}

fn ensureProcessDeathCapacity(self: *Self, additional_count: usize) !void {
    const table = &self.branch_stack.items[self.branch_stack.items.len - 1].inst_table;
    try table.ensureUnusedCapacity(self.gpa, additional_count);
}

fn memSize(self: *Self, ty: Type) Memory.Size {
    const mod = self.bin_file.comp.module.?;
    return switch (ty.zigTypeTag(mod)) {
        .Float => Memory.Size.fromBitSize(ty.floatBits(self.target.*)),
        else => Memory.Size.fromByteSize(ty.abiSize(mod)),
    };
}

fn splitType(self: *Self, ty: Type) ![2]Type {
    const zcu = self.bin_file.comp.module.?;
    const classes = mem.sliceTo(&abi.classifySystem(ty, zcu), .none);
    var parts: [2]Type = undefined;
    if (classes.len == 2) for (&parts, classes, 0..) |*part, class, part_i| {
        part.* = switch (class) {
            .integer => switch (part_i) {
                0 => Type.u64,
                1 => part: {
                    const elem_size = ty.abiAlignment(zcu).minStrict(.@"8").toByteUnits().?;
                    const elem_ty = try zcu.intType(.unsigned, @intCast(elem_size * 8));
                    break :part switch (@divExact(ty.abiSize(zcu) - 8, elem_size)) {
                        1 => elem_ty,
                        else => |len| try zcu.arrayType(.{ .len = len, .child = elem_ty.toIntern() }),
                    };
                },
                else => unreachable,
            },
            else => return self.fail("TODO: splitType class {}", .{class}),
        };
    } else if (parts[0].abiSize(zcu) + parts[1].abiSize(zcu) == ty.abiSize(zcu)) return parts;
    return self.fail("TODO implement splitType for {}", .{ty.fmt(zcu)});
}

fn symbolIndex(self: *Self) !u32 {
    const zcu = self.bin_file.comp.module.?;
    const decl_index = zcu.funcOwnerDeclIndex(self.func_index);
    return switch (self.bin_file.tag) {
        .elf => blk: {
            const elf_file = self.bin_file.cast(link.File.Elf).?;
            const atom_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, decl_index);
            break :blk atom_index;
        },
        else => return self.fail("TODO genSetReg load_symbol for {s}", .{@tagName(self.bin_file.tag)}),
    };
}

fn allocFrameIndex(self: *Self, alloc: FrameAlloc) !FrameIndex {
    const frame_allocs_slice = self.frame_allocs.slice();
    const frame_size = frame_allocs_slice.items(.abi_size);
    const frame_align = frame_allocs_slice.items(.abi_align);

    const stack_frame_align = &frame_align[@intFromEnum(FrameIndex.stack_frame)];
    stack_frame_align.* = stack_frame_align.max(alloc.abi_align);

    for (self.free_frame_indices.keys(), 0..) |frame_index, free_i| {
        const abi_size = frame_size[@intFromEnum(frame_index)];
        if (abi_size != alloc.abi_size) continue;
        const abi_align = &frame_align[@intFromEnum(frame_index)];
        abi_align.* = abi_align.max(alloc.abi_align);

        _ = self.free_frame_indices.swapRemoveAt(free_i);
        return frame_index;
    }
    const frame_index: FrameIndex = @enumFromInt(self.frame_allocs.len);
    try self.frame_allocs.append(self.gpa, alloc);
    log.debug("allocated frame {}", .{frame_index});
    return frame_index;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !FrameIndex {
    const zcu = self.bin_file.comp.module.?;
    const ptr_ty = self.typeOfIndex(inst);
    const val_ty = ptr_ty.childType(zcu);
    return self.allocFrameIndex(FrameAlloc.init(.{
        .size = math.cast(u32, val_ty.abiSize(zcu)) orelse {
            return self.fail("type '{}' too big to fit into stack frame", .{val_ty.fmt(zcu)});
        },
        .alignment = ptr_ty.ptrAlignment(zcu).max(.@"1"),
    }));
}

fn allocRegOrMem(self: *Self, inst: Air.Inst.Index, reg_ok: bool) !MCValue {
    const zcu = self.bin_file.comp.module.?;
    const elem_ty = self.typeOfIndex(inst);

    const abi_size = math.cast(u32, elem_ty.abiSize(zcu)) orelse {
        return self.fail("type '{}' too big to fit into stack frame", .{elem_ty.fmt(zcu)});
    };

    if (reg_ok) {
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        if (abi_size <= ptr_bytes) {
            if (self.register_manager.tryAllocReg(inst, gp)) |reg| {
                return .{ .register = reg };
            }
        }
    }

    const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(elem_ty, zcu));
    return .{ .load_frame = .{ .index = frame_index } };
}

/// Allocates a register from the general purpose set and returns the Register and the Lock.
///
/// Up to the user to unlock the register later.
fn allocReg(self: *Self) !struct { Register, RegisterLock } {
    const reg = try self.register_manager.allocReg(null, gp);
    const lock = self.register_manager.lockRegAssumeUnused(reg);
    return .{ reg, lock };
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
                const lock = self.register_manager.lockRegAssumeUnused(reg);
                defer self.register_manager.unlockReg(lock);

                const result = try self.binOp(
                    .mul,
                    .{ .register = reg },
                    index_ty,
                    .{ .immediate = elem_size },
                    index_ty,
                );
                break :blk result.register;
            },
        }
    };
    return reg;
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const tracking = self.inst_tracking.getPtr(inst) orelse return;
    for (tracking.getRegs()) |tracked_reg| {
        if (tracked_reg.id() == reg.id()) break;
    } else unreachable; // spilled reg not tracked with spilled instruciton
    try tracking.spill(self, inst);
    try tracking.trackSpill(self, inst);
}

/// Copies a value to a register without tracking the register. The register is not considered
/// allocated. A second call to `copyToTmpRegister` may return the same register.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToTmpRegister(self: *Self, ty: Type, mcv: MCValue) !Register {
    const reg = try self.register_manager.allocReg(null, tp);
    try self.genSetReg(ty, reg, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
fn copyToNewRegister(self: *Self, reg_owner: Air.Inst.Index, mcv: MCValue) !MCValue {
    const reg = try self.register_manager.allocReg(reg_owner, gp);
    try self.genSetReg(self.typeOfIndex(reg_owner), reg, mcv);
    return MCValue{ .register = reg };
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const result = MCValue{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = switch (self.ret_mcv.long) {
        .none => .{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } },
        .load_frame => .{ .register_offset = .{
            .reg = (try self.copyToNewRegister(
                inst,
                self.ret_mcv.long,
            )).register,
            .off = self.ret_mcv.short.indirect.off,
        } },
        else => |t| return self.fail("TODO: airRetPtr {s}", .{@tagName(t)}),
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airFptrunc for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airFpext for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const src_ty = self.typeOf(ty_op.operand);
    const dst_ty = self.typeOfIndex(inst);

    const result: MCValue = result: {
        const src_int_info = src_ty.intInfo(zcu);
        const dst_int_info = dst_ty.intInfo(zcu);

        const min_ty = if (dst_int_info.bits < src_int_info.bits) dst_ty else src_ty;

        const src_mcv = try self.resolveInst(ty_op.operand);

        const src_storage_bits: u16 = switch (src_mcv) {
            .register => 64,
            .load_frame => src_int_info.bits,
            else => return self.fail("airIntCast from {s}", .{@tagName(src_mcv)}),
        };

        const dst_mcv = if (dst_int_info.bits <= src_storage_bits and
            math.divCeil(u16, dst_int_info.bits, 64) catch unreachable ==
            math.divCeil(u32, src_storage_bits, 64) catch unreachable and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) src_mcv else dst: {
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(min_ty, dst_mcv, src_mcv);
            break :dst dst_mcv;
        };

        if (dst_int_info.bits <= src_int_info.bits)
            break :result dst_mcv;

        if (dst_int_info.bits > 64 or src_int_info.bits > 64)
            break :result null; // TODO

        break :result dst_mcv;
    } orelse return self.fail("TODO implement airIntCast from {} to {}", .{
        src_ty.fmt(zcu), dst_ty.fmt(zcu),
    });

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    if (self.liveness.isUnused(inst))
        return self.finishAir(inst, .unreach, .{ ty_op.operand, .none, .none });

    const operand = try self.resolveInst(ty_op.operand);
    _ = operand;
    return self.fail("TODO implement trunc for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromBool(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else operand;
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airNot(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const zcu = self.bin_file.comp.module.?;

        const operand = try self.resolveInst(ty_op.operand);
        const ty = self.typeOf(ty_op.operand);

        switch (ty.zigTypeTag(zcu)) {
            .Bool => {
                const operand_reg = blk: {
                    if (operand == .register) break :blk operand.register;
                    break :blk try self.copyToTmpRegister(ty, operand);
                };

                const dst_reg: Register =
                    if (self.reuseOperand(inst, ty_op.operand, 0, operand) and operand == .register)
                    operand.register
                else
                    try self.register_manager.allocReg(inst, gp);

                _ = try self.addInst(.{
                    .tag = .pseudo,
                    .ops = .pseudo_not,
                    .data = .{
                        .rr = .{
                            .rs = operand_reg,
                            .rd = dst_reg,
                        },
                    },
                });

                break :result .{ .register = dst_reg };
            },
            .Int => return self.fail("TODO: airNot ints", .{}),
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airMinMax(
    self: *Self,
    inst: Air.Inst.Index,
    comptime tag: enum {
        max,
        min,
    },
) !void {
    const zcu = self.bin_file.comp.module.?;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);
        const rhs_ty = self.typeOf(bin_op.rhs);

        const int_info = lhs_ty.intInfo(zcu);

        if (int_info.bits > 64) return self.fail("TODO: > 64 bit @min", .{});

        const lhs_reg, const lhs_lock = blk: {
            if (lhs == .register) break :blk .{ lhs.register, null };

            const lhs_reg, const lhs_lock = try self.allocReg();
            try self.genSetReg(lhs_ty, lhs_reg, lhs);
            break :blk .{ lhs_reg, lhs_lock };
        };
        defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

        const rhs_reg, const rhs_lock = blk: {
            if (rhs == .register) break :blk .{ rhs.register, null };

            const rhs_reg, const rhs_lock = try self.allocReg();
            try self.genSetReg(rhs_ty, rhs_reg, rhs);
            break :blk .{ rhs_reg, rhs_lock };
        };
        defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

        const mask_reg, const mask_lock = try self.allocReg();
        defer self.register_manager.unlockReg(mask_lock);

        const result_reg, const result_lock = try self.allocReg();
        defer self.register_manager.unlockReg(result_lock);

        _ = try self.addInst(.{
            .tag = if (int_info.signedness == .unsigned) .sltu else .slt,
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = mask_reg,
                .rs1 = lhs_reg,
                .rs2 = rhs_reg,
            } },
        });

        _ = try self.addInst(.{
            .tag = .sub,
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = mask_reg,
                .rs1 = .zero,
                .rs2 = mask_reg,
            } },
        });

        _ = try self.addInst(.{
            .tag = .xor,
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = result_reg,
                .rs1 = lhs_reg,
                .rs2 = rhs_reg,
            } },
        });

        _ = try self.addInst(.{
            .tag = .@"and",
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = mask_reg,
                .rs1 = result_reg,
                .rs2 = mask_reg,
            } },
        });

        _ = try self.addInst(.{
            .tag = .xor,
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = result_reg,
                .rs1 = if (tag == .min) rhs_reg else lhs_reg,
                .rs2 = mask_reg,
            } },
        });

        break :result .{ .register = result_reg };
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement slice for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        break :result try self.binOp(tag, lhs, lhs_ty, rhs, rhs_ty);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

/// For all your binary operation needs, this function will generate
/// the corresponding Mir instruction(s). Returns the location of the
/// result.
///
/// If the binary operation itself happens to be an Air instruction,
/// pass the corresponding index in the inst parameter. That helps
/// this function do stuff like reusing operands.
///
/// This function does not do any lowering to Mir itself, but instead
/// looks at the lhs and rhs and determines which kind of lowering
/// would be best suitable and then delegates the lowering to other
/// functions.
///
/// `maybe_inst` **needs** to be a bin_op, make sure of that.
fn binOp(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs: MCValue,
    lhs_ty: Type,
    rhs: MCValue,
    rhs_ty: Type,
) InnerError!MCValue {
    const zcu = self.bin_file.comp.module.?;

    switch (tag) {
        // Arithmetic operations on integers and floats
        .add,
        .sub,
        .mul,
        .cmp_eq,
        .cmp_neq,
        .cmp_gt,
        .cmp_gte,
        .cmp_lt,
        .cmp_lte,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    assert(lhs_ty.eql(rhs_ty, zcu));
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        return self.binOpRegister(tag, lhs, lhs_ty, rhs, rhs_ty);
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => |x| return self.fail("TOOD: binOp {s}", .{@tagName(x)}),
            }
        },

        .ptr_add,
        .ptr_sub,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .Pointer => {
                    const ptr_ty = lhs_ty;
                    const elem_ty = switch (ptr_ty.ptrSize(zcu)) {
                        .One => ptr_ty.childType(zcu).childType(zcu), // ptr to array, so get array element type
                        else => ptr_ty.childType(zcu),
                    };
                    const elem_size = elem_ty.abiSize(zcu);

                    if (elem_size == 1) {
                        const base_tag: Air.Inst.Tag = switch (tag) {
                            .ptr_add => .add,
                            .ptr_sub => .sub,
                            else => unreachable,
                        };

                        return try self.binOpRegister(base_tag, lhs, lhs_ty, rhs, rhs_ty);
                    } else {
                        const offset = try self.binOp(
                            .mul,
                            rhs,
                            Type.usize,
                            .{ .immediate = elem_size },
                            Type.usize,
                        );

                        const addr = try self.binOp(
                            tag,
                            lhs,
                            Type.manyptr_u8,
                            offset,
                            Type.usize,
                        );
                        return addr;
                    }
                },
                else => unreachable,
            }
        },

        // These instructions have unsymteric bit sizes on RHS and LHS.
        .shr,
        .shl,
        => {
            switch (lhs_ty.zigTypeTag(zcu)) {
                .Float => return self.fail("TODO binary operations on floats", .{}),
                .Vector => return self.fail("TODO binary operations on vectors", .{}),
                .Int => {
                    const int_info = lhs_ty.intInfo(zcu);
                    if (int_info.bits <= 64) {
                        return self.binOpRegister(tag, lhs, lhs_ty, rhs, rhs_ty);
                    } else {
                        return self.fail("TODO binary operations on int with bits > 64", .{});
                    }
                },
                else => unreachable,
            }
        },
        else => return self.fail("TODO binOp {}", .{tag}),
    }
}
/// Don't call this function directly. Use binOp instead.
///
/// Calling this function signals an intention to generate a Mir
/// instruction of the form
///
///     op dest, lhs, rhs
///
/// Asserts that generating an instruction of that form is possible.
fn binOpRegister(
    self: *Self,
    tag: Air.Inst.Tag,
    lhs: MCValue,
    lhs_ty: Type,
    rhs: MCValue,
    rhs_ty: Type,
) !MCValue {
    const lhs_reg, const lhs_lock = blk: {
        if (lhs == .register) break :blk .{ lhs.register, null };

        const lhs_reg, const lhs_lock = try self.allocReg();
        try self.genSetReg(lhs_ty, lhs_reg, lhs);
        break :blk .{ lhs_reg, lhs_lock };
    };
    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);

    const rhs_reg, const rhs_lock = blk: {
        if (rhs == .register) break :blk .{ rhs.register, null };

        const rhs_reg, const rhs_lock = try self.allocReg();
        try self.genSetReg(rhs_ty, rhs_reg, rhs);
        break :blk .{ rhs_reg, rhs_lock };
    };
    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

    const dest_reg, const dest_lock = try self.allocReg();
    defer self.register_manager.unlockReg(dest_lock);

    const mir_tag: Mir.Inst.Tag = switch (tag) {
        .add => .add,
        .sub => .sub,
        .mul => .mul,

        .shl => .sllw,
        .shr => .srlw,

        .cmp_eq,
        .cmp_neq,
        .cmp_gt,
        .cmp_gte,
        .cmp_lt,
        .cmp_lte,
        => .pseudo,

        else => return self.fail("TODO: binOpRegister {s}", .{@tagName(tag)}),
    };

    switch (mir_tag) {
        .add,
        .sub,
        .mul,
        .sllw,
        .srlw,
        => {
            _ = try self.addInst(.{
                .tag = mir_tag,
                .ops = .rrr,
                .data = .{
                    .r_type = .{
                        .rd = dest_reg,
                        .rs1 = lhs_reg,
                        .rs2 = rhs_reg,
                    },
                },
            });
        },

        .pseudo => {
            const pseudo_op = switch (tag) {
                .cmp_eq,
                .cmp_neq,
                .cmp_gt,
                .cmp_gte,
                .cmp_lt,
                .cmp_lte,
                => .pseudo_compare,
                else => unreachable,
            };

            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = pseudo_op,
                .data = .{
                    .compare = .{
                        .rd = dest_reg,
                        .rs1 = lhs_reg,
                        .rs2 = rhs_reg,
                        .op = switch (tag) {
                            .cmp_eq => .eq,
                            .cmp_neq => .neq,
                            .cmp_gt => .gt,
                            .cmp_gte => .gte,
                            .cmp_lt => .lt,
                            .cmp_lte => .lte,
                            else => unreachable,
                        },
                    },
                },
            });
        },

        else => unreachable,
    }

    // generate the struct for OF checks

    return MCValue{ .register = dest_reg };
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const lhs = try self.resolveInst(bin_op.lhs);
    const rhs = try self.resolveInst(bin_op.rhs);
    const lhs_ty = self.typeOf(bin_op.lhs);
    const rhs_ty = self.typeOf(bin_op.rhs);

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        break :result try self.binOp(tag, lhs, lhs_ty, rhs, rhs_ty);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement addwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement add_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        // RISCV arthemtic instructions already wrap, so this is simply a sub binOp with
        // no overflow checks.
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);
        const rhs_ty = self.typeOf(bin_op.rhs);

        break :result try self.binOp(.sub, lhs, lhs_ty, rhs, rhs_ty);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement sub_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMul(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement mul for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulWrap(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement mulwrap for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement mul_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        const int_info = lhs_ty.intInfo(zcu);

        const tuple_ty = self.typeOfIndex(inst);
        const result_mcv = try self.allocRegOrMem(inst, false);
        const offset = result_mcv.load_frame;

        if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
            const add_result = try self.binOp(.add, lhs, lhs_ty, rhs, rhs_ty);
            const add_result_reg = try self.copyToTmpRegister(lhs_ty, add_result);
            const add_result_reg_lock = self.register_manager.lockRegAssumeUnused(add_result_reg);
            defer self.register_manager.unlockReg(add_result_reg_lock);

            const shift_amount: u6 = @intCast(Type.usize.bitSize(zcu) - int_info.bits);

            const shift_reg, const shift_lock = try self.allocReg();
            defer self.register_manager.unlockReg(shift_lock);

            _ = try self.addInst(.{
                .tag = .slli,
                .ops = .rri,
                .data = .{
                    .i_type = .{
                        .rd = shift_reg,
                        .rs1 = add_result_reg,
                        .imm12 = Immediate.s(shift_amount),
                    },
                },
            });

            _ = try self.addInst(.{
                .tag = if (int_info.signedness == .unsigned) .srli else .srai,
                .ops = .rri,
                .data = .{
                    .i_type = .{
                        .rd = shift_reg,
                        .rs1 = shift_reg,
                        .imm12 = Immediate.s(shift_amount),
                    },
                },
            });

            const add_result_frame: FrameAddr = .{
                .index = offset.index,
                .off = offset.off + @as(i32, @intCast(tuple_ty.structFieldOffset(0, zcu))),
            };
            try self.genSetStack(
                lhs_ty,
                add_result_frame,
                add_result,
            );

            const overflow_mcv = try self.binOp(
                .cmp_neq,
                .{ .register = shift_reg },
                lhs_ty,
                .{ .register = add_result_reg },
                lhs_ty,
            );

            const overflow_frame: FrameAddr = .{
                .index = offset.index,
                .off = offset.off + @as(i32, @intCast(tuple_ty.structFieldOffset(1, zcu))),
            };
            try self.genSetStack(
                Type.u1,
                overflow_frame,
                overflow_mcv,
            );

            break :result result_mcv;
        } else {
            return self.fail("TODO: less than 8 bit or non-pow 2 addition", .{});
        }
    };

    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airSubWithOverflow for {}", .{self.target.cpu.arch});
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    //const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const zcu = self.bin_file.comp.module.?;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const lhs = try self.resolveInst(extra.lhs);
        const rhs = try self.resolveInst(extra.rhs);
        const lhs_ty = self.typeOf(extra.lhs);
        const rhs_ty = self.typeOf(extra.rhs);

        switch (lhs_ty.zigTypeTag(zcu)) {
            else => |x| return self.fail("TODO: airMulWithOverflow {s}", .{@tagName(x)}),
            .Int => {
                assert(lhs_ty.eql(rhs_ty, zcu));
                const int_info = lhs_ty.intInfo(zcu);
                switch (int_info.bits) {
                    1...32 => {
                        if (self.hasFeature(.m)) {
                            const dest = try self.binOp(.mul, lhs, lhs_ty, rhs, rhs_ty);

                            const add_result_lock = self.register_manager.lockRegAssumeUnused(dest.register);
                            defer self.register_manager.unlockReg(add_result_lock);

                            const tuple_ty = self.typeOfIndex(inst);

                            // TODO: optimization, set this to true. needs the other struct access stuff to support
                            // accessing registers.
                            const result_mcv = try self.allocRegOrMem(inst, false);

                            const result_off: i32 = @intCast(tuple_ty.structFieldOffset(0, zcu));
                            const overflow_off: i32 = @intCast(tuple_ty.structFieldOffset(1, zcu));

                            try self.genSetStack(lhs_ty, result_mcv.offset(result_off).load_frame, dest);

                            if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                                if (int_info.signedness == .unsigned) {
                                    switch (int_info.bits) {
                                        1...8 => {
                                            const max_val = std.math.pow(u16, 2, int_info.bits) - 1;

                                            const overflow_reg, const overflow_lock = try self.allocReg();
                                            defer self.register_manager.unlockReg(overflow_lock);

                                            const add_reg, const add_lock = blk: {
                                                if (dest == .register) break :blk .{ dest.register, null };

                                                const add_reg, const add_lock = try self.allocReg();
                                                try self.genSetReg(lhs_ty, add_reg, dest);
                                                break :blk .{ add_reg, add_lock };
                                            };
                                            defer if (add_lock) |lock| self.register_manager.unlockReg(lock);

                                            _ = try self.addInst(.{
                                                .tag = .andi,
                                                .ops = .rri,
                                                .data = .{ .i_type = .{
                                                    .rd = overflow_reg,
                                                    .rs1 = add_reg,
                                                    .imm12 = Immediate.s(max_val),
                                                } },
                                            });

                                            const overflow_mcv = try self.binOp(
                                                .cmp_neq,
                                                .{ .register = overflow_reg },
                                                lhs_ty,
                                                .{ .register = add_reg },
                                                lhs_ty,
                                            );

                                            try self.genSetStack(
                                                lhs_ty,
                                                result_mcv.offset(overflow_off).load_frame,
                                                overflow_mcv,
                                            );

                                            break :result result_mcv;
                                        },

                                        else => return self.fail("TODO: airMulWithOverflow check for size {d}", .{int_info.bits}),
                                    }
                                } else {
                                    return self.fail("TODO: airMulWithOverflow calculate carry for signed addition", .{});
                                }
                            } else {
                                return self.fail("TODO: airMulWithOverflow with < 8 bits or non-pow of 2", .{});
                            }
                        } else {
                            return self.fail("TODO: emulate mul for targets without M feature", .{});
                        }
                    },
                    else => return self.fail("TODO: airMulWithOverflow larger than 32-bit mul", .{}),
                }
            },
        }
    };

    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airShlWithOverflow for {}", .{self.target.cpu.arch});
}

fn airDiv(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement div for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airRem(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement rem for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMod(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement zcu for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitAnd(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement bitwise and for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airBitOr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement bitwise or for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airXor(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement xor for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShl(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);
        const rhs_ty = self.typeOf(bin_op.rhs);

        break :result try self.binOp(.shl, lhs, lhs_ty, rhs, rhs_ty);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShr(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement shr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement .optional_payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement .optional_payload_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement .optional_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const zcu = self.bin_file.comp.module.?;
    const err_union_ty = self.typeOf(ty_op.operand);
    const err_ty = err_union_ty.errorUnionSet(zcu);
    const payload_ty = err_union_ty.errorUnionPayload(zcu);
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (err_ty.errorSetIsEmpty(zcu)) {
            break :result .{ .immediate = 0 };
        }

        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
            break :result operand;
        }

        const err_off: u32 = @intCast(errUnionErrorOffset(payload_ty, zcu));

        switch (operand) {
            .register => |reg| {
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                var result = try self.copyToNewRegister(inst, operand);

                if (err_off > 0) {
                    result = try self.binOp(
                        .shr,
                        result,
                        err_union_ty,
                        .{ .immediate = @as(u6, @intCast(err_off * 8)) },
                        Type.u8,
                    );
                }
                break :result result;
            },
            else => return self.fail("TODO implement unwrap_err_err for {}", .{operand}),
        }
    };

    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const operand_ty = self.typeOf(ty_op.operand);
    const operand = try self.resolveInst(ty_op.operand);
    const result = try self.genUnwrapErrUnionPayloadMir(operand_ty, operand);
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn genUnwrapErrUnionPayloadMir(
    self: *Self,
    err_union_ty: Type,
    err_union: MCValue,
) !MCValue {
    const zcu = self.bin_file.comp.module.?;
    const payload_ty = err_union_ty.errorUnionPayload(zcu);

    const result: MCValue = result: {
        if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const payload_off: u31 = @intCast(errUnionPayloadOffset(payload_ty, zcu));
        switch (err_union) {
            .load_frame => |frame_addr| break :result .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + payload_off,
            } },
            .register => |reg| {
                const eu_lock = self.register_manager.lockReg(reg);
                defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

                var result: MCValue = .{ .register = try self.copyToTmpRegister(err_union_ty, err_union) };

                if (payload_off > 0) {
                    result = try self.binOp(
                        .shr,
                        result,
                        err_union_ty,
                        .{ .immediate = @as(u6, @intCast(payload_off * 8)) },
                        Type.u8,
                    );
                }

                break :result result;
            },
            else => return self.fail("TODO implement genUnwrapErrUnionPayloadMir for {}", .{err_union}),
        }
    };

    return result;
}

// *(E!T) -> E
fn airUnwrapErrErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement unwrap error union error ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement unwrap error union payload ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrUnionPayloadPtrSet(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement .errunion_payload_ptr_set for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = if (self.liveness.isUnused(inst))
        .unreach
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
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const zcu = self.bin_file.comp.module.?;
        const optional_ty = self.typeOfIndex(inst);

        // Optional with a zero-bit payload type is just a boolean true
        if (optional_ty.abiSize(zcu) == 1)
            break :result MCValue{ .immediate = 1 };

        return self.fail("TODO implement wrap optional for {}", .{self.target.cpu.arch});
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// T to E!T
fn airWrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement wrap errunion payload for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;

    const eu_ty = ty_op.ty.toType();
    const pl_ty = eu_ty.errorUnionPayload(zcu);
    const err_ty = eu_ty.errorUnionSet(zcu);

    const result: MCValue = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result try self.resolveInst(ty_op.operand);

        const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(eu_ty, zcu));
        const pl_off: i32 = @intCast(errUnionPayloadOffset(pl_ty, zcu));
        const err_off: i32 = @intCast(errUnionErrorOffset(pl_ty, zcu));
        try self.genSetStack(pl_ty, .{ .index = frame_index, .off = pl_off }, .undef);
        const operand = try self.resolveInst(ty_op.operand);
        try self.genSetStack(err_ty, .{ .index = frame_index, .off = err_off }, operand);
        break :result .{ .load_frame = .{ .index = frame_index } };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]);
    const operand_ty = self.typeOf(pl_op.operand);
    const result = try self.genTry(inst, pl_op.operand, body, operand_ty, false);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn genTry(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    body: []const Air.Inst.Index,
    operand_ty: Type,
    operand_is_ptr: bool,
) !MCValue {
    _ = operand_is_ptr;

    const liveness_cond_br = self.liveness.getCondBr(inst);

    const operand_mcv = try self.resolveInst(operand);
    const is_err_mcv = try self.isErr(null, operand_ty, operand_mcv);

    // A branch to the false section. Uses beq. 1 is the default "true" state.
    const reloc = try self.condBr(Type.anyerror, is_err_mcv);

    if (self.liveness.operandDies(inst, 0)) {
        if (operand.toIndex()) |operand_inst| try self.processDeath(operand_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    for (liveness_cond_br.else_deaths) |death| try self.processDeath(death);
    try self.genBody(body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    self.performReloc(reloc);

    for (liveness_cond_br.then_deaths) |death| try self.processDeath(death);

    const result = if (self.liveness.isUnused(inst))
        .unreach
    else
        try self.genUnwrapErrUnionPayloadMir(operand_ty, operand_mcv);

    return result;
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        switch (src_mcv) {
            .load_frame => |frame_addr| {
                const len_mcv: MCValue = .{ .load_frame = .{
                    .index = frame_addr.index,
                    .off = frame_addr.off + 8,
                } };
                if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result len_mcv;

                const dst_mcv = try self.allocRegOrMem(inst, true);
                try self.genCopy(Type.usize, dst_mcv, len_mcv);
                break :result dst_mcv;
            },
            .register_pair => |pair| {
                const len_mcv: MCValue = .{ .register = pair[1] };

                if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result len_mcv;

                const dst_mcv = try self.allocRegOrMem(inst, true);
                try self.genCopy(Type.usize, dst_mcv, len_mcv);
                break :result dst_mcv;
            },
            else => return self.fail("TODO airSliceLen for {}", .{src_mcv}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement ptr_slice_len_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement ptr_slice_ptr_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;

    if (!is_volatile and self.liveness.isUnused(inst)) return self.finishAir(
        inst,
        .unreach,
        .{ bin_op.lhs, bin_op.rhs, .none },
    );
    const result: MCValue = result: {
        const slice_mcv = try self.resolveInst(bin_op.lhs);
        const index_mcv = try self.resolveInst(bin_op.rhs);

        const slice_ty = self.typeOf(bin_op.lhs);

        const slice_ptr_field_type = slice_ty.slicePtrFieldType(zcu);

        const index_lock: ?RegisterLock = if (index_mcv == .register)
            self.register_manager.lockRegAssumeUnused(index_mcv.register)
        else
            null;
        defer if (index_lock) |reg| self.register_manager.unlockReg(reg);

        const base_mcv: MCValue = switch (slice_mcv) {
            .load_frame,
            .load_symbol,
            => .{ .register = try self.copyToTmpRegister(slice_ptr_field_type, slice_mcv) },
            else => return self.fail("TODO slice_elem_val when slice is {}", .{slice_mcv}),
        };

        const dest = try self.allocRegOrMem(inst, true);
        const addr = try self.binOp(.ptr_add, base_mcv, slice_ptr_field_type, index_mcv, Type.usize);
        try self.load(dest, addr, slice_ptr_field_type);

        break :result dest;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement slice_elem_ptr for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const array_ty = self.typeOf(bin_op.lhs);
        const array_mcv = try self.resolveInst(bin_op.lhs);

        const index_mcv = try self.resolveInst(bin_op.rhs);
        const index_ty = self.typeOf(bin_op.rhs);

        const elem_ty = array_ty.childType(zcu);
        const elem_abi_size = elem_ty.abiSize(zcu);

        const addr_reg, const addr_reg_lock = try self.allocReg();
        defer self.register_manager.unlockReg(addr_reg_lock);

        switch (array_mcv) {
            .register => {
                const frame_index = try self.allocFrameIndex(FrameAlloc.initType(array_ty, zcu));
                try self.genSetStack(array_ty, .{ .index = frame_index }, array_mcv);
                try self.genSetReg(Type.usize, addr_reg, .{ .lea_frame = .{ .index = frame_index } });
            },
            .load_frame => |frame_addr| {
                try self.genSetReg(Type.usize, addr_reg, .{ .lea_frame = frame_addr });
            },
            else => try self.genSetReg(Type.usize, addr_reg, array_mcv.address()),
        }

        const offset_reg = try self.elemOffset(index_ty, index_mcv, elem_abi_size);
        const offset_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
        defer self.register_manager.unlockReg(offset_lock);

        const dst_mcv = try self.allocRegOrMem(inst, false);
        _ = try self.addInst(.{
            .tag = .add,
            .ops = .rrr,
            .data = .{ .r_type = .{
                .rd = addr_reg,
                .rs1 = offset_reg,
                .rs2 = addr_reg,
            } },
        });
        try self.genCopy(elem_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } });
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const is_volatile = false; // TODO
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const result: MCValue = if (!is_volatile and self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement ptr_elem_val for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement ptr_elem_ptr for {}", .{self.target.cpu.arch});
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
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airGetUnionTag for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airClz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airClz for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand = try self.resolveInst(ty_op.operand);
        const operand_ty = self.typeOf(ty_op.operand);

        const dest_reg = try self.register_manager.allocReg(inst, gp);

        const source_reg, const source_lock = blk: {
            if (operand == .register) break :blk .{ operand.register, null };

            const source_reg, const source_lock = try self.allocReg();
            try self.genSetReg(operand_ty, source_reg, operand);
            break :blk .{ source_reg, source_lock };
        };
        defer if (source_lock) |lock| self.register_manager.unlockReg(lock);

        // TODO: the B extension for RISCV should have the ctz instruction, and we should use it.

        try self.ctz(source_reg, dest_reg, operand_ty);

        break :result .{ .register = dest_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn ctz(self: *Self, src: Register, dst: Register, ty: Type) !void {
    const zcu = self.bin_file.comp.module.?;
    const length = (ty.abiSize(zcu) * 8) - 1;

    const count_reg, const count_lock = try self.allocReg();
    defer self.register_manager.unlockReg(count_lock);

    const len_reg, const len_lock = try self.allocReg();
    defer self.register_manager.unlockReg(len_lock);

    try self.genSetReg(Type.usize, count_reg, .{ .immediate = 0 });
    try self.genSetReg(Type.usize, len_reg, .{ .immediate = length });

    _ = src;
    _ = dst;

    return self.fail("TODO: finish ctz", .{});
}

fn airPopcount(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airPopcount for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airAbs(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const ty = self.typeOf(ty_op.operand);
        const scalar_ty = ty.scalarType(zcu);
        const operand = try self.resolveInst(ty_op.operand);

        switch (scalar_ty.zigTypeTag(zcu)) {
            .Int => if (ty.zigTypeTag(zcu) == .Vector) {
                return self.fail("TODO implement airAbs for {}", .{ty.fmt(zcu)});
            } else {
                const int_bits = ty.intInfo(zcu).bits;

                if (int_bits > 32) {
                    return self.fail("TODO: airAbs for larger than 32 bits", .{});
                }

                // promote the src into a register
                const src_mcv = try self.copyToNewRegister(inst, operand);
                // temp register for shift
                const temp_reg = try self.register_manager.allocReg(inst, gp);

                _ = try self.addInst(.{
                    .tag = .abs,
                    .ops = .rri,
                    .data = .{
                        .i_type = .{
                            .rs1 = src_mcv.register,
                            .rd = temp_reg,
                            .imm12 = Immediate.s(int_bits - 1),
                        },
                    },
                });

                break :result src_mcv;
            },
            else => return self.fail("TODO: implement airAbs {}", .{scalar_ty.fmt(zcu)}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airByteSwap(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const zcu = self.bin_file.comp.module.?;
        const ty = self.typeOf(ty_op.operand);
        const operand = try self.resolveInst(ty_op.operand);

        const int_bits = ty.intInfo(zcu).bits;

        // bytes are no-op
        if (int_bits == 8 and self.reuseOperand(inst, ty_op.operand, 0, operand)) {
            return self.finishAir(inst, operand, .{ ty_op.operand, .none, .none });
        }

        const dest_reg = try self.register_manager.allocReg(null, gp);
        try self.genSetReg(ty, dest_reg, operand);

        const dest_mcv: MCValue = .{ .register = dest_reg };

        switch (int_bits) {
            16 => {
                const temp = try self.binOp(.shr, dest_mcv, ty, .{ .immediate = 8 }, Type.u8);
                assert(temp == .register);
                _ = try self.addInst(.{
                    .tag = .slli,
                    .ops = .rri,
                    .data = .{ .i_type = .{
                        .imm12 = Immediate.s(8),
                        .rd = dest_reg,
                        .rs1 = dest_reg,
                    } },
                });
                _ = try self.addInst(.{
                    .tag = .@"or",
                    .ops = .rri,
                    .data = .{ .r_type = .{
                        .rd = dest_reg,
                        .rs1 = dest_reg,
                        .rs2 = temp.register,
                    } },
                });
            },
            else => return self.fail("TODO: {d} bits for airByteSwap", .{int_bits}),
        }

        break :result dest_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airBitReverse for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst))
        .unreach
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
    return self.reuseOperandAdvanced(inst, operand, op_index, mcv, inst);
}

fn reuseOperandAdvanced(
    self: *Self,
    inst: Air.Inst.Index,
    operand: Air.Inst.Ref,
    op_index: Liveness.OperandInt,
    mcv: MCValue,
    maybe_tracked_inst: ?Air.Inst.Index,
) bool {
    if (!self.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register,
        .register_pair,
        => for (mcv.getRegs()) |reg| {
            // If it's in the registers table, need to associate the register(s) with the
            // new instruction.
            if (maybe_tracked_inst) |tracked_inst| {
                if (!self.register_manager.isRegFree(reg)) {
                    if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
                        self.register_manager.registers[index] = tracked_inst;
                    }
                }
            } else self.register_manager.freeReg(reg);
        },
        .load_frame => |frame_addr| if (frame_addr.index.isNamed()) return false,
        else => return false,
    }

    // Prevent the operand deaths processing code from deallocating it.
    self.liveness.clearOperandDeath(inst, op_index);
    const op_inst = operand.toIndex().?;
    self.getResolvedInstValue(op_inst).reuse(self, maybe_tracked_inst, op_inst);

    return true;
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const elem_ty = self.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBits(zcu))
            break :result .none;

        const ptr = try self.resolveInst(ty_op.operand);
        const is_volatile = self.typeOf(ty_op.operand).isVolatilePtr(zcu);
        if (self.liveness.isUnused(inst) and !is_volatile)
            break :result .unreach;

        const dst_mcv: MCValue = blk: {
            if (self.reuseOperand(inst, ty_op.operand, 0, ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };

        try self.load(dst_mcv, ptr, self.typeOf(ty_op.operand));
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn load(self: *Self, dst_mcv: MCValue, ptr_mcv: MCValue, ptr_ty: Type) InnerError!void {
    const zcu = self.bin_file.comp.module.?;
    const dst_ty = ptr_ty.childType(zcu);

    log.debug("loading {}:{} into {}", .{ ptr_mcv, ptr_ty.fmt(zcu), dst_mcv });

    switch (ptr_mcv) {
        .none,
        .undef,
        .unreach,
        .dead,
        .register_pair,
        .reserved_frame,
        => unreachable, // not a valid pointer

        .immediate,
        .register,
        .register_offset,
        .lea_frame,
        .lea_symbol,
        => try self.genCopy(dst_ty, dst_mcv, ptr_mcv.deref()),

        .memory,
        .indirect,
        .load_symbol,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(dst_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } });
        },
        .air_ref => |ptr_ref| try self.load(dst_mcv, try self.resolveInst(ptr_ref), ptr_ty),
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

    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

/// Loads `value` into the "payload" of `pointer`.
fn store(self: *Self, ptr_mcv: MCValue, src_mcv: MCValue, ptr_ty: Type, src_ty: Type) !void {
    const zcu = self.bin_file.comp.module.?;

    log.debug("storing {}:{} in {}:{}", .{ src_mcv, src_ty.fmt(zcu), ptr_mcv, ptr_ty.fmt(zcu) });

    switch (ptr_mcv) {
        .none => unreachable,
        .undef => unreachable,
        .unreach => unreachable,
        .dead => unreachable,
        .register_pair => unreachable,
        .reserved_frame => unreachable,

        .immediate,
        .register,
        .register_offset,
        .lea_symbol,
        .lea_frame,
        => try self.genCopy(src_ty, ptr_mcv.deref(), src_mcv),

        .memory,
        .indirect,
        .load_symbol,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(src_ty, .{ .indirect = .{ .reg = addr_reg } }, src_mcv);
        },
        .air_ref => |ptr_ref| try self.store(try self.resolveInst(ptr_ref), src_mcv, ptr_ty, src_ty),
    }
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
    const zcu = self.bin_file.comp.module.?;
    const ptr_field_ty = self.typeOfIndex(inst);
    const ptr_container_ty = self.typeOf(operand);
    const ptr_container_ty_info = ptr_container_ty.ptrInfo(zcu);
    const container_ty = ptr_container_ty.childType(zcu);

    const field_offset: i32 = if (zcu.typeToPackedStruct(container_ty)) |struct_obj|
        if (ptr_field_ty.ptrInfo(zcu).packed_offset.host_size == 0)
            @divExact(zcu.structPackedFieldBitOffset(struct_obj, index) +
                ptr_container_ty_info.packed_offset.bit_offset, 8)
        else
            0
    else
        @intCast(container_ty.structFieldOffset(index, zcu));

    const src_mcv = try self.resolveInst(operand);
    const dst_mcv = if (switch (src_mcv) {
        .immediate, .lea_frame => true,
        .register, .register_offset => self.reuseOperand(inst, operand, 0, src_mcv),
        else => false,
    }) src_mcv else try self.copyToNewRegister(inst, src_mcv);
    return dst_mcv.offset(field_offset);
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;

    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const operand = extra.struct_operand;
    const index = extra.field_index;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const zcu = self.bin_file.comp.module.?;
        const src_mcv = try self.resolveInst(operand);
        const struct_ty = self.typeOf(operand);
        const field_ty = struct_ty.structFieldType(index, zcu);
        if (!field_ty.hasRuntimeBitsIgnoreComptime(zcu)) break :result .none;

        const field_off: u32 = switch (struct_ty.containerLayout(zcu)) {
            .auto, .@"extern" => @intCast(struct_ty.structFieldOffset(index, zcu) * 8),
            .@"packed" => if (zcu.typeToStruct(struct_ty)) |struct_type|
                zcu.structPackedFieldBitOffset(struct_type, index)
            else
                0,
        };

        switch (src_mcv) {
            .dead, .unreach => unreachable,
            .register => |src_reg| {
                const src_reg_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_reg_lock);

                const dst_reg = if (field_off == 0)
                    (try self.copyToNewRegister(inst, src_mcv)).register
                else
                    try self.copyToTmpRegister(Type.usize, .{ .register = src_reg });

                const dst_mcv: MCValue = .{ .register = dst_reg };
                const dst_lock = self.register_manager.lockReg(dst_reg);
                defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

                if (field_off > 0) {
                    _ = try self.addInst(.{
                        .tag = .srli,
                        .ops = .rri,
                        .data = .{ .i_type = .{
                            .imm12 = Immediate.s(@intCast(field_off)),
                            .rd = dst_reg,
                            .rs1 = dst_reg,
                        } },
                    });

                    return self.fail("TODO: airStructFieldVal register with field_off > 0", .{});
                }

                break :result if (field_off == 0) dst_mcv else try self.copyToNewRegister(inst, dst_mcv);
            },
            .load_frame => {
                const field_abi_size: u32 = @intCast(field_ty.abiSize(mod));
                if (field_off % 8 == 0) {
                    const field_byte_off = @divExact(field_off, 8);
                    const off_mcv = src_mcv.address().offset(@intCast(field_byte_off)).deref();
                    const field_bit_size = field_ty.bitSize(mod);

                    if (field_abi_size <= 8) {
                        const int_ty = try mod.intType(
                            if (field_ty.isAbiInt(mod)) field_ty.intInfo(mod).signedness else .unsigned,
                            @intCast(field_bit_size),
                        );

                        const dst_reg, const dst_lock = try self.allocReg();
                        const dst_mcv = MCValue{ .register = dst_reg };
                        defer self.register_manager.unlockReg(dst_lock);

                        try self.genCopy(int_ty, dst_mcv, off_mcv);
                        break :result try self.copyToNewRegister(inst, dst_mcv);
                    }

                    const container_abi_size: u32 = @intCast(struct_ty.abiSize(mod));
                    const dst_mcv = if (field_byte_off + field_abi_size <= container_abi_size and
                        self.reuseOperand(inst, operand, 0, src_mcv))
                        off_mcv
                    else dst: {
                        const dst_mcv = try self.allocRegOrMem(inst, true);
                        try self.genCopy(field_ty, dst_mcv, off_mcv);
                        break :dst dst_mcv;
                    };
                    if (field_abi_size * 8 > field_bit_size and dst_mcv.isMemory()) {
                        const tmp_reg, const tmp_lock = try self.allocReg();
                        defer self.register_manager.unlockReg(tmp_lock);

                        const hi_mcv =
                            dst_mcv.address().offset(@intCast(field_bit_size / 64 * 8)).deref();
                        try self.genSetReg(Type.usize, tmp_reg, hi_mcv);
                        try self.genCopy(Type.usize, hi_mcv, .{ .register = tmp_reg });
                    }
                    break :result dst_mcv;
                }

                return self.fail("TODO: airStructFieldVal load_frame field_off non multiple of 8", .{});
            },
            else => return self.fail("TODO: airStructField {s}", .{@tagName(src_mcv)}),
        }
    };

    return self.finishAir(inst, result, .{ extra.struct_operand, .none, .none });
}

fn airFieldParentPtr(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement codegen airFieldParentPtr", .{});
}

fn genArgDbgInfo(self: Self, inst: Air.Inst.Index, mcv: MCValue) !void {
    const zcu = self.bin_file.comp.module.?;
    const arg = self.air.instructions.items(.data)[@intFromEnum(inst)].arg;
    const ty = arg.ty.toType();
    const owner_decl = zcu.funcOwnerDeclIndex(self.func_index);
    const name = zcu.getParamName(self.func_index, arg.src_index);

    switch (self.debug_output) {
        .dwarf => |dw| switch (mcv) {
            .register => |reg| try dw.genArgDbgInfo(name, ty, owner_decl, .{
                .register = reg.dwarfLocOp(),
            }),
            .load_frame => {},
            else => {},
        },
        .plan9 => {},
        .none => {},
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    var arg_index = self.arg_index;

    // we skip over args that have no bits
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const src_mcv = self.args[arg_index];

        const arg_ty = self.typeOfIndex(inst);

        const dst_mcv = switch (src_mcv) {
            .register => dst: {
                const frame = try self.allocFrameIndex(FrameAlloc.init(.{
                    .size = Type.usize.abiSize(zcu),
                    .alignment = Type.usize.abiAlignment(zcu),
                }));
                const dst_mcv: MCValue = .{ .load_frame = .{ .index = frame } };
                try self.genCopy(Type.usize, dst_mcv, src_mcv);
                break :dst dst_mcv;
            },
            .register_pair => dst: {
                const frame = try self.allocFrameIndex(FrameAlloc.init(.{
                    .size = Type.usize.abiSize(zcu) * 2,
                    .alignment = Type.usize.abiAlignment(zcu),
                }));
                const dst_mcv: MCValue = .{ .load_frame = .{ .index = frame } };
                try self.genCopy(arg_ty, dst_mcv, src_mcv);
                break :dst dst_mcv;
            },
            .load_frame => src_mcv,
            else => return self.fail("TODO: airArg {s}", .{@tagName(src_mcv)}),
        };

        try self.genArgDbgInfo(inst, src_mcv);
        break :result dst_mcv;
    };

    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airTrap(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .unimp,
        .ops = .none,
        .data = undefined,
    });
    return self.finishAirBookkeeping();
}

fn airBreakpoint(self: *Self) !void {
    _ = try self.addInst(.{
        .tag = .ebreak,
        .ops = .none,
        .data = undefined,
    });
    return self.finishAirBookkeeping();
}

fn airRetAddr(self: *Self, inst: Air.Inst.Index) !void {
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .load_frame = .{ .index = .ret_addr } });
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .lea_frame = .{ .index = .base_ptr } });
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airFence(self: *Self) !void {
    return self.fail("TODO implement fence() for {}", .{self.target.cpu.arch});
    //return self.finishAirBookkeeping();
}

fn airCall(self: *Self, inst: Air.Inst.Index, modifier: std.builtin.CallModifier) !void {
    if (modifier == .always_tail) return self.fail("TODO implement tail calls for riscv64", .{});
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const callee = pl_op.operand;
    const extra = self.air.extraData(Air.Call, pl_op.payload);
    const arg_refs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra.end..][0..extra.data.args_len]);

    const expected_num_args = 8;
    const ExpectedContents = extern struct {
        vals: [expected_num_args][@sizeOf(MCValue)]u8 align(@alignOf(MCValue)),
    };
    var stack align(@max(@alignOf(ExpectedContents), @alignOf(std.heap.StackFallbackAllocator(0)))) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), self.gpa);
    const allocator = stack.get();

    const arg_tys = try allocator.alloc(Type, arg_refs.len);
    defer allocator.free(arg_tys);
    for (arg_tys, arg_refs) |*arg_ty, arg_ref| arg_ty.* = self.typeOf(arg_ref);

    const arg_vals = try allocator.alloc(MCValue, arg_refs.len);
    defer allocator.free(arg_vals);
    for (arg_vals, arg_refs) |*arg_val, arg_ref| arg_val.* = .{ .air_ref = arg_ref };

    const call_ret = try self.genCall(.{ .air = callee }, arg_tys, arg_vals);

    var bt = self.liveness.iterateBigTomb(inst);
    try self.feed(&bt, pl_op.operand);
    for (arg_refs) |arg_ref| try self.feed(&bt, arg_ref);

    const result = if (self.liveness.isUnused(inst)) .unreach else call_ret;
    return self.finishAirResult(inst, result);
}

fn genCall(
    self: *Self,
    info: union(enum) {
        air: Air.Inst.Ref,
        lib: struct {
            return_type: InternPool.Index,
            param_types: []const InternPool.Index,
            lib: ?[]const u8 = null,
            callee: []const u8,
        },
    },
    arg_tys: []const Type,
    args: []const MCValue,
) !MCValue {
    const zcu = self.bin_file.comp.module.?;

    const fn_ty = switch (info) {
        .air => |callee| fn_info: {
            const callee_ty = self.typeOf(callee);
            break :fn_info switch (callee_ty.zigTypeTag(zcu)) {
                .Fn => callee_ty,
                .Pointer => callee_ty.childType(zcu),
                else => unreachable,
            };
        },
        .lib => |lib| try zcu.funcType(.{
            .param_types = lib.param_types,
            .return_type = lib.return_type,
            .cc = .C,
        }),
    };

    const fn_info = zcu.typeToFunc(fn_ty).?;
    var call_info = try self.resolveCallingConventionValues(fn_info);
    defer call_info.deinit(self);

    // We need a properly aligned and sized call frame to be able to call this function.
    {
        const needed_call_frame = FrameAlloc.init(.{
            .size = call_info.stack_byte_count,
            .alignment = call_info.stack_align,
        });
        const frame_allocs_slice = self.frame_allocs.slice();
        const stack_frame_size =
            &frame_allocs_slice.items(.abi_size)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_size.* = @max(stack_frame_size.*, needed_call_frame.abi_size);
        const stack_frame_align =
            &frame_allocs_slice.items(.abi_align)[@intFromEnum(FrameIndex.call_frame)];
        stack_frame_align.* = stack_frame_align.max(needed_call_frame.abi_align);
    }

    for (call_info.args, 0..) |mc_arg, arg_i| try self.genCopy(arg_tys[arg_i], mc_arg, args[arg_i]);

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    switch (info) {
        .air => |callee| {
            if (try self.air.value(callee, zcu)) |func_value| {
                const func_key = zcu.intern_pool.indexToKey(func_value.ip_index);
                switch (switch (func_key) {
                    else => func_key,
                    .ptr => |ptr| if (ptr.byte_offset == 0) switch (ptr.base_addr) {
                        .decl => |decl| zcu.intern_pool.indexToKey(zcu.declPtr(decl).val.toIntern()),
                        else => func_key,
                    } else func_key,
                }) {
                    .func => |func| {
                        if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                            const sym_index = try elf_file.zigObjectPtr().?.getOrCreateMetadataForDecl(elf_file, func.owner_decl);
                            const sym = elf_file.symbol(sym_index);

                            _ = try sym.getOrCreateZigGotEntry(sym_index, elf_file);
                            const got_addr = sym.zigGotAddress(elf_file);
                            try self.genSetReg(Type.usize, .ra, .{ .memory = @intCast(got_addr) });

                            _ = try self.addInst(.{
                                .tag = .jalr,
                                .ops = .rri,
                                .data = .{ .i_type = .{
                                    .rd = .ra,
                                    .rs1 = .ra,
                                    .imm12 = Immediate.s(0),
                                } },
                            });
                        } else unreachable;
                    },
                    .extern_func => return self.fail("TODO: extern func calls", .{}),
                    else => return self.fail("TODO implement calling bitcasted functions", .{}),
                }
            } else {
                assert(self.typeOf(callee).zigTypeTag(zcu) == .Pointer);
                const addr_reg, const addr_lock = try self.allocReg();
                defer self.register_manager.unlockReg(addr_lock);
                try self.genSetReg(Type.usize, addr_reg, .{ .air_ref = callee });
                _ = try self.addInst(.{
                    .tag = .jalr,
                    .ops = .rri,
                    .data = .{ .i_type = .{
                        .rd = .ra,
                        .rs1 = addr_reg,
                        .imm12 = Immediate.s(0),
                    } },
                });
            }
        },
        .lib => return self.fail("TODO: lib func calls", .{}),
    }

    return call_info.return_value.short;
}

fn airRet(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    const zcu = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    if (safety) {
        // safe
    } else {
        // not safe
    }

    const ret_ty = self.fn_type.fnReturnType(zcu);
    switch (self.ret_mcv.short) {
        .none => {},
        .register,
        .register_pair,
        => try self.genCopy(ret_ty, self.ret_mcv.short, .{ .air_ref = un_op }),
        .indirect => |reg_off| {
            try self.register_manager.getReg(reg_off.reg, null);
            const lock = self.register_manager.lockRegAssumeUnused(reg_off.reg);
            defer self.register_manager.unlockReg(lock);

            try self.genSetReg(Type.usize, reg_off.reg, self.ret_mcv.long);
            try self.genCopy(
                ret_ty,
                .{ .register_offset = reg_off },
                .{ .air_ref = un_op },
            );
        },
        else => unreachable,
    }

    self.ret_mcv.liveOut(self, inst);
    try self.finishAir(inst, .unreach, .{ un_op, .none, .none });

    // Just add space for an instruction, reloced this later
    const index = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_j,
        .data = .{ .inst = undefined },
    });

    try self.exitlude_jump_relocs.append(self.gpa, index);
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const ptr = try self.resolveInst(un_op);

    const ptr_ty = self.typeOf(un_op);
    switch (self.ret_mcv.short) {
        .none => {},
        .register, .register_pair => try self.load(self.ret_mcv.short, ptr, ptr_ty),
        .indirect => |reg_off| try self.genSetReg(ptr_ty, reg_off.reg, ptr),
        else => unreachable,
    }
    self.ret_mcv.liveOut(self, inst);
    try self.finishAir(inst, .unreach, .{ un_op, .none, .none });

    // Just add space for an instruction, reloced this later
    const index = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_j,
        .data = .{ .inst = undefined },
    });

    try self.exitlude_jump_relocs.append(self.gpa, index);
}

fn airCmp(self: *Self, inst: Air.Inst.Index) !void {
    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const zcu = self.bin_file.comp.module.?;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        const lhs_ty = self.typeOf(bin_op.lhs);

        const int_ty = switch (lhs_ty.zigTypeTag(zcu)) {
            .Vector => unreachable, // Handled by cmp_vector.
            .Enum => lhs_ty.intTagType(zcu),
            .Int => lhs_ty,
            .Bool => Type.u1,
            .Pointer => Type.usize,
            .ErrorSet => Type.u16,
            .Optional => blk: {
                const payload_ty = lhs_ty.optionalChild(zcu);
                if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                    break :blk Type.u1;
                } else if (lhs_ty.isPtrLikeOptional(zcu)) {
                    break :blk Type.usize;
                } else {
                    return self.fail("TODO riscv cmp non-pointer optionals", .{});
                }
            },
            .Float => return self.fail("TODO riscv cmp floats", .{}),
            else => unreachable,
        };

        const int_info = int_ty.intInfo(zcu);
        if (int_info.bits <= 64) {
            break :result try self.binOp(tag, lhs, int_ty, rhs, int_ty);
        } else {
            return self.fail("TODO riscv cmp for ints > 64 bits", .{});
        }
    };

    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airCmpVector(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airCmpVector for {}", .{self.target.cpu.arch});
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    _ = operand;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airCmpLtErrorsLen for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[@intFromEnum(inst)].dbg_stmt;

    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_dbg_line_column,
        .data = .{ .pseudo_dbg_line_column = .{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        } },
    });

    return self.finishAirBookkeeping();
}

fn airDbgInlineBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.DbgInlineBlock, ty_pl.payload);
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const operand = pl_op.operand;
    const ty = self.typeOf(operand);
    const mcv = try self.resolveInst(operand);

    const name = self.air.nullTerminatedString(pl_op.payload);

    const tag = self.air.instructions.items(.tag)[@intFromEnum(inst)];
    try self.genVarDbgInfo(tag, ty, mcv, name);

    return self.finishAir(inst, .unreach, .{ operand, .none, .none });
}

fn genVarDbgInfo(
    self: Self,
    tag: Air.Inst.Tag,
    ty: Type,
    mcv: MCValue,
    name: [:0]const u8,
) !void {
    const zcu = self.bin_file.comp.module.?;
    const is_ptr = switch (tag) {
        .dbg_var_ptr => true,
        .dbg_var_val => false,
        else => unreachable,
    };

    switch (self.debug_output) {
        .dwarf => |dw| {
            const loc: link.File.Dwarf.DeclState.DbgInfoLoc = switch (mcv) {
                .register => |reg| .{ .register = reg.dwarfLocOp() },
                .memory => |address| .{ .memory = address },
                .load_symbol => |sym_off| loc: {
                    assert(sym_off.off == 0);
                    break :loc .{ .linker_load = .{ .type = .direct, .sym_index = sym_off.sym } };
                },
                .immediate => |x| .{ .immediate = x },
                .undef => .undef,
                .none => .none,
                else => blk: {
                    // log.warn("TODO generate debug info for {}", .{mcv});
                    break :blk .nop;
                },
            };
            try dw.genVarDbgInfo(name, ty, zcu.funcOwnerDeclIndex(self.func_index), is_ptr, loc);
        },
        .plan9 => {},
        .none => {},
    }
}

fn airCondBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const cond = try self.resolveInst(pl_op.operand);
    const cond_ty = self.typeOf(pl_op.operand);
    const extra = self.air.extraData(Air.CondBr, pl_op.payload);
    const then_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end..][0..extra.data.then_body_len]);
    const else_body: []const Air.Inst.Index = @ptrCast(self.air.extra[extra.end + then_body.len ..][0..extra.data.else_body_len]);
    const liveness_cond_br = self.liveness.getCondBr(inst);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (pl_op.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();
    const reloc = try self.condBr(cond_ty, cond);

    for (liveness_cond_br.then_deaths) |death| try self.processDeath(death);
    try self.genBody(then_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    self.performReloc(reloc);

    for (liveness_cond_br.else_deaths) |death| try self.processDeath(death);
    try self.genBody(else_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    // We already took care of pl_op.operand earlier, so there's nothing left to do.
    self.finishAirBookkeeping();
}

fn condBr(self: *Self, cond_ty: Type, condition: MCValue) !Mir.Inst.Index {
    const cond_reg = try self.copyToTmpRegister(cond_ty, condition);

    return try self.addInst(.{
        .tag = .beq,
        .ops = .rr_inst,
        .data = .{
            .b_type = .{
                .rs1 = cond_reg,
                .rs2 = .zero,
                .inst = undefined,
            },
        },
    });
}

fn airIsNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn isNull(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNonNull and invert the result.
    return self.fail("TODO call isNonNull and invert the result", .{});
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand = try self.resolveInst(un_op);
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn isNonNull(self: *Self, operand: MCValue) !MCValue {
    _ = operand;
    // Here you can specialize this instruction if it makes sense to, otherwise the default
    // will call isNull and invert the result.
    return self.fail("TODO call isNull and invert the result", .{});
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isNonNull(operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand = try self.resolveInst(un_op);
        const operand_ty = self.typeOf(un_op);
        break :result try self.isErr(inst, operand_ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        try self.load(operand, operand_ptr, self.typeOf(un_op));
        const operand_ptr_ty = self.typeOf(un_op);
        const operand_ty = operand_ptr_ty.childType(zcu);

        break :result try self.isErr(inst, operand_ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

/// Generates a compare instruction which will indicate if `eu_mcv` is an error.
///
/// Result is in the return register.
fn isErr(self: *Self, maybe_inst: ?Air.Inst.Index, eu_ty: Type, eu_mcv: MCValue) !MCValue {
    const zcu = self.bin_file.comp.module.?;
    const err_ty = eu_ty.errorUnionSet(zcu);
    if (err_ty.errorSetIsEmpty(zcu)) return MCValue{ .immediate = 0 }; // always false

    _ = maybe_inst;

    const err_off = errUnionErrorOffset(eu_ty.errorUnionPayload(zcu), zcu);

    switch (eu_mcv) {
        .register => |reg| {
            const eu_lock = self.register_manager.lockReg(reg);
            defer if (eu_lock) |lock| self.register_manager.unlockReg(lock);

            const return_reg = try self.copyToTmpRegister(eu_ty, eu_mcv);
            const return_lock = self.register_manager.lockRegAssumeUnused(return_reg);
            defer self.register_manager.unlockReg(return_lock);

            var return_mcv: MCValue = .{ .register = return_reg };

            if (err_off > 0) {
                return_mcv = try self.binOp(
                    .shr,
                    return_mcv,
                    eu_ty,
                    .{ .immediate = @as(u6, @intCast(err_off * 8)) },
                    Type.u8,
                );
            }

            return_mcv = try self.binOp(
                .cmp_neq,
                return_mcv,
                Type.u16,
                .{ .immediate = 0 },
                Type.u16,
            );

            return return_mcv;
        },
        else => return self.fail("TODO implement isErr for {}", .{eu_mcv}),
    }
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand = try self.resolveInst(un_op);
        const ty = self.typeOf(un_op);
        break :result try self.isNonErr(inst, ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn isNonErr(self: *Self, inst: Air.Inst.Index, eu_ty: Type, eu_mcv: MCValue) !MCValue {
    const is_err_res = try self.isErr(inst, eu_ty, eu_mcv);
    switch (is_err_res) {
        .register => |reg| {
            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_not,
                .data = .{
                    .rr = .{
                        .rd = reg,
                        .rs = reg,
                    },
                },
            });
            return is_err_res;
        },
        // always false case
        .immediate => |imm| {
            assert(imm == 0);
            return MCValue{ .immediate = @intFromBool(imm == 0) };
        },
        else => unreachable,
    }
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const operand_ptr = try self.resolveInst(un_op);
        const operand: MCValue = blk: {
            if (self.reuseOperand(inst, un_op, 0, operand_ptr)) {
                // The MCValue that holds the pointer can be re-used as the value.
                break :blk operand_ptr;
            } else {
                break :blk try self.allocRegOrMem(inst, true);
            }
        };
        const operand_ptr_ty = self.typeOf(un_op);
        const operand_ty = operand_ptr_ty.childType(zcu);

        try self.load(operand, operand_ptr, self.typeOf(un_op));
        break :result try self.isNonErr(inst, operand_ty, operand);
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body: []const Air.Inst.Index = @ptrCast(self.air.extra[loop.end..][0..loop.data.body_len]);

    self.scope_generation += 1;
    const state = try self.saveState();

    const jmp_target: Mir.Inst.Index = @intCast(self.mir_instructions.len);
    try self.genBody(body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = true,
    });
    _ = try self.jump(jmp_target);

    self.finishAirBookkeeping();
}

/// Send control flow to the `index` of `self.code`.
fn jump(self: *Self, index: Mir.Inst.Index) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_j,
        .data = .{
            .inst = index,
        },
    });
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    try self.lowerBlock(inst, @ptrCast(self.air.extra[extra.end..][0..extra.data.body_len]));
}

fn lowerBlock(self: *Self, inst: Air.Inst.Index, body: []const Air.Inst.Index) !void {
    // A block is a setup to be able to jump to the end.
    const inst_tracking_i = self.inst_tracking.count();
    self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(.unreach));

    self.scope_generation += 1;
    try self.blocks.putNoClobber(self.gpa, inst, .{ .state = self.initRetroactiveState() });
    const liveness = self.liveness.getBlock(inst);

    // TODO emit debug info lexical block
    try self.genBody(body);

    var block_data = self.blocks.fetchRemove(inst).?;
    defer block_data.value.deinit(self.gpa);
    if (block_data.value.relocs.items.len > 0) {
        try self.restoreState(block_data.value.state, liveness.deaths, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });
        for (block_data.value.relocs.items) |reloc| self.performReloc(reloc);
    }

    if (std.debug.runtime_safety) assert(self.inst_tracking.getIndex(inst).? == inst_tracking_i);
    const tracking = &self.inst_tracking.values()[inst_tracking_i];
    if (self.liveness.isUnused(inst)) try tracking.die(self, inst);
    self.getValueIfFree(tracking.short, inst);
    self.finishAirBookkeeping();
}

fn airSwitch(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const condition = pl_op.operand;
    _ = condition;
    return self.fail("TODO airSwitch for {}", .{self.target.cpu.arch});
    // return self.finishAir(inst, .dead, .{ condition, .none, .none });
}

fn performReloc(self: *Self, inst: Mir.Inst.Index) void {
    const tag = self.mir_instructions.items(.tag)[inst];
    const ops = self.mir_instructions.items(.ops)[inst];
    const target: Mir.Inst.Index = @intCast(self.mir_instructions.len);

    switch (tag) {
        .bne,
        .beq,
        => self.mir_instructions.items(.data)[inst].b_type.inst = target,
        .jal => self.mir_instructions.items(.data)[inst].j_type.inst = target,
        .pseudo => switch (ops) {
            .pseudo_j => self.mir_instructions.items(.data)[inst].inst = target,
            else => std.debug.panic("TODO: performReloc {s}", .{@tagName(ops)}),
        },
        else => std.debug.panic("TODO: performReloc {s}", .{@tagName(tag)}),
    }
}

fn airBr(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.comp.module.?;
    const br = self.air.instructions.items(.data)[@intFromEnum(inst)].br;

    const block_ty = self.typeOfIndex(br.block_inst);
    const block_unused =
        !block_ty.hasRuntimeBitsIgnoreComptime(mod) or self.liveness.isUnused(br.block_inst);
    const block_tracking = self.inst_tracking.getPtr(br.block_inst).?;
    const block_data = self.blocks.getPtr(br.block_inst).?;
    const first_br = block_data.relocs.items.len == 0;
    const block_result = result: {
        if (block_unused) break :result .none;

        if (!first_br) try self.getValue(block_tracking.short, null);
        const src_mcv = try self.resolveInst(br.operand);

        if (self.reuseOperandAdvanced(inst, br.operand, 0, src_mcv, br.block_inst)) {
            if (first_br) break :result src_mcv;

            try self.getValue(block_tracking.short, br.block_inst);
            // .long = .none to avoid merging operand and block result stack frames.
            const current_tracking: InstTracking = .{ .long = .none, .short = src_mcv };
            try current_tracking.materializeUnsafe(self, br.block_inst, block_tracking.*);
            for (current_tracking.getRegs()) |src_reg| self.register_manager.freeReg(src_reg);
            break :result block_tracking.short;
        }

        const dst_mcv = if (first_br) try self.allocRegOrMem(br.block_inst, true) else dst: {
            try self.getValue(block_tracking.short, br.block_inst);
            break :dst block_tracking.short;
        };
        try self.genCopy(block_ty, dst_mcv, try self.resolveInst(br.operand));
        break :result dst_mcv;
    };

    // Process operand death so that it is properly accounted for in the State below.
    if (self.liveness.operandDies(inst, 0)) {
        if (br.operand.toIndex()) |op_inst| try self.processDeath(op_inst);
    }

    if (first_br) {
        block_tracking.* = InstTracking.init(block_result);
        try self.saveRetroactiveState(&block_data.state);
    } else try self.restoreState(block_data.state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = false,
    });

    // Emit a jump with a relocation. It will be patched up after the block ends.
    // Leave the jump offset undefined
    const jmp_reloc = try self.jump(undefined);
    try block_data.relocs.append(self.gpa, jmp_reloc);

    // Stop tracking block result without forgetting tracking info
    try self.freeValue(block_tracking.short);

    self.finishAirBookkeeping();
}

fn airBoolOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[@intFromEnum(inst)].bin_op;
    const air_tags = self.air.instructions.items(.tag);
    _ = air_tags;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement boolean operations for {}", .{self.target.cpu.arch});
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
    const clobbers_len: u31 = @truncate(extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs: []const Air.Inst.Ref =
        @ptrCast(self.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs: []const Air.Inst.Ref = @ptrCast(self.air.extra[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;

    log.debug("airAsm input: {any}", .{inputs});

    const dead = !is_volatile and self.liveness.isUnused(inst);
    const result: MCValue = if (dead) .unreach else result: {
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

                if (std.mem.eql(u8, clobber, "") or std.mem.eql(u8, clobber, "memory")) {
                    // nothing really to do
                } else {
                    try self.register_manager.getReg(parseRegName(clobber) orelse
                        return self.fail("invalid clobber: '{s}'", .{clobber}), null);
                }
            }
        }

        const asm_source = std.mem.sliceAsBytes(self.air.extra[extra_i..])[0..extra.data.source_len];

        if (std.meta.stringToEnum(Mir.Inst.Tag, asm_source)) |tag| {
            _ = try self.addInst(.{
                .tag = tag,
                .ops = .none,
                .data = undefined,
            });
        } else {
            return self.fail("TODO: asm_source {s}", .{asm_source});
        }

        if (output_constraint) |output| {
            if (output.len < 4 or output[0] != '=' or output[1] != '{' or output[output.len - 1] != '}') {
                return self.fail("unrecognized asm output constraint: '{s}'", .{output});
            }
            const reg_name = output[2 .. output.len - 1];
            const reg = parseRegName(reg_name) orelse
                return self.fail("unrecognized register: '{s}'", .{reg_name});
            break :result .{ .register = reg };
        } else {
            break :result .{ .none = {} };
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
    var bt = self.liveness.iterateBigTomb(inst);
    for (outputs) |output| if (output != .none) try self.feed(&bt, output);
    for (inputs) |input| try self.feed(&bt, input);
    return self.finishAirResult(inst, result);
}

/// Sets the value without any modifications to register allocation metadata or stack allocation metadata.
fn genCopy(self: *Self, ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const zcu = self.bin_file.comp.module.?;

    // There isn't anything to store
    if (dst_mcv == .none) return;

    if (!dst_mcv.isMutable()) {
        // panic so we can see the trace
        return self.fail("tried to genCopy immutable: {s}", .{@tagName(dst_mcv)});
    }

    switch (dst_mcv) {
        .register => |reg| return self.genSetReg(ty, reg, src_mcv),
        .register_offset => |dst_reg_off| try self.genSetReg(ty, dst_reg_off.reg, switch (src_mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            => unreachable,
            .immediate,
            .register,
            .register_offset,
            => src_mcv.offset(-dst_reg_off.off),
            else => .{ .register_offset = .{
                .reg = try self.copyToTmpRegister(ty, src_mcv),
                .off = -dst_reg_off.off,
            } },
        }),
        .indirect => |ro| {
            const src_reg = try self.copyToTmpRegister(ty, src_mcv);

            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_store_rm,
                .data = .{ .rm = .{
                    .r = src_reg,
                    .m = .{
                        .base = .{ .reg = ro.reg },
                        .mod = .{ .rm = .{ .disp = ro.off, .size = self.memSize(ty) } },
                    },
                } },
            });
        },
        .load_frame => |frame| return self.genSetStack(ty, frame, src_mcv),
        .memory => return self.fail("TODO: genCopy memory", .{}),
        .register_pair => |dst_regs| {
            const src_info: ?struct { addr_reg: Register, addr_lock: RegisterLock } = switch (src_mcv) {
                .register_pair, .memory, .indirect, .load_frame => null,
                .load_symbol => src: {
                    const src_addr_reg, const src_addr_lock = try self.allocReg();
                    errdefer self.register_manager.unlockReg(src_addr_lock);

                    try self.genSetReg(Type.usize, src_addr_reg, src_mcv.address());
                    break :src .{ .addr_reg = src_addr_reg, .addr_lock = src_addr_lock };
                },
                .air_ref => |src_ref| return self.genCopy(
                    ty,
                    dst_mcv,
                    try self.resolveInst(src_ref),
                ),
                else => unreachable,
            };
            defer if (src_info) |info| self.register_manager.unlockReg(info.addr_lock);

            var part_disp: i32 = 0;
            for (dst_regs, try self.splitType(ty), 0..) |dst_reg, dst_ty, part_i| {
                try self.genSetReg(dst_ty, dst_reg, switch (src_mcv) {
                    .register_pair => |src_regs| .{ .register = src_regs[part_i] },
                    .memory, .indirect, .load_frame => src_mcv.address().offset(part_disp).deref(),
                    .load_symbol => .{ .indirect = .{
                        .reg = src_info.?.addr_reg,
                        .off = part_disp,
                    } },
                    else => unreachable,
                });
                part_disp += @intCast(dst_ty.abiSize(zcu));
            }
        },
        else => return self.fail("TODO: genCopy to {s} from {s}", .{ @tagName(dst_mcv), @tagName(src_mcv) }),
    }
}

fn genSetStack(
    self: *Self,
    ty: Type,
    frame: FrameAddr,
    src_mcv: MCValue,
) InnerError!void {
    const zcu = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));

    switch (src_mcv) {
        .none => return,
        .dead => unreachable,
        .undef => {
            if (!self.wantSafety()) return;
            try self.genSetStack(ty, frame, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .immediate,
        .lea_frame,
        => {
            // TODO: remove this lock in favor of a copyToTmpRegister when we load 64 bit immediates with
            // a register allocation.
            const reg, const reg_lock = try self.allocReg();
            defer self.register_manager.unlockReg(reg_lock);

            try self.genSetReg(ty, reg, src_mcv);

            return self.genSetStack(ty, frame, .{ .register = reg });
        },
        .register => |reg| {
            switch (abi_size) {
                1, 2, 4, 8 => {
                    _ = try self.addInst(.{
                        .tag = .pseudo,
                        .ops = .pseudo_store_rm,
                        .data = .{ .rm = .{
                            .r = reg,
                            .m = .{
                                .base = .{ .frame = frame.index },
                                .mod = .{
                                    .rm = .{
                                        .size = self.memSize(ty),
                                        .disp = frame.off,
                                    },
                                },
                            },
                        } },
                    });
                },
                else => unreachable, // register can hold a max of 8 bytes
            }
        },
        .register_pair => |pair| {
            var part_disp: i32 = frame.off;
            for (try self.splitType(ty), pair) |src_ty, src_reg| {
                try self.genSetStack(
                    src_ty,
                    .{ .index = frame.index, .off = part_disp },
                    .{ .register = src_reg },
                );
                part_disp += @intCast(src_ty.abiSize(zcu));
            }
        },
        .load_frame,
        .indirect,
        .load_symbol,
        => {
            if (abi_size <= 8) {
                const reg = try self.copyToTmpRegister(ty, src_mcv);
                return self.genSetStack(ty, frame, .{ .register = reg });
            }

            try self.genInlineMemcpy(
                .{ .lea_frame = frame },
                src_mcv.address(),
                .{ .immediate = abi_size },
            );
        },
        .air_ref => |ref| try self.genSetStack(ty, frame, try self.resolveInst(ref)),
        else => return self.fail("TODO: genSetStack {s}", .{@tagName(src_mcv)}),
    }
}

fn genInlineMemcpy(
    self: *Self,
    dst_ptr: MCValue,
    src_ptr: MCValue,
    len: MCValue,
) !void {
    const regs = try self.register_manager.allocRegs(4, .{null} ** 4, tp);
    const locks = self.register_manager.lockRegsAssumeUnused(4, regs);
    defer for (locks) |lock| self.register_manager.unlockReg(lock);

    const count = regs[0];
    const tmp = regs[1];
    const src = regs[2];
    const dst = regs[3];

    try self.genSetReg(Type.usize, count, len);
    try self.genSetReg(Type.usize, src, src_ptr);
    try self.genSetReg(Type.usize, dst, dst_ptr);

    // lb tmp, 0(src)
    const first_inst = try self.addInst(.{
        .tag = .lb,
        .ops = .rri,
        .data = .{
            .i_type = .{
                .rd = tmp,
                .rs1 = src,
                .imm12 = Immediate.s(0),
            },
        },
    });

    // sb tmp, 0(dst)
    _ = try self.addInst(.{
        .tag = .sb,
        .ops = .rri,
        .data = .{
            .i_type = .{
                .rd = dst,
                .rs1 = tmp,
                .imm12 = Immediate.s(0),
            },
        },
    });

    // dec count by 1
    _ = try self.addInst(.{
        .tag = .addi,
        .ops = .rri,
        .data = .{
            .i_type = .{
                .rd = count,
                .rs1 = count,
                .imm12 = Immediate.s(-1),
            },
        },
    });

    // branch if count is 0
    _ = try self.addInst(.{
        .tag = .beq,
        .ops = .rr_inst,
        .data = .{
            .b_type = .{
                .inst = @intCast(self.mir_instructions.len + 4), // points after the last inst
                .rs1 = count,
                .rs2 = .zero,
            },
        },
    });

    // increment the pointers
    _ = try self.addInst(.{
        .tag = .addi,
        .ops = .rri,
        .data = .{
            .i_type = .{
                .rd = src,
                .rs1 = src,
                .imm12 = Immediate.s(1),
            },
        },
    });

    _ = try self.addInst(.{
        .tag = .addi,
        .ops = .rri,
        .data = .{
            .i_type = .{
                .rd = dst,
                .rs1 = dst,
                .imm12 = Immediate.s(1),
            },
        },
    });

    // jump back to start of loop
    _ = try self.addInst(.{
        .tag = .pseudo,
        .ops = .pseudo_j,
        .data = .{
            .inst = first_inst,
        },
    });
}

/// Sets the value of `src_mcv` into `reg`. Assumes you have a lock on it.
fn genSetReg(self: *Self, ty: Type, reg: Register, src_mcv: MCValue) InnerError!void {
    const zcu = self.bin_file.comp.module.?;
    const abi_size: u32 = @intCast(ty.abiSize(zcu));

    if (abi_size > 8) return self.fail("tried to set reg with size {}", .{abi_size});

    switch (src_mcv) {
        .dead => unreachable,
        .unreach, .none => return, // Nothing to do.
        .undef => {
            if (!self.wantSafety())
                return; // The already existing value will do just fine.
            // Write the debug undefined value.
            return self.genSetReg(ty, reg, .{ .immediate = 0xaaaaaaaaaaaaaaaa });
        },
        .immediate => |unsigned_x| {
            const x: i64 = @bitCast(unsigned_x);
            if (math.minInt(i12) <= x and x <= math.maxInt(i12)) {
                _ = try self.addInst(.{
                    .tag = .addi,
                    .ops = .rri,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = .zero,
                        .imm12 = Immediate.s(@intCast(x)),
                    } },
                });
            } else if (math.minInt(i32) <= x and x <= math.maxInt(i32)) {
                const lo12: i12 = @truncate(x);
                const carry: i32 = if (lo12 < 0) 1 else 0;
                const hi20: i20 = @truncate((x >> 12) +% carry);

                _ = try self.addInst(.{
                    .tag = .lui,
                    .ops = .ri,
                    .data = .{ .u_type = .{
                        .rd = reg,
                        .imm20 = Immediate.s(hi20),
                    } },
                });
                _ = try self.addInst(.{
                    .tag = .addi,
                    .ops = .rri,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = reg,
                        .imm12 = Immediate.s(lo12),
                    } },
                });
            } else {
                // TODO: use a more advanced myriad seq to do this without a reg.
                // see: https://github.com/llvm/llvm-project/blob/081a66ffacfe85a37ff775addafcf3371e967328/llvm/lib/Target/RISCV/MCTargetDesc/RISCVMatInt.cpp#L224

                const temp, const temp_lock = try self.allocReg();
                defer self.register_manager.unlockReg(temp_lock);

                const lo32: i32 = @truncate(x);
                const carry: i32 = if (lo32 < 0) 1 else 0;
                const hi32: i32 = @truncate((x >> 32) +% carry);

                try self.genSetReg(Type.i32, temp, .{ .immediate = @bitCast(@as(i64, lo32)) });
                try self.genSetReg(Type.i32, reg, .{ .immediate = @bitCast(@as(i64, hi32)) });

                _ = try self.addInst(.{
                    .tag = .slli,
                    .ops = .rri,
                    .data = .{ .i_type = .{
                        .rd = reg,
                        .rs1 = reg,
                        .imm12 = Immediate.s(32),
                    } },
                });

                _ = try self.addInst(.{
                    .tag = .add,
                    .ops = .rrr,
                    .data = .{ .r_type = .{
                        .rd = reg,
                        .rs1 = reg,
                        .rs2 = temp,
                    } },
                });
            }
        },
        .register => |src_reg| {
            // If the registers are the same, nothing to do.
            if (src_reg.id() == reg.id())
                return;

            // mov reg, src_reg
            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_mv,
                .data = .{ .rr = .{
                    .rd = reg,
                    .rs = src_reg,
                } },
            });
        },
        .register_pair => |pair| try self.genSetReg(ty, reg, .{ .register = pair[0] }),
        .memory => |addr| {
            try self.genSetReg(ty, reg, .{ .immediate = addr });

            _ = try self.addInst(.{
                .tag = .ld,
                .ops = .rri,
                .data = .{ .i_type = .{
                    .rd = reg,
                    .rs1 = reg,
                    .imm12 = Immediate.s(0),
                } },
            });
        },
        .load_frame => |frame| {
            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_load_rm,
                .data = .{ .rm = .{
                    .r = reg,
                    .m = .{
                        .base = .{ .frame = frame.index },
                        .mod = .{
                            .rm = .{
                                .size = self.memSize(ty),
                                .disp = frame.off,
                            },
                        },
                    },
                } },
            });
        },
        .lea_frame => |frame| {
            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_lea_rm,
                .data = .{ .rm = .{
                    .r = reg,
                    .m = .{
                        .base = .{ .frame = frame.index },
                        .mod = .{
                            .rm = .{
                                .size = self.memSize(ty),
                                .disp = frame.off,
                            },
                        },
                    },
                } },
            });
        },
        .load_symbol => {
            try self.genSetReg(ty, reg, src_mcv.address());
            try self.genSetReg(ty, reg, .{ .indirect = .{ .reg = reg } });
        },
        .indirect => |reg_off| {
            const load_tag: Mir.Inst.Tag = switch (abi_size) {
                1 => .lb,
                2 => .lh,
                4 => .lw,
                8 => .ld,
                else => return self.fail("TODO: genSetReg for size {d}", .{abi_size}),
            };

            _ = try self.addInst(.{
                .tag = load_tag,
                .ops = .rri,
                .data = .{ .i_type = .{
                    .rd = reg,
                    .rs1 = reg_off.reg,
                    .imm12 = Immediate.s(reg_off.off),
                } },
            });
        },
        .lea_symbol => |sym_off| {
            assert(sym_off.off == 0);

            const atom_index = try self.symbolIndex();

            _ = try self.addInst(.{
                .tag = .pseudo,
                .ops = .pseudo_load_symbol,
                .data = .{ .payload = try self.addExtra(Mir.LoadSymbolPayload{
                    .register = reg.id(),
                    .atom_index = atom_index,
                    .sym_index = sym_off.sym,
                }) },
            });
        },
        .air_ref => |ref| try self.genSetReg(ty, reg, try self.resolveInst(ref)),
        else => return self.fail("TODO: genSetReg {s}", .{@tagName(src_mcv)}),
    }
}

fn airIntFromPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const result = result: {
        const src_mcv = try self.resolveInst(un_op);
        if (self.reuseOperand(inst, un_op, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;

    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result = if (self.liveness.isUnused(inst)) .unreach else result: {
        const src_mcv = try self.resolveInst(ty_op.operand);

        const dst_ty = self.typeOfIndex(inst);
        const src_ty = self.typeOf(ty_op.operand);

        const src_lock = if (src_mcv.getReg()) |reg| self.register_manager.lockReg(reg) else null;
        defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

        const dst_mcv = if (dst_ty.abiSize(zcu) <= src_ty.abiSize(zcu) and
            self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) src_mcv else dst: {
            const dst_mcv = try self.allocRegOrMem(inst, true);
            try self.genCopy(switch (math.order(dst_ty.abiSize(zcu), src_ty.abiSize(zcu))) {
                .lt => dst_ty,
                .eq => if (!dst_mcv.isMemory() or src_mcv.isMemory()) dst_ty else src_ty,
                .gt => src_ty,
            }, dst_mcv, src_mcv);
            break :dst dst_mcv;
        };

        if (dst_ty.isAbiInt(zcu) and src_ty.isAbiInt(zcu) and
            dst_ty.intInfo(zcu).signedness == src_ty.intInfo(zcu).signedness) break :result dst_mcv;

        const abi_size = dst_ty.abiSize(zcu);
        const bit_size = dst_ty.bitSize(zcu);
        if (abi_size * 8 <= bit_size) break :result dst_mcv;

        return self.fail("TODO: airBitCast {} to {}", .{ src_ty.fmt(zcu), dst_ty.fmt(zcu) });
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airArrayToSlice for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airFloatFromInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airFloatFromInt for {}", .{
        self.target.cpu.arch,
    });
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntFromFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airIntFromFloat for {}", .{
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

fn airMemset(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    _ = inst;
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    return self.fail("TODO implement airMemset for {}", .{self.target.cpu.arch});
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airMemcpy for {}", .{self.target.cpu.arch});
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;
    const operand = try self.resolveInst(un_op);
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else {
        _ = operand;
        return self.fail("TODO implement airTagName for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const un_op = self.air.instructions.items(.data)[@intFromEnum(inst)].un_op;

    const err_ty = self.typeOf(un_op);
    const err_mcv = try self.resolveInst(un_op);

    const err_reg = try self.copyToTmpRegister(err_ty, err_mcv);
    const err_lock = self.register_manager.lockRegAssumeUnused(err_reg);
    defer self.register_manager.unlockReg(err_lock);

    const addr_reg, const addr_lock = try self.allocReg();
    defer self.register_manager.unlockReg(addr_lock);

    const lazy_sym = link.File.LazySymbol.initDecl(.const_data, null, zcu);
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const sym_index = elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const sym = elf_file.symbol(sym_index);
        try self.genSetReg(Type.usize, addr_reg, .{ .load_symbol = .{ .sym = sym.esym_index } });
    } else {
        return self.fail("TODO: riscv non-elf", .{});
    }

    const start_reg, const start_lock = try self.allocReg();
    defer self.register_manager.unlockReg(start_lock);

    const end_reg, const end_lock = try self.allocReg();
    defer self.register_manager.unlockReg(end_lock);

    _ = start_reg;
    _ = end_reg;

    return self.fail("TODO: airErrorName", .{});
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airSplat for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airSelect for riscv64", .{});
    return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_op;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airShuffle for riscv64", .{});
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[@intFromEnum(inst)].reduce;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else return self.fail("TODO implement airReduce for riscv64", .{});
    return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const zcu = self.bin_file.comp.module.?;
    const result_ty = self.typeOfIndex(inst);
    const len: usize = @intCast(result_ty.arrayLen(zcu));
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const elements: []const Air.Inst.Ref = @ptrCast(self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = result: {
        switch (result_ty.zigTypeTag(zcu)) {
            .Struct => {
                const frame_index = try self.allocFrameIndex(FrameAlloc.initSpill(result_ty, zcu));

                if (result_ty.containerLayout(zcu) == .@"packed") {} else for (elements, 0..) |elem, elem_i| {
                    if ((try result_ty.structFieldValueComptime(zcu, elem_i)) != null) continue;

                    const elem_ty = result_ty.structFieldType(elem_i, zcu);
                    const elem_off: i32 = @intCast(result_ty.structFieldOffset(elem_i, zcu));
                    const elem_mcv = try self.resolveInst(elem);

                    const elem_frame: FrameAddr = .{
                        .index = frame_index,
                        .off = elem_off,
                    };
                    try self.genSetStack(
                        elem_ty,
                        elem_frame,
                        elem_mcv,
                    );
                }
            },
            else => return self.fail("TODO: airAggregateInit {}", .{result_ty.fmt(zcu)}),
        }
        break :result .{ .register = .zero };
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        @memcpy(buf[0..elements.len], elements);
        return self.finishAir(inst, result, buf);
    }
    var bt = self.liveness.iterateBigTomb(inst);
    for (elements) |elem| try self.feed(&bt, elem);
    return self.finishAirResult(inst, result);
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[@intFromEnum(inst)].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement airUnionInit for riscv64", .{});
    // return self.finishAir(inst, result, .{ extra.ptr, extra.expected_value, extra.new_value });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[@intFromEnum(inst)].prefetch;
    // TODO: RISC-V does have prefetch instruction variants.
    // see here: https://raw.githubusercontent.com/riscv/riscv-CMOs/master/specifications/cmobase-v1.0.1.pdf
    return self.finishAir(inst, .unreach, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[@intFromEnum(inst)].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else {
        return self.fail("TODO implement airMulAdd for riscv64", .{});
    };
    return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn resolveInst(self: *Self, ref: Air.Inst.Ref) InnerError!MCValue {
    const zcu = self.bin_file.comp.module.?;

    // If the type has no codegen bits, no need to store it.
    const inst_ty = self.typeOf(ref);
    if (!inst_ty.hasRuntimeBits(zcu))
        return .none;

    const mcv = if (ref.toIndex()) |inst| mcv: {
        break :mcv self.inst_tracking.getPtr(inst).?.short;
    } else mcv: {
        const ip_index = ref.toInterned().?;
        const gop = try self.const_tracking.getOrPut(self.gpa, ip_index);
        if (!gop.found_existing) gop.value_ptr.* = InstTracking.init(
            try self.genTypedValue(Value.fromInterned(ip_index)),
        );
        break :mcv gop.value_ptr.short;
    };

    return mcv;
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) *InstTracking {
    const tracking = self.inst_tracking.getPtr(inst).?;
    return switch (tracking.short) {
        .none, .unreach, .dead => unreachable,
        else => tracking,
    };
}

fn genTypedValue(self: *Self, val: Value) InnerError!MCValue {
    const zcu = self.bin_file.comp.module.?;
    const result = try codegen.genTypedValue(
        self.bin_file,
        self.src_loc,
        val,
        zcu.funcOwnerDeclIndex(self.func_index),
    );
    const mcv: MCValue = switch (result) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .load_symbol => |sym_index| .{ .load_symbol = .{ .sym = sym_index } },
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_got, .load_direct, .load_tlv => {
                return self.fail("TODO: genTypedValue {s}", .{@tagName(mcv)});
            },
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
    return_value: InstTracking,
    stack_byte_count: u31,
    stack_align: Alignment,

    fn deinit(self: *CallMCValues, func: *Self) void {
        func.gpa.free(self.args);
        self.* = undefined;
    }
};

/// Caller must call `CallMCValues.deinit`.
fn resolveCallingConventionValues(
    self: *Self,
    fn_info: InternPool.Key.FuncType,
) !CallMCValues {
    const zcu = self.bin_file.comp.module.?;
    const ip = &zcu.intern_pool;

    const param_types = try self.gpa.alloc(Type, fn_info.param_types.len);
    defer self.gpa.free(param_types);

    for (param_types[0..fn_info.param_types.len], fn_info.param_types.get(ip)) |*dest, src| {
        dest.* = Type.fromInterned(src);
    }

    const cc = fn_info.cc;
    var result: CallMCValues = .{
        .args = try self.gpa.alloc(MCValue, param_types.len),
        // These undefined values must be populated before returning from this function.
        .return_value = undefined,
        .stack_byte_count = 0,
        .stack_align = undefined,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = Type.fromInterned(fn_info.return_type);

    switch (cc) {
        .Naked => {
            assert(result.args.len == 0);
            result.return_value = InstTracking.init(.unreach);
            result.stack_align = .@"8";
        },
        .C, .Unspecified => {
            if (result.args.len > 8) {
                return self.fail("RISC-V calling convention does not support more than 8 arguments", .{});
            }

            var ret_int_reg_i: u32 = 0;
            var param_int_reg_i: u32 = 0;

            result.stack_align = .@"16";

            // Return values
            if (ret_ty.zigTypeTag(zcu) == .NoReturn) {
                result.return_value = InstTracking.init(.unreach);
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
                result.return_value = InstTracking.init(.none);
            } else {
                var ret_tracking: [2]InstTracking = undefined;
                var ret_tracking_i: usize = 0;

                const classes = mem.sliceTo(&abi.classifySystem(ret_ty, zcu), .none);

                for (classes) |class| switch (class) {
                    .integer => {
                        const ret_int_reg = abi.function_ret_regs[ret_int_reg_i];
                        ret_int_reg_i += 1;

                        ret_tracking[ret_tracking_i] = InstTracking.init(.{ .register = ret_int_reg });
                        ret_tracking_i += 1;
                    },
                    .memory => {
                        const ret_int_reg = abi.function_ret_regs[ret_int_reg_i];
                        ret_int_reg_i += 1;
                        const ret_indirect_reg = abi.function_arg_regs[param_int_reg_i];
                        param_int_reg_i += 1;

                        ret_tracking[ret_tracking_i] = .{
                            .short = .{ .indirect = .{ .reg = ret_int_reg } },
                            .long = .{ .indirect = .{ .reg = ret_indirect_reg } },
                        };
                        ret_tracking_i += 1;
                    },
                    else => return self.fail("TODO: C calling convention return class {}", .{class}),
                };

                result.return_value = switch (ret_tracking_i) {
                    else => return self.fail("ty {} took {} tracking return indices", .{ ret_ty.fmt(zcu), ret_tracking_i }),
                    1 => ret_tracking[0],
                    2 => InstTracking.init(.{ .register_pair = .{
                        ret_tracking[0].short.register, ret_tracking[1].short.register,
                    } }),
                };
            }

            for (param_types, result.args) |ty, *arg| {
                assert(ty.hasRuntimeBitsIgnoreComptime(zcu));

                var arg_mcv: [2]MCValue = undefined;
                var arg_mcv_i: usize = 0;

                const classes = mem.sliceTo(&abi.classifySystem(ty, zcu), .none);

                for (classes) |class| switch (class) {
                    .integer => {
                        const param_int_regs = abi.function_arg_regs;
                        if (param_int_reg_i >= param_int_regs.len) break;

                        const param_int_reg = param_int_regs[param_int_reg_i];
                        param_int_reg_i += 1;

                        arg_mcv[arg_mcv_i] = .{ .register = param_int_reg };
                        arg_mcv_i += 1;
                    },
                    .memory => {
                        const param_int_regs = abi.function_arg_regs;
                        const param_int_reg = param_int_regs[param_int_reg_i];

                        arg_mcv[arg_mcv_i] = .{ .indirect = .{ .reg = param_int_reg } };
                        arg_mcv_i += 1;
                    },
                    else => return self.fail("TODO: C calling convention arg class {}", .{class}),
                } else {
                    arg.* = switch (arg_mcv_i) {
                        else => return self.fail("ty {} took {} tracking arg indices", .{ ty.fmt(zcu), arg_mcv_i }),
                        1 => arg_mcv[0],
                        2 => .{ .register_pair = .{ arg_mcv[0].register, arg_mcv[1].register } },
                    };
                    continue;
                }

                return self.fail("TODO: pass args by stack", .{});
            }
        },
        else => return self.fail("TODO implement function parameters for {} on riscv64", .{cc}),
    }

    result.stack_byte_count = @intCast(result.stack_align.forward(result.stack_byte_count));
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
    self.err_msg = try ErrorMsg.create(self.gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn failSymbol(self: *Self, comptime format: []const u8, args: anytype) InnerError {
    @setCold(true);
    assert(self.err_msg == null);
    self.err_msg = try ErrorMsg.create(self.gpa, self.src_loc, format, args);
    return error.CodegenFail;
}

fn parseRegName(name: []const u8) ?Register {
    if (@hasDecl(Register, "parseRegName")) {
        return Register.parseRegName(name);
    }
    return std.meta.stringToEnum(Register, name);
}

fn typeOf(self: *Self, inst: Air.Inst.Ref) Type {
    const zcu = self.bin_file.comp.module.?;
    return self.air.typeOf(inst, &zcu.intern_pool);
}

fn typeOfIndex(self: *Self, inst: Air.Inst.Index) Type {
    const zcu = self.bin_file.comp.module.?;
    return self.air.typeOfIndex(inst, &zcu.intern_pool);
}

fn hasFeature(self: *Self, feature: Target.riscv.Feature) bool {
    return Target.riscv.featureSetHas(self.target.cpu.features, feature);
}

pub fn errUnionPayloadOffset(payload_ty: Type, zcu: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return 0;
    const payload_align = payload_ty.abiAlignment(zcu);
    const error_align = Type.anyerror.abiAlignment(zcu);
    if (payload_align.compare(.gte, error_align) or !payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return 0;
    } else {
        return payload_align.forward(Type.anyerror.abiSize(zcu));
    }
}

pub fn errUnionErrorOffset(payload_ty: Type, zcu: *Module) u64 {
    if (!payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) return 0;
    const payload_align = payload_ty.abiAlignment(zcu);
    const error_align = Type.anyerror.abiAlignment(zcu);
    if (payload_align.compare(.gte, error_align) and payload_ty.hasRuntimeBitsIgnoreComptime(zcu)) {
        return error_align.forward(payload_ty.abiSize(zcu));
    } else {
        return 0;
    }
}
