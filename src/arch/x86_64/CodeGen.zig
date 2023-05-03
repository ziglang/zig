const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const codegen = @import("../../codegen.zig");
const leb128 = std.leb;
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const tracking_log = std.log.scoped(.tracking);
const verbose_tracking_log = std.log.scoped(.verbose_tracking);
const wip_mir_log = std.log.scoped(.wip_mir);
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
const FrameIndex = bits.FrameIndex;

const gp = abi.RegisterClass.gp;
const sse = abi.RegisterClass.sse;

const InnerError = CodeGenError || error{OutOfRegisters};

gpa: Allocator,
air: Air,
liveness: Liveness,
bin_file: *link.File,
debug_output: DebugInfoOutput,
target: *const std.Target,
owner: Owner,
err_msg: ?*ErrorMsg,
args: []MCValue,
ret_mcv: InstTracking,
fn_type: Type,
arg_index: u32,
src_loc: Module.SrcLoc,

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

const_tracking: InstTrackingMap = .{},
inst_tracking: InstTrackingMap = .{},

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .{},

register_manager: RegisterManager = .{},

/// Generation of the current scope, increments by 1 for every entered scope.
scope_generation: u32 = 0,

frame_allocs: std.MultiArrayList(FrameAlloc) = .{},
free_frame_indices: std.AutoArrayHashMapUnmanaged(FrameIndex, void) = .{},
frame_locs: std.MultiArrayList(Mir.FrameLoc) = .{},

/// Debug field, used to find bugs in the compiler.
air_bookkeeping: @TypeOf(air_bookkeeping_init) = air_bookkeeping_init,

/// For mir debug info, maps a mir index to a air index
mir_to_air_map: @TypeOf(mir_to_air_map_init) = mir_to_air_map_init,

const air_bookkeeping_init = if (std.debug.runtime_safety) @as(usize, 0) else {};

const mir_to_air_map_init = if (builtin.mode == .Debug) std.AutoHashMapUnmanaged(Mir.Inst.Index, Air.Inst.Index){} else {};

const FrameAddr = struct { index: FrameIndex, off: i32 = 0 };
const RegisterOffset = struct { reg: Register, off: i32 = 0 };

const Owner = union(enum) {
    mod_fn: *const Module.Fn,
    lazy_sym: link.File.LazySymbol,

    fn getDecl(owner: Owner) Module.Decl.Index {
        return switch (owner) {
            .mod_fn => |mod_fn| mod_fn.owner_decl,
            .lazy_sym => |lazy_sym| lazy_sym.ty.getOwnerDecl(),
        };
    }

    fn getSymbolIndex(owner: Owner, ctx: *Self) !u32 {
        switch (owner) {
            .mod_fn => |mod_fn| {
                const decl_index = mod_fn.owner_decl;
                if (ctx.bin_file.cast(link.File.MachO)) |macho_file| {
                    const atom = try macho_file.getOrCreateAtomForDecl(decl_index);
                    return macho_file.getAtom(atom).getSymbolIndex().?;
                } else if (ctx.bin_file.cast(link.File.Coff)) |coff_file| {
                    const atom = try coff_file.getOrCreateAtomForDecl(decl_index);
                    return coff_file.getAtom(atom).getSymbolIndex().?;
                } else unreachable;
            },
            .lazy_sym => |lazy_sym| {
                if (ctx.bin_file.cast(link.File.MachO)) |macho_file| {
                    const atom = macho_file.getOrCreateAtomForLazySymbol(lazy_sym) catch |err|
                        return ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
                    return macho_file.getAtom(atom).getSymbolIndex().?;
                } else if (ctx.bin_file.cast(link.File.Coff)) |coff_file| {
                    const atom = coff_file.getOrCreateAtomForLazySymbol(lazy_sym) catch |err|
                        return ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
                    return coff_file.getAtom(atom).getSymbolIndex().?;
                } else unreachable;
            },
        }
    }
};

pub const MCValue = union(enum) {
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
    /// The value resides in the EFLAGS register.
    eflags: Condition,
    /// The value is in a register.
    register: Register,
    /// The value is a constant offset from the value in a register.
    register_offset: RegisterOffset,
    /// The value is a tuple { wrapped, overflow } where wrapped value is stored in the GP register.
    register_overflow: struct { reg: Register, eflags: Condition },
    /// The value is in memory at a hard-coded address.
    /// If the type is a pointer, it means the pointer address is at this memory location.
    memory: u64,
    /// The value is in memory at a constant offset from the address in a register.
    indirect: RegisterOffset,
    /// The value is in memory.
    /// Payload is a symbol index.
    load_direct: u32,
    /// The value is a pointer to a value in memory.
    /// Payload is a symbol index.
    lea_direct: u32,
    /// The value is in memory referenced indirectly via GOT.
    /// Payload is a symbol index.
    load_got: u32,
    /// The value is a pointer to a value referenced indirectly via GOT.
    /// Payload is a symbol index.
    lea_got: u32,
    /// The value is a threadlocal variable.
    /// Payload is a symbol index.
    load_tlv: u32,
    /// The value is a pointer to a threadlocal variable.
    /// Payload is a symbol index.
    lea_tlv: u32,
    /// The value stored at an offset from a frame index
    /// Payload is a frame address.
    load_frame: FrameAddr,
    /// The address of an offset from a frame index
    /// Payload is a frame address.
    lea_frame: FrameAddr,
    /// This indicates that we have already allocated a frame index for this instruction,
    /// but it has not been spilled there yet in the current control flow.
    /// Payload is a frame index.
    reserved_frame: FrameIndex,

    fn isMemory(mcv: MCValue) bool {
        return switch (mcv) {
            .memory,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .lea_frame,
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
            .register_offset => |reg_off| return reg_off.off == 0,
            else => false,
        };
    }

    fn isRegisterOffset(mcv: MCValue) bool {
        return switch (mcv) {
            .register, .register_offset => true,
            else => false,
        };
    }

    fn getReg(mcv: MCValue) ?Register {
        return switch (mcv) {
            .register => |reg| reg,
            .register_offset, .indirect => |ro| ro.reg,
            .register_overflow => |ro| ro.reg,
            else => null,
        };
    }

    fn getCondition(mcv: MCValue) ?Condition {
        return switch (mcv) {
            .eflags => |cc| cc,
            .register_overflow => |reg_ov| reg_ov.eflags,
            else => null,
        };
    }

    fn address(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .eflags,
            .register,
            .register_offset,
            .register_overflow,
            .lea_direct,
            .lea_got,
            .lea_tlv,
            .lea_frame,
            .reserved_frame,
            => unreachable, // not in memory
            .memory => |addr| .{ .immediate = addr },
            .indirect => |reg_off| switch (reg_off.off) {
                0 => .{ .register = reg_off.reg },
                else => .{ .register_offset = reg_off },
            },
            .load_direct => |sym_index| .{ .lea_direct = sym_index },
            .load_got => |sym_index| .{ .lea_got = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
            .load_frame => |frame_addr| .{ .lea_frame = frame_addr },
        };
    }

    fn deref(mcv: MCValue) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .eflags,
            .register_overflow,
            .memory,
            .indirect,
            .load_direct,
            .load_got,
            .load_tlv,
            .load_frame,
            .reserved_frame,
            => unreachable, // not a dereferenceable
            .immediate => |addr| .{ .memory = addr },
            .register => |reg| .{ .indirect = .{ .reg = reg } },
            .register_offset => |reg_off| .{ .indirect = reg_off },
            .lea_direct => |sym_index| .{ .load_direct = sym_index },
            .lea_got => |sym_index| .{ .load_got = sym_index },
            .lea_tlv => |sym_index| .{ .load_tlv = sym_index },
            .lea_frame => |frame_addr| .{ .load_frame = frame_addr },
        };
    }

    fn offset(mcv: MCValue, off: i32) MCValue {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .eflags,
            .register_overflow,
            .memory,
            .indirect,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .reserved_frame,
            => unreachable, // not offsettable
            .immediate => |imm| .{ .immediate = @bitCast(u64, @bitCast(i64, imm) +% off) },
            .register => |reg| .{ .register_offset = .{ .reg = reg, .off = off } },
            .register_offset => |reg_off| .{
                .register_offset = .{ .reg = reg_off.reg, .off = reg_off.off + off },
            },
            .lea_frame => |frame_addr| .{
                .lea_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
            },
        };
    }

    fn mem(mcv: MCValue, ptr_size: Memory.PtrSize) Memory {
        return switch (mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .immediate,
            .eflags,
            .register,
            .register_offset,
            .register_overflow,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .lea_frame,
            .reserved_frame,
            => unreachable,
            .memory => |addr| if (math.cast(i32, @bitCast(i64, addr))) |small_addr|
                Memory.sib(ptr_size, .{ .base = .{ .reg = .ds }, .disp = small_addr })
            else
                Memory.moffs(.ds, addr),
            .indirect => |reg_off| Memory.sib(ptr_size, .{
                .base = .{ .reg = reg_off.reg },
                .disp = reg_off.off,
            }),
            .load_frame => |frame_addr| Memory.sib(ptr_size, .{
                .base = .{ .frame = frame_addr.index },
                .disp = frame_addr.off,
            }),
        };
    }

    pub fn format(
        mcv: MCValue,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (mcv) {
            .none, .unreach, .dead, .undef => try writer.print("({s})", .{@tagName(mcv)}),
            .immediate => |pl| try writer.print("0x{x}", .{pl}),
            .memory => |pl| try writer.print("[ds:0x{x}]", .{pl}),
            inline .eflags, .register => |pl| try writer.print("{s}", .{@tagName(pl)}),
            .register_offset => |pl| try writer.print("{s} + 0x{x}", .{ @tagName(pl.reg), pl.off }),
            .register_overflow => |pl| try writer.print("{s}:{s}", .{ @tagName(pl.eflags), @tagName(pl.reg) }),
            .indirect => |pl| try writer.print("[{s} + 0x{x}]", .{ @tagName(pl.reg), pl.off }),
            .load_direct => |pl| try writer.print("[direct:{d}]", .{pl}),
            .lea_direct => |pl| try writer.print("direct:{d}", .{pl}),
            .load_got => |pl| try writer.print("[got:{d}]", .{pl}),
            .lea_got => |pl| try writer.print("got:{d}", .{pl}),
            .load_tlv => |pl| try writer.print("[tlv:{d}]", .{pl}),
            .lea_tlv => |pl| try writer.print("tlv:{d}", .{pl}),
            .load_frame => |pl| try writer.print("[{} + 0x{x}]", .{ pl.index, pl.off }),
            .lea_frame => |pl| try writer.print("{} + 0x{x}", .{ pl.index, pl.off }),
            .reserved_frame => |pl| try writer.print("(dead:{})", .{pl}),
        }
    }
};

