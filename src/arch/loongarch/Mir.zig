//! Machine Intermediate Representation.
//! This data is produced by CodeGen.zig

const Mir = @This();
const std = @import("std");
const Writer = std.Io.Writer;

const bits = @import("bits.zig");
const Register = bits.Register;
const Lir = @import("Lir.zig");
const encoding = @import("encoding.zig");
const Emit = @import("Emit.zig");

const InternPool = @import("../../InternPool.zig");
const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");

instructions: std.MultiArrayList(Inst).Slice,
frame_locs: std.MultiArrayList(FrameLoc).Slice,
frame_size: usize,
/// The first instruction of epilogue.
epilogue_begin: Inst.Index,
/// Indicates that $ra needs to be spilled.
spill_ra: bool,

pub const Inst = struct {
    tag: Tag,
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Index = u32;

    pub const Tag = enum(u16) {
        _,

        pub fn fromInst(opcode: encoding.OpCode) Tag {
            return @enumFromInt(@intFromEnum(opcode));
        }

        pub fn fromPseudo(tag: PseudoTag) Tag {
            return @enumFromInt(@as(u16, @intFromEnum(tag)) | (1 << 15));
        }

        pub fn unwrap(tag: Tag) union(enum) { pseudo: PseudoTag, inst: encoding.OpCode } {
            if ((@intFromEnum(tag) & (1 << 15)) != 0) {
                return .{ .pseudo = @enumFromInt(@intFromEnum(tag) & ~@as(u16, @intCast((1 << 15)))) };
            } else {
                return .{ .inst = @enumFromInt(@intFromEnum(tag)) };
            }
        }
    };

    pub const PseudoTag = enum {
        /// Placeholder for backpatch or dead. No payload.
        none,

        /// Branch instructions, uses `br` payload.
        branch,
        /// Load an 64-bit immediate to register, uses `imm_reg` payload.
        imm_to_reg,
        /// Load frame address to register, uses `frame_reg` payload.
        frame_addr_to_reg,
        /// Frame memory load/store operations, uses `memop_frame_reg` payload.
        frame_addr_reg_mem,
        /// NAV memory load/store operations, uses `memop_nav_reg` payload.
        nav_memop,
        /// UAV memory load/store operations, uses `memop_uav_reg` payload.
        uav_memop,
        /// Load NAV address to register, uses `nav_reg` payload.
        nav_addr_to_reg,
        /// Load UAV address to register, uses `uav_reg` payload.
        uav_addr_to_reg,
        /// Function call, uses `nav` payload.
        call,
        /// Loads spilled $ra back to $ra, no payload.
        load_ra,

        /// Prologue of a function, no payload.
        func_prologue,
        /// Epilogue of a function, no payload.
        func_epilogue,
        /// Jump to epilogue, no payload.
        jump_to_epilogue,
        /// Spills general-purpose integer registers, uses `reg_list` payload.
        spill_int_regs,
        /// Restores general-purpose integer registers, uses `reg_list` payload.
        restore_int_regs,
        /// Spills general-purpose float registers, uses `reg_list` payload.
        spill_float_regs,
        /// Restores general-purpose float registers, uses `reg_list` payload.
        restore_float_regs,

        /// Update debug line with is_stmt register set, uses `line_column` payload.
        dbg_line_stmt_line_column,
        /// Update debug line with is_stmt register clear, uses `line_column` payload.
        dbg_line_line_column,
        /// Start of lexical block, no payload.
        dbg_enter_block,
        /// End of lexical block, no payload.
        dbg_exit_block,
        /// Start of inline function block, uses `func` payload.
        /// Payload points to the inlined function.
        dbg_enter_inline_func,
        /// End of inline function block, uses `func` payload.
        /// Payload points to the outer function.
        dbg_exit_inline_func,
    };

    pub const Data = union {
        pub const none = undefined;

        op: encoding.Data,

        /// Register list.
        reg_list: RegisterList,
        /// Debug line and column position.
        line_column: struct {
            line: u32,
            column: u32,
        },
        /// Branches.
        br: struct {
            inst: Index,
            cond: BranchCondition,
        },
        /// Immediate and register
        imm_reg: struct {
            imm: u64,
            reg: Register,
        },
        /// Frame address and register
        frame_reg: struct {
            frame: bits.FrameAddr,
            reg: Register,
        },
        /// Mem op, frame address and register
        memop_frame_reg: struct {
            op: Lir.SizedMemOp,
            frame: bits.FrameAddr,
            reg: Register,
            tmp_reg: Register,
        },
        /// Mem op, NAV offset and register
        memop_nav_reg: struct {
            op: Lir.SizedMemOp,
            nav: bits.NavOffset,
            reg: Register,
            tmp_reg: Register,
        },
        /// Mem op, UAV offset and register
        memop_uav_reg: struct {
            op: Lir.SizedMemOp,
            uav: bits.UavOffset,
            reg: Register,
            tmp_reg: Register,
        },
        /// NAV offset and register
        nav_reg: struct {
            nav: bits.NavOffset,
            reg: Register,
        },
        /// UAV offset and register
        uav_reg: struct {
            uav: bits.UavOffset,
            reg: Register,
        },
        /// NAV offset
        nav: bits.NavOffset,
        /// Function index
        func: InternPool.Index,
    };

    pub inline fn initInst(inst: encoding.Inst) Inst {
        const lir_inst = Lir.Inst.fromInst(inst);
        return .{ .tag = .fromInst(lir_inst.opcode), .data = .{ .op = lir_inst.data } };
    }

    pub fn format(inst: Inst, writer: *Writer) Writer.Error!void {
        switch (inst.tag.unwrap()) {
            .pseudo => |tag| {
                switch (tag) {
                    .dbg_line_stmt_line_column, .dbg_line_line_column => try writer.print(".{s} L{d}:{d}", .{
                        @tagName(tag),
                        inst.data.line_column.line,
                        inst.data.line_column.column,
                    }),
                    .branch => try writer.print(".branch {f} => {}", .{ inst.data.br.cond, inst.data.br.inst }),
                    .imm_to_reg => try writer.print(".imm_to_reg {s} <== {}", .{
                        @tagName(inst.data.imm_reg.reg),
                        inst.data.imm_reg.imm,
                    }),
                    .frame_addr_to_reg => try writer.print(".frame_addr_to_reg {s} <== {f}", .{
                        @tagName(inst.data.frame_reg.reg),
                        inst.data.frame_reg.frame,
                    }),
                    .frame_addr_reg_mem => try writer.print(".frame_addr_reg_mem {f} {s} (tmp {s}), {f}", .{
                        inst.data.memop_frame_reg.op,
                        @tagName(inst.data.memop_frame_reg.reg),
                        @tagName(inst.data.memop_frame_reg.tmp_reg),
                        inst.data.memop_frame_reg.frame,
                    }),
                    .nav_memop => try writer.print(".nav_memop {f} {s} (tmp {s}), {} + 0x{x}", .{
                        inst.data.memop_nav_reg.op,
                        @tagName(inst.data.memop_nav_reg.reg),
                        @tagName(inst.data.memop_nav_reg.tmp_reg),
                        inst.data.memop_nav_reg.nav.index,
                        inst.data.memop_nav_reg.nav.off,
                    }),
                    .uav_memop => try writer.print(".uav_memop {f} {s} (tmp {s}), {} + 0x{x}", .{
                        inst.data.memop_uav_reg.op,
                        @tagName(inst.data.memop_uav_reg.reg),
                        @tagName(inst.data.memop_uav_reg.tmp_reg),
                        inst.data.memop_uav_reg.uav.index,
                        inst.data.memop_uav_reg.uav.off,
                    }),
                    .nav_addr_to_reg => try writer.print(".nav_addr_to_reg {} + 0x{x} => {s}", .{
                        inst.data.nav_reg.nav.index,
                        inst.data.nav_reg.nav.off,
                        @tagName(inst.data.nav_reg.reg),
                    }),
                    .uav_addr_to_reg => try writer.print(".uav_addr_to_reg {} + 0x{x} => {s}", .{
                        inst.data.uav_reg.uav.index,
                        inst.data.uav_reg.uav.off,
                        @tagName(inst.data.uav_reg.reg),
                    }),
                    .call => try writer.print(".call nav:{} + 0x{x}", .{ inst.data.nav.index, inst.data.nav.off }),
                    .spill_int_regs => try writer.print(".spill_int_regs {f}", .{inst.data.reg_list.fmt(.int)}),
                    .spill_float_regs => try writer.print(".spill_float_regs {f}", .{inst.data.reg_list.fmt(.float)}),
                    .restore_int_regs => try writer.print(".restore_int_regs {f}", .{inst.data.reg_list.fmt(.int)}),
                    .restore_float_regs => try writer.print(".restore_float_regs {f}", .{inst.data.reg_list.fmt(.float)}),
                    .dbg_enter_inline_func, .dbg_exit_inline_func => try writer.print(".{s} {}", .{ @tagName(tag), inst.data.func }),
                    else => try writer.print(".{s}", .{@tagName(tag)}),
                }
            },
            .inst => |opcode| {
                try writer.print("{f}", .{Lir.Inst{ .opcode = opcode, .data = inst.data.op }});
            },
        }
    }
};

