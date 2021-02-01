//! This file has to do with parsing and rendering the ZIR text format.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const ir = @import("ir.zig");
const IrModule = @import("Module.zig");

/// These are instructions that correspond to the ZIR text format. See `ir.Inst` for
/// in-memory, analyzed instructions with types and values.
/// We use a table to map these instruction to their respective semantically analyzed
/// instructions because it is possible to have multiple analyses on the same ZIR
/// happening at the same time.
pub const Inst = struct {
    tag: Tag,
    /// Byte offset into the source.
    src: usize,

    /// These names are used directly as the instruction names in the text format.
    pub const Tag = enum {
        /// Arithmetic addition, asserts no integer overflow.
        add,
        /// Twos complement wrapping integer addition.
        addwrap,
        /// Allocates stack local memory. Its lifetime ends when the block ends that contains
        /// this instruction. The operand is the type of the allocated object.
        alloc,
        /// Same as `alloc` except mutable.
        alloc_mut,
        /// Same as `alloc` except the type is inferred.
        alloc_inferred,
        /// Same as `alloc_inferred` except mutable.
        alloc_inferred_mut,
        /// Create an `anyframe->T`.
        anyframe_type,
        /// Array concatenation. `a ++ b`
        array_cat,
        /// Array multiplication `a ** b`
        array_mul,
        /// Create an array type
        array_type,
        /// Create an array type with sentinel
        array_type_sentinel,
        /// Given a pointer to an indexable object, returns the len property. This is
        /// used by for loops. This instruction also emits a for-loop specific instruction
        /// if the indexable object is not indexable.
        indexable_ptr_len,
        /// Function parameter value. These must be first in a function's main block,
        /// in respective order with the parameters.
        arg,
        /// Type coercion.
        as,
        /// Inline assembly.
        @"asm",
        /// Bitwise AND. `&`
        bit_and,
        /// TODO delete this instruction, it has no purpose.
        bitcast,
        /// An arbitrary typed pointer is pointer-casted to a new Pointer.
        /// The destination type is given by LHS. The cast is to be evaluated
        /// as if it were a bit-cast operation from the operand pointer element type to the
        /// provided destination type.
        bitcast_ref,
        /// A typed result location pointer is bitcasted to a new result location pointer.
        /// The new result location pointer has an inferred type.
        bitcast_result_ptr,
        /// Bitwise NOT. `~`
        bit_not,
        /// Bitwise OR. `|`
        bit_or,
        /// A labeled block of code, which can return a value.
        block,
        /// A block of code, which can return a value. There are no instructions that break out of
        /// this block; it is implied that the final instruction is the result.
        block_flat,
        /// Same as `block` but additionally makes the inner instructions execute at comptime.
        block_comptime,
        /// Same as `block_flat` but additionally makes the inner instructions execute at comptime.
        block_comptime_flat,
        /// Boolean AND. See also `bit_and`.
        bool_and,
        /// Boolean NOT. See also `bit_not`.
        bool_not,
        /// Boolean OR. See also `bit_or`.
        bool_or,
        /// Return a value from a `Block`.
        @"break",
        breakpoint,
        /// Same as `break` but without an operand; the operand is assumed to be the void value.
        break_void,
        /// Function call.
        call,
        /// `<`
        cmp_lt,
        /// `<=`
        cmp_lte,
        /// `==`
        cmp_eq,
        /// `>=`
        cmp_gte,
        /// `>`
        cmp_gt,
        /// `!=`
        cmp_neq,
        /// Coerces a result location pointer to a new element type. It is evaluated "backwards"-
        /// as type coercion from the new element type to the old element type.
        /// LHS is destination element type, RHS is result pointer.
        coerce_result_ptr,
        /// Emit an error message and fail compilation.
        compile_error,
        /// Log compile time variables and emit an error message.
        compile_log,
        /// Conditional branch. Splits control flow based on a boolean condition value.
        condbr,
        /// Special case, has no textual representation.
        @"const",
        /// Container field with just the name.
        container_field_named,
        /// Container field with a type and a name,
        container_field_typed,
        /// Container field with all the bells and whistles.
        container_field,
        /// Declares the beginning of a statement. Used for debug info.
        dbg_stmt,
        /// Represents a pointer to a global decl.
        decl_ref,
        /// Represents a pointer to a global decl by string name.
        decl_ref_str,
        /// Equivalent to a decl_ref followed by deref.
        decl_val,
        /// Load the value from a pointer.
        deref,
        /// Arithmetic division. Asserts no integer overflow.
        div,
        /// Given a pointer to an array, slice, or pointer, returns a pointer to the element at
        /// the provided index.
        elem_ptr,
        /// Given an array, slice, or pointer, returns the element at the provided index.
        elem_val,
        /// Emits a compile error if the operand is not `void`.
        ensure_result_used,
        /// Emits a compile error if an error is ignored.
        ensure_result_non_error,
        /// Create a `E!T` type.
        error_union_type,
        /// Create an error set.
        error_set,
        /// Export the provided Decl as the provided name in the compilation's output object file.
        @"export",
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field. The field name is a []const u8. Used by a.b syntax.
        field_ptr,
        /// Given a struct or object that contains virtual fields, returns the named field.
        /// The field name is a []const u8. Used by a.b syntax.
        field_val,
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field. The field name is a comptime instruction. Used by @field.
        field_ptr_named,
        /// Given a struct or object that contains virtual fields, returns the named field.
        /// The field name is a comptime instruction. Used by @field.
        field_val_named,
        /// Convert a larger float type to any other float type, possibly causing a loss of precision.
        floatcast,
        /// Declare a function body.
        @"fn",
        /// Returns a function type.
        fntype,
        /// @import(operand)
        import,
        /// Integer literal.
        int,
        /// Convert an integer value to another integer type, asserting that the destination type
        /// can hold the same mathematical value.
        intcast,
        /// Make an integer type out of signedness and bit count.
        int_type,
        /// Return a boolean false if an optional is null. `x != null`
        is_non_null,
        /// Return a boolean true if an optional is null. `x == null`
        is_null,
        /// Return a boolean false if an optional is null. `x.* != null`
        is_non_null_ptr,
        /// Return a boolean true if an optional is null. `x.* == null`
        is_null_ptr,
        /// Return a boolean true if value is an error
        is_err,
        /// Return a boolean true if dereferenced pointer is an error
        is_err_ptr,
        /// A labeled block of code that loops forever. At the end of the body it is implied
        /// to repeat; no explicit "repeat" instruction terminates loop bodies.
        loop,
        /// Merge two error sets into one, `E1 || E2`.
        merge_error_sets,
        /// Ambiguously remainder division or modulus. If the computation would possibly have
        /// a different value depending on whether the operation is remainder division or modulus,
        /// a compile error is emitted. Otherwise the computation is performed.
        mod_rem,
        /// Arithmetic multiplication. Asserts no integer overflow.
        mul,
        /// Twos complement wrapping integer multiplication.
        mulwrap,
        /// Given a reference to a function and a parameter index, returns the
        /// type of the parameter. TODO what happens when the parameter is `anytype`?
        param_type,
        /// An alternative to using `const` for simple primitive values such as `true` or `u8`.
        /// TODO flatten so that each primitive has its own ZIR Inst Tag.
        primitive,
        /// Convert a pointer to a `usize` integer.
        ptrtoint,
        /// Turns an R-Value into a const L-Value. In other words, it takes a value,
        /// stores it in a memory location, and returns a const pointer to it. If the value
        /// is `comptime`, the memory location is global static constant data. Otherwise,
        /// the memory location is in the stack frame, local to the scope containing the
        /// instruction.
        ref,
        /// Obtains a pointer to the return value.
        ret_ptr,
        /// Obtains the return type of the in-scope function.
        ret_type,
        /// Sends control flow back to the function's callee. Takes an operand as the return value.
        @"return",
        /// Same as `return` but there is no operand; the operand is implicitly the void value.
        return_void,
        /// Changes the maximum number of backwards branches that compile-time
        /// code execution can use before giving up and making a compile error.
        set_eval_branch_quota,
        /// Integer shift-left. Zeroes are shifted in from the right hand side.
        shl,
        /// Integer shift-right. Arithmetic or logical depending on the signedness of the integer type.
        shr,
        /// Create a const pointer type with element type T. `*const T`
        single_const_ptr_type,
        /// Create a mutable pointer type with element type T. `*T`
        single_mut_ptr_type,
        /// Create a const pointer type with element type T. `[*]const T`
        many_const_ptr_type,
        /// Create a mutable pointer type with element type T. `[*]T`
        many_mut_ptr_type,
        /// Create a const pointer type with element type T. `[*c]const T`
        c_const_ptr_type,
        /// Create a mutable pointer type with element type T. `[*c]T`
        c_mut_ptr_type,
        /// Create a mutable slice type with element type T. `[]T`
        mut_slice_type,
        /// Create a const slice type with element type T. `[]T`
        const_slice_type,
        /// Create a pointer type with attributes
        ptr_type,
        /// Each `store_to_inferred_ptr` puts the type of the stored value into a set,
        /// and then `resolve_inferred_alloc` triggers peer type resolution on the set.
        /// The operand is a `alloc_inferred` or `alloc_inferred_mut` instruction, which
        /// is the allocation that needs to have its type inferred.
        resolve_inferred_alloc,
        /// Slice operation `array_ptr[start..end:sentinel]`
        slice,
        /// Slice operation with just start `lhs[rhs..]`
        slice_start,
        /// Write a value to a pointer. For loading, see `deref`.
        store,
        /// Same as `store` but the type of the value being stored will be used to infer
        /// the block type. The LHS is the pointer to store to.
        store_to_block_ptr,
        /// Same as `store` but the type of the value being stored will be used to infer
        /// the pointer type.
        store_to_inferred_ptr,
        /// String Literal. Makes an anonymous Decl and then takes a pointer to it.
        str,
        /// Create a struct type.
        struct_type,
        /// Arithmetic subtraction. Asserts no integer overflow.
        sub,
        /// Twos complement wrapping integer subtraction.
        subwrap,
        /// Returns the type of a value.
        typeof,
        /// Is the builtin @TypeOf which returns the type after peertype resolution of one or more params
        typeof_peer,
        /// Asserts control-flow will not reach this instruction. Not safety checked - the compiler
        /// will assume the correctness of this instruction.
        unreachable_unsafe,
        /// Asserts control-flow will not reach this instruction. In safety-checked modes,
        /// this will generate a call to the panic function unless it can be proven unreachable
        /// by the compiler.
        unreachable_safe,
        /// Bitwise XOR. `^`
        xor,
        /// Create an optional type '?T'
        optional_type,
        /// Create a union type.
        union_type,
        /// ?T => T with safety.
        /// Given an optional value, returns the payload value, with a safety check that
        /// the value is non-null. Used for `orelse`, `if` and `while`.
        optional_payload_safe,
        /// ?T => T without safety.
        /// Given an optional value, returns the payload value. No safety checks.
        optional_payload_unsafe,
        /// *?T => *T with safety.
        /// Given a pointer to an optional value, returns a pointer to the payload value,
        /// with a safety check that the value is non-null. Used for `orelse`, `if` and `while`.
        optional_payload_safe_ptr,
        /// *?T => *T without safety.
        /// Given a pointer to an optional value, returns a pointer to the payload value.
        /// No safety checks.
        optional_payload_unsafe_ptr,
        /// E!T => T with safety.
        /// Given an error union value, returns the payload value, with a safety check
        /// that the value is not an error. Used for catch, if, and while.
        err_union_payload_safe,
        /// E!T => T without safety.
        /// Given an error union value, returns the payload value. No safety checks.
        err_union_payload_unsafe,
        /// *E!T => *T with safety.
        /// Given a pointer to an error union value, returns a pointer to the payload value,
        /// with a safety check that the value is not an error. Used for catch, if, and while.
        err_union_payload_safe_ptr,
        /// *E!T => *T without safety.
        /// Given a pointer to a error union value, returns a pointer to the payload value.
        /// No safety checks.
        err_union_payload_unsafe_ptr,
        /// E!T => E without safety.
        /// Given an error union value, returns the error code. No safety checks.
        err_union_code,
        /// *E!T => E without safety.
        /// Given a pointer to an error union value, returns the error code. No safety checks.
        err_union_code_ptr,
        /// Takes a *E!T and raises a compiler error if T != void
        ensure_err_payload_void,
        /// Create a enum literal,
        enum_literal,
        /// Create an enum type.
        enum_type,
        /// Does nothing; returns a void value.
        void_value,
        /// A switch expression.
        switchbr,
        /// A range in a switch case, `lhs...rhs`.
        /// Only checks that `lhs >= rhs` if they are ints, everything else is
        /// validated by the .switch instruction.
        switch_range,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .alloc_inferred,
                .alloc_inferred_mut,
                .breakpoint,
                .dbg_stmt,
                .return_void,
                .ret_ptr,
                .ret_type,
                .unreachable_unsafe,
                .unreachable_safe,
                .void_value,
                => NoOp,

                .alloc,
                .alloc_mut,
                .bool_not,
                .compile_error,
                .deref,
                .@"return",
                .is_null,
                .is_non_null,
                .is_null_ptr,
                .is_non_null_ptr,
                .is_err,
                .is_err_ptr,
                .ptrtoint,
                .ensure_result_used,
                .ensure_result_non_error,
                .bitcast_result_ptr,
                .ref,
                .bitcast_ref,
                .typeof,
                .resolve_inferred_alloc,
                .single_const_ptr_type,
                .single_mut_ptr_type,
                .many_const_ptr_type,
                .many_mut_ptr_type,
                .c_const_ptr_type,
                .c_mut_ptr_type,
                .mut_slice_type,
                .const_slice_type,
                .optional_type,
                .optional_payload_safe,
                .optional_payload_unsafe,
                .optional_payload_safe_ptr,
                .optional_payload_unsafe_ptr,
                .err_union_payload_safe,
                .err_union_payload_unsafe,
                .err_union_payload_safe_ptr,
                .err_union_payload_unsafe_ptr,
                .err_union_code,
                .err_union_code_ptr,
                .ensure_err_payload_void,
                .anyframe_type,
                .bit_not,
                .import,
                .set_eval_branch_quota,
                .indexable_ptr_len,
                => UnOp,

                .add,
                .addwrap,
                .array_cat,
                .array_mul,
                .array_type,
                .bit_and,
                .bit_or,
                .bool_and,
                .bool_or,
                .div,
                .mod_rem,
                .mul,
                .mulwrap,
                .shl,
                .shr,
                .store,
                .store_to_block_ptr,
                .store_to_inferred_ptr,
                .sub,
                .subwrap,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .as,
                .floatcast,
                .intcast,
                .bitcast,
                .coerce_result_ptr,
                .xor,
                .error_union_type,
                .merge_error_sets,
                .slice_start,
                .switch_range,
                => BinOp,

                .block,
                .block_flat,
                .block_comptime,
                .block_comptime_flat,
                => Block,

                .arg => Arg,
                .array_type_sentinel => ArrayTypeSentinel,
                .@"break" => Break,
                .break_void => BreakVoid,
                .call => Call,
                .decl_ref => DeclRef,
                .decl_ref_str => DeclRefStr,
                .decl_val => DeclVal,
                .compile_log => CompileLog,
                .loop => Loop,
                .@"const" => Const,
                .str => Str,
                .int => Int,
                .int_type => IntType,
                .field_ptr, .field_val => Field,
                .field_ptr_named, .field_val_named => FieldNamed,
                .@"asm" => Asm,
                .@"fn" => Fn,
                .@"export" => Export,
                .param_type => ParamType,
                .primitive => Primitive,
                .fntype => FnType,
                .elem_ptr, .elem_val => Elem,
                .condbr => CondBr,
                .ptr_type => PtrType,
                .enum_literal => EnumLiteral,
                .error_set => ErrorSet,
                .slice => Slice,
                .typeof_peer => TypeOfPeer,
                .container_field_named => ContainerFieldNamed,
                .container_field_typed => ContainerFieldTyped,
                .container_field => ContainerField,
                .enum_type => EnumType,
                .union_type => UnionType,
                .struct_type => StructType,
                .switchbr => SwitchBr,
            };
        }

        /// Returns whether the instruction is one of the control flow "noreturn" types.
        /// Function calls do not count.
        pub fn isNoReturn(tag: Tag) bool {
            return switch (tag) {
                .add,
                .addwrap,
                .alloc,
                .alloc_mut,
                .alloc_inferred,
                .alloc_inferred_mut,
                .array_cat,
                .array_mul,
                .array_type,
                .array_type_sentinel,
                .indexable_ptr_len,
                .arg,
                .as,
                .@"asm",
                .bit_and,
                .bitcast,
                .bitcast_ref,
                .bitcast_result_ptr,
                .bit_or,
                .block,
                .block_flat,
                .block_comptime,
                .block_comptime_flat,
                .bool_not,
                .bool_and,
                .bool_or,
                .breakpoint,
                .call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .coerce_result_ptr,
                .@"const",
                .dbg_stmt,
                .decl_ref,
                .decl_ref_str,
                .decl_val,
                .deref,
                .div,
                .elem_ptr,
                .elem_val,
                .ensure_result_used,
                .ensure_result_non_error,
                .@"export",
                .floatcast,
                .field_ptr,
                .field_val,
                .field_ptr_named,
                .field_val_named,
                .@"fn",
                .fntype,
                .int,
                .intcast,
                .int_type,
                .is_non_null,
                .is_null,
                .is_non_null_ptr,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .mod_rem,
                .mul,
                .mulwrap,
                .param_type,
                .primitive,
                .ptrtoint,
                .ref,
                .ret_ptr,
                .ret_type,
                .shl,
                .shr,
                .single_const_ptr_type,
                .single_mut_ptr_type,
                .many_const_ptr_type,
                .many_mut_ptr_type,
                .c_const_ptr_type,
                .c_mut_ptr_type,
                .mut_slice_type,
                .const_slice_type,
                .store,
                .store_to_block_ptr,
                .store_to_inferred_ptr,
                .str,
                .sub,
                .subwrap,
                .typeof,
                .xor,
                .optional_type,
                .optional_payload_safe,
                .optional_payload_unsafe,
                .optional_payload_safe_ptr,
                .optional_payload_unsafe_ptr,
                .err_union_payload_safe,
                .err_union_payload_unsafe,
                .err_union_payload_safe_ptr,
                .err_union_payload_unsafe_ptr,
                .err_union_code,
                .err_union_code_ptr,
                .ptr_type,
                .ensure_err_payload_void,
                .enum_literal,
                .merge_error_sets,
                .anyframe_type,
                .error_union_type,
                .bit_not,
                .error_set,
                .slice,
                .slice_start,
                .import,
                .typeof_peer,
                .resolve_inferred_alloc,
                .set_eval_branch_quota,
                .compile_log,
                .enum_type,
                .union_type,
                .struct_type,
                .void_value,
                .switch_range,
                .switchbr,
                => false,

                .@"break",
                .break_void,
                .condbr,
                .compile_error,
                .@"return",
                .return_void,
                .unreachable_unsafe,
                .unreachable_safe,
                .loop,
                .container_field_named,
                .container_field_typed,
                .container_field,
                => true,
            };
        }
    };

    /// Prefer `castTag` to this.
    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (@hasField(T, "base_tag")) {
            return base.castTag(T.base_tag);
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                if (T == tag.Type()) {
                    return @fieldParentPtr(T, "base", base);
                }
                return null;
            }
        }
        unreachable;
    }

    pub fn castTag(base: *Inst, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
    }

    pub const NoOp = struct {
        base: Inst,

        positionals: struct {},
        kw_args: struct {},
    };

    pub const UnOp = struct {
        base: Inst,

        positionals: struct {
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const BinOp = struct {
        base: Inst,

        positionals: struct {
            lhs: *Inst,
            rhs: *Inst,
        },
        kw_args: struct {},
    };

    pub const Arg = struct {
        pub const base_tag = Tag.arg;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const Block = struct {
        pub const base_tag = Tag.block;
        base: Inst,

        positionals: struct {
            body: Body,
        },
        kw_args: struct {},
    };

    pub const Break = struct {
        pub const base_tag = Tag.@"break";
        base: Inst,

        positionals: struct {
            block: *Block,
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const BreakVoid = struct {
        pub const base_tag = Tag.break_void;
        base: Inst,

        positionals: struct {
            block: *Block,
        },
        kw_args: struct {},
    };

    pub const Call = struct {
        pub const base_tag = Tag.call;
        base: Inst,

        positionals: struct {
            func: *Inst,
            args: []*Inst,
        },
        kw_args: struct {
            modifier: std.builtin.CallOptions.Modifier = .auto,
        },
    };

    pub const DeclRef = struct {
        pub const base_tag = Tag.decl_ref;
        base: Inst,

        positionals: struct {
            decl: *IrModule.Decl,
        },
        kw_args: struct {},
    };

    pub const DeclRefStr = struct {
        pub const base_tag = Tag.decl_ref_str;
        base: Inst,

        positionals: struct {
            name: *Inst,
        },
        kw_args: struct {},
    };

    pub const DeclVal = struct {
        pub const base_tag = Tag.decl_val;
        base: Inst,

        positionals: struct {
            decl: *IrModule.Decl,
        },
        kw_args: struct {},
    };

    pub const CompileLog = struct {
        pub const base_tag = Tag.compile_log;
        base: Inst,

        positionals: struct {
            to_log: []*Inst,
        },
        kw_args: struct {},
    };

    pub const Const = struct {
        pub const base_tag = Tag.@"const";
        base: Inst,

        positionals: struct {
            typed_value: TypedValue,
        },
        kw_args: struct {},
    };

    pub const Str = struct {
        pub const base_tag = Tag.str;
        base: Inst,

        positionals: struct {
            bytes: []const u8,
        },
        kw_args: struct {},
    };

    pub const Int = struct {
        pub const base_tag = Tag.int;
        base: Inst,

        positionals: struct {
            int: BigIntConst,
        },
        kw_args: struct {},
    };

    pub const Loop = struct {
        pub const base_tag = Tag.loop;
        base: Inst,

        positionals: struct {
            body: Body,
        },
        kw_args: struct {},
    };

    pub const Field = struct {
        base: Inst,

        positionals: struct {
            object: *Inst,
            field_name: []const u8,
        },
        kw_args: struct {},
    };

    pub const FieldNamed = struct {
        base: Inst,

        positionals: struct {
            object: *Inst,
            field_name: *Inst,
        },
        kw_args: struct {},
    };

    pub const Asm = struct {
        pub const base_tag = Tag.@"asm";
        base: Inst,

        positionals: struct {
            asm_source: *Inst,
            return_type: *Inst,
        },
        kw_args: struct {
            @"volatile": bool = false,
            output: ?*Inst = null,
            inputs: []*Inst = &[0]*Inst{},
            clobbers: []*Inst = &[0]*Inst{},
            args: []*Inst = &[0]*Inst{},
        },
    };

    pub const Fn = struct {
        pub const base_tag = Tag.@"fn";
        base: Inst,

        positionals: struct {
            fn_type: *Inst,
            body: Body,
        },
        kw_args: struct {
            is_inline: bool = false,
        },
    };

    pub const FnType = struct {
        pub const base_tag = Tag.fntype;
        base: Inst,

        positionals: struct {
            param_types: []*Inst,
            return_type: *Inst,
        },
        kw_args: struct {
            cc: std.builtin.CallingConvention = .Unspecified,
        },
    };

    pub const IntType = struct {
        pub const base_tag = Tag.int_type;
        base: Inst,

        positionals: struct {
            signed: *Inst,
            bits: *Inst,
        },
        kw_args: struct {},
    };

    pub const Export = struct {
        pub const base_tag = Tag.@"export";
        base: Inst,

        positionals: struct {
            symbol_name: *Inst,
            decl_name: []const u8,
        },
        kw_args: struct {},
    };

    pub const ParamType = struct {
        pub const base_tag = Tag.param_type;
        base: Inst,

        positionals: struct {
            func: *Inst,
            arg_index: usize,
        },
        kw_args: struct {},
    };

    pub const Primitive = struct {
        pub const base_tag = Tag.primitive;
        base: Inst,

        positionals: struct {
            tag: Builtin,
        },
        kw_args: struct {},

        pub const Builtin = enum {
            i8,
            u8,
            i16,
            u16,
            i32,
            u32,
            i64,
            u64,
            isize,
            usize,
            c_short,
            c_ushort,
            c_int,
            c_uint,
            c_long,
            c_ulong,
            c_longlong,
            c_ulonglong,
            c_longdouble,
            c_void,
            f16,
            f32,
            f64,
            f128,
            bool,
            void,
            noreturn,
            type,
            anyerror,
            comptime_int,
            comptime_float,
            @"true",
            @"false",
            @"null",
            @"undefined",
            void_value,

            pub fn toTypedValue(self: Builtin) TypedValue {
                return switch (self) {
                    .i8 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i8_type) },
                    .u8 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u8_type) },
                    .i16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i16_type) },
                    .u16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u16_type) },
                    .i32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i32_type) },
                    .u32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u32_type) },
                    .i64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i64_type) },
                    .u64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u64_type) },
                    .isize => .{ .ty = Type.initTag(.type), .val = Value.initTag(.isize_type) },
                    .usize => .{ .ty = Type.initTag(.type), .val = Value.initTag(.usize_type) },
                    .c_short => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_short_type) },
                    .c_ushort => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ushort_type) },
                    .c_int => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_int_type) },
                    .c_uint => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_uint_type) },
                    .c_long => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_long_type) },
                    .c_ulong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ulong_type) },
                    .c_longlong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_longlong_type) },
                    .c_ulonglong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ulonglong_type) },
                    .c_longdouble => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_longdouble_type) },
                    .c_void => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_void_type) },
                    .f16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f16_type) },
                    .f32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f32_type) },
                    .f64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f64_type) },
                    .f128 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f128_type) },
                    .bool => .{ .ty = Type.initTag(.type), .val = Value.initTag(.bool_type) },
                    .void => .{ .ty = Type.initTag(.type), .val = Value.initTag(.void_type) },
                    .noreturn => .{ .ty = Type.initTag(.type), .val = Value.initTag(.noreturn_type) },
                    .type => .{ .ty = Type.initTag(.type), .val = Value.initTag(.type_type) },
                    .anyerror => .{ .ty = Type.initTag(.type), .val = Value.initTag(.anyerror_type) },
                    .comptime_int => .{ .ty = Type.initTag(.type), .val = Value.initTag(.comptime_int_type) },
                    .comptime_float => .{ .ty = Type.initTag(.type), .val = Value.initTag(.comptime_float_type) },
                    .@"true" => .{ .ty = Type.initTag(.bool), .val = Value.initTag(.bool_true) },
                    .@"false" => .{ .ty = Type.initTag(.bool), .val = Value.initTag(.bool_false) },
                    .@"null" => .{ .ty = Type.initTag(.@"null"), .val = Value.initTag(.null_value) },
                    .@"undefined" => .{ .ty = Type.initTag(.@"undefined"), .val = Value.initTag(.undef) },
                    .void_value => .{ .ty = Type.initTag(.void), .val = Value.initTag(.void_value) },
                };
            }
        };
    };

    pub const Elem = struct {
        base: Inst,

        positionals: struct {
            array: *Inst,
            index: *Inst,
        },
        kw_args: struct {},
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;
        base: Inst,

        positionals: struct {
            condition: *Inst,
            then_body: Body,
            else_body: Body,
        },
        kw_args: struct {},
    };

    pub const PtrType = struct {
        pub const base_tag = Tag.ptr_type;
        base: Inst,

        positionals: struct {
            child_type: *Inst,
        },
        kw_args: struct {
            @"allowzero": bool = false,
            @"align": ?*Inst = null,
            align_bit_start: ?*Inst = null,
            align_bit_end: ?*Inst = null,
            mutable: bool = true,
            @"volatile": bool = false,
            sentinel: ?*Inst = null,
            size: std.builtin.TypeInfo.Pointer.Size = .One,
        },
    };

    pub const ArrayTypeSentinel = struct {
        pub const base_tag = Tag.array_type_sentinel;
        base: Inst,

        positionals: struct {
            len: *Inst,
            sentinel: *Inst,
            elem_type: *Inst,
        },
        kw_args: struct {},
    };

    pub const EnumLiteral = struct {
        pub const base_tag = Tag.enum_literal;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const ErrorSet = struct {
        pub const base_tag = Tag.error_set;
        base: Inst,

        positionals: struct {
            fields: [][]const u8,
        },
        kw_args: struct {},
    };

    pub const Slice = struct {
        pub const base_tag = Tag.slice;
        base: Inst,

        positionals: struct {
            array_ptr: *Inst,
            start: *Inst,
        },
        kw_args: struct {
            end: ?*Inst = null,
            sentinel: ?*Inst = null,
        },
    };

    pub const TypeOfPeer = struct {
        pub const base_tag = .typeof_peer;
        base: Inst,
        positionals: struct {
            items: []*Inst,
        },
        kw_args: struct {},
    };

    pub const ContainerFieldNamed = struct {
        pub const base_tag = Tag.container_field_named;
        base: Inst,

        positionals: struct {
            bytes: []const u8,
        },
        kw_args: struct {},
    };

    pub const ContainerFieldTyped = struct {
        pub const base_tag = Tag.container_field_typed;
        base: Inst,

        positionals: struct {
            bytes: []const u8,
            ty: *Inst,
        },
        kw_args: struct {},
    };

    pub const ContainerField = struct {
        pub const base_tag = Tag.container_field;
        base: Inst,

        positionals: struct {
            bytes: []const u8,
        },
        kw_args: struct {
            ty: ?*Inst = null,
            init: ?*Inst = null,
            alignment: ?*Inst = null,
            is_comptime: bool = false,
        },
    };

    pub const EnumType = struct {
        pub const base_tag = Tag.enum_type;
        base: Inst,

        positionals: struct {
            fields: []*Inst,
        },
        kw_args: struct {
            tag_type: ?*Inst = null,
            layout: std.builtin.TypeInfo.ContainerLayout = .Auto,
        },
    };

    pub const StructType = struct {
        pub const base_tag = Tag.struct_type;
        base: Inst,

        positionals: struct {
            fields: []*Inst,
        },
        kw_args: struct {
            layout: std.builtin.TypeInfo.ContainerLayout = .Auto,
        },
    };

    pub const UnionType = struct {
        pub const base_tag = Tag.union_type;
        base: Inst,

        positionals: struct {
            fields: []*Inst,
        },
        kw_args: struct {
            init_inst: ?*Inst = null,
            init_kind: InitKind = .none,
            layout: std.builtin.TypeInfo.ContainerLayout = .Auto,
        },

        // TODO error: values of type '(enum literal)' must be comptime known
        pub const InitKind = enum {
            enum_type,
            tag_type,
            none,
        };
    };

    pub const SwitchBr = struct {
        pub const base_tag = Tag.switchbr;
        base: Inst,

        positionals: struct {
            target: *Inst,
            /// List of all individual items and ranges
            items: []*Inst,
            cases: []Case,
            else_body: Body,
        },
        kw_args: struct {
            /// Pointer to first range if such exists.
            range: ?*Inst = null,
            special_prong: SpecialProng = .none,
        },

        // Not anonymous due to stage1 limitations
        pub const SpecialProng = enum {
            none,
            @"else",
            underscore,
        };

        pub const Case = struct {
            item: *Inst,
            body: Body,
        };
    };
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Body = struct {
    instructions: []*Inst,
};

pub const Module = struct {
    decls: []*Decl,
    arena: std.heap.ArenaAllocator,
    error_msg: ?ErrorMsg = null,
    metadata: std.AutoHashMap(*Inst, MetaData),
    body_metadata: std.AutoHashMap(*Body, BodyMetaData),

    pub const Decl = struct {
        name: []const u8,

        /// Hash of slice into the source of the part after the = and before the next instruction.
        contents_hash: std.zig.SrcHash,

        inst: *Inst,
    };

    pub const MetaData = struct {
        deaths: ir.Inst.DeathsInt,
        addr: usize,
    };

    pub const BodyMetaData = struct {
        deaths: []*Inst,
    };

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        self.metadata.deinit();
        self.body_metadata.deinit();
        allocator.free(self.decls);
        self.arena.deinit();
        self.* = undefined;
    }

    /// This is a debugging utility for rendering the tree to stderr.
    pub fn dump(self: Module) void {
        self.writeToStream(std.heap.page_allocator, std.io.getStdErr().writer()) catch {};
    }

    const DeclAndIndex = struct {
        decl: *Decl,
        index: usize,
    };

    /// TODO Look into making a table to speed this up.
    pub fn findDecl(self: Module, name: []const u8) ?DeclAndIndex {
        for (self.decls) |decl, i| {
            if (mem.eql(u8, decl.name, name)) {
                return DeclAndIndex{
                    .decl = decl,
                    .index = i,
                };
            }
        }
        return null;
    }

    pub fn findInstDecl(self: Module, inst: *Inst) ?DeclAndIndex {
        for (self.decls) |decl, i| {
            if (decl.inst == inst) {
                return DeclAndIndex{
                    .decl = decl,
                    .index = i,
                };
            }
        }
        return null;
    }

    /// The allocator is used for temporary storage, but this function always returns
    /// with no resources allocated.
    pub fn writeToStream(self: Module, allocator: *Allocator, stream: anytype) !void {
        var write = Writer{
            .module = &self,
            .inst_table = InstPtrTable.init(allocator),
            .block_table = std.AutoHashMap(*Inst.Block, []const u8).init(allocator),
            .loop_table = std.AutoHashMap(*Inst.Loop, []const u8).init(allocator),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .indent = 2,
            .next_instr_index = undefined,
        };
        defer write.arena.deinit();
        defer write.inst_table.deinit();
        defer write.block_table.deinit();
        defer write.loop_table.deinit();

        // First, build a map of *Inst to @ or % indexes
        try write.inst_table.ensureCapacity(@intCast(u32, self.decls.len));

        for (self.decls) |decl, decl_i| {
            try write.inst_table.putNoClobber(decl.inst, .{ .inst = decl.inst, .index = null, .name = decl.name });
        }

        for (self.decls) |decl, i| {
            write.next_instr_index = 0;
            try stream.print("@{s} ", .{decl.name});
            try write.writeInstToStream(stream, decl.inst);
            try stream.writeByte('\n');
        }
    }
};

