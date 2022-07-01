//! Analyzed Intermediate Representation.
//! This data is produced by Sema and consumed by codegen.
//! Unlike ZIR where there is one instance for an entire source file, each function
//! gets its own `Air` instance.

const std = @import("std");
const builtin = @import("builtin");
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;
const Air = @This();

instructions: std.MultiArrayList(Inst).Slice,
/// The meaning of this data is determined by `Inst.Tag` value.
/// The first few indexes are reserved. See `ExtraIndex` for the values.
extra: []const u32,
values: []const Value,

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
        /// Uses the `ty` field.
        arg,
        /// Float or integer addition. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        add,
        /// Integer addition. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        addwrap,
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
        /// Integer subtraction. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        subwrap,
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
        /// Integer multiplication. Wrapping is defined to be twos complement wrapping.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mulwrap,
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
        /// Truncating integer or float division. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_trunc,
        /// Flooring integer or float division. For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_floor,
        /// Integer or float division. Guaranteed no remainder.
        /// For integers, wrapping is undefined behavior.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        div_exact,
        /// Integer or float remainder division.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        rem,
        /// Integer or float modulus division.
        /// Both operands are guaranteed to be the same type, and the result type
        /// is the same as both operands.
        /// Uses the `bin_op` field.
        mod,
        /// Add an offset to a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
        /// Uses the `ty_pl` field. Payload is `Bin`.
        ptr_add,
        /// Subtract an offset from a pointer, returning a new pointer.
        /// The offset is in element type units, not bytes.
        /// Wrapping is undefined behavior.
        /// The lhs is the pointer, rhs is the offset. Result type is the same as lhs.
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
        /// Uses the `ty_pl` field with payload `Block`.
        block,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `ty_pl` field. Payload is `Block`.
        loop,
        /// Return from a block with a result.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `br` field.
        br,
        /// Lowers to a hardware trap instruction, or the next best thing.
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
        /// Aboslute value of a floating point number.
        /// Uses the `un_op` field.
        fabs,
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

        /// `<`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lt,
        /// `<=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_lte,
        /// `==`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_eq,
        /// `>=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gte,
        /// `>`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_gt,
        /// `!=`. Result type is always bool.
        /// Uses the `bin_op` field.
        cmp_neq,
        /// Conditional between two vectors.
        /// Result type is always a vector of bools.
        /// Uses the `ty_pl` field, payload is `VectorCmp`.
        cmp_vector,

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
        /// A comptime-known value. Uses the `ty_pl` field, payload is index of
        /// `values` array.
        constant,
        /// A comptime-known type. Uses the `ty` field.
        const_ty,
        /// Notes the beginning of a source code statement and marks the line and column.
        /// Result type is always void.
        /// Uses the `dbg_stmt` field.
        dbg_stmt,
        /// Marks the beginning of a semantic scope for debug info variables.
        dbg_block_begin,
        /// Marks the end of a semantic scope for debug info variables.
        dbg_block_end,
        /// Marks the start of an inline call.
        /// Uses `ty_pl` with the payload being the index of a Value.Function in air.values.
        dbg_inline_begin,
        /// Marks the end of an inline call.
        /// Uses `ty_pl` with the payload being the index of a Value.Function in air.values.
        dbg_inline_end,
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
        /// Uses the `un_op` field.
        ptrtoint,
        /// Given a boolean, returns 0 or 1.
        /// Result type is always `u1`.
        /// Uses the `un_op` field.
        bool_to_int,
        /// Return a value from a function.
        /// Result type is always noreturn; no instructions in a block follow this one.
        /// Uses the `un_op` field.
        /// Triggers `resolveTypeLayout` on the return type.
        ret,
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
        store,
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
        float_to_int,
        /// Given an integer operand, return the float with the closest mathematical meaning.
        /// Uses the `ty_op` field.
        int_to_float,

        /// Transforms a vector into a scalar value by performing a sequential
        /// horizontal reduction of its elements using the specified operator.
        /// The vector element type (and hence result type) will be:
        ///  * and, or, xor       => integer or boolean
        ///  * min, max, add, mul => integer or float
        /// Uses the `reduce` field.
        reduce,
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

        /// Given dest ptr, value, and len, set all elements at dest to value.
        /// Result type is always void.
        /// Uses the `pl_op` field. Operand is the dest ptr. Payload is `Bin`. `lhs` is the
        /// value, `rhs` is the length.
        /// The element type may be any type, not just u8.
        memset,
        /// Given dest ptr, src ptr, and len, copy len elements from src to dest.
        /// Result type is always void.
        /// Uses the `pl_op` field. Operand is the dest ptr. Payload is `Bin`. `lhs` is the
        /// src ptr, `rhs` is the length.
        /// The element type may be any type, not just u8.
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
        /// Same as `atomic_store_unordered` but with `AtomicOrder.Monotonic`.
        atomic_store_monotonic,
        /// Same as `atomic_store_unordered` but with `AtomicOrder.Release`.
        atomic_store_release,
        /// Same as `atomic_store_unordered` but with `AtomicOrder.SeqCst`.
        atomic_store_seq_cst,
        /// Atomically read-modify-write via a pointer.
        /// Result type is the element type of the pointer.
        /// Uses the `pl_op` field with payload `AtomicRmw`. Operand is `ptr`.
        atomic_rmw,

        /// Given an enum tag value, returns the tag name. The enum type may be non-exhaustive.
        /// Result type is always `[:0]const u8`.
        /// Uses the `un_op` field.
        tag_name,

        /// Given an error value, return the error name. Result type is always `[:0] const u8`.
        /// Uses the `un_op` field.
        error_name,

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

        pub fn fromCmpOp(op: std.math.CompareOperator) Tag {
            return switch (op) {
                .lt => .cmp_lt,
                .lte => .cmp_lte,
                .eq => .cmp_eq,
                .gte => .cmp_gte,
                .gt => .cmp_gt,
                .neq => .cmp_neq,
            };
        }

        pub fn toCmpOp(tag: Tag) ?std.math.CompareOperator {
            return switch (tag) {
                .cmp_lt => .lt,
                .cmp_lte => .lte,
                .cmp_eq => .eq,
                .cmp_gte => .gte,
                .cmp_gt => .gt,
                .cmp_neq => .neq,
                else => null,
            };
        }
    };

    /// The position of an AIR instruction within the `Air` instructions array.
    pub const Index = u32;

    pub const Ref = @import("Zir.zig").Inst.Ref;

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

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (builtin.mode != .Debug) {
                assert(@sizeOf(Data) == 8);
            }
        }
    };
};

