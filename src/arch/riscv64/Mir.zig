//! Machine Intermediate Representation.
//! This data is produced by RISCV64 Codegen or RISCV64 assembly parsing
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Tag,
    data: Data,
    ops: Ops,

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    pub const Tag = enum(u16) {

        // base extension
        addi,
        addiw,

        jalr,
        lui,

        @"and",
        andi,

        xori,
        xor,
        @"or",

        ebreak,
        ecall,
        unimp,

        add,
        addw,
        sub,
        subw,

        sltu,
        slt,

        slli,
        srli,
        srai,

        slliw,
        srliw,
        sraiw,

        sll,
        srl,
        sra,

        sllw,
        srlw,
        sraw,

        jal,

        beq,
        bne,

        nop,

        ld,
        lw,
        lh,
        lb,

        sd,
        sw,
        sh,
        sb,

        // M extension
        mul,
        mulw,

        div,
        divu,
        divw,
        divuw,

        rem,
        remu,
        remw,
        remuw,

        // F extension (32-bit float)
        fadds,
        fsubs,
        fmuls,
        fdivs,

        fabss,

        fmins,
        fmaxs,

        fsqrts,

        flw,
        fsw,

        feqs,
        flts,
        fles,

        // D extension (64-bit float)
        faddd,
        fsubd,
        fmuld,
        fdivd,

        fabsd,

        fmind,
        fmaxd,

        fsqrtd,

        fld,
        fsd,

        feqd,
        fltd,
        fled,

        // Zicsr Extension Instructions
        csrrs,

        // V Extension Instructions
        vsetvli,
        vsetivli,
        vsetvl,
        vaddvv,

        // A Extension Instructions
        amo,

        /// A pseudo-instruction. Used for anything that isn't 1:1 with an
        /// assembly instruction.
        pseudo,
    };

    /// All instructions have a 4-byte payload, which is contained within
    /// this union. `Ops` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        nop: void,
        inst: Index,
        payload: u32,
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
        pseudo_dbg_line_column: struct {
            line: u32,
            column: u32,
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
        fabs: struct {
            rd: Register,
            rs: Register,
            bits: u16,
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
            atom_index: u32,
            sym_index: u32,
        },
        fence: struct {
            pred: Barrier,
            succ: Barrier,
            fm: enum {
                none,
                tso,
            },
        },
        amo: struct {
            rd: Register,
            rs1: Register,
            rs2: Register,
            aq: Barrier,
            rl: Barrier,
            op: AmoOp,
            ty: Type,
        },
        csr: struct {
            csr: CSR,
            rs1: Register,
            rd: Register,
        },
    };

    pub const Ops = enum {
        /// No data associated with this instruction (only mnemonic is used).
        none,
        /// Two registers
        rr,
        /// Three registers
        rrr,

        /// Two registers + immediate, uses the i_type payload.
        rri,
        //extern_fn_reloc/ Two registers + another instruction.
        rr_inst,

        /// Register + Memory
        rm,

        /// Register + Immediate
        ri,

        /// Another instruction.
        inst,

        /// Control and Status Register Instruction.
        csr,

        /// Pseudo-instruction that will generate a backpatched
        /// function prologue.
        pseudo_prologue,
        /// Pseudo-instruction that will generate a backpatched
        /// function epilogue
        pseudo_epilogue,

        /// Pseudo-instruction: End of prologue
        pseudo_dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        pseudo_dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        pseudo_dbg_line_column,

        /// Pseudo-instruction that loads from memory into a register.
        ///
        /// Uses `rm` payload.
        pseudo_load_rm,
        /// Pseudo-instruction that stores from a register into memory
        ///
        /// Uses `rm` payload.
        pseudo_store_rm,

        /// Pseudo-instruction that loads the address of memory into a register.
        ///
        /// Uses `rm` payload.
        pseudo_lea_rm,

        /// Jumps. Uses `inst` payload.
        pseudo_j,

        /// Floating point absolute value.
        pseudo_fabs,

        /// Dead inst, ignored by the emitter.
        pseudo_dead,

        /// Loads the address of a value that hasn't yet been allocated in memory.
        ///
        /// uses the Mir.LoadSymbolPayload payload.
        pseudo_load_symbol,

        /// Moves the value of rs1 to rd.
        ///
        /// uses the `rr` payload.
        pseudo_mv,

        pseudo_restore_regs,
        pseudo_spill_regs,

        pseudo_compare,

        /// NOT operation on booleans. Does an `andi reg, reg, 1` to mask out any other bits from the boolean.
        pseudo_not,

        /// Generates an auipc + jalr pair, with a R_RISCV_CALL_PLT reloc
        pseudo_extern_fn_reloc,

        /// IORW, IORW
        pseudo_fence,

        /// Ordering, Src, Addr, Dest
        pseudo_amo,
    };

    pub fn format(
        inst: Inst,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        assert(fmt.len == 0);
        _ = options;

        try writer.print("Tag: {s}, Ops: {s}", .{ @tagName(inst.tag), @tagName(inst.ops) });
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    mir.frame_locs.deinit(gpa);
    gpa.free(mir.extra);
    mir.* = undefined;
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

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(mir: Mir, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => mir.extra[i],
            i32 => @as(i32, @bitCast(mir.extra[i])),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

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

const assert = std.debug.assert;

const bits = @import("bits.zig");
const Register = bits.Register;
const CSR = bits.CSR;
const Immediate = bits.Immediate;
const Memory = bits.Memory;
const FrameIndex = bits.FrameIndex;
const FrameAddr = @import("CodeGen.zig").FrameAddr;
const IntegerBitSet = std.bit_set.IntegerBitSet;
