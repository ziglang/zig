//! Machine Intermediate Representation.
//! This data is produced by x86_64 Codegen and consumed by x86_64 Isel.
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

const Mir = @This();
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const bits = @import("bits.zig");
const encoder = @import("encoder.zig");

const Air = @import("../../Air.zig");
const CodeGen = @import("CodeGen.zig");
const IntegerBitSet = std.bit_set.IntegerBitSet;
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

pub const Mnemonic = encoder.Instruction.Mnemonic;
pub const Operand = encoder.Instruction.Operand;

pub const Inst = struct {
    tag: Tag,
    ops: Ops,
    data: Data,

    pub const Index = u32;

    pub const Tag = enum(u8) {
        /// Add with carry
        adc,
        /// Add
        add,
        /// Logical and
        @"and",
        /// Call
        call,
        /// Convert byte to word
        cbw,
        /// Convert word to doubleword
        cwde,
        /// Convert doubleword to quadword
        cdqe,
        /// Convert word to doubleword
        cwd,
        /// Convert doubleword to quadword
        cdq,
        /// Convert doubleword to quadword
        cqo,
        /// Logical compare
        cmp,
        /// Conditional move
        cmovcc,
        /// Unsigned division
        div,
        /// Store integer with truncation
        fisttp,
        /// Load floating-point value
        fld,
        /// Signed division
        idiv,
        /// Signed multiplication
        imul,
        ///
        int3,
        /// Conditional jump
        jcc,
        /// Jump
        jmp,
        /// Load effective address
        lea,
        /// Move
        mov,
        /// Move with sign extension
        movsx,
        /// Move with zero extension
        movzx,
        /// Multiply
        mul,
        /// No-op
        nop,
        /// Logical or
        @"or",
        /// Pop
        pop,
        /// Push
        push,
        /// Return
        ret,
        /// Arithmetic shift left
        sal,
        /// Arithmetic shift right
        sar,
        /// Integer subtraction with borrow
        sbb,
        /// Set byte on condition
        setcc,
        /// Logical shift left
        shl,
        /// Logical shift right
        shr,
        /// Subtract
        sub,
        /// Syscall
        syscall,
        /// Test condition
        @"test",
        /// Undefined instruction
        ud2,
        /// Logical exclusive-or
        xor,

        /// Add single precision floating point
        addss,
        /// Compare scalar single-precision floating-point values
        cmpss,
        /// Move scalar single-precision floating-point value
        movss,
        /// Unordered compare scalar single-precision floating-point values
        ucomiss,
        /// Add double precision floating point
        addsd,
        /// Compare scalar double-precision floating-point values
        cmpsd,
        /// Move scalar double-precision floating-point value
        movsd,
        /// Unordered compare scalar double-precision floating-point values
        ucomisd,

        /// End of prologue
        dbg_prologue_end,
        /// Start of epilogue
        dbg_epilogue_begin,
        /// Update debug line
        /// Uses `payload` payload with data of type `DbgLineColumn`.
        dbg_line,
        /// Push registers
        /// Uses `payload` payload with data of type `SaveRegisterList`.
        push_regs,
        /// Pop registers
        /// Uses `payload` payload with data of type `SaveRegisterList`.
        pop_regs,
    };

    pub const Ops = enum(u8) {
        /// No data associated with this instruction (only mnemonic is used).
        none,
        /// Single register operand.
        /// Uses `r` payload.
        r,
        /// Register, register operands.
        /// Uses `rr` payload.
        rr,
        /// Register, register, register operands.
        /// Uses `rrr` payload.
        rrr,
        /// Register, immediate (sign-extended) operands.
        /// Uses `ri_s` payload.
        ri_s,
        /// Register, immediate (unsigned) operands.
        /// Uses `ri_u` payload.
        ri_u,
        /// Register, 64-bit unsigned immediate operands.
        /// Uses `rx` payload with payload type `Imm64`.
        ri64,
        /// Immediate (sign-extended) operand.
        /// Uses `imm_s` payload.
        imm_s,
        /// Immediate (unsigned) operand.
        /// Uses `imm_u` payload.
        imm_u,
        /// Relative displacement operand.
        /// Uses `rel` payload.
        rel,
        /// Register, memory operands.
        /// Uses `rx` payload.
        rm,
        /// Register, memory, immediate (unsigned) operands
        /// Uses `rx` payload.
        rmi_u,
        /// Register, memory, immediate (sign-extended) operands
        /// Uses `rx` payload.
        rmi_s,
        /// Memory, immediate (unsigned) operands.
        /// Uses `payload` payload.
        mi_u,
        /// Memory, immediate (sign-extend) operands.
        /// Uses `payload` payload.
        mi_s,
        /// Memory, register operands.
        /// Uses `payload` payload.
        mr,
        /// Lea into register with linker relocation.
        /// Uses `payload` payload with data of type `LeaRegisterReloc`.
        lea_r_reloc,
        /// References another Mir instruction directly.
        /// Uses `inst` payload.
        inst,
        /// References another Mir instruction directly with condition code (CC).
        /// Uses `inst_cc` payload.
        inst_cc,
        /// Uses `payload` payload with data of type `MemoryConditionCode`.
        m_cc,
        /// Uses `rx` payload with extra data of type `MemoryConditionCode`.
        rm_cc,
        /// Uses `reloc` payload.
        reloc,
    };

    pub const Data = union {
        /// References another Mir instruction.
        inst: Index,
        /// Another instruction with condition code (CC).
        /// Used by `jcc`.
        inst_cc: struct {
            /// Another instruction.
            inst: Index,
            /// A condition code for use with EFLAGS register.
            cc: bits.Condition,
        },
        /// A 32-bit signed immediate value.
        imm_s: i32,
        /// A 32-bit unsigned immediate value.
        imm_u: u32,
        /// A 32-bit signed relative offset value.
        rel: i32,
        r: Register,
        rr: struct {
            r1: Register,
            r2: Register,
        },
        rrr: struct {
            r1: Register,
            r2: Register,
            r3: Register,
        },
        /// Register, signed immediate.
        ri_s: struct {
            r1: Register,
            imm: i32,
        },
        /// Register, unsigned immediate.
        ri_u: struct {
            r1: Register,
            imm: u32,
        },
        /// Register, followed by custom payload found in extra.
        rx: struct {
            r1: Register,
            payload: u32,
        },
        /// Relocation for the linker where:
        /// * `atom_index` is the index of the source
        /// * `sym_index` is the index of the target
        relocation: struct {
            /// Index of the containing atom.
            atom_index: u32,
            /// Index into the linker's symbol table.
            sym_index: u32,
        },
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        payload: u32,
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in Debug builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
            assert(@sizeOf(Data) == 8);
        }
    }
};

