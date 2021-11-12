//! Machine Intermediate Representation.
//! This data is produced by AArch64 Codegen or AArch64 assembly parsing
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
        /// Add (immediate)
        add_immediate,
        /// Branch conditionally
        b_cond,
        /// Branch
        b,
        /// Branch with Link
        bl,
        /// Branch with Link to Register
        blr,
        /// Breakpoint
        brk,
        /// Pseudo-instruction: Call extern
        call_extern,
        /// Compare (immediate)
        cmp_immediate,
        /// Compare (shifted register)
        cmp_shifted_register,
        /// Conditional set
        cset,
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,
        /// Pseudo-instruction: Load memory
        ///
        /// Payload is `LoadMemory`
        load_memory,
        /// Load Pair of Registers
        ldp,
        /// Pseudo-instruction: Load from stack
        ldr_stack,
        /// Load Register
        // TODO: split into ldr_immediate and ldr_register
        ldr,
        /// Pseudo-instruction: Load byte from stack
        ldrb_stack,
        /// Load Register Byte
        // TODO: split into ldrb_immediate and ldrb_register
        ldrb,
        /// Pseudo-instruction: Load halfword from stack
        ldrh_stack,
        /// Load Register Halfword
        // TODO: split into ldrh_immediate and ldrh_register
        ldrh,
        /// Move (to/from SP)
        mov_to_from_sp,
        /// Move (register)
        mov_register,
        /// Move wide with keep
        movk,
        /// Move wide with zero
        movz,
        /// No Operation
        nop,
        /// Return from subroutine
        ret,
        /// Store Pair of Registers
        stp,
        /// Pseudo-instruction: Store to stack
        str_stack,
        /// Store Register
        // TODO: split into str_immediate and str_register
        str,
        /// Pseudo-instruction: Store byte to stack
        strb_stack,
        /// Store Register Byte
        // TODO: split into strb_immediate and strb_register
        strb,
        /// Pseudo-instruction: Store halfword to stack
        strh_stack,
        /// Store Register Halfword
        // TODO: split into strh_immediate and strh_register
        strh,
        /// Subtract (immediate)
        sub_immediate,
        /// Supervisor Call
        svc,
    };

    /// The position of an MIR instruction within the `Mir` instructions array.
    pub const Index = u32;

    /// All instructions have a 4-byte payload, which is contained within
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
        /// An extern function
        ///
        /// Used by e.g. call_extern
        extern_fn: u32,
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
        /// Another instruction and a condition
        ///
        /// Used by e.g. b_cond
        inst_cond: struct {
            inst: Index,
            cond: bits.Instruction.Condition,
        },
        /// A register, an unsigned 16-bit immediate, and an optional shift
        ///
        /// Used by e.g. movz
        r_imm16_sh: struct {
            rd: Register,
            imm16: u16,
            hw: u2 = 0,
        },
        /// Two registers
        ///
        /// Used by e.g. mov_register
        rr: struct {
            rd: Register,
            rn: Register,
        },
        /// Two registers, an unsigned 12-bit immediate, and an optional shift
        ///
        /// Used by e.g. sub_immediate
        rr_imm12_sh: struct {
            rd: Register,
            rn: Register,
            imm12: u12,
            sh: u1 = 0,
        },
        /// Three registers and a shift (shift type and 6-bit amount)
        ///
        /// Used by e.g. cmp_shifted_register
        rrr_imm6_shift: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            imm6: u6,
            shift: bits.Instruction.AddSubtractShiftedRegisterShift,
        },
        /// Three registers and a condition
        ///
        /// Used by e.g. cset
        rrr_cond: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            cond: bits.Instruction.Condition,
        },
        /// Two registers and a LoadStoreOffset
        ///
        /// Used by e.g. str_register
        load_store_register: struct {
            rt: Register,
            rn: Register,
            offset: bits.Instruction.LoadStoreOffset,
        },
        /// A registers and a stack offset
        ///
        /// Used by e.g. str_register
        load_store_stack: struct {
            rt: Register,
            offset: u32,
        },
        /// Three registers and a LoadStorePairOffset
        ///
        /// Used by e.g. stp
        load_store_register_pair: struct {
            rt: Register,
            rt2: Register,
            rn: Register,
            offset: bits.Instruction.LoadStorePairOffset,
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
    // Note that in Debug builds, Zig is allowed to insert a secret field for safety checks.
    // comptime {
    //     if (builtin.mode != .Debug) {
    //         assert(@sizeOf(Inst) == 8);
    //     }
    // }
};

pub fn deinit(mir: *Mir, gpa: *std.mem.Allocator) void {
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

pub const LoadMemory = struct {
    register: u32,
    addr: u32,
};
