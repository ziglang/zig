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

/// This struct is relevent only for the ZIR Module text format. It is not used for
/// semantic analysis of Zig source code.
pub const Decl = struct {
    name: []const u8,

    /// Hash of slice into the source of the part after the = and before the next instruction.
    contents_hash: std.zig.SrcHash,

    inst: *Inst,
};

/// These are instructions that correspond to the ZIR text format. See `ir.Inst` for
/// in-memory, analyzed instructions with types and values.
pub const Inst = struct {
    tag: Tag,
    /// Byte offset into the source.
    src: usize,
    /// Pre-allocated field for mapping ZIR text instructions to post-analysis instructions.
    analyzed_inst: ?*ir.Inst = null,

    /// These names are used directly as the instruction names in the text format.
    pub const Tag = enum {
        /// Arithmetic addition, asserts no integer overflow.
        add,
        /// Twos complement wrapping integer addition.
        addwrap,
        /// Allocates stack local memory. Its lifetime ends when the block ends that contains
        /// this instruction. The operand is the type of the allocated object.
        alloc,
        /// Same as `alloc` except the type is inferred.
        alloc_inferred,
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
        /// Function parameter value. These must be first in a function's main block,
        /// in respective order with the parameters.
        arg,
        /// Type coercion.
        as,
        /// Inline assembly.
        @"asm",
        /// Bitwise AND. `&`
        bitand,
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
        bitnot,
        /// Bitwise OR. `|`
        bitor,
        /// A labeled block of code, which can return a value.
        block,
        /// A block of code, which can return a value. There are no instructions that break out of
        /// this block; it is implied that the final instruction is the result.
        block_flat,
        /// Same as `block` but additionally makes the inner instructions execute at comptime.
        block_comptime,
        /// Same as `block_flat` but additionally makes the inner instructions execute at comptime.
        block_comptime_flat,
        /// Boolean NOT. See also `bitnot`.
        boolnot,
        /// Return a value from a `Block`.
        @"break",
        breakpoint,
        /// Same as `break` but without an operand; the operand is assumed to be the void value.
        breakvoid,
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
        /// This instruction does a `coerce_result_ptr` operation on a `Block`'s
        /// result location pointer, whose type is inferred by peer type resolution on the
        /// `Block`'s corresponding `break` instructions.
        coerce_result_block_ptr,
        /// Equivalent to `as(ptr_child_type(typeof(ptr)), value)`.
        coerce_to_ptr_elem,
        /// Emit an error message and fail compilation.
        compileerror,
        /// Conditional branch. Splits control flow based on a boolean condition value.
        condbr,
        /// Special case, has no textual representation.
        @"const",
        /// Declares the beginning of a statement. Used for debug info.
        dbg_stmt,
        /// Represents a pointer to a global decl by name.
        declref,
        /// Represents a pointer to a global decl by string name.
        declref_str,
        /// The syntax `@foo` is equivalent to `declval("foo")`.
        /// declval is equivalent to declref followed by deref.
        declval,
        /// Same as declval but the parameter is a `*Module.Decl` rather than a name.
        declval_in_module,
        /// Load the value from a pointer.
        deref,
        /// Arithmetic division. Asserts no integer overflow.
        div,
        /// Given a pointer to an array, slice, or pointer, returns a pointer to the element at
        /// the provided index.
        elemptr,
        /// Emits a compile error if the operand is not `void`.
        ensure_result_used,
        /// Emits a compile error if an error is ignored.
        ensure_result_non_error,
        /// Emits a compile error if operand cannot be indexed.
        ensure_indexable,
        /// Create a `E!T` type.
        error_union_type,
        /// Create an error set.
        error_set,
        /// Export the provided Decl as the provided name in the compilation's output object file.
        @"export",
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field.
        fieldptr,
        /// Convert a larger float type to any other float type, possibly causing a loss of precision.
        floatcast,
        /// Declare a function body.
        @"fn",
        /// Returns a function type.
        fntype,
        /// Integer literal.
        int,
        /// Convert an integer value to another integer type, asserting that the destination type
        /// can hold the same mathematical value.
        intcast,
        /// Make an integer type out of signedness and bit count.
        inttype,
        /// Return a boolean false if an optional is null. `x != null`
        isnonnull,
        /// Return a boolean true if an optional is null. `x == null`
        isnull,
        /// Return a boolean true if value is an error
        iserr,
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
        returnvoid,
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
        /// Slice operation `array_ptr[start..end:sentinel]`
        slice,
        /// Slice operation with just start `lhs[rhs..]`
        slice_start,
        /// Write a value to a pointer. For loading, see `deref`.
        store,
        /// String Literal. Makes an anonymous Decl and then takes a pointer to it.
        str,
        /// Arithmetic subtraction. Asserts no integer overflow.
        sub,
        /// Twos complement wrapping integer subtraction.
        subwrap,
        /// Returns the type of a value.
        typeof,
        /// Asserts control-flow will not reach this instruction. Not safety checked - the compiler
        /// will assume the correctness of this instruction.
        unreach_nocheck,
        /// Asserts control-flow will not reach this instruction. In safety-checked modes,
        /// this will generate a call to the panic function unless it can be proven unreachable
        /// by the compiler.
        @"unreachable",
        /// Bitwise XOR. `^`
        xor,
        /// Create an optional type '?T'
        optional_type,
        /// Unwraps an optional value 'lhs.?'
        unwrap_optional_safe,
        /// Same as previous, but without safety checks. Used for orelse, if and while
        unwrap_optional_unsafe,
        /// Gets the payload of an error union
        unwrap_err_safe,
        /// Same as previous, but without safety checks. Used for orelse, if and while
        unwrap_err_unsafe,
        /// Gets the error code value of an error union
        unwrap_err_code,
        /// Takes a *E!T and raises a compiler error if T != void
        ensure_err_payload_void,
        /// Enum literal
        enum_literal,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .breakpoint,
                .dbg_stmt,
                .returnvoid,
                .alloc_inferred,
                .ret_ptr,
                .ret_type,
                .unreach_nocheck,
                .@"unreachable",
                => NoOp,

                .boolnot,
                .deref,
                .@"return",
                .isnull,
                .isnonnull,
                .iserr,
                .ptrtoint,
                .alloc,
                .ensure_result_used,
                .ensure_result_non_error,
                .ensure_indexable,
                .bitcast_result_ptr,
                .ref,
                .bitcast_ref,
                .typeof,
                .single_const_ptr_type,
                .single_mut_ptr_type,
                .many_const_ptr_type,
                .many_mut_ptr_type,
                .c_const_ptr_type,
                .c_mut_ptr_type,
                .mut_slice_type,
                .const_slice_type,
                .optional_type,
                .unwrap_optional_safe,
                .unwrap_optional_unsafe,
                .unwrap_err_safe,
                .unwrap_err_unsafe,
                .unwrap_err_code,
                .ensure_err_payload_void,
                .anyframe_type,
                .bitnot,
                => UnOp,

                .add,
                .addwrap,
                .array_cat,
                .array_mul,
                .array_type,
                .bitand,
                .bitor,
                .div,
                .mod_rem,
                .mul,
                .mulwrap,
                .shl,
                .shr,
                .store,
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
                => BinOp,

                .block,
                .block_flat,
                .block_comptime,
                .block_comptime_flat,
                => Block,

                .arg => Arg,
                .array_type_sentinel => ArrayTypeSentinel,
                .@"break" => Break,
                .breakvoid => BreakVoid,
                .call => Call,
                .coerce_to_ptr_elem => CoerceToPtrElem,
                .declref => DeclRef,
                .declref_str => DeclRefStr,
                .declval => DeclVal,
                .declval_in_module => DeclValInModule,
                .coerce_result_block_ptr => CoerceResultBlockPtr,
                .compileerror => CompileError,
                .loop => Loop,
                .@"const" => Const,
                .str => Str,
                .int => Int,
                .inttype => IntType,
                .fieldptr => FieldPtr,
                .@"asm" => Asm,
                .@"fn" => Fn,
                .@"export" => Export,
                .param_type => ParamType,
                .primitive => Primitive,
                .fntype => FnType,
                .elemptr => ElemPtr,
                .condbr => CondBr,
                .ptr_type => PtrType,
                .enum_literal => EnumLiteral,
                .error_set => ErrorSet,
                .slice => Slice,
            };
        }

        /// Returns whether the instruction is one of the control flow "noreturn" types.
        /// Function calls do not count.
        pub fn isNoReturn(tag: Tag) bool {
            return switch (tag) {
                .add,
                .addwrap,
                .alloc,
                .alloc_inferred,
                .array_cat,
                .array_mul,
                .array_type,
                .array_type_sentinel,
                .arg,
                .as,
                .@"asm",
                .bitand,
                .bitcast,
                .bitcast_ref,
                .bitcast_result_ptr,
                .bitor,
                .block,
                .block_flat,
                .block_comptime,
                .block_comptime_flat,
                .boolnot,
                .breakpoint,
                .call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .coerce_result_ptr,
                .coerce_result_block_ptr,
                .coerce_to_ptr_elem,
                .@"const",
                .dbg_stmt,
                .declref,
                .declref_str,
                .declval,
                .declval_in_module,
                .deref,
                .div,
                .elemptr,
                .ensure_result_used,
                .ensure_result_non_error,
                .ensure_indexable,
                .@"export",
                .floatcast,
                .fieldptr,
                .@"fn",
                .fntype,
                .int,
                .intcast,
                .inttype,
                .isnonnull,
                .isnull,
                .iserr,
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
                .str,
                .sub,
                .subwrap,
                .typeof,
                .xor,
                .optional_type,
                .unwrap_optional_safe,
                .unwrap_optional_unsafe,
                .unwrap_err_safe,
                .unwrap_err_unsafe,
                .unwrap_err_code,
                .ptr_type,
                .ensure_err_payload_void,
                .enum_literal,
                .merge_error_sets,
                .anyframe_type,
                .error_union_type,
                .bitnot,
                .error_set,
                .slice,
                .slice_start,
                => false,

                .@"break",
                .breakvoid,
                .condbr,
                .compileerror,
                .@"return",
                .returnvoid,
                .unreach_nocheck,
                .@"unreachable",
                .loop,
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
            body: Module.Body,
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
        pub const base_tag = Tag.breakvoid;
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

    pub const CoerceToPtrElem = struct {
        pub const base_tag = Tag.coerce_to_ptr_elem;
        base: Inst,

        positionals: struct {
            ptr: *Inst,
            value: *Inst,
        },
        kw_args: struct {},
    };

    pub const DeclRef = struct {
        pub const base_tag = Tag.declref;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const DeclRefStr = struct {
        pub const base_tag = Tag.declref_str;
        base: Inst,

        positionals: struct {
            name: *Inst,
        },
        kw_args: struct {},
    };

    pub const DeclVal = struct {
        pub const base_tag = Tag.declval;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const DeclValInModule = struct {
        pub const base_tag = Tag.declval_in_module;
        base: Inst,

        positionals: struct {
            decl: *IrModule.Decl,
        },
        kw_args: struct {},
    };

    pub const CoerceResultBlockPtr = struct {
        pub const base_tag = Tag.coerce_result_block_ptr;
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            block: *Block,
        },
        kw_args: struct {},
    };

    pub const CompileError = struct {
        pub const base_tag = Tag.compileerror;
        base: Inst,

        positionals: struct {
            msg: []const u8,
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
            body: Module.Body,
        },
        kw_args: struct {},
    };

    pub const FieldPtr = struct {
        pub const base_tag = Tag.fieldptr;
        base: Inst,

        positionals: struct {
            object_ptr: *Inst,
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
            body: Module.Body,
        },
        kw_args: struct {},
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
        pub const base_tag = Tag.inttype;
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

    pub const ElemPtr = struct {
        pub const base_tag = Tag.elemptr;
        base: Inst,

        positionals: struct {
            array_ptr: *Inst,
            index: *Inst,
        },
        kw_args: struct {},
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;
        base: Inst,

        positionals: struct {
            condition: *Inst,
            then_body: Module.Body,
            else_body: Module.Body,
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
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Module = struct {
    decls: []*Decl,
    arena: std.heap.ArenaAllocator,
    error_msg: ?ErrorMsg = null,
    metadata: std.AutoHashMap(*Inst, MetaData),
    body_metadata: std.AutoHashMap(*Body, BodyMetaData),

    pub const MetaData = struct {
        deaths: ir.Inst.DeathsInt,
        addr: usize,
    };

    pub const BodyMetaData = struct {
        deaths: []*Inst,
    };

    pub const Body = struct {
        instructions: []*Inst,
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
        self.writeToStream(std.heap.page_allocator, std.io.getStdErr().outStream()) catch {};
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
            try stream.print("@{} ", .{decl.name});
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
                    try stream.print("{}=", .{arg_field.name});
                    try self.writeParamToStream(stream, &non_optional);
                    need_comma = true;
                }
            } else {
                if (need_comma) try stream.writeAll(", ");
                try stream.print("{}=", .{arg_field.name});
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
            Module.Body => {
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
                    try stream.print("%{} ", .{my_i});
                    if (inst.cast(Inst.Block)) |block| {
                        const name = try std.fmt.allocPrint(&self.arena.allocator, "label_{}", .{my_i});
                        try self.block_table.put(block, name);
                    } else if (inst.cast(Inst.Loop)) |loop| {
                        const name = try std.fmt.allocPrint(&self.arena.allocator, "loop_{}", .{my_i});
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
            []u8, []const u8 => return std.zig.renderStringLiteral(param, stream),
            BigIntConst, usize => return stream.print("{}", .{param}),
            TypedValue => unreachable, // this is a special case
            *IrModule.Decl => unreachable, // this is a special case
            *Inst.Block => {
                const name = self.block_table.get(param).?;
                return std.zig.renderStringLiteral(name, stream);
            },
            *Inst.Loop => {
                const name = self.loop_table.get(param).?;
                return std.zig.renderStringLiteral(name, stream);
            },
            [][]const u8 => {
                try stream.writeByte('[');
                for (param) |str, i| {
                    if (i != 0) {
                        try stream.writeAll(", ");
                    }
                    try std.zig.renderStringLiteral(str, stream);
                }
                try stream.writeByte(']');
            },
            else => |T| @compileError("unimplemented: rendering parameter of type " ++ @typeName(T)),
        }
    }

    fn writeInstParamToStream(self: *Writer, stream: anytype, inst: *Inst) !void {
        if (self.inst_table.get(inst)) |info| {
            if (info.index) |i| {
                try stream.print("%{}", .{info.index});
            } else {
                try stream.print("@{}", .{info.name});
            }
        } else if (inst.cast(Inst.DeclVal)) |decl_val| {
            try stream.print("@{}", .{decl_val.positionals.name});
        } else if (inst.cast(Inst.DeclValInModule)) |decl_val| {
            try stream.print("@{}", .{decl_val.positionals.decl.name});
        } else {
            // This should be unreachable in theory, but since ZIR is used for debugging the compiler
            // we output some debug text instead.
            try stream.print("?{}?", .{@tagName(inst.tag)});
        }
    }
};

pub fn parse(allocator: *Allocator, source: [:0]const u8) Allocator.Error!Module {
    var global_name_map = std.StringHashMap(*Inst).init(allocator);
    defer global_name_map.deinit();

    var parser: Parser = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .i = 0,
        .source = source,
        .global_name_map = &global_name_map,
        .decls = .{},
        .unnamed_index = 0,
        .block_table = std.StringHashMap(*Inst.Block).init(allocator),
        .loop_table = std.StringHashMap(*Inst.Loop).init(allocator),
    };
    defer parser.block_table.deinit();
    defer parser.loop_table.deinit();
    errdefer parser.arena.deinit();

    parser.parseRoot() catch |err| switch (err) {
        error.ParseFailure => {
            assert(parser.error_msg != null);
        },
        else => |e| return e,
    };

    return Module{
        .decls = parser.decls.toOwnedSlice(allocator),
        .arena = parser.arena,
        .error_msg = parser.error_msg,
        .metadata = std.AutoHashMap(*Inst, Module.MetaData).init(allocator),
        .body_metadata = std.AutoHashMap(*Module.Body, Module.BodyMetaData).init(allocator),
    };
}

const Parser = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    i: usize,
    source: [:0]const u8,
    decls: std.ArrayListUnmanaged(*Decl),
    global_name_map: *std.StringHashMap(*Inst),
    error_msg: ?ErrorMsg = null,
    unnamed_index: usize,
    block_table: std.StringHashMap(*Inst.Block),
    loop_table: std.StringHashMap(*Inst.Loop),

    const Body = struct {
        instructions: std.ArrayList(*Inst),
        name_map: *std.StringHashMap(*Inst),
    };

    fn parseBody(self: *Parser, body_ctx: ?*Body) !Module.Body {
        var name_map = std.StringHashMap(*Inst).init(self.allocator);
        defer name_map.deinit();

        var body_context = Body{
            .instructions = std.ArrayList(*Inst).init(self.allocator),
            .name_map = if (body_ctx) |bctx| bctx.name_map else &name_map,
        };
        defer body_context.instructions.deinit();

        try requireEatBytes(self, "{");
        skipSpace(self);

        while (true) : (self.i += 1) switch (self.source[self.i]) {
            ';' => _ = try skipToAndOver(self, '\n'),
            '%' => {
                self.i += 1;
                const ident = try skipToAndOver(self, ' ');
                skipSpace(self);
                try requireEatBytes(self, "=");
                skipSpace(self);
                const decl = try parseInstruction(self, &body_context, ident);
                const ident_index = body_context.instructions.items.len;
                if (try body_context.name_map.fetchPut(ident, decl.inst)) |_| {
                    return self.fail("redefinition of identifier '{}'", .{ident});
                }
                try body_context.instructions.append(decl.inst);
                continue;
            },
            ' ', '\n' => continue,
            '}' => {
                self.i += 1;
                break;
            },
            else => |byte| return self.failByte(byte),
        };

        // Move the instructions to the arena
        const instrs = try self.arena.allocator.alloc(*Inst, body_context.instructions.items.len);
        mem.copy(*Inst, instrs, body_context.instructions.items);
        return Module.Body{ .instructions = instrs };
    }

    fn parseStringLiteral(self: *Parser) ![]u8 {
        const start = self.i;
        try self.requireEatBytes("\"");

        while (true) : (self.i += 1) switch (self.source[self.i]) {
            '"' => {
                self.i += 1;
                const span = self.source[start..self.i];
                var bad_index: usize = undefined;
                const parsed = std.zig.parseStringLiteral(&self.arena.allocator, span, &bad_index) catch |err| switch (err) {
                    error.InvalidCharacter => {
                        self.i = start + bad_index;
                        const bad_byte = self.source[self.i];
                        return self.fail("invalid string literal character: '{c}'\n", .{bad_byte});
                    },
                    else => |e| return e,
                };
                return parsed;
            },
            '\\' => {
                self.i += 1;
                continue;
            },
            0 => return self.failByte(0),
            else => continue,
        };
    }

    fn parseIntegerLiteral(self: *Parser) !BigIntConst {
        const start = self.i;
        if (self.source[self.i] == '-') self.i += 1;
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            '0'...'9' => continue,
            else => break,
        };
        const number_text = self.source[start..self.i];
        const base = 10;
        // TODO reuse the same array list for this
        const limbs_buffer_len = std.math.big.int.calcSetStringLimbsBufferLen(base, number_text.len);
        const limbs_buffer = try self.allocator.alloc(std.math.big.Limb, limbs_buffer_len);
        defer self.allocator.free(limbs_buffer);
        const limb_len = std.math.big.int.calcSetStringLimbCount(base, number_text.len);
        const limbs = try self.arena.allocator.alloc(std.math.big.Limb, limb_len);
        var result = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result.setString(base, number_text, limbs_buffer, self.allocator) catch |err| switch (err) {
            error.InvalidCharacter => {
                self.i = start;
                return self.fail("invalid digit in integer literal", .{});
            },
        };
        return result.toConst();
    }

    fn parseRoot(self: *Parser) !void {
        // The IR format is designed so that it can be tokenized and parsed at the same time.
        while (true) {
            switch (self.source[self.i]) {
                ';' => _ = try skipToAndOver(self, '\n'),
                '@' => {
                    self.i += 1;
                    const ident = try skipToAndOver(self, ' ');
                    skipSpace(self);
                    try requireEatBytes(self, "=");
                    skipSpace(self);
                    const decl = try parseInstruction(self, null, ident);
                    const ident_index = self.decls.items.len;
                    if (try self.global_name_map.fetchPut(ident, decl.inst)) |_| {
                        return self.fail("redefinition of identifier '{}'", .{ident});
                    }
                    try self.decls.append(self.allocator, decl);
                },
                ' ', '\n' => self.i += 1,
                0 => break,
                else => |byte| return self.fail("unexpected byte: '{c}'", .{byte}),
            }
        }
    }

    fn eatByte(self: *Parser, byte: u8) bool {
        if (self.source[self.i] != byte) return false;
        self.i += 1;
        return true;
    }

    fn skipSpace(self: *Parser) void {
        while (self.source[self.i] == ' ' or self.source[self.i] == '\n') {
            self.i += 1;
        }
    }

    fn requireEatBytes(self: *Parser, bytes: []const u8) !void {
        const start = self.i;
        for (bytes) |byte| {
            if (self.source[self.i] != byte) {
                self.i = start;
                return self.fail("expected '{}'", .{bytes});
            }
            self.i += 1;
        }
    }

    fn skipToAndOver(self: *Parser, byte: u8) ![]const u8 {
        const start_i = self.i;
        while (self.source[self.i] != 0) : (self.i += 1) {
            if (self.source[self.i] == byte) {
                const result = self.source[start_i..self.i];
                self.i += 1;
                return result;
            }
        }
        return self.fail("unexpected EOF", .{});
    }

    /// ParseFailure is an internal error code; handled in `parse`.
    const InnerError = error{ ParseFailure, OutOfMemory };

    fn failByte(self: *Parser, byte: u8) InnerError {
        if (byte == 0) {
            return self.fail("unexpected EOF", .{});
        } else {
            return self.fail("unexpected byte: '{c}'", .{byte});
        }
    }

    fn fail(self: *Parser, comptime format: []const u8, args: anytype) InnerError {
        @setCold(true);
        self.error_msg = ErrorMsg{
            .byte_offset = self.i,
            .msg = try std.fmt.allocPrint(&self.arena.allocator, format, args),
        };
        return error.ParseFailure;
    }

    fn parseInstruction(self: *Parser, body_ctx: ?*Body, name: []const u8) InnerError!*Decl {
        const contents_start = self.i;
        const fn_name = try skipToAndOver(self, '(');
        inline for (@typeInfo(Inst.Tag).Enum.fields) |field| {
            if (mem.eql(u8, field.name, fn_name)) {
                const tag = @field(Inst.Tag, field.name);
                return parseInstructionGeneric(self, field.name, tag.Type(), tag, body_ctx, name, contents_start);
            }
        }
        return self.fail("unknown instruction '{}'", .{fn_name});
    }

    fn parseInstructionGeneric(
        self: *Parser,
        comptime fn_name: []const u8,
        comptime InstType: type,
        tag: Inst.Tag,
        body_ctx: ?*Body,
        inst_name: []const u8,
        contents_start: usize,
    ) InnerError!*Decl {
        const inst_specific = try self.arena.allocator.create(InstType);
        inst_specific.base = .{
            .src = self.i,
            .tag = tag,
        };

        if (InstType == Inst.Block) {
            try self.block_table.put(inst_name, inst_specific);
        } else if (InstType == Inst.Loop) {
            try self.loop_table.put(inst_name, inst_specific);
        }

        if (@hasField(InstType, "ty")) {
            inst_specific.ty = opt_type orelse {
                return self.fail("instruction '" ++ fn_name ++ "' requires type", .{});
            };
        }

        const Positionals = @TypeOf(inst_specific.positionals);
        inline for (@typeInfo(Positionals).Struct.fields) |arg_field| {
            if (self.source[self.i] == ',') {
                self.i += 1;
                skipSpace(self);
            } else if (self.source[self.i] == ')') {
                return self.fail("expected positional parameter '{}'", .{arg_field.name});
            }
            @field(inst_specific.positionals, arg_field.name) = try parseParameterGeneric(
                self,
                arg_field.field_type,
                body_ctx,
            );
            skipSpace(self);
        }

        const KW_Args = @TypeOf(inst_specific.kw_args);
        inst_specific.kw_args = .{}; // assign defaults
        skipSpace(self);
        while (eatByte(self, ',')) {
            skipSpace(self);
            const name = try skipToAndOver(self, '=');
            inline for (@typeInfo(KW_Args).Struct.fields) |arg_field| {
                const field_name = arg_field.name;
                if (mem.eql(u8, name, field_name)) {
                    const NonOptional = switch (@typeInfo(arg_field.field_type)) {
                        .Optional => |info| info.child,
                        else => arg_field.field_type,
                    };
                    @field(inst_specific.kw_args, field_name) = try parseParameterGeneric(self, NonOptional, body_ctx);
                    break;
                }
            } else {
                return self.fail("unrecognized keyword parameter: '{}'", .{name});
            }
            skipSpace(self);
        }
        try requireEatBytes(self, ")");

        const decl = try self.arena.allocator.create(Decl);
        decl.* = .{
            .name = inst_name,
            .contents_hash = std.zig.hashSrc(self.source[contents_start..self.i]),
            .inst = &inst_specific.base,
        };
        //std.debug.warn("parsed {} = '{}'\n", .{ inst_specific.base.name, inst_specific.base.contents });

        return decl;
    }

    fn parseParameterGeneric(self: *Parser, comptime T: type, body_ctx: ?*Body) !T {
        if (@typeInfo(T) == .Enum) {
            const start = self.i;
            while (true) : (self.i += 1) switch (self.source[self.i]) {
                ' ', '\n', ',', ')' => {
                    const enum_name = self.source[start..self.i];
                    return std.meta.stringToEnum(T, enum_name) orelse {
                        return self.fail("tag '{}' not a member of enum '{}'", .{ enum_name, @typeName(T) });
                    };
                },
                0 => return self.failByte(0),
                else => continue,
            };
        }
        switch (T) {
            Module.Body => return parseBody(self, body_ctx),
            bool => {
                const bool_value = switch (self.source[self.i]) {
                    '0' => false,
                    '1' => true,
                    else => |byte| return self.fail("expected '0' or '1' for boolean value, found {c}", .{byte}),
                };
                self.i += 1;
                return bool_value;
            },
            []*Inst => {
                try requireEatBytes(self, "[");
                skipSpace(self);
                if (eatByte(self, ']')) return &[0]*Inst{};

                var instructions = std.ArrayList(*Inst).init(&self.arena.allocator);
                while (true) {
                    skipSpace(self);
                    try instructions.append(try parseParameterInst(self, body_ctx));
                    skipSpace(self);
                    if (!eatByte(self, ',')) break;
                }
                try requireEatBytes(self, "]");
                return instructions.toOwnedSlice();
            },
            *Inst => return parseParameterInst(self, body_ctx),
            []u8, []const u8 => return self.parseStringLiteral(),
            BigIntConst => return self.parseIntegerLiteral(),
            usize => {
                const big_int = try self.parseIntegerLiteral();
                return big_int.to(usize) catch |err| return self.fail("integer literal: {}", .{@errorName(err)});
            },
            TypedValue => return self.fail("'const' is a special instruction; not legal in ZIR text", .{}),
            *IrModule.Decl => return self.fail("'declval_in_module' is a special instruction; not legal in ZIR text", .{}),
            *Inst.Block => {
                const name = try self.parseStringLiteral();
                return self.block_table.get(name).?;
            },
            *Inst.Loop => {
                const name = try self.parseStringLiteral();
                return self.loop_table.get(name).?;
            },
            [][]const u8 => {
                try requireEatBytes(self, "[");
                skipSpace(self);
                if (eatByte(self, ']')) return &[0][]const u8{};

                var strings = std.ArrayList([]const u8).init(&self.arena.allocator);
                while (true) {
                    skipSpace(self);
                    try strings.append(try self.parseStringLiteral());
                    skipSpace(self);
                    if (!eatByte(self, ',')) break;
                }
                try requireEatBytes(self, "]");
                return strings.toOwnedSlice();
            },
            else => @compileError("Unimplemented: ir parseParameterGeneric for type " ++ @typeName(T)),
        }
        return self.fail("TODO parse parameter {}", .{@typeName(T)});
    }

    fn parseParameterInst(self: *Parser, body_ctx: ?*Body) !*Inst {
        const local_ref = switch (self.source[self.i]) {
            '@' => false,
            '%' => true,
            else => |byte| return self.fail("unexpected byte: '{c}'", .{byte}),
        };
        const map = if (local_ref)
            if (body_ctx) |bc|
                bc.name_map
            else
                return self.fail("referencing a % instruction in global scope", .{})
        else
            self.global_name_map;

        self.i += 1;
        const name_start = self.i;
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            0, ' ', '\n', ',', ')', ']' => break,
            else => continue,
        };
        const ident = self.source[name_start..self.i];
        return map.get(ident) orelse {
            const bad_name = self.source[name_start - 1 .. self.i];
            const src = name_start - 1;
            if (local_ref) {
                self.i = src;
                return self.fail("unrecognized identifier: {}", .{bad_name});
            } else {
                const declval = try self.arena.allocator.create(Inst.DeclVal);
                declval.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.DeclVal.base_tag,
                    },
                    .positionals = .{ .name = ident },
                    .kw_args = .{},
                };
                return &declval.base;
            }
        };
    }

    fn generateName(self: *Parser) ![]u8 {
        const result = try std.fmt.allocPrint(&self.arena.allocator, "unnamed${}", .{self.unnamed_index});
        self.unnamed_index += 1;
        return result;
    }
};