const InstPtrTable = std.AutoHashMap(*Inst, struct { inst: *Inst, index: ?usize, name: []const u8 });

const Writer = struct {
    module: *const Module,
    inst_table: InstPtrTable,
    block_table: std.AutoHashMap(*Inst.Block, []const u8),
    loop_table: std.AutoHashMap(*Inst.Loop, []const u8),
    arena: std.heap.ArenaAllocator,
    indent: usize,
    next_instr_index: usize,

    fn writeInstToStream(
        self: *Writer,
        stream: anytype,
        inst: *Inst,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        inline for (@typeInfo(Inst.Tag).Enum.fields) |enum_field| {
            const expected_tag = @field(Inst.Tag, enum_field.name);
            if (inst.tag == expected_tag) {
                return self.writeInstToStreamGeneric(stream, expected_tag, inst);
            }
        }
        unreachable; // all tags handled
    }

    fn writeInstToStreamGeneric(
        self: *Writer,
        stream: anytype,
        comptime inst_tag: Inst.Tag,
        base: *Inst,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const SpecificInst = inst_tag.Type();
        const inst = @fieldParentPtr(SpecificInst, "base", base);
        const Positionals = @TypeOf(inst.positionals);
        try stream.writeAll("= " ++ @tagName(inst_tag) ++ "(");
        const pos_fields = @typeInfo(Positionals).Struct.fields;
        inline for (pos_fields) |arg_field, i| {
            if (i != 0) {
                try stream.writeAll(", ");
            }
            try self.writeParamToStream(stream, &@field(inst.positionals, arg_field.name));
        }

        comptime var need_comma = pos_fields.len != 0;
        const KW_Args = @TypeOf(inst.kw_args);
        inline for (@typeInfo(KW_Args).Struct.fields) |arg_field, i| {
            if (@typeInfo(arg_field.field_type) == .Optional) {
                if (@field(inst.kw_args, arg_field.name)) |non_optional| {
                    if (need_comma) try stream.writeAll(", ");
                    try stream.print("{s}=", .{arg_field.name});
                    try self.writeParamToStream(stream, &non_optional);
                    need_comma = true;
                }
            } else {
                if (need_comma) try stream.writeAll(", ");
                try stream.print("{s}=", .{arg_field.name});
                try self.writeParamToStream(stream, &@field(inst.kw_args, arg_field.name));
                need_comma = true;
            }
        }

        try stream.writeByte(')');
    }

    fn writeParamToStream(self: *Writer, stream: anytype, param_ptr: anytype) !void {
        const param = param_ptr.*;
        if (@typeInfo(@TypeOf(param)) == .Enum) {
            return stream.writeAll(@tagName(param));
        }
        switch (@TypeOf(param)) {
            *Inst => return self.writeInstParamToStream(stream, param),
            []*Inst => {
                try stream.writeByte('[');
                for (param) |inst, i| {
                    if (i != 0) {
                        try stream.writeAll(", ");
                    }
                    try self.writeInstParamToStream(stream, inst);
                }
                try stream.writeByte(']');
            },
            Body => {
                try stream.writeAll("{\n");
                if (self.module.body_metadata.get(param_ptr)) |metadata| {
                    if (metadata.deaths.len > 0) {
                        try stream.writeByteNTimes(' ', self.indent);
                        try stream.writeAll("; deaths={");
                        for (metadata.deaths) |death, i| {
                            if (i != 0) try stream.writeAll(", ");
                            try self.writeInstParamToStream(stream, death);
                        }
                        try stream.writeAll("}\n");
                    }
                }

                for (param.instructions) |inst| {
                    const my_i = self.next_instr_index;
                    self.next_instr_index += 1;
                    try self.inst_table.putNoClobber(inst, .{ .inst = inst, .index = my_i, .name = undefined });
                    try stream.writeByteNTimes(' ', self.indent);
                    try stream.print("%{d} ", .{my_i});
                    if (inst.cast(Inst.Block)) |block| {
                        const name = try std.fmt.allocPrint(&self.arena.allocator, "label_{d}", .{my_i});
                        try self.block_table.put(block, name);
                    } else if (inst.cast(Inst.Loop)) |loop| {
                        const name = try std.fmt.allocPrint(&self.arena.allocator, "loop_{d}", .{my_i});
                        try self.loop_table.put(loop, name);
                    }
                    self.indent += 2;
                    try self.writeInstToStream(stream, inst);
                    if (self.module.metadata.get(inst)) |metadata| {
                        try stream.print(" ; deaths=0b{b}", .{metadata.deaths});
                        // This is conditionally compiled in because addresses mess up the tests due
                        // to Address Space Layout Randomization. It's super useful when debugging
                        // codegen.zig though.
                        if (!std.builtin.is_test) {
                            try stream.print(" 0x{x}", .{metadata.addr});
                        }
                    }
                    self.indent -= 2;
                    try stream.writeByte('\n');
                }
                try stream.writeByteNTimes(' ', self.indent - 2);
                try stream.writeByte('}');
            },
            bool => return stream.writeByte("01"[@boolToInt(param)]),
            []u8, []const u8 => return stream.print("\"{}\"", .{std.zig.fmtEscapes(param)}),
            BigIntConst, usize => return stream.print("{}", .{param}),
            TypedValue => return stream.print("TypedValue{{ .ty = {}, .val = {}}}", .{ param.ty, param.val }),
            *IrModule.Decl => return stream.print("Decl({s})", .{param.name}),
            *Inst.Block => {
                const name = self.block_table.get(param) orelse "!BADREF!";
                return stream.print("\"{}\"", .{std.zig.fmtEscapes(name)});
            },
            *Inst.Loop => {
                const name = self.loop_table.get(param).?;
                return stream.print("\"{}\"", .{std.zig.fmtEscapes(name)});
            },
            [][]const u8 => {
                try stream.writeByte('[');
                for (param) |str, i| {
                    if (i != 0) {
                        try stream.writeAll(", ");
                    }
                    try stream.print("\"{}\"", .{std.zig.fmtEscapes(str)});
                }
                try stream.writeByte(']');
            },
            []Inst.SwitchBr.Case => {
                if (param.len == 0) {
                    return stream.writeAll("{}");
                }
                try stream.writeAll("{\n");
                for (param) |*case, i| {
                    if (i != 0) {
                        try stream.writeAll(",\n");
                    }
                    try stream.writeByteNTimes(' ', self.indent);
                    self.indent += 2;
                    try self.writeParamToStream(stream, &case.item);
                    try stream.writeAll(" => ");
                    try self.writeParamToStream(stream, &case.body);
                    self.indent -= 2;
                }
                try stream.writeByte('\n');
                try stream.writeByteNTimes(' ', self.indent - 2);
                try stream.writeByte('}');
            },
            else => |T| @compileError("unimplemented: rendering parameter of type " ++ @typeName(T)),
        }
    }

    fn writeInstParamToStream(self: *Writer, stream: anytype, inst: *Inst) !void {
        if (self.inst_table.get(inst)) |info| {
            if (info.index) |i| {
                try stream.print("%{d}", .{info.index});
            } else {
                try stream.print("@{s}", .{info.name});
            }
        } else if (inst.cast(Inst.DeclVal)) |decl_val| {
            try stream.print("@{s}", .{decl_val.positionals.decl.name});
        } else {
            // This should be unreachable in theory, but since ZIR is used for debugging the compiler
            // we output some debug text instead.
            try stream.print("?{s}?", .{@tagName(inst.tag)});
        }
    }
};