const InstTrackingMap = std.AutoArrayHashMapUnmanaged(Air.Inst.Index, InstTracking);
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
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .lea_frame,
            => result,
            .dead,
            .reserved_frame,
            => unreachable,
            .eflags,
            .register,
            .register_offset,
            .register_overflow,
            .indirect,
            => .none,
        }, .short = result };
    }

    fn getReg(self: InstTracking) ?Register {
        return self.short.getReg();
    }

    fn getCondition(self: InstTracking) ?Condition {
        return self.short.getCondition();
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
        try function.genCopy(function.air.typeOfIndex(inst), self.long, self.short);
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
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .load_frame,
            .lea_frame,
            => self.long,
            .dead,
            .eflags,
            .register,
            .register_offset,
            .register_overflow,
            .indirect,
            .reserved_frame,
            => unreachable,
        };
    }

    fn trackSpill(self: *InstTracking, function: *Self, inst: Air.Inst.Index) void {
        function.freeValue(self.short);
        self.reuseFrame();
        tracking_log.debug("%{d} => {} (spilled)", .{ inst, self.* });
    }

    fn verifyMaterialize(self: *InstTracking, target: InstTracking) void {
        switch (self.long) {
            .none,
            .unreach,
            .undef,
            .immediate,
            .memory,
            .load_direct,
            .lea_direct,
            .load_got,
            .lea_got,
            .load_tlv,
            .lea_tlv,
            .lea_frame,
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
            .eflags,
            .register,
            .register_offset,
            .register_overflow,
            .indirect,
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
        self: *InstTracking,
        function: *Self,
        inst: Air.Inst.Index,
        target: InstTracking,
    ) !void {
        const ty = function.air.typeOfIndex(inst);
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

    fn die(self: *InstTracking, function: *Self, inst: Air.Inst.Index) void {
        function.freeValue(self.short);
        self.short = .{ .dead = function.scope_generation };
        tracking_log.debug("%{d} => {} (death)", .{ inst, self.* });
    }

    fn reuse(
        self: *InstTracking,
        function: *Self,
        new_inst: Air.Inst.Index,
        old_inst: Air.Inst.Index,
    ) void {
        self.short = .{ .dead = function.scope_generation };
        tracking_log.debug("%{d} => {} (reuse %{d})", .{ new_inst, self.*, old_inst });
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
    abi_align: u5,
    ref_count: u16,

    fn init(alloc_abi: struct { size: u64, alignment: u32 }) FrameAlloc {
        assert(math.isPowerOfTwo(alloc_abi.alignment));
        return .{
            .abi_size = @intCast(u31, alloc_abi.size),
            .abi_align = math.log2_int(u32, alloc_abi.alignment),
            .ref_count = 0,
        };
    }
    fn initType(ty: Type, target: Target) FrameAlloc {
        return init(.{ .size = ty.abiSize(target), .alignment = ty.abiAlignment(target) });
    }
};

const StackAllocation = struct {
    inst: ?Air.Inst.Index,
    /// TODO do we need size? should be determined by inst.ty.abiSize(self.target.*)
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

    const gpa = bin_file.allocator;
    var function = Self{
        .gpa = gpa,
        .air = air,
        .liveness = liveness,
        .target = &bin_file.options.target,
        .bin_file = bin_file,
        .debug_output = debug_output,
        .owner = .{ .mod_fn = module_fn },
        .err_msg = null,
        .args = undefined, // populated after `resolveCallingConventionValues`
        .ret_mcv = undefined, // populated after `resolveCallingConventionValues`
        .fn_type = fn_type,
        .arg_index = 0,
        .src_loc = src_loc,
        .end_di_line = module_fn.rbrace_line,
        .end_di_column = module_fn.rbrace_column,
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
        if (builtin.mode == .Debug) function.mir_to_air_map.deinit(gpa);
    }

    wip_mir_log.debug("{}:", .{function.fmtDecl(module_fn.owner_decl)});

    try function.frame_allocs.resize(gpa, FrameIndex.named_count);
    function.frame_allocs.set(
        @enumToInt(FrameIndex.stack_frame),
        FrameAlloc.init(.{
            .size = 0,
            .alignment = if (mod.align_stack_fns.get(module_fn)) |set_align_stack|
                set_align_stack.alignment
            else
                1,
        }),
    );
    function.frame_allocs.set(
        @enumToInt(FrameIndex.call_frame),
        FrameAlloc.init(.{ .size = 0, .alignment = 1 }),
    );

    var call_info = function.resolveCallingConventionValues(fn_type, &.{}, .args_frame) catch |err| switch (err) {
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
    function.frame_allocs.set(@enumToInt(FrameIndex.ret_addr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(function.target.*),
        .alignment = @min(Type.usize.abiAlignment(function.target.*), call_info.stack_align),
    }));
    function.frame_allocs.set(@enumToInt(FrameIndex.base_ptr), FrameAlloc.init(.{
        .size = Type.usize.abiSize(function.target.*),
        .alignment = @min(Type.usize.abiAlignment(function.target.*) * 2, call_info.stack_align),
    }));
    function.frame_allocs.set(
        @enumToInt(FrameIndex.args_frame),
        FrameAlloc.init(.{ .size = call_info.stack_byte_count, .alignment = call_info.stack_align }),
    );

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
        .frame_locs = function.frame_locs.toOwnedSlice(),
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

pub fn generateLazy(
    bin_file: *link.File,
    src_loc: Module.SrcLoc,
    lazy_sym: link.File.LazySymbol,
    code: *std.ArrayList(u8),
    debug_output: DebugInfoOutput,
) CodeGenError!Result {
    const gpa = bin_file.allocator;
    var function = Self{
        .gpa = gpa,
        .air = undefined,
        .liveness = undefined,
        .target = &bin_file.options.target,
        .bin_file = bin_file,
        .debug_output = debug_output,
        .owner = .{ .lazy_sym = lazy_sym },
        .err_msg = null,
        .args = undefined,
        .ret_mcv = undefined,
        .fn_type = undefined,
        .arg_index = undefined,
        .src_loc = src_loc,
        .end_di_line = undefined, // no debug info yet
        .end_di_column = undefined, // no debug info yet
    };
    defer {
        function.mir_instructions.deinit(gpa);
        function.mir_extra.deinit(gpa);
    }

    function.genLazy(lazy_sym) catch |err| switch (err) {
        error.CodegenFail => return Result{ .fail = function.err_msg.? },
        error.OutOfRegisters => return Result{
            .fail = try ErrorMsg.create(bin_file.allocator, src_loc, "CodeGen ran out of registers. This is a bug in the Zig compiler.", .{}),
        },
        else => |e| return e,
    };

    var mir = Mir{
        .instructions = function.mir_instructions.toOwnedSlice(),
        .extra = try function.mir_extra.toOwnedSlice(bin_file.allocator),
        .frame_locs = function.frame_locs.toOwnedSlice(),
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
        .prev_di_pc = undefined, // no debug info yet
        .prev_di_line = undefined, // no debug info yet
        .prev_di_column = undefined, // no debug info yet
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

const FormatDeclData = struct {
    mod: *Module,
    decl_index: Module.Decl.Index,
};
fn formatDecl(
    data: FormatDeclData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    try data.mod.declPtr(data.decl_index).renderFullyQualifiedName(data.mod, writer);
}
fn fmtDecl(self: *Self, decl_index: Module.Decl.Index) std.fmt.Formatter(formatDecl) {
    return .{ .data = .{
        .mod = self.bin_file.options.module.?,
        .decl_index = decl_index,
    } };
}

const FormatAirData = struct {
    self: *Self,
    inst: Air.Inst.Index,
};
fn formatAir(
    data: FormatAirData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    @import("../../print_air.zig").dumpInst(
        data.inst,
        data.self.bin_file.options.module.?,
        data.self.air,
        data.self.liveness,
    );
}
fn fmtAir(self: *Self, inst: Air.Inst.Index) std.fmt.Formatter(formatAir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

const FormatWipMirData = struct {
    self: *Self,
    inst: Mir.Inst.Index,
};
fn formatWipMir(
    data: FormatWipMirData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var lower = Lower{
        .allocator = data.self.gpa,
        .mir = .{
            .instructions = data.self.mir_instructions.slice(),
            .extra = data.self.mir_extra.items,
            .frame_locs = (std.MultiArrayList(Mir.FrameLoc){}).slice(),
        },
        .target = data.self.target,
        .src_loc = data.self.src_loc,
    };
    for (lower.lowerMir(data.self.mir_instructions.get(data.inst)) catch |err| switch (err) {
        error.LowerFail => {
            defer {
                lower.err_msg.?.deinit(data.self.gpa);
                lower.err_msg = null;
            }
            try writer.writeAll(lower.err_msg.?.msg);
            return;
        },
        error.OutOfMemory, error.InvalidInstruction, error.CannotEncode => |e| {
            try writer.writeAll(switch (e) {
                error.OutOfMemory => "Out of memory",
                error.InvalidInstruction => "CodeGen failed to find a viable instruction.",
                error.CannotEncode => "CodeGen failed to encode the instruction.",
            });
            return;
        },
        else => |e| return e,
    }) |lower_inst| try writer.print("  | {}", .{lower_inst});
}
fn fmtWipMir(self: *Self, inst: Mir.Inst.Index) std.fmt.Formatter(formatWipMir) {
    return .{ .data = .{ .self = self, .inst = inst } };
}

const FormatTrackingData = struct {
    self: *Self,
};
fn formatTracking(
    data: FormatTrackingData,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var it = data.self.inst_tracking.iterator();
    while (it.next()) |entry| try writer.print("\n%{d} = {}", .{ entry.key_ptr.*, entry.value_ptr.* });
}
fn fmtTracking(self: *Self) std.fmt.Formatter(formatTracking) {
    return .{ .data = .{ .self = self } };
}

fn addInst(self: *Self, inst: Mir.Inst) error{OutOfMemory}!Mir.Inst.Index {
    const gpa = self.gpa;
    try self.mir_instructions.ensureUnusedCapacity(gpa, 1);
    const result_index = @intCast(Mir.Inst.Index, self.mir_instructions.len);
    self.mir_instructions.appendAssumeCapacity(inst);
    switch (inst.tag) {
        else => wip_mir_log.debug("{}", .{self.fmtWipMir(result_index)}),
        .dbg_line,
        .dbg_prologue_end,
        .dbg_epilogue_begin,
        .dead,
        => {},
    }
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

fn asmPlaceholder(self: *Self) !Mir.Inst.Index {
    return self.addInst(.{
        .tag = .dead,
        .ops = undefined,
        .data = undefined,
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

fn asmRegisterMemoryImmediate(
    self: *Self,
    tag: Mir.Inst.Tag,
    reg: Register,
    m: Memory,
    imm: Immediate,
) !void {
    _ = try self.addInst(.{
        .tag = tag,
        .ops = switch (m) {
            .sib => .rmi_sib,
            .rip => .rmi_rip,
            else => unreachable,
        },
        .data = .{ .rix = .{ .r = reg, .i = @intCast(u8, imm.unsigned), .payload = switch (m) {
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
        const backpatch_push_callee_preserved_regs = try self.asmPlaceholder();
        try self.asmRegisterRegister(.mov, .rbp, .rsp);
        const backpatch_frame_align = try self.asmPlaceholder();
        const backpatch_stack_alloc = try self.asmPlaceholder();

        switch (self.ret_mcv.long) {
            .none, .unreach => {},
            .indirect => {
                // The address where to store the return value for the caller is in a
                // register which the callee is free to clobber. Therefore, we purposely
                // spill it to stack immediately.
                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initType(Type.usize, self.target.*));
                try self.genSetMem(
                    .{ .frame = frame_index },
                    0,
                    Type.usize,
                    self.ret_mcv.long.address().offset(-self.ret_mcv.short.indirect.off),
                );
                self.ret_mcv.long = .{ .load_frame = .{ .index = frame_index } };
                tracking_log.debug("spill {} to {}", .{ self.ret_mcv.long, frame_index });
            },
            else => unreachable,
        }

        try self.asmOpOnly(.dbg_prologue_end);

        try self.genBody(self.air.getMainBody());

        // TODO can single exitlude jump reloc be elided? What if it is not at the end of the code?
        // Example:
        // pub fn main() void {
        //     maybeErr() catch return;
        //     unreachable;
        // }
        // Eliding the reloc will cause a miscompilation in this case.
        for (self.exitlude_jump_relocs.items) |jmp_reloc| {
            self.mir_instructions.items(.data)[jmp_reloc].inst =
                @intCast(u32, self.mir_instructions.len);
        }

        try self.asmOpOnly(.dbg_epilogue_begin);
        const backpatch_stack_dealloc = try self.asmPlaceholder();
        const backpatch_pop_callee_preserved_regs = try self.asmPlaceholder();
        try self.asmRegister(.pop, .rbp);
        try self.asmOpOnly(.ret);

        const frame_layout = try self.computeFrameLayout();
        const need_frame_align = frame_layout.stack_mask != math.maxInt(u32);
        const need_stack_adjust = frame_layout.stack_adjust > 0;
        const need_save_reg = frame_layout.save_reg_list.count() > 0;
        if (need_frame_align) {
            self.mir_instructions.set(backpatch_frame_align, .{
                .tag = .@"and",
                .ops = .ri_s,
                .data = .{ .ri = .{ .r = .rsp, .i = frame_layout.stack_mask } },
            });
        }
        if (need_stack_adjust) {
            self.mir_instructions.set(backpatch_stack_alloc, .{
                .tag = .sub,
                .ops = .ri_s,
                .data = .{ .ri = .{ .r = .rsp, .i = frame_layout.stack_adjust } },
            });
        }
        if (need_frame_align or need_stack_adjust) {
            self.mir_instructions.set(backpatch_stack_dealloc, .{
                .tag = .mov,
                .ops = .rr,
                .data = .{ .rr = .{ .r1 = .rsp, .r2 = .rbp } },
            });
        }
        if (need_save_reg) {
            const save_reg_list = frame_layout.save_reg_list.asInt();
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
        try self.asmOpOnly(.dbg_prologue_end);
        try self.genBody(self.air.getMainBody());
        try self.asmOpOnly(.dbg_epilogue_begin);
    }

    // Drop them off at the rbrace.
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .ops = undefined,
        .data = .{ .line_column = .{
            .line = self.end_di_line,
            .column = self.end_di_column,
        } },
    });
}

fn genBody(self: *Self, body: []const Air.Inst.Index) InnerError!void {
    const air_tags = self.air.instructions.items(.tag);

    for (body) |inst| {
        if (builtin.mode == .Debug) {
            const mir_inst = @intCast(Mir.Inst.Index, self.mir_instructions.len);
            try self.mir_to_air_map.put(self.gpa, mir_inst, inst);
        }

        if (self.liveness.isUnused(inst) and !self.air.mustLower(inst)) continue;
        wip_mir_log.debug("{}", .{self.fmtAir(inst)});
        verbose_tracking_log.debug("{}", .{self.fmtTracking()});

        const old_air_bookkeeping = self.air_bookkeeping;
        try self.inst_tracking.ensureUnusedCapacity(self.gpa, 1);
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
            => try self.airUnaryMath(inst),

            .sqrt => try self.airSqrt(inst),
            .neg, .fabs => try self.airFloatSign(inst),

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
            .store           => try self.airStore(inst, false),
            .store_safe      => try self.airStore(inst, true),
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
            .memset          => try self.airMemset(inst, false),
            .memset_safe     => try self.airMemset(inst, true),
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

            .switch_br       => try self.airSwitchBr(inst),
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
                    const tracking = self.getResolvedInstValue(tracked_inst);
                    assert(RegisterManager.indexOfRegIntoTracked(tracking.getReg().?).? == index);
                }
            }
        }
    }
    verbose_tracking_log.debug("{}", .{self.fmtTracking()});
}

fn genLazy(self: *Self, lazy_sym: link.File.LazySymbol) InnerError!void {
    switch (lazy_sym.ty.zigTypeTag()) {
        .Enum => {
            const enum_ty = lazy_sym.ty;
            wip_mir_log.debug("{}.@tagName:", .{enum_ty.fmt(self.bin_file.options.module.?)});

            const param_regs = abi.getCAbiIntParamRegs(self.target.*);
            const param_locks = self.register_manager.lockRegsAssumeUnused(2, param_regs[0..2].*);
            defer for (param_locks) |lock| self.register_manager.unlockReg(lock);

            const ret_reg = param_regs[0];
            const enum_mcv = MCValue{ .register = param_regs[1] };

            var exitlude_jump_relocs = try self.gpa.alloc(u32, enum_ty.enumFieldCount());
            defer self.gpa.free(exitlude_jump_relocs);

            const data_reg = try self.register_manager.allocReg(null, gp);
            const data_lock = self.register_manager.lockRegAssumeUnused(data_reg);
            defer self.register_manager.unlockReg(data_lock);
            try self.genLazySymbolRef(.lea, data_reg, .{ .kind = .const_data, .ty = enum_ty });

            var data_off: i32 = 0;
            for (
                exitlude_jump_relocs,
                enum_ty.enumFields().keys(),
                0..,
            ) |*exitlude_jump_reloc, tag_name, index| {
                var tag_pl = Value.Payload.U32{
                    .base = .{ .tag = .enum_field_index },
                    .data = @intCast(u32, index),
                };
                const tag_val = Value.initPayload(&tag_pl.base);
                const tag_mcv = try self.genTypedValue(.{ .ty = enum_ty, .val = tag_val });
                try self.genBinOpMir(.cmp, enum_ty, enum_mcv, tag_mcv);
                const skip_reloc = try self.asmJccReloc(undefined, .ne);

                try self.genSetMem(
                    .{ .reg = ret_reg },
                    0,
                    Type.usize,
                    .{ .register_offset = .{ .reg = data_reg, .off = data_off } },
                );
                try self.genSetMem(.{ .reg = ret_reg }, 8, Type.usize, .{ .immediate = tag_name.len });

                exitlude_jump_reloc.* = try self.asmJmpReloc(undefined);
                try self.performReloc(skip_reloc);

                data_off += @intCast(i32, tag_name.len + 1);
            }

            try self.airTrap();

            for (exitlude_jump_relocs) |reloc| try self.performReloc(reloc);
            try self.asmOpOnly(.ret);
        },
        else => return self.fail(
            "TODO implement {s} for {}",
            .{ @tagName(lazy_sym.kind), lazy_sym.ty.fmt(self.bin_file.options.module.?) },
        ),
    }
}

fn getValue(self: *Self, value: MCValue, inst: ?Air.Inst.Index) void {
    const reg = value.getReg() orelse return;
    if (self.register_manager.isRegFree(reg)) {
        self.register_manager.getRegAssumeFree(reg, inst);
    }
}

fn freeValue(self: *Self, value: MCValue) void {
    switch (value) {
        .register => |reg| {
            self.register_manager.freeReg(reg);
        },
        .register_offset => |reg_off| {
            self.register_manager.freeReg(reg_off.reg);
        },
        .register_overflow => |reg_ov| {
            self.register_manager.freeReg(reg_ov.reg);
            self.eflags_inst = null;
        },
        .eflags => {
            self.eflags_inst = null;
        },
        else => {}, // TODO process stack allocation death
    }
}

fn feed(self: *Self, bt: *Liveness.BigTomb, operand: Air.Inst.Ref) void {
    if (bt.feed()) if (Air.refToIndex(operand)) |inst| self.processDeath(inst);
}

/// Asserts there is already capacity to insert into top branch inst_table.
fn processDeath(self: *Self, inst: Air.Inst.Index) void {
    switch (self.air.instructions.items(.tag)[inst]) {
        .constant, .const_ty => unreachable,
        else => self.inst_tracking.getPtr(inst).?.die(self, inst),
    }
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
        self.getValue(result, inst);
    }
    self.finishAirBookkeeping();
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
    self.finishAirResult(inst, result);
}

const FrameLayout = struct {
    stack_mask: u32,
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
    const frame_i = @enumToInt(frame_index);
    if (aligned) {
        const alignment = @as(i32, 1) << self.frame_allocs.items(.abi_align)[frame_i];
        offset.* = mem.alignForwardGeneric(i32, offset.*, alignment);
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
    const frame_offset = self.frame_locs.items(.disp);

    for (stack_frame_order, FrameIndex.named_count..) |*frame_order, frame_index|
        frame_order.* = @intToEnum(FrameIndex, frame_index);
    {
        const SortContext = struct {
            frame_align: @TypeOf(frame_align),
            pub fn lessThan(context: @This(), lhs: FrameIndex, rhs: FrameIndex) bool {
                return context.frame_align[@enumToInt(lhs)] > context.frame_align[@enumToInt(rhs)];
            }
        };
        const sort_context = SortContext{ .frame_align = frame_align };
        std.sort.sort(FrameIndex, stack_frame_order, sort_context, SortContext.lessThan);
    }

    const call_frame_align = frame_align[@enumToInt(FrameIndex.call_frame)];
    const stack_frame_align = frame_align[@enumToInt(FrameIndex.stack_frame)];
    const args_frame_align = frame_align[@enumToInt(FrameIndex.args_frame)];
    const needed_align = @max(call_frame_align, stack_frame_align);
    const need_align_stack = needed_align > args_frame_align;

    // Create list of registers to save in the prologue.
    // TODO handle register classes
    var save_reg_list = Mir.RegisterList{};
    const callee_preserved_regs = abi.getCalleePreservedRegs(self.target.*);
    for (callee_preserved_regs) |reg| {
        if (self.register_manager.isRegAllocated(reg)) {
            save_reg_list.push(callee_preserved_regs, reg);
        }
    }

    var rbp_offset = @intCast(i32, save_reg_list.count() * 8);
    self.setFrameLoc(.base_ptr, .rbp, &rbp_offset, false);
    self.setFrameLoc(.ret_addr, .rbp, &rbp_offset, false);
    self.setFrameLoc(.args_frame, .rbp, &rbp_offset, false);
    const stack_frame_align_offset =
        if (need_align_stack) 0 else frame_offset[@enumToInt(FrameIndex.args_frame)];

    var rsp_offset: i32 = 0;
    self.setFrameLoc(.call_frame, .rsp, &rsp_offset, true);
    self.setFrameLoc(.stack_frame, .rsp, &rsp_offset, true);
    for (stack_frame_order) |frame_index| self.setFrameLoc(frame_index, .rsp, &rsp_offset, true);
    rsp_offset += stack_frame_align_offset;
    rsp_offset = mem.alignForwardGeneric(i32, rsp_offset, @as(i32, 1) << needed_align);
    rsp_offset -= stack_frame_align_offset;
    frame_size[@enumToInt(FrameIndex.call_frame)] =
        @intCast(u31, rsp_offset - frame_offset[@enumToInt(FrameIndex.stack_frame)]);

    return .{
        .stack_mask = @as(u32, math.maxInt(u32)) << (if (need_align_stack) needed_align else 0),
        .stack_adjust = @intCast(u32, rsp_offset - frame_offset[@enumToInt(FrameIndex.call_frame)]),
        .save_reg_list = save_reg_list,
    };
}

fn allocFrameIndex(self: *Self, alloc: FrameAlloc) !FrameIndex {
    const frame_allocs_slice = self.frame_allocs.slice();
    const frame_size = frame_allocs_slice.items(.abi_size);
    const frame_align = frame_allocs_slice.items(.abi_align);

    const stack_frame_align = &frame_align[@enumToInt(FrameIndex.stack_frame)];
    stack_frame_align.* = @max(stack_frame_align.*, alloc.abi_align);

    for (self.free_frame_indices.keys(), 0..) |frame_index, free_i| {
        const abi_size = frame_size[@enumToInt(frame_index)];
        if (abi_size != alloc.abi_size) continue;
        const abi_align = &frame_align[@enumToInt(frame_index)];
        abi_align.* = @max(abi_align.*, alloc.abi_align);

        _ = self.free_frame_indices.swapRemoveAt(free_i);
        return frame_index;
    }
    const frame_index = @intToEnum(FrameIndex, self.frame_allocs.len);
    try self.frame_allocs.append(self.gpa, alloc);
    return frame_index;
}

/// Use a pointer instruction as the basis for allocating stack memory.
fn allocMemPtr(self: *Self, inst: Air.Inst.Index) !FrameIndex {
    const ptr_ty = self.air.typeOfIndex(inst);
    const val_ty = ptr_ty.childType();
    return self.allocFrameIndex(FrameAlloc.init(.{
        .size = math.cast(u32, val_ty.abiSize(self.target.*)) orelse {
            const mod = self.bin_file.options.module.?;
            return self.fail("type '{}' too big to fit into stack frame", .{val_ty.fmt(mod)});
        },
        .alignment = @max(ptr_ty.ptrAlignment(self.target.*), 1),
    }));
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
        // Make sure the type can fit in a register before we try to allocate one.
        const ptr_bits = self.target.cpu.arch.ptrBitWidth();
        const ptr_bytes: u64 = @divExact(ptr_bits, 8);
        if (abi_size <= ptr_bytes) {
            if (self.register_manager.tryAllocReg(inst, regClassForType(elem_ty))) |reg| {
                return MCValue{ .register = registerAlias(reg, abi_size) };
            }
        }
    }

    const frame_index = try self.allocFrameIndex(FrameAlloc.initType(elem_ty, self.target.*));
    return .{ .load_frame = .{ .index = frame_index } };
}

fn regClassForType(ty: Type) RegisterManager.RegisterBitSet {
    return switch (ty.zigTypeTag()) {
        .Float, .Vector => sse,
        else => gp,
    };
}

const State = struct {
    registers: RegisterManager.TrackedRegisters,
    reg_tracking: [RegisterManager.RegisterBitSet.bit_length]InstTracking,
    free_registers: RegisterManager.RegisterBitSet,
    inst_tracking_len: u32,
    scope_generation: u32,
};

fn initRetroactiveState(self: *Self) State {
    var state: State = undefined;
    state.inst_tracking_len = @intCast(u32, self.inst_tracking.count());
    state.scope_generation = self.scope_generation;
    return state;
}

fn saveRetroactiveState(self: *Self, state: *State) !void {
    try self.spillEflagsIfOccupied();
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
        ) |inst, *tracking| tracking.die(self, inst);
        self.inst_tracking.shrinkRetainingCapacity(state.inst_tracking_len);
    }

    if (opts.resurrect) for (
        self.inst_tracking.keys()[0..state.inst_tracking_len],
        self.inst_tracking.values()[0..state.inst_tracking_len],
    ) |inst, *tracking| tracking.resurrect(inst, state.scope_generation);
    for (deaths) |death| self.processDeath(death);

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
                try self.inst_tracking.getPtr(target_inst).?.materialize(
                    self,
                    target_inst,
                    state.reg_tracking[index],
                );
            }
        }
        if (opts.update_tracking) {
            if (current_maybe_inst) |current_inst| {
                self.inst_tracking.getPtr(current_inst).?.trackSpill(self, current_inst);
            }
            {
                const reg = RegisterManager.regAtTrackedIndex(
                    @intCast(RegisterManager.RegisterBitSet.ShiftInt, index),
                );
                self.register_manager.freeReg(reg);
                self.register_manager.getRegAssumeFree(reg, target_maybe_inst);
            }
            if (target_maybe_inst) |target_inst| {
                self.inst_tracking.getPtr(target_inst).?.trackMaterialize(
                    target_inst,
                    state.reg_tracking[index],
                );
            }
        }
    }
    if (opts.emit_instructions) if (self.eflags_inst) |inst|
        try self.inst_tracking.getPtr(inst).?.spill(self, inst);
    if (opts.update_tracking) if (self.eflags_inst) |inst| {
        self.eflags_inst = null;
        self.inst_tracking.getPtr(inst).?.trackSpill(self, inst);
    };

    if (opts.update_tracking and std.debug.runtime_safety) {
        assert(self.eflags_inst == null);
        assert(self.register_manager.free_registers.eql(state.free_registers));
        var used_reg_it = state.free_registers.iterator(.{ .kind = .unset });
        while (used_reg_it.next()) |index|
            assert(self.register_manager.registers[index] == state.registers[index]);
    }
}

pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
    const tracking = self.inst_tracking.getPtr(inst).?;
    assert(tracking.getReg().?.id() == reg.id());
    try tracking.spill(self, inst);
    tracking.trackSpill(self, inst);
}

pub fn spillEflagsIfOccupied(self: *Self) !void {
    if (self.eflags_inst) |inst| {
        self.eflags_inst = null;
        const tracking = self.inst_tracking.getPtr(inst).?;
        assert(tracking.getCondition() != null);
        try tracking.spill(self, inst);
        tracking.trackSpill(self, inst);
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
    const reg = try self.register_manager.allocReg(null, regClassForType(ty));
    try self.genSetReg(reg, ty, mcv);
    return reg;
}

/// Allocates a new register and copies `mcv` into it.
/// `reg_owner` is the instruction that gets associated with the register in the register table.
/// This can have a side effect of spilling instructions to the stack to free up a register.
/// WARNING make sure that the allocated register matches the returned MCValue from an instruction!
fn copyToRegisterWithInstTracking(
    self: *Self,
    reg_owner: Air.Inst.Index,
    ty: Type,
    mcv: MCValue,
) !MCValue {
    const reg: Register = try self.register_manager.allocReg(reg_owner, regClassForType(ty));
    try self.genSetReg(reg, ty, mcv);
    return MCValue{ .register = reg };
}

fn airAlloc(self: *Self, inst: Air.Inst.Index) !void {
    const result = MCValue{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airRetPtr(self: *Self, inst: Air.Inst.Index) !void {
    const result: MCValue = switch (self.ret_mcv.long) {
        else => unreachable,
        .none => .{ .lea_frame = .{ .index = try self.allocMemPtr(inst) } },
        .load_frame => .{ .register_offset = .{
            .reg = (try self.copyToRegisterWithInstTracking(
                inst,
                self.air.typeOfIndex(inst),
                self.ret_mcv.long,
            )).register,
            .off = self.ret_mcv.short.indirect.off,
        } },
    };
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airFptrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dst_ty = self.air.typeOfIndex(inst);
    const src_ty = self.air.typeOf(ty_op.operand);
    if (dst_ty.floatBits(self.target.*) != 32 or src_ty.floatBits(self.target.*) != 64 or
        !Target.x86.featureSetHas(self.target.cpu.features, .sse2))
        return self.fail("TODO implement airFptrunc from {} to {}", .{
            src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
        });

    const src_mcv = try self.resolveInst(ty_op.operand);
    const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
    const dst_lock = self.register_manager.lockReg(dst_mcv.register);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genBinOpMir(.cvtsd2ss, src_ty, dst_mcv, src_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airFpext(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dst_ty = self.air.typeOfIndex(inst);
    const src_ty = self.air.typeOf(ty_op.operand);
    if (dst_ty.floatBits(self.target.*) != 64 or src_ty.floatBits(self.target.*) != 32 or
        !Target.x86.featureSetHas(self.target.cpu.features, .sse2))
        return self.fail("TODO implement airFpext from {} to {}", .{
            src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
        });

    const src_mcv = try self.resolveInst(ty_op.operand);
    const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, ty_op.operand, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, src_mcv);
    const dst_lock = self.register_manager.lockReg(dst_mcv.register);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    try self.genBinOpMir(.cvtss2sd, src_ty, dst_mcv, src_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airIntCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
                .memory, .indirect, .load_frame => try self.asmRegisterMemory(
                    tag,
                    dst_alias,
                    src_mcv.mem(Memory.PtrSize.fromSize(min_abi_size)),
                ),
                else => return self.fail("TODO airIntCast from {s} to {s}", .{
                    @tagName(src_mcv),
                    @tagName(dst_mcv),
                }),
            }
            if (self.regExtraBits(min_ty) > 0) try self.truncateRegister(min_ty, dst_reg);
        },
        else => {
            try self.genCopy(min_ty, dst_mcv, src_mcv);
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
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airTrunc(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airBoolToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ty = self.air.typeOfIndex(inst);

    const operand = try self.resolveInst(un_op);
    const dst_mcv = if (self.reuseOperand(inst, un_op, 0, operand))
        operand
    else
        try self.copyToRegisterWithInstTracking(inst, ty, operand);

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;

    const slice_ty = self.air.typeOfIndex(inst);
    const ptr = try self.resolveInst(bin_op.lhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const len = try self.resolveInst(bin_op.rhs);
    const len_ty = self.air.typeOf(bin_op.rhs);

    const frame_index = try self.allocFrameIndex(FrameAlloc.initType(slice_ty, self.target.*));
    try self.genSetMem(.{ .frame = frame_index }, 0, ptr_ty, ptr);
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(i32, ptr_ty.abiSize(self.target.*)),
        len_ty,
        len,
    );

    const result = MCValue{ .load_frame = .{ .index = frame_index } };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airUnOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dst_mcv = try self.genUnOp(inst, tag, ty_op.operand);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airBinOp(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const dst_mcv = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrArithmetic(self: *Self, inst: Air.Inst.Index, tag: Air.Inst.Tag) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const dst_mcv = try self.genBinOp(inst, tag, bin_op.lhs, bin_op.rhs);
    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
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
    const result = result: {
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

        try self.spillEflagsIfOccupied();
        try self.spillRegisters(&.{ .rax, .rdx });
        const lhs = try self.resolveInst(bin_op.lhs);
        const rhs = try self.resolveInst(bin_op.rhs);
        break :result try self.genMulDivBinOp(tag, inst, dst_ty, src_ty, lhs, rhs);
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
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
        try self.genSetReg(limit_reg, ty, dst_mcv);
        try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
        try self.genBinOpMir(.xor, ty, limit_mcv, .{
            .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
        });
        break :cc .o;
    } else cc: {
        try self.genSetReg(limit_reg, ty, .{
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

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSubSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
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
        try self.genSetReg(limit_reg, ty, dst_mcv);
        try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
        try self.genBinOpMir(.xor, ty, limit_mcv, .{
            .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
        });
        break :cc .o;
    } else cc: {
        try self.genSetReg(limit_reg, ty, .{ .immediate = 0 });
        break :cc .c;
    };
    try self.genBinOpMir(.sub, ty, dst_mcv, rhs_mcv);

    const cmov_abi_size = @max(@intCast(u32, ty.abiSize(self.target.*)), 2);
    try self.asmCmovccRegisterRegister(
        registerAlias(dst_reg, cmov_abi_size),
        registerAlias(limit_reg, cmov_abi_size),
        cc,
    );

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMulSat(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
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
        try self.genSetReg(limit_reg, ty, lhs_mcv);
        try self.genBinOpMir(.xor, ty, limit_mcv, rhs_mcv);
        try self.genShiftBinOpMir(.sar, ty, limit_mcv, .{ .immediate = reg_bits - 1 });
        try self.genBinOpMir(.xor, ty, limit_mcv, .{
            .immediate = (@as(u64, 1) << @intCast(u6, reg_bits - 1)) - 1,
        });
        break :cc .o;
    } else cc: {
        try self.genSetReg(limit_reg, ty, .{
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

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airAddSubWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = result: {
        const tag = self.air.instructions.items(.tag)[inst];
        const ty = self.air.typeOf(bin_op.lhs);
        switch (ty.zigTypeTag()) {
            .Vector => return self.fail("TODO implement add/sub with overflow for Vector type", .{}),
            .Int => {
                try self.spillEflagsIfOccupied();

                const partial_mcv = try self.genBinOp(null, switch (tag) {
                    .add_with_overflow => .add,
                    .sub_with_overflow => .sub,
                    else => unreachable,
                }, bin_op.lhs, bin_op.rhs);
                const int_info = ty.intInfo(self.target.*);
                const cc: Condition = switch (int_info.signedness) {
                    .unsigned => .c,
                    .signed => .o,
                };

                const tuple_ty = self.air.typeOfIndex(inst);
                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*)),
                        Type.u1,
                        .{ .eflags = cc },
                    );
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(i32, tuple_ty.structFieldOffset(0, self.target.*)),
                        ty,
                        partial_mcv,
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                }

                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airShlWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const result: MCValue = result: {
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

                const tuple_ty = self.air.typeOfIndex(inst);
                if (int_info.bits >= 8 and math.isPowerOfTwo(int_info.bits)) {
                    switch (partial_mcv) {
                        .register => |reg| {
                            self.eflags_inst = inst;
                            break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                        },
                        else => {},
                    }

                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*)),
                        tuple_ty.structFieldType(1),
                        .{ .eflags = cc },
                    );
                    try self.genSetMem(
                        .{ .frame = frame_index },
                        @intCast(i32, tuple_ty.structFieldOffset(0, self.target.*)),
                        tuple_ty.structFieldType(0),
                        partial_mcv,
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                }

                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            else => unreachable,
        }
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn genSetFrameTruncatedOverflowCompare(
    self: *Self,
    tuple_ty: Type,
    frame_index: FrameIndex,
    src_mcv: MCValue,
    overflow_cc: ?Condition,
) !void {
    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    const ty = tuple_ty.structFieldType(0);
    const int_info = ty.intInfo(self.target.*);

    var hi_limb_pl = Type.Payload.Bits{
        .base = .{ .tag = switch (int_info.signedness) {
            .signed => .int_signed,
            .unsigned => .int_unsigned,
        } },
        .data = (int_info.bits - 1) % 64 + 1,
    };
    const hi_limb_ty = Type.initPayload(&hi_limb_pl.base);

    var rest_pl = Type.Payload.Bits{
        .base = .{ .tag = .int_unsigned },
        .data = int_info.bits - hi_limb_pl.data,
    };
    const rest_ty = Type.initPayload(&rest_pl.base);

    const temp_regs = try self.register_manager.allocRegs(3, .{ null, null, null }, gp);
    const temp_locks = self.register_manager.lockRegsAssumeUnused(3, temp_regs);
    defer for (temp_locks) |lock| self.register_manager.unlockReg(lock);

    const overflow_reg = temp_regs[0];
    if (overflow_cc) |cc| try self.asmSetccRegister(overflow_reg.to8(), cc);

    const scratch_reg = temp_regs[1];
    const hi_limb_off = if (int_info.bits <= 64) 0 else (int_info.bits - 1) / 64 * 8;
    const hi_limb_mcv = if (hi_limb_off > 0)
        src_mcv.address().offset(int_info.bits / 64 * 8).deref()
    else
        src_mcv;
    try self.genSetReg(scratch_reg, hi_limb_ty, hi_limb_mcv);
    try self.truncateRegister(hi_limb_ty, scratch_reg);
    try self.genBinOpMir(.cmp, hi_limb_ty, .{ .register = scratch_reg }, hi_limb_mcv);

    const eq_reg = temp_regs[2];
    if (overflow_cc) |_| {
        try self.asmSetccRegister(eq_reg.to8(), .ne);
        try self.genBinOpMir(.@"or", Type.u8, .{ .register = overflow_reg }, .{ .register = eq_reg });
    }

    const payload_off = @intCast(i32, tuple_ty.structFieldOffset(0, self.target.*));
    if (hi_limb_off > 0) try self.genSetMem(.{ .frame = frame_index }, payload_off, rest_ty, src_mcv);
    try self.genSetMem(
        .{ .frame = frame_index },
        payload_off + hi_limb_off,
        hi_limb_ty,
        .{ .register = scratch_reg },
    );
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*)),
        tuple_ty.structFieldType(1),
        if (overflow_cc) |_| .{ .register = overflow_reg.to8() } else .{ .eflags = .ne },
    );
}

fn airMulWithOverflow(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const bin_op = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const dst_ty = self.air.typeOf(bin_op.lhs);
    const result: MCValue = switch (dst_ty.zigTypeTag()) {
        .Vector => return self.fail("TODO implement mul_with_overflow for Vector type", .{}),
        .Int => result: {
            try self.spillEflagsIfOccupied();
            try self.spillRegisters(&.{ .rax, .rdx });

            const dst_info = dst_ty.intInfo(self.target.*);
            const cc: Condition = switch (dst_info.signedness) {
                .unsigned => .c,
                .signed => .o,
            };

            const lhs_active_bits = self.activeIntBits(bin_op.lhs);
            const rhs_active_bits = self.activeIntBits(bin_op.rhs);
            var src_pl = Type.Payload.Bits{ .base = .{ .tag = switch (dst_info.signedness) {
                .signed => .int_signed,
                .unsigned => .int_unsigned,
            } }, .data = math.max3(lhs_active_bits, rhs_active_bits, dst_info.bits / 2) };
            const src_ty = Type.initPayload(&src_pl.base);

            const lhs = try self.resolveInst(bin_op.lhs);
            const rhs = try self.resolveInst(bin_op.rhs);

            const tuple_ty = self.air.typeOfIndex(inst);
            const extra_bits = if (dst_info.bits <= 64)
                self.regExtraBits(dst_ty)
            else
                dst_info.bits % 64;
            const partial_mcv = if (dst_info.signedness == .signed and extra_bits > 0) dst: {
                const rhs_lock: ?RegisterLock = switch (rhs) {
                    .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
                    else => null,
                };
                defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                const dst_reg: Register = blk: {
                    if (lhs.isRegister()) break :blk lhs.register;
                    break :blk try self.copyToTmpRegister(dst_ty, lhs);
                };
                const dst_mcv = MCValue{ .register = dst_reg };
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

                try self.genIntMulComplexOpMir(Type.isize, dst_mcv, rhs_mcv);
                break :dst dst_mcv;
            } else try self.genMulDivBinOp(.mul, null, dst_ty, src_ty, lhs, rhs);

            switch (partial_mcv) {
                .register => |reg| if (extra_bits == 0) {
                    self.eflags_inst = inst;
                    break :result .{ .register_overflow = .{ .reg = reg, .eflags = cc } };
                } else {
                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                    try self.genSetFrameTruncatedOverflowCompare(tuple_ty, frame_index, partial_mcv, cc);
                    break :result .{ .load_frame = .{ .index = frame_index } };
                },
                else => {
                    // For now, this is the only supported multiply that doesn't fit in a register,
                    // so cc being set is impossible.

                    assert(dst_info.bits <= 128 and src_pl.data == 64);

                    const frame_index =
                        try self.allocFrameIndex(FrameAlloc.initType(tuple_ty, self.target.*));
                    if (dst_info.bits >= lhs_active_bits + rhs_active_bits) {
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            @intCast(i32, tuple_ty.structFieldOffset(0, self.target.*)),
                            tuple_ty.structFieldType(0),
                            partial_mcv,
                        );
                        try self.genSetMem(
                            .{ .frame = frame_index },
                            @intCast(i32, tuple_ty.structFieldOffset(1, self.target.*)),
                            tuple_ty.structFieldType(1),
                            .{ .immediate = 0 },
                        );
                    } else try self.genSetFrameTruncatedOverflowCompare(
                        tuple_ty,
                        frame_index,
                        partial_mcv,
                        null,
                    );
                    break :result .{ .load_frame = .{ .index = frame_index } };
                },
            }
        },
        else => unreachable,
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

    try self.genSetReg(.rax, ty, lhs);
    switch (tag) {
        else => unreachable,
        .mul, .imul => {},
        .div => try self.asmRegisterRegister(.xor, .edx, .edx),
        .idiv => switch (self.regBitSize(ty)) {
            8 => try self.asmOpOnly(.cbw),
            16 => try self.asmOpOnly(.cwd),
            32 => try self.asmOpOnly(.cdq),
            64 => try self.asmOpOnly(.cqo),
            else => unreachable,
        },
    }

    const mat_rhs: MCValue = switch (rhs) {
        .register, .indirect, .load_frame => rhs,
        else => .{ .register = try self.copyToTmpRegister(ty, rhs) },
    };
    switch (mat_rhs) {
        .register => |reg| try self.asmRegister(tag, registerAlias(reg, abi_size)),
        .memory, .indirect, .load_frame => try self.asmMemory(
            tag,
            mat_rhs.mem(Memory.PtrSize.fromSize(abi_size)),
        ),
        else => unreachable,
    }
}

/// Always returns a register.
/// Clobbers .rax and .rdx registers.
fn genInlineIntDivFloor(self: *Self, ty: Type, lhs: MCValue, rhs: MCValue) !MCValue {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    const int_info = ty.intInfo(self.target.*);
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

    try self.genIntMulDivOpMir(switch (int_info.signedness) {
        .signed => .idiv,
        .unsigned => .div,
    }, ty, .{ .register = dividend }, .{ .register = divisor });

    try self.asmRegisterRegister(
        .xor,
        registerAlias(divisor, abi_size),
        registerAlias(dividend, abi_size),
    );
    try self.asmRegisterImmediate(
        .sar,
        registerAlias(divisor, abi_size),
        Immediate.u(int_info.bits - 1),
    );
    try self.asmRegisterRegister(
        .@"test",
        registerAlias(.rdx, abi_size),
        registerAlias(.rdx, abi_size),
    );
    try self.asmCmovccRegisterRegister(
        registerAlias(divisor, abi_size),
        registerAlias(.rdx, abi_size),
        .z,
    );
    try self.genBinOpMir(.add, ty, .{ .register = divisor }, .{ .register = .rax });
    return MCValue{ .register = divisor };
}

fn airShlShrBinOp(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

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
    _ = bin_op;
    return self.fail("TODO implement shl_sat for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airOptionalPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result: MCValue = result: {
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
        try self.genCopy(pl_ty, pl_mcv, switch (opt_mcv) {
            else => opt_mcv,
            .register_overflow => |ro| .{ .register = ro.reg },
        });
        break :result pl_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airOptionalPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const dst_ty = self.air.typeOfIndex(inst);
    const opt_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
        opt_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
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
                .unreach
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
        try self.genSetMem(.{ .reg = dst_mcv.register }, pl_abi_size, Type.bool, .{ .immediate = 1 });
        break :result if (self.liveness.isUnused(inst)) .unreach else dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
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
            .load_frame => |frame_addr| break :result .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + @intCast(i32, err_off),
            } },
            else => return self.fail("TODO implement unwrap_err_err for {}", .{operand}),
        }
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airUnwrapErrUnionPayload(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
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
            .load_frame => |frame_addr| break :result .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + @intCast(i32, payload_off),
            } },
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

    const src_ty = self.air.typeOf(ty_op.operand);
    const src_mcv = try self.resolveInst(ty_op.operand);
    const src_reg = switch (src_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(src_ty, src_mcv),
    };
    const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
    defer self.register_manager.unlockReg(src_lock);

    const dst_reg = try self.register_manager.allocReg(inst, gp);
    const dst_mcv = MCValue{ .register = dst_reg };
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
        Memory.sib(Memory.PtrSize.fromSize(err_abi_size), .{
            .base = .{ .reg = src_reg },
            .disp = err_off,
        }),
    );

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

// *(E!T) -> *T
fn airUnwrapErrUnionPayloadPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const eu_ty = src_ty.childType();
    const pl_ty = eu_ty.errorUnionPayload();
    const pl_off = @intCast(i32, errUnionPayloadOffset(pl_ty, self.target.*));
    const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    try self.asmRegisterMemory(
        .lea,
        registerAlias(dst_reg, dst_abi_size),
        Memory.sib(.qword, .{ .base = .{ .reg = src_reg }, .disp = pl_off }),
    );

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
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
            Memory.sib(Memory.PtrSize.fromSize(err_abi_size), .{
                .base = .{ .reg = src_reg },
                .disp = err_off,
            }),
            Immediate.u(0),
        );

        if (self.liveness.isUnused(inst)) break :result .unreach;

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
            Memory.sib(.qword, .{ .base = .{ .reg = src_reg }, .disp = pl_off }),
        );
        break :result .{ .register = dst_reg };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airErrReturnTrace(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airErrReturnTrace for {}", .{self.target.cpu.arch});
    //return self.finishAir(inst, result, .{ .none, .none, .none });
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
        try self.genCopy(pl_ty, opt_mcv, pl_mcv);

        if (!same_repr) {
            const pl_abi_size = @intCast(i32, pl_ty.abiSize(self.target.*));
            switch (opt_mcv) {
                else => unreachable,

                .register => |opt_reg| try self.asmRegisterImmediate(
                    .bts,
                    opt_reg,
                    Immediate.u(@intCast(u6, pl_abi_size * 8)),
                ),

                .load_frame => |frame_addr| try self.asmMemoryImmediate(
                    .mov,
                    Memory.sib(.byte, .{
                        .base = .{ .frame = frame_addr.index },
                        .disp = frame_addr.off + pl_abi_size,
                    }),
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

    const eu_ty = self.air.getRefType(ty_op.ty);
    const pl_ty = eu_ty.errorUnionPayload();
    const err_ty = eu_ty.errorUnionSet();
    const operand = try self.resolveInst(ty_op.operand);

    const result: MCValue = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime()) break :result .{ .immediate = 0 };

        const frame_index = try self.allocFrameIndex(FrameAlloc.initType(eu_ty, self.target.*));
        const pl_off = @intCast(i32, errUnionPayloadOffset(pl_ty, self.target.*));
        const err_off = @intCast(i32, errUnionErrorOffset(pl_ty, self.target.*));
        try self.genSetMem(.{ .frame = frame_index }, pl_off, pl_ty, operand);
        try self.genSetMem(.{ .frame = frame_index }, err_off, err_ty, .{ .immediate = 0 });
        break :result .{ .load_frame = .{ .index = frame_index } };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

/// E to E!T
fn airWrapErrUnionErr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const eu_ty = self.air.getRefType(ty_op.ty);
    const pl_ty = eu_ty.errorUnionPayload();
    const err_ty = eu_ty.errorUnionSet();

    const result: MCValue = result: {
        if (!pl_ty.hasRuntimeBitsIgnoreComptime()) break :result try self.resolveInst(ty_op.operand);

        const frame_index = try self.allocFrameIndex(FrameAlloc.initType(eu_ty, self.target.*));
        const pl_off = @intCast(i32, errUnionPayloadOffset(pl_ty, self.target.*));
        const err_off = @intCast(i32, errUnionErrorOffset(pl_ty, self.target.*));
        try self.genSetMem(.{ .frame = frame_index }, pl_off, pl_ty, .undef);
        const operand = try self.resolveInst(ty_op.operand);
        try self.genSetMem(.{ .frame = frame_index }, err_off, err_ty, operand);
        break :result .{ .load_frame = .{ .index = frame_index } };
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSlicePtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
        const src_mcv = try self.resolveInst(ty_op.operand);
        if (self.reuseOperand(inst, ty_op.operand, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.air.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSliceLen(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const operand = try self.resolveInst(ty_op.operand);
    const dst_mcv: MCValue = blk: {
        switch (operand) {
            .load_frame => |frame_addr| break :blk .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + 8,
            } },
            else => return self.fail("TODO implement slice_len for {}", .{operand}),
        }
    };

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airPtrSliceLenPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockReg(dst_reg);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const dst_abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    try self.asmRegisterMemory(
        .lea,
        registerAlias(dst_reg, dst_abi_size),
        Memory.sib(.qword, .{
            .base = .{ .reg = src_reg },
            .disp = @divExact(self.target.cpu.arch.ptrBitWidth(), 8),
        }),
    );

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airPtrSlicePtrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const dst_ty = self.air.typeOfIndex(inst);
    const opt_mcv = try self.resolveInst(ty_op.operand);

    const dst_mcv = if (self.reuseOperand(inst, ty_op.operand, 0, opt_mcv))
        opt_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, dst_ty, opt_mcv);
    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn elemOffset(self: *Self, index_ty: Type, index: MCValue, elem_size: u64) !Register {
    const reg: Register = blk: {
        switch (index) {
            .immediate => |imm| {
                // Optimisation: if index MCValue is an immediate, we can multiply in `comptime`
                // and set the register directly to the scaled offset as an immediate.
                const reg = try self.register_manager.allocReg(null, gp);
                try self.genSetReg(reg, index_ty, .{ .immediate = imm * elem_size });
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
    try self.genSetReg(addr_reg, Type.usize, slice_mcv);
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

    var buf: Type.SlicePtrFieldTypeBuffer = undefined;
    const slice_ptr_field_type = slice_ty.slicePtrFieldType(&buf);
    const elem_ptr = try self.genSliceElemPtr(bin_op.lhs, bin_op.rhs);
    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.load(dst_mcv, slice_ptr_field_type, elem_ptr);

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airSliceElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;
    const dst_mcv = try self.genSliceElemPtr(extra.lhs, extra.rhs);
    return self.finishAir(inst, dst_mcv, .{ extra.lhs, extra.rhs, .none });
}

fn airArrayElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

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

    const addr_reg = try self.register_manager.allocReg(null, gp);
    switch (array) {
        .register => {
            const frame_index = try self.allocFrameIndex(FrameAlloc.initType(array_ty, self.target.*));
            try self.genSetMem(.{ .frame = frame_index }, 0, array_ty, array);
            try self.asmRegisterMemory(
                .lea,
                addr_reg,
                Memory.sib(.qword, .{ .base = .{ .frame = frame_index } }),
            );
        },
        .load_frame => |frame_addr| try self.asmRegisterMemory(
            .lea,
            addr_reg,
            Memory.sib(.qword, .{ .base = .{ .frame = frame_addr.index }, .disp = frame_addr.off }),
        ),
        .memory,
        .load_direct,
        .load_got,
        .load_tlv,
        => try self.genSetReg(addr_reg, Type.usize, array.address()),
        .lea_direct, .lea_tlv => unreachable,
        else => return self.fail("TODO implement array_elem_val when array is {}", .{array}),
    }

    // TODO we could allocate register here, but need to expect addr register and potentially
    // offset register.
    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.genBinOpMir(.add, Type.usize, .{ .register = addr_reg }, .{ .register = offset_reg });
    try self.genCopy(elem_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } });

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemVal(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_ty = self.air.typeOf(bin_op.lhs);

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
    try self.load(dst_mcv, ptr_ty, .{ .register = elem_ptr_reg });

    return self.finishAir(inst, dst_mcv, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airPtrElemPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Bin, ty_pl.payload).data;

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

    return self.finishAir(inst, dst_mcv, .{ extra.lhs, extra.rhs, .none });
}

fn airSetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_union_ty = self.air.typeOf(bin_op.lhs);
    const union_ty = ptr_union_ty.childType();
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
        const reg = try self.copyToTmpRegister(ptr_union_ty, ptr);
        try self.genBinOpMir(.add, ptr_union_ty, .{ .register = reg }, .{ .immediate = layout.payload_size });
        break :blk MCValue{ .register = reg };
    } else ptr;

    var ptr_tag_pl = ptr_union_ty.ptrInfo();
    ptr_tag_pl.data.pointee_type = tag_ty;
    const ptr_tag_ty = Type.initPayload(&ptr_tag_pl.base);
    try self.store(ptr_tag_ty, adjusted_ptr, tag);

    return self.finishAir(inst, .none, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airGetUnionTag(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
            .load_frame => |frame_addr| {
                if (tag_abi_size <= 8) {
                    const off: i32 = if (layout.tag_align < layout.payload_align)
                        @intCast(i32, layout.payload_size)
                    else
                        0;
                    break :blk try self.copyToRegisterWithInstTracking(inst, tag_ty, .{
                        .load_frame = .{ .index = frame_addr.index, .off = frame_addr.off + off },
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

            try self.genSetReg(dst_reg, dst_ty, .{ .immediate = src_bits - 1 });
            try self.genBinOpMir(.sub, dst_ty, dst_mcv, .{ .register = imm_reg });
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airCtz(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const result = result: {
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
                    try self.genSetReg(dst_reg, src_ty, src_mcv);
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

            try self.genSetReg(dst_mcv.register, src_ty, src_mcv);
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

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airBitReverse(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
                .base = .{ .reg = dst.to64() },
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
                .base = .{ .reg = tmp.to64() },
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

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airFloatSign(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ty = self.air.typeOf(un_op);
    const ty_bits = ty.floatBits(self.target.*);

    var arena = std.heap.ArenaAllocator.init(self.gpa);
    defer arena.deinit();

    const ExpectedContents = union {
        f16: Value.Payload.Float_16,
        f32: Value.Payload.Float_32,
        f64: Value.Payload.Float_64,
        f80: Value.Payload.Float_80,
        f128: Value.Payload.Float_128,
    };
    var stack align(@alignOf(ExpectedContents)) =
        std.heap.stackFallback(@sizeOf(ExpectedContents), arena.allocator());

    var vec_pl = Type.Payload.Array{
        .base = .{ .tag = .vector },
        .data = .{
            .len = @divExact(128, ty_bits),
            .elem_type = ty,
        },
    };
    const vec_ty = Type.initPayload(&vec_pl.base);

    var sign_pl = Value.Payload.SubValue{
        .base = .{ .tag = .repeated },
        .data = try Value.floatToValue(-0.0, stack.get(), ty, self.target.*),
    };
    const sign_val = Value.initPayload(&sign_pl.base);

    const sign_mcv = try self.genTypedValue(.{ .ty = vec_ty, .val = sign_val });

    const src_mcv = try self.resolveInst(un_op);
    const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, un_op, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);
    const dst_lock = self.register_manager.lockReg(dst_mcv.register);
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const tag = self.air.instructions.items(.tag)[inst];
    try self.genBinOpMir(switch (ty_bits) {
        // No point using an extra prefix byte for *pd which performs the same operation.
        32, 64 => switch (tag) {
            .neg => .xorps,
            .fabs => .andnps,
            else => unreachable,
        },
        else => return self.fail("TODO implement airFloatSign for {}", .{
            ty.fmt(self.bin_file.options.module.?),
        }),
    }, vec_ty, dst_mcv, sign_mcv);
    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airSqrt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ty = self.air.typeOf(un_op);

    const src_mcv = try self.resolveInst(un_op);
    const dst_mcv = if (src_mcv.isRegister() and self.reuseOperand(inst, un_op, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, ty, src_mcv);

    try self.genBinOpMir(switch (ty.zigTypeTag()) {
        .Float => switch (ty.floatBits(self.target.*)) {
            32 => .sqrtss,
            64 => .sqrtsd,
            else => return self.fail("TODO implement airSqrt for {}", .{
                ty.fmt(self.bin_file.options.module.?),
            }),
        },
        else => return self.fail("TODO implement airSqrt for {}", .{
            ty.fmt(self.bin_file.options.module.?),
        }),
    }, ty, dst_mcv, src_mcv);
    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airUnaryMath(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    _ = un_op;
    return self.fail("TODO implement airUnaryMath for {}", .{
        self.air.instructions.items(.tag)[inst],
    });
    //return self.finishAir(inst, result, .{ un_op, .none, .none });
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
    tracked_inst: Air.Inst.Index,
) bool {
    if (!self.liveness.operandDies(inst, op_index))
        return false;

    switch (mcv) {
        .register => |reg| {
            // If it's in the registers table, need to associate the register with the
            // new instruction.
            if (!self.register_manager.isRegFree(reg)) {
                if (RegisterManager.indexOfRegIntoTracked(reg)) |index| {
                    self.register_manager.registers[index] = tracked_inst;
                }
            }
        },
        .load_frame => |frame_addr| if (frame_addr.index.isNamed()) return false,
        else => return false,
    }

    // Prevent the operand deaths processing code from deallocating it.
    self.liveness.clearOperandDeath(inst, op_index);
    const op_inst = Air.refToIndex(operand).?;
    self.getResolvedInstValue(op_inst).reuse(self, tracked_inst, op_inst);

    return true;
}

fn packedLoad(self: *Self, dst_mcv: MCValue, ptr_ty: Type, ptr_mcv: MCValue) InnerError!void {
    const ptr_info = ptr_ty.ptrInfo().data;

    const val_ty = ptr_info.pointee_type;
    const val_abi_size = @intCast(u32, val_ty.abiSize(self.target.*));
    const limb_abi_size: u32 = @min(val_abi_size, 8);
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
        try self.asmRegisterMemory(
            .mov,
            load_reg,
            Memory.sib(Memory.PtrSize.fromSize(load_abi_size), .{
                .base = .{ .reg = ptr_reg },
                .disp = val_byte_off,
            }),
        );
        try self.asmRegisterImmediate(.shr, load_reg, Immediate.u(val_bit_off));
    } else {
        const tmp_reg = registerAlias(try self.register_manager.allocReg(null, gp), val_abi_size);
        const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
        defer self.register_manager.unlockReg(tmp_lock);

        const dst_alias = registerAlias(dst_reg, val_abi_size);
        try self.asmRegisterMemory(
            .mov,
            dst_alias,
            Memory.sib(Memory.PtrSize.fromSize(val_abi_size), .{
                .base = .{ .reg = ptr_reg },
                .disp = val_byte_off,
            }),
        );
        try self.asmRegisterMemory(
            .mov,
            tmp_reg,
            Memory.sib(Memory.PtrSize.fromSize(val_abi_size), .{
                .base = .{ .reg = ptr_reg },
                .disp = val_byte_off + 1,
            }),
        );
        try self.asmRegisterRegisterImmediate(.shrd, dst_alias, tmp_reg, Immediate.u(val_bit_off));
    }

    if (val_extra_bits > 0) try self.truncateRegister(val_ty, dst_reg);
    try self.genCopy(val_ty, dst_mcv, .{ .register = dst_reg });
}

fn load(self: *Self, dst_mcv: MCValue, ptr_ty: Type, ptr_mcv: MCValue) InnerError!void {
    const dst_ty = ptr_ty.childType();
    switch (ptr_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .eflags,
        .register_overflow,
        .reserved_frame,
        => unreachable, // not a valid pointer
        .immediate,
        .register,
        .register_offset,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        => try self.genCopy(dst_ty, dst_mcv, ptr_mcv.deref()),
        .memory,
        .indirect,
        .load_direct,
        .load_got,
        .load_tlv,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(dst_ty, dst_mcv, .{ .indirect = .{ .reg = addr_reg } });
        },
    }
}

fn airLoad(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const elem_ty = self.air.typeOfIndex(inst);
    const result: MCValue = result: {
        if (!elem_ty.hasRuntimeBitsIgnoreComptime()) break :result .none;

        try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
        const reg_locks = self.register_manager.lockRegsAssumeUnused(3, .{ .rdi, .rsi, .rcx });
        defer for (reg_locks) |lock| self.register_manager.unlockReg(lock);

        const ptr_ty = self.air.typeOf(ty_op.operand);
        const elem_size = elem_ty.abiSize(self.target.*);

        const elem_rc = regClassForType(elem_ty);
        const ptr_rc = regClassForType(ptr_ty);

        const ptr_mcv = try self.resolveInst(ty_op.operand);
        const dst_mcv = if (elem_size <= 8 and elem_rc.supersetOf(ptr_rc) and
            self.reuseOperand(inst, ty_op.operand, 0, ptr_mcv))
            // The MCValue that holds the pointer can be re-used as the value.
            ptr_mcv
        else
            try self.allocRegOrMem(inst, true);

        if (ptr_ty.ptrInfo().data.host_size > 0) {
            try self.packedLoad(dst_mcv, ptr_ty, ptr_mcv);
        } else {
            try self.load(dst_mcv, ptr_ty, ptr_mcv);
        }
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn packedStore(self: *Self, ptr_ty: Type, ptr_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const ptr_info = ptr_ty.ptrInfo().data;
    const src_ty = ptr_ty.childType();

    const limb_abi_size: u16 = @min(ptr_info.host_size, 8);
    const limb_abi_bits = limb_abi_size * 8;

    const src_bit_size = src_ty.bitSize(self.target.*);
    const src_byte_off = @intCast(i32, ptr_info.bit_offset / limb_abi_bits * limb_abi_size);
    const src_bit_off = ptr_info.bit_offset % limb_abi_bits;

    const ptr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
    const ptr_lock = self.register_manager.lockRegAssumeUnused(ptr_reg);
    defer self.register_manager.unlockReg(ptr_lock);

    var limb_i: u16 = 0;
    while (limb_i * limb_abi_bits < src_bit_off + src_bit_size) : (limb_i += 1) {
        const part_bit_off = if (limb_i == 0) src_bit_off else 0;
        const part_bit_size =
            @min(src_bit_off + src_bit_size - limb_i * limb_abi_bits, limb_abi_bits) - part_bit_off;
        const limb_mem = Memory.sib(Memory.PtrSize.fromSize(limb_abi_size), .{
            .base = .{ .reg = ptr_reg },
            .disp = src_byte_off + limb_i * limb_abi_bits,
        });

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

        if (src_bit_size <= 64) {
            const tmp_reg = try self.register_manager.allocReg(null, gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genSetReg(tmp_reg, src_ty, src_mcv);
            switch (limb_i) {
                0 => try self.genShiftBinOpMir(.shl, src_ty, tmp_mcv, .{ .immediate = src_bit_off }),
                1 => try self.genShiftBinOpMir(.shr, src_ty, tmp_mcv, .{
                    .immediate = limb_abi_bits - src_bit_off,
                }),
                else => unreachable,
            }
            try self.genBinOpMir(.@"and", src_ty, tmp_mcv, .{ .immediate = part_mask });
            try self.asmMemoryRegister(.@"or", limb_mem, registerAlias(tmp_reg, limb_abi_size));
        } else return self.fail("TODO: implement packed store of {}", .{
            src_ty.fmt(self.bin_file.options.module.?),
        });
    }
}

fn store(self: *Self, ptr_ty: Type, ptr_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const src_ty = ptr_ty.childType();
    switch (ptr_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .eflags,
        .register_overflow,
        .reserved_frame,
        => unreachable, // not a valid pointer
        .immediate,
        .register,
        .register_offset,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        => try self.genCopy(src_ty, ptr_mcv.deref(), src_mcv),
        .memory,
        .indirect,
        .load_direct,
        .load_got,
        .load_tlv,
        .load_frame,
        => {
            const addr_reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv);
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genCopy(src_ty, .{ .indirect = .{ .reg = addr_reg } }, src_mcv);
        },
    }
}

fn airStore(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
    const ptr_mcv = try self.resolveInst(bin_op.lhs);
    const ptr_ty = self.air.typeOf(bin_op.lhs);
    const src_mcv = try self.resolveInst(bin_op.rhs);
    if (ptr_ty.ptrInfo().data.host_size > 0) {
        try self.packedStore(ptr_ty, ptr_mcv, src_mcv);
    } else {
        try self.store(ptr_ty, ptr_mcv, src_mcv);
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
    const ptr_field_ty = self.air.typeOfIndex(inst);
    const mcv = try self.resolveInst(operand);
    const ptr_container_ty = self.air.typeOf(operand);
    const container_ty = ptr_container_ty.childType();
    const field_offset = switch (container_ty.containerLayout()) {
        .Auto, .Extern => @intCast(u32, container_ty.structFieldOffset(index, self.target.*)),
        .Packed => if (container_ty.zigTypeTag() == .Struct and
            ptr_field_ty.ptrInfo().data.host_size == 0)
            container_ty.packedStructFieldByteOffset(index, self.target.*)
        else
            0,
    };

    const result: MCValue = result: {
        switch (mcv) {
            .load_frame, .lea_tlv, .load_tlv => {
                const offset_reg = try self.copyToTmpRegister(Type.usize, .{
                    .immediate = field_offset,
                });
                const offset_reg_lock = self.register_manager.lockRegAssumeUnused(offset_reg);
                defer self.register_manager.unlockReg(offset_reg_lock);

                const dst_mcv = try self.copyToRegisterWithInstTracking(inst, Type.usize, switch (mcv) {
                    .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
                    else => mcv,
                });
                try self.genBinOpMir(.add, Type.usize, dst_mcv, .{ .register = offset_reg });
                break :result dst_mcv;
            },
            .indirect => |reg_off| break :result .{ .indirect = .{
                .reg = reg_off.reg,
                .off = reg_off.off + @intCast(i32, field_offset),
            } },
            .lea_frame => |frame_addr| break :result .{ .lea_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + @intCast(i32, field_offset),
            } },
            .register, .register_offset => {
                const src_reg = mcv.getReg().?;
                const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_lock);

                const dst_mcv: MCValue = if (self.reuseOperand(inst, operand, 0, mcv))
                    mcv
                else
                    .{ .register = try self.copyToTmpRegister(ptr_field_ty, mcv) };
                break :result .{ .register_offset = .{
                    .reg = dst_mcv.getReg().?,
                    .off = switch (dst_mcv) {
                        .register => 0,
                        .register_offset => |reg_off| reg_off.off,
                        else => unreachable,
                    } + @intCast(i32, field_offset),
                } };
            },
            else => return self.fail("TODO implement fieldPtr for {}", .{mcv}),
        }
    };
    return result;
}

fn airStructFieldVal(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.StructField, ty_pl.payload).data;
    const result: MCValue = result: {
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
            .load_frame => |frame_addr| {
                if (field_off % 8 == 0) {
                    const off_mcv =
                        src_mcv.address().offset(@intCast(i32, @divExact(field_off, 8))).deref();
                    if (self.reuseOperand(inst, operand, 0, src_mcv)) break :result off_mcv;

                    const dst_mcv = try self.allocRegOrMem(inst, true);
                    try self.genCopy(field_ty, dst_mcv, off_mcv);
                    break :result dst_mcv;
                }

                const field_abi_size = @intCast(u32, field_ty.abiSize(self.target.*));
                const limb_abi_size: u32 = @min(field_abi_size, 8);
                const limb_abi_bits = limb_abi_size * 8;
                const field_byte_off = @intCast(i32, field_off / limb_abi_bits * limb_abi_size);
                const field_bit_off = field_off % limb_abi_bits;

                if (field_abi_size > 8) {
                    return self.fail("TODO implement struct_field_val with large packed field", .{});
                }

                const dst_reg = try self.register_manager.allocReg(inst, gp);
                const field_extra_bits = self.regExtraBits(field_ty);
                const load_abi_size =
                    if (field_bit_off < field_extra_bits) field_abi_size else field_abi_size * 2;
                if (load_abi_size <= 8) {
                    const load_reg = registerAlias(dst_reg, load_abi_size);
                    try self.asmRegisterMemory(
                        .mov,
                        load_reg,
                        Memory.sib(Memory.PtrSize.fromSize(load_abi_size), .{
                            .base = .{ .frame = frame_addr.index },
                            .disp = frame_addr.off + field_byte_off,
                        }),
                    );
                    try self.asmRegisterImmediate(.shr, load_reg, Immediate.u(field_bit_off));
                } else {
                    const tmp_reg = registerAlias(
                        try self.register_manager.allocReg(null, gp),
                        field_abi_size,
                    );
                    const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
                    defer self.register_manager.unlockReg(tmp_lock);

                    const dst_alias = registerAlias(dst_reg, field_abi_size);
                    try self.asmRegisterMemory(
                        .mov,
                        dst_alias,
                        Memory.sib(Memory.PtrSize.fromSize(field_abi_size), .{
                            .base = .{ .frame = frame_addr.index },
                            .disp = frame_addr.off + field_byte_off,
                        }),
                    );
                    try self.asmRegisterMemory(
                        .mov,
                        tmp_reg,
                        Memory.sib(Memory.PtrSize.fromSize(field_abi_size), .{
                            .base = .{ .frame = frame_addr.index },
                            .disp = frame_addr.off + field_byte_off + @intCast(i32, limb_abi_size),
                        }),
                    );
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
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.FieldParentPtr, ty_pl.payload).data;

    const inst_ty = self.air.typeOfIndex(inst);
    const parent_ty = inst_ty.childType();
    const field_offset = @intCast(i32, parent_ty.structFieldOffset(extra.field_index, self.target.*));

    const src_mcv = try self.resolveInst(extra.field_ptr);
    const dst_mcv = if (src_mcv.isRegisterOffset() and
        self.reuseOperand(inst, extra.field_ptr, 0, src_mcv))
        src_mcv
    else
        try self.copyToRegisterWithInstTracking(inst, inst_ty, src_mcv);
    const result = dst_mcv.offset(-field_offset);
    return self.finishAir(inst, result, .{ extra.field_ptr, .none, .none });
}

fn genUnOp(self: *Self, maybe_inst: ?Air.Inst.Index, tag: Air.Inst.Tag, src_air: Air.Inst.Ref) !MCValue {
    const src_ty = self.air.typeOf(src_air);
    const src_mcv = try self.resolveInst(src_air);
    if (src_ty.zigTypeTag() == .Vector) {
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

    const dst_mcv: MCValue = dst: {
        if (maybe_inst) |inst| if (self.reuseOperand(inst, src_air, 0, src_mcv)) break :dst src_mcv;

        const dst_mcv = try self.allocRegOrMemAdvanced(src_ty, maybe_inst, true);
        try self.genCopy(src_ty, dst_mcv, src_mcv);
        break :dst dst_mcv;
    };
    const dst_lock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    switch (tag) {
        .not => {
            const limb_abi_size = @intCast(u16, @min(src_ty.abiSize(self.target.*), 8));
            const int_info = if (src_ty.tag() == .bool)
                std.builtin.Type.Int{ .signedness = .unsigned, .bits = 1 }
            else
                src_ty.intInfo(self.target.*);
            var byte_off: i32 = 0;
            while (byte_off * 8 < int_info.bits) : (byte_off += limb_abi_size) {
                var limb_pl = Type.Payload.Bits{
                    .base = .{ .tag = switch (int_info.signedness) {
                        .signed => .int_signed,
                        .unsigned => .int_unsigned,
                    } },
                    .data = @intCast(u16, @min(int_info.bits - byte_off * 8, limb_abi_size * 8)),
                };
                const limb_ty = Type.initPayload(&limb_pl.base);
                const limb_mcv = switch (byte_off) {
                    0 => dst_mcv,
                    else => dst_mcv.address().offset(byte_off).deref(),
                };

                if (limb_pl.base.tag == .int_unsigned and self.regExtraBits(limb_ty) > 0) {
                    const mask = @as(u64, math.maxInt(u64)) >> @intCast(u6, 64 - limb_pl.data);
                    try self.genBinOpMir(.xor, limb_ty, limb_mcv, .{ .immediate = mask });
                } else try self.genUnOpMir(.not, limb_ty, limb_mcv);
            }
        },
        .neg => try self.genUnOpMir(.neg, src_ty, dst_mcv),
        else => unreachable,
    }
    return dst_mcv;
}

fn genUnOpMir(self: *Self, mir_tag: Mir.Inst.Tag, dst_ty: Type, dst_mcv: MCValue) !void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    if (abi_size > 8) return self.fail("TODO implement {} for {}", .{
        mir_tag,
        dst_ty.fmt(self.bin_file.options.module.?),
    });
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .register_offset,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .reserved_frame,
        => unreachable, // unmodifiable destination
        .register => |dst_reg| try self.asmRegister(mir_tag, registerAlias(dst_reg, abi_size)),
        .memory, .load_got, .load_direct, .load_tlv => {
            const addr_reg = try self.register_manager.allocReg(null, gp);
            const addr_reg_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_reg_lock);

            try self.genSetReg(addr_reg, Type.usize, dst_mcv.address());
            try self.asmMemory(
                mir_tag,
                Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = .{ .reg = addr_reg } }),
            );
        },
        .indirect, .load_frame => try self.asmMemory(
            mir_tag,
            dst_mcv.mem(Memory.PtrSize.fromSize(abi_size)),
        ),
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
        try self.genSetReg(.cl, Type.u8, shift_mcv);
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
            .memory, .indirect, .load_frame => {
                const lhs_mem = Memory.sib(Memory.PtrSize.fromSize(abi_size), switch (lhs_mcv) {
                    .memory => |addr| .{
                        .base = .{ .reg = .ds },
                        .disp = math.cast(i32, @bitCast(i64, addr)) orelse
                            return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                            @tagName(lhs_mcv),
                            @tagName(rhs_mcv),
                        }),
                    },
                    .indirect => |reg_off| .{
                        .base = .{ .reg = reg_off.reg },
                        .disp = reg_off.off,
                    },
                    .load_frame => |frame_addr| .{
                        .base = .{ .frame = frame_addr.index },
                        .disp = frame_addr.off,
                    },
                    else => unreachable,
                });
                switch (rhs_mcv) {
                    .immediate => |rhs_imm| try self.asmMemoryImmediate(
                        tag,
                        lhs_mem,
                        Immediate.u(rhs_imm),
                    ),
                    .register => |rhs_reg| try self.asmMemoryRegister(
                        tag,
                        lhs_mem,
                        registerAlias(rhs_reg, 1),
                    ),
                    else => return self.fail("TODO genShiftBinOpMir between {s} and {s}", .{
                        @tagName(lhs_mcv),
                        @tagName(rhs_mcv),
                    }),
                }
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
            .load_frame => |dst_frame_addr| switch (rhs_mcv) {
                .immediate => |rhs_imm| if (rhs_imm == 0) {} else if (rhs_imm < 64) {
                    try self.asmRegisterMemory(
                        .mov,
                        tmp_reg,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[0],
                        }),
                    );
                    try self.asmMemoryRegisterImmediate(
                        info.double_tag,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[1],
                        }),
                        tmp_reg,
                        Immediate.u(rhs_imm),
                    );
                    try self.asmMemoryImmediate(
                        tag,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[0],
                        }),
                        Immediate.u(rhs_imm),
                    );
                } else {
                    assert(rhs_imm < 128);
                    try self.asmRegisterMemory(
                        .mov,
                        tmp_reg,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[0],
                        }),
                    );
                    if (rhs_imm > 64) {
                        try self.asmRegisterImmediate(tag, tmp_reg, Immediate.u(rhs_imm - 64));
                    }
                    try self.asmMemoryRegister(
                        .mov,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[1],
                        }),
                        tmp_reg,
                    );
                    switch (tag) {
                        .shl, .sal, .shr => {
                            try self.asmRegisterRegister(.xor, tmp_reg.to32(), tmp_reg.to32());
                            try self.asmMemoryRegister(
                                .mov,
                                Memory.sib(.qword, .{
                                    .base = .{ .frame = dst_frame_addr.index },
                                    .disp = dst_frame_addr.off + info.offsets[0],
                                }),
                                tmp_reg,
                            );
                        },
                        .sar => try self.asmMemoryImmediate(
                            tag,
                            Memory.sib(.qword, .{
                                .base = .{ .frame = dst_frame_addr.index },
                                .disp = dst_frame_addr.off + info.offsets[0],
                            }),
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

                    try self.genSetReg(.cl, Type.u8, rhs_mcv);
                    try self.asmRegisterMemory(
                        .mov,
                        first_reg,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[0],
                        }),
                    );
                    try self.asmRegisterMemory(
                        .mov,
                        second_reg,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[1],
                        }),
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
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[1],
                        }),
                        second_reg,
                    );
                    try self.asmMemoryRegister(
                        .mov,
                        Memory.sib(.qword, .{
                            .base = .{ .frame = dst_frame_addr.index },
                            .disp = dst_frame_addr.off + info.offsets[0],
                        }),
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
        try self.genCopy(lhs_ty, dst_mcv, lhs_mcv);
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
        src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
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
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .disp = dst_mcv.load_frame.off,
                }),
                .rax,
            );
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .disp = dst_mcv.load_frame.off + 8,
                }),
                .rdx,
            );
            return dst_mcv;
        },

        .mod => {
            try self.register_manager.getReg(.rax, null);
            try self.register_manager.getReg(.rdx, if (signedness == .unsigned) maybe_inst else null);

            switch (signedness) {
                .signed => {
                    const lhs_lock = switch (lhs) {
                        .register => |reg| self.register_manager.lockReg(reg),
                        else => null,
                    };
                    defer if (lhs_lock) |lock| self.register_manager.unlockReg(lock);
                    const rhs_lock = switch (rhs) {
                        .register => |reg| self.register_manager.lockReg(reg),
                        else => null,
                    };
                    defer if (rhs_lock) |lock| self.register_manager.unlockReg(lock);

                    // hack around hazard between rhs and div_floor by copying rhs to another register
                    const rhs_copy = try self.copyToTmpRegister(ty, rhs);
                    const rhs_copy_lock = self.register_manager.lockRegAssumeUnused(rhs_copy);
                    defer self.register_manager.unlockReg(rhs_copy_lock);

                    const div_floor = try self.genInlineIntDivFloor(ty, lhs, rhs);
                    try self.genIntMulComplexOpMir(ty, div_floor, .{ .register = rhs_copy });
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
        try self.genCopy(lhs_ty, dst_mcv, lhs);
        break :dst dst_mcv;
    };
    const dst_lock: ?RegisterLock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const src_mcv = if (flipped) lhs else rhs;
    switch (tag) {
        .add,
        .addwrap,
        => try self.genBinOpMir(switch (lhs_ty.zigTypeTag()) {
            else => .add,
            .Float => switch (lhs_ty.floatBits(self.target.*)) {
                32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
                    .addss
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
                    .addsd
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse2", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
            },
        }, lhs_ty, dst_mcv, src_mcv),

        .sub,
        .subwrap,
        => try self.genBinOpMir(switch (lhs_ty.zigTypeTag()) {
            else => .sub,
            .Float => switch (lhs_ty.floatBits(self.target.*)) {
                32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
                    .subss
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
                    .subsd
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse2", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
            },
        }, lhs_ty, dst_mcv, src_mcv),

        .mul => try self.genBinOpMir(switch (lhs_ty.zigTypeTag()) {
            else => return self.fail("TODO implement genBinOp for {s} {}", .{
                @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
            }),
            .Float => switch (lhs_ty.floatBits(self.target.*)) {
                32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
                    .mulss
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
                    .mulsd
                else
                    return self.fail("TODO implement genBinOp for {s} {} without sse2", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
            },
        }, lhs_ty, dst_mcv, src_mcv),

        .div_float,
        .div_exact,
        .div_trunc,
        .div_floor,
        => {
            try self.genBinOpMir(switch (lhs_ty.zigTypeTag()) {
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
                .Float => switch (lhs_ty.floatBits(self.target.*)) {
                    32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
                        .divss
                    else
                        return self.fail("TODO implement genBinOp for {s} {} without sse", .{
                            @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                        }),
                    64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
                        .divsd
                    else
                        return self.fail("TODO implement genBinOp for {s} {} without sse2", .{
                            @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                        }),
                    else => return self.fail("TODO implement genBinOp for {s} {}", .{
                        @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                    }),
                },
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
                    try self.asmRegisterRegisterImmediate(switch (lhs_ty.floatBits(self.target.*)) {
                        32 => .roundss,
                        64 => .roundsd,
                        else => unreachable,
                    }, dst_alias, dst_alias, Immediate.u(switch (tag) {
                        .div_trunc => 0b1_0_11,
                        .div_floor => 0b1_0_01,
                        else => unreachable,
                    }));
                } else return self.fail("TODO implement genBinOp for {s} {} without sse4_1", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
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
                const mat_src_mcv: MCValue = if (switch (src_mcv) {
                    .immediate,
                    .eflags,
                    .register_offset,
                    .load_direct,
                    .lea_direct,
                    .load_got,
                    .lea_got,
                    .load_tlv,
                    .lea_tlv,
                    .lea_frame,
                    => true,
                    .memory => |addr| math.cast(i32, @bitCast(i64, addr)) == null,
                    else => false,
                }) .{ .register = try self.copyToTmpRegister(rhs_ty, src_mcv) } else src_mcv;
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
                    .unreach,
                    .dead,
                    .undef,
                    .immediate,
                    .eflags,
                    .register_offset,
                    .register_overflow,
                    .load_direct,
                    .lea_direct,
                    .load_got,
                    .lea_got,
                    .load_tlv,
                    .lea_tlv,
                    .lea_frame,
                    .reserved_frame,
                    => unreachable,
                    .register => |src_reg| try self.asmCmovccRegisterRegister(
                        registerAlias(tmp_reg, cmov_abi_size),
                        registerAlias(src_reg, cmov_abi_size),
                        cc,
                    ),
                    .memory, .indirect, .load_frame => try self.asmCmovccRegisterMemory(
                        registerAlias(tmp_reg, cmov_abi_size),
                        Memory.sib(Memory.PtrSize.fromSize(cmov_abi_size), switch (mat_src_mcv) {
                            .memory => |addr| .{
                                .base = .{ .reg = .ds },
                                .disp = @intCast(i32, @bitCast(i64, addr)),
                            },
                            .indirect => |reg_off| .{
                                .base = .{ .reg = reg_off.reg },
                                .disp = reg_off.off,
                            },
                            .load_frame => |frame_addr| .{
                                .base = .{ .frame = frame_addr.index },
                                .disp = frame_addr.off,
                            },
                            else => unreachable,
                        }),
                        cc,
                    ),
                }
                try self.genCopy(lhs_ty, dst_mcv, .{ .register = tmp_reg });
            },
            .Float => try self.genBinOpMir(switch (lhs_ty.floatBits(self.target.*)) {
                32 => switch (tag) {
                    .min => .minss,
                    .max => .maxss,
                    else => unreachable,
                },
                64 => switch (tag) {
                    .min => .minsd,
                    .max => .maxsd,
                    else => unreachable,
                },
                else => return self.fail("TODO implement genBinOp for {s} {}", .{
                    @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
                }),
            }, lhs_ty, dst_mcv, src_mcv),
            else => return self.fail("TODO implement genBinOp for {s} {}", .{
                @tagName(tag), lhs_ty.fmt(self.bin_file.options.module.?),
            }),
        },

        else => unreachable,
    }
    return dst_mcv;
}

fn genBinOpMir(self: *Self, mir_tag: Mir.Inst.Tag, ty: Type, dst_mcv: MCValue, src_mcv: MCValue) !void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .register_offset,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .reserved_frame,
        => unreachable, // unmodifiable destination
        .register => |dst_reg| {
            const dst_alias = registerAlias(dst_reg, abi_size);
            switch (src_mcv) {
                .none,
                .unreach,
                .dead,
                .undef,
                .register_overflow,
                .reserved_frame,
                => unreachable,
                .register => |src_reg| switch (ty.zigTypeTag()) {
                    .Float => {
                        if (!Target.x86.featureSetHas(self.target.cpu.features, .sse))
                            return self.fail("TODO genBinOpMir for {s} {} without sse", .{
                                @tagName(mir_tag), ty.fmt(self.bin_file.options.module.?),
                            });
                        return self.asmRegisterRegister(mir_tag, dst_reg.to128(), src_reg.to128());
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
                .eflags,
                .register_offset,
                .memory,
                .indirect,
                .load_direct,
                .lea_direct,
                .load_got,
                .lea_got,
                .load_tlv,
                .lea_tlv,
                .load_frame,
                .lea_frame,
                => {
                    blk: {
                        return self.asmRegisterMemory(
                            mir_tag,
                            registerAlias(dst_reg, abi_size),
                            Memory.sib(Memory.PtrSize.fromSize(abi_size), switch (src_mcv) {
                                .memory => |addr| .{
                                    .base = .{ .reg = .ds },
                                    .disp = math.cast(i32, addr) orelse break :blk,
                                },
                                .indirect => |reg_off| .{
                                    .base = .{ .reg = reg_off.reg },
                                    .disp = reg_off.off,
                                },
                                .load_frame => |frame_addr| .{
                                    .base = .{ .frame = frame_addr.index },
                                    .disp = frame_addr.off,
                                },
                                else => break :blk,
                            }),
                        );
                    }

                    const dst_reg_lock = self.register_manager.lockReg(dst_reg);
                    defer if (dst_reg_lock) |lock| self.register_manager.unlockReg(lock);

                    switch (src_mcv) {
                        .eflags,
                        .register_offset,
                        .lea_direct,
                        .lea_got,
                        .lea_tlv,
                        .lea_frame,
                        => {
                            const reg = try self.copyToTmpRegister(ty, src_mcv);
                            return self.genBinOpMir(mir_tag, ty, dst_mcv, .{ .register = reg });
                        },
                        .memory,
                        .load_direct,
                        .load_got,
                        .load_tlv,
                        => {
                            var ptr_pl = Type.Payload.ElemType{
                                .base = .{ .tag = .single_const_pointer },
                                .data = ty,
                            };
                            const ptr_ty = Type.initPayload(&ptr_pl.base);
                            const addr_reg = try self.copyToTmpRegister(ptr_ty, src_mcv.address());
                            return self.genBinOpMir(mir_tag, ty, dst_mcv, .{
                                .indirect = .{ .reg = addr_reg },
                            });
                        },
                        else => unreachable,
                    }
                },
            }
        },
        .memory, .indirect, .load_got, .load_direct, .load_tlv, .load_frame => {
            const OpInfo = ?struct { addr_reg: Register, addr_lock: RegisterLock };
            const limb_abi_size: u32 = @min(abi_size, 8);

            const dst_info: OpInfo = switch (dst_mcv) {
                else => unreachable,
                .memory, .load_got, .load_direct, .load_tlv => dst: {
                    const dst_addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    const dst_addr_lock = self.register_manager.lockRegAssumeUnused(dst_addr_reg);
                    errdefer self.register_manager.unlockReg(dst_addr_lock);

                    try self.genSetReg(dst_addr_reg, Type.usize, dst_mcv.address());
                    break :dst .{
                        .addr_reg = dst_addr_reg,
                        .addr_lock = dst_addr_lock,
                    };
                },
                .load_frame => null,
            };
            defer if (dst_info) |info| self.register_manager.unlockReg(info.addr_lock);

            const src_info: OpInfo = switch (src_mcv) {
                .none,
                .unreach,
                .dead,
                .undef,
                .register_overflow,
                .reserved_frame,
                => unreachable,
                .immediate,
                .register,
                .register_offset,
                .eflags,
                .indirect,
                .lea_direct,
                .lea_got,
                .lea_tlv,
                .load_frame,
                .lea_frame,
                => null,
                .memory, .load_got, .load_direct, .load_tlv => src: {
                    switch (src_mcv) {
                        .memory => |addr| if (math.cast(i32, @bitCast(i64, addr)) != null and
                            math.cast(i32, @bitCast(i64, addr) + abi_size - limb_abi_size) != null)
                            break :src null,
                        .load_got, .load_direct, .load_tlv => {},
                        else => unreachable,
                    }

                    const src_addr_reg = (try self.register_manager.allocReg(null, gp)).to64();
                    const src_addr_lock = self.register_manager.lockRegAssumeUnused(src_addr_reg);
                    errdefer self.register_manager.unlockReg(src_addr_lock);

                    try self.genSetReg(src_addr_reg, Type.usize, src_mcv.address());
                    break :src .{
                        .addr_reg = src_addr_reg,
                        .addr_lock = src_addr_lock,
                    };
                },
            };
            defer if (src_info) |info| self.register_manager.unlockReg(info.addr_lock);

            const ty_signedness =
                if (ty.isAbiInt()) ty.intInfo(self.target.*).signedness else .unsigned;
            const limb_ty = if (abi_size <= 8) ty else switch (ty_signedness) {
                .signed => Type.usize,
                .unsigned => Type.isize,
            };
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
                        .memory,
                        .load_got,
                        .load_direct,
                        .load_tlv,
                        => .{ .base = .{ .reg = dst_info.?.addr_reg }, .disp = off },
                        .indirect => |reg_off| .{
                            .base = .{ .reg = reg_off.reg },
                            .disp = reg_off.off + off,
                        },
                        .load_frame => |frame_addr| .{
                            .base = .{ .frame = frame_addr.index },
                            .disp = frame_addr.off + off,
                        },
                        else => unreachable,
                    },
                );
                switch (src_mcv) {
                    .none,
                    .unreach,
                    .dead,
                    .undef,
                    .register_overflow,
                    .reserved_frame,
                    => unreachable,
                    .register => |src_reg| switch (off) {
                        0 => try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src_reg, limb_abi_size),
                        ),
                        else => unreachable,
                    },
                    .immediate => |src_imm| {
                        const imm = switch (off) {
                            0 => src_imm,
                            else => switch (ty_signedness) {
                                .signed => @bitCast(u64, @bitCast(i64, src_imm) >> 63),
                                .unsigned => 0,
                            },
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
                    .register_offset,
                    .eflags,
                    .memory,
                    .indirect,
                    .load_direct,
                    .lea_direct,
                    .load_got,
                    .lea_got,
                    .load_tlv,
                    .lea_tlv,
                    .load_frame,
                    .lea_frame,
                    => {
                        const src_limb_reg = try self.copyToTmpRegister(limb_ty, if (src_info) |info| .{
                            .indirect = .{ .reg = info.addr_reg, .off = off },
                        } else switch (src_mcv) {
                            .eflags,
                            .register_offset,
                            .lea_direct,
                            .lea_got,
                            .lea_tlv,
                            .lea_frame,
                            => switch (off) {
                                0 => src_mcv,
                                else => .{ .immediate = 0 },
                            },
                            .memory => |addr| .{ .memory = @bitCast(u64, @bitCast(i64, addr) + off) },
                            .indirect => |reg_off| .{ .indirect = .{
                                .reg = reg_off.reg,
                                .off = reg_off.off + off,
                            } },
                            .load_frame => |frame_addr| .{ .load_frame = .{
                                .index = frame_addr.index,
                                .off = frame_addr.off + off,
                            } },
                            else => unreachable,
                        });
                        try self.asmMemoryRegister(
                            mir_limb_tag,
                            dst_limb_mem,
                            registerAlias(src_limb_reg, limb_abi_size),
                        );
                    },
                }
            }
        },
    }
}

