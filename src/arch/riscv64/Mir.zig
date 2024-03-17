//! Machine Intermediate Representation.
//! This data is produced by RISCV64 Codegen or RISCV64 assembly parsing
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
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Tag = enum(u16) {
        add,
        addi,
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,
        unimp,
        ebreak,
        ecall,
        jalr,
        ld,
        lui,
        mv,
        nop,
        ret,
        sd,
        sub,
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 4-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// No additional data
        ///
        /// Used by e.g. ebreak
        nop: void,
        /// Another instruction.
        ///
        /// Used by e.g. b
        inst: Index,
        /// A 16-bit immediate value.
        ///
        /// Used by e.g. svc
        imm16: u16,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        ///
        /// Used by e.g. load_memory
        payload: u32,
        /// A register
        ///
        /// Used by e.g. blr
        reg: Register,
        /// Two registers
        ///
        /// Used by e.g. mv
        rr: struct {
            rd: Register,
            rs: Register,
        },
        /// I-Type
        ///
        /// Used by e.g. jalr
        i_type: struct {
            rd: Register,
            rs1: Register,
            imm12: i12,
        },
        /// R-Type
        ///
        /// Used by e.g. add
        r_type: struct {
            rd: Register,
            rs1: Register,
            rs2: Register,
        },
        /// U-Type
        ///
        /// Used by e.g. lui
        u_type: struct {
            rd: Register,
            imm20: i20,
        },
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
    // comptime {
    //     if (!std.debug.runtime_safety) {
    //         assert(@sizeOf(Inst) == 8);
    //     }
    // }
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
