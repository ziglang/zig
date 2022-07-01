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
const Air = @import("../../Air.zig");
const CodeGen = @import("CodeGen.zig");
const IntegerBitSet = std.bit_set.IntegerBitSet;
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

pub const Inst = struct {
    tag: Tag,
    ops: Ops,
    /// The meaning of this depends on `tag` and `ops`.
    data: Data,

    pub const Tag = enum(u16) {
        /// ops flags:  form:
        ///       0b00  reg1, reg2
        ///       0b00  reg1, imm32
        ///       0b01  reg1, [reg2 + imm32]
        ///       0b01  reg1, [ds:imm32]
        ///       0b10  [reg1 + imm32], reg2
        /// Notes:
        ///  * If reg2 is `none` then it means Data field `imm` is used as the immediate.
        ///  * When two imm32 values are required, Data field `payload` points at `ImmPair`.
        adc,

        /// ops flags: form:
        ///       0b00 byte ptr [reg1 + imm32], imm8
        ///       0b01 word ptr [reg1 + imm32], imm16
        ///       0b10 dword ptr [reg1 + imm32], imm32
        ///       0b11 qword ptr [reg1 + imm32], imm32 (sign-extended to imm64)
        adc_mem_imm,

        /// form: reg1, [reg2 + scale*rcx + imm32]
        /// ops flags  scale
        ///      0b00      1
        ///      0b01      2
        ///      0b10      4
        ///      0b11      8
        adc_scale_src,

        /// form: [reg1 + scale*rax + imm32], reg2
        /// form: [reg1 + scale*rax + 0], imm32
        /// ops flags  scale
        ///      0b00      1
        ///      0b01      2
        ///      0b10      4
        ///      0b11      8
        /// Notes:
        ///  * If reg2 is `none` then it means Data field `imm` is used as the immediate.
        adc_scale_dst,

        /// form: [reg1 + scale*rax + imm32], imm32
        /// ops flags  scale
        ///      0b00      1
        ///      0b01      2
        ///      0b10      4
        ///      0b11      8
        /// Notes:
        ///  * Data field `payload` points at `ImmPair`.
        adc_scale_imm,

        /// ops flags: form:
        ///       0b00 byte ptr [reg1 + rax + imm32], imm8
        ///       0b01 word ptr [reg1 + rax + imm32], imm16
        ///       0b10 dword ptr [reg1 + rax + imm32], imm32
        ///       0b11 qword ptr [reg1 + rax + imm32], imm32 (sign-extended to imm64)
        adc_mem_index_imm,

        // The following instructions all have the same encoding as `adc`.

        add,
        add_mem_imm,
        add_scale_src,
        add_scale_dst,
        add_scale_imm,
        add_mem_index_imm,
        sub,
        sub_mem_imm,
        sub_scale_src,
        sub_scale_dst,
        sub_scale_imm,
        sub_mem_index_imm,
        xor,
        xor_mem_imm,
        xor_scale_src,
        xor_scale_dst,
        xor_scale_imm,
        xor_mem_index_imm,
        @"and",
        and_mem_imm,
        and_scale_src,
        and_scale_dst,
        and_scale_imm,
        and_mem_index_imm,
        @"or",
        or_mem_imm,
        or_scale_src,
        or_scale_dst,
        or_scale_imm,
        or_mem_index_imm,
        rol,
        rol_mem_imm,
        rol_scale_src,
        rol_scale_dst,
        rol_scale_imm,
        rol_mem_index_imm,
        ror,
        ror_mem_imm,
        ror_scale_src,
        ror_scale_dst,
        ror_scale_imm,
        ror_mem_index_imm,
        rcl,
        rcl_mem_imm,
        rcl_scale_src,
        rcl_scale_dst,
        rcl_scale_imm,
        rcl_mem_index_imm,
        rcr,
        rcr_mem_imm,
        rcr_scale_src,
        rcr_scale_dst,
        rcr_scale_imm,
        rcr_mem_index_imm,
        sbb,
        sbb_mem_imm,
        sbb_scale_src,
        sbb_scale_dst,
        sbb_scale_imm,
        sbb_mem_index_imm,
        cmp,
        cmp_mem_imm,
        cmp_scale_src,
        cmp_scale_dst,
        cmp_scale_imm,
        cmp_mem_index_imm,
        mov,
        mov_mem_imm,
        mov_scale_src,
        mov_scale_dst,
        mov_scale_imm,
        mov_mem_index_imm,

        /// ops flags: form:
        ///      0b00  reg1, reg2,
        ///      0b01  reg1, byte ptr [reg2 + imm32]
        ///      0b10  reg1, word ptr [reg2 + imm32]
        ///      0b11  reg1, dword ptr [reg2 + imm32]
        mov_sign_extend,

        /// ops flags: form:
        ///      0b00  reg1, reg2
        ///      0b01  reg1, byte ptr [reg2 + imm32]
        ///      0b10  reg1, word ptr [reg2 + imm32]
        mov_zero_extend,

        /// ops flags: form:
        ///      0b00  reg1, [reg2 + imm32]
        ///      0b00  reg1, [ds:imm32]
        ///      0b01  reg1, [rip + imm32]
        ///      0b10  reg1, [reg2 + rcx + imm32]
        lea,

        /// ops flags: form:
        ///      0b00  reg1, [rip + reloc] // via GOT emits X86_64_RELOC_GOT relocation
        ///      0b01  reg1, [rip + reloc] // direct load emits X86_64_RELOC_SIGNED relocation
        /// Notes:
        /// * `Data` contains `load_reloc`
        lea_pie,

        /// ops flags: form:
        ///      0b00  reg1, 1
        ///      0b01  reg1, .cl
        ///      0b10  reg1, imm8
        /// Notes:
        ///   * If flags == 0b10, uses `imm`.
        shl,
        shl_mem_imm,
        shl_scale_src,
        shl_scale_dst,
        shl_scale_imm,
        shl_mem_index_imm,
        sal,
        sal_mem_imm,
        sal_scale_src,
        sal_scale_dst,
        sal_scale_imm,
        sal_mem_index_imm,
        shr,
        shr_mem_imm,
        shr_scale_src,
        shr_scale_dst,
        shr_scale_imm,
        shr_mem_index_imm,
        sar,
        sar_mem_imm,
        sar_scale_src,
        sar_scale_dst,
        sar_scale_imm,
        sar_mem_index_imm,

        /// ops flags: form:
        ///      0b00  reg1
        ///      0b00  byte ptr [reg2 + imm32]
        ///      0b01  word ptr [reg2 + imm32]
        ///      0b10  dword ptr [reg2 + imm32]
        ///      0b11  qword ptr [reg2 + imm32]
        imul,
        idiv,
        mul,
        div,

        /// ops flags: form:
        ///      0b00  AX      <- AL
        ///      0b01  DX:AX   <- AX
        ///      0b10  EDX:EAX <- EAX
        ///      0b11  RDX:RAX <- RAX
        cwd,

        /// ops flags:  form:
        ///      0b00  reg1, reg2
        ///      0b01  reg1, [reg2 + imm32]
        ///      0b01  reg1, [imm32] if reg2 is none
        ///      0b10  reg1, reg2, imm32
        ///      0b11  reg1, [reg2 + imm32], imm32
        imul_complex,

        /// ops flags:  form:
        ///      0bX0   reg1, imm64
        ///      0bX1   rax, moffs64
        /// Notes:
        ///   * If reg1 is 64-bit, the immediate is 64-bit and stored
        ///     within extra data `Imm64`.
        ///   * For 0bX1, reg1 (or reg2) need to be
        ///     a version of rax. If reg1 == .none, then reg2 == .rax,
        ///     or vice versa.
        /// TODO handle scaling
        movabs,

        /// ops flags:  form:
        ///      0b00    word ptr [reg1 + imm32]
        ///      0b01    dword ptr [reg1 + imm32]
        ///      0b10    qword ptr [reg1 + imm32]
        /// Notes:
        ///   * source is always ST(0)
        ///   * only supports memory operands as destination
        fisttp,

        /// ops flags:  form:
        ///      0b01    dword ptr [reg1 + imm32]
        ///      0b10    qword ptr [reg1 + imm32]
        fld,

        /// ops flags:  form:
        ///      0b00    inst
        ///      0b01    reg1
        ///      0b01    [imm32] if reg1 is none
        ///      0b10    [reg1 + imm32]
        jmp,
        call,

        /// ops flags:
        ///     unused
        /// Notes:
        ///  * uses `inst_cc` in Data.
        cond_jmp,

        /// ops flags:
        ///      0b00 reg1
        /// Notes:
        ///  * uses condition code (CC) stored as part of data
        cond_set_byte,

        /// ops flags:
        ///     0b00 reg1, reg2,
        ///     0b01 reg1, word ptr  [reg2 + imm]
        ///     0b10 reg1, dword ptr [reg2 + imm]
        ///     0b11 reg1, qword ptr [reg2 + imm]
        /// Notes:
        ///  * uses condition code (CC) stored as part of data
        cond_mov,

        /// ops flags:  form:
        ///       0b00   reg1
        ///       0b01   [reg1 + imm32]
        ///       0b10   imm32
        /// Notes:
        ///  * If 0b10 is specified and the tag is push, pushes immediate onto the stack
        ///    using the mnemonic PUSH imm32.
        push,
        pop,

        /// ops flags:  form:
        ///       0b00  retf imm16
        ///       0b01  retf
        ///       0b10  retn imm16
        ///       0b11  retn
        ret,

        /// Fast system call
        syscall,

        /// ops flags:  form:
        ///       0b00  reg1, imm32 if reg2 == .none
        ///       0b00  reg1, reg2
        /// TODO handle more cases
        @"test",

        /// Breakpoint  form:
        ///       0b00  int3
        interrupt,

        /// Nop
        nop,

        /// SSE instructions
        /// ops flags:  form:
        ///       0b00  reg1, qword ptr [reg2 + imm32]
        ///       0b01  qword ptr [reg1 + imm32], reg2
        ///       0b10  reg1, reg2
        mov_f64_sse,
        mov_f32_sse,

        /// ops flags:  form:
        ///       0b00  reg1, reg2
        add_f64_sse,
        add_f32_sse,

        /// ops flags:  form:
        ///       0b00  reg1, reg2
        cmp_f64_sse,
        cmp_f32_sse,

        /// AVX instructions
        /// ops flags:  form:
        ///       0b00  reg1, qword ptr [reg2 + imm32]
        ///       0b01  qword ptr [reg1 + imm32], reg2
        ///       0b10  reg1, reg1, reg2
        mov_f64_avx,
        mov_f32_avx,

        /// ops flags:  form:
        ///       0b00  reg1, reg1, reg2
        add_f64_avx,
        add_f32_avx,

        /// ops flags:  form:
        ///       0b00  reg1, reg1, reg2
        cmp_f64_avx,
        cmp_f32_avx,

        /// Pseudo-instructions
        /// call extern function
        /// Notes:
        ///   * target of the call is stored as `extern_fn` in `Data` union.
        call_extern,

        /// end of prologue
        dbg_prologue_end,

        /// start of epilogue
        dbg_epilogue_begin,

        /// update debug line
        dbg_line,

        /// push registers
        /// Uses `payload` field with `SaveRegisterList` as payload.
        push_regs,

        /// pop registers
        /// Uses `payload` field with `SaveRegisterList` as payload.
        pop_regs,
    };
    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    pub const Ops = packed struct {
        reg1: u7,
        reg2: u7,
        flags: u2,

        pub fn encode(vals: struct {
            reg1: Register = .none,
            reg2: Register = .none,
            flags: u2 = 0b00,
        }) Ops {
            return .{
                .reg1 = @enumToInt(vals.reg1),
                .reg2 = @enumToInt(vals.reg2),
                .flags = vals.flags,
            };
        }

        pub fn decode(ops: Ops) struct {
            reg1: Register,
            reg2: Register,
            flags: u2,
        } {
            return .{
                .reg1 = @intToEnum(Register, ops.reg1),
                .reg2 = @intToEnum(Register, ops.reg2),
                .flags = ops.flags,
            };
        }
    };

    /// All instructions have a 4-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Another instruction.
        inst: Index,
        /// A 32-bit immediate value.
        imm: u32,
        /// A condition code for use with EFLAGS register.
        cc: bits.Condition,
        /// Another instruction with condition code.
        /// Used by `cond_jmp`.
        inst_cc: struct {
            /// Another instruction.
            inst: Index,
            /// A condition code for use with EFLAGS register.
            cc: bits.Condition,
        },
        /// An extern function.
        extern_fn: struct {
            /// Index of the containing atom.
            atom_index: u32,
            /// Index into the linker's string table.
            sym_name: u32,
        },
        /// PIE load relocation.
        load_reloc: struct {
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
        if (builtin.mode != .Debug) {
            assert(@sizeOf(Data) == 8);
        }
    }
};

