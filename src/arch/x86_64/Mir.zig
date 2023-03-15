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
const Memory = bits.Memory;
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

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

        /// Conditional move
        cmovcc,
        /// Conditional jump
        jcc,
        /// Set byte on condition
        setcc,

        /// Mov absolute to/from memory wrt segment register to/from rax
        mov_moffs,

        /// Jump with relocation to another local MIR instruction
        /// Uses `inst` payload.
        jmp_reloc,

        /// Call to an extern symbol via linker relocation.
        /// Uses `relocation` payload.
        call_extern,

        /// Load effective address of a symbol not yet allocated in VM.
        lea_linker,

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

        /// Tombstone
        /// Emitter should skip this instruction.
        dead,
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
        /// Register, register, immediate (sign-extended) operands.
        /// Uses `rri`  payload.
        rri_s,
        /// Register, register, immediate (unsigned) operands.
        /// Uses `rri`  payload.
        rri_u,
        /// Register with condition code (CC).
        /// Uses `r_c` payload.
        r_c,
        /// Register, register with condition code (CC).
        /// Uses `rr_c` payload.
        rr_c,
        /// Register, immediate (sign-extended) operands.
        /// Uses `ri` payload.
        ri_s,
        /// Register, immediate (unsigned) operands.
        /// Uses `ri` payload.
        ri_u,
        /// Register, 64-bit unsigned immediate operands.
        /// Uses `rx` payload with payload type `Imm64`.
        ri64,
        /// Immediate (sign-extended) operand.
        /// Uses `imm` payload.
        imm_s,
        /// Immediate (unsigned) operand.
        /// Uses `imm` payload.
        imm_u,
        /// Relative displacement operand.
        /// Uses `imm` payload.
        rel,
        /// Register, memory (SIB) operands.
        /// Uses `rx` payload.
        rm_sib,
        /// Register, memory (RIP) operands.
        /// Uses `rx` payload.
        rm_rip,
        /// Single memory (SIB) operand.
        /// Uses `payload` with extra data of type `MemorySib`.
        m_sib,
        /// Single memory (RIP) operand.
        /// Uses `payload` with extra data of type `MemoryRip`.
        m_rip,
        /// Memory (SIB), immediate (unsigned) operands.
        /// Uses `xi` payload with extra data of type `MemorySib`.
        mi_u_sib,
        /// Memory (RIP), immediate (unsigned) operands.
        /// Uses `xi` payload with extra data of type `MemoryRip`.
        mi_u_rip,
        /// Memory (SIB), immediate (sign-extend) operands.
        /// Uses `xi` payload with extra data of type `MemorySib`.
        mi_s_sib,
        /// Memory (RIP), immediate (sign-extend) operands.
        /// Uses `xi` payload with extra data of type `MemoryRip`.
        mi_s_rip,
        /// Memory (SIB), register operands.
        /// Uses `rx` payload with extra data of type `MemorySib`.
        mr_sib,
        /// Memory (RIP), register operands.
        /// Uses `rx` payload with extra data of type `MemoryRip`.
        mr_rip,
        /// Rax, Memory moffs.
        /// Uses `payload` with extra data of type `MemoryMoffs`.
        rax_moffs,
        /// Memory moffs, rax.
        /// Uses `payload` with extra data of type `MemoryMoffs`.
        moffs_rax,
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
        /// Linker relocation - GOT indirection.
        /// Uses `payload` payload with extra data of type `LeaRegisterReloc`.
        got_reloc,
        /// Linker relocation - direct reference.
        /// Uses `payload` payload with extra data of type `LeaRegisterReloc`.
        direct_reloc,
        /// Linker relocation - imports table indirection (binding).
        /// Uses `payload` payload with extra data of type `LeaRegisterReloc`.
        import_reloc,
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
        /// A 32-bit immediate value.
        imm: u32,
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
        rri: struct {
            r1: Register,
            r2: Register,
            imm: u32,
        },
        /// Register with condition code (CC).
        r_c: struct {
            r1: Register,
            cc: bits.Condition,
        },
        /// Register, register with condition code (CC).
        rr_c: struct {
            r1: Register,
            r2: Register,
            cc: bits.Condition,
        },
        /// Register, immediate.
        ri: struct {
            r1: Register,
            imm: u32,
        },
        /// Register, followed by custom payload found in extra.
        rx: struct {
            r1: Register,
            payload: u32,
        },
        /// Custom payload followed by an immediate.
        xi: struct {
            payload: u32,
            imm: u32,
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
    reg: u32,
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

// TODO this can be further compacted using packed struct
pub const MemorySib = struct {
    /// Size of the pointer.
    ptr_size: u32,
    /// Base register. -1 means null, or no base register.
    base: i32,
    /// Scale for index register. -1 means null, or no scale.
    /// This has to be in sync with `index` field.
    scale: i32,
    /// Index register. -1 means null, or no index register.
    /// This has to be in sync with `scale` field.
    index: i32,
    /// Displacement value.
    disp: i32,

    pub fn encode(mem: Memory) MemorySib {
        const sib = mem.sib;
        return .{
            .ptr_size = @enumToInt(sib.ptr_size),
            .base = if (sib.base) |r| @enumToInt(r) else -1,
            .scale = if (sib.scale_index) |si| si.scale else -1,
            .index = if (sib.scale_index) |si| @enumToInt(si.index) else -1,
            .disp = sib.disp,
        };
    }

    pub fn decode(msib: MemorySib) Memory {
        const base: ?Register = if (msib.base == -1) null else @intToEnum(Register, msib.base);
        const scale_index: ?Memory.ScaleIndex = if (msib.index == -1) null else .{
            .scale = @intCast(u4, msib.scale),
            .index = @intToEnum(Register, msib.index),
        };
        const mem: Memory = .{ .sib = .{
            .ptr_size = @intToEnum(Memory.PtrSize, msib.ptr_size),
            .base = base,
            .scale_index = scale_index,
            .disp = msib.disp,
        } };
        return mem;
    }
};

pub const MemoryRip = struct {
    /// Size of the pointer.
    ptr_size: u32,
    /// Displacement value.
    disp: i32,

    pub fn encode(mem: Memory) MemoryRip {
        return .{
            .ptr_size = @enumToInt(mem.rip.ptr_size),
            .disp = mem.rip.disp,
        };
    }

    pub fn decode(mrip: MemoryRip) Memory {
        return .{ .rip = .{
            .ptr_size = @intToEnum(Memory.PtrSize, mrip.ptr_size),
            .disp = mrip.disp,
        } };
    }
};

pub const MemoryMoffs = struct {
    /// Segment register.
    seg: u32,
    /// Absolute offset wrt to the segment register split between MSB and LSB parts much like
    /// `Imm64` payload.
    msb: u32,
    lsb: u32,

    pub fn encodeOffset(moffs: *MemoryMoffs, v: u64) void {
        moffs.msb = @truncate(u32, v >> 32);
        moffs.lsb = @truncate(u32, v);
    }

    pub fn decodeOffset(moffs: *const MemoryMoffs) u64 {
        var res: u64 = 0;
        res |= (@intCast(u64, moffs.msb) << 32);
        res |= @intCast(u64, moffs.lsb);
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
