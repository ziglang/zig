//! Analyzed Intermediate Representation.
//! This data is produced by Sema and consumed by codegen.
//! Unlike ZIR where there is one instance for an entire source file, each function
//! gets its own `Air` instance.

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const Air = @This();
const Value = @import("Value.zig");
const Type = @import("type.zig").Type;
const InternPool = @import("InternPool.zig");
const Module = @import("Module.zig");

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
/// The first few indexes are reserved. See `ExtraIndex` for the values.
extra: []const u32,

pub const ExtraIndex = enum(u32) {
    /// Payload index of the main `Block` in the `extra` array.
    main_block,

    _,
};

pub const Inst = struct {
    tag: Tag,
    data: Data,

    pub const Tag = enum(u8) {
        /// The first N instructions in the main block must be one arg instruction per
        /// function parameter. This makes function parameters participate in
        /// liveness analysis without any special handling.
        /// Uses the `arg` field.
        arg,
        /// Float or integer addition. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        add,
        /// Integer addition. Wrapping is a safety panic.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// The panic handler function must be populated before lowering AIR
        /// that contains this instruction.
        /// This instruction will only be emitted if the backend has the
        /// feature `safety_checked_instructions`.
        /// Uses the `bin_op` field.
        add_safe,
        /// Float addition. The instruction is allowed to have equal or more
        /// mathematical accuracy than strict IEEE-757 float addition.
        /// If either operand is NaN, the result value is undefined.
        /// Uses the `bin_op` field.
        add_optimized,
        /// Twos complement wrapping integer addition.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        add_wrap,
        /// Saturating integer addition.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        add_sat,
        /// Float or integer subtraction. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        sub,
        /// Integer subtraction. Wrapping is a safety panic.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// The panic handler function must be populated before lowering AIR
        /// that contains this instruction.
        /// This instruction will only be emitted if the backend has the
        /// feature `safety_checked_instructions`.
        /// Uses the `bin_op` field.
        sub_safe,
        /// Float subtraction. The instruction is allowed to have equal or more
        /// mathematical accuracy than strict IEEE-757 float subtraction.
        /// If either operand is NaN, the result value is undefined.
        /// Uses the `bin_op` field.
        sub_optimized,
        /// Twos complement wrapping integer subtraction.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        sub_wrap,
        /// Saturating integer subtraction.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        sub_sat,
        /// Float or integer multiplication. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mul,
        /// Integer multiplication. Wrapping is a safety panic.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// The panic handler function must be populated before lowering AIR
        /// that contains this instruction.
        /// This instruction will only be emitted if the backend has the
        /// feature `safety_checked_instructions`.
        /// Uses the `bin_op` field.
        mul_safe,
        /// Float multiplication. The instruction is allowed to have equal or more
        /// mathematical accuracy than strict IEEE-757 float multiplication.
        /// If either operand is NaN, the result value is undefined.
        /// Uses the `bin_op` field.
        mul_optimized,
        /// Twos complement wrapping integer multiplication.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mul_wrap,
        /// Saturating integer multiplication.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mul_sat,
        /// Float division.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_float,
        /// Same as `div_float` with optimized float mode.
        div_float_optimized,
        /// Truncating integer or float division. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_trunc,
        /// Same as `div_trunc` with optimized float mode.
        div_trunc_optimized,
        /// Flooring integer or float division. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_floor,
        /// Same as `div_floor` with optimized float mode.
        div_floor_optimized,
        /// Integer or float division.
        /// If a remainder would be produced, undefined behavior occurs.
        /// For integers, overflow is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_exact,
        /// Same as `div_exact` with optimized float mode.
        div_exact_optimized,
        /// Integer or float remainder division.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        rem,
        /// Same as `rem` with optimized float mode.
        rem_optimized,
        /// Integer or float modulus division.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mod,
        /// Same as `mod` with optimized float mode.
        mod_optimized,
        /// Add an offset to a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
        /// The pointer may be a slice.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        ptr_add,
        /// Subtract an offset from a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
        /// The pointer may be a slice.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        ptr_sub,
        /// Given two operands which can be floats, integers, or vectors, returns the
        /// greater of the operands. For vectors it operates element-wise.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        max,
        /// Given two operands which can be floats, integers, or vectors, returns the
        /// lesser of the operands. For vectors it operates element-wise.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        min,
        /// Integer addition with overflow. Both operands are guaranteed to be the same type,
        /// and the result is a tuple with .{res, ov}. The wrapped value is written to res
        /// and if an overflow happens, ov is 1. Otherwise ov is 0.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        add_with_overflow,
        /// Integer subtraction with overflow. Both operands are guaranteed to be the same type,
        /// and the result is a tuple with .{res, ov}. The wrapped value is written to res
        /// and if an overflow happens, ov is 1. Otherwise ov is 0.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        sub_with_overflow,
        /// Integer multiplication with overflow. Both operands are guaranteed to be the same type,
        /// and the result is a tuple with .{res, ov}. The wrapped value is written to res
        /// and if an overflow happens, ov is 1. Otherwise ov is 0.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        mul_with_overflow,
        /// Integer left-shift with overflow. Both operands are guaranteed to be the same type,
        /// and the result is a tuple with .{res, ov}. The wrapped value is written to res
        /// and if an overflow happens, ov is 1. Otherwise ov is 0.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        shl_with_overflow,
        /// Allocates stack local memory.
        /// Uses the `ty` field.
        alloc,
        /// This special instruction only exists temporarily during semantic
        /// analysis and is guaranteed to be unreachable in machine code
        /// backends. It tracks a set of types that have been stored to an
        /// inferred allocation.
        /// Uses the `inferred_alloc` field.
        inferred_alloc,
        /// This special instruction only exists temporarily during semantic
        /// analysis and is guaranteed to be unreachable in machine code
        /// backends. Used to coordinate alloc_inferred, store_to_inferred_ptr,
        /// and resolve_inferred_alloc instructions for comptime code.
        /// Uses the `inferred_alloc_comptime` field.
        inferred_alloc_comptime,
        /// If the function will pass the result by-ref, this instruction returns the
        /// result pointer. Otherwise it is equivalent to `alloc`.
        /// Uses the `ty` field.
        ret_ptr,
        /// Inline assembly. Uses the `ty_pl` field. Payload is `Asm`.
        assembly,
        /// Bitwise AND. `&`.
        /// Result type is the same as both operands.
        /// Uses the `bin_op` field.
        bit_and,
        /// Bitwise OR. `|`.
        /// Result type is the same as both operands.
        /// Uses the `bin_op` field.
        bit_or,
        /// Shift right. `>>`
        /// Uses the `bin_op` field.
        shr,
        /// Shift right. The shift produces a poison value if it shifts out any non-zero bits.
        /// Uses the `bin_op` field.
        shr_exact,
        /// Shift left. `<<`
        /// Uses the `bin_op` field.
        shl,
        /// Shift left; For unsigned integers, the shift produces a poison value if it shifts
        /// out any non-zero bits. For signed integers, the shift produces a poison value if
        /// it shifts out any bits that disagree with the resultant sign bit.
        /// Uses the `bin_op` field.
        shl_exact,
        /// Saturating integer shift left. `<<|`
        /// Uses the `bin_op` field.
        shl_sat,
        /// Bitwise XOR. `^`
        /// Uses the `bin_op` field.
        xor,
        /// Boolean or binary NOT.
        /// Uses the `ty_op` field.
        not,
        /// Reinterpret the memory representation of a value as a different type.
        /// Uses the `ty_op` field.
        bitcast,
        /// Uses the `ty_pl` field with payload `Block`.  A block runs its body which always ends
        /// with a `noreturn` instruction, so the only way to proceed to the code after the `block`
        /// is to encounter a `br` that targets this `block`.  If the `block` type is `noreturn`,
        /// then there do not exist any `br` instructions targetting this `block`.
        block,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        /// Result type is always `noreturn`; no instructions in a block follow this one.
        /// The body never ends with a `noreturn` instruction, so the "repeat" operation
        /// is always statically reachable.
        /// Uses the `ty_pl` field. Payload is `Block`.
        loop,
        /// Return from a block with a result.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `br` field.
        br,
        /// Lowers to a trap/jam instruction causing program abortion.
        /// This may lower to an instruction known to be invalid.
        /// Sometimes, for the lack of a better instruction, `trap` and `breakpoint` may compile down to the same code.
        /// Result type is always noreturn; no instructions in a block follow this one.
        trap,
        /// Lowers to a trap instruction causing debuggers to break here, or the next best thing.
        /// The debugger or something else may allow the program to resume after this point.
        /// Sometimes, for the lack of a better instruction, `trap` and `breakpoint` may compile down to the same code.
        /// Result type is always void.
        breakpoint,
        /// Yields the return address of the current function.
        /// Uses the `no_op` field.
        ret_addr,
        /// Implements @frameAddress builtin.
        /// Uses the `no_op` field.
        frame_addr,
        /// Function call.
        /// Result type is the return type of the function being called.
        /// Uses the `pl_op` field with the `Call` payload. operand is the callee.
        /// Triggers `resolveTypeLayout` on the return type of the callee.
        call,
        /// Same as `call` except with the `always_tail` attribute.
        call_always_tail,
        /// Same as `call` except with the `never_tail` attribute.
        call_never_tail,
        /// Same as `call` except with the `never_inline` attribute.
        call_never_inline,
        /// Count leading zeroes of an integer according to its representation in twos complement.
        /// Result type will always be an unsigned integer big enough to fit the answer.
        /// Uses the `ty_op` field.
        clz,
        /// Count trailing zeroes of an integer according to its representation in twos complement.
        /// Result type will always be an unsigned integer big enough to fit the answer.
        /// Uses the `ty_op` field.
        ctz,
        /// Count number of 1 bits in an integer according to its representation in twos complement.
        /// Result type will always be an unsigned integer big enough to fit the answer.
        /// Uses the `ty_op` field.
        popcount,
        /// Reverse the bytes in an integer according to its representation in twos complement.
        /// Uses the `ty_op` field.
        byte_swap,
        /// Reverse the bits in an integer according to its representation in twos complement.
        /// Uses the `ty_op` field.
        bit_reverse,

        /// Square root of a floating point number.
        /// Uses the `un_op` field.
        sqrt,
        /// Sine function on a floating point number.
        /// Uses the `un_op` field.
        sin,
        /// Cosine function on a floating point number.
        /// Uses the `un_op` field.
        cos,
        /// Tangent function on a floating point number.
        /// Uses the `un_op` field.
        tan,
        /// Base e exponential of a floating point number.
        /// Uses the `un_op` field.
        exp,
        /// Base 2 exponential of a floating point number.
        /// Uses the `un_op` field.
        exp2,
        /// Natural (base e) logarithm of a floating point number.
        /// Uses the `un_op` field.
        log,
        /// Base 2 logarithm of a floating point number.
        /// Uses the `un_op` field.
        log2,
        /// Base 10 logarithm of a floating point number.
        /// Uses the `un_op` field.
        log10,
        /// Aboslute value of an integer, floating point number or vector.
        /// Result type is always unsigned if the operand is an integer.
        /// Uses the `ty_op` field.
        abs,
        /// Floor: rounds a floating pointer number down to the nearest integer.
        /// Uses the `un_op` field.
        floor,
        /// Ceiling: rounds a floating pointer number up to the nearest integer.
        /// Uses the `un_op` field.
        ceil,
        /// Rounds a floating pointer number to the nearest integer.
        /// Uses the `un_op` field.
        round,
        /// Rounds a floating pointer number to the nearest integer towards zero.
        /// Uses the `un_op` field.
        trunc_float,
        /// Float negation. This affects the sign of zero, inf, and NaN, which is impossible
        /// to do with sub. Integers are not allowed and must be represented with sub with
        /// LHS of zero.
        /// Uses the `un_op` field.
        neg,
        /// Same as `neg` with optimized float mode.
        neg_optimized,

        /// `<`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lt,
        /// Same as `cmp_lt` with optimized float mode.
        cmp_lt_optimized,
        /// `<=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lte,
        /// Same as `cmp_lte` with optimized float mode.
        cmp_lte_optimized,
        /// `==`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_eq,
        /// Same as `cmp_eq` with optimized float mode.
        cmp_eq_optimized,
        /// `>=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gte,
        /// Same as `cmp_gte` with optimized float mode.
        cmp_gte_optimized,
        /// `>`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gt,
        /// Same as `cmp_gt` with optimized float mode.
        cmp_gt_optimized,
        /// `!=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_neq,
        /// Same as `cmp_neq` with optimized float mode.
        cmp_neq_optimized,
        /// Conditional between two vectors.
        /// Result type is always a vector of bools.
        /// Uses the `ty_pl` field, payload is `VectorCmp`.
        cmp_vector,
        /// Same as `cmp_vector` with optimized float mode.
        cmp_vector_optimized,

        /// Conditional branch.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `pl_op` field. Operand is the condition. Payload is `CondBr`.
        cond_br,
        /// Switch branch.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `pl_op` field. Operand is the condition. Payload is `SwitchBr`.
        switch_br,
        /// Given an operand which is an error union, splits control flow. In
        /// case of error, control flow goes into the block that is part of this
        /// instruction, which is guaranteed to end with a return instruction
        /// and never breaks out of the block.
        /// In the case of non-error, control flow proceeds to the next instruction
        /// after the `try`, with the result of this instruction being the unwrapped
        /// payload value, as if `unwrap_errunion_payload` was executed on the operand.
        /// Uses the `pl_op` field. Payload is `Try`.
        @"try",
        /// Same as `try` except the operand is a pointer to an error union, and the
        /// result is a pointer to the payload. Result is as if `unwrap_errunion_payload_ptr`
        /// was executed on the operand.
        /// Uses the `ty_pl` field. Payload is `TryPtr`.
        try_ptr,
        /// Notes the beginning of a source code statement and marks the line and column.
        /// Result type is always void.
        /// Uses the `dbg_stmt` field.
        dbg_stmt,
        /// A block that represents an inlined function call.
        /// Uses the `ty_pl` field. Payload is `DbgInlineBlock`.
        dbg_inline_block,
        /// Marks the beginning of a local variable. The operand is a pointer pointing
        /// to the storage for the variable. The local may be a const or a var.
        /// Result type is always void.
        /// Uses `pl_op`. The payload index is the variable name. It points to the extra
        /// array, reinterpreting the bytes there as a null-terminated string.
        dbg_var_ptr,
        /// Same as `dbg_var_ptr` except the local is a const, not a var, and the
        /// operand is the local's value.
        dbg_var_val,
        /// ?T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_null,
        /// ?T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_null,
        /// *?T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_null_ptr,
        /// *?T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_null_ptr,
        /// E!T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_err,
        /// E!T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_err,
        /// *E!T => bool
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_err_ptr,
        /// *E!T => bool (inverted logic)
        /// Result type is always bool.
        /// Uses the `un_op` field.
        is_non_err_ptr,
        /// Result type is always bool.
        /// Uses the `bin_op` field.
        bool_and,
        /// Result type is always bool.
        /// Uses the `bin_op` field.
        bool_or,
        /// Read a value from a pointer.
        /// Uses the `ty_op` field.
        load,
        /// Converts a pointer to its address. Result type is always `usize`.
        /// Pointer type size may be any, including slice.
        /// Uses the `un_op` field.
        int_from_ptr,
        /// Given a boolean, returns 0 or 1.
        /// Result type is always `u1`.
        /// Uses the `un_op` field.
        int_from_bool,
        /// Return a value from a function.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `un_op` field.
        /// Triggers `resolveTypeLayout` on the return type.
        ret,
        /// Same as `ret`, except if the operand is undefined, the
        /// returned value is 0xaa bytes, and any other safety metadata
        /// such as Valgrind integrations should be notified of
        /// this value being undefined.
        ret_safe,
        /// This instruction communicates that the function's result value is pointed to by
        /// the operand. If the function will pass the result by-ref, the operand is a
        /// `ret_ptr` instruction. Otherwise, this instruction is equivalent to a `load`
        /// on the operand, followed by a `ret` on the loaded value.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `un_op` field.
        /// Triggers `resolveTypeLayout` on the return type.
        ret_load,
        /// Write a value to a pointer. LHS is pointer, RHS is value.
        /// Result type is always void.
        /// Uses the `bin_op` field.
        /// The value to store may be undefined, in which case the destination
        /// memory region has undefined bytes after this instruction is
        /// evaluated. In such case ignoring this instruction is legal
        /// lowering.
        store,
        /// Same as `store`, except if the value to store is undefined, the
        /// memory region should be filled with 0xaa bytes, and any other
        /// safety metadata such as Valgrind integrations should be notified of
        /// this memory region being undefined.
        store_safe,
        /// Indicates the program counter will never get to this instruction.
        /// Result type is always noreturn; no instructions in a block follow this one.
        unreach,
        /// Convert from a float type to a smaller one.
        /// Uses the `ty_op` field.
        fptrunc,
        /// Convert from a float type to a wider one.
        /// Uses the `ty_op` field.
        fpext,
        /// Returns an integer with a different type than the operand. The new type may have
        /// fewer, the same, or more bits than the operand type. The new type may also
        /// differ in signedness from the operand type. However, the instruction
        /// guarantees that the same integer value fits in both types.
        /// The new type may also be an enum type, in which case the integer cast operates on
        /// the integer tag type of the enum.
        /// See `trunc` for integer truncation.
        /// Uses the `ty_op` field.
        intcast,
        /// Truncate higher bits from an integer, resulting in an integer with the same
        /// sign but an equal or smaller number of bits.
        /// Uses the `ty_op` field.
        trunc,
        /// ?T => T. If the value is null, undefined behavior.
        /// Uses the `ty_op` field.
        optional_payload,
        /// *?T => *T. If the value is null, undefined behavior.
        /// Uses the `ty_op` field.
        optional_payload_ptr,
        /// *?T => *T. Sets the value to non-null with an undefined payload value.
        /// Uses the `ty_op` field.
        optional_payload_ptr_set,
        /// Given a payload value, wraps it in an optional type.
        /// Uses the `ty_op` field.
        wrap_optional,
        /// E!T -> T. If the value is an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_payload,
        /// E!T -> E. If the value is not an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_err,
        /// *(E!T) -> *T. If the value is an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_payload_ptr,
        /// *(E!T) -> E. If the value is not an error, undefined behavior.
        /// Uses the `ty_op` field.
        unwrap_errunion_err_ptr,
        /// *(E!T) => *T. Sets the value to non-error with an undefined payload value.
        /// Uses the `ty_op` field.
        errunion_payload_ptr_set,
        /// wrap from T to E!T
        /// Uses the `ty_op` field.
        wrap_errunion_payload,
        /// wrap from E to E!T
        /// Uses the `ty_op` field.
        wrap_errunion_err,
        /// Given a pointer to a struct or union and a field index, returns a pointer to the field.
        /// Uses the `ty_pl` field, payload is `StructField`.
        /// TODO rename to `agg_field_ptr`.
        struct_field_ptr,
        /// Given a pointer to a struct or union, returns a pointer to the field.
        /// The field index is the number at the end of the name.
        /// Uses `ty_op` field.
        /// TODO rename to `agg_field_ptr_index_X`
        struct_field_ptr_index_0,
        struct_field_ptr_index_1,
        struct_field_ptr_index_2,
        struct_field_ptr_index_3,
        /// Given a byval struct or union and a field index, returns the field byval.
        /// Uses the `ty_pl` field, payload is `StructField`.
        /// TODO rename to `agg_field_val`
        struct_field_val,
        /// Given a pointer to a tagged union, set its tag to the provided value.
        /// Result type is always void.
        /// Uses the `bin_op` field. LHS is union pointer, RHS is new tag value.
        set_union_tag,
        /// Given a tagged union value, get its tag value.
        /// Uses the `ty_op` field.
        get_union_tag,
        /// Constructs a slice from a pointer and a length.
        /// Uses the `ty_pl` field, payload is `Bin`. lhs is ptr, rhs is len.
        slice,
        /// Given a slice value, return the length.
        /// Result type is always usize.
        /// Uses the `ty_op` field.
        slice_len,
        /// Given a slice value, return the pointer.
        /// Uses the `ty_op` field.
        slice_ptr,
        /// Given a pointer to a slice, return a pointer to the length of the slice.
        /// Uses the `ty_op` field.
        ptr_slice_len_ptr,
        /// Given a pointer to a slice, return a pointer to the pointer of the slice.
        /// Uses the `ty_op` field.
        ptr_slice_ptr_ptr,
        /// Given an (array value or vector value) and element index,
        /// return the element value at that index.
        /// Result type is the element type of the array operand.
        /// Uses the `bin_op` field.
        array_elem_val,
        /// Given a slice value, and element index, return the element value at that index.
        /// Result type is the element type of the slice operand.
        /// Uses the `bin_op` field.
        slice_elem_val,
        /// Given a slice value and element index, return a pointer to the element value at that index.
        /// Result type is a pointer to the element type of the slice operand.
        /// Uses the `ty_pl` field with payload `Bin`.
        slice_elem_ptr,
        /// Given a pointer value, and element index, return the element value at that index.
        /// Result type is the element type of the pointer operand.
        /// Uses the `bin_op` field.
        ptr_elem_val,
        /// Given a pointer value, and element index, return the element pointer at that index.
        /// Result type is pointer to the element type of the pointer operand.
        /// Uses the `ty_pl` field with payload `Bin`.
        ptr_elem_ptr,
        /// Given a pointer to an array, return a slice.
        /// Uses the `ty_op` field.
        array_to_slice,
        /// Given a float operand, return the integer with the closest mathematical meaning.
        /// Uses the `ty_op` field.
        int_from_float,
        /// Same as `int_from_float` with optimized float mode.
        int_from_float_optimized,
        /// Given an integer operand, return the float with the closest mathematical meaning.
        /// Uses the `ty_op` field.
        float_from_int,

        /// Transforms a vector into a scalar value by performing a sequential
        /// horizontal reduction of its elements using the specified operator.
        /// The vector element type (and hence result type) will be:
        ///  * and, or, xor       => integer or boolean
        ///  * min, max, add, mul => integer or float
        /// Uses the `reduce` field.
        reduce,
        /// Same as `reduce` with optimized float mode.
        reduce_optimized,
        /// Given an integer, bool, float, or pointer operand, return a vector with all elements
        /// equal to the scalar value.
        /// Uses the `ty_op` field.
        splat,
        /// Constructs a vector by selecting elements from `a` and `b` based on `mask`.
        /// Uses the `ty_pl` field with payload `Shuffle`.
        shuffle,
        /// Constructs a vector element-wise from `a` or `b` based on `pred`.
        /// Uses the `pl_op` field with `pred` as operand, and payload `Bin`.
        select,

        /// Given dest pointer and value, set all elements at dest to value.
        /// Dest pointer is either a slice or a pointer to array.
        /// The element type may be any type, and the slice may have any alignment.
        /// Result type is always void.
        /// Uses the `bin_op` field. LHS is the dest slice. RHS is the element value.
        /// The element value may be undefined, in which case the destination
        /// memory region has undefined bytes after this instruction is
        /// evaluated. In such case ignoring this instruction is legal
        /// lowering.
        /// If the length is compile-time known (due to the destination being a
        /// pointer-to-array), then it is guaranteed to be greater than zero.
        memset,
        /// Same as `memset`, except if the element value is undefined, the memory region
        /// should be filled with 0xaa bytes, and any other safety metadata such as Valgrind
        /// integrations should be notified of this memory region being undefined.
        memset_safe,
        /// Given dest pointer and source pointer, copy elements from source to dest.
        /// Dest pointer is either a slice or a pointer to array.
        /// The dest element type may be any type.
        /// Source pointer must have same element type as dest element type.
        /// Dest slice may have any alignment; source pointer may have any alignment.
        /// The two memory regions must not overlap.
        /// Result type is always void.
        /// Uses the `bin_op` field. LHS is the dest slice. RHS is the source pointer.
        /// If the length is compile-time known (due to the destination or
        /// source being a pointer-to-array), then it is guaranteed to be
        /// greater than zero.
        memcpy,

        /// Uses the `ty_pl` field with payload `Cmpxchg`.
        cmpxchg_weak,
        /// Uses the `ty_pl` field with payload `Cmpxchg`.
        cmpxchg_strong,
        /// Lowers to a memory fence instruction.
        /// Result type is always void.
        /// Uses the `fence` field.
        fence,
        /// Atomically load from a pointer.
        /// Result type is the element type of the pointer.
        /// Uses the `atomic_load` field.
        atomic_load,
        /// Atomically store through a pointer.
        /// Result type is always `void`.
        /// Uses the `bin_op` field. LHS is pointer, RHS is element.
        atomic_store_unordered,
        /// Same as `atomic_store_unordered` but with `AtomicOrder.monotonic`.
        atomic_store_monotonic,
        /// Same as `atomic_store_unordered` but with `AtomicOrder.release`.
        atomic_store_release,
        /// Same as `atomic_store_unordered` but with `AtomicOrder.seq_cst`.
        atomic_store_seq_cst,
        /// Atomically read-modify-write via a pointer.
        /// Result type is the element type of the pointer.
        /// Uses the `pl_op` field with payload `AtomicRmw`. Operand is `ptr`.
        atomic_rmw,

        /// Returns true if enum tag value has a name.
        /// Uses the `un_op` field.
        is_named_enum_value,

        /// Given an enum tag value, returns the tag name. The enum type may be non-exhaustive.
        /// Result type is always `[:0]const u8`.
        /// Uses the `un_op` field.
        tag_name,

        /// Given an error value, return the error name. Result type is always `[:0]const u8`.
        /// Uses the `un_op` field.
        error_name,

        /// Returns true if error set has error with value.
        /// Uses the `ty_op` field.
        error_set_has_value,

        /// Constructs a vector, tuple, struct, or array value out of runtime-known elements.
        /// Some of the elements may be comptime-known.
        /// Uses the `ty_pl` field, payload is index of an array of elements, each of which
        /// is a `Ref`. Length of the array is given by the vector type.
        /// If the type is an array with a sentinel, the AIR elements do not include it
        /// explicitly.
        aggregate_init,

        /// Constructs a union from a field index and a runtime-known init value.
        /// Uses the `ty_pl` field with payload `UnionInit`.
        union_init,

        /// Communicates an intent to load memory.
        /// Result is always unused.
        /// Uses the `prefetch` field.
        prefetch,

        /// Computes `(a * b) + c`, but only rounds once.
        /// Uses the `pl_op` field with payload `Bin`.
        /// The operand is the addend. The mulends are lhs and rhs.
        mul_add,

        /// Implements @fieldParentPtr builtin.
        /// Uses the `ty_pl` field.
        field_parent_ptr,

        /// Implements @wasmMemorySize builtin.
        /// Result type is always `u32`,
        /// Uses the `pl_op` field, payload represents the index of the target memory.
        /// The operand is unused and always set to `Ref.none`.
        wasm_memory_size,

        /// Implements @wasmMemoryGrow builtin.
        /// Result type is always `i32`,
        /// Uses the `pl_op` field, payload represents the index of the target memory.
        wasm_memory_grow,

        /// Returns `true` if and only if the operand, an integer with
        /// the same size as the error integer type, is less than the
        /// total number of errors in the Module.
        /// Result type is always `bool`.
        /// Uses the `un_op` field.
        /// Note that the number of errors in the Module cannot be considered stable until
        /// flush().
        cmp_lt_errors_len,

        /// Returns pointer to current error return trace.
        err_return_trace,

        /// Sets the operand as the current error return trace,
        set_err_return_trace,

        /// Convert the address space of a pointer.
        /// Uses the `ty_op` field.
        addrspace_cast,

        /// Saves the error return trace index, if any. Otherwise, returns 0.
        /// Uses the `ty_pl` field.
        save_err_return_trace_index,

        /// Store an element to a vector pointer at an index.
        /// Uses the `vector_store_elem` field.
        vector_store_elem,

        /// Implements @cVaArg builtin.
        /// Uses the `ty_op` field.
        c_va_arg,
        /// Implements @cVaCopy builtin.
        /// Uses the `ty_op` field.
        c_va_copy,
        /// Implements @cVaEnd builtin.
        /// Uses the `un_op` field.
        c_va_end,
        /// Implements @cVaStart builtin.
        /// Uses the `ty` field.
        c_va_start,

        /// Implements @workItemId builtin.
        /// Result type is always `u32`
        /// Uses the `pl_op` field, payload is the dimension to get the work item id for.
        /// Operand is unused and set to Ref.none
        work_item_id,
        /// Implements @workGroupSize builtin.
        /// Result type is always `u32`
        /// Uses the `pl_op` field, payload is the dimension to get the work group size for.
        /// Operand is unused and set to Ref.none
        work_group_size,
        /// Implements @workGroupId builtin.
        /// Result type is always `u32`
        /// Uses the `pl_op` field, payload is the dimension to get the work group id for.
        /// Operand is unused and set to Ref.none
        work_group_id,

        pub fn fromCmpOp(op: std.math.CompareOperator, optimized: bool) Tag {
            switch (op) {
                .lt => return if (optimized) .cmp_lt_optimized else .cmp_lt,
                .lte => return if (optimized) .cmp_lte_optimized else .cmp_lte,
                .eq => return if (optimized) .cmp_eq_optimized else .cmp_eq,
                .gte => return if (optimized) .cmp_gte_optimized else .cmp_gte,
                .gt => return if (optimized) .cmp_gt_optimized else .cmp_gt,
                .neq => return if (optimized) .cmp_neq_optimized else .cmp_neq,
            }
        }

        pub fn toCmpOp(tag: Tag) ?std.math.CompareOperator {
            return switch (tag) {
                .cmp_lt, .cmp_lt_optimized => .lt,
                .cmp_lte, .cmp_lte_optimized => .lte,
                .cmp_eq, .cmp_eq_optimized => .eq,
                .cmp_gte, .cmp_gte_optimized => .gte,
                .cmp_gt, .cmp_gt_optimized => .gt,
                .cmp_neq, .cmp_neq_optimized => .neq,
                else => null,
            };
        }
    };

    /// The position of an AIR instruction within the `Air` instructions array.
    pub const Index = enum(u32) {
        _,

        pub fn toRef(i: Index) Inst.Ref {
            assert(@intFromEnum(i) >> 31 == 0);
            return @enumFromInt((1 << 31) | @intFromEnum(i));
        }

        pub fn toTargetIndex(i: Index) u31 {
            assert(@intFromEnum(i) >> 31 == 1);
            return @truncate(@intFromEnum(i));
        }
    };

    /// Either a reference to a value stored in the InternPool, or a reference to an AIR instruction.
    /// The most-significant bit of the value is a tag bit. This bit is 1 if the value represents an
    /// instruction index and 0 if it represents an InternPool index.
    ///
    /// The hardcoded refs `none` and `var_args_param_type` are exceptions to this rule: they have
    /// their tag bit set but refer to the InternPool.
    pub const Ref = enum(u32) {
        u0_type = @intFromEnum(InternPool.Index.u0_type),
        i0_type = @intFromEnum(InternPool.Index.i0_type),
        u1_type = @intFromEnum(InternPool.Index.u1_type),
        u8_type = @intFromEnum(InternPool.Index.u8_type),
        i8_type = @intFromEnum(InternPool.Index.i8_type),
        u16_type = @intFromEnum(InternPool.Index.u16_type),
        i16_type = @intFromEnum(InternPool.Index.i16_type),
        u29_type = @intFromEnum(InternPool.Index.u29_type),
        u32_type = @intFromEnum(InternPool.Index.u32_type),
        i32_type = @intFromEnum(InternPool.Index.i32_type),
        u64_type = @intFromEnum(InternPool.Index.u64_type),
        i64_type = @intFromEnum(InternPool.Index.i64_type),
        u80_type = @intFromEnum(InternPool.Index.u80_type),
        u128_type = @intFromEnum(InternPool.Index.u128_type),
        i128_type = @intFromEnum(InternPool.Index.i128_type),
        usize_type = @intFromEnum(InternPool.Index.usize_type),
        isize_type = @intFromEnum(InternPool.Index.isize_type),
        c_char_type = @intFromEnum(InternPool.Index.c_char_type),
        c_short_type = @intFromEnum(InternPool.Index.c_short_type),
        c_ushort_type = @intFromEnum(InternPool.Index.c_ushort_type),
        c_int_type = @intFromEnum(InternPool.Index.c_int_type),
        c_uint_type = @intFromEnum(InternPool.Index.c_uint_type),
        c_long_type = @intFromEnum(InternPool.Index.c_long_type),
        c_ulong_type = @intFromEnum(InternPool.Index.c_ulong_type),
        c_longlong_type = @intFromEnum(InternPool.Index.c_longlong_type),
        c_ulonglong_type = @intFromEnum(InternPool.Index.c_ulonglong_type),
        c_longdouble_type = @intFromEnum(InternPool.Index.c_longdouble_type),
        f16_type = @intFromEnum(InternPool.Index.f16_type),
        f32_type = @intFromEnum(InternPool.Index.f32_type),
        f64_type = @intFromEnum(InternPool.Index.f64_type),
        f80_type = @intFromEnum(InternPool.Index.f80_type),
        f128_type = @intFromEnum(InternPool.Index.f128_type),
        anyopaque_type = @intFromEnum(InternPool.Index.anyopaque_type),
        bool_type = @intFromEnum(InternPool.Index.bool_type),
        void_type = @intFromEnum(InternPool.Index.void_type),
        type_type = @intFromEnum(InternPool.Index.type_type),
        anyerror_type = @intFromEnum(InternPool.Index.anyerror_type),
        comptime_int_type = @intFromEnum(InternPool.Index.comptime_int_type),
        comptime_float_type = @intFromEnum(InternPool.Index.comptime_float_type),
        noreturn_type = @intFromEnum(InternPool.Index.noreturn_type),
        anyframe_type = @intFromEnum(InternPool.Index.anyframe_type),
        null_type = @intFromEnum(InternPool.Index.null_type),
        undefined_type = @intFromEnum(InternPool.Index.undefined_type),
        enum_literal_type = @intFromEnum(InternPool.Index.enum_literal_type),
        atomic_order_type = @intFromEnum(InternPool.Index.atomic_order_type),
        atomic_rmw_op_type = @intFromEnum(InternPool.Index.atomic_rmw_op_type),
        calling_convention_type = @intFromEnum(InternPool.Index.calling_convention_type),
        address_space_type = @intFromEnum(InternPool.Index.address_space_type),
        float_mode_type = @intFromEnum(InternPool.Index.float_mode_type),
        reduce_op_type = @intFromEnum(InternPool.Index.reduce_op_type),
        call_modifier_type = @intFromEnum(InternPool.Index.call_modifier_type),
        prefetch_options_type = @intFromEnum(InternPool.Index.prefetch_options_type),
        export_options_type = @intFromEnum(InternPool.Index.export_options_type),
        extern_options_type = @intFromEnum(InternPool.Index.extern_options_type),
        type_info_type = @intFromEnum(InternPool.Index.type_info_type),
        manyptr_u8_type = @intFromEnum(InternPool.Index.manyptr_u8_type),
        manyptr_const_u8_type = @intFromEnum(InternPool.Index.manyptr_const_u8_type),
        manyptr_const_u8_sentinel_0_type = @intFromEnum(InternPool.Index.manyptr_const_u8_sentinel_0_type),
        single_const_pointer_to_comptime_int_type = @intFromEnum(InternPool.Index.single_const_pointer_to_comptime_int_type),
        slice_const_u8_type = @intFromEnum(InternPool.Index.slice_const_u8_type),
        slice_const_u8_sentinel_0_type = @intFromEnum(InternPool.Index.slice_const_u8_sentinel_0_type),
        optional_noreturn_type = @intFromEnum(InternPool.Index.optional_noreturn_type),
        anyerror_void_error_union_type = @intFromEnum(InternPool.Index.anyerror_void_error_union_type),
        adhoc_inferred_error_set_type = @intFromEnum(InternPool.Index.adhoc_inferred_error_set_type),
        generic_poison_type = @intFromEnum(InternPool.Index.generic_poison_type),
        empty_struct_type = @intFromEnum(InternPool.Index.empty_struct_type),
        undef = @intFromEnum(InternPool.Index.undef),
        zero = @intFromEnum(InternPool.Index.zero),
        zero_usize = @intFromEnum(InternPool.Index.zero_usize),
        zero_u8 = @intFromEnum(InternPool.Index.zero_u8),
        one = @intFromEnum(InternPool.Index.one),
        one_usize = @intFromEnum(InternPool.Index.one_usize),
        one_u8 = @intFromEnum(InternPool.Index.one_u8),
        four_u8 = @intFromEnum(InternPool.Index.four_u8),
        negative_one = @intFromEnum(InternPool.Index.negative_one),
        calling_convention_c = @intFromEnum(InternPool.Index.calling_convention_c),
        calling_convention_inline = @intFromEnum(InternPool.Index.calling_convention_inline),
        void_value = @intFromEnum(InternPool.Index.void_value),
        unreachable_value = @intFromEnum(InternPool.Index.unreachable_value),
        null_value = @intFromEnum(InternPool.Index.null_value),
        bool_true = @intFromEnum(InternPool.Index.bool_true),
        bool_false = @intFromEnum(InternPool.Index.bool_false),
        empty_struct = @intFromEnum(InternPool.Index.empty_struct),
        generic_poison = @intFromEnum(InternPool.Index.generic_poison),

        /// This Ref does not correspond to any AIR instruction or constant
        /// value. It is used to handle argument types of var args functions.
        var_args_param_type = @intFromEnum(InternPool.Index.var_args_param_type),
        /// This Ref does not correspond to any AIR instruction or constant
        /// value and may instead be used as a sentinel to indicate null.
        none = @intFromEnum(InternPool.Index.none),
        _,

        pub fn toInterned(ref: Ref) ?InternPool.Index {
            assert(ref != .none);
            return ref.toInternedAllowNone();
        }

        pub fn toInternedAllowNone(ref: Ref) ?InternPool.Index {
            return switch (ref) {
                .var_args_param_type => .var_args_param_type,
                .none => .none,
                else => if (@intFromEnum(ref) >> 31 == 0)
                    @enumFromInt(@as(u31, @truncate(@intFromEnum(ref))))
                else
                    null,
            };
        }

        pub fn toIndex(ref: Ref) ?Index {
            assert(ref != .none);
            return ref.toIndexAllowNone();
        }

        pub fn toIndexAllowNone(ref: Ref) ?Index {
            return switch (ref) {
                .var_args_param_type, .none => null,
                else => if (@intFromEnum(ref) >> 31 != 0)
                    @enumFromInt(@as(u31, @truncate(@intFromEnum(ref))))
                else
                    null,
            };
        }

        pub fn toType(ref: Ref) Type {
            return Type.fromInterned(ref.toInterned().?);
        }
    };

    /// All instructions have an 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        no_op: void,
        un_op: Ref,

        bin_op: struct {
            lhs: Ref,
            rhs: Ref,
        },
        ty: Type,
        arg: struct {
            ty: Ref,
            src_index: u32,
        },
        ty_op: struct {
            ty: Ref,
            operand: Ref,
        },
        ty_pl: struct {
            ty: Ref,
            // Index into a different array.
            payload: u32,
        },
        br: struct {
            block_inst: Index,
            operand: Ref,
        },
        pl_op: struct {
            operand: Ref,
            payload: u32,
        },
        dbg_stmt: struct {
            line: u32,
            column: u32,
        },
        fence: std.builtin.AtomicOrder,
        atomic_load: struct {
            ptr: Ref,
            order: std.builtin.AtomicOrder,
        },
        prefetch: struct {
            ptr: Ref,
            rw: std.builtin.PrefetchOptions.Rw,
            locality: u2,
            cache: std.builtin.PrefetchOptions.Cache,
        },
        reduce: struct {
            operand: Ref,
            operation: std.builtin.ReduceOp,
        },
        vector_store_elem: struct {
            vector_ptr: Ref,
            // Index into a different array.
            payload: u32,
        },
        inferred_alloc_comptime: InferredAllocComptime,
        inferred_alloc: InferredAlloc,

        pub const InferredAllocComptime = struct {
            alignment: InternPool.Alignment,
            is_const: bool,
            /// This is `undefined` until we encounter a `store_to_inferred_alloc`,
            /// at which point the pointer is created and stored here.
            ptr: InternPool.Index,
        };

        pub const InferredAlloc = struct {
            alignment: InternPool.Alignment,
            is_const: bool,
        };

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in safety builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (!std.debug.runtime_safety) {
                assert(@sizeOf(Data) == 8);
            }
        }
    };
};

