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
const Register = bits.Register;

function: *const CodeGen,
instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

pub const Inst = struct {
    tag: Tag,
    /// This is 3 fields, and the meaning of each depends on `tag`.
    /// reg1: Register
    /// reg2: Register
    /// flags: u2
    ops: u16,
    /// The meaning of this depends on `tag` and `ops`.
    data: Data,

    pub const Tag = enum(u16) {
        /// ops flags:  form:
        ///       0b00  reg1, reg2
        ///       0b00  reg1, imm32
        ///       0b01  reg1, [reg2 + imm32]
        ///       0b01  reg1, [ds:imm32]
        ///       0b10  [reg1 + imm32], reg2
        ///       0b10  [reg1 + 0], imm32
        ///       0b11  [reg1 + imm32], imm32
        /// Notes:
        ///  * If reg2 is `none` then it means Data field `imm` is used as the immediate.
        ///  * When two imm32 values are required, Data field `payload` points at `ImmPair`.
        adc,

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

        // The following instructions all have the same encoding as `adc`.

        add,
        add_scale_src,
        add_scale_dst,
        add_scale_imm,
        sub,
        sub_scale_src,
        sub_scale_dst,
        sub_scale_imm,
        xor,
        xor_scale_src,
        xor_scale_dst,
        xor_scale_imm,
        @"and",
        and_scale_src,
        and_scale_dst,
        and_scale_imm,
        @"or",
        or_scale_src,
        or_scale_dst,
        or_scale_imm,
        rol,
        rol_scale_src,
        rol_scale_dst,
        rol_scale_imm,
        ror,
        ror_scale_src,
        ror_scale_dst,
        ror_scale_imm,
        rcl,
        rcl_scale_src,
        rcl_scale_dst,
        rcl_scale_imm,
        rcr,
        rcr_scale_src,
        rcr_scale_dst,
        rcr_scale_imm,
        shl,
        shl_scale_src,
        shl_scale_dst,
        shl_scale_imm,
        sal,
        sal_scale_src,
        sal_scale_dst,
        sal_scale_imm,
        shr,
        shr_scale_src,
        shr_scale_dst,
        shr_scale_imm,
        sar,
        sar_scale_src,
        sar_scale_dst,
        sar_scale_imm,
        sbb,
        sbb_scale_src,
        sbb_scale_dst,
        sbb_scale_imm,
        cmp,
        cmp_scale_src,
        cmp_scale_dst,
        cmp_scale_imm,
        mov,
        mov_scale_src,
        mov_scale_dst,
        mov_scale_imm,
        lea,
        lea_scale_src,
        lea_scale_dst,
        lea_scale_imm,

        /// ops flags: form:
        ///      0bX0  reg1
        ///      0bX1  [reg1 + imm32]
        imul,
        idiv,

        /// ops flags:  form:
        ///      0b00  reg1, reg2
        ///      0b01  reg1, [reg2 + imm32]
        ///      0b01  reg1, [imm32] if reg2 is none
        ///      0b10  reg1, reg2, imm32
        ///      0b11  reg1, [reg2 + imm32], imm32
        imul_complex,

        /// ops flags:  form:
        ///      0bX0   reg1, [rip + imm32]
        ///      0bX1   reg1, [rip + reloc]
        /// Notes:
        /// * if flags are 0bX1, `Data` contains `got_entry` for linker to generate
        ///   valid relocation for.
        /// TODO handle more cases
        lea_rip,

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

        /// ops flags: 0bX0:
        /// - Uses the `inst` Data tag as the jump target.
        /// - reg1 and reg2 are ignored.
        /// ops flags: 0bX1:
        /// - reg1 is the jump target, reg2 and data are ignored.
        /// - if reg1 is none, [imm]
        jmp,
        call,

        /// ops flags:
        ///     0b00 gte
        ///     0b01 gt
        ///     0b10 lt
        ///     0b11 lte
        cond_jmp_greater_less,
        cond_set_byte_greater_less,

        /// ops flags:
        ///     0b00 above or equal
        ///     0b01 above
        ///     0b10 below
        ///     0b11 below or equal
        cond_jmp_above_below,
        cond_set_byte_above_below,

        /// ops flags:
        ///     0bX0 ne
        ///     0bX1 eq
        cond_jmp_eq_ne,
        cond_set_byte_eq_ne,

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
        ///       0b00  reg1, reg2
        ///       0b00  reg1, imm32
        ///       0b01  reg1, [reg2 + imm32]
        ///       0b01  reg1, [ds:imm32]
        ///       0b10  [reg1 + imm32], reg2
        ///       0b10  [reg1 + 0], imm32
        ///       0b11  [reg1 + imm32], imm32
        /// Notes:
        ///  * If reg2 is `none` then it means Data field `imm` is used as the immediate.
        ///  * When two imm32 values are required, Data field `payload` points at `ImmPair`.
        @"test",

        /// Breakpoint
        brk,

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

        /// arg debug info
        arg_dbg_info,
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 4-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Another instruction.
        inst: Index,
        /// A 32-bit immediate value.
        imm: i32,
        /// An extern function.
        /// Index into the linker's string table.
        extern_fn: u32,
        /// Entry in the GOT table by index.
        got_entry: u32,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        payload: u32,
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in Debug builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (builtin.mode != .Debug) {
            assert(@sizeOf(Inst) == 8);
        }
    }
};

pub const ImmPair = struct {
    dest_off: i32,
    operand: i32,
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

pub const ArgDbgInfo = struct {
    air_inst: Air.Inst.Index,
    arg_index: u32,
};

pub fn deinit(mir: *Mir, gpa: *std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    gpa.free(mir.extra);
    mir.* = undefined;
}

pub const Ops = struct {
    reg1: Register = .none,
    reg2: Register = .none,
    flags: u2 = 0b00,

    pub fn encode(self: Ops) u16 {
        var ops: u16 = 0;
        ops |= @intCast(u16, @enumToInt(self.reg1)) << 9;
        ops |= @intCast(u16, @enumToInt(self.reg2)) << 2;
        ops |= self.flags;
        return ops;
    }

    pub fn decode(ops: u16) Ops {
        const reg1 = @intToEnum(Register, @truncate(u7, ops >> 9));
        const reg2 = @intToEnum(Register, @truncate(u7, ops >> 2));
        const flags = @truncate(u2, ops);
        return .{
            .reg1 = reg1,
            .reg2 = reg2,
            .flags = flags,
        };
    }
};

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