pub fn emit(allocator: *Allocator, old_module: IrModule) !Module {
    var ctx: EmitZIR = .{
        .allocator = allocator,
        .decls = .{},
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .next_auto_name = 0,
        .names = std.StringArrayHashMap(void).init(allocator),
        .primitive_table = std.AutoHashMap(Inst.Primitive.Builtin, *Decl).init(allocator),
        .indent = 0,
        .block_table = std.AutoHashMap(*ir.Inst.Block, *Inst.Block).init(allocator),
        .loop_table = std.AutoHashMap(*ir.Inst.Loop, *Inst.Loop).init(allocator),
        .metadata = std.AutoHashMap(*Inst, Module.MetaData).init(allocator),
        .body_metadata = std.AutoHashMap(*Module.Body, Module.BodyMetaData).init(allocator),
    };
    errdefer ctx.metadata.deinit();
    errdefer ctx.body_metadata.deinit();
    defer ctx.block_table.deinit();
    defer ctx.loop_table.deinit();
    defer ctx.decls.deinit(allocator);
    defer ctx.names.deinit();
    defer ctx.primitive_table.deinit();
    errdefer ctx.arena.deinit();

    try ctx.emit();

    return Module{
        .decls = ctx.decls.toOwnedSlice(allocator),
        .arena = ctx.arena,
        .metadata = ctx.metadata,
        .body_metadata = ctx.body_metadata,
    };
}

