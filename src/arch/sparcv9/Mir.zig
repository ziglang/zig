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
        /// Pseudo-instruction: Argument
        dbg_arg,
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,

        // All the real instructions are ordered by their section number
        // in The SPARC Architecture Manual, Version 9.

        /// A.2 Add
        /// Those uses the arithmetic_3op field.
        // TODO add other operations.
        add,

        /// A.7 Branch on Integer Condition Codes with Prediction (BPcc)
        /// It uses the branch_predict field.
        bpcc,

        /// A.8 Call and Link
        /// It uses the branch_link field.
        call,

        /// A.24 Jump and Link
        /// jmpl (far direct jump) uses the branch_link field,
        /// while jmpl_i (indirect jump) uses the branch_link_indirect field.
        /// Those two MIR instructions will be lowered into SPARCv9 jmpl instruction.
        jmpl,
        jmpl_i,

        /// A.27 Load Integer
        /// Those uses the arithmetic_3op field.
        /// Note that the ldd variant of this instruction is deprecated, so do not emit
        /// it unless specifically requested (e.g. by inline assembly).
        // TODO add other operations.
        ldub,
        lduh,
        lduw,
        ldx,

        /// A.31 Logical Operations
        /// Those uses the arithmetic_3op field.
        // TODO add other operations.
        @"or",

        /// A.40 No Operation
        /// It uses the nop field.
        nop,

        /// A.45 RETURN
        /// It uses the arithmetic_2op field.
        @"return",

        /// A.46 SAVE and RESTORE
        /// Those uses the arithmetic_3op field.
        save,
        restore,

        /// A.48 SETHI
        /// It uses the sethi field.
        sethi,

        /// A.49 Shift
        /// Those uses the shift field.
        // TODO add other operations.
        sllx,

        /// A.56 Subtract
        /// Those uses the arithmetic_3op field.
        // TODO add other operations.
        sub,

        /// A.61 Trap on Integer Condition Codes (Tcc)
        /// It uses the trap field.
        tcc,
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    // TODO this is a quick-n-dirty solution that needs to be cleaned up.
    pub const Data = union {
        /// Debug info: argument
        ///
        /// Used by e.g. dbg_arg
        dbg_arg_info: struct {
            air_inst: Air.Inst.Index,
            arg_index: usize,
        },

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

        /// Indirect branch and link (always unconditional).
        /// Used by e.g. jmpl_i
        branch_link_indirect: struct {
            reg: Register,
            link: Register = .o7,
        },

        /// Branch with prediction.
        /// Used by e.g. bpcc
        branch_predict: struct {
            annul: bool = false,
            pt: bool = true,
            ccr: Instruction.CCR,
            cond: Instruction.Condition,
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
        /// Used by e.g. add, sub
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
            cond: Instruction.Condition,
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
            // TODO clean up the definition of Data before enabling this.
            // I'll do that after the PoC backend can produce usable binaries.

            // assert(@sizeOf(Data) == 8);
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
