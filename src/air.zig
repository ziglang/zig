//! Analyzed Intermediate Representation.
//! Sema.zig converts ZIR to these in-memory, type-annotated instructions.
//! This struct owns the `Value` and `Type` memory. When the struct is deallocated,
//! so are the `Value` and `Type`. The value of a constant must be copied into
//! a memory location for the value to survive after a const instruction.
const std = @import("std");
const assert = std.debug.assert;

const Air = @This();
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;

instructions: std.MultiArrayList(Inst).Slice,

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Tag = enum {
        /// Stack allocation.
        /// These are *not* guaranteed to be all at the beginning of the function.
        /// Uses `Data.ty`.
        alloc,
        /// Uses `Data.none`. Result type is `noreturn`.
        retvoid,
        /// Undefined behavior.
        /// Uses `Data.none`. Result type is `noreturn`.
        unreach,
        /// Trace/breakpoint trap.
        /// Uses `Data.none`. No result.
        breakpoint,

        /// Given a value, returns a temporary const pointer to it.
        /// TODO what are the rules on the lifetime of the pointer?
        /// Uses `Data.un`.
        ref,
        /// Return from current function.
        /// Uses `Data.un`.
        ret,
        /// Reinterpret bits from one type to another.
        /// Uses `Data.un`.
        bitcast,
        /// Result type is same as operand.
        /// Uses `Data.un`.
        not,
        /// ?T => bool (inverted logic)
        is_non_null,
        /// *?T => bool (inverted logic)
        /// Uses `Data.un`.
        is_non_null_ptr,
        /// ?T => bool
        /// Uses `Data.un`.
        is_null,
        /// *?T => bool
        /// Uses `Data.un`.
        is_null_ptr,
        /// E!T => bool
        /// Uses `Data.un`.
        is_err,
        /// *E!T => bool
        /// Uses `Data.un`.
        is_err_ptr,
        /// u16 => E
        /// Uses `Data.un`.
        int_to_error,
        /// E => u16
        /// Uses `Data.un`.
        error_to_int,
        /// Uses `Data.un`.
        ptrtoint,
        /// Uses `Data.un`.
        floatcast,
        /// Uses `Data.un`.
        intcast,
        /// Read a value from a pointer.
        /// Uses `Data.un`.
        load,
        /// ?T => T
        /// Uses `Data.un`.
        optional_payload,
        /// *?T => *T
        /// Uses `Data.un`.
        optional_payload_ptr,
        /// Uses `Data.un`.
        wrap_optional,
        /// E!T -> T
        /// Uses `Data.un`.
        unwrap_errunion_payload,
        /// E!T -> E
        /// Uses `Data.un`.
        unwrap_errunion_err,
        /// *(E!T) -> *T
        /// Uses `Data.un`.
        unwrap_errunion_payload_ptr,
        /// *(E!T) -> E
        /// Uses `Data.un`.
        unwrap_errunion_err_ptr,
        /// wrap from T to E!T
        /// Uses `Data.un`.
        wrap_errunion_payload,
        /// wrap from E to E!T
        /// Uses `Data.un`.
        wrap_errunion_err,

        /// Addition. Overflow is undefined behavior.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        add,
        /// Addition. Overflow is two's complement wrapping.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        addwrap,
        /// Subtraction. Overflow is undefined behavior.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        sub,
        /// Subtraction. Overflow is two's complement wrapping.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        subwrap,
        /// Multiplication. Overflow is undefined behavior.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        mul,
        /// Multiplication. Overflow is two's complement wrapping.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        mulwrap,
        /// Division. Overflow is undefined behavior.
        /// Result type is the same as both operands.
        /// Uses `Data.bin`.
        div,

        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_lt,
        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_lte,
        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_eq,
        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_gte,
        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_gt,
        /// Result type is `bool` or vector of `bool`, depending on
        /// whether the operands are vectors.
        /// Uses `Data.bin`.
        cmp_neq,

        /// Write a value to a pointer.
        /// No result.
        /// Uses `Data.bin`. LHS is pointer, RHS is value.
        store,

        /// Result type is `bool`.
        /// Uses `Data.bin`.
        bool_and,
        /// Result type is `bool`.
        /// Uses `Data.bin`.
        bool_or,
        /// Result type is same as both operands.
        /// Uses `Data.bin`.
        bit_and,
        /// Result type is same as both operands.
        /// Uses `Data.bin`.
        bit_or,
        /// Result type is same as both operands.
        /// Uses `Data.bin`.
        xor,

        /// Uses `Data.pl_ty`, `Asm` payload.
        assembly,
        /// Same as `assembly` except has side effects.
        assembly_volatile,
        /// Uses `pl_ty`, `Block` payload.
        block,
        /// Uses `Data.br`.
        /// Result type is `noreturn`.
        br,

        // TODO I haven't looked at the tags below this yet

        /// Same as `br` except the operand is a list of instructions to be treated as
        /// a flat block; that is there is only 1 break instruction from the block, and
        /// it is implied to be after the last instruction, and the last instruction is
        /// the break operand.
        /// This instruction exists for late-stage semantic analysis patch ups, to
        /// replace one br operand with multiple instructions, without moving anything else around.
        br_block_flat,
        call,
        condbr,
        constant,
        dbg_stmt,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        loop,
        varptr,
        switchbr,
        /// Given a pointer to a struct and a field index, returns a pointer to the field.
        struct_field_ptr,
    };

    /// The position of an AIR instruction within the `Air` instructions array.
    pub const Index = u32;

    pub const Ref = @import("Zir.zig").Inst.Ref;

    /// All instructions have an 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        none: void,
        ty: Type,
        un: struct {
            ty: Type,
            op: Ref,
        },
        bin: Bin,
        pl_ty: struct {
            ty: Type,
            payload_index: u32,
        },
        br: struct {
            block: Index,
            operand: Ref,
        },

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (std.builtin.mode != .Debug) {
                assert(@sizeOf(Data) == 8);
            }
        }
    };

    /// The meaning of these operands depends on the corresponding `Tag`.
    pub const Bin = struct {
        lhs: Ref,
        rhs: Ref,
    };

    /// Trailing:
    /// * output_constraint: u32 // string index, one for every output_constraints_len
    /// * input: u32 // string index, one for every inputs_len
    /// * clobber: u32 // string index, one for every clobbers_len
    /// * arg: Ref // one for every args_len
    pub const Asm = struct {
        /// String index into the corresponding ZIR.
        asm_source: u32,
        output_constraints_len: u32,
        inputs_len: u32,
        clobbers_len: u32,
        args_len: u32,
    };

    /// Trailing:
    /// * instruction: Index // for each body_len
    pub const Block = struct {
        body_len: u32,
    };
};