/// For debugging purposes, prints a function representation to stderr.
pub fn dumpFn(old_module: IrModule, module_fn: *IrModule.Fn) void {
    const allocator = old_module.gpa;
    var ctx: EmitZIR = .{
        .allocator = allocator,
        .decls = .{},
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .next_auto_name = 0,
        .names = std.StringHashMap(void).init(allocator),
        .primitive_table = std.AutoHashMap(Inst.Primitive.Builtin, *Decl).init(allocator),
        .indent = 0,
        .block_table = std.AutoHashMap(*ir.Inst.Block, *Inst.Block).init(allocator),
        .loop_table = std.AutoHashMap(*ir.Inst.Loop, *Inst.Loop).init(allocator),
        .metadata = std.AutoHashMap(*Inst, Module.MetaData).init(allocator),
        .body_metadata = std.AutoHashMap(*Module.Body, Module.BodyMetaData).init(allocator),
    };
    defer ctx.metadata.deinit();
    defer ctx.body_metadata.deinit();
    defer ctx.block_table.deinit();
    defer ctx.loop_table.deinit();
    defer ctx.decls.deinit(allocator);
    defer ctx.names.deinit();
    defer ctx.primitive_table.deinit();
    defer ctx.arena.deinit();

    const fn_ty = module_fn.owner_decl.typed_value.most_recent.typed_value.ty;
    _ = ctx.emitFn(module_fn, 0, fn_ty) catch |err| {
        std.debug.print("unable to dump function: {}\n", .{err});
        return;
    };
    var module = Module{
        .decls = ctx.decls.items,
        .arena = ctx.arena,
        .metadata = ctx.metadata,
        .body_metadata = ctx.body_metadata,
    };

    module.dump();
}