/// Trailing is a list of instruction indexes for every `body_len`.
pub const Block = struct {
    body_len: u32,
};

/// Trailing is a list of instruction indexes for every `body_len`.
pub const DbgInlineBlock = struct {
    func: InternPool.Index,
    body_len: u32,
};

/// Trailing is a list of `Inst.Ref` for every `args_len`.
pub const Call = struct {
    args_len: u32,
};

/// This data is stored inside extra, with two sets of trailing `Inst.Ref`:
/// * 0. the then body, according to `then_body_len`.
/// * 1. the else body, according to `else_body_len`.
pub const CondBr = struct {
    then_body_len: u32,
    else_body_len: u32,
};

/// Trailing:
/// * 0. `Case` for each `cases_len`
/// * 1. the else body, according to `else_body_len`.
pub const SwitchBr = struct {
    cases_len: u32,
    else_body_len: u32,

    /// Trailing:
    /// * item: Inst.Ref // for each `items_len`.
    /// * instruction index for each `body_len`.
    pub const Case = struct {
        items_len: u32,
        body_len: u32,
    };
};

/// This data is stored inside extra. Trailing:
/// 0. body: Inst.Index // for each body_len
pub const Try = struct {
    body_len: u32,
};

/// This data is stored inside extra. Trailing:
/// 0. body: Inst.Index // for each body_len
pub const TryPtr = struct {
    ptr: Inst.Ref,
    body_len: u32,
};