/// Performs multi-operand integer multiplication between dst_mcv and src_mcv, storing the result in dst_mcv.
/// Does not support byte-size operands.
fn genIntMulComplexOpMir(self: *Self, dst_ty: Type, dst_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, dst_ty.abiSize(self.target.*));
    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .register_offset,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .reserved_frame,
        => unreachable, // unmodifiable destination
        .register => |dst_reg| {
            const dst_alias = registerAlias(dst_reg, abi_size);
            const dst_lock = self.register_manager.lockReg(dst_reg);
            defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

            switch (src_mcv) {
                .none,
                .unreach,
                .dead,
                .undef,
                .register_overflow,
                .reserved_frame,
                => unreachable,
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
                .register_offset,
                .eflags,
                .load_direct,
                .lea_direct,
                .load_got,
                .lea_got,
                .load_tlv,
                .lea_tlv,
                .lea_frame,
                => try self.asmRegisterRegister(
                    .imul,
                    dst_alias,
                    registerAlias(try self.copyToTmpRegister(dst_ty, src_mcv), abi_size),
                ),
                .memory, .indirect, .load_frame => try self.asmRegisterMemory(
                    .imul,
                    dst_alias,
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), switch (src_mcv) {
                        .memory => |addr| .{
                            .base = .{ .reg = .ds },
                            .disp = math.cast(i32, @bitCast(i64, addr)) orelse
                                return self.asmRegisterRegister(
                                .imul,
                                dst_alias,
                                registerAlias(try self.copyToTmpRegister(dst_ty, src_mcv), abi_size),
                            ),
                        },
                        .indirect => |reg_off| .{
                            .base = .{ .reg = reg_off.reg },
                            .disp = reg_off.off,
                        },
                        .load_frame => |frame_addr| .{
                            .base = .{ .frame = frame_addr.index },
                            .disp = frame_addr.off,
                        },
                        else => unreachable,
                    }),
                ),
            }
        },
        .memory, .indirect, .load_direct, .load_got, .load_tlv, .load_frame => {
            const tmp_reg = try self.copyToTmpRegister(dst_ty, dst_mcv);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.genIntMulComplexOpMir(dst_ty, tmp_mcv, src_mcv);
            try self.genCopy(dst_ty, dst_mcv, tmp_mcv);
        },
    }
}

