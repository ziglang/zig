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
frame_locs: std.MultiArrayList(FrameLoc).Slice,

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
        /// Bit scan forward
        bsf,
        /// Bit scan reverse
        bsr,
        /// Byte swap
        bswap,
        /// Bit test
        bt,
        /// Bit test and complement
        btc,
        /// Bit test and reset
        btr,
        /// Bit test and set
        bts,
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
        /// Compare and exchange
        cmpxchg,
        /// Compare and exchange bytes
        cmpxchgb,
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
        /// Load fence
        lfence,
        /// Count the number of leading zero bits
        lzcnt,
        /// Memory fence
        mfence,
        /// Move
        mov,
        /// Move data after swapping bytes
        movbe,
        /// Move doubleword
        movd,
        /// Move quadword
        movq,
        /// Move with sign extension
        movsx,
        /// Move with zero extension
        movzx,
        /// Multiply
        mul,
        /// Two's complement negation
        neg,
        /// No-op
        nop,
        /// One's complement negation
        not,
        /// Logical or
        @"or",
        /// Pop
        pop,
        /// Return the count of number of bits set to 1
        popcnt,
        /// Push
        push,
        /// Rotate left through carry
        rcl,
        /// Rotate right through carry
        rcr,
        /// Return
        ret,
        /// Rotate left
        rol,
        /// Rotate right
        ror,
        /// Arithmetic shift left
        sal,
        /// Arithmetic shift right
        sar,
        /// Integer subtraction with borrow
        sbb,
        /// Store fence
        sfence,
        /// Logical shift left
        shl,
        /// Double precision shift left
        shld,
        /// Logical shift right
        shr,
        /// Double precision shift right
        shrd,
        /// Subtract
        sub,
        /// Syscall
        syscall,
        /// Test condition
        @"test",
        /// Count the number of trailing zero bits
        tzcnt,
        /// Undefined instruction
        ud2,
        /// Exchange and add
        xadd,
        /// Exchange register/memory with register
        xchg,
        /// Logical exclusive-or
        xor,

        /// Add single precision floating point values
        addss,
        /// Bitwise logical and of packed single precision floating-point values
        andps,
        /// Bitwise logical and not of packed single precision floating-point values
        andnps,
        /// Compare scalar single-precision floating-point values
        cmpss,
        /// Convert doubleword integer to scalar single-precision floating-point value
        cvtsi2ss,
        /// Divide scalar single-precision floating-point values
        divss,
        /// Return maximum single-precision floating-point value
        maxss,
        /// Return minimum single-precision floating-point value
        minss,
        /// Move aligned packed single-precision floating-point values
        movaps,
        /// Move scalar single-precision floating-point value
        movss,
        /// Move unaligned packed single-precision floating-point values
        movups,
        /// Multiply scalar single-precision floating-point values
        mulss,
        /// Bitwise logical or of packed single precision floating-point values
        orps,
        /// Extract word
        pextrw,
        /// Insert word
        pinsrw,
        /// Round scalar single-precision floating-point values
        roundss,
        /// Square root of scalar single precision floating-point value
        sqrtps,
        /// Subtract scalar single-precision floating-point values
        sqrtss,
        /// Square root of single precision floating-point values
        subss,
        /// Unordered compare scalar single-precision floating-point values
        ucomiss,
        /// Bitwise logical xor of packed single precision floating-point values
        xorps,
        /// Add double precision floating point values
        addsd,
        /// Bitwise logical and not of packed double precision floating-point values
        andnpd,
        /// Bitwise logical and of packed double precision floating-point values
        andpd,
        /// Compare scalar double-precision floating-point values
        cmpsd,
        /// Convert scalar double-precision floating-point value to scalar single-precision floating-point value
        cvtsd2ss,
        /// Convert doubleword integer to scalar double-precision floating-point value
        cvtsi2sd,
        /// Convert scalar single-precision floating-point value to scalar double-precision floating-point value
        cvtss2sd,
        /// Divide scalar double-precision floating-point values
        divsd,
        /// Return maximum double-precision floating-point value
        maxsd,
        /// Return minimum double-precision floating-point value
        minsd,
        /// Move scalar double-precision floating-point value
        movsd,
        /// Multiply scalar double-precision floating-point values
        mulsd,
        /// Bitwise logical or of packed double precision floating-point values
        orpd,
        /// Round scalar double-precision floating-point values
        roundsd,
        /// Square root of double precision floating-point values
        sqrtpd,
        /// Square root of scalar double precision floating-point value
        sqrtsd,
        /// Subtract scalar double-precision floating-point values
        subsd,
        /// Unordered compare scalar double-precision floating-point values
        ucomisd,
        /// Bitwise logical xor of packed double precision floating-point values
        xorpd,

        /// Compare string operands
        cmps,
        /// Load string
        lods,
        /// Move data from string to string
        movs,
        /// Scan string
        scas,
        /// Store string
        stos,

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
        /// Move address of a symbol not yet allocated in VM.
        mov_linker,

        /// End of prologue
        dbg_prologue_end,
        /// Start of epilogue
        dbg_epilogue_begin,
        /// Update debug line
        /// Uses `line_column` payload containing the line and column.
        dbg_line,
        /// Push registers
        /// Uses `payload` payload containing `RegisterList.asInt` directly.
        push_regs,
        /// Pop registers
        /// Uses `payload` payload containing `RegisterList.asInt` directly.
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
        /// Uses `r_cc` payload.
        r_cc,
        /// Register, register with condition code (CC).
        /// Uses `rr_cc` payload.
        rr_cc,
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
        i_s,
        /// Immediate (unsigned) operand.
        /// Uses `imm` payload.
        i_u,
        /// Relative displacement operand.
        /// Uses `imm` payload.
        rel,
        /// Register, memory (SIB) operands.
        /// Uses `rx` payload.
        rm_sib,
        /// Register, memory (RIP) operands.
        /// Uses `rx` payload.
        rm_rip,
        /// Register, memory (SIB) operands with condition code (CC).
        /// Uses `rx_cc` payload.
        rm_sib_cc,
        /// Register, memory (RIP) operands with condition code (CC).
        /// Uses `rx_cc` payload.
        rm_rip_cc,
        /// Register, memory (SIB), immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemorySib`.
        rmi_sib,
        /// Register, memory (RIP), immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemoryRip`.
        rmi_rip,
        /// Single memory (SIB) operand.
        /// Uses `payload` with extra data of type `MemorySib`.
        m_sib,
        /// Single memory (RIP) operand.
        /// Uses `payload` with extra data of type `MemoryRip`.
        m_rip,
        /// Single memory (SIB) operand with condition code (CC).
        /// Uses `x_cc` with extra data of type `MemorySib`.
        m_sib_cc,
        /// Single memory (RIP) operand with condition code (CC).
        /// Uses `x_cc` with extra data of type `MemoryRip`.
        m_rip_cc,
        /// Memory (SIB), immediate (unsigned) operands.
        /// Uses `ix` payload with extra data of type `MemorySib`.
        mi_sib_u,
        /// Memory (RIP), immediate (unsigned) operands.
        /// Uses `ix` payload with extra data of type `MemoryRip`.
        mi_rip_u,
        /// Memory (SIB), immediate (sign-extend) operands.
        /// Uses `ix` payload with extra data of type `MemorySib`.
        mi_sib_s,
        /// Memory (RIP), immediate (sign-extend) operands.
        /// Uses `ix` payload with extra data of type `MemoryRip`.
        mi_rip_s,
        /// Memory (SIB), register operands.
        /// Uses `rx` payload with extra data of type `MemorySib`.
        mr_sib,
        /// Memory (RIP), register operands.
        /// Uses `rx` payload with extra data of type `MemoryRip`.
        mr_rip,
        /// Memory (SIB), register, register operands.
        /// Uses `rrx` payload with extra data of type `MemorySib`.
        mrr_sib,
        /// Memory (RIP), register, register operands.
        /// Uses `rrx` payload with extra data of type `MemoryRip`.
        mrr_rip,
        /// Memory (SIB), register, immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemorySib`.
        mri_sib,
        /// Memory (RIP), register, immediate (byte) operands.
        /// Uses `rix` payload with extra data of type `MemoryRip`.
        mri_rip,
        /// Rax, Memory moffs.
        /// Uses `payload` with extra data of type `MemoryMoffs`.
        rax_moffs,
        /// Memory moffs, rax.
        /// Uses `payload` with extra data of type `MemoryMoffs`.
        moffs_rax,
        /// Single memory (SIB) operand with lock prefix.
        /// Uses `payload` with extra data of type `MemorySib`.
        lock_m_sib,
        /// Single memory (RIP) operand with lock prefix.
        /// Uses `payload` with extra data of type `MemoryRip`.
        lock_m_rip,
        /// Memory (SIB), immediate (unsigned) operands with lock prefix.
        /// Uses `xi` payload with extra data of type `MemorySib`.
        lock_mi_sib_u,
        /// Memory (RIP), immediate (unsigned) operands with lock prefix.
        /// Uses `xi` payload with extra data of type `MemoryRip`.
        lock_mi_rip_u,
        /// Memory (SIB), immediate (sign-extend) operands with lock prefix.
        /// Uses `xi` payload with extra data of type `MemorySib`.
        lock_mi_sib_s,
        /// Memory (RIP), immediate (sign-extend) operands with lock prefix.
        /// Uses `xi` payload with extra data of type `MemoryRip`.
        lock_mi_rip_s,
        /// Memory (SIB), register operands with lock prefix.
        /// Uses `rx` payload with extra data of type `MemorySib`.
        lock_mr_sib,
        /// Memory (RIP), register operands with lock prefix.
        /// Uses `rx` payload with extra data of type `MemoryRip`.
        lock_mr_rip,
        /// Memory moffs, rax with lock prefix.
        /// Uses `payload` with extra data of type `MemoryMoffs`.
        lock_moffs_rax,
        /// References another Mir instruction directly.
        /// Uses `inst` payload.
        inst,
        /// References another Mir instruction directly with condition code (CC).
        /// Uses `inst_cc` payload.
        inst_cc,
        /// String repeat and width
        /// Uses `string` payload.
        string,
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
        /// Linker relocation - threadlocal variable via GOT indirection.
        /// Uses `payload` payload with extra data of type `LeaRegisterReloc`.
        tlv_reloc,
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
        i: u32,
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
            i: u32,
        },
        /// Condition code (CC), followed by custom payload found in extra.
        x_cc: struct {
            cc: bits.Condition,
            payload: u32,
        },
        /// Register with condition code (CC).
        r_cc: struct {
            r: Register,
            cc: bits.Condition,
        },
        /// Register, register with condition code (CC).
        rr_cc: struct {
            r1: Register,
            r2: Register,
            cc: bits.Condition,
        },
        /// Register, immediate.
        ri: struct {
            r: Register,
            i: u32,
        },
        /// Register, followed by custom payload found in extra.
        rx: struct {
            r: Register,
            payload: u32,
        },
        /// Register with condition code (CC), followed by custom payload found in extra.
        rx_cc: struct {
            r: Register,
            cc: bits.Condition,
            payload: u32,
        },
        /// Immediate, followed by Custom payload found in extra.
        ix: struct {
            i: u32,
            payload: u32,
        },
        /// Register, register, followed by Custom payload found in extra.
        rrx: struct {
            r1: Register,
            r2: Register,
            payload: u32,
        },
        /// Register, byte immediate, followed by Custom payload found in extra.
        rix: struct {
            r: Register,
            i: u8,
            payload: u32,
        },
        /// String instruction prefix and width.
        string: struct {
            repeat: bits.StringRepeat,
            width: bits.StringWidth,
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
        /// Debug line and column position
        line_column: struct {
            line: u32,
            column: u32,
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

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet = BitSet.initEmpty(),

    const BitSet = IntegerBitSet(32);
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

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
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
    /// Base register tag of type Memory.Base.Tag
    base_tag: u32,
    /// Base register of type Register or FrameIndex
    base: u32,
    /// Scale starting at bit 0 and index register starting at bit 4.
    scale_index: u32,
    /// Displacement value.
    disp: i32,

    pub fn encode(mem: Memory) MemorySib {
        const sib = mem.sib;
        assert(sib.scale_index.scale == 0 or std.math.isPowerOfTwo(sib.scale_index.scale));
        return .{
            .ptr_size = @enumToInt(sib.ptr_size),
            .base_tag = @enumToInt(@as(Memory.Base.Tag, sib.base)),
            .base = switch (sib.base) {
                .none => undefined,
                .reg => |r| @enumToInt(r),
                .frame => |fi| @enumToInt(fi),
            },
            .scale_index = @as(u32, sib.scale_index.scale) << 0 |
                @as(u32, if (sib.scale_index.scale > 0)
                @enumToInt(sib.scale_index.index)
            else
                undefined) << 4,
            .disp = sib.disp,
        };
    }

    pub fn decode(msib: MemorySib) Memory {
        const scale = @truncate(u4, msib.scale_index);
        assert(scale == 0 or std.math.isPowerOfTwo(scale));
        return .{ .sib = .{
            .ptr_size = @intToEnum(Memory.PtrSize, msib.ptr_size),
            .base = switch (@intToEnum(Memory.Base.Tag, msib.base_tag)) {
                .none => .none,
                .reg => .{ .reg = @intToEnum(Register, msib.base) },
                .frame => .{ .frame = @intToEnum(bits.FrameIndex, msib.base) },
            },
            .scale_index = .{
                .scale = scale,
                .index = if (scale > 0) @intToEnum(Register, msib.scale_index >> 4) else undefined,
            },
            .disp = msib.disp,
        } };
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

    pub fn encode(seg: Register, offset: u64) MemoryMoffs {
        return .{
            .seg = @enumToInt(seg),
            .msb = @truncate(u32, offset >> 32),
            .lsb = @truncate(u32, offset >> 0),
        };
    }

    pub fn decode(moffs: MemoryMoffs) Memory {
        return .{ .moffs = .{
            .seg = @intToEnum(Register, moffs.seg),
            .offset = @as(u64, moffs.msb) << 32 | @as(u64, moffs.lsb) << 0,
        } };
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    gpa.free(mir.extra);
    mir.frame_locs.deinit(gpa);
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

pub const FrameLoc = struct {
    base: Register,
    disp: i32,
};

pub fn resolveFrameLoc(mir: Mir, mem: Memory) Memory {
    return switch (mem) {
        .sib => |sib| switch (sib.base) {
            .none, .reg => mem,
            .frame => |index| if (mir.frame_locs.len > 0) Memory.sib(sib.ptr_size, .{
                .base = .{ .reg = mir.frame_locs.items(.base)[@enumToInt(index)] },
                .disp = mir.frame_locs.items(.disp)[@enumToInt(index)] + sib.disp,
                .scale_index = mem.scaleIndex(),
            }) else mem,
        },
        .rip, .moffs => mem,
    };
}