pub const StructField = struct {
    /// Whether this is a pointer or byval is determined by the AIR tag.
    struct_operand: Inst.Ref,
    field_index: u32,
};

pub const Bin = struct {
    lhs: Inst.Ref,
    rhs: Inst.Ref,
};

pub const FieldParentPtr = struct {
    field_ptr: Inst.Ref,
    field_index: u32,
};

pub const Shuffle = struct {
    a: Inst.Ref,
    b: Inst.Ref,
    mask: InternPool.Index,
    mask_len: u32,
};

pub const VectorCmp = struct {
    lhs: Inst.Ref,
    rhs: Inst.Ref,
    op: u32,

    pub fn compareOperator(self: VectorCmp) std.math.CompareOperator {
        return @as(std.math.CompareOperator, @enumFromInt(@as(u3, @truncate(self.op))));
    }

    pub fn encodeOp(compare_operator: std.math.CompareOperator) u32 {
        return @intFromEnum(compare_operator);
    }
};

/// Trailing:
/// 0. `Inst.Ref` for every outputs_len
/// 1. `Inst.Ref` for every inputs_len
/// 2. for every outputs_len
///    - constraint: memory at this position is reinterpreted as a null
///      terminated string.
///    - name: memory at this position is reinterpreted as a null
///      terminated string. pad to the next u32 after the null byte.
/// 3. for every inputs_len
///    - constraint: memory at this position is reinterpreted as a null
///      terminated string.
///    - name: memory at this position is reinterpreted as a null
///      terminated string. pad to the next u32 after the null byte.
/// 4. for every clobbers_len
///    - clobber_name: memory at this position is reinterpreted as a null
///      terminated string. pad to the next u32 after the null byte.
/// 5. A number of u32 elements follow according to the equation `(source_len + 3) / 4`.
///    Memory starting at this position is reinterpreted as the source bytes.
pub const Asm = struct {
    /// Length of the assembly source in bytes.
    source_len: u32,
    outputs_len: u32,
    inputs_len: u32,
    /// The MSB is `is_volatile`.
    /// The rest of the bits are `clobbers_len`.
    flags: u32,
};