/// Trailing is a list of instruction indexes for every `body_len`.
pub const Block = struct {
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
    // index to air_values
    mask: u32,
    mask_len: u32,
};

pub const VectorCmp = struct {
    lhs: Inst.Ref,
    rhs: Inst.Ref,
    op: u32,

    pub fn compareOperator(self: VectorCmp) std.math.CompareOperator {
        return @intToEnum(std.math.CompareOperator, @truncate(u3, self.op));
    }

    pub fn encodeOp(compare_operator: std.math.CompareOperator) u32 {
        return @enumToInt(compare_operator);
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
        return @intToEnum(std.builtin.AtomicOrder, @truncate(u3, self.flags));
    }

    pub fn failureOrder(self: Cmpxchg) std.builtin.AtomicOrder {
        return @intToEnum(std.builtin.AtomicOrder, @truncate(u3, self.flags >> 3));
    }
};

pub const AtomicRmw = struct {
    operand: Inst.Ref,
    /// 0b00000000000000000000000000000XXX - ordering
    /// 0b0000000000000000000000000XXXX000 - op
    flags: u32,

    pub fn ordering(self: AtomicRmw) std.builtin.AtomicOrder {
        return @intToEnum(std.builtin.AtomicOrder, @truncate(u3, self.flags));
    }

    pub fn op(self: AtomicRmw) std.builtin.AtomicRmwOp {
        return @intToEnum(std.builtin.AtomicRmwOp, @truncate(u4, self.flags >> 3));
    }
};

pub const UnionInit = struct {
    field_index: u32,
    init: Inst.Ref,
};

pub fn getMainBody(air: Air) []const Air.Inst.Index {
    const body_index = air.extra[@enumToInt(ExtraIndex.main_block)];
    const extra = air.extraData(Block, body_index);
    return air.extra[extra.end..][0..extra.data.body_len];
}

pub fn typeOf(air: Air, inst: Air.Inst.Ref) Type {
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        return Air.Inst.Ref.typed_value_map[ref_int].ty;
    }
    return air.typeOfIndex(@intCast(Air.Inst.Index, ref_int - Air.Inst.Ref.typed_value_map.len));
}