pub fn RegisterList(comptime Reg: type, comptime registers: []const Reg) type {
    assert(registers.len <= @bitSizeOf(u32));
    return struct {
        bitset: RegBitSet = RegBitSet.initEmpty(),

        const RegBitSet = IntegerBitSet(registers.len);
        const Self = @This();

        fn getIndexForReg(reg: Reg) RegBitSet.MaskInt {
            inline for (registers) |cpreg, i| {
                if (reg.id() == cpreg.id()) return i;
            }
            unreachable; // register not in input register list!
        }

        pub fn push(self: *Self, reg: Reg) void {
            const index = getIndexForReg(reg);
            self.bitset.set(index);
        }

        pub fn isSet(self: Self, reg: Reg) bool {
            const index = getIndexForReg(reg);
            return self.bitset.isSet(index);
        }

        pub fn asInt(self: Self) u32 {
            return self.bitset.mask;
        }

        pub fn fromInt(mask: u32) Self {
            return .{
                .bitset = RegBitSet{ .mask = @intCast(RegBitSet.MaskInt, mask) },
            };
        }

        pub fn count(self: Self) u32 {
            return @intCast(u32, self.bitset.count());
        }
    };
}

pub const SaveRegisterList = struct {
    /// Use `RegisterList` to populate.
    register_list: u32,
    stack_end: u32,
};

pub const ImmPair = struct {
    dest_off: u32,
    operand: u32,
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

pub fn extraData(mir: Mir, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
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