pub const LeaRegisterReloc = struct {
    /// Destination register.
    reg: Register,
    /// Type of the load.
    load_type: enum(u2) {
        got,
        direct,
        import,
    },
    /// Index of the containing atom.
    atom_index: u32,
    /// Index into the linker's symbol table.
    sym_index: u32,
};

/// Used in conjunction with `SaveRegisterList` payload to transfer a list of used registers
/// in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet = BitSet.initEmpty(),

    const BitSet = IntegerBitSet(@ctz(@as(u32, 0)));
    const Self = @This();

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(u32, i);
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

    pub fn asInt(self: Self) u32 {
        return self.bitset.mask;
    }

    pub fn fromInt(mask: u32) Self {
        return .{
            .bitset = BitSet{ .mask = @intCast(BitSet.MaskInt, mask) },
        };
    }

    pub fn count(self: Self) u32 {
        return @intCast(u32, self.bitset.count());
    }
};

pub const SaveRegisterList = struct {
    /// Base register
    base_reg: u32,
    /// Use `RegisterList` to populate.
    register_list: u32,
    stack_end: u32,
};

pub const Imm64 = struct {
    msb: u32,
    lsb: u32,

    pub fn encode(v: u64) Imm64 {
        return .{
            .msb = @truncate(u32, v >> 32),
            .lsb = @truncate(u32, v),
        };
    }

    pub fn decode(imm: Imm64) u64 {
        var res: u64 = 0;
        res |= (@intCast(u64, imm.msb) << 32);
        res |= @intCast(u64, imm.lsb);
        return res;
    }
};

pub const DbgLineColumn = struct {
    line: u32,
    column: u32,
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    gpa.free(mir.extra);
    mir.* = undefined;
}

pub fn extraData(mir: Mir, comptime T: type, index: u32) struct { data: T, end: u32 } {
    const fields = std.meta.fields(T);
    var i: u32 = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => mir.extra[i],
            i32 => @bitCast(i32, mir.extra[i]),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}