comptime {
    // Be careful with memory usage when making instruction data larger.
    std.debug.assert(@sizeOf(Inst.Data) <= 24);
}

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    mir.frame_locs.deinit(gpa);
    mir.* = undefined;
}

pub fn emit(
    mir: Mir,
    lf: *link.File,
    pt: Zcu.PerThread,
    src_loc: Zcu.LazySrcLoc,
    func_index: InternPool.Index,
    code: *std.ArrayListUnmanaged(u8),
    debug_output: link.File.DebugInfoOutput,
) codegen.CodeGenError!void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = comp.gpa;
    const func = zcu.funcInfo(func_index);
    const fn_info = zcu.typeToFunc(.fromInterned(func.ty)).?;
    const nav = func.owner_nav;
    const mod = zcu.navFileScope(nav).mod.?;

    var emitter: Emit = .{
        .lower = .{
            .pt = pt,
            .link_file = lf,
            .target = &mod.resolved_target.result,
            .allocator = gpa,
            .mir = mir,
            .cc = fn_info.cc,
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .pt = pt,
        .bin_file = lf,
        .owner_nav = nav,
        .atom_index = sym: {
            if (lf.cast(.elf)) |ef| break :sym try ef.zigObjectPtr().?.getOrCreateMetadataForNav(zcu, nav);
            unreachable;
        },
        .debug_output = debug_output,
        .code = code,
        .prev_di_loc = .{
            .line = func.lbrace_line,
            .column = func.lbrace_column,
            .is_stmt = switch (debug_output) {
                .dwarf => |dwarf| dwarf.dwarf.debug_line.header.default_is_stmt,
                .plan9 => undefined,
                .none => undefined,
            },
        },
        .prev_di_pc = 0,
    };
    emitter.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return zcu.codegenFailMsg(nav, emitter.lower.err_msg.?),
        else => |e| return zcu.codegenFail(nav, "emit MIR failed: {s} (Zig compiler bug)", .{@errorName(e)}),
    };
}

