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
        /// Add, update condition flags (immediate)
        adds_immediate,
        /// Add (shifted register)
        add_shifted_register,
        /// Add, update condition flags (shifted register)
        adds_shifted_register,
        /// Add (extended register)
        add_extended_register,
        /// Add, update condition flags (extended register)
        adds_extended_register,
        /// Bitwise AND (shifted register)
        and_shifted_register,
        /// Arithmetic Shift Right (immediate)
        asr_immediate,
        /// Arithmetic Shift Right (register)
        asr_register,
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
        /// Compare and Branch on Zero
        cbz,
        /// Compare (immediate)
        cmp_immediate,
        /// Compare (shifted register)
        cmp_shifted_register,
        /// Compare (extended register)
        cmp_extended_register,
        /// Conditional Select
        csel,
        /// Conditional set
        cset,
        /// Pseudo-instruction: End of prologue
        dbg_prologue_end,
        /// Pseudo-instruction: Beginning of epilogue
        dbg_epilogue_begin,
        /// Pseudo-instruction: Update debug line
        dbg_line,
        /// Bitwise Exclusive OR (immediate)
        eor_immediate,
        /// Bitwise Exclusive OR (shifted register)
        eor_shifted_register,
        /// Loads the contents into a register
        ///
        /// Payload is `LoadMemoryPie`
        load_memory_got,
        /// Loads the contents into a register
        ///
        /// Payload is `LoadMemoryPie`
        load_memory_direct,
        /// Loads the contents into a register
        ///
        /// Payload is `LoadMemoryPie`
        load_memory_import,
        /// Loads the address into a register
        ///
        /// Payload is `LoadMemoryPie`
        load_memory_ptr_got,
        /// Loads the address into a register
        ///
        /// Payload is `LoadMemoryPie`
        load_memory_ptr_direct,
        /// Load Pair of Registers
        ldp,
        /// Pseudo-instruction: Load pointer to stack item
        ldr_ptr_stack,
        /// Pseudo-instruction: Load pointer to stack argument
        ldr_ptr_stack_argument,
        /// Pseudo-instruction: Load from stack
        ldr_stack,
        /// Pseudo-instruction: Load from stack argument
        ldr_stack_argument,
        /// Load Register (immediate)
        ldr_immediate,
        /// Load Register (register)
        ldr_register,
        /// Pseudo-instruction: Load byte from stack
        ldrb_stack,
        /// Pseudo-instruction: Load byte from stack argument
        ldrb_stack_argument,
        /// Load Register Byte (immediate)
        ldrb_immediate,
        /// Load Register Byte (register)
        ldrb_register,
        /// Pseudo-instruction: Load halfword from stack
        ldrh_stack,
        /// Pseudo-instruction: Load halfword from stack argument
        ldrh_stack_argument,
        /// Load Register Halfword (immediate)
        ldrh_immediate,
        /// Load Register Halfword (register)
        ldrh_register,
        /// Load Register Signed Byte (immediate)
        ldrsb_immediate,
        /// Pseudo-instruction: Load signed byte from stack
        ldrsb_stack,
        /// Pseudo-instruction: Load signed byte from stack argument
        ldrsb_stack_argument,
        /// Load Register Signed Halfword (immediate)
        ldrsh_immediate,
        /// Pseudo-instruction: Load signed halfword from stack
        ldrsh_stack,
        /// Pseudo-instruction: Load signed halfword from stack argument
        ldrsh_stack_argument,
        /// Load Register Signed Word (immediate)
        ldrsw_immediate,
        /// Logical Shift Left (immediate)
        lsl_immediate,
        /// Logical Shift Left (register)
        lsl_register,
        /// Logical Shift Right (immediate)
        lsr_immediate,
        /// Logical Shift Right (register)
        lsr_register,
        /// Move (to/from SP)
        mov_to_from_sp,
        /// Move (register)
        mov_register,
        /// Move wide with keep
        movk,
        /// Move wide with zero
        movz,
        /// Multiply-subtract
        msub,
        /// Multiply
        mul,
        /// Bitwise NOT
        mvn,
        /// No Operation
        nop,
        /// Bitwise inclusive OR (shifted register)
        orr_shifted_register,
        /// Pseudo-instruction: Pop multiple registers
        pop_regs,
        /// Pseudo-instruction: Push multiple registers
        push_regs,
        /// Return from subroutine
        ret,
        /// Signed bitfield extract
        sbfx,
        /// Signed divide
        sdiv,
        /// Signed multiply high
        smulh,
        /// Signed multiply long
        smull,
        /// Signed extend byte
        sxtb,
        /// Signed extend halfword
        sxth,
        /// Signed extend word
        sxtw,
        /// Store Pair of Registers
        stp,
        /// Pseudo-instruction: Store to stack
        str_stack,
        /// Store Register (immediate)
        str_immediate,
        /// Store Register (register)
        str_register,
        /// Pseudo-instruction: Store byte to stack
        strb_stack,
        /// Store Register Byte (immediate)
        strb_immediate,
        /// Store Register Byte (register)
        strb_register,
        /// Pseudo-instruction: Store halfword to stack
        strh_stack,
        /// Store Register Halfword (immediate)
        strh_immediate,
        /// Store Register Halfword (register)
        strh_register,
        /// Subtract (immediate)
        sub_immediate,
        /// Subtract, update condition flags (immediate)
        subs_immediate,
        /// Subtract (shifted register)
        sub_shifted_register,
        /// Subtract, update condition flags (shifted register)
        subs_shifted_register,
        /// Subtract (extended register)
        sub_extended_register,
        /// Subtract, update condition flags (extended register)
        subs_extended_register,
        /// Supervisor Call
        svc,
        /// Test bits (immediate)
        tst_immediate,
        /// Unsigned bitfield extract
        ubfx,
        /// Unsigned divide
        udiv,
        /// Unsigned multiply high
        umulh,
        /// Unsigned multiply long
        umull,
        /// Unsigned extend byte
        uxtb,
        /// Unsigned extend halfword
        uxth,
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
        /// Relocation for the linker where:
        /// * `atom_index` is the index of the source
        /// * `sym_index` is the index of the target
        ///
        /// Used by e.g. call_extern
        relocation: struct {
            /// Index of the containing atom.
            atom_index: u32,
            /// Index into the linker's string table.
            sym_index: u32,
        },
        /// A 16-bit immediate value.
        ///
        /// Used by e.g. svc
        imm16: u16,
        /// Index into `extra`. Meaning of what can be found there is context-dependent.
        payload: u32,
        /// A register
        ///
        /// Used by e.g. blr
        reg: Register,
        /// Multiple registers
        ///
        /// Used by e.g. pop_regs
        reg_list: u32,
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
        /// A register and a condition
        ///
        /// Used by e.g. cset
        r_cond: struct {
            rd: Register,
            cond: bits.Instruction.Condition,
        },
        /// A register and another instruction
        ///
        /// Used by e.g. cbz
        r_inst: struct {
            rt: Register,
            inst: Index,
        },
        /// A register, an unsigned 12-bit immediate, and an optional shift
        ///
        /// Used by e.g. cmp_immediate
        r_imm12_sh: struct {
            rn: Register,
            imm12: u12,
            sh: u1 = 0,
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
        /// Two registers and a shift (shift type and 6-bit amount)
        ///
        /// Used by e.g. cmp_shifted_register
        rr_imm6_shift: struct {
            rn: Register,
            rm: Register,
            imm6: u6,
            shift: bits.Instruction.AddSubtractShiftedRegisterShift,
        },
        /// Two registers with sign-extension (extension type and 3-bit shift amount)
        ///
        /// Used by e.g. cmp_extended_register
        rr_extend_shift: struct {
            rn: Register,
            rm: Register,
            ext_type: bits.Instruction.AddSubtractExtendedRegisterOption,
            imm3: u3,
        },
        /// Two registers and a shift (logical instruction version)
        /// (shift type and 6-bit amount)
        ///
        /// Used by e.g. mvn
        rr_imm6_logical_shift: struct {
            rd: Register,
            rm: Register,
            imm6: u6,
            shift: bits.Instruction.LogicalShiftedRegisterShift,
        },
        /// Two registers and a lsb (range 0-63) and a width (range
        /// 1-64)
        ///
        /// Used by e.g. ubfx
        rr_lsb_width: struct {
            rd: Register,
            rn: Register,
            lsb: u6,
            width: u7,
        },
        /// Two registers and a bitmask immediate
        ///
        /// Used by e.g. eor_immediate
        rr_bitmask: struct {
            rd: Register,
            rn: Register,
            imms: u6,
            immr: u6,
            n: u1,
        },
        /// Two registers and a 6-bit unsigned shift
        ///
        /// Used by e.g. lsl_immediate
        rr_shift: struct {
            rd: Register,
            rn: Register,
            shift: u6,
        },
        /// Three registers
        ///
        /// Used by e.g. mul
        rrr: struct {
            rd: Register,
            rn: Register,
            rm: Register,
        },
        /// Three registers and a condition
        ///
        /// Used by e.g. csel
        rrr_cond: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            cond: bits.Instruction.Condition,
        },
        /// Three registers and a shift (shift type and 6-bit amount)
        ///
        /// Used by e.g. add_shifted_register
        rrr_imm6_shift: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            imm6: u6,
            shift: bits.Instruction.AddSubtractShiftedRegisterShift,
        },
        /// Three registers with sign-extension (extension type and 3-bit shift amount)
        ///
        /// Used by e.g. add_extended_register
        rrr_extend_shift: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            ext_type: bits.Instruction.AddSubtractExtendedRegisterOption,
            imm3: u3,
        },
        /// Three registers and a shift (logical instruction version)
        /// (shift type and 6-bit amount)
        ///
        /// Used by e.g. eor_shifted_register
        rrr_imm6_logical_shift: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            imm6: u6,
            shift: bits.Instruction.LogicalShiftedRegisterShift,
        },
        /// Two registers and a LoadStoreOffsetImmediate
        ///
        /// Used by e.g. str_immediate
        load_store_register_immediate: struct {
            rt: Register,
            rn: Register,
            offset: bits.Instruction.LoadStoreOffsetImmediate,
        },
        /// Two registers and a LoadStoreOffsetRegister
        ///
        /// Used by e.g. str_register
        load_store_register_register: struct {
            rt: Register,
            rn: Register,
            offset: bits.Instruction.LoadStoreOffsetRegister,
        },
        /// A register and a stack offset
        ///
        /// Used by e.g. str_stack
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
        /// Four registers
        ///
        /// Used by e.g. msub
        rrrr: struct {
            rd: Register,
            rn: Register,
            rm: Register,
            ra: Register,
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

pub const LoadMemoryPie = struct {
    register: u32,
    /// Index of the containing atom.
    atom_index: u32,
    /// Index into the linker's symbol table.
    sym_index: u32,
};