const EmitZIR = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const IrModule,
    decls: std.ArrayListUnmanaged(*Decl),
    names: std.StringArrayHashMap(void),
    next_auto_name: usize,
    primitive_table: std.AutoHashMap(Inst.Primitive.Builtin, *Decl),
    indent: usize,
    block_table: std.AutoHashMap(*ir.Inst.Block, *Inst.Block),
    loop_table: std.AutoHashMap(*ir.Inst.Loop, *Inst.Loop),
    metadata: std.AutoHashMap(*Inst, Module.MetaData),
    body_metadata: std.AutoHashMap(*Module.Body, Module.BodyMetaData),

    fn emit(self: *EmitZIR) !void {
        // Put all the Decls in a list and sort them by name to avoid nondeterminism introduced
        // by the hash table.
        var src_decls = std.ArrayList(*IrModule.Decl).init(self.allocator);
        defer src_decls.deinit();
        try src_decls.ensureCapacity(self.old_module.decl_table.items().len);
        try self.decls.ensureCapacity(self.allocator, self.old_module.decl_table.items().len);
        try self.names.ensureCapacity(self.old_module.decl_table.items().len);

        for (self.old_module.decl_table.items()) |entry| {
            const decl = entry.value;
            src_decls.appendAssumeCapacity(decl);
            self.names.putAssumeCapacityNoClobber(mem.spanZ(decl.name), {});
        }
        std.sort.sort(*IrModule.Decl, src_decls.items, {}, (struct {
            fn lessThan(context: void, a: *IrModule.Decl, b: *IrModule.Decl) bool {
                return a.src_index < b.src_index;
            }
        }).lessThan);

        // Emit all the decls.
        for (src_decls.items) |ir_decl| {
            switch (ir_decl.analysis) {
                .unreferenced => continue,

                .complete => {},
                .codegen_failure => {}, // We still can emit the ZIR.
                .codegen_failure_retryable => {}, // We still can emit the ZIR.

                .in_progress => unreachable,
                .outdated => unreachable,

                .sema_failure,
                .sema_failure_retryable,
                .dependency_failure,
                => if (self.old_module.failed_decls.get(ir_decl)) |err_msg| {
                    const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                    fail_inst.* = .{
                        .base = .{
                            .src = ir_decl.src(),
                            .tag = Inst.CompileError.base_tag,
                        },
                        .positionals = .{
                            .msg = try self.arena.allocator.dupe(u8, err_msg.msg),
                        },
                        .kw_args = .{},
                    };
                    const decl = try self.arena.allocator.create(Decl);
                    decl.* = .{
                        .name = mem.spanZ(ir_decl.name),
                        .contents_hash = undefined,
                        .inst = &fail_inst.base,
                    };
                    try self.decls.append(self.allocator, decl);
                    continue;
                },
            }
            if (self.old_module.export_owners.get(ir_decl)) |exports| {
                for (exports) |module_export| {
                    const symbol_name = try self.emitStringLiteral(module_export.src, module_export.options.name);
                    const export_inst = try self.arena.allocator.create(Inst.Export);
                    export_inst.* = .{
                        .base = .{
                            .src = module_export.src,
                            .tag = Inst.Export.base_tag,
                        },
                        .positionals = .{
                            .symbol_name = symbol_name.inst,
                            .decl_name = mem.spanZ(module_export.exported_decl.name),
                        },
                        .kw_args = .{},
                    };
                    _ = try self.emitUnnamedDecl(&export_inst.base);
                }
            } else {
                const new_decl = try self.emitTypedValue(ir_decl.src(), ir_decl.typed_value.most_recent.typed_value);
                new_decl.name = try self.arena.allocator.dupe(u8, mem.spanZ(ir_decl.name));
            }
        }
    }

    const ZirBody = struct {
        inst_table: *std.AutoHashMap(*ir.Inst, *Inst),
        instructions: *std.ArrayList(*Inst),
    };

    fn resolveInst(self: *EmitZIR, new_body: ZirBody, inst: *ir.Inst) !*Inst {
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            const new_inst = if (const_inst.val.cast(Value.Payload.Function)) |func_pl| blk: {
                const owner_decl = func_pl.func.owner_decl;
                break :blk try self.emitDeclVal(inst.src, mem.spanZ(owner_decl.name));
            } else if (const_inst.val.cast(Value.Payload.DeclRef)) |declref| blk: {
                const decl_ref = try self.emitDeclRef(inst.src, declref.decl);
                try new_body.instructions.append(decl_ref);
                break :blk decl_ref;
            } else if (const_inst.val.cast(Value.Payload.Variable)) |var_pl| blk: {
                const owner_decl = var_pl.variable.owner_decl;
                break :blk try self.emitDeclVal(inst.src, mem.spanZ(owner_decl.name));
            } else blk: {
                break :blk (try self.emitTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val })).inst;
            };
            _ = try new_body.inst_table.put(inst, new_inst);
            return new_inst;
        } else {
            return new_body.inst_table.get(inst).?;
        }
    }

    fn emitDeclVal(self: *EmitZIR, src: usize, decl_name: []const u8) !*Inst {
        const declval = try self.arena.allocator.create(Inst.DeclVal);
        declval.* = .{
            .base = .{
                .src = src,
                .tag = Inst.DeclVal.base_tag,
            },
            .positionals = .{ .name = try self.arena.allocator.dupe(u8, decl_name) },
            .kw_args = .{},
        };
        return &declval.base;
    }

    fn emitComptimeIntVal(self: *EmitZIR, src: usize, val: Value) !*Decl {
        const big_int_space = try self.arena.allocator.create(Value.BigIntSpace);
        const int_inst = try self.arena.allocator.create(Inst.Int);
        int_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.Int.base_tag,
            },
            .positionals = .{
                .int = val.toBigInt(big_int_space),
            },
            .kw_args = .{},
        };
        return self.emitUnnamedDecl(&int_inst.base);
    }

    fn emitDeclRef(self: *EmitZIR, src: usize, module_decl: *IrModule.Decl) !*Inst {
        const declref_inst = try self.arena.allocator.create(Inst.DeclRef);
        declref_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.DeclRef.base_tag,
            },
            .positionals = .{
                .name = mem.spanZ(module_decl.name),
            },
            .kw_args = .{},
        };
        return &declref_inst.base;
    }

    fn emitFn(self: *EmitZIR, module_fn: *IrModule.Fn, src: usize, ty: Type) Allocator.Error!*Decl {
        var inst_table = std.AutoHashMap(*ir.Inst, *Inst).init(self.allocator);
        defer inst_table.deinit();

        var instructions = std.ArrayList(*Inst).init(self.allocator);
        defer instructions.deinit();

        switch (module_fn.analysis) {
            .queued => unreachable,
            .in_progress => unreachable,
            .success => |body| {
                try self.emitBody(body, &inst_table, &instructions);
            },
            .sema_failure => {
                const err_msg = self.old_module.failed_decls.get(module_fn.owner_decl).?;
                const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                fail_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.CompileError.base_tag,
                    },
                    .positionals = .{
                        .msg = try self.arena.allocator.dupe(u8, err_msg.msg),
                    },
                    .kw_args = .{},
                };
                try instructions.append(&fail_inst.base);
            },
            .dependency_failure => {
                const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                fail_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.CompileError.base_tag,
                    },
                    .positionals = .{
                        .msg = try self.arena.allocator.dupe(u8, "depends on another failed Decl"),
                    },
                    .kw_args = .{},
                };
                try instructions.append(&fail_inst.base);
            },
        }

        const fn_type = try self.emitType(src, ty);

        const arena_instrs = try self.arena.allocator.alloc(*Inst, instructions.items.len);
        mem.copy(*Inst, arena_instrs, instructions.items);

        const fn_inst = try self.arena.allocator.create(Inst.Fn);
        fn_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.Fn.base_tag,
            },
            .positionals = .{
                .fn_type = fn_type.inst,
                .body = .{ .instructions = arena_instrs },
            },
            .kw_args = .{},
        };
        return self.emitUnnamedDecl(&fn_inst.base);
    }

    fn emitTypedValue(self: *EmitZIR, src: usize, typed_value: TypedValue) Allocator.Error!*Decl {
        const allocator = &self.arena.allocator;
        if (typed_value.val.cast(Value.Payload.DeclRef)) |decl_ref| {
            const decl = decl_ref.decl;
            return try self.emitUnnamedDecl(try self.emitDeclRef(src, decl));
        } else if (typed_value.val.cast(Value.Payload.Variable)) |variable| {
            return self.emitTypedValue(src, .{
                .ty = typed_value.ty,
                .val = variable.variable.init,
            });
        }
        if (typed_value.val.isUndef()) {
            const as_inst = try self.arena.allocator.create(Inst.BinOp);
            as_inst.* = .{
                .base = .{
                    .tag = .as,
                    .src = src,
                },
                .positionals = .{
                    .lhs = (try self.emitType(src, typed_value.ty)).inst,
                    .rhs = (try self.emitPrimitive(src, .@"undefined")).inst,
                },
                .kw_args = .{},
            };
            return self.emitUnnamedDecl(&as_inst.base);
        }
        switch (typed_value.ty.zigTypeTag()) {
            .Pointer => {
                const ptr_elem_type = typed_value.ty.elemType();
                switch (ptr_elem_type.zigTypeTag()) {
                    .Array => {
                        // TODO more checks to make sure this can be emitted as a string literal
                        //const array_elem_type = ptr_elem_type.elemType();
                        //if (array_elem_type.eql(Type.initTag(.u8)) and
                        //    ptr_elem_type.hasSentinel(Value.initTag(.zero)))
                        //{
                        //}
                        const bytes = typed_value.val.toAllocatedBytes(allocator) catch |err| switch (err) {
                            error.AnalysisFail => unreachable,
                            else => |e| return e,
                        };
                        return self.emitStringLiteral(src, bytes);
                    },
                    else => |t| std.debug.panic("TODO implement emitTypedValue for pointer to {}", .{@tagName(t)}),
                }
            },
            .ComptimeInt => return self.emitComptimeIntVal(src, typed_value.val),
            .Int => {
                const as_inst = try self.arena.allocator.create(Inst.BinOp);
                as_inst.* = .{
                    .base = .{
                        .tag = .as,
                        .src = src,
                    },
                    .positionals = .{
                        .lhs = (try self.emitType(src, typed_value.ty)).inst,
                        .rhs = (try self.emitComptimeIntVal(src, typed_value.val)).inst,
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&as_inst.base);
            },
            .Type => {
                const ty = try typed_value.val.toType(&self.arena.allocator);
                return self.emitType(src, ty);
            },
            .Fn => {
                const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;
                return self.emitFn(module_fn, src, typed_value.ty);
            },
            .Array => {
                // TODO more checks to make sure this can be emitted as a string literal
                //const array_elem_type = ptr_elem_type.elemType();
                //if (array_elem_type.eql(Type.initTag(.u8)) and
                //    ptr_elem_type.hasSentinel(Value.initTag(.zero)))
                //{
                //}
                const bytes = typed_value.val.toAllocatedBytes(allocator) catch |err| switch (err) {
                    error.AnalysisFail => unreachable,
                    else => |e| return e,
                };
                const str_inst = try self.arena.allocator.create(Inst.Str);
                str_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.Str.base_tag,
                    },
                    .positionals = .{
                        .bytes = bytes,
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&str_inst.base);
            },
            .Void => return self.emitPrimitive(src, .void_value),
            .Bool => if (typed_value.val.toBool())
                return self.emitPrimitive(src, .@"true")
            else
                return self.emitPrimitive(src, .@"false"),
            .EnumLiteral => {
                const enum_literal = @fieldParentPtr(Value.Payload.Bytes, "base", typed_value.val.ptr_otherwise);
                const inst = try self.arena.allocator.create(Inst.Str);
                inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = .enum_literal,
                    },
                    .positionals = .{
                        .bytes = enum_literal.data,
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&inst.base);
            },
            else => |t| std.debug.panic("TODO implement emitTypedValue for {}", .{@tagName(t)}),
        }
    }

    fn emitNoOp(self: *EmitZIR, src: usize, old_inst: *ir.Inst.NoOp, tag: Inst.Tag) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.NoOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{},
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitUnOp(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.UnOp,
        tag: Inst.Tag,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.UnOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{
                .operand = try self.resolveInst(new_body, old_inst.operand),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitBinOp(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.BinOp,
        tag: Inst.Tag,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.BinOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{
                .lhs = try self.resolveInst(new_body, old_inst.lhs),
                .rhs = try self.resolveInst(new_body, old_inst.rhs),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitCast(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.UnOp,
        tag: Inst.Tag,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.BinOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{
                .lhs = (try self.emitType(old_inst.base.src, old_inst.base.ty)).inst,
                .rhs = try self.resolveInst(new_body, old_inst.operand),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitBody(
        self: *EmitZIR,
        body: ir.Body,
        inst_table: *std.AutoHashMap(*ir.Inst, *Inst),
        instructions: *std.ArrayList(*Inst),
    ) Allocator.Error!void {
        const new_body = ZirBody{
            .inst_table = inst_table,
            .instructions = instructions,
        };
        for (body.instructions) |inst| {
            const new_inst = switch (inst.tag) {
                .constant => unreachable, // excluded from function bodies

                .breakpoint => try self.emitNoOp(inst.src, inst.castTag(.breakpoint).?, .breakpoint),
                .unreach => try self.emitNoOp(inst.src, inst.castTag(.unreach).?, .unreach_nocheck),
                .retvoid => try self.emitNoOp(inst.src, inst.castTag(.retvoid).?, .returnvoid),
                .dbg_stmt => try self.emitNoOp(inst.src, inst.castTag(.dbg_stmt).?, .dbg_stmt),

                .not => try self.emitUnOp(inst.src, new_body, inst.castTag(.not).?, .boolnot),
                .ret => try self.emitUnOp(inst.src, new_body, inst.castTag(.ret).?, .@"return"),
                .ptrtoint => try self.emitUnOp(inst.src, new_body, inst.castTag(.ptrtoint).?, .ptrtoint),
                .isnull => try self.emitUnOp(inst.src, new_body, inst.castTag(.isnull).?, .isnull),
                .isnonnull => try self.emitUnOp(inst.src, new_body, inst.castTag(.isnonnull).?, .isnonnull),
                .iserr => try self.emitUnOp(inst.src, new_body, inst.castTag(.iserr).?, .iserr),
                .load => try self.emitUnOp(inst.src, new_body, inst.castTag(.load).?, .deref),
                .ref => try self.emitUnOp(inst.src, new_body, inst.castTag(.ref).?, .ref),
                .unwrap_optional => try self.emitUnOp(inst.src, new_body, inst.castTag(.unwrap_optional).?, .unwrap_optional_unsafe),
                .wrap_optional => try self.emitCast(inst.src, new_body, inst.castTag(.wrap_optional).?, .as),

                .add => try self.emitBinOp(inst.src, new_body, inst.castTag(.add).?, .add),
                .sub => try self.emitBinOp(inst.src, new_body, inst.castTag(.sub).?, .sub),
                .store => try self.emitBinOp(inst.src, new_body, inst.castTag(.store).?, .store),
                .cmp_lt => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_lt).?, .cmp_lt),
                .cmp_lte => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_lte).?, .cmp_lte),
                .cmp_eq => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_eq).?, .cmp_eq),
                .cmp_gte => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_gte).?, .cmp_gte),
                .cmp_gt => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_gt).?, .cmp_gt),
                .cmp_neq => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_neq).?, .cmp_neq),

                .bitcast => try self.emitCast(inst.src, new_body, inst.castTag(.bitcast).?, .bitcast),
                .intcast => try self.emitCast(inst.src, new_body, inst.castTag(.intcast).?, .intcast),
                .floatcast => try self.emitCast(inst.src, new_body, inst.castTag(.floatcast).?, .floatcast),

                .alloc => blk: {
                    const new_inst = try self.arena.allocator.create(Inst.UnOp);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = .alloc,
                        },
                        .positionals = .{
                            .operand = (try self.emitType(inst.src, inst.ty)).inst,
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .arg => blk: {
                    const old_inst = inst.castTag(.arg).?;
                    const new_inst = try self.arena.allocator.create(Inst.Arg);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = .arg,
                        },
                        .positionals = .{
                            .name = try self.arena.allocator.dupe(u8, mem.spanZ(old_inst.name)),
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .block => blk: {
                    const old_inst = inst.castTag(.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.Block);

                    try self.block_table.put(old_inst, new_inst);

                    var block_body = std.ArrayList(*Inst).init(self.allocator);
                    defer block_body.deinit();

                    try self.emitBody(old_inst.body, inst_table, &block_body);

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Block.base_tag,
                        },
                        .positionals = .{
                            .body = .{ .instructions = block_body.toOwnedSlice() },
                        },
                        .kw_args = .{},
                    };

                    break :blk &new_inst.base;
                },

                .loop => blk: {
                    const old_inst = inst.castTag(.loop).?;
                    const new_inst = try self.arena.allocator.create(Inst.Loop);

                    try self.loop_table.put(old_inst, new_inst);

                    var loop_body = std.ArrayList(*Inst).init(self.allocator);
                    defer loop_body.deinit();

                    try self.emitBody(old_inst.body, inst_table, &loop_body);

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Loop.base_tag,
                        },
                        .positionals = .{
                            .body = .{ .instructions = loop_body.toOwnedSlice() },
                        },
                        .kw_args = .{},
                    };

                    break :blk &new_inst.base;
                },

                .brvoid => blk: {
                    const old_inst = inst.cast(ir.Inst.BrVoid).?;
                    const new_block = self.block_table.get(old_inst.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.BreakVoid);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.BreakVoid.base_tag,
                        },
                        .positionals = .{
                            .block = new_block,
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .br => blk: {
                    const old_inst = inst.castTag(.br).?;
                    const new_block = self.block_table.get(old_inst.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.Break);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Break.base_tag,
                        },
                        .positionals = .{
                            .block = new_block,
                            .operand = try self.resolveInst(new_body, old_inst.operand),
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .call => blk: {
                    const old_inst = inst.castTag(.call).?;
                    const new_inst = try self.arena.allocator.create(Inst.Call);

                    const args = try self.arena.allocator.alloc(*Inst, old_inst.args.len);
                    for (args) |*elem, i| {
                        elem.* = try self.resolveInst(new_body, old_inst.args[i]);
                    }
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Call.base_tag,
                        },
                        .positionals = .{
                            .func = try self.resolveInst(new_body, old_inst.func),
                            .args = args,
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .assembly => blk: {
                    const old_inst = inst.castTag(.assembly).?;
                    const new_inst = try self.arena.allocator.create(Inst.Asm);

                    const inputs = try self.arena.allocator.alloc(*Inst, old_inst.inputs.len);
                    for (inputs) |*elem, i| {
                        elem.* = (try self.emitStringLiteral(inst.src, old_inst.inputs[i])).inst;
                    }

                    const clobbers = try self.arena.allocator.alloc(*Inst, old_inst.clobbers.len);
                    for (clobbers) |*elem, i| {
                        elem.* = (try self.emitStringLiteral(inst.src, old_inst.clobbers[i])).inst;
                    }

                    const args = try self.arena.allocator.alloc(*Inst, old_inst.args.len);
                    for (args) |*elem, i| {
                        elem.* = try self.resolveInst(new_body, old_inst.args[i]);
                    }

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Asm.base_tag,
                        },
                        .positionals = .{
                            .asm_source = (try self.emitStringLiteral(inst.src, old_inst.asm_source)).inst,
                            .return_type = (try self.emitType(inst.src, inst.ty)).inst,
                        },
                        .kw_args = .{
                            .@"volatile" = old_inst.is_volatile,
                            .output = if (old_inst.output) |o|
                                (try self.emitStringLiteral(inst.src, o)).inst
                            else
                                null,
                            .inputs = inputs,
                            .clobbers = clobbers,
                            .args = args,
                        },
                    };
                    break :blk &new_inst.base;
                },

                .condbr => blk: {
                    const old_inst = inst.castTag(.condbr).?;

                    var then_body = std.ArrayList(*Inst).init(self.allocator);
                    var else_body = std.ArrayList(*Inst).init(self.allocator);

                    defer then_body.deinit();
                    defer else_body.deinit();

                    const then_deaths = try self.arena.allocator.alloc(*Inst, old_inst.thenDeaths().len);
                    const else_deaths = try self.arena.allocator.alloc(*Inst, old_inst.elseDeaths().len);

                    for (old_inst.thenDeaths()) |death, i| {
                        then_deaths[i] = try self.resolveInst(new_body, death);
                    }
                    for (old_inst.elseDeaths()) |death, i| {
                        else_deaths[i] = try self.resolveInst(new_body, death);
                    }

                    try self.emitBody(old_inst.then_body, inst_table, &then_body);
                    try self.emitBody(old_inst.else_body, inst_table, &else_body);

                    const new_inst = try self.arena.allocator.create(Inst.CondBr);

                    try self.body_metadata.put(&new_inst.positionals.then_body, .{ .deaths = then_deaths });
                    try self.body_metadata.put(&new_inst.positionals.else_body, .{ .deaths = else_deaths });

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.CondBr.base_tag,
                        },
                        .positionals = .{
                            .condition = try self.resolveInst(new_body, old_inst.condition),
                            .then_body = .{ .instructions = then_body.toOwnedSlice() },
                            .else_body = .{ .instructions = else_body.toOwnedSlice() },
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .varptr => @panic("TODO"),
            };
            try self.metadata.put(new_inst, .{
                .deaths = inst.deaths,
                .addr = @ptrToInt(inst),
            });
            try instructions.append(new_inst);
            try inst_table.put(inst, new_inst);
        }
    }

    fn emitType(self: *EmitZIR, src: usize, ty: Type) Allocator.Error!*Decl {
        switch (ty.tag()) {
            .i8 => return self.emitPrimitive(src, .i8),
            .u8 => return self.emitPrimitive(src, .u8),
            .i16 => return self.emitPrimitive(src, .i16),
            .u16 => return self.emitPrimitive(src, .u16),
            .i32 => return self.emitPrimitive(src, .i32),
            .u32 => return self.emitPrimitive(src, .u32),
            .i64 => return self.emitPrimitive(src, .i64),
            .u64 => return self.emitPrimitive(src, .u64),
            .isize => return self.emitPrimitive(src, .isize),
            .usize => return self.emitPrimitive(src, .usize),
            .c_short => return self.emitPrimitive(src, .c_short),
            .c_ushort => return self.emitPrimitive(src, .c_ushort),
            .c_int => return self.emitPrimitive(src, .c_int),
            .c_uint => return self.emitPrimitive(src, .c_uint),
            .c_long => return self.emitPrimitive(src, .c_long),
            .c_ulong => return self.emitPrimitive(src, .c_ulong),
            .c_longlong => return self.emitPrimitive(src, .c_longlong),
            .c_ulonglong => return self.emitPrimitive(src, .c_ulonglong),
            .c_longdouble => return self.emitPrimitive(src, .c_longdouble),
            .c_void => return self.emitPrimitive(src, .c_void),
            .f16 => return self.emitPrimitive(src, .f16),
            .f32 => return self.emitPrimitive(src, .f32),
            .f64 => return self.emitPrimitive(src, .f64),
            .f128 => return self.emitPrimitive(src, .f128),
            .anyerror => return self.emitPrimitive(src, .anyerror),
            else => switch (ty.zigTypeTag()) {
                .Bool => return self.emitPrimitive(src, .bool),
                .Void => return self.emitPrimitive(src, .void),
                .NoReturn => return self.emitPrimitive(src, .noreturn),
                .Type => return self.emitPrimitive(src, .type),
                .ComptimeInt => return self.emitPrimitive(src, .comptime_int),
                .ComptimeFloat => return self.emitPrimitive(src, .comptime_float),
                .Fn => {
                    const param_types = try self.allocator.alloc(Type, ty.fnParamLen());
                    defer self.allocator.free(param_types);

                    ty.fnParamTypes(param_types);
                    const emitted_params = try self.arena.allocator.alloc(*Inst, param_types.len);
                    for (param_types) |param_type, i| {
                        emitted_params[i] = (try self.emitType(src, param_type)).inst;
                    }

                    const fntype_inst = try self.arena.allocator.create(Inst.FnType);
                    fntype_inst.* = .{
                        .base = .{
                            .src = src,
                            .tag = Inst.FnType.base_tag,
                        },
                        .positionals = .{
                            .param_types = emitted_params,
                            .return_type = (try self.emitType(src, ty.fnReturnType())).inst,
                        },
                        .kw_args = .{
                            .cc = ty.fnCallingConvention(),
                        },
                    };
                    return self.emitUnnamedDecl(&fntype_inst.base);
                },
                .Int => {
                    const info = ty.intInfo(self.old_module.target());
                    const signed = try self.emitPrimitive(src, if (info.signed) .@"true" else .@"false");
                    const bits_payload = try self.arena.allocator.create(Value.Payload.Int_u64);
                    bits_payload.* = .{ .int = info.bits };
                    const bits = try self.emitComptimeIntVal(src, Value.initPayload(&bits_payload.base));
                    const inttype_inst = try self.arena.allocator.create(Inst.IntType);
                    inttype_inst.* = .{
                        .base = .{
                            .src = src,
                            .tag = Inst.IntType.base_tag,
                        },
                        .positionals = .{
                            .signed = signed.inst,
                            .bits = bits.inst,
                        },
                        .kw_args = .{},
                    };
                    return self.emitUnnamedDecl(&inttype_inst.base);
                },
                .Pointer => {
                    if (ty.isSinglePointer()) {
                        const inst = try self.arena.allocator.create(Inst.UnOp);
                        const tag: Inst.Tag = if (ty.isConstPtr()) .single_const_ptr_type else .single_mut_ptr_type;
                        inst.* = .{
                            .base = .{
                                .src = src,
                                .tag = tag,
                            },
                            .positionals = .{
                                .operand = (try self.emitType(src, ty.elemType())).inst,
                            },
                            .kw_args = .{},
                        };
                        return self.emitUnnamedDecl(&inst.base);
                    } else {
                        std.debug.panic("TODO implement emitType for {}", .{ty});
                    }
                },
                .Optional => {
                    var buf: Type.Payload.PointerSimple = undefined;
                    const inst = try self.arena.allocator.create(Inst.UnOp);
                    inst.* = .{
                        .base = .{
                            .src = src,
                            .tag = .optional_type,
                        },
                        .positionals = .{
                            .operand = (try self.emitType(src, ty.optionalChild(&buf))).inst,
                        },
                        .kw_args = .{},
                    };
                    return self.emitUnnamedDecl(&inst.base);
                },
                .Array => {
                    var len_pl = Value.Payload.Int_u64{ .int = ty.arrayLen() };
                    const len = Value.initPayload(&len_pl.base);

                    const inst = if (ty.sentinel()) |sentinel| blk: {
                        const inst = try self.arena.allocator.create(Inst.ArrayTypeSentinel);
                        inst.* = .{
                            .base = .{
                                .src = src,
                                .tag = .array_type,
                            },
                            .positionals = .{
                                .len = (try self.emitTypedValue(src, .{
                                    .ty = Type.initTag(.usize),
                                    .val = len,
                                })).inst,
                                .sentinel = (try self.emitTypedValue(src, .{
                                    .ty = ty.elemType(),
                                    .val = sentinel,
                                })).inst,
                                .elem_type = (try self.emitType(src, ty.elemType())).inst,
                            },
                            .kw_args = .{},
                        };
                        break :blk &inst.base;
                    } else blk: {
                        const inst = try self.arena.allocator.create(Inst.BinOp);
                        inst.* = .{
                            .base = .{
                                .src = src,
                                .tag = .array_type,
                            },
                            .positionals = .{
                                .lhs = (try self.emitTypedValue(src, .{
                                    .ty = Type.initTag(.usize),
                                    .val = len,
                                })).inst,
                                .rhs = (try self.emitType(src, ty.elemType())).inst,
                            },
                            .kw_args = .{},
                        };
                        break :blk &inst.base;
                    };
                    return self.emitUnnamedDecl(inst);
                },
                else => std.debug.panic("TODO implement emitType for {}", .{ty}),
            },
        }
    }

    fn autoName(self: *EmitZIR) ![]u8 {
        while (true) {
            const proposed_name = try std.fmt.allocPrint(&self.arena.allocator, "unnamed${}", .{self.next_auto_name});
            self.next_auto_name += 1;
            const gop = try self.names.getOrPut(proposed_name);
            if (!gop.found_existing) {
                gop.entry.value = {};
                return proposed_name;
            }
        }
    }

    fn emitPrimitive(self: *EmitZIR, src: usize, tag: Inst.Primitive.Builtin) !*Decl {
        const gop = try self.primitive_table.getOrPut(tag);
        if (!gop.found_existing) {
            const primitive_inst = try self.arena.allocator.create(Inst.Primitive);
            primitive_inst.* = .{
                .base = .{
                    .src = src,
                    .tag = Inst.Primitive.base_tag,
                },
                .positionals = .{
                    .tag = tag,
                },
                .kw_args = .{},
            };
            gop.entry.value = try self.emitUnnamedDecl(&primitive_inst.base);
        }
        return gop.entry.value;
    }

    fn emitStringLiteral(self: *EmitZIR, src: usize, str: []const u8) !*Decl {
        const str_inst = try self.arena.allocator.create(Inst.Str);
        str_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.Str.base_tag,
            },
            .positionals = .{
                .bytes = str,
            },
            .kw_args = .{},
        };
        return self.emitUnnamedDecl(&str_inst.base);
    }

    fn emitUnnamedDecl(self: *EmitZIR, inst: *Inst) !*Decl {
        const decl = try self.arena.allocator.create(Decl);
        decl.* = .{
            .name = try self.autoName(),
            .contents_hash = undefined,
            .inst = inst,
        };
        try self.decls.append(self.allocator, decl);
        return decl;
    }
};
