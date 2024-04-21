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
const ASI = bits.Instruction.ASI;
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
        addcc,

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

        /// A.28 Load Integer from Alternate Space
        /// This uses the mem_asi field.
        /// Note that the ldda variant of this instruction is deprecated, so do not emit
        /// it unless specifically requested (e.g. by inline assembly).
        // TODO add other operations.
        lduba,
        lduha,
        lduwa,
        ldxa,

        /// A.31 Logical Operations
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        @"and",
        @"or",
        xor,
        xnor,

        /// A.32 Memory Barrier
        /// This uses the membar_mask field.
        membar,

        /// A.35 Move Integer Register on Condition (MOVcc)
        /// This uses the conditional_move_int field.
        movcc,

        /// A.36 Move Integer Register on Register Condition (MOVr)
        /// This uses the conditional_move_reg field.
        movr,

        /// A.37 Multiply and Divide (64-bit)
        /// This uses the arithmetic_3op field.
        mulx,
        sdivx,
        udivx,

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

        /// A.55 Store Integer into Alternate Space
        /// This uses the mem_asi field.
        /// Note that the stda variant of this instruction is deprecated, so do not emit
        /// it unless specifically requested (e.g. by inline assembly).
        // TODO add other operations.
        stba,
        stha,
        stwa,
        stxa,

        /// A.56 Subtract
        /// This uses the arithmetic_3op field.
        // TODO add other operations.
        sub,
        subcc,

        /// A.61 Trap on Integer Condition Codes (Tcc)
        /// This uses the trap field.
        tcc,

        // SPARCv9 synthetic instructions
        // Note that the instructions that is added here are only those that
        // will simplify backend development. Synthetic instructions that is
        // only used to provide syntactic sugar in, e.g. inline assembly should
        // be deconstructed inside the parser instead.
        // See also: G.3 Synthetic Instructions
        // TODO add more synthetic instructions

        /// Comparison
        /// This uses the arithmetic_2op field.
        cmp, // cmp rs1, rs2/imm -> subcc rs1, rs2/imm, %g0

        /// Copy register/immediate contents to another register
        /// This uses the arithmetic_2op field, with rs1
        /// being the *destination* register.
        // TODO is it okay to abuse rs1 in this way?
        mov, // mov rs2/imm, rs1 -> or %g0, rs2/imm, rs1

        /// Bitwise negation
        /// This uses the arithmetic_2op field, with rs1
        /// being the *destination* register.
        // TODO is it okay to abuse rs1 in this way?
        // not rs2, rs1 -> xnor rs2, %g0, rs1
        // not imm, rs1 -> xnor %g0, imm, rs1
        not,
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
            // link is always %o7
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

        /// ASI-tagged memory operations.
        /// Used by e.g. ldxa, stxa
        mem_asi: struct {
            rd: Register,
            rs1: Register,
            rs2: Register = .g0,
            asi: ASI,
        },

        /// Membar mask, controls the barrier behavior
        /// Used by e.g. membar
        membar_mask: struct {
            mmask: Instruction.MemOrderingConstraint = .{},
            cmask: Instruction.MemCompletionConstraint = .{},
        },

        /// Conditional move, checking the integer status code
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. movcc
        conditional_move_int: struct {
            is_imm: bool,
            ccr: Instruction.CCR,
            cond: Instruction.Condition,
            rd: Register,
            rs2_or_imm: union {
                rs2: Register,
                imm: i11,
            },
        },

        /// Conditional move, comparing a register's content with zero
        /// if is_imm true then it uses the imm field of rs2_or_imm,
        /// otherwise it uses rs2 field.
        ///
        /// Used by e.g. movr
        conditional_move_reg: struct {
            is_imm: bool,
            cond: Instruction.RCondition,
            rd: Register,
            rs1: Register,
            rs2_or_imm: union {
                rs2: Register,
                imm: i10,
            },
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