/// For debugging purposes, prints a function representation to stderr.
pub fn dumpFn(old_module: IrModule, module_fn: *IrModule.Fn) void {
    const allocator = old_module.gpa;
    var ctx: DumpTzir = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .module_fn = module_fn,
        .indent = 2,
        .inst_table = DumpTzir.InstTable.init(allocator),
        .partial_inst_table = DumpTzir.InstTable.init(allocator),
        .const_table = DumpTzir.InstTable.init(allocator),
    };
    defer ctx.inst_table.deinit();
    defer ctx.partial_inst_table.deinit();
    defer ctx.const_table.deinit();
    defer ctx.arena.deinit();

    switch (module_fn.state) {
        .queued => std.debug.print("(queued)", .{}),
        .inline_only => std.debug.print("(inline_only)", .{}),
        .in_progress => std.debug.print("(in_progress)", .{}),
        .sema_failure => std.debug.print("(sema_failure)", .{}),
        .dependency_failure => std.debug.print("(dependency_failure)", .{}),
        .success => {
            const writer = std.io.getStdErr().writer();
            ctx.dump(module_fn.body, writer) catch @panic("failed to dump TZIR");
        },
    }
}

const DumpTzir = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const IrModule,
    module_fn: *IrModule.Fn,
    indent: usize,
    inst_table: InstTable,
    partial_inst_table: InstTable,
    const_table: InstTable,
    next_index: usize = 0,
    next_partial_index: usize = 0,
    next_const_index: usize = 0,

    const InstTable = std.AutoArrayHashMap(*ir.Inst, usize);

    /// TODO: Improve this code to include a stack of ir.Body and store the instructions
    /// in there. Now we are putting all the instructions in a function local table,
    /// however instructions that are in a Body can be thown away when the Body ends.
    fn dump(dtz: *DumpTzir, body: ir.Body, writer: std.fs.File.Writer) !void {
        // First pass to pre-populate the table so that we can show even invalid references.
        // Must iterate the same order we iterate the second time.
        // We also look for constants and put them in the const_table.
        try dtz.fetchInstsAndResolveConsts(body);

        std.debug.print("Module.Function(name={s}):\n", .{dtz.module_fn.owner_decl.name});

        for (dtz.const_table.items()) |entry| {
            const constant = entry.key.castTag(.constant).?;
            try writer.print("  @{d}: {} = {};\n", .{
                entry.value, constant.base.ty, constant.val,
            });
        }

        return dtz.dumpBody(body, writer);
    }

    fn fetchInstsAndResolveConsts(dtz: *DumpTzir, body: ir.Body) error{OutOfMemory}!void {
        for (body.instructions) |inst| {
            try dtz.inst_table.put(inst, dtz.next_index);
            dtz.next_index += 1;
            switch (inst.tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                .dbg_stmt,
                => {},

                .ref,
                .ret,
                .bitcast,
                .not,
                .is_non_null,
                .is_non_null_ptr,
                .is_null,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .optional_payload,
                .optional_payload_ptr,
                .wrap_optional,
                => {
                    const un_op = inst.cast(ir.Inst.UnOp).?;
                    try dtz.findConst(un_op.operand);
                },

                .add,
                .sub,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                .bool_and,
                .bool_or,
                .bit_and,
                .bit_or,
                .xor,
                => {
                    const bin_op = inst.cast(ir.Inst.BinOp).?;
                    try dtz.findConst(bin_op.lhs);
                    try dtz.findConst(bin_op.rhs);
                },

                .arg => {},

                .br => {
                    const br = inst.castTag(.br).?;
                    try dtz.findConst(&br.block.base);
                    try dtz.findConst(br.operand);
                },

                .br_block_flat => {
                    const br_block_flat = inst.castTag(.br_block_flat).?;
                    try dtz.findConst(&br_block_flat.block.base);
                    try dtz.fetchInstsAndResolveConsts(br_block_flat.body);
                },

                .br_void => {
                    const br_void = inst.castTag(.br_void).?;
                    try dtz.findConst(&br_void.block.base);
                },

                .block => {
                    const block = inst.castTag(.block).?;
                    try dtz.fetchInstsAndResolveConsts(block.body);
                },

                .condbr => {
                    const condbr = inst.castTag(.condbr).?;
                    try dtz.findConst(condbr.condition);
                    try dtz.fetchInstsAndResolveConsts(condbr.then_body);
                    try dtz.fetchInstsAndResolveConsts(condbr.else_body);
                },

                .loop => {
                    const loop = inst.castTag(.loop).?;
                    try dtz.fetchInstsAndResolveConsts(loop.body);
                },
                .call => {
                    const call = inst.castTag(.call).?;
                    try dtz.findConst(call.func);
                    for (call.args) |arg| {
                        try dtz.findConst(arg);
                    }
                },

                // TODO fill out this debug printing
                .assembly,
                .constant,
                .varptr,
                .switchbr,
                => {},
            }
        }
    }

    fn dumpBody(dtz: *DumpTzir, body: ir.Body, writer: std.fs.File.Writer) (std.fs.File.WriteError || error{OutOfMemory})!void {
        for (body.instructions) |inst| {
            const my_index = dtz.next_partial_index;
            try dtz.partial_inst_table.put(inst, my_index);
            dtz.next_partial_index += 1;

            try writer.writeByteNTimes(' ', dtz.indent);
            try writer.print("%{d}: {} = {s}(", .{
                my_index, inst.ty, @tagName(inst.tag),
            });
            switch (inst.tag) {
                .alloc,
                .retvoid,
                .unreach,
                .breakpoint,
                .dbg_stmt,
                => try writer.writeAll(")\n"),

                .ref,
                .ret,
                .bitcast,
                .not,
                .is_non_null,
                .is_null,
                .is_non_null_ptr,
                .is_null_ptr,
                .is_err,
                .is_err_ptr,
                .ptrtoint,
                .floatcast,
                .intcast,
                .load,
                .optional_payload,
                .optional_payload_ptr,
                .wrap_optional,
                => {
                    const un_op = inst.cast(ir.Inst.UnOp).?;
                    const kinky = try dtz.writeInst(writer, un_op.operand);
                    if (kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .add,
                .sub,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .store,
                .bool_and,
                .bool_or,
                .bit_and,
                .bit_or,
                .xor,
                => {
                    const bin_op = inst.cast(ir.Inst.BinOp).?;

                    const lhs_kinky = try dtz.writeInst(writer, bin_op.lhs);
                    try writer.writeAll(", ");
                    const rhs_kinky = try dtz.writeInst(writer, bin_op.rhs);

                    if (lhs_kinky != null or rhs_kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (lhs_kinky) |lhs| {
                            try writer.print(" %{d}", .{lhs});
                        }
                        if (rhs_kinky) |rhs| {
                            try writer.print(" %{d}", .{rhs});
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .arg => {
                    const arg = inst.castTag(.arg).?;
                    try writer.print("{s})\n", .{arg.name});
                },

                .br => {
                    const br = inst.castTag(.br).?;

                    const lhs_kinky = try dtz.writeInst(writer, &br.block.base);
                    try writer.writeAll(", ");
                    const rhs_kinky = try dtz.writeInst(writer, br.operand);

                    if (lhs_kinky != null or rhs_kinky != null) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (lhs_kinky) |lhs| {
                            try writer.print(" %{d}", .{lhs});
                        }
                        if (rhs_kinky) |rhs| {
                            try writer.print(" %{d}", .{rhs});
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .br_block_flat => {
                    const br_block_flat = inst.castTag(.br_block_flat).?;
                    const block_kinky = try dtz.writeInst(writer, &br_block_flat.block.base);
                    if (block_kinky != null) {
                        try writer.writeAll(", { // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(", {\n");
                    }

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(br_block_flat.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .br_void => {
                    const br_void = inst.castTag(.br_void).?;
                    const kinky = try dtz.writeInst(writer, &br_void.block.base);
                    if (kinky) |_| {
                        try writer.writeAll(") // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                .block => {
                    const block = inst.castTag(.block).?;

                    try writer.writeAll("{\n");

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(block.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .condbr => {
                    const condbr = inst.castTag(.condbr).?;

                    const condition_kinky = try dtz.writeInst(writer, condbr.condition);
                    if (condition_kinky != null) {
                        try writer.writeAll(", { // Instruction does not dominate all uses!\n");
                    } else {
                        try writer.writeAll(", {\n");
                    }

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(condbr.then_body, writer);

                    try writer.writeByteNTimes(' ', old_indent);
                    try writer.writeAll("}, {\n");

                    try dtz.dumpBody(condbr.else_body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', old_indent);
                    try writer.writeAll("})\n");
                },

                .loop => {
                    const loop = inst.castTag(.loop).?;

                    try writer.writeAll("{\n");

                    const old_indent = dtz.indent;
                    dtz.indent += 2;
                    try dtz.dumpBody(loop.body, writer);
                    dtz.indent = old_indent;

                    try writer.writeByteNTimes(' ', dtz.indent);
                    try writer.writeAll("})\n");
                },

                .call => {
                    const call = inst.castTag(.call).?;

                    const args_kinky = try dtz.allocator.alloc(?usize, call.args.len);
                    defer dtz.allocator.free(args_kinky);
                    std.mem.set(?usize, args_kinky, null);
                    var any_kinky_args = false;

                    const func_kinky = try dtz.writeInst(writer, call.func);

                    for (call.args) |arg, i| {
                        try writer.writeAll(", ");

                        args_kinky[i] = try dtz.writeInst(writer, arg);
                        any_kinky_args = any_kinky_args or args_kinky[i] != null;
                    }

                    if (func_kinky != null or any_kinky_args) {
                        try writer.writeAll(") // Instruction does not dominate all uses!");
                        if (func_kinky) |func_index| {
                            try writer.print(" %{d}", .{func_index});
                        }
                        for (args_kinky) |arg_kinky| {
                            if (arg_kinky) |arg_index| {
                                try writer.print(" %{d}", .{arg_index});
                            }
                        }
                        try writer.writeAll("\n");
                    } else {
                        try writer.writeAll(")\n");
                    }
                },

                // TODO fill out this debug printing
                .assembly,
                .constant,
                .varptr,
                .switchbr,
                => {
                    try writer.writeAll("!TODO!)\n");
                },
            }
        }
    }

    fn writeInst(dtz: *DumpTzir, writer: std.fs.File.Writer, inst: *ir.Inst) !?usize {
        if (dtz.partial_inst_table.get(inst)) |operand_index| {
            try writer.print("%{d}", .{operand_index});
            return null;
        } else if (dtz.const_table.get(inst)) |operand_index| {
            try writer.print("@{d}", .{operand_index});
            return null;
        } else if (dtz.inst_table.get(inst)) |operand_index| {
            try writer.print("%{d}", .{operand_index});
            return operand_index;
        } else {
            try writer.writeAll("!BADREF!");
            return null;
        }
    }

    fn findConst(dtz: *DumpTzir, operand: *ir.Inst) !void {
        if (operand.tag == .constant) {
            try dtz.const_table.put(operand, dtz.next_const_index);
            dtz.next_const_index += 1;
        }
    }
};

/// For debugging purposes, like dumpFn but for unanalyzed zir blocks
pub fn dumpZir(allocator: *Allocator, kind: []const u8, decl_name: [*:0]const u8, instructions: []*Inst) !void {
    var fib = std.heap.FixedBufferAllocator.init(&[_]u8{});
    var module = Module{
        .decls = &[_]*Module.Decl{},
        .arena = std.heap.ArenaAllocator.init(&fib.allocator),
        .metadata = std.AutoHashMap(*Inst, Module.MetaData).init(&fib.allocator),
        .body_metadata = std.AutoHashMap(*Body, Module.BodyMetaData).init(&fib.allocator),
    };
    var write = Writer{
        .module = &module,
        .inst_table = InstPtrTable.init(allocator),
        .block_table = std.AutoHashMap(*Inst.Block, []const u8).init(allocator),
        .loop_table = std.AutoHashMap(*Inst.Loop, []const u8).init(allocator),
        .arena = std.heap.ArenaAllocator.init(allocator),
        .indent = 4,
        .next_instr_index = 0,
    };
    defer write.arena.deinit();
    defer write.inst_table.deinit();
    defer write.block_table.deinit();
    defer write.loop_table.deinit();

    try write.inst_table.ensureCapacity(@intCast(u32, instructions.len));

    const stderr = std.io.getStdErr().writer();
    try stderr.print("{s} {s} {{ // unanalyzed\n", .{ kind, decl_name });

    for (instructions) |inst| {
        const my_i = write.next_instr_index;
        write.next_instr_index += 1;

        if (inst.cast(Inst.Block)) |block| {
            const name = try std.fmt.allocPrint(&write.arena.allocator, "label_{d}", .{my_i});
            try write.block_table.put(block, name);
        } else if (inst.cast(Inst.Loop)) |loop| {
            const name = try std.fmt.allocPrint(&write.arena.allocator, "loop_{d}", .{my_i});
            try write.loop_table.put(loop, name);
        }

        try write.inst_table.putNoClobber(inst, .{ .inst = inst, .index = my_i, .name = "inst" });
        try stderr.print("  %{d} ", .{my_i});
        try write.writeInstToStream(stderr, inst);
        try stderr.writeByte('\n');
    }

    try stderr.print("}} // {s} {s}\n\n", .{ kind, decl_name });
}