fn airArg(self: *Self, inst: Air.Inst.Index) !void {
    // skip zero-bit arguments as they don't have a corresponding arg instruction
    var arg_index = self.arg_index;
    while (self.args[arg_index] == .none) arg_index += 1;
    self.arg_index = arg_index + 1;

    const result: MCValue = if (self.liveness.isUnused(inst)) .unreach else result: {
        const dst_mcv = self.args[arg_index];
        switch (dst_mcv) {
            .register => |reg| self.register_manager.getRegAssumeFree(reg, inst),
            .load_frame => {},
            else => return self.fail("TODO implement arg for {}", .{dst_mcv}),
        }

        const ty = self.air.typeOfIndex(inst);
        const src_index = self.air.instructions.items(.data)[inst].arg.src_index;
        const name = self.owner.mod_fn.getParamName(self.bin_file.options.module.?, src_index);
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
                // TODO use a frame index
                .load_frame => return,
                //.stack_offset => |off| .{
                //    .stack = .{
                //        // TODO handle -fomit-frame-pointer
                //        .fp_register = Register.rbp.dwarfLocOpDeref(),
                //        .offset = -off,
                //    },
                //},
                else => unreachable, // not a valid function parameter
            };
            // TODO: this might need adjusting like the linkers do.
            // Instead of flattening the owner and passing Decl.Index here we may
            // want to special case LazySymbol in DWARF linker too.
            try dw.genArgDbgInfo(name, ty, self.owner.getDecl(), loc);
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
                // TODO use a frame index
                .load_frame, .lea_frame => return,
                //=> |off| .{ .stack = .{
                //    .fp_register = Register.rbp.dwarfLocOpDeref(),
                //    .offset = -off,
                //} },
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
            // TODO: this might need adjusting like the linkers do.
            // Instead of flattening the owner and passing Decl.Index here we may
            // want to special case LazySymbol in DWARF linker too.
            try dw.genVarDbgInfo(name, ty, self.owner.getDecl(), is_ptr, loc);
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
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .load_frame = .{ .index = .ret_addr } });
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
}

