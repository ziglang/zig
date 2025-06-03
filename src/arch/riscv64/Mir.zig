//! Machine Intermediate Representation.
//! This data is produced by CodeGen.zig

instructions: std.MultiArrayList(Inst).Slice,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Mnemonic,
    data: Data,

    pub const Index = u32;

    pub const Data = union(enum) {
        none: void,
        r_type: struct {
            rd: Register,
            rs1: Register,
            rs2: Register,
        },
        i_type: struct {
            rd: Register,
            rs1: Register,
            imm12: Immediate,
        },
        s_type: struct {
            rs1: Register,
            rs2: Register,
            imm5: Immediate,
            imm7: Immediate,
        },
        b_type: struct {
            rs1: Register,
            rs2: Register,
            inst: Inst.Index,
        },
        u_type: struct {
            rd: Register,
            imm20: Immediate,
        },
        j_type: struct {
            rd: Register,
            inst: Inst.Index,
        },
        rm: struct {
            r: Register,
            m: Memory,
        },
        reg_list: Mir.RegisterList,
        reg: Register,
        rr: struct {
            rd: Register,
            rs: Register,
        },
        compare: struct {
            rd: Register,
            rs1: Register,
            rs2: Register,
            op: enum {
                eq,
                neq,
                gt,
                gte,
                lt,
                lte,
            },
            ty: Type,
        },
        reloc: struct {
            register: Register,
            atom_index: u32,
            sym_index: u32,
        },
        fence: struct {
            pred: Barrier,
            succ: Barrier,
        },
        amo: struct {
            rd: Register,
            rs1: Register,
            rs2: Register,
            aq: Barrier,
            rl: Barrier,
        },
        csr: struct {
            csr: CSR,
            rs1: Register,
            rd: Register,
        },
        pseudo_dbg_line_column: struct {
            line: u32,
            column: u32,
        },
    };

    pub fn format(inst: Inst, bw: *std.io.Writer, comptime fmt: []const u8) !void {
        assert(fmt.len == 0);
        try bw.print("Tag: {s}, Data: {s}", .{ @tagName(inst.tag), @tagName(inst.data) });
    }
};

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
    var e: Emit = .{
        .lower = .{
            .pt = pt,
            .allocator = gpa,
            .mir = mir,
            .cc = fn_info.cc,
            .src_loc = src_loc,
            .output_mode = comp.config.output_mode,
            .link_mode = comp.config.link_mode,
            .pic = mod.pic,
        },
        .bin_file = lf,
        .debug_output = debug_output,
        .code = code,
        .prev_di_pc = 0,
        .prev_di_line = func.lbrace_line,
        .prev_di_column = func.lbrace_column,
    };
    defer e.deinit();
    e.emitMir() catch |err| switch (err) {
        error.LowerFail, error.EmitFail => return zcu.codegenFailMsg(nav, e.lower.err_msg.?),
        error.InvalidInstruction => return zcu.codegenFail(nav, "emit MIR failed: {s} (Zig compiler bug)", .{@errorName(err)}),
        else => |err1| return err1,
    };
}

pub const FrameLoc = struct {
    base: Register,
    disp: i32,
};

pub const Barrier = enum(u4) {
    // Fence
    w = 0b0001,
    r = 0b0010,
    rw = 0b0011,

    // Amo
    none,
    aq,
    rl,
};

pub const AmoOp = enum(u5) {
    SWAP,
    ADD,
    AND,
    OR,
    XOR,
    MAX,
    MIN,
};

pub const FcvtOp = enum(u5) {
    w = 0b00000,
    wu = 0b00001,
    l = 0b00010,
    lu = 0b00011,
};

pub const LoadSymbolPayload = struct {
    register: u32,
    atom_index: u32,
    sym_index: u32,
};

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet = BitSet.initEmpty(),

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(i);
        }
        unreachable; // register not in input register list!
    }

    pub fn push(self: *Self, registers: []const Register, reg: Register) void {
        const index = getIndexForReg(registers, reg);
        self.bitset.set(index);
    }

    pub fn isSet(self: Self, registers: []const Register, reg: Register) bool {
        const index = getIndexForReg(registers, reg);
        return self.bitset.isSet(index);
    }

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
    }

    pub fn count(self: Self) i32 {
        return @intCast(self.bitset.count());
    }

    pub fn size(self: Self) i32 {
        return @intCast(self.bitset.count() * 8);
    }
};

const Mir = @This();
const std = @import("std");
const builtin = @import("builtin");
const Type = @import("../../Type.zig");
const bits = @import("bits.zig");

const assert = std.debug.assert;

const Register = bits.Register;
const CSR = bits.CSR;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const FrameIndex = bits.FrameIndex;
const FrameAddr = @import("CodeGen.zig").FrameAddr;
const IntegerBitSet = std.bit_set.IntegerBitSet;
const Mnemonic = @import("mnem.zig").Mnemonic;

const InternPool = @import("../../InternPool.zig");
const Emit = @import("Emit.zig");
const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const Zcu = @import("../../Zcu.zig");