pub const FrameLoc = struct {
    base: Register,
    offset: i32,

    pub fn format(loc: FrameLoc, writer: *Writer) Writer.Error!void {
        if (loc.offset >= 0) {
            try writer.print("{s} + 0x{x}", .{ @tagName(loc.base), loc.offset });
        } else {
            try writer.print("{s} - 0x{x}", .{ @tagName(loc.base), -loc.offset });
        }
    }
};

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet,

    const BitSet = std.bit_set.StaticBitSet(32);
    const Self = @This();

    pub const empty: Self = .{ .bitset = .initEmpty() };

    pub fn getRegFromIndex(rc: Register.Class, reg: usize) Register {
        return .fromClass(rc, @intCast(reg));
    }

    pub fn push(self: *Self, reg: Register) void {
        self.bitset.set(reg.enc());
    }

    pub fn isSet(self: Self, reg: Register) bool {
        return self.bitset.isSet(reg.enc());
    }

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
    }

    pub fn count(self: Self) usize {
        return self.bitset.count();
    }

    const FormatData = struct {
        regs: *const RegisterList,
        rc: Register.Class,
    };
    fn format2(data: FormatData, writer: *Writer) Writer.Error!void {
        var iter = data.regs.iterator(.{});
        var reg_i: usize = 0;
        while (iter.next()) |reg| {
            if (reg_i != 0) try writer.writeAll(" ");
            reg_i += 1;
            try writer.writeAll(@tagName(Register.fromClass(data.rc, @intCast(reg))));
        }
    }
    fn fmt(regs: *const RegisterList, rc: Register.Class) std.fmt.Formatter(FormatData, format2) {
        return .{ .data = .{ .regs = regs, .rc = rc } };
    }
};

pub const BranchCondition = union(enum) {
    none,
    eq: struct { Register, Register },
    ne: struct { Register, Register },
    le: struct { Register, Register },
    gt: struct { Register, Register },
    leu: struct { Register, Register },
    gtu: struct { Register, Register },

    pub const Tag = std.meta.Tag(BranchCondition);

    pub fn format(inst: BranchCondition, writer: *Writer) Writer.Error!void {
        switch (inst) {
            .none => try writer.print("(unconditionally)", .{}),
            inline .eq, .ne, .le, .gt, .leu, .gtu => |regs| {
                const op = switch (inst) {
                    .eq => "==",
                    .ne => "!=",
                    .le => "<=",
                    .gt => ">",
                    .leu => "<= (unsigned)",
                    .gtu => "> (unsigned)",
                    else => unreachable,
                };
                try writer.print("{s} {s} {s}", .{ @tagName(regs[0]), op, @tagName(regs[1]) });
            },
        }
    }

    pub fn compare(tag: Tag, lhs: Register, rhs: Register) BranchCondition {
        return switch (tag) {
            .none => .none,
            .eq => .{ .eq = .{ lhs, rhs } },
            .ne => .{ .ne = .{ lhs, rhs } },
            .le => .{ .le = .{ lhs, rhs } },
            .gt => .{ .gt = .{ lhs, rhs } },
            .leu => .{ .leu = .{ lhs, rhs } },
            .gtu => .{ .gtu = .{ lhs, rhs } },
        };
    }
};