fn airFrameAddress(self: *Self, inst: Air.Inst.Index) !void {
    const dst_mcv = try self.allocRegOrMem(inst, true);
    try self.genCopy(Type.usize, dst_mcv, .{ .lea_frame = .{ .index = .base_ptr } });
    return self.finishAir(inst, dst_mcv, .{ .none, .none, .none });
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

    var info = try self.resolveCallingConventionValues(fn_ty, args[fn_ty.fnParamLen()..], .call_frame);
    defer info.deinit(self);

    // We need a properly aligned and sized call frame to be able to call this function.
    {
        const needed_call_frame =
            FrameAlloc.init(.{ .size = info.stack_byte_count, .alignment = info.stack_align });
        const frame_allocs_slice = self.frame_allocs.slice();
        const stack_frame_size =
            &frame_allocs_slice.items(.abi_size)[@enumToInt(FrameIndex.call_frame)];
        stack_frame_size.* = @max(stack_frame_size.*, needed_call_frame.abi_size);
        const stack_frame_align =
            &frame_allocs_slice.items(.abi_align)[@enumToInt(FrameIndex.call_frame)];
        stack_frame_align.* = @max(stack_frame_align.*, needed_call_frame.abi_align);
    }

    try self.spillEflagsIfOccupied();
    try self.spillRegisters(abi.getCallerPreservedRegs(self.target.*));

    // set stack arguments first because this can clobber registers
    // also clobber spill arguments as we go
    switch (info.return_value.long) {
        .none, .unreach => {},
        .indirect => |reg_off| try self.spillRegisters(&.{reg_off.reg}),
        else => unreachable,
    }
    for (args, info.args) |arg, mc_arg| {
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);
        switch (mc_arg) {
            .none => {},
            .register => |reg| try self.spillRegisters(&.{reg}),
            .load_frame => try self.genCopy(arg_ty, mc_arg, arg_mcv),
            else => unreachable,
        }
    }

    // now we are free to set register arguments
    const ret_lock = switch (info.return_value.long) {
        .none, .unreach => null,
        .indirect => |reg_off| lock: {
            const ret_ty = fn_ty.fnReturnType();
            const frame_index = try self.allocFrameIndex(FrameAlloc.initType(ret_ty, self.target.*));
            try self.genSetReg(reg_off.reg, Type.usize, .{
                .lea_frame = .{ .index = frame_index, .off = -reg_off.off },
            });
            info.return_value.short = .{ .load_frame = .{ .index = frame_index } };
            break :lock self.register_manager.lockRegAssumeUnused(reg_off.reg);
        },
        else => unreachable,
    };
    defer if (ret_lock) |lock| self.register_manager.unlockReg(lock);

    for (args, info.args) |arg, mc_arg| {
        const arg_ty = self.air.typeOf(arg);
        const arg_mcv = try self.resolveInst(arg);
        switch (mc_arg) {
            .none, .load_frame => {},
            .register => try self.genCopy(arg_ty, mc_arg, arg_mcv),
            else => unreachable,
        }
    }

    // Due to incremental compilation, how function calls are generated depends
    // on linking.
    const mod = self.bin_file.options.module.?;
    if (self.air.value(callee)) |func_value| {
        if (func_value.castTag(.function)) |func_payload| {
            const func = func_payload.data;

            if (self.bin_file.cast(link.File.Elf)) |elf_file| {
                const atom_index = try elf_file.getOrCreateAtomForDecl(func.owner_decl);
                const atom = elf_file.getAtom(atom_index);
                _ = try atom.getOrCreateOffsetTableEntry(elf_file);
                const got_addr = atom.getOffsetTableAddress(elf_file);
                try self.asmMemory(.call, Memory.sib(.qword, .{
                    .base = .{ .reg = .ds },
                    .disp = @intCast(i32, got_addr),
                }));
            } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
                const atom = try coff_file.getOrCreateAtomForDecl(func.owner_decl);
                const sym_index = coff_file.getAtom(atom).getSymbolIndex().?;
                try self.genSetReg(.rax, Type.usize, .{ .lea_got = sym_index });
                try self.asmRegister(.call, .rax);
            } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
                const atom = try macho_file.getOrCreateAtomForDecl(func.owner_decl);
                const sym_index = macho_file.getAtom(atom).getSymbolIndex().?;
                try self.genSetReg(.rax, Type.usize, .{ .lea_got = sym_index });
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
                    .base = .{ .reg = .ds },
                    .disp = @intCast(i32, fn_got_addr),
                }));
            } else unreachable;
        } else if (func_value.castTag(.extern_fn)) |func_payload| {
            const extern_fn = func_payload.data;
            const decl_name = mem.sliceTo(mod.declPtr(extern_fn.owner_decl).name, 0);
            const lib_name = mem.sliceTo(extern_fn.lib_name, 0);
            if (self.bin_file.cast(link.File.Coff)) |coff_file| {
                const atom_index = try self.owner.getSymbolIndex(self);
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
                const atom_index = try self.owner.getSymbolIndex(self);
                const sym_index = try macho_file.getGlobalSymbol(decl_name, lib_name);
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
        try self.genSetReg(.rax, Type.usize, mcv);
        try self.asmRegister(.call, .rax);
    }

    var bt = self.liveness.iterateBigTomb(inst);
    self.feed(&bt, callee);
    for (args) |arg| self.feed(&bt, arg);

    const result = if (self.liveness.isUnused(inst)) .unreach else info.return_value.short;
    return self.finishAirResult(inst, result);
}

fn airRet(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ret_ty = self.fn_type.fnReturnType();
    switch (self.ret_mcv.short) {
        .none => {},
        .register => try self.genCopy(ret_ty, self.ret_mcv.short, operand),
        .indirect => |reg_off| {
            try self.register_manager.getReg(reg_off.reg, null);
            const lock = self.register_manager.lockRegAssumeUnused(reg_off.reg);
            defer self.register_manager.unlockReg(lock);

            try self.genSetReg(reg_off.reg, Type.usize, self.ret_mcv.long);
            try self.genSetMem(.{ .reg = reg_off.reg }, reg_off.off, ret_ty, operand);
        },
        else => unreachable,
    }
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .unreach, .{ un_op, .none, .none });
}

fn airRetLoad(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const ptr = try self.resolveInst(un_op);
    const ptr_ty = self.air.typeOf(un_op);
    switch (self.ret_mcv.short) {
        .none => {},
        .register => try self.load(self.ret_mcv.short, ptr_ty, ptr),
        .indirect => |reg_off| try self.genSetReg(reg_off.reg, ptr_ty, ptr),
        else => unreachable,
    }
    // TODO optimization opportunity: figure out when we can emit this as a 2 byte instruction
    // which is available if the jump is 127 bytes or less forward.
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try self.exitlude_jump_relocs.append(self.gpa, jmp_reloc);
    return self.finishAir(inst, .unreach, .{ un_op, .none, .none });
}