pub const Cmpxchg = struct {
    ptr: Inst.Ref,
    expected_value: Inst.Ref,
    new_value: Inst.Ref,
    /// 0b00000000000000000000000000000XXX - success_order
    /// 0b00000000000000000000000000XXX000 - failure_order
    flags: u32,

    pub fn successOrder(self: Cmpxchg) std.builtin.AtomicOrder {
        return @as(std.builtin.AtomicOrder, @enumFromInt(@as(u3, @truncate(self.flags))));
    }

    pub fn failureOrder(self: Cmpxchg) std.builtin.AtomicOrder {
        return @as(std.builtin.AtomicOrder, @enumFromInt(@as(u3, @truncate(self.flags >> 3))));
    }
};

pub const AtomicRmw = struct {
    operand: Inst.Ref,
    /// 0b00000000000000000000000000000XXX - ordering
    /// 0b0000000000000000000000000XXXX000 - op
    flags: u32,

    pub fn ordering(self: AtomicRmw) std.builtin.AtomicOrder {
        return @as(std.builtin.AtomicOrder, @enumFromInt(@as(u3, @truncate(self.flags))));
    }

    pub fn op(self: AtomicRmw) std.builtin.AtomicRmwOp {
        return @as(std.builtin.AtomicRmwOp, @enumFromInt(@as(u4, @truncate(self.flags >> 3))));
    }
};

