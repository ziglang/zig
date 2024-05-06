//! Machine Intermediate Representation.
//! This data is produced by ARM Codegen or ARM assembly parsing
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
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

pub const Inst = struct {
    tag: Tag,
    cond: bits.Condition = .al,
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Tag = enum(u16) {
        /// Add
        add,
        /// Add, update condition flags
        adds,
        /// Bitwise AND
        @"and",
        /// Arithmetic Shift Right
        asr,
        /// Branch
        b,
        /// Undefined instruction
        undefined_instruction,
        /// Breakpoint
        bkpt,
        /// Branch with Link and Exchange
        blx,
        /// Branch and Exchange
        bx,
        /// Compare
        cmp,
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,
        /// Bitwise Exclusive OR
        eor,
        /// Load Register
        ldr,
        /// Pseudo-instruction: Load pointer to stack argument offset
        ldr_ptr_stack_argument,
        /// Load Register
        ldr_stack_argument,
        /// Load Register Byte
        ldrb,
        /// Load Register Byte
        ldrb_stack_argument,
        /// Load Register Halfword
        ldrh,
        /// Load Register Halfword
        ldrh_stack_argument,
        /// Load Register Signed Byte
        ldrsb,
        /// Load Register Signed Byte
        ldrsb_stack_argument,
        /// Load Register Signed Halfword
        ldrsh,
        /// Load Register Signed Halfword
        ldrsh_stack_argument,
        /// Logical Shift Left
        lsl,
        /// Logical Shift Right
        lsr,
        /// Move
        mov,
        /// Move
        movw,
        /// Move Top
        movt,
        /// Multiply
        mul,
        /// Bitwise NOT
        mvn,
        /// No Operation
        nop,
        /// Bitwise OR
        orr,
        /// Pop multiple registers from Stack
        pop,
        /// Push multiple registers to Stack
        push,
        /// Reverse Subtract
        rsb,
        /// Signed Bit Field Extract
        sbfx,
        /// Signed Multiply (halfwords), bottom half, bottom half
        smulbb,
        /// Signed Multiply Long
        smull,
        /// Store Register
        str,
        /// Store Register Byte
        strb,
        /// Store Register Halfword
        strh,
        /// Subtract
        sub,
        /// Pseudo-instruction: Subtract 32-bit immediate from stack
        ///
        /// r4 can be used by Emit as a scratch register for loading
        /// the immediate
        sub_sp_scratch_r4,
        /// Subtract, update condition flags
        subs,
        /// Supervisor Call
        svc,
        /// Unsigned Bit Field Extract
        ubfx,
        /// Unsigned Multiply Long
        umull,
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// No additional data
        ///
        /// Used by e.g. nop
        nop: void,
        /// Another instruction
        ///
        /// Used by e.g. b
        inst: Index,
        /// A 16-bit immediate value.
        ///
        /// Used by e.g. bkpt
        imm16: u16,
        /// A 24-bit immediate value.
        ///
        /// Used by e.g. svc
        imm24: u24,
        /// A 32-bit immediate value.
        ///
        /// Used by e.g. sub_sp_scratch_r0
        imm32: u32,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        ///
        /// Used by e.g. load_memory
        payload: u32,
        /// A register
        ///
        /// Used by e.g. blx
        reg: Register,
        /// A register and a stack offset
        ///
        /// Used by e.g. ldr_stack_argument
        r_stack_offset: struct {
            rt: Register,
            stack_offset: u32,
        },
        /// A register and a 16-bit unsigned immediate
        ///
        /// Used by e.g. movw
        r_imm16: struct {
            rd: Register,
            imm16: u16,
        },
        /// A register and an operand
        ///
        /// Used by mov and mvn
        r_op_mov: struct {
            rd: Register,
            op: bits.Instruction.Operand,
        },
        /// A register and an operand
        ///
        /// Used by cmp
        r_op_cmp: struct {
            rn: Register,
            op: bits.Instruction.Operand,
        },
        /// Two registers and a shift amount
        ///
        /// Used by e.g. lsl
        rr_shift: struct {
            rd: Register,
            rm: Register,
            shift_amount: bits.Instruction.ShiftAmount,
        },
        /// Two registers and an operand
        ///
        /// Used by e.g. sub
        rr_op: struct {
            rd: Register,
            rn: Register,
            op: bits.Instruction.Operand,
        },
        /// Two registers and an offset
        ///
        /// Used by e.g. ldr
        rr_offset: struct {
            rt: Register,
            rn: Register,
            offset: bits.Instruction.OffsetArgs,
        },
        /// Two registers and an extra load/store offset
        ///
        /// Used by e.g. ldrh
        rr_extra_offset: struct {
            rt: Register,
            rn: Register,
            offset: bits.Instruction.ExtraLoadStoreOffsetArgs,
        },
        /// Two registers and a lsb (range 0-31) and a width (range
        /// 1-32)
        ///
        /// Used by e.g. sbfx
        rr_lsb_width: struct {
            rd: Register,
            rn: Register,
            lsb: u5,
            width: u6,
        },
        /// Three registers
        ///
        /// Used by e.g. mul
        rrr: struct {
            rd: Register,
            rn: Register,
            rm: Register,
        },
        /// Four registers
        ///
        /// Used by e.g. smull
        rrrr: struct {
            rdlo: Register,
            rdhi: Register,
            rn: Register,
            rm: Register,
        },
        /// An unordered list of registers
        ///
        /// Used by e.g. push
        register_list: bits.Instruction.RegisterList,
        /// Debug info: line and column
        ///
        /// Used by e.g. dbg_line
        dbg_line_column: struct {
            line: u32,
            column: u32,
        },
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in safety builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (!std.debug.runtime_safety) {
            assert(@sizeOf(Data) == 8);
        }
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    gpa.free(mir.extra);
    mir.* = undefined;
}

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
