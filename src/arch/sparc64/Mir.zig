//! Machine Intermediate Representation.
//! This data is produced by SPARCv9 Codegen or SPARCv9 assembly parsing
//! These instructions have a 1:1 correspondence with machine code instructions
//! for the target. MIR can be lowered to source-annotated textual assembly code
//! instructions, or it can be lowered to machine code.
//! The main purpose of MIR is to postpone the assignment of offsets until Isel,
//! so that, for example, the smaller encodings of jump instructions can be used.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const Mir = @This();
const bits = @import("bits.zig");
const Air = @import("../../Air.zig");

const Instruction = bits.Instruction;
const Register = bits.Register;

instructions: std.MultiArrayList(Inst).Slice,

/// The meaning of this data is determined by `Inst.Tag` value.
extra: []const u32,

pub const Inst = struct {
    tag: Tag,
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Tag = enum(u16) {
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,

        // All the real instructions are ordered by their section number
        // in The SPARC Architecture Manual, Version 9.

        /// A.2 Add
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        add,

        /// A.3 Branch on Integer Register with Prediction (BPr)
        /// This uses the branch_predict_reg field.
        bpr,

        /// A.7 Branch on Integer Condition Codes with Prediction (BPcc)
        /// This uses the branch_predict_int field.
        bpcc,

        /// A.8 Call and Link
        /// This uses the branch_link field.
        call,

        /// A.24 Jump and Link
        /// This uses the arithmetic_3op field.
        jmpl,

        /// A.27 Load Integer
        /// This uses the arithmetic_3op field.
        /// Note that the ldd variant of this instruction is deprecated, so do not emit
        /// it unless specifically requested (e.g. by inline assembly).
        // TODO add other operations.
        ldub,
        lduh,
        lduw,
        ldx,

        /// A.31 Logical Operations
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        @"or",

        /// A.37 Multiply and Divide (64-bit)
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        mulx,

        /// A.40 No Operation
        /// This uses the nop field.
        nop,

        /// A.45 RETURN
        /// This uses the arithmetic_2op field.
        @"return",

        /// A.46 SAVE and RESTORE
        /// This uses the arithmetic_3op field.
        save,
        restore,

        /// A.48 SETHI
        /// This uses the sethi field.
        sethi,

        /// A.49 Shift
        /// This uses the shift field.
        sll,
        srl,
        sra,
        sllx,
        srlx,
        srax,

        /// A.54 Store Integer
        /// This uses the arithmetic_3op field.
        /// Note that the std variant of this instruction is deprecated, so do not emit
        /// it unless specifically requested (e.g. by inline assembly).
        // TODO add other operations.
        stb,
        sth,
        stw,
        stx,

        /// A.56 Subtract
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        sub,
        subcc,

        /// A.61 Trap on Integer Condition Codes (Tcc)
        /// This uses the trap field.
        tcc,

        // TODO add synthetic instructions
        // TODO add cmp synthetic instruction to avoid wasting a register when
        // comparing with subcc
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    // TODO this is a quick-n-dirty solution that needs to be cleaned up.
    pub const Data = union {
        /// Debug info: line and column
        ///
        /// Used by e.g. dbg_line
        dbg_line_column: struct {
            line: u32,
            column: u32,
        },

        /// Two operand arithmetic.
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. return
        arithmetic_2op: struct {
            is_imm: bool,
            rs1: Register,
            rs2_or_imm: union {
                rs2: Register,
                imm: i13,
            },
        },

        /// Three operand arithmetic.
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. add, sub
        arithmetic_3op: struct {
            is_imm: bool,
            rd: Register,
            rs1: Register,
            rs2_or_imm: union {
                rs2: Register,
                imm: i13,
            },
        },

        /// Branch and link (always unconditional).
        /// Used by e.g. call
        branch_link: struct {
            inst: Index,
            link: Register = .o7,
        },

        /// Branch with prediction, checking the integer status code
        /// Used by e.g. bpcc
        branch_predict_int: struct {
            annul: bool = false,
            pt: bool = true,
            ccr: Instruction.CCR,
            cond: Instruction.ICondition,
            inst: Index,
        },

        /// Branch with prediction, comparing a register's content with zero
        /// Used by e.g. bpr
        branch_predict_reg: struct {
            annul: bool = false,
            pt: bool = true,
            cond: Instruction.RCondition,
            rs1: Register,
            inst: Index,
        },

        /// No additional data
        ///
        /// Used by e.g. flushw
        nop: void,

        /// SETHI operands.
        ///
        /// Used by sethi
        sethi: struct {
            rd: Register,
            imm: u22,
        },

        /// Shift operands.
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. sllx
        shift: struct {
            is_imm: bool,
            width: Instruction.ShiftWidth,
            rd: Register,
            rs1: Register,
            rs2_or_imm: union {
                rs2: Register,
                imm: u6,
            },
        },

        /// Trap.
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. tcc
        trap: struct {
            is_imm: bool = true,
            cond: Instruction.ICondition,
            ccr: Instruction.CCR = .icc,
            rs1: Register = .g0,
            rs2_or_imm: union {
                rs2: Register,
                imm: u7,
            },
        },
    };

    // Make sure we don't accidentally make instructions bigger than expected.
    // Note that in Debug builds, Zig is allowed to insert a secret field for safety checks.
    comptime {
        if (builtin.mode != .Debug) {
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