pub const UnionInit = struct {
    field_index: u32,
    init: Inst.Ref,
};

pub fn getMainBody(air: Air) []const Air.Inst.Index {
    const body_index = air.extra[@intFromEnum(ExtraIndex.main_block)];
    const extra = air.extraData(Block, body_index);
    return @ptrCast(air.extra[extra.end..][0..extra.data.body_len]);
}

pub fn typeOf(air: *const Air, inst: Air.Inst.Ref, ip: *const InternPool) Type {
    if (inst.toInterned()) |ip_index| {
        return Type.fromInterned(ip.typeOf(ip_index));
    } else {
        return air.typeOfIndex(inst.toIndex().?, ip);
    }
}

pub fn typeOfIndex(air: *const Air, inst: Air.Inst.Index, ip: *const InternPool) Type {
    const datas = air.instructions.items(.data);
    switch (air.instructions.items(.tag)[@intFromEnum(inst)]) {
        .add,
        .add_safe,
        .add_wrap,
        .add_sat,
        .sub,
        .sub_safe,
        .sub_wrap,
        .sub_sat,
        .mul,
        .mul_safe,
        .mul_wrap,
        .mul_sat,
        .div_float,
        .div_trunc,
        .div_floor,
        .div_exact,
        .rem,
        .mod,
        .bit_and,
        .bit_or,
        .xor,
        .shr,
        .shr_exact,
        .shl,
        .shl_exact,
        .shl_sat,
        .min,
        .max,
        .bool_and,
        .bool_or,
        .add_optimized,
        .sub_optimized,
        .mul_optimized,
        .div_float_optimized,
        .div_trunc_optimized,
        .div_floor_optimized,
        .div_exact_optimized,
        .rem_optimized,
        .mod_optimized,
        => return air.typeOf(datas[@intFromEnum(inst)].bin_op.lhs, ip),

        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .floor,
        .ceil,
        .round,
        .trunc_float,
        .neg,
        .neg_optimized,
        => return air.typeOf(datas[@intFromEnum(inst)].un_op, ip),

        .cmp_lt,
        .cmp_lte,
        .cmp_eq,
        .cmp_gte,
        .cmp_gt,
        .cmp_neq,
        .cmp_lt_optimized,
        .cmp_lte_optimized,
        .cmp_eq_optimized,
        .cmp_gte_optimized,
        .cmp_gt_optimized,
        .cmp_neq_optimized,
        .cmp_lt_errors_len,
        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,
        .is_err,
        .is_non_err,
        .is_err_ptr,
        .is_non_err_ptr,
        .is_named_enum_value,
        .error_set_has_value,
        => return Type.bool,

        .alloc,
        .ret_ptr,
        .err_return_trace,
        .c_va_start,
        => return datas[@intFromEnum(inst)].ty,

        .arg => return datas[@intFromEnum(inst)].arg.ty.toType(),

        .assembly,
        .block,
        .dbg_inline_block,
        .struct_field_ptr,
        .struct_field_val,
        .slice_elem_ptr,
        .ptr_elem_ptr,
        .cmpxchg_weak,
        .cmpxchg_strong,
        .slice,
        .shuffle,
        .aggregate_init,
        .union_init,
        .field_parent_ptr,
        .cmp_vector,
        .cmp_vector_optimized,
        .add_with_overflow,
        .sub_with_overflow,
        .mul_with_overflow,
        .shl_with_overflow,
        .ptr_add,
        .ptr_sub,
        .try_ptr,
        => return datas[@intFromEnum(inst)].ty_pl.ty.toType(),

        .not,
        .bitcast,
        .load,
        .fpext,
        .fptrunc,
        .intcast,
        .trunc,
        .optional_payload,
        .optional_payload_ptr,
        .optional_payload_ptr_set,
        .errunion_payload_ptr_set,
        .wrap_optional,
        .unwrap_errunion_payload,
        .unwrap_errunion_err,
        .unwrap_errunion_payload_ptr,
        .unwrap_errunion_err_ptr,
        .wrap_errunion_payload,
        .wrap_errunion_err,
        .slice_ptr,
        .ptr_slice_len_ptr,
        .ptr_slice_ptr_ptr,
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        .array_to_slice,
        .int_from_float,
        .int_from_float_optimized,
        .float_from_int,
        .splat,
        .get_union_tag,
        .clz,
        .ctz,
        .popcount,
        .byte_swap,
        .bit_reverse,
        .addrspace_cast,
        .c_va_arg,
        .c_va_copy,
        .abs,
        => return datas[@intFromEnum(inst)].ty_op.ty.toType(),

        .loop,
        .br,
        .cond_br,
        .switch_br,
        .ret,
        .ret_safe,
        .ret_load,
        .unreach,
        .trap,
        => return Type.noreturn,

        .breakpoint,
        .dbg_stmt,
        .dbg_var_ptr,
        .dbg_var_val,
        .store,
        .store_safe,
        .fence,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .memset,
        .memset_safe,
        .memcpy,
        .set_union_tag,
        .prefetch,
        .set_err_return_trace,
        .vector_store_elem,
        .c_va_end,
        => return Type.void,

        .int_from_ptr,
        .slice_len,
        .ret_addr,
        .frame_addr,
        .save_err_return_trace_index,
        => return Type.usize,

        .wasm_memory_grow => return Type.i32,
        .wasm_memory_size => return Type.u32,

        .int_from_bool => return Type.u1,

        .tag_name, .error_name => return Type.slice_const_u8_sentinel_0,

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const callee_ty = air.typeOf(datas[@intFromEnum(inst)].pl_op.operand, ip);
            return Type.fromInterned(ip.funcTypeReturnType(callee_ty.toIntern()));
        },

        .slice_elem_val, .ptr_elem_val, .array_elem_val => {
            const ptr_ty = air.typeOf(datas[@intFromEnum(inst)].bin_op.lhs, ip);
            return ptr_ty.childTypeIp(ip);
        },
        .atomic_load => {
            const ptr_ty = air.typeOf(datas[@intFromEnum(inst)].atomic_load.ptr, ip);
            return ptr_ty.childTypeIp(ip);
        },
        .atomic_rmw => {
            const ptr_ty = air.typeOf(datas[@intFromEnum(inst)].pl_op.operand, ip);
            return ptr_ty.childTypeIp(ip);
        },

        .reduce, .reduce_optimized => {
            const operand_ty = air.typeOf(datas[@intFromEnum(inst)].reduce.operand, ip);
            return Type.fromInterned(ip.indexToKey(operand_ty.ip_index).vector_type.child);
        },

        .mul_add => return air.typeOf(datas[@intFromEnum(inst)].pl_op.operand, ip),
        .select => {
            const extra = air.extraData(Air.Bin, datas[@intFromEnum(inst)].pl_op.payload).data;
            return air.typeOf(extra.lhs, ip);
        },

        .@"try" => {
            const err_union_ty = air.typeOf(datas[@intFromEnum(inst)].pl_op.operand, ip);
            return Type.fromInterned(ip.indexToKey(err_union_ty.ip_index).error_union_type.payload_type);
        },

        .work_item_id,
        .work_group_size,
        .work_group_id,
        => return Type.u32,

        .inferred_alloc => unreachable,
        .inferred_alloc_comptime => unreachable,
    }
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(air: Air, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => air.extra[i],
            Inst.Ref => @as(Inst.Ref, @enumFromInt(air.extra[i])),
            i32 => @as(i32, @bitCast(air.extra[i])),
            InternPool.Index => @as(InternPool.Index, @enumFromInt(air.extra[i])),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

pub fn deinit(air: *Air, gpa: std.mem.Allocator) void {
    air.instructions.deinit(gpa);
    gpa.free(air.extra);
    air.* = undefined;
}

pub fn internedToRef(ip_index: InternPool.Index) Inst.Ref {
    return switch (ip_index) {
        .var_args_param_type => .var_args_param_type,
        .none => .none,
        else => {
            assert(@intFromEnum(ip_index) >> 31 == 0);
            return @enumFromInt(@as(u31, @intCast(@intFromEnum(ip_index))));
        },
    };
}

/// Returns `null` if runtime-known.
pub fn value(air: Air, inst: Inst.Ref, mod: *Module) !?Value {
    if (inst.toInterned()) |ip_index| {
        return Value.fromInterned(ip_index);
    }
    const index = inst.toIndex().?;
    return air.typeOfIndex(index, &mod.intern_pool).onePossibleValue(mod);
}

pub fn nullTerminatedString(air: Air, index: usize) [:0]const u8 {
    const bytes = std.mem.sliceAsBytes(air.extra[index..]);
    var end: usize = 0;
    while (bytes[end] != 0) {
        end += 1;
    }
    return bytes[0..end :0];
}

/// Returns whether the given instruction must always be lowered, for instance
/// because it can cause side effects. If an instruction does not need to be
/// lowered, and Liveness determines its result is unused, backends should
/// avoid lowering it.
pub fn mustLower(air: Air, inst: Air.Inst.Index, ip: *const InternPool) bool {
    const data = air.instructions.items(.data)[@intFromEnum(inst)];
    return switch (air.instructions.items(.tag)[@intFromEnum(inst)]) {
        .arg,
        .block,
        .loop,
        .br,
        .trap,
        .breakpoint,
        .call,
        .call_always_tail,
        .call_never_tail,
        .call_never_inline,
        .cond_br,
        .switch_br,
        .@"try",
        .try_ptr,
        .dbg_stmt,
        .dbg_inline_block,
        .dbg_var_ptr,
        .dbg_var_val,
        .ret,
        .ret_safe,
        .ret_load,
        .store,
        .store_safe,
        .unreach,
        .optional_payload_ptr_set,
        .errunion_payload_ptr_set,
        .set_union_tag,
        .memset,
        .memset_safe,
        .memcpy,
        .cmpxchg_weak,
        .cmpxchg_strong,
        .fence,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .atomic_rmw,
        .prefetch,
        .wasm_memory_grow,
        .set_err_return_trace,
        .vector_store_elem,
        .c_va_arg,
        .c_va_copy,
        .c_va_end,
        .c_va_start,
        .add_safe,
        .sub_safe,
        .mul_safe,
        => true,

        .add,
        .add_optimized,
        .add_wrap,
        .add_sat,
        .sub,
        .sub_optimized,
        .sub_wrap,
        .sub_sat,
        .mul,
        .mul_optimized,
        .mul_wrap,
        .mul_sat,
        .div_float,
        .div_float_optimized,
        .div_trunc,
        .div_trunc_optimized,
        .div_floor,
        .div_floor_optimized,
        .div_exact,
        .div_exact_optimized,
        .rem,
        .rem_optimized,
        .mod,
        .mod_optimized,
        .ptr_add,
        .ptr_sub,
        .max,
        .min,
        .add_with_overflow,
        .sub_with_overflow,
        .mul_with_overflow,
        .shl_with_overflow,
        .alloc,
        .inferred_alloc,
        .inferred_alloc_comptime,
        .ret_ptr,
        .bit_and,
        .bit_or,
        .shr,
        .shr_exact,
        .shl,
        .shl_exact,
        .shl_sat,
        .xor,
        .not,
        .bitcast,
        .ret_addr,
        .frame_addr,
        .clz,
        .ctz,
        .popcount,
        .byte_swap,
        .bit_reverse,
        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .abs,
        .floor,
        .ceil,
        .round,
        .trunc_float,
        .neg,
        .neg_optimized,
        .cmp_lt,
        .cmp_lt_optimized,
        .cmp_lte,
        .cmp_lte_optimized,
        .cmp_eq,
        .cmp_eq_optimized,
        .cmp_gte,
        .cmp_gte_optimized,
        .cmp_gt,
        .cmp_gt_optimized,
        .cmp_neq,
        .cmp_neq_optimized,
        .cmp_vector,
        .cmp_vector_optimized,
        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,
        .is_err,
        .is_non_err,
        .is_err_ptr,
        .is_non_err_ptr,
        .bool_and,
        .bool_or,
        .int_from_ptr,
        .int_from_bool,
        .fptrunc,
        .fpext,
        .intcast,
        .trunc,
        .optional_payload,
        .optional_payload_ptr,
        .wrap_optional,
        .unwrap_errunion_payload,
        .unwrap_errunion_err,
        .unwrap_errunion_payload_ptr,
        .unwrap_errunion_err_ptr,
        .wrap_errunion_payload,
        .wrap_errunion_err,
        .struct_field_ptr,
        .struct_field_ptr_index_0,
        .struct_field_ptr_index_1,
        .struct_field_ptr_index_2,
        .struct_field_ptr_index_3,
        .struct_field_val,
        .get_union_tag,
        .slice,
        .slice_len,
        .slice_ptr,
        .ptr_slice_len_ptr,
        .ptr_slice_ptr_ptr,
        .array_elem_val,
        .slice_elem_ptr,
        .ptr_elem_ptr,
        .array_to_slice,
        .int_from_float,
        .int_from_float_optimized,
        .float_from_int,
        .reduce,
        .reduce_optimized,
        .splat,
        .shuffle,
        .select,
        .is_named_enum_value,
        .tag_name,
        .error_name,
        .error_set_has_value,
        .aggregate_init,
        .union_init,
        .mul_add,
        .field_parent_ptr,
        .wasm_memory_size,
        .cmp_lt_errors_len,
        .err_return_trace,
        .addrspace_cast,
        .save_err_return_trace_index,
        .work_item_id,
        .work_group_size,
        .work_group_id,
        => false,

        .assembly => {
            const extra = air.extraData(Air.Asm, data.ty_pl.payload);
            const is_volatile = @as(u1, @truncate(extra.data.flags >> 31)) != 0;
            return is_volatile or if (extra.data.outputs_len == 1)
                @as(Air.Inst.Ref, @enumFromInt(air.extra[extra.end])) != .none
            else
                extra.data.outputs_len > 1;
        },
        .load => air.typeOf(data.ty_op.operand, ip).isVolatilePtrIp(ip),
        .slice_elem_val, .ptr_elem_val => air.typeOf(data.bin_op.lhs, ip).isVolatilePtrIp(ip),
        .atomic_load => air.typeOf(data.atomic_load.ptr, ip).isVolatilePtrIp(ip),
    };
}