pub fn typeOfIndex(air: Air, inst: Air.Inst.Index) Type {
    const datas = air.instructions.items(.data);
    switch (air.instructions.items(.tag)[inst]) {
        .add,
        .addwrap,
        .add_sat,
        .sub,
        .subwrap,
        .sub_sat,
        .mul,
        .mulwrap,
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
        => return air.typeOf(datas[inst].bin_op.lhs),

        .sqrt,
        .sin,
        .cos,
        .tan,
        .exp,
        .exp2,
        .log,
        .log2,
        .log10,
        .fabs,
        .floor,
        .ceil,
        .round,
        .trunc_float,
        .neg,
        => return air.typeOf(datas[inst].un_op),

        .cmp_lt,
        .cmp_lte,
        .cmp_eq,
        .cmp_gte,
        .cmp_gt,
        .cmp_neq,
        .cmp_lt_errors_len,
        .is_null,
        .is_non_null,
        .is_null_ptr,
        .is_non_null_ptr,
        .is_err,
        .is_non_err,
        .is_err_ptr,
        .is_non_err_ptr,
        => return Type.bool,

        .const_ty => return Type.type,

        .alloc,
        .ret_ptr,
        .arg,
        .err_return_trace,
        => return datas[inst].ty,

        .assembly,
        .block,
        .constant,
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
        .add_with_overflow,
        .sub_with_overflow,
        .mul_with_overflow,
        .shl_with_overflow,
        .ptr_add,
        .ptr_sub,
        .try_ptr,
        => return air.getRefType(datas[inst].ty_pl.ty),

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
        .float_to_int,
        .int_to_float,
        .splat,
        .get_union_tag,
        .clz,
        .ctz,
        .popcount,
        .byte_swap,
        .bit_reverse,
        => return air.getRefType(datas[inst].ty_op.ty),

        .loop,
        .br,
        .cond_br,
        .switch_br,
        .ret,
        .ret_load,
        .unreach,
        => return Type.initTag(.noreturn),

        .breakpoint,
        .dbg_stmt,
        .dbg_inline_begin,
        .dbg_inline_end,
        .dbg_block_begin,
        .dbg_block_end,
        .dbg_var_ptr,
        .dbg_var_val,
        .store,
        .fence,
        .atomic_store_unordered,
        .atomic_store_monotonic,
        .atomic_store_release,
        .atomic_store_seq_cst,
        .memset,
        .memcpy,
        .set_union_tag,
        .prefetch,
        .set_err_return_trace,
        => return Type.void,

        .ptrtoint,
        .slice_len,
        .ret_addr,
        .frame_addr,
        => return Type.usize,

        .wasm_memory_grow => return Type.i32,
        .wasm_memory_size => return Type.u32,

        .bool_to_int => return Type.initTag(.u1),

        .tag_name, .error_name => return Type.initTag(.const_slice_u8_sentinel_0),

        .call, .call_always_tail, .call_never_tail, .call_never_inline => {
            const callee_ty = air.typeOf(datas[inst].pl_op.operand);
            switch (callee_ty.zigTypeTag()) {
                .Fn => return callee_ty.fnReturnType(),
                .Pointer => return callee_ty.childType().fnReturnType(),
                else => unreachable,
            }
        },

        .slice_elem_val, .ptr_elem_val, .array_elem_val => {
            const ptr_ty = air.typeOf(datas[inst].bin_op.lhs);
            return ptr_ty.elemType();
        },
        .atomic_load => {
            const ptr_ty = air.typeOf(datas[inst].atomic_load.ptr);
            return ptr_ty.elemType();
        },
        .atomic_rmw => {
            const ptr_ty = air.typeOf(datas[inst].pl_op.operand);
            return ptr_ty.elemType();
        },

        .reduce => return air.typeOf(datas[inst].reduce.operand).childType(),

        .mul_add => return air.typeOf(datas[inst].pl_op.operand),
        .select => {
            const extra = air.extraData(Air.Bin, datas[inst].pl_op.payload).data;
            return air.typeOf(extra.lhs);
        },

        .@"try" => {
            const err_union_ty = air.typeOf(datas[inst].pl_op.operand);
            return err_union_ty.errorUnionPayload();
        },
    }
}

pub fn getRefType(air: Air, ref: Air.Inst.Ref) Type {
    const ref_int = @enumToInt(ref);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        var buffer: Value.ToTypeBuffer = undefined;
        return Air.Inst.Ref.typed_value_map[ref_int].val.toType(&buffer);
    }
    const inst_index = ref_int - Air.Inst.Ref.typed_value_map.len;
    const air_tags = air.instructions.items(.tag);
    const air_datas = air.instructions.items(.data);
    assert(air_tags[inst_index] == .const_ty);
    return air_datas[inst_index].ty;
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(air: Air, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = std.meta.fields(T);
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
            u32 => air.extra[i],
            Inst.Ref => @intToEnum(Inst.Ref, air.extra[i]),
            i32 => @bitCast(i32, air.extra[i]),
            else => @compileError("bad field type"),
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
    gpa.free(air.values);
    air.* = undefined;
}

const ref_start_index: u32 = Air.Inst.Ref.typed_value_map.len;

pub fn indexToRef(inst: Air.Inst.Index) Air.Inst.Ref {
    return @intToEnum(Air.Inst.Ref, ref_start_index + inst);
}

pub fn refToIndex(inst: Air.Inst.Ref) ?Air.Inst.Index {
    const ref_int = @enumToInt(inst);
    if (ref_int >= ref_start_index) {
        return ref_int - ref_start_index;
    } else {
        return null;
    }
}

/// Returns `null` if runtime-known.
pub fn value(air: Air, inst: Air.Inst.Ref) ?Value {
    const ref_int = @enumToInt(inst);
    if (ref_int < Air.Inst.Ref.typed_value_map.len) {
        return Air.Inst.Ref.typed_value_map[ref_int].val;
    }
    const inst_index = @intCast(Air.Inst.Index, ref_int - Air.Inst.Ref.typed_value_map.len);
    const air_datas = air.instructions.items(.data);
    switch (air.instructions.items(.tag)[inst_index]) {
        .constant => return air.values[air_datas[inst_index].ty_pl.payload],
        .const_ty => unreachable,
        else => return air.typeOfIndex(inst_index).onePossibleValue(),
    }
}

pub fn nullTerminatedString(air: Air, index: usize) [:0]const u8 {
    const bytes = std.mem.sliceAsBytes(air.extra[index..]);
    var end: usize = 0;
    while (bytes[end] != 0) {
        end += 1;
    }
    return bytes[0..end :0];
}