fn airCmp(self: *Self, inst: Air.Inst.Index, op: math.CompareOperator) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;
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
        try self.genCopy(ty, dst_mcv, lhs_mcv);
        break :dst dst_mcv;
    } else .{ .register = try self.copyToTmpRegister(ty, lhs_mcv) };
    const dst_lock = switch (dst_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        else => null,
    };
    defer if (dst_lock) |lock| self.register_manager.unlockReg(lock);

    const src_mcv = if (flipped) lhs_mcv else rhs_mcv;
    try self.genBinOpMir(switch (ty.zigTypeTag()) {
        else => .cmp,
        .Float => switch (ty.floatBits(self.target.*)) {
            32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
                .ucomiss
            else
                return self.fail("TODO implement airCmp for {} without sse", .{
                    ty.fmt(self.bin_file.options.module.?),
                }),
            64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
                .ucomisd
            else
                return self.fail("TODO implement airCmp for {} without sse2", .{
                    ty.fmt(self.bin_file.options.module.?),
                }),
            else => return self.fail("TODO implement airCmp for {}", .{
                ty.fmt(self.bin_file.options.module.?),
            }),
        },
    }, ty, dst_mcv, src_mcv);

    const signedness = if (ty.isAbiInt()) ty.intInfo(self.target.*).signedness else .unsigned;
    const result = MCValue{
        .eflags = Condition.fromCompareOperator(signedness, if (flipped) op.reverse() else op),
    };
    return self.finishAir(inst, result, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airCmpVector(self: *Self, inst: Air.Inst.Index) !void {
    _ = inst;
    return self.fail("TODO implement airCmpVector for {}", .{self.target.cpu.arch});
}

fn airCmpLtErrorsLen(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.options.module.?;
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    const addr_reg = try self.register_manager.allocReg(null, gp);
    const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
    defer self.register_manager.unlockReg(addr_lock);
    try self.genLazySymbolRef(.lea, addr_reg, link.File.LazySymbol.initDecl(.const_data, null, mod));

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
        Memory.sib(Memory.PtrSize.fromSize(op_abi_size), .{ .base = .{ .reg = addr_reg } }),
    );
    const result = MCValue{ .eflags = .b };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airTry(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Try, pl_op.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = self.air.typeOf(pl_op.operand);
    const result = try self.genTry(inst, pl_op.operand, body, err_union_ty, false);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn airTryPtr(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.TryPtr, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
    const err_union_ty = self.air.typeOf(extra.data.ptr).childType();
    const result = try self.genTry(inst, extra.data.ptr, body, err_union_ty, true);
    return self.finishAir(inst, result, .{ .none, .none, .none });
}

fn genTry(
    self: *Self,
    inst: Air.Inst.Index,
    err_union: Air.Inst.Ref,
    body: []const Air.Inst.Index,
    err_union_ty: Type,
    operand_is_ptr: bool,
) !MCValue {
    if (operand_is_ptr) {
        return self.fail("TODO genTry for pointers", .{});
    }
    const liveness_cond_br = self.liveness.getCondBr(inst);

    const err_union_mcv = try self.resolveInst(err_union);
    const is_err_mcv = try self.isErr(null, err_union_ty, err_union_mcv);

    const reloc = try self.genCondBrMir(Type.anyerror, is_err_mcv);

    if (self.liveness.operandDies(inst, 0)) {
        if (Air.refToIndex(err_union)) |err_union_inst| self.processDeath(err_union_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    for (liveness_cond_br.else_deaths) |operand| self.processDeath(operand);
    try self.genBody(body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    try self.performReloc(reloc);

    for (liveness_cond_br.then_deaths) |operand| self.processDeath(operand);

    const result = if (self.liveness.isUnused(inst))
        .unreach
    else
        try self.genUnwrapErrorUnionPayloadMir(inst, err_union_ty, err_union_mcv);
    return result;
}

fn airDbgStmt(self: *Self, inst: Air.Inst.Index) !void {
    const dbg_stmt = self.air.instructions.items(.data)[inst].dbg_stmt;
    _ = try self.addInst(.{
        .tag = .dbg_line,
        .ops = undefined,
        .data = .{ .line_column = .{
            .line = dbg_stmt.line,
            .column = dbg_stmt.column,
        } },
    });
    return self.finishAirBookkeeping();
}

fn airDbgInline(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const function = self.air.values[ty_pl.payload].castTag(.function).?.data;
    // TODO emit debug info for function change
    _ = function;
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn airDbgBlock(self: *Self, inst: Air.Inst.Index) !void {
    // TODO emit debug info lexical block
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
}

fn airDbgVar(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const operand = pl_op.operand;
    const ty = self.air.typeOf(operand);
    const mcv = try self.resolveInst(operand);

    const name = self.air.nullTerminatedString(pl_op.payload);

    const tag = self.air.instructions.items(.tag)[inst];
    try self.genVarDbgInfo(tag, ty, mcv, name);

    return self.finishAir(inst, .unreach, .{ operand, .none, .none });
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
        .load_frame,
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
    const liveness_cond_br = self.liveness.getCondBr(inst);

    const reloc = try self.genCondBrMir(cond_ty, cond);

    // If the condition dies here in this condbr instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (Air.refToIndex(pl_op.operand)) |op_inst| self.processDeath(op_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    for (liveness_cond_br.then_deaths) |operand| self.processDeath(operand);
    try self.genBody(then_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

    try self.performReloc(reloc);

    for (liveness_cond_br.else_deaths) |operand| self.processDeath(operand);
    try self.genBody(else_body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = false,
        .update_tracking = true,
        .resurrect = true,
        .close_scope = true,
    });

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
        .eflags,
        .register_offset,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .reserved_frame,
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

            try self.genSetReg(addr_reg, Type.usize, opt_mcv.address());
            const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
            try self.asmMemoryImmediate(
                .cmp,
                Memory.sib(Memory.PtrSize.fromSize(some_abi_size), .{
                    .base = .{ .reg = addr_reg },
                    .disp = some_info.off,
                }),
                Immediate.u(0),
            );
            return .{ .eflags = .e };
        },

        .indirect, .load_frame => {
            const some_abi_size = @intCast(u32, some_info.ty.abiSize(self.target.*));
            try self.asmMemoryImmediate(
                .cmp,
                Memory.sib(Memory.PtrSize.fromSize(some_abi_size), switch (opt_mcv) {
                    .indirect => |reg_off| .{
                        .base = .{ .reg = reg_off.reg },
                        .disp = reg_off.off + some_info.off,
                    },
                    .load_frame => |frame_addr| .{
                        .base = .{ .frame = frame_addr.index },
                        .disp = frame_addr.off + some_info.off,
                    },
                    else => unreachable,
                }),
                Immediate.u(0),
            );
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
    try self.asmMemoryImmediate(
        .cmp,
        Memory.sib(Memory.PtrSize.fromSize(some_abi_size), .{
            .base = .{ .reg = ptr_reg },
            .disp = some_info.off,
        }),
        Immediate.u(0),
    );
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
        .load_frame => |frame_addr| try self.genBinOpMir(
            .cmp,
            Type.anyerror,
            .{ .load_frame = .{
                .index = frame_addr.index,
                .off = frame_addr.off + @intCast(i32, err_off),
            } },
            .{ .immediate = 0 },
        ),
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
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = try self.isNull(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = try self.isNullPtr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNull(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = switch (try self.isNull(inst, ty, operand)) {
        .eflags => |cc| .{ .eflags = cc.negate() },
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonNullPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = switch (try self.isNullPtr(inst, ty, operand)) {
        .eflags => |cc| .{ .eflags = cc.negate() },
        else => unreachable,
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = try self.isErr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

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
    try self.load(operand, ptr_ty, operand_ptr);

    const result = try self.isErr(inst, ptr_ty.childType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const operand = try self.resolveInst(un_op);
    const ty = self.air.typeOf(un_op);
    const result = try self.isNonErr(inst, ty, operand);
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airIsNonErrPtr(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;

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
    try self.load(operand, ptr_ty, operand_ptr);

    const result = try self.isNonErr(inst, ptr_ty.childType(), operand);

    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airLoop(self: *Self, inst: Air.Inst.Index) !void {
    // A loop is a setup to be able to jump back to the beginning.
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const loop = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[loop.end..][0..loop.data.body_len];
    const jmp_target = @intCast(u32, self.mir_instructions.len);

    self.scope_generation += 1;
    const state = try self.saveState();

    try self.genBody(body);
    try self.restoreState(state, &.{}, .{
        .emit_instructions = true,
        .update_tracking = false,
        .resurrect = false,
        .close_scope = true,
    });
    _ = try self.asmJmpReloc(jmp_target);

    return self.finishAirBookkeeping();
}

fn airBlock(self: *Self, inst: Air.Inst.Index) !void {
    // A block is a setup to be able to jump to the end.
    const inst_tracking_i = self.inst_tracking.count();
    self.inst_tracking.putAssumeCapacityNoClobber(inst, InstTracking.init(.unreach));

    self.scope_generation += 1;
    try self.blocks.putNoClobber(self.gpa, inst, .{ .state = self.initRetroactiveState() });
    const liveness = self.liveness.getBlock(inst);

    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Block, ty_pl.payload);
    const body = self.air.extra[extra.end..][0..extra.data.body_len];
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
        for (block_data.value.relocs.items) |reloc| try self.performReloc(reloc);
    }

    if (std.debug.runtime_safety) assert(self.inst_tracking.getIndex(inst).? == inst_tracking_i);
    const tracking = &self.inst_tracking.values()[inst_tracking_i];
    if (self.liveness.isUnused(inst)) tracking.die(self, inst);
    self.getValue(tracking.short, inst);
    self.finishAirBookkeeping();
}

fn airSwitchBr(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const condition = try self.resolveInst(pl_op.operand);
    const condition_ty = self.air.typeOf(pl_op.operand);
    const switch_br = self.air.extraData(Air.SwitchBr, pl_op.payload);
    var extra_index: usize = switch_br.end;
    var case_i: u32 = 0;
    const liveness = try self.liveness.getSwitchBr(self.gpa, inst, switch_br.data.cases_len + 1);
    defer self.gpa.free(liveness.deaths);

    // If the condition dies here in this switch instruction, process
    // that death now instead of later as this has an effect on
    // whether it needs to be spilled in the branches
    if (self.liveness.operandDies(inst, 0)) {
        if (Air.refToIndex(pl_op.operand)) |op_inst| self.processDeath(op_inst);
    }

    self.scope_generation += 1;
    const state = try self.saveState();

    while (case_i < switch_br.data.cases_len) : (case_i += 1) {
        const case = self.air.extraData(Air.SwitchBr.Case, extra_index);
        const items = @ptrCast(
            []const Air.Inst.Ref,
            self.air.extra[case.end..][0..case.data.items_len],
        );
        const case_body = self.air.extra[case.end + items.len ..][0..case.data.body_len];
        extra_index = case.end + items.len + case_body.len;

        var relocs = try self.gpa.alloc(u32, items.len);
        defer self.gpa.free(relocs);

        try self.spillEflagsIfOccupied();
        for (items, relocs, 0..) |item, *reloc, i| {
            const item_mcv = try self.resolveInst(item);
            try self.genBinOpMir(.cmp, condition_ty, condition, item_mcv);
            reloc.* = try self.asmJccReloc(undefined, if (i < relocs.len - 1) .e else .ne);
        }

        for (liveness.deaths[case_i]) |operand| self.processDeath(operand);

        for (relocs[0 .. relocs.len - 1]) |reloc| try self.performReloc(reloc);
        try self.genBody(case_body);
        try self.restoreState(state, &.{}, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });

        try self.performReloc(relocs[relocs.len - 1]);
    }

    if (switch_br.data.else_body_len > 0) {
        const else_body = self.air.extra[extra_index..][0..switch_br.data.else_body_len];

        const else_deaths = liveness.deaths.len - 1;
        for (liveness.deaths[else_deaths]) |operand| self.processDeath(operand);

        try self.genBody(else_body);
        try self.restoreState(state, &.{}, .{
            .emit_instructions = false,
            .update_tracking = true,
            .resurrect = true,
            .close_scope = true,
        });
    }

    // We already took care of pl_op.operand earlier, so we're going to pass .none here
    return self.finishAir(inst, .unreach, .{ .none, .none, .none });
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
    const src_mcv = try self.resolveInst(br.operand);

    const block_ty = self.air.typeOfIndex(br.block_inst);
    const block_unused =
        !block_ty.hasRuntimeBitsIgnoreComptime() or self.liveness.isUnused(br.block_inst);
    const block_tracking = self.inst_tracking.getPtr(br.block_inst).?;
    const block_data = self.blocks.getPtr(br.block_inst).?;
    const first_br = block_data.relocs.items.len == 0;
    const block_result = result: {
        if (block_unused) break :result .none;

        if (self.reuseOperandAdvanced(inst, br.operand, 0, src_mcv, br.block_inst)) {
            if (first_br) break :result src_mcv;

            if (block_tracking.getReg()) |block_reg|
                try self.register_manager.getReg(block_reg, br.block_inst);
            // .long = .none to avoid merging operand and block result stack frames.
            var current_tracking = InstTracking{ .long = .none, .short = src_mcv };
            try current_tracking.materializeUnsafe(self, br.block_inst, block_tracking.*);
            if (src_mcv.getReg()) |src_reg| self.register_manager.freeReg(src_reg);
            break :result block_tracking.short;
        }

        const dst_mcv = if (first_br) try self.allocRegOrMem(br.block_inst, true) else dst: {
            self.getValue(block_tracking.short, br.block_inst);
            break :dst block_tracking.short;
        };
        try self.genCopy(block_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };

    // Process operand death so that it is properly accounted for in the State below.
    if (self.liveness.operandDies(inst, 0)) {
        if (Air.refToIndex(br.operand)) |op_inst| self.processDeath(op_inst);
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

    // Stop tracking block result without forgetting tracking info
    self.freeValue(block_tracking.short);

    // Emit a jump with a relocation. It will be patched up after the block ends.
    // Leave the jump offset undefined
    const jmp_reloc = try self.asmJmpReloc(undefined);
    try block_data.relocs.append(self.gpa, jmp_reloc);

    self.finishAirBookkeeping();
}

fn airAsm(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Asm, ty_pl.payload);
    const clobbers_len = @truncate(u31, extra.data.flags);
    var extra_i: usize = extra.end;
    const outputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.outputs_len]);
    extra_i += outputs.len;
    const inputs = @ptrCast([]const Air.Inst.Ref, self.air.extra[extra_i..][0..extra.data.inputs_len]);
    extra_i += inputs.len;

    var result: MCValue = .none;
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
        try self.genSetReg(reg, self.air.typeOf(input), arg_mcv);
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
        const mnem = mnem: {
            if (mnem_size) |_| {
                if (std.meta.stringToEnum(Mir.Inst.Tag, mnem_str[0 .. mnem_str.len - 1])) |mnem| {
                    break :mnem mnem;
                }
            }
            break :mnem std.meta.stringToEnum(Mir.Inst.Tag, mnem_str) orelse
                return self.fail("Invalid mnemonic: '{s}'", .{mnem_str});
        };

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
                        .{ .base = .{ .reg = reg }, .disp = disp },
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
    for (outputs) |output| if (output != .none) self.feed(&bt, output);
    for (inputs) |input| self.feed(&bt, input);
    return self.finishAirResult(inst, result);
}

fn movMirTag(self: *Self, ty: Type) !Mir.Inst.Tag {
    return switch (ty.zigTypeTag()) {
        else => .mov,
        .Float => switch (ty.floatBits(self.target.*)) {
            16 => unreachable, // needs special handling
            32 => .movss,
            64 => .movsd,
            128 => .movaps,
            else => return self.fail("TODO movMirTag from {}", .{
                ty.fmt(self.bin_file.options.module.?),
            }),
        },
    };
}

fn genCopy(self: *Self, ty: Type, dst_mcv: MCValue, src_mcv: MCValue) InnerError!void {
    const src_lock = switch (src_mcv) {
        .register => |reg| self.register_manager.lockReg(reg),
        .register_overflow => |ro| self.register_manager.lockReg(ro.reg),
        else => null,
    };
    defer if (src_lock) |lock| self.register_manager.unlockReg(lock);

    switch (dst_mcv) {
        .none,
        .unreach,
        .dead,
        .undef,
        .immediate,
        .eflags,
        .register_overflow,
        .lea_direct,
        .lea_got,
        .lea_tlv,
        .lea_frame,
        .reserved_frame,
        => unreachable, // unmodifiable destination
        .register => |reg| try self.genSetReg(reg, ty, src_mcv),
        .register_offset => |dst_reg_off| try self.genSetReg(dst_reg_off.reg, ty, switch (src_mcv) {
            .none,
            .unreach,
            .dead,
            .undef,
            .register_overflow,
            .reserved_frame,
            => unreachable,
            .immediate,
            .register,
            .register_offset,
            .lea_frame,
            => src_mcv.offset(-dst_reg_off.off),
            else => .{ .register_offset = .{
                .reg = try self.copyToTmpRegister(ty, src_mcv),
                .off = -dst_reg_off.off,
            } },
        }),
        .indirect => |reg_off| try self.genSetMem(.{ .reg = reg_off.reg }, reg_off.off, ty, src_mcv),
        .memory, .load_direct, .load_got, .load_tlv => {
            switch (dst_mcv) {
                .memory => |addr| if (math.cast(i32, @bitCast(i64, addr))) |small_addr|
                    return self.genSetMem(.{ .reg = .ds }, small_addr, ty, src_mcv),
                .load_direct, .load_got, .load_tlv => {},
                else => unreachable,
            }

            const addr_reg = try self.copyToTmpRegister(Type.usize, dst_mcv.address());
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            try self.genSetMem(.{ .reg = addr_reg }, 0, ty, src_mcv);
        },
        .load_frame => |frame_addr| try self.genSetMem(
            .{ .frame = frame_addr.index },
            frame_addr.off,
            ty,
            src_mcv,
        ),
    }
}

fn genSetReg(self: *Self, dst_reg: Register, ty: Type, src_mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    if (abi_size > 8) return self.fail("genSetReg called with a value larger than one register", .{});
    switch (src_mcv) {
        .none,
        .unreach,
        .dead,
        .register_overflow,
        .reserved_frame,
        => unreachable,
        .undef => if (self.wantSafety())
            try self.genSetReg(dst_reg.to64(), Type.usize, .{ .immediate = 0xaaaaaaaaaaaaaaaa }),
        .eflags => |cc| try self.asmSetccRegister(dst_reg.to8(), cc),
        .immediate => |imm| {
            if (imm == 0) {
                // 32-bit moves zero-extend to 64-bit, so xoring the 32-bit
                // register is the fastest way to zero a register.
                try self.asmRegisterRegister(.xor, dst_reg.to32(), dst_reg.to32());
            } else if (abi_size > 4 and math.cast(u32, imm) != null) {
                // 32-bit moves zero-extend to 64-bit.
                try self.asmRegisterImmediate(.mov, dst_reg.to32(), Immediate.u(imm));
            } else if (abi_size <= 4 and @bitCast(i64, imm) < 0) {
                try self.asmRegisterImmediate(
                    .mov,
                    registerAlias(dst_reg, abi_size),
                    Immediate.s(@intCast(i32, @bitCast(i64, imm))),
                );
            } else {
                try self.asmRegisterImmediate(
                    .mov,
                    registerAlias(dst_reg, abi_size),
                    Immediate.u(imm),
                );
            }
        },
        .register => |src_reg| if (dst_reg.id() != src_reg.id()) try self.asmRegisterRegister(
            if ((dst_reg.class() == .floating_point) == (src_reg.class() == .floating_point))
                switch (ty.zigTypeTag()) {
                    else => .mov,
                    .Float, .Vector => .movaps,
                }
            else switch (abi_size) {
                2 => return try self.asmRegisterRegisterImmediate(
                    if (dst_reg.class() == .floating_point) .pinsrw else .pextrw,
                    registerAlias(dst_reg, abi_size),
                    registerAlias(src_reg, abi_size),
                    Immediate.u(0),
                ),
                4 => .movd,
                8 => .movq,
                else => return self.fail(
                    "unsupported register copy from {s} to {s}",
                    .{ @tagName(src_reg), @tagName(dst_reg) },
                ),
            },
            registerAlias(dst_reg, abi_size),
            registerAlias(src_reg, abi_size),
        ),
        .register_offset,
        .indirect,
        .load_frame,
        .lea_frame,
        => {
            const src_mem = Memory.sib(Memory.PtrSize.fromSize(abi_size), switch (src_mcv) {
                .register_offset, .indirect => |reg_off| .{
                    .base = .{ .reg = reg_off.reg },
                    .disp = reg_off.off,
                },
                .load_frame, .lea_frame => |frame_addr| .{
                    .base = .{ .frame = frame_addr.index },
                    .disp = frame_addr.off,
                },
                else => unreachable,
            });
            if (ty.isRuntimeFloat() and ty.floatBits(self.target.*) == 16)
                try self.asmRegisterMemoryImmediate(
                    .pinsrw,
                    registerAlias(dst_reg, abi_size),
                    src_mem,
                    Immediate.u(0),
                )
            else
                try self.asmRegisterMemory(
                    switch (src_mcv) {
                        .register_offset => |reg_off| switch (reg_off.off) {
                            0 => return self.genSetReg(dst_reg, ty, .{ .register = reg_off.reg }),
                            else => .lea,
                        },
                        .indirect, .load_frame => try self.movMirTag(ty),
                        .lea_frame => .lea,
                        else => unreachable,
                    },
                    registerAlias(dst_reg, abi_size),
                    src_mem,
                );
        },
        .memory, .load_direct, .load_got, .load_tlv => {
            switch (src_mcv) {
                .memory => |addr| if (math.cast(i32, @bitCast(i64, addr))) |small_addr| {
                    const src_mem = Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                        .base = .{ .reg = .ds },
                        .disp = small_addr,
                    });
                    return if (ty.isRuntimeFloat() and ty.floatBits(self.target.*) == 16)
                        self.asmRegisterMemoryImmediate(
                            .pinsrw,
                            registerAlias(dst_reg, abi_size),
                            src_mem,
                            Immediate.u(0),
                        )
                    else
                        self.asmRegisterMemory(
                            try self.movMirTag(ty),
                            registerAlias(dst_reg, abi_size),
                            src_mem,
                        );
                },
                .load_direct => |sym_index| if (!ty.isRuntimeFloat()) {
                    const atom_index = try self.owner.getSymbolIndex(self);
                    _ = try self.addInst(.{
                        .tag = .mov_linker,
                        .ops = .direct_reloc,
                        .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                            .reg = @enumToInt(dst_reg.to64()),
                            .atom_index = atom_index,
                            .sym_index = sym_index,
                        }) },
                    });
                    return;
                },
                .load_got, .load_tlv => {},
                else => unreachable,
            }

            const addr_reg = try self.copyToTmpRegister(Type.usize, src_mcv.address());
            const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
            defer self.register_manager.unlockReg(addr_lock);

            const src_mem = Memory.sib(Memory.PtrSize.fromSize(abi_size), .{
                .base = .{ .reg = addr_reg },
            });
            if (ty.isRuntimeFloat() and ty.floatBits(self.target.*) == 16)
                try self.asmRegisterMemoryImmediate(
                    .pinsrw,
                    registerAlias(dst_reg, abi_size),
                    src_mem,
                    Immediate.u(0),
                )
            else
                try self.asmRegisterMemory(
                    try self.movMirTag(ty),
                    registerAlias(dst_reg, abi_size),
                    src_mem,
                );
        },
        .lea_direct, .lea_got => |sym_index| {
            const atom_index = try self.owner.getSymbolIndex(self);
            _ = try self.addInst(.{
                .tag = switch (src_mcv) {
                    .lea_direct => .lea_linker,
                    .lea_got => .mov_linker,
                    else => unreachable,
                },
                .ops = switch (src_mcv) {
                    .lea_direct => .direct_reloc,
                    .lea_got => .got_reloc,
                    else => unreachable,
                },
                .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                    .reg = @enumToInt(dst_reg.to64()),
                    .atom_index = atom_index,
                    .sym_index = sym_index,
                }) },
            });
        },
        .lea_tlv => |sym_index| {
            const atom_index = try self.owner.getSymbolIndex(self);
            if (self.bin_file.cast(link.File.MachO)) |_| {
                _ = try self.addInst(.{
                    .tag = .lea_linker,
                    .ops = .tlv_reloc,
                    .data = .{ .payload = try self.addExtra(Mir.LeaRegisterReloc{
                        .reg = @enumToInt(Register.rdi),
                        .atom_index = atom_index,
                        .sym_index = sym_index,
                    }) },
                });
                // TODO: spill registers before calling
                try self.asmMemory(.call, Memory.sib(.qword, .{ .base = .{ .reg = .rdi } }));
                try self.genSetReg(dst_reg.to64(), Type.usize, .{ .register = .rax });
            } else return self.fail("TODO emit ptr to TLV sequence on {s}", .{
                @tagName(self.bin_file.tag),
            });
        },
    }
}

fn genSetMem(self: *Self, base: Memory.Base, disp: i32, ty: Type, src_mcv: MCValue) InnerError!void {
    const abi_size = @intCast(u32, ty.abiSize(self.target.*));
    const dst_ptr_mcv: MCValue = switch (base) {
        .none => .{ .immediate = @bitCast(u64, @as(i64, disp)) },
        .reg => |base_reg| .{ .register_offset = .{ .reg = base_reg, .off = disp } },
        .frame => |base_frame_index| .{ .lea_frame = .{ .index = base_frame_index, .off = disp } },
    };
    switch (src_mcv) {
        .none, .unreach, .dead, .reserved_frame => unreachable,
        .undef => if (self.wantSafety())
            try self.genInlineMemset(dst_ptr_mcv, .{ .immediate = 0xaa }, .{ .immediate = abi_size }),
        .immediate => |imm| switch (abi_size) {
            1, 2, 4 => {
                const immediate = if (ty.isSignedInt())
                    Immediate.s(@truncate(i32, @bitCast(i64, imm)))
                else
                    Immediate.u(@intCast(u32, imm));
                try self.asmMemoryImmediate(
                    .mov,
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = base, .disp = disp }),
                    immediate,
                );
            },
            3, 5...7 => unreachable,
            else => if (math.cast(i32, @bitCast(i64, imm))) |small| {
                try self.asmMemoryImmediate(
                    .mov,
                    Memory.sib(Memory.PtrSize.fromSize(abi_size), .{ .base = base, .disp = disp }),
                    Immediate.s(small),
                );
            } else {
                var offset: i32 = 0;
                while (offset < abi_size) : (offset += 4) try self.asmMemoryImmediate(
                    .mov,
                    Memory.sib(.dword, .{ .base = base, .disp = disp + offset }),
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
            },
        },
        .eflags => |cc| try self.asmSetccMemory(Memory.sib(.byte, .{ .base = base, .disp = disp }), cc),
        .register => |src_reg| {
            const dst_mem = Memory.sib(
                Memory.PtrSize.fromSize(abi_size),
                .{ .base = base, .disp = disp },
            );
            if (ty.isRuntimeFloat() and ty.floatBits(self.target.*) == 16)
                try self.asmMemoryRegisterImmediate(
                    .pextrw,
                    dst_mem,
                    registerAlias(src_reg, abi_size),
                    Immediate.u(0),
                )
            else
                try self.asmMemoryRegister(
                    try self.movMirTag(ty),
                    dst_mem,
                    registerAlias(src_reg, abi_size),
                );
        },
        .register_overflow => |ro| {
            try self.genSetMem(
                base,
                disp + @intCast(i32, ty.structFieldOffset(0, self.target.*)),
                ty.structFieldType(0),
                .{ .register = ro.reg },
            );
            try self.genSetMem(
                base,
                disp + @intCast(i32, ty.structFieldOffset(1, self.target.*)),
                ty.structFieldType(1),
                .{ .eflags = ro.eflags },
            );
        },
        .register_offset,
        .memory,
        .indirect,
        .load_direct,
        .lea_direct,
        .load_got,
        .lea_got,
        .load_tlv,
        .lea_tlv,
        .load_frame,
        .lea_frame,
        => switch (abi_size) {
            0 => {},
            1, 2, 4, 8 => {
                const src_reg = try self.copyToTmpRegister(ty, src_mcv);
                const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
                defer self.register_manager.unlockReg(src_lock);

                try self.genSetMem(base, disp, ty, .{ .register = src_reg });
            },
            else => try self.genInlineMemcpy(dst_ptr_mcv, src_mcv.address(), .{ .immediate = abi_size }),
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
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(Memory.PtrSize.fromSize(nearest_power_of_two), .{
                    .base = dst_reg,
                    .disp = -next_offset,
                }),
                registerAlias(tmp_reg, nearest_power_of_two),
            );

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

fn genInlineMemcpy(self: *Self, dst_ptr: MCValue, src_ptr: MCValue, len: MCValue) InnerError!void {
    try self.spillRegisters(&.{ .rdi, .rsi, .rcx });
    try self.genSetReg(.rdi, Type.usize, dst_ptr);
    try self.genSetReg(.rsi, Type.usize, src_ptr);
    try self.genSetReg(.rcx, Type.usize, len);
    _ = try self.addInst(.{
        .tag = .movs,
        .ops = .string,
        .data = .{ .string = .{ .repeat = .rep, .width = .b } },
    });
}

fn genInlineMemset(self: *Self, dst_ptr: MCValue, value: MCValue, len: MCValue) InnerError!void {
    try self.spillRegisters(&.{ .rdi, .al, .rcx });
    try self.genSetReg(.rdi, Type.usize, dst_ptr);
    try self.genSetReg(.al, Type.u8, value);
    try self.genSetReg(.rcx, Type.usize, len);
    _ = try self.addInst(.{
        .tag = .stos,
        .ops = .string,
        .data = .{ .string = .{ .repeat = .rep, .width = .b } },
    });
}

fn genLazySymbolRef(
    self: *Self,
    comptime tag: Mir.Inst.Tag,
    reg: Register,
    lazy_sym: link.File.LazySymbol,
) InnerError!void {
    if (self.bin_file.cast(link.File.Elf)) |elf_file| {
        const atom_index = elf_file.getOrCreateAtomForLazySymbol(lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const atom = elf_file.getAtom(atom_index);
        _ = try atom.getOrCreateOffsetTableEntry(elf_file);
        const got_addr = atom.getOffsetTableAddress(elf_file);
        const got_mem =
            Memory.sib(.qword, .{ .base = .{ .reg = .ds }, .disp = @intCast(i32, got_addr) });
        switch (tag) {
            .lea, .mov => try self.asmRegisterMemory(.mov, reg.to64(), got_mem),
            .call => try self.asmMemory(.call, got_mem),
            else => unreachable,
        }
        switch (tag) {
            .lea, .call => {},
            .mov => try self.asmRegisterMemory(
                tag,
                reg.to64(),
                Memory.sib(.qword, .{ .base = .{ .reg = reg.to64() } }),
            ),
            else => unreachable,
        }
    } else if (self.bin_file.cast(link.File.Coff)) |coff_file| {
        const atom_index = coff_file.getOrCreateAtomForLazySymbol(lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const sym_index = coff_file.getAtom(atom_index).getSymbolIndex().?;
        switch (tag) {
            .lea, .call => try self.genSetReg(reg, Type.usize, .{ .lea_got = sym_index }),
            .mov => try self.genSetReg(reg, Type.usize, .{ .load_got = sym_index }),
            else => unreachable,
        }
        switch (tag) {
            .lea, .mov => {},
            .call => try self.asmRegister(.call, reg),
            else => unreachable,
        }
    } else if (self.bin_file.cast(link.File.MachO)) |macho_file| {
        const atom_index = macho_file.getOrCreateAtomForLazySymbol(lazy_sym) catch |err|
            return self.fail("{s} creating lazy symbol", .{@errorName(err)});
        const sym_index = macho_file.getAtom(atom_index).getSymbolIndex().?;
        switch (tag) {
            .lea, .call => try self.genSetReg(reg, Type.usize, .{ .lea_got = sym_index }),
            .mov => try self.genSetReg(reg, Type.usize, .{ .load_got = sym_index }),
            else => unreachable,
        }
        switch (tag) {
            .lea, .mov => {},
            .call => try self.asmRegister(.call, reg),
            else => unreachable,
        }
    } else {
        return self.fail("TODO implement genLazySymbol for x86_64 {s}", .{@tagName(self.bin_file.tag)});
    }
}

fn airPtrToInt(self: *Self, inst: Air.Inst.Index) !void {
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const result = result: {
        // TODO: handle case where the operand is a slice not a raw pointer
        const src_mcv = try self.resolveInst(un_op);
        if (self.reuseOperand(inst, un_op, 0, src_mcv)) break :result src_mcv;

        const dst_mcv = try self.allocRegOrMem(inst, true);
        const dst_ty = self.air.typeOfIndex(inst);
        try self.genCopy(dst_ty, dst_mcv, src_mcv);
        break :result dst_mcv;
    };
    return self.finishAir(inst, result, .{ un_op, .none, .none });
}

fn airBitCast(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    const dst_ty = self.air.typeOfIndex(inst);
    const src_ty = self.air.typeOf(ty_op.operand);

    const result = result: {
        const dst_rc = regClassForType(dst_ty);
        const src_rc = regClassForType(src_ty);
        const operand = try self.resolveInst(ty_op.operand);
        if (dst_rc.supersetOf(src_rc) and self.reuseOperand(inst, ty_op.operand, 0, operand))
            break :result operand;

        const operand_lock = switch (operand) {
            .register => |reg| self.register_manager.lockReg(reg),
            .register_overflow => |ro| self.register_manager.lockReg(ro.reg),
            else => null,
        };
        defer if (operand_lock) |lock| self.register_manager.unlockReg(lock);

        const dest = try self.allocRegOrMem(inst, true);
        try self.genCopy(self.air.typeOfIndex(inst), dest, operand);
        break :result dest;
    };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airArrayToSlice(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const slice_ty = self.air.typeOfIndex(inst);
    const ptr_ty = self.air.typeOf(ty_op.operand);
    const ptr = try self.resolveInst(ty_op.operand);
    const array_ty = ptr_ty.childType();
    const array_len = array_ty.arrayLen();

    const frame_index = try self.allocFrameIndex(FrameAlloc.initType(slice_ty, self.target.*));
    try self.genSetMem(.{ .frame = frame_index }, 0, ptr_ty, ptr);
    try self.genSetMem(
        .{ .frame = frame_index },
        @intCast(i32, ptr_ty.abiSize(self.target.*)),
        Type.usize,
        .{ .immediate = array_len },
    );

    const result = MCValue{ .load_frame = .{ .index = frame_index } };
    return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airIntToFloat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

    const src_ty = self.air.typeOf(ty_op.operand);
    const src_bits = @intCast(u32, src_ty.bitSize(self.target.*));
    const src_signedness =
        if (src_ty.isAbiInt()) src_ty.intInfo(self.target.*).signedness else .unsigned;
    const dst_ty = self.air.typeOfIndex(inst);

    const src_size = std.math.divCeil(u32, @max(switch (src_signedness) {
        .signed => src_bits,
        .unsigned => src_bits + 1,
    }, 32), 8) catch unreachable;
    if (src_size > 8) return self.fail("TODO implement airIntToFloat from {} to {}", .{
        src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
    });

    const src_mcv = try self.resolveInst(ty_op.operand);
    const src_reg = switch (src_mcv) {
        .register => |reg| reg,
        else => try self.copyToTmpRegister(src_ty, src_mcv),
    };
    const src_lock = self.register_manager.lockRegAssumeUnused(src_reg);
    defer self.register_manager.unlockReg(src_lock);

    if (src_bits < src_size * 8) try self.truncateRegister(src_ty, src_reg);

    const dst_reg = try self.register_manager.allocReg(inst, regClassForType(dst_ty));
    const dst_mcv = MCValue{ .register = dst_reg };
    const dst_lock = self.register_manager.lockRegAssumeUnused(dst_reg);
    defer self.register_manager.unlockReg(dst_lock);

    try self.asmRegisterRegister(switch (dst_ty.floatBits(self.target.*)) {
        32 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse))
            .cvtsi2ss
        else
            return self.fail("TODO implement airIntToFloat from {} to {} without sse", .{
                src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
            }),
        64 => if (Target.x86.featureSetHas(self.target.cpu.features, .sse2))
            .cvtsi2sd
        else
            return self.fail("TODO implement airIntToFloat from {} to {} without sse2", .{
                src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
            }),
        else => return self.fail("TODO implement airIntToFloat from {} to {}", .{
            src_ty.fmt(self.bin_file.options.module.?), dst_ty.fmt(self.bin_file.options.module.?),
        }),
    }, dst_reg.to128(), registerAlias(src_reg, src_size));

    return self.finishAir(inst, dst_mcv, .{ ty_op.operand, .none, .none });
}

fn airFloatToInt(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;

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
    const frame_addr: FrameAddr = switch (operand) {
        .load_frame => |frame_addr| frame_addr,
        else => frame_addr: {
            const frame_index = try self.allocFrameIndex(FrameAlloc.initType(src_ty, self.target.*));
            try self.genSetMem(.{ .frame = frame_index }, 0, src_ty, operand);
            break :frame_addr .{ .index = frame_index };
        },
    };
    try self.asmMemory(
        .fld,
        Memory.sib(Memory.PtrSize.fromSize(src_abi_size), .{
            .base = .{ .frame = frame_addr.index },
            .disp = frame_addr.off,
        }),
    );

    // convert
    const stack_dst = try self.allocRegOrMem(inst, false);
    try self.asmMemory(
        .fisttp,
        Memory.sib(Memory.PtrSize.fromSize(dst_abi_size), .{
            .base = .{ .frame = stack_dst.load_frame.index },
            .disp = stack_dst.load_frame.off,
        }),
    );

    return self.finishAir(inst, stack_dst, .{ ty_op.operand, .none, .none });
}

fn airCmpxchg(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.Cmpxchg, ty_pl.payload).data;

    const ptr_ty = self.air.typeOf(extra.ptr);
    const val_ty = self.air.typeOf(extra.expected_value);
    const val_abi_size = @intCast(u32, val_ty.abiSize(self.target.*));

    try self.spillRegisters(&.{ .rax, .rdx, .rbx, .rcx });
    const regs_lock = self.register_manager.lockRegsAssumeUnused(4, .{ .rax, .rdx, .rbx, .rcx });
    defer for (regs_lock) |lock| self.register_manager.unlockReg(lock);

    const exp_mcv = try self.resolveInst(extra.expected_value);
    if (val_abi_size > 8) {
        try self.genSetReg(.rax, Type.usize, exp_mcv);
        try self.genSetReg(.rdx, Type.usize, exp_mcv.address().offset(8).deref());
    } else try self.genSetReg(.rax, val_ty, exp_mcv);

    const new_mcv = try self.resolveInst(extra.new_value);
    const new_reg = if (val_abi_size > 8) new: {
        try self.genSetReg(.rbx, Type.usize, new_mcv);
        try self.genSetReg(.rcx, Type.usize, new_mcv.address().offset(8).deref());
        break :new null;
    } else try self.copyToTmpRegister(val_ty, new_mcv);
    const new_lock = if (new_reg) |reg| self.register_manager.lockRegAssumeUnused(reg) else null;
    defer if (new_lock) |lock| self.register_manager.unlockReg(lock);

    const ptr_mcv = try self.resolveInst(extra.ptr);
    const ptr_size = Memory.PtrSize.fromSize(val_abi_size);
    const ptr_mem = switch (ptr_mcv) {
        .immediate, .register, .register_offset, .lea_frame => ptr_mcv.deref().mem(ptr_size),
        else => Memory.sib(ptr_size, .{
            .base = .{ .reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv) },
        }),
    };
    switch (ptr_mem) {
        .sib, .rip => {},
        .moffs => return self.fail("TODO airCmpxchg with {s}", .{@tagName(ptr_mcv)}),
    }
    const ptr_lock = switch (ptr_mem.base()) {
        .none, .frame => null,
        .reg => |reg| self.register_manager.lockReg(reg),
    };
    defer if (ptr_lock) |lock| self.register_manager.unlockReg(lock);

    try self.spillEflagsIfOccupied();
    if (val_abi_size <= 8) {
        _ = try self.addInst(.{ .tag = .cmpxchg, .ops = .lock_mr_sib, .data = .{ .rx = .{
            .r = registerAlias(new_reg.?, val_abi_size),
            .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
        } } });
    } else {
        _ = try self.addInst(.{ .tag = .cmpxchgb, .ops = .lock_m_sib, .data = .{
            .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
        } });
    }

    const result: MCValue = result: {
        if (self.liveness.isUnused(inst)) break :result .unreach;

        if (val_abi_size <= 8) {
            self.eflags_inst = inst;
            break :result .{ .register_overflow = .{ .reg = .rax, .eflags = .ne } };
        }

        const dst_mcv = try self.allocRegOrMem(inst, false);
        try self.genCopy(Type.usize, dst_mcv, .{ .register = .rax });
        try self.genCopy(Type.usize, dst_mcv.address().offset(8).deref(), .{ .register = .rdx });
        try self.genCopy(Type.bool, dst_mcv.address().offset(16).deref(), .{ .eflags = .ne });
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
        .immediate, .register, .register_offset, .lea_frame => ptr_mcv.deref().mem(ptr_size),
        else => Memory.sib(ptr_size, .{
            .base = .{ .reg = try self.copyToTmpRegister(ptr_ty, ptr_mcv) },
        }),
    };
    switch (ptr_mem) {
        .sib, .rip => {},
        .moffs => return self.fail("TODO airCmpxchg with {s}", .{@tagName(ptr_mcv)}),
    }
    const mem_lock = switch (ptr_mem.base()) {
        .none, .frame => null,
        .reg => |reg| self.register_manager.lockReg(reg),
    };
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

            try self.genSetReg(dst_reg, val_ty, val_mcv);
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

            return if (unused) .unreach else dst_mcv;
        },
        .loop => _ = if (val_abi_size <= 8) {
            const tmp_reg = try self.register_manager.allocReg(null, gp);
            const tmp_mcv = MCValue{ .register = tmp_reg };
            const tmp_lock = self.register_manager.lockRegAssumeUnused(tmp_reg);
            defer self.register_manager.unlockReg(tmp_lock);

            try self.asmRegisterMemory(.mov, registerAlias(.rax, val_abi_size), ptr_mem);
            const loop = @intCast(u32, self.mir_instructions.len);
            if (rmw_op != std.builtin.AtomicRmwOp.Xchg) {
                try self.genSetReg(tmp_reg, val_ty, .{ .register = .rax });
            }
            if (rmw_op) |op| switch (op) {
                .Xchg => try self.genSetReg(tmp_reg, val_ty, val_mcv),
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
                        .memory, .indirect, .load_frame => try self.asmCmovccRegisterMemory(
                            registerAlias(tmp_reg, cmov_abi_size),
                            val_mcv.mem(Memory.PtrSize.fromSize(cmov_abi_size)),
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
            return if (unused) .unreach else .{ .register = .rax };
        } else {
            try self.asmRegisterMemory(.mov, .rax, Memory.sib(.qword, .{
                .base = ptr_mem.sib.base,
                .scale_index = ptr_mem.scaleIndex(),
                .disp = ptr_mem.sib.disp + 0,
            }));
            try self.asmRegisterMemory(.mov, .rdx, Memory.sib(.qword, .{
                .base = ptr_mem.sib.base,
                .scale_index = ptr_mem.scaleIndex(),
                .disp = ptr_mem.sib.disp + 8,
            }));
            const loop = @intCast(u32, self.mir_instructions.len);
            const val_mem_mcv: MCValue = switch (val_mcv) {
                .memory, .indirect, .load_frame => val_mcv,
                else => .{ .indirect = .{
                    .reg = try self.copyToTmpRegister(Type.usize, val_mcv.address()),
                } },
            };
            const val_lo_mem = val_mem_mcv.mem(.qword);
            const val_hi_mem = val_mem_mcv.address().offset(8).deref().mem(.qword);
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
                else => return self.fail("TODO implement x86 atomic loop for {} {s}", .{
                    val_ty.fmt(self.bin_file.options.module.?), @tagName(op),
                }),
            };
            _ = try self.addInst(.{ .tag = .cmpxchgb, .ops = .lock_m_sib, .data = .{
                .payload = try self.addExtra(Mir.MemorySib.encode(ptr_mem)),
            } });
            _ = try self.asmJccReloc(loop, .ne);

            if (unused) return .unreach;
            const dst_mcv = try self.allocTempRegOrMem(val_ty, false);
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .disp = dst_mcv.load_frame.off + 0,
                }),
                .rax,
            );
            try self.asmMemoryRegister(
                .mov,
                Memory.sib(.qword, .{
                    .base = .{ .frame = dst_mcv.load_frame.index },
                    .disp = dst_mcv.load_frame.off + 8,
                }),
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

    try self.load(dst_mcv, ptr_ty, ptr_mcv);
    return self.finishAir(inst, dst_mcv, .{ atomic_load.ptr, .none, .none });
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

fn airMemset(self: *Self, inst: Air.Inst.Index, safety: bool) !void {
    if (safety) {
        // TODO if the value is undef, write 0xaa bytes to dest
    } else {
        // TODO if the value is undef, don't lower this instruction
    }

    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const dst_ptr = try self.resolveInst(bin_op.lhs);
    const dst_ptr_ty = self.air.typeOf(bin_op.lhs);
    const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const src_val = try self.resolveInst(bin_op.rhs);
    const elem_ty = self.air.typeOf(bin_op.rhs);
    const src_val_lock: ?RegisterLock = switch (src_val) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_val_lock) |lock| self.register_manager.unlockReg(lock);

    const elem_abi_size = @intCast(u31, elem_ty.abiSize(self.target.*));

    if (elem_abi_size == 1) {
        const ptr: MCValue = switch (dst_ptr_ty.ptrSize()) {
            // TODO: this only handles slices stored in the stack
            .Slice => dst_ptr,
            .One => dst_ptr,
            .C, .Many => unreachable,
        };
        const len: MCValue = switch (dst_ptr_ty.ptrSize()) {
            // TODO: this only handles slices stored in the stack
            .Slice => dst_ptr.address().offset(8).deref(),
            .One => .{ .immediate = dst_ptr_ty.childType().arrayLen() },
            .C, .Many => unreachable,
        };
        const len_lock: ?RegisterLock = switch (len) {
            .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
            else => null,
        };
        defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

        try self.genInlineMemset(ptr, src_val, len);
        return self.finishAir(inst, .unreach, .{ bin_op.lhs, bin_op.rhs, .none });
    }

    // Store the first element, and then rely on memcpy copying forwards.
    // Length zero requires a runtime check - so we handle arrays specially
    // here to elide it.
    switch (dst_ptr_ty.ptrSize()) {
        .Slice => {
            var buf: Type.SlicePtrFieldTypeBuffer = undefined;
            const slice_ptr_ty = dst_ptr_ty.slicePtrFieldType(&buf);

            // TODO: this only handles slices stored in the stack
            const ptr = dst_ptr;
            const len = dst_ptr.address().offset(8).deref();

            // Used to store the number of elements for comparison.
            // After comparison, updated to store number of bytes needed to copy.
            const len_reg = try self.register_manager.allocReg(null, gp);
            const len_mcv: MCValue = .{ .register = len_reg };
            const len_lock = self.register_manager.lockRegAssumeUnused(len_reg);
            defer self.register_manager.unlockReg(len_lock);

            try self.genSetReg(len_reg, Type.usize, len);

            const skip_reloc = try self.asmJccReloc(undefined, .z);
            try self.store(slice_ptr_ty, ptr, src_val);

            const second_elem_ptr_reg = try self.register_manager.allocReg(null, gp);
            const second_elem_ptr_mcv: MCValue = .{ .register = second_elem_ptr_reg };
            const second_elem_ptr_lock = self.register_manager.lockRegAssumeUnused(second_elem_ptr_reg);
            defer self.register_manager.unlockReg(second_elem_ptr_lock);

            try self.genSetReg(second_elem_ptr_reg, Type.usize, .{ .register_offset = .{
                .reg = try self.copyToTmpRegister(Type.usize, ptr),
                .off = elem_abi_size,
            } });

            try self.genBinOpMir(.sub, Type.usize, len_mcv, .{ .immediate = 1 });
            try self.asmRegisterRegisterImmediate(.imul, len_reg, len_reg, Immediate.u(elem_abi_size));
            try self.genInlineMemcpy(second_elem_ptr_mcv, ptr, len_mcv);

            try self.performReloc(skip_reloc);
        },
        .One => {
            var elem_ptr_pl = Type.Payload.ElemType{
                .base = .{ .tag = .single_mut_pointer },
                .data = elem_ty,
            };
            const elem_ptr_ty = Type.initPayload(&elem_ptr_pl.base);

            const len = dst_ptr_ty.childType().arrayLen();

            assert(len != 0); // prevented by Sema
            try self.store(elem_ptr_ty, dst_ptr, src_val);

            const second_elem_ptr_reg = try self.register_manager.allocReg(null, gp);
            const second_elem_ptr_mcv: MCValue = .{ .register = second_elem_ptr_reg };
            const second_elem_ptr_lock = self.register_manager.lockRegAssumeUnused(second_elem_ptr_reg);
            defer self.register_manager.unlockReg(second_elem_ptr_lock);

            try self.genSetReg(second_elem_ptr_reg, Type.usize, .{ .register_offset = .{
                .reg = try self.copyToTmpRegister(Type.usize, dst_ptr),
                .off = elem_abi_size,
            } });

            const bytes_to_copy: MCValue = .{ .immediate = elem_abi_size * (len - 1) };
            try self.genInlineMemcpy(second_elem_ptr_mcv, dst_ptr, bytes_to_copy);
        },
        .C, .Many => unreachable,
    }

    return self.finishAir(inst, .unreach, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airMemcpy(self: *Self, inst: Air.Inst.Index) !void {
    const bin_op = self.air.instructions.items(.data)[inst].bin_op;

    const dst_ptr = try self.resolveInst(bin_op.lhs);
    const dst_ptr_ty = self.air.typeOf(bin_op.lhs);
    const dst_ptr_lock: ?RegisterLock = switch (dst_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (dst_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const src_ptr = try self.resolveInst(bin_op.rhs);
    const src_ptr_lock: ?RegisterLock = switch (src_ptr) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (src_ptr_lock) |lock| self.register_manager.unlockReg(lock);

    const len: MCValue = switch (dst_ptr_ty.ptrSize()) {
        .Slice => dst_ptr.address().offset(8).deref(),
        .One => .{ .immediate = dst_ptr_ty.childType().arrayLen() },
        .C, .Many => unreachable,
    };
    const len_lock: ?RegisterLock = switch (len) {
        .register => |reg| self.register_manager.lockRegAssumeUnused(reg),
        else => null,
    };
    defer if (len_lock) |lock| self.register_manager.unlockReg(lock);

    // TODO: dst_ptr and src_ptr could be slices rather than raw pointers
    try self.genInlineMemcpy(dst_ptr, src_ptr, len);

    return self.finishAir(inst, .unreach, .{ bin_op.lhs, bin_op.rhs, .none });
}

fn airTagName(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.options.module.?;
    const un_op = self.air.instructions.items(.data)[inst].un_op;
    const inst_ty = self.air.typeOfIndex(inst);
    const enum_ty = self.air.typeOf(un_op);

    // We need a properly aligned and sized call frame to be able to call this function.
    {
        const needed_call_frame = FrameAlloc.init(.{
            .size = inst_ty.abiSize(self.target.*),
            .alignment = inst_ty.abiAlignment(self.target.*),
        });
        const frame_allocs_slice = self.frame_allocs.slice();
        const stack_frame_size =
            &frame_allocs_slice.items(.abi_size)[@enumToInt(FrameIndex.call_frame)];
        stack_frame_size.* = @max(stack_frame_size.*, needed_call_frame.abi_size);
        const stack_frame_align =
            &frame_allocs_slice.items(.abi_align)[@enumToInt(FrameIndex.call_frame)];
        stack_frame_align.* = @max(stack_frame_align.*, needed_call_frame.abi_align);
    }

    try self.spillEflagsIfOccupied();
    try self.spillRegisters(abi.getCallerPreservedRegs(self.target.*));

    const param_regs = abi.getCAbiIntParamRegs(self.target.*);

    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.genSetReg(param_regs[0], Type.usize, dst_mcv.address());

    const operand = try self.resolveInst(un_op);
    try self.genSetReg(param_regs[1], enum_ty, operand);

    try self.genLazySymbolRef(
        .call,
        .rax,
        link.File.LazySymbol.initDecl(.code, enum_ty.getOwnerDecl(), mod),
    );

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airErrorName(self: *Self, inst: Air.Inst.Index) !void {
    const mod = self.bin_file.options.module.?;
    const un_op = self.air.instructions.items(.data)[inst].un_op;

    const err_ty = self.air.typeOf(un_op);
    const err_mcv = try self.resolveInst(un_op);
    const err_reg = try self.copyToTmpRegister(err_ty, err_mcv);
    const err_lock = self.register_manager.lockRegAssumeUnused(err_reg);
    defer self.register_manager.unlockReg(err_lock);

    const addr_reg = try self.register_manager.allocReg(null, gp);
    const addr_lock = self.register_manager.lockRegAssumeUnused(addr_reg);
    defer self.register_manager.unlockReg(addr_lock);
    try self.genLazySymbolRef(.lea, addr_reg, link.File.LazySymbol.initDecl(.const_data, null, mod));

    const start_reg = try self.register_manager.allocReg(null, gp);
    const start_lock = self.register_manager.lockRegAssumeUnused(start_reg);
    defer self.register_manager.unlockReg(start_lock);

    const end_reg = try self.register_manager.allocReg(null, gp);
    const end_lock = self.register_manager.lockRegAssumeUnused(end_reg);
    defer self.register_manager.unlockReg(end_lock);

    try self.truncateRegister(err_ty, err_reg.to32());

    try self.asmRegisterMemory(
        .mov,
        start_reg.to32(),
        Memory.sib(.dword, .{
            .base = .{ .reg = addr_reg.to64() },
            .scale_index = .{ .scale = 4, .index = err_reg.to64() },
            .disp = 4,
        }),
    );
    try self.asmRegisterMemory(
        .mov,
        end_reg.to32(),
        Memory.sib(.dword, .{
            .base = .{ .reg = addr_reg.to64() },
            .scale_index = .{ .scale = 4, .index = err_reg.to64() },
            .disp = 8,
        }),
    );
    try self.asmRegisterRegister(.sub, end_reg.to32(), start_reg.to32());
    try self.asmRegisterMemory(
        .lea,
        start_reg.to64(),
        Memory.sib(.byte, .{
            .base = .{ .reg = addr_reg.to64() },
            .scale_index = .{ .scale = 1, .index = start_reg.to64() },
            .disp = 0,
        }),
    );
    try self.asmRegisterMemory(
        .lea,
        end_reg.to32(),
        Memory.sib(.byte, .{
            .base = .{ .reg = end_reg.to64() },
            .disp = -1,
        }),
    );

    const dst_mcv = try self.allocRegOrMem(inst, false);
    try self.asmMemoryRegister(
        .mov,
        Memory.sib(.qword, .{
            .base = .{ .frame = dst_mcv.load_frame.index },
            .disp = dst_mcv.load_frame.off,
        }),
        start_reg.to64(),
    );
    try self.asmMemoryRegister(
        .mov,
        Memory.sib(.qword, .{
            .base = .{ .frame = dst_mcv.load_frame.index },
            .disp = dst_mcv.load_frame.off + 8,
        }),
        end_reg.to64(),
    );

    return self.finishAir(inst, dst_mcv, .{ un_op, .none, .none });
}

fn airSplat(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airSplat for x86_64", .{});
    //return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airSelect(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    _ = extra;
    return self.fail("TODO implement airSelect for x86_64", .{});
    //return self.finishAir(inst, result, .{ pl_op.operand, extra.lhs, extra.rhs });
}

fn airShuffle(self: *Self, inst: Air.Inst.Index) !void {
    const ty_op = self.air.instructions.items(.data)[inst].ty_op;
    _ = ty_op;
    return self.fail("TODO implement airShuffle for x86_64", .{});
    //return self.finishAir(inst, result, .{ ty_op.operand, .none, .none });
}

fn airReduce(self: *Self, inst: Air.Inst.Index) !void {
    const reduce = self.air.instructions.items(.data)[inst].reduce;
    _ = reduce;
    return self.fail("TODO implement airReduce for x86_64", .{});
    //return self.finishAir(inst, result, .{ reduce.operand, .none, .none });
}

fn airAggregateInit(self: *Self, inst: Air.Inst.Index) !void {
    const result_ty = self.air.typeOfIndex(inst);
    const len = @intCast(usize, result_ty.arrayLen());
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const elements = @ptrCast([]const Air.Inst.Ref, self.air.extra[ty_pl.payload..][0..len]);
    const result: MCValue = result: {
        switch (result_ty.zigTypeTag()) {
            .Struct => {
                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initType(result_ty, self.target.*));
                if (result_ty.containerLayout() == .Packed) {
                    const struct_obj = result_ty.castTag(.@"struct").?.data;
                    try self.genInlineMemset(
                        .{ .lea_frame = .{ .index = frame_index } },
                        .{ .immediate = 0 },
                        .{ .immediate = result_ty.abiSize(self.target.*) },
                    );
                    for (elements, 0..) |elem, elem_i| {
                        if (result_ty.structFieldValueComptime(elem_i) != null) continue;

                        const elem_ty = result_ty.structFieldType(elem_i);
                        const elem_bit_size = @intCast(u32, elem_ty.bitSize(self.target.*));
                        if (elem_bit_size > 64) {
                            return self.fail(
                                "TODO airAggregateInit implement packed structs with large fields",
                                .{},
                            );
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
                            .{ .load_frame = .{ .index = frame_index, .off = elem_byte_off } },
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
                                .{ .load_frame = .{
                                    .index = frame_index,
                                    .off = elem_byte_off + @intCast(i32, elem_abi_size),
                                } },
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
                    try self.genSetMem(.{ .frame = frame_index }, elem_off, elem_ty, mat_elem_mcv);
                }
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            .Array => {
                const frame_index =
                    try self.allocFrameIndex(FrameAlloc.initType(result_ty, self.target.*));
                const elem_ty = result_ty.childType();
                const elem_size = @intCast(u32, elem_ty.abiSize(self.target.*));

                for (elements, 0..) |elem, elem_i| {
                    const elem_mcv = try self.resolveInst(elem);
                    const mat_elem_mcv = switch (elem_mcv) {
                        .load_tlv => |sym_index| MCValue{ .lea_tlv = sym_index },
                        else => elem_mcv,
                    };
                    const elem_off = @intCast(i32, elem_size * elem_i);
                    try self.genSetMem(.{ .frame = frame_index }, elem_off, elem_ty, mat_elem_mcv);
                }
                break :result .{ .load_frame = .{ .index = frame_index } };
            },
            .Vector => return self.fail("TODO implement aggregate_init for vectors", .{}),
            else => unreachable,
        }
    };

    if (elements.len <= Liveness.bpi - 1) {
        var buf = [1]Air.Inst.Ref{.none} ** (Liveness.bpi - 1);
        @memcpy(buf[0..elements.len], elements);
        return self.finishAir(inst, result, buf);
    }
    var bt = self.liveness.iterateBigTomb(inst);
    for (elements) |elem| self.feed(&bt, elem);
    return self.finishAirResult(inst, result);
}

fn airUnionInit(self: *Self, inst: Air.Inst.Index) !void {
    const ty_pl = self.air.instructions.items(.data)[inst].ty_pl;
    const extra = self.air.extraData(Air.UnionInit, ty_pl.payload).data;
    _ = extra;
    return self.fail("TODO implement airUnionInit for x86_64", .{});
    //return self.finishAir(inst, result, .{ extra.init, .none, .none });
}

fn airPrefetch(self: *Self, inst: Air.Inst.Index) !void {
    const prefetch = self.air.instructions.items(.data)[inst].prefetch;
    return self.finishAir(inst, .unreach, .{ prefetch.ptr, .none, .none });
}

fn airMulAdd(self: *Self, inst: Air.Inst.Index) !void {
    const pl_op = self.air.instructions.items(.data)[inst].pl_op;
    const extra = self.air.extraData(Air.Bin, pl_op.payload).data;
    _ = extra;
    return self.fail("TODO implement airMulAdd for x86_64", .{});
    //return self.finishAir(inst, result, .{ extra.lhs, extra.rhs, pl_op.operand });
}

fn resolveInst(self: *Self, ref: Air.Inst.Ref) InnerError!MCValue {
    const ty = self.air.typeOf(ref);

    // If the type has no codegen bits, no need to store it.
    if (!ty.hasRuntimeBitsIgnoreComptime()) return .none;

    if (Air.refToIndex(ref)) |inst| {
        const mcv = switch (self.air.instructions.items(.tag)[inst]) {
            .constant => tracking: {
                const gop = try self.const_tracking.getOrPut(self.gpa, inst);
                if (!gop.found_existing) gop.value_ptr.* = InstTracking.init(try self.genTypedValue(.{
                    .ty = ty,
                    .val = self.air.value(ref).?,
                }));
                break :tracking gop.value_ptr;
            },
            .const_ty => unreachable,
            else => self.inst_tracking.getPtr(inst).?,
        }.short;
        switch (mcv) {
            .none, .unreach, .dead => unreachable,
            else => return mcv,
        }
    }

    return self.genTypedValue(.{ .ty = ty, .val = self.air.value(ref).? });
}

fn getResolvedInstValue(self: *Self, inst: Air.Inst.Index) *InstTracking {
    const tracking = switch (self.air.instructions.items(.tag)[inst]) {
        .constant => &self.const_tracking,
        .const_ty => unreachable,
        else => &self.inst_tracking,
    }.getPtr(inst).?;
    return switch (tracking.short) {
        .none, .unreach, .dead => unreachable,
        else => tracking,
    };
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
    return switch (try codegen.genTypedValue(self.bin_file, self.src_loc, arg_tv, self.owner.getDecl())) {
        .mcv => |mcv| switch (mcv) {
            .none => .none,
            .undef => .undef,
            .immediate => |imm| .{ .immediate = imm },
            .memory => |addr| .{ .memory = addr },
            .load_direct => |sym_index| .{ .load_direct = sym_index },
            .load_got => |sym_index| .{ .lea_got = sym_index },
            .load_tlv => |sym_index| .{ .lea_tlv = sym_index },
        },
        .fail => |msg| {
            self.err_msg = msg;
            return error.CodegenFail;
        },
    };
}

const CallMCValues = struct {
    args: []MCValue,
    return_value: InstTracking,
    stack_byte_count: u31,
    stack_align: u31,

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
    stack_frame_base: FrameIndex,
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
        .stack_byte_count = 0,
        .stack_align = undefined,
    };
    errdefer self.gpa.free(result.args);

    const ret_ty = fn_ty.fnReturnType();

    switch (cc) {
        .Naked => {
            assert(result.args.len == 0);
            result.return_value = InstTracking.init(.unreach);
            result.stack_align = 8;
        },
        .C => {
            var param_reg_i: usize = 0;
            var param_sse_reg_i: usize = 0;
            result.stack_align = 16;

            switch (self.target.os.tag) {
                .windows => {
                    // Align the stack to 16bytes before allocating shadow stack space (if any).
                    result.stack_byte_count += @intCast(u31, 4 * Type.usize.abiSize(self.target.*));
                },
                else => {},
            }

            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = InstTracking.init(.unreach);
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
                // TODO: is this even possible for C calling convention?
                result.return_value = InstTracking.init(.none);
            } else {
                const classes = switch (self.target.os.tag) {
                    .windows => &[1]abi.Class{abi.classifyWindows(ret_ty, self.target.*)},
                    else => mem.sliceTo(&abi.classifySystemV(ret_ty, self.target.*, .ret), .none),
                };
                if (classes.len > 1) {
                    return self.fail("TODO handle multiple classes per type", .{});
                }
                const ret_reg = abi.getCAbiIntReturnRegs(self.target.*)[0];
                result.return_value = switch (classes[0]) {
                    .integer => InstTracking.init(.{ .register = registerAlias(
                        ret_reg,
                        @intCast(u32, ret_ty.abiSize(self.target.*)),
                    ) }),
                    .float, .sse => InstTracking.init(.{ .register = .xmm0 }),
                    .memory => ret: {
                        const ret_indirect_reg = abi.getCAbiIntParamRegs(self.target.*)[param_reg_i];
                        param_reg_i += 1;
                        break :ret .{
                            .short = .{ .indirect = .{ .reg = ret_reg } },
                            .long = .{ .indirect = .{ .reg = ret_indirect_reg } },
                        };
                    },
                    else => |class| return self.fail("TODO handle calling convention class {s}", .{
                        @tagName(class),
                    }),
                };
            }

            // Input params
            for (param_types, result.args) |ty, *arg| {
                assert(ty.hasRuntimeBitsIgnoreComptime());

                const classes = switch (self.target.os.tag) {
                    .windows => &[1]abi.Class{abi.classifyWindows(ty, self.target.*)},
                    else => mem.sliceTo(&abi.classifySystemV(ty, self.target.*, .arg), .none),
                };
                if (classes.len > 1) {
                    return self.fail("TODO handle multiple classes per type", .{});
                }
                switch (classes[0]) {
                    .integer => if (param_reg_i < abi.getCAbiIntParamRegs(self.target.*).len) {
                        arg.* = .{ .register = abi.getCAbiIntParamRegs(self.target.*)[param_reg_i] };
                        param_reg_i += 1;
                        continue;
                    },
                    .float, .sse => switch (self.target.os.tag) {
                        .windows => if (param_reg_i < 4) {
                            arg.* = .{ .register = @intToEnum(
                                Register,
                                @enumToInt(Register.xmm0) + param_reg_i,
                            ) };
                            param_reg_i += 1;
                            continue;
                        },
                        else => if (param_sse_reg_i < 8) {
                            arg.* = .{ .register = @intToEnum(
                                Register,
                                @enumToInt(Register.xmm0) + param_sse_reg_i,
                            ) };
                            param_sse_reg_i += 1;
                            continue;
                        },
                    },
                    .memory => {}, // fallthrough
                    else => |class| return self.fail("TODO handle calling convention class {s}", .{
                        @tagName(class),
                    }),
                }

                const param_size = @intCast(u31, ty.abiSize(self.target.*));
                const param_align = @intCast(u31, ty.abiAlignment(self.target.*));
                result.stack_byte_count =
                    mem.alignForwardGeneric(u31, result.stack_byte_count, param_align);
                arg.* = .{ .load_frame = .{
                    .index = stack_frame_base,
                    .off = result.stack_byte_count,
                } };
                result.stack_byte_count += param_size;
            }
        },
        .Unspecified => {
            result.stack_align = 16;

            // Return values
            if (ret_ty.zigTypeTag() == .NoReturn) {
                result.return_value = InstTracking.init(.unreach);
            } else if (!ret_ty.hasRuntimeBitsIgnoreComptime()) {
                result.return_value = InstTracking.init(.none);
            } else {
                const ret_reg = abi.getCAbiIntReturnRegs(self.target.*)[0];
                const ret_ty_size = @intCast(u31, ret_ty.abiSize(self.target.*));
                if (ret_ty_size <= 8 and !ret_ty.isRuntimeFloat()) {
                    const aliased_reg = registerAlias(ret_reg, ret_ty_size);
                    result.return_value = .{ .short = .{ .register = aliased_reg }, .long = .none };
                } else {
                    const ret_indirect_reg = abi.getCAbiIntParamRegs(self.target.*)[0];
                    result.return_value = .{
                        .short = .{ .indirect = .{ .reg = ret_reg } },
                        .long = .{ .indirect = .{ .reg = ret_indirect_reg } },
                    };
                }
            }

            // Input params
            for (param_types, result.args) |ty, *arg| {
                if (!ty.hasRuntimeBitsIgnoreComptime()) {
                    arg.* = .none;
                    continue;
                }
                const param_size = @intCast(u31, ty.abiSize(self.target.*));
                const param_align = @intCast(u31, ty.abiAlignment(self.target.*));
                result.stack_byte_count =
                    mem.alignForwardGeneric(u31, result.stack_byte_count, param_align);
                arg.* = .{ .load_frame = .{
                    .index = stack_frame_base,
                    .off = result.stack_byte_count,
                } };
                result.stack_byte_count += param_size;
            }
        },
        else => return self.fail("TODO implement function parameters and return values for {} on x86_64", .{cc}),
    }

    result.stack_byte_count = mem.alignForwardGeneric(u31, result.stack_byte_count, result.stack_align);
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
    const abi_size = ty.abiSize(self.target.*);
    return switch (ty.zigTypeTag()) {
        else => switch (abi_size) {
            1 => 8,
            2 => 16,
            3...4 => 32,
            5...8 => 64,
            else => unreachable,
        },
        .Float => switch (abi_size) {
            1...16 => 128,
            17...32 => 256,
            else => unreachable,
        },
    };
}

fn regExtraBits(self: *Self, ty: Type) u64 {
    return self.regBitSize(ty) - ty.bitSize(self.target.*);
}
