//! Zig Intermediate Representation. astgen.zig converts AST nodes to these
//! untyped IR instructions. Next, Sema.zig processes these into TZIR.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const ast = std.zig.ast;

const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const ir = @import("ir.zig");
const Module = @import("Module.zig");
const LazySrcLoc = Module.LazySrcLoc;

/// The minimum amount of information needed to represent a list of ZIR instructions.
/// Once this structure is completed, it can be used to generate TZIR, followed by
/// machine code, without any memory access into the AST tree token list, node list,
/// or source bytes. Exceptions include:
///  * Compile errors, which may need to reach into these data structures to
///    create a useful report.
///  * In the future, possibly inline assembly, which needs to get parsed and
///    handled by the codegen backend, and errors reported there. However for now,
///    inline assembly is not an exception.
pub const Code = struct {
    instructions: std.MultiArrayList(Inst).Slice,
    /// In order to store references to strings in fewer bytes, we copy all
    /// string bytes into here. String bytes can be null. It is up to whomever
    /// is referencing the data here whether they want to store both index and length,
    /// thus allowing null bytes, or store only index, and use null-termination. The
    /// `string_bytes` array is agnostic to either usage.
    string_bytes: []u8,
    /// The meaning of this data is determined by `Inst.Tag` value.
    extra: []u32,
    /// First ZIR instruction in this `Code`.
    /// `extra` at this index contains a `Ref` for every root member.
    root_start: u32,
    /// Number of ZIR instructions in the implicit root block of the `Code`.
    root_len: u32,

    /// Returns the requested data, as well as the new index which is at the start of the
    /// trailers for the object.
    pub fn extraData(code: Code, comptime T: type, index: usize) struct { data: T, end: usize } {
        const fields = std.meta.fields(T);
        var i: usize = index;
        var result: T = undefined;
        inline for (fields) |field| {
            comptime assert(field.field_type == u32);
            @field(result, field.name) = code.extra[i];
            i += 1;
        }
        return .{
            .data = result,
            .end = i,
        };
    }

    /// Given an index into `string_bytes` returns the null-terminated string found there.
    pub fn nullTerminatedString(code: Code, index: usize) [:0]const u8 {
        var end: usize = index;
        while (code.string_bytes[end] != 0) {
            end += 1;
        }
        return code.string_bytes[index..end :0];
    }

    pub fn deinit(code: *Code, gpa: *Allocator) void {
        code.instructions.deinit(gpa);
        gpa.free(code.string_bytes);
        gpa.free(code.extra);
        code.* = undefined;
    }

    /// For debugging purposes, like dumpFn but for unanalyzed zir blocks
    pub fn dump(
        code: Code,
        gpa: *Allocator,
        kind: []const u8,
        scope: *Module.Scope,
        param_count: usize,
    ) !void {
        var arena = std.heap.ArenaAllocator.init(gpa);
        defer arena.deinit();

        var writer: Writer = .{
            .gpa = gpa,
            .arena = &arena.allocator,
            .scope = scope,
            .code = code,
            .indent = 2,
            .param_count = param_count,
        };

        const decl_name = scope.srcDecl().?.name;
        const stderr = std.io.getStdErr().writer();
        try stderr.print("ZIR {s} {s} {{\n", .{ kind, decl_name });

        const root_body = code.extra[code.root_start..][0..code.root_len];
        try writer.writeBody(stderr, root_body);

        try stderr.print("}} // ZIR {s} {s}\n\n", .{ kind, decl_name });
    }
};

/// These correspond to the first N tags of Value.
/// A ZIR instruction refers to another one by index. However the first N indexes
/// correspond to this enum, and the next M indexes correspond to the parameters
/// of the current function. After that, they refer to other instructions in the
/// instructions array for the function.
/// When adding to this, consider adding a corresponding entry o `simple_types`
/// in astgen.
pub const Const = enum {
    /// The 0 value is reserved so that ZIR instruction indexes can use it to
    /// mean "null".
    unused,

    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    u128_type,
    i128_type,
    usize_type,
    isize_type,
    c_short_type,
    c_ushort_type,
    c_int_type,
    c_uint_type,
    c_long_type,
    c_ulong_type,
    c_longlong_type,
    c_ulonglong_type,
    c_longdouble_type,
    f16_type,
    f32_type,
    f64_type,
    f128_type,
    c_void_type,
    bool_type,
    void_type,
    type_type,
    anyerror_type,
    comptime_int_type,
    comptime_float_type,
    noreturn_type,
    null_type,
    undefined_type,
    fn_noreturn_no_args_type,
    fn_void_no_args_type,
    fn_naked_noreturn_no_args_type,
    fn_ccc_void_no_args_type,
    single_const_pointer_to_comptime_int_type,
    const_slice_u8_type,
    enum_literal_type,

    /// `undefined` (untyped)
    undef,
    /// `0` (comptime_int)
    zero,
    /// `1` (comptime_int)
    one,
    /// `{}`
    void_value,
    /// `unreachable` (noreturn type)
    unreachable_value,
    /// `null` (untyped)
    null_value,
    /// `true`
    bool_true,
    /// `false`
    bool_false,
};

pub const const_inst_list = std.enums.directEnumArray(Const, TypedValue, 0, .{
    .unused = undefined,
    .u8_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u8_type),
    },
    .i8_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.i8_type),
    },
    .u16_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u16_type),
    },
    .i16_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.i16_type),
    },
    .u32_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u32_type),
    },
    .i32_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.i32_type),
    },
    .u64_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u64_type),
    },
    .i64_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.i64_type),
    },
    .u128_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.u128_type),
    },
    .i128_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.i128_type),
    },
    .usize_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.usize_type),
    },
    .isize_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.isize_type),
    },
    .c_short_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_short_type),
    },
    .c_ushort_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_ushort_type),
    },
    .c_int_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_int_type),
    },
    .c_uint_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_uint_type),
    },
    .c_long_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_long_type),
    },
    .c_ulong_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_ulong_type),
    },
    .c_longlong_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_longlong_type),
    },
    .c_ulonglong_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_ulonglong_type),
    },
    .c_longdouble_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_longdouble_type),
    },
    .f16_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.f16_type),
    },
    .f32_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.f32_type),
    },
    .f64_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.f64_type),
    },
    .f128_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.f128_type),
    },
    .c_void_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.c_void_type),
    },
    .bool_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.bool_type),
    },
    .void_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.void_type),
    },
    .type_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.type_type),
    },
    .anyerror_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.anyerror_type),
    },
    .comptime_int_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.comptime_int_type),
    },
    .comptime_float_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.comptime_float_type),
    },
    .noreturn_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.noreturn_type),
    },
    .null_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.null_type),
    },
    .undefined_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.undefined_type),
    },
    .fn_noreturn_no_args_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.fn_noreturn_no_args_type),
    },
    .fn_void_no_args_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.fn_void_no_args_type),
    },
    .fn_naked_noreturn_no_args_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.fn_naked_noreturn_no_args_type),
    },
    .fn_ccc_void_no_args_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.fn_ccc_void_no_args_type),
    },
    .single_const_pointer_to_comptime_int_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.single_const_pointer_to_comptime_int_type),
    },
    .const_slice_u8_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.const_slice_u8_type),
    },
    .enum_literal_type = .{
        .ty = Type.initTag(.type),
        .val = Value.initTag(.enum_literal_type),
    },

    .undef = .{
        .ty = Type.initTag(.@"undefined"),
        .val = Value.initTag(.undef),
    },
    .zero = .{
        .ty = Type.initTag(.comptime_int),
        .val = Value.initTag(.zero),
    },
    .one = .{
        .ty = Type.initTag(.comptime_int),
        .val = Value.initTag(.one),
    },
    .void_value = .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.void_value),
    },
    .unreachable_value = .{
        .ty = Type.initTag(.noreturn),
        .val = Value.initTag(.unreachable_value),
    },
    .null_value = .{
        .ty = Type.initTag(.@"null"),
        .val = Value.initTag(.null_value),
    },
    .bool_true = .{
        .ty = Type.initTag(.bool),
        .val = Value.initTag(.bool_true),
    },
    .bool_false = .{
        .ty = Type.initTag(.bool),
        .val = Value.initTag(.bool_false),
    },
});

/// These are untyped instructions generated from an Abstract Syntax Tree.
/// The data here is immutable because it is possible to have multiple
/// analyses on the same ZIR happening at the same time.
pub const Inst = struct {
    tag: Tag,
    data: Data,

    /// These names are used directly as the instruction names in the text format.
    pub const Tag = enum {
        /// Arithmetic addition, asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        add,
        /// Twos complement wrapping integer addition.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        addwrap,
        /// Allocates stack local memory.
        /// Uses the `un_node` union field. The operand is the type of the allocated object.
        /// The node source location points to a var decl node.
        /// Indicates the beginning of a new statement in debug info.
        alloc,
        /// Same as `alloc` except mutable.
        alloc_mut,
        /// Same as `alloc` except the type is inferred.
        /// The operand is unused.
        alloc_inferred,
        /// Same as `alloc_inferred` except mutable.
        alloc_inferred_mut,
        /// Array concatenation. `a ++ b`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        array_cat,
        /// Array multiplication `a ** b`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        array_mul,
        /// `[N]T` syntax. No source location provided.
        /// Uses the `bin` union field. lhs is length, rhs is element type.
        array_type,
        /// `[N:S]T` syntax. No source location provided.
        /// Uses the `array_type_sentinel` field.
        array_type_sentinel,
        /// Given a pointer to an indexable object, returns the len property. This is
        /// used by for loops. This instruction also emits a for-loop specific compile
        /// error if the indexable object is not indexable.
        /// Uses the `un_node` field. The AST node is the for loop node.
        indexable_ptr_len,
        /// Type coercion. No source location attached.
        /// Uses the `bin` field.
        as,
        /// Type coercion to the function's return type.
        /// Uses the `pl_node` field. Payload is `As`. AST node could be many things.
        as_node,
        /// Inline assembly. Non-volatile.
        /// Uses the `pl_node` union field. Payload is `Asm`. AST node is the assembly node.
        @"asm",
        /// Inline assembly with the volatile attribute.
        /// Uses the `pl_node` union field. Payload is `Asm`. AST node is the assembly node.
        asm_volatile,
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
        /// Uses `un_node`.
        bit_not,
        /// Bitwise OR. `|`
        bit_or,
        /// A labeled block of code, which can return a value.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block,
        /// Same as `block` but additionally makes the inner instructions execute at comptime.
        block_comptime,
        /// Boolean AND. See also `bit_and`.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        bool_and,
        /// Boolean NOT. See also `bit_not`.
        /// Uses the `un_node` field.
        bool_not,
        /// Boolean OR. See also `bit_or`.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        bool_or,
        /// Short-circuiting boolean `and`. `lhs` is a boolean `Ref` and the other operand
        /// is a block, which is evaluated if `lhs` is `true`.
        /// Uses the `bool_br` union field.
        bool_br_and,
        /// Short-circuiting boolean `or`. `lhs` is a boolean `Ref` and the other operand
        /// is a block, which is evaluated if `lhs` is `false`.
        /// Uses the `bool_br` union field.
        bool_br_or,
        /// Return a value from a block.
        /// Uses the `break` union field.
        /// Uses the source information from previous instruction.
        @"break",
        /// Same as `break` but has source information in the form of an AST node, and
        /// the operand is assumed to be the void value.
        /// Uses the `break_void_node` union field.
        break_void_node,
        /// Return a value from a block. This is a special form that is only valid
        /// when there is exactly 1 break from a block (this one). This instruction
        /// allows using the return value from `Sema.analyzeBody`. The block is
        /// assumed to be the direct parent of this instruction.
        /// Uses the `un_node` union field. The AST node is unused.
        break_flat,
        /// Uses the `node` union field.
        breakpoint,
        /// Function call with modifier `.auto`.
        /// Uses `pl_node`. AST node is the function call. Payload is `Call`.
        call,
        /// Same as `call` but it also does `ensure_result_used` on the return value.
        call_chkused,
        /// Same as `call` but with modifier `.compile_time`.
        call_compile_time,
        /// Function call with modifier `.auto`, empty parameter list.
        /// Uses the `un_node` field. Operand is callee. AST node is the function call.
        call_none,
        /// Same as `call_none` but it also does `ensure_result_used` on the return value.
        call_none_chkused,
        /// `<`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_lt,
        /// `<=`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_lte,
        /// `==`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_eq,
        /// `>=`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_gte,
        /// `>`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_gt,
        /// `!=`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        cmp_neq,
        /// Coerces a result location pointer to a new element type. It is evaluated "backwards"-
        /// as type coercion from the new element type to the old element type.
        /// Uses the `bin` union field.
        /// LHS is destination element type, RHS is result pointer.
        coerce_result_ptr,
        /// Emit an error message and fail compilation.
        /// Uses the `un_node` field.
        compile_error,
        /// Log compile time variables and emit an error message.
        /// Uses the `pl_node` union field. The AST node is the compile log builtin call.
        /// The payload is `MultiOp`.
        compile_log,
        /// Conditional branch. Splits control flow based on a boolean condition value.
        /// Uses the `pl_node` union field. AST node is an if, while, for, etc.
        /// Payload is `CondBr`.
        condbr,
        /// Special case, has no textual representation.
        /// Uses the `const` union field.
        @"const",
        /// Declares the beginning of a statement. Used for debug info.
        /// Uses the `node` union field.
        dbg_stmt_node,
        /// Represents a pointer to a global decl.
        /// Uses the `decl` union field.
        decl_ref,
        /// Equivalent to a decl_ref followed by deref.
        /// Uses the `decl` union field.
        decl_val,
        /// Load the value from a pointer. Assumes `x.*` syntax.
        /// Uses `un_node` field. AST node is the `x.*` syntax.
        deref_node,
        /// Arithmetic division. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        div,
        /// Given a pointer to an array, slice, or pointer, returns a pointer to the element at
        /// the provided index. Uses the `bin` union field. Source location is implied
        /// to be the same as the previous instruction.
        elem_ptr,
        /// Same as `elem_ptr` except also stores a source location node.
        /// Uses the `pl_node` union field. AST node is a[b] syntax. Payload is `Bin`.
        elem_ptr_node,
        /// Given an array, slice, or pointer, returns the element at the provided index.
        /// Uses the `bin` union field. Source location is implied to be the same
        /// as the previous instruction.
        elem_val,
        /// Same as `elem_val` except also stores a source location node.
        /// Uses the `pl_node` union field. AST node is a[b] syntax. Payload is `Bin`.
        elem_val_node,
        /// This instruction has been deleted late in the astgen phase. It must
        /// be ignored, and the corresponding `Data` is undefined.
        elided,
        /// Emits a compile error if the operand is not `void`.
        /// Uses the `un_node` field.
        ensure_result_used,
        /// Emits a compile error if an error is ignored.
        /// Uses the `un_node` field.
        ensure_result_non_error,
        /// Create a `E!T` type.
        error_union_type,
        /// Create an error set. extra[lhs..rhs]. The values are token index offsets.
        error_set,
        /// `error.Foo` syntax. Uses the `str_tok` field of the Data union.
        error_value,
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field. The field name is stored in string_bytes. Used by a.b syntax.
        /// Uses `pl_node` field. The AST node is the a.b syntax. Payload is Field.
        field_ptr,
        /// Given a struct or object that contains virtual fields, returns the named field.
        /// The field name is stored in string_bytes. Used by a.b syntax.
        /// Uses `pl_node` field. The AST node is the a.b syntax. Payload is Field.
        field_val,
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field. The field name is a comptime instruction. Used by @field.
        /// Uses `pl_node` field. The AST node is the builtin call. Payload is FieldNamed.
        field_ptr_named,
        /// Given a struct or object that contains virtual fields, returns the named field.
        /// The field name is a comptime instruction. Used by @field.
        /// Uses `pl_node` field. The AST node is the builtin call. Payload is FieldNamed.
        field_val_named,
        /// Convert a larger float type to any other float type, possibly causing
        /// a loss of precision.
        /// Uses the `pl_node` field. AST is the `@floatCast` syntax.
        /// Payload is `Bin` with lhs as the dest type, rhs the operand.
        floatcast,
        /// Returns a function type, assuming unspecified calling convention.
        /// Uses the `fn_type` union field. `payload_index` points to a `FnType`.
        fn_type,
        /// Same as `fn_type` but the function is variadic.
        fn_type_var_args,
        /// Returns a function type, with a calling convention instruction operand.
        /// Uses the `fn_type` union field. `payload_index` points to a `FnTypeCc`.
        fn_type_cc,
        /// Same as `fn_type_cc` but the function is variadic.
        fn_type_cc_var_args,
        /// `@import(operand)`.
        /// Uses the `un_node` field.
        import,
        /// Integer literal that fits in a u64. Uses the int union value.
        int,
        /// Convert an integer value to another integer type, asserting that the destination type
        /// can hold the same mathematical value.
        /// Uses the `pl_node` field. AST is the `@intCast` syntax.
        /// Payload is `Bin` with lhs as the dest type, rhs the operand.
        intcast,
        /// Make an integer type out of signedness and bit count.
        /// Payload is `int_type`
        int_type,
        /// Return a boolean false if an optional is null. `x != null`
        /// Uses the `un_tok` field.
        is_non_null,
        /// Return a boolean true if an optional is null. `x == null`
        /// Uses the `un_tok` field.
        is_null,
        /// Return a boolean false if an optional is null. `x.* != null`
        /// Uses the `un_tok` field.
        is_non_null_ptr,
        /// Return a boolean true if an optional is null. `x.* == null`
        /// Uses the `un_tok` field.
        is_null_ptr,
        /// Return a boolean true if value is an error
        /// Uses the `un_tok` field.
        is_err,
        /// Return a boolean true if dereferenced pointer is an error
        /// Uses the `un_tok` field.
        is_err_ptr,
        /// A labeled block of code that loops forever. At the end of the body will have either
        /// a `repeat` instruction or a `repeat_inline` instruction.
        /// Uses the `pl_node` field. The AST node is either a for loop or while loop.
        /// This ZIR instruction is needed because TZIR does not (yet?) match ZIR, and Sema
        /// needs to emit more than 1 TZIR block for this instruction.
        /// The payload is `Block`.
        loop,
        /// Sends runtime control flow back to the beginning of the current block.
        /// Uses the `node` field.
        repeat,
        /// Sends comptime control flow back to the beginning of the current block.
        /// Uses the `node` field.
        repeat_inline,
        /// Merge two error sets into one, `E1 || E2`.
        merge_error_sets,
        /// Ambiguously remainder division or modulus. If the computation would possibly have
        /// a different value depending on whether the operation is remainder division or modulus,
        /// a compile error is emitted. Otherwise the computation is performed.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mod_rem,
        /// Arithmetic multiplication. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mul,
        /// Twos complement wrapping integer multiplication.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mulwrap,
        /// Given a reference to a function and a parameter index, returns the
        /// type of the parameter. The only usage of this instruction is for the
        /// result location of parameters of function calls. In the case of a function's
        /// parameter type being `anytype`, it is the type coercion's job to detect this
        /// scenario and skip the coercion, so that semantic analysis of this instruction
        /// is not in a position where it must create an invalid type.
        /// Uses the `param_type` union field.
        param_type,
        /// Convert a pointer to a `usize` integer.
        /// Uses the `un_node` field. The AST node is the builtin fn call node.
        ptrtoint,
        /// Turns an R-Value into a const L-Value. In other words, it takes a value,
        /// stores it in a memory location, and returns a const pointer to it. If the value
        /// is `comptime`, the memory location is global static constant data. Otherwise,
        /// the memory location is in the stack frame, local to the scope containing the
        /// instruction.
        /// Uses the `un_tok` union field.
        ref,
        /// Obtains a pointer to the return value.
        /// Uses the `node` union field.
        ret_ptr,
        /// Obtains the return type of the in-scope function.
        /// Uses the `node` union field.
        ret_type,
        /// Sends control flow back to the function's callee.
        /// Includes an operand as the return value.
        /// Includes an AST node source location.
        /// Uses the `un_node` union field.
        ret_node,
        /// Sends control flow back to the function's callee.
        /// Includes an operand as the return value.
        /// Includes a token source location.
        /// Uses the `un_tok` union field.
        ret_tok,
        /// Same as `ret_tok` except the operand needs to get coerced to the function's
        /// return type.
        ret_coerce,
        /// Changes the maximum number of backwards branches that compile-time
        /// code execution can use before giving up and making a compile error.
        /// Uses the `un_node` union field.
        set_eval_branch_quota,
        /// Integer shift-left. Zeroes are shifted in from the right hand side.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        shl,
        /// Integer shift-right. Arithmetic or logical depending on the signedness of the integer type.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        shr,
        /// Create a pointer type that does not have a sentinel, alignment, or bit range specified.
        /// Uses the `ptr_type_simple` union field.
        ptr_type_simple,
        /// Create a pointer type which can have a sentinel, alignment, and/or bit range.
        /// Uses the `ptr_type` union field.
        ptr_type,
        /// Each `store_to_inferred_ptr` puts the type of the stored value into a set,
        /// and then `resolve_inferred_alloc` triggers peer type resolution on the set.
        /// The operand is a `alloc_inferred` or `alloc_inferred_mut` instruction, which
        /// is the allocation that needs to have its type inferred.
        /// Uses the `un_node` field. The AST node is the var decl.
        resolve_inferred_alloc,
        /// Slice operation `lhs[rhs..]`. No sentinel and no end offset.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceStart`.
        slice_start,
        /// Slice operation `array_ptr[start..end]`. No sentinel.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceEnd`.
        slice_end,
        /// Slice operation `array_ptr[start..end:sentinel]`.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceSentinel`.
        slice_sentinel,
        /// Write a value to a pointer. For loading, see `deref`.
        /// Uses the `bin` union field.
        store,
        /// Same as `store` but the type of the value being stored will be used to infer
        /// the block type. The LHS is the pointer to store to.
        /// Uses the `bin` union field.
        store_to_block_ptr,
        /// Same as `store` but the type of the value being stored will be used to infer
        /// the pointer type.
        /// Uses the `bin` union field - astgen.zig depends on the ability to change
        /// the tag of an instruction from `store_to_block_ptr` to `store_to_inferred_ptr`
        /// without changing the data.
        store_to_inferred_ptr,
        /// String Literal. Makes an anonymous Decl and then takes a pointer to it.
        /// Uses the `str` union field.
        str,
        /// Arithmetic subtraction. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        sub,
        /// Twos complement wrapping integer subtraction.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        subwrap,
        /// Arithmetic negation. Asserts no integer overflow.
        /// Same as sub with a lhs of 0, split into a separate instruction to save memory.
        /// Uses `un_node`.
        negate,
        /// Twos complement wrapping integer negation.
        /// Same as subwrap with a lhs of 0, split into a separate instruction to save memory.
        /// Uses `un_node`.
        negate_wrap,
        /// Returns the type of a value.
        /// Uses the `un_tok` field.
        typeof,
        /// The builtin `@TypeOf` which returns the type after Peer Type Resolution
        /// of one or more params.
        /// Uses the `pl_node` field. AST node is the `@TypeOf` call. Payload is `MultiOp`.
        typeof_peer,
        /// Asserts control-flow will not reach this instruction (`unreachable`).
        /// Uses the `unreachable` union field.
        @"unreachable",
        /// Bitwise XOR. `^`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        xor,
        /// Create an optional type '?T'
        /// Uses the `un_node` field.
        optional_type,
        /// Create an optional type '?T'. The operand is a pointer value. The optional type will
        /// be the type of the pointer element, wrapped in an optional.
        /// Uses the `un_node` field.
        optional_type_from_ptr_elem,
        /// ?T => T with safety.
        /// Given an optional value, returns the payload value, with a safety check that
        /// the value is non-null. Used for `orelse`, `if` and `while`.
        /// Uses the `un_node` field.
        optional_payload_safe,
        /// ?T => T without safety.
        /// Given an optional value, returns the payload value. No safety checks.
        /// Uses the `un_node` field.
        optional_payload_unsafe,
        /// *?T => *T with safety.
        /// Given a pointer to an optional value, returns a pointer to the payload value,
        /// with a safety check that the value is non-null. Used for `orelse`, `if` and `while`.
        /// Uses the `un_node` field.
        optional_payload_safe_ptr,
        /// *?T => *T without safety.
        /// Given a pointer to an optional value, returns a pointer to the payload value.
        /// No safety checks.
        /// Uses the `un_node` field.
        optional_payload_unsafe_ptr,
        /// E!T => T with safety.
        /// Given an error union value, returns the payload value, with a safety check
        /// that the value is not an error. Used for catch, if, and while.
        /// Uses the `un_node` field.
        err_union_payload_safe,
        /// E!T => T without safety.
        /// Given an error union value, returns the payload value. No safety checks.
        /// Uses the `un_node` field.
        err_union_payload_unsafe,
        /// *E!T => *T with safety.
        /// Given a pointer to an error union value, returns a pointer to the payload value,
        /// with a safety check that the value is not an error. Used for catch, if, and while.
        /// Uses the `un_node` field.
        err_union_payload_safe_ptr,
        /// *E!T => *T without safety.
        /// Given a pointer to a error union value, returns a pointer to the payload value.
        /// No safety checks.
        /// Uses the `un_node` field.
        err_union_payload_unsafe_ptr,
        /// E!T => E without safety.
        /// Given an error union value, returns the error code. No safety checks.
        /// Uses the `un_node` field.
        err_union_code,
        /// *E!T => E without safety.
        /// Given a pointer to an error union value, returns the error code. No safety checks.
        /// Uses the `un_node` field.
        err_union_code_ptr,
        /// Takes a *E!T and raises a compiler error if T != void
        /// Uses the `un_tok` field.
        ensure_err_payload_void,
        /// An enum literal. Uses the `str_tok` union field.
        enum_literal,
        /// An enum literal 8 or fewer bytes. No source location.
        /// Uses the `small_str` field.
        enum_literal_small,
        // /// A switch expression.
        // /// lhs is target, SwitchBr[rhs]
        // /// All prongs of target handled.
        // switch_br,
        // /// Same as switch_br, except has a range field.
        // switch_br_range,
        // /// Same as switch_br, except has an else prong.
        // switch_br_else,
        // /// Same as switch_br_else, except has a range field.
        // switch_br_else_range,
        // /// Same as switch_br, except has an underscore prong.
        // switch_br_underscore,
        // /// Same as switch_br, except has a range field.
        // switch_br_underscore_range,
        // /// Same as `switch_br` but the target is a pointer to the value being switched on.
        // switch_br_ref,
        // /// Same as `switch_br_range` but the target is a pointer to the value being switched on.
        // switch_br_ref_range,
        // /// Same as `switch_br_else` but the target is a pointer to the value being switched on.
        // switch_br_ref_else,
        // /// Same as `switch_br_else_range` but the target is a pointer to the
        // /// value being switched on.
        // switch_br_ref_else_range,
        // /// Same as `switch_br_underscore` but the target is a pointer to the value
        // /// being switched on.
        // switch_br_ref_underscore,
        // /// Same as `switch_br_underscore_range` but the target is a pointer to
        // /// the value being switched on.
        // switch_br_ref_underscore_range,
        // /// A range in a switch case, `lhs...rhs`.
        // /// Only checks that `lhs >= rhs` if they are ints, everything else is
        // /// validated by the switch_br instruction.
        // switch_range,

        comptime {
            assert(@sizeOf(Tag) == 1);
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
                .as,
                .as_node,
                .@"asm",
                .asm_volatile,
                .bit_and,
                .bitcast,
                .bitcast_ref,
                .bitcast_result_ptr,
                .bit_or,
                .block,
                .block_comptime,
                .loop,
                .bool_br_and,
                .bool_br_or,
                .bool_not,
                .bool_and,
                .bool_or,
                .breakpoint,
                .call,
                .call_chkused,
                .call_compile_time,
                .call_none,
                .call_none_chkused,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .coerce_result_ptr,
                .@"const",
                .dbg_stmt_node,
                .decl_ref,
                .decl_val,
                .deref_node,
                .div,
                .elem_ptr,
                .elem_val,
                .elem_ptr_node,
                .elem_val_node,
                .ensure_result_used,
                .ensure_result_non_error,
                .floatcast,
                .field_ptr,
                .field_val,
                .field_ptr_named,
                .field_val_named,
                .fn_type,
                .fn_type_var_args,
                .fn_type_cc,
                .fn_type_cc_var_args,
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
                .ptrtoint,
                .ref,
                .ret_ptr,
                .ret_type,
                .shl,
                .shr,
                .store,
                .store_to_block_ptr,
                .store_to_inferred_ptr,
                .str,
                .sub,
                .subwrap,
                .negate,
                .negate_wrap,
                .typeof,
                .xor,
                .optional_type,
                .optional_type_from_ptr_elem,
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
                .ptr_type_simple,
                .ensure_err_payload_void,
                .enum_literal,
                .enum_literal_small,
                .merge_error_sets,
                .error_union_type,
                .bit_not,
                .error_set,
                .error_value,
                .slice_start,
                .slice_end,
                .slice_sentinel,
                .import,
                .typeof_peer,
                .resolve_inferred_alloc,
                .set_eval_branch_quota,
                .compile_log,
                .elided,
                => false,

                .@"break",
                .break_void_node,
                .break_flat,
                .condbr,
                .compile_error,
                .ret_node,
                .ret_tok,
                .ret_coerce,
                .@"unreachable",
                .repeat,
                .repeat_inline,
                => true,
            };
        }
    };

    /// The position of a ZIR instruction within the `Code` instructions array.
    pub const Index = u32;

    /// A reference to another ZIR instruction. If this value is below a certain
    /// threshold, it implicitly refers to a constant-known value from the `Const` enum.
    /// Below a second threshold, it implicitly refers to a parameter of the current
    /// function.
    /// Finally, after subtracting that offset, it refers to another instruction in
    /// the instruction array.
    /// This logic is implemented in `Sema.resolveRef`.
    pub const Ref = u32;

    /// All instructions have an 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Used for unary operators, with an AST node source location.
        un_node: struct {
            /// Offset from Decl AST node index.
            src_node: i32,
            /// The meaning of this operand depends on the corresponding `Tag`.
            operand: Ref,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .node_offset = self.src_node };
            }
        },
        /// Used for unary operators, with a token source location.
        un_tok: struct {
            /// Offset from Decl AST token index.
            src_tok: ast.TokenIndex,
            /// The meaning of this operand depends on the corresponding `Tag`.
            operand: Ref,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .token_offset = self.src_tok };
            }
        },
        pl_node: struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,
            /// index into extra.
            /// `Tag` determines what lives there.
            payload_index: u32,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .node_offset = self.src_node };
            }
        },
        bin: Bin,
        decl: *Module.Decl,
        @"const": *TypedValue,
        /// For strings which may contain null bytes.
        str: struct {
            /// Offset into `string_bytes`.
            start: u32,
            /// Number of bytes in the string.
            len: u32,

            pub fn get(self: @This(), code: Code) []const u8 {
                return code.string_bytes[self.start..][0..self.len];
            }
        },
        /// Strings 8 or fewer bytes which may not contain null bytes.
        small_str: struct {
            bytes: [8]u8,

            pub fn get(self: @This()) []const u8 {
                const end = for (self.bytes) |byte, i| {
                    if (byte == 0) break i;
                } else self.bytes.len;
                return self.bytes[0..end];
            }
        },
        str_tok: struct {
            /// Offset into `string_bytes`. Null-terminated.
            start: u32,
            /// Offset from Decl AST token index.
            src_tok: u32,

            pub fn get(self: @This(), code: Code) [:0]const u8 {
                return code.nullTerminatedString(self.start);
            }

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .token_offset = self.src_tok };
            }
        },
        /// Offset from Decl AST token index.
        tok: ast.TokenIndex,
        /// Offset from Decl AST node index.
        node: i32,
        int: u64,
        array_type_sentinel: struct {
            len: Ref,
            /// index into extra, points to an `ArrayTypeSentinel`
            payload_index: u32,
        },
        ptr_type_simple: struct {
            is_allowzero: bool,
            is_mutable: bool,
            is_volatile: bool,
            size: std.builtin.TypeInfo.Pointer.Size,
            elem_type: Ref,
        },
        ptr_type: struct {
            flags: packed struct {
                is_allowzero: bool,
                is_mutable: bool,
                is_volatile: bool,
                has_sentinel: bool,
                has_align: bool,
                has_bit_range: bool,
                _: u2 = undefined,
            },
            size: std.builtin.TypeInfo.Pointer.Size,
            /// Index into extra. See `PtrType`.
            payload_index: u32,
        },
        fn_type: struct {
            return_type: Ref,
            /// For `fn_type` this points to a `FnType` in `extra`.
            /// For `fn_type_cc` this points to `FnTypeCc` in `extra`.
            payload_index: u32,
        },
        int_type: struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,
            signedness: std.builtin.Signedness,
            bit_count: u16,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .node_offset = self.src_node };
            }
        },
        bool_br: struct {
            lhs: Ref,
            /// Points to a `Block`.
            payload_index: u32,
        },
        param_type: struct {
            callee: Ref,
            param_index: u32,
        },
        @"unreachable": struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,
            /// `false`: Not safety checked - the compiler will assume the
            /// correctness of this instruction.
            /// `true`: In safety-checked modes, this will generate a call
            /// to the panic function unless it can be proven unreachable by the compiler.
            safety: bool,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .node_offset = self.src_node };
            }
        },
        break_void_node: struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,
            block_inst: Index,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .node_offset = self.src_node };
            }
        },
        @"break": struct {
            block_inst: Index,
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

    /// Stored in extra. Trailing is:
    /// * output_name: u32 // index into string_bytes (null terminated) if output is present
    /// * arg: Ref // for every args_len.
    /// * constraint: u32 // index into string_bytes (null terminated) for every args_len.
    /// * clobber: u32 // index into string_bytes (null terminated) for every clobbers_len.
    pub const Asm = struct {
        asm_source: Ref,
        return_type: Ref,
        /// May be omitted.
        output: Ref,
        args_len: u32,
        clobbers_len: u32,
    };

    /// This data is stored inside extra, with trailing parameter type indexes
    /// according to `param_types_len`.
    /// Each param type is a `Ref`.
    pub const FnTypeCc = struct {
        cc: Ref,
        param_types_len: u32,
    };

    /// This data is stored inside extra, with trailing parameter type indexes
    /// according to `param_types_len`.
    /// Each param type is a `Ref`.
    pub const FnType = struct {
        param_types_len: u32,
    };

    /// This data is stored inside extra, with trailing operands according to `operands_len`.
    /// Each operand is a `Ref`.
    pub const MultiOp = struct {
        operands_len: u32,
    };

    /// This data is stored inside extra, with trailing operands according to `body_len`.
    /// Each operand is an `Index`.
    pub const Block = struct {
        body_len: u32,
    };

    /// Stored inside extra, with trailing arguments according to `args_len`.
    /// Each argument is a `Ref`.
    pub const Call = struct {
        callee: Ref,
        args_len: u32,
    };

    /// This data is stored inside extra, with two sets of trailing `Ref`:
    /// * 0. the then body, according to `then_body_len`.
    /// * 1. the else body, according to `else_body_len`.
    pub const CondBr = struct {
        condition: Ref,
        then_body_len: u32,
        else_body_len: u32,
    };

    /// Stored in extra. Depending on the flags in Data, there will be up to 4
    /// trailing Ref fields:
    /// 0. sentinel: Ref // if `has_sentinel` flag is set
    /// 1. align: Ref // if `has_align` flag is set
    /// 2. bit_start: Ref // if `has_bit_range` flag is set
    /// 3. bit_end: Ref // if `has_bit_range` flag is set
    pub const PtrType = struct {
        elem_type: Ref,
    };

    pub const ArrayTypeSentinel = struct {
        sentinel: Ref,
        elem_type: Ref,
    };

    pub const SliceStart = struct {
        lhs: Ref,
        start: Ref,
    };

    pub const SliceEnd = struct {
        lhs: Ref,
        start: Ref,
        end: Ref,
    };

    pub const SliceSentinel = struct {
        lhs: Ref,
        start: Ref,
        end: Ref,
        sentinel: Ref,
    };

    /// The meaning of these operands depends on the corresponding `Tag`.
    pub const Bin = struct {
        lhs: Ref,
        rhs: Ref,
    };

    /// Stored in extra. Depending on zir tag and len fields, extra fields trail
    /// this one in the extra array.
    /// 0. range: Ref // If the tag has "_range" in it.
    /// 1. else_body: Ref // If the tag has "_else" or "_underscore" in it.
    /// 2. items: list of all individual items and ranges.
    /// 3. cases: {
    ///        item: Ref,
    ///        body_len: u32,
    ///        body member Ref for every body_len
    ///    } for every cases_len
    pub const SwitchBr = struct {
        /// TODO investigate, why do we need to store this? is it redundant?
        items_len: u32,
        cases_len: u32,
    };

    pub const Field = struct {
        lhs: Ref,
        /// Offset into `string_bytes`.
        field_name_start: u32,
        /// Number of bytes in the string.
        field_name_len: u32,
    };

    pub const FieldNamed = struct {
        lhs: Ref,
        field_name: Ref,
    };

    pub const As = struct {
        dest_type: Ref,
        operand: Ref,
    };
};

const Writer = struct {
    gpa: *Allocator,
    arena: *Allocator,
    scope: *Module.Scope,
    code: Code,
    indent: usize,
    param_count: usize,

    fn writeInstToStream(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const tags = self.code.instructions.items(.tag);
        const tag = tags[inst];
        try stream.print("= {s}(", .{@tagName(tags[inst])});
        switch (tag) {
            .array_type,
            .bit_and,
            .bit_or,
            .as,
            .coerce_result_ptr,
            .elem_ptr,
            .elem_val,
            .intcast,
            .merge_error_sets,
            .store,
            .store_to_block_ptr,
            => try self.writeBin(stream, inst),

            .alloc,
            .alloc_mut,
            .alloc_inferred,
            .alloc_inferred_mut,
            .indexable_ptr_len,
            .bit_not,
            .bool_not,
            .negate,
            .negate_wrap,
            .call_none,
            .call_none_chkused,
            .compile_error,
            .deref_node,
            .ensure_result_used,
            .ensure_result_non_error,
            .import,
            .ptrtoint,
            .ret_node,
            .set_eval_branch_quota,
            .resolve_inferred_alloc,
            .optional_type,
            .optional_type_from_ptr_elem,
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
            .break_flat,
            => try self.writeUnNode(stream, inst),

            .is_non_null,
            .is_null,
            .is_non_null_ptr,
            .is_null_ptr,
            .is_err,
            .is_err_ptr,
            .ref,
            .ret_tok,
            .ret_coerce,
            .typeof,
            .ensure_err_payload_void,
            => try self.writeUnTok(stream, inst),

            .bool_br_and,
            .bool_br_or,
            => try self.writeBoolBr(stream, inst),

            .array_type_sentinel => try self.writeArrayTypeSentinel(stream, inst),
            .@"const" => try self.writeConst(stream, inst),
            .param_type => try self.writeParamType(stream, inst),
            .ptr_type_simple => try self.writePtrTypeSimple(stream, inst),
            .ptr_type => try self.writePtrType(stream, inst),
            .int => try self.writeInt(stream, inst),
            .str => try self.writeStr(stream, inst),
            .elided => try stream.writeAll(")"),
            .break_void_node => try self.writeBreakVoidNode(stream, inst),
            .int_type => try self.writeIntType(stream, inst),
            .@"break" => try self.writeBreak(stream, inst),

            .@"asm",
            .asm_volatile,
            .compile_log,
            .elem_ptr_node,
            .elem_val_node,
            .field_ptr,
            .field_val,
            .field_ptr_named,
            .field_val_named,
            .floatcast,
            .slice_start,
            .slice_end,
            .slice_sentinel,
            .typeof_peer,
            => try self.writePlNode(stream, inst),

            .add,
            .addwrap,
            .array_cat,
            .array_mul,
            .mul,
            .mulwrap,
            .sub,
            .subwrap,
            .bool_and,
            .bool_or,
            .cmp_lt,
            .cmp_lte,
            .cmp_eq,
            .cmp_gte,
            .cmp_gt,
            .cmp_neq,
            .div,
            .mod_rem,
            .shl,
            .shr,
            .xor,
            => try self.writePlNodeBin(stream, inst),

            .call,
            .call_chkused,
            .call_compile_time,
            => try self.writePlNodeCall(stream, inst),

            .block,
            .block_comptime,
            .loop,
            => try self.writePlNodeBlock(stream, inst),

            .condbr => try self.writePlNodeCondBr(stream, inst),

            .as_node => try self.writeAs(stream, inst),

            .breakpoint,
            .dbg_stmt_node,
            .ret_ptr,
            .ret_type,
            .repeat,
            .repeat_inline,
            => try self.writeNode(stream, inst),

            .decl_ref,
            .decl_val,
            => try self.writeDecl(stream, inst),

            .error_value,
            .enum_literal,
            => try self.writeStrTok(stream, inst),

            .fn_type => try self.writeFnType(stream, inst, false),
            .fn_type_cc => try self.writeFnTypeCc(stream, inst, false),
            .fn_type_var_args => try self.writeFnType(stream, inst, true),
            .fn_type_cc_var_args => try self.writeFnTypeCc(stream, inst, true),
            .@"unreachable" => try self.writeUnreachable(stream, inst),

            .enum_literal_small => try self.writeSmallStr(stream, inst),

            .bitcast,
            .bitcast_ref,
            .bitcast_result_ptr,
            .error_union_type,
            .error_set,
            .store_to_inferred_ptr,
            => try stream.writeAll("TODO)"),
        }
    }

    fn writeBin(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].bin;
        try self.writeInstRef(stream, inst_data.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, inst_data.rhs);
        try stream.writeByte(')');
    }

    fn writeUnNode(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].un_node;
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(") ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeUnTok(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].un_tok;
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(") ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeArrayTypeSentinel(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].array_type_sentinel;
        try stream.writeAll("TODO)");
    }

    fn writeConst(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].@"const";
        try stream.writeAll("TODO)");
    }

    fn writeParamType(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].param_type;
        try self.writeInstRef(stream, inst_data.callee);
        try stream.print(", {d})", .{inst_data.param_index});
    }

    fn writePtrTypeSimple(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].ptr_type_simple;
        try stream.writeAll("TODO)");
    }

    fn writePtrType(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].ptr_type;
        try stream.writeAll("TODO)");
    }

    fn writeInt(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].int;
        try stream.print("{d})", .{inst_data});
    }

    fn writeStr(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].str;
        const str = inst_data.get(self.code);
        try stream.print("\"{}\")", .{std.zig.fmtEscapes(str)});
    }

    fn writePlNode(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        try stream.writeAll("TODO) ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writePlNodeBin(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        const extra = self.code.extraData(Inst.Bin, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.lhs);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.rhs);
        try stream.writeAll(") ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writePlNodeCall(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        const extra = self.code.extraData(Inst.Call, inst_data.payload_index);
        const args = self.code.extra[extra.end..][0..extra.data.args_len];
        try self.writeInstRef(stream, extra.data.callee);
        try stream.writeAll(", [");
        for (args) |arg, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, arg);
        }
        try stream.writeAll("]) ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writePlNodeBlock(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        const extra = self.code.extraData(Inst.Block, inst_data.payload_index);
        const body = self.code.extra[extra.end..][0..extra.data.body_len];
        try stream.writeAll("{\n");
        self.indent += 2;
        try self.writeBody(stream, body);
        self.indent -= 2;
        try stream.writeByteNTimes(' ', self.indent);
        try stream.writeAll("}) ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writePlNodeCondBr(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        const extra = self.code.extraData(Inst.CondBr, inst_data.payload_index);
        const then_body = self.code.extra[extra.end..][0..extra.data.then_body_len];
        const else_body = self.code.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
        try self.writeInstRef(stream, extra.data.condition);
        try stream.writeAll(", {\n");
        self.indent += 2;
        try self.writeBody(stream, then_body);
        self.indent -= 2;
        try stream.writeByteNTimes(' ', self.indent);
        try stream.writeAll("}, {\n");
        self.indent += 2;
        try self.writeBody(stream, else_body);
        self.indent -= 2;
        try stream.writeByteNTimes(' ', self.indent);
        try stream.writeAll("}) ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeAs(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].pl_node;
        const extra = self.code.extraData(Inst.As, inst_data.payload_index).data;
        try self.writeInstRef(stream, extra.dest_type);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, extra.operand);
        try stream.writeAll(") ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeNode(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const src_node = self.code.instructions.items(.data)[inst].node;
        const src: LazySrcLoc = .{ .node_offset = src_node };
        try stream.writeAll(") ");
        try self.writeSrc(stream, src);
    }

    fn writeDecl(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const decl = self.code.instructions.items(.data)[inst].decl;
        try stream.print("{s})", .{decl.name});
    }

    fn writeStrTok(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].str_tok;
        const str = inst_data.get(self.code);
        try stream.print("\"{}\") ", .{std.zig.fmtEscapes(str)});
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeFnType(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
        var_args: bool,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].fn_type;
        const extra = self.code.extraData(Inst.FnType, inst_data.payload_index);
        const param_types = self.code.extra[extra.end..][0..extra.data.param_types_len];
        const cc: Inst.Ref = 0;
        return self.writeFnTypeCommon(stream, param_types, inst_data.return_type, var_args, cc);
    }

    fn writeBoolBr(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].bool_br;
        const extra = self.code.extraData(Inst.Block, inst_data.payload_index);
        const body = self.code.extra[extra.end..][0..extra.data.body_len];
        try self.writeInstRef(stream, inst_data.lhs);
        try stream.writeAll(", {\n");
        self.indent += 2;
        try self.writeBody(stream, body);
        self.indent -= 2;
        try stream.writeByteNTimes(' ', self.indent);
        try stream.writeAll("})");
    }

    fn writeFnTypeCc(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
        var_args: bool,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const inst_data = self.code.instructions.items(.data)[inst].fn_type;
        const extra = self.code.extraData(Inst.FnTypeCc, inst_data.payload_index);
        const param_types = self.code.extra[extra.end..][0..extra.data.param_types_len];
        const cc = extra.data.cc;
        return self.writeFnTypeCommon(stream, param_types, inst_data.return_type, var_args, cc);
    }

    fn writeBreakVoidNode(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].break_void_node;
        try self.writeInstIndex(stream, inst_data.block_inst);
        try stream.writeAll(") ");
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeIntType(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const int_type = self.code.instructions.items(.data)[inst].int_type;
        const prefix: u8 = switch (int_type.signedness) {
            .signed => 'i',
            .unsigned => 'u',
        };
        try stream.print("{c}{d}) ", .{ prefix, int_type.bit_count });
        try self.writeSrc(stream, int_type.src());
    }

    fn writeBreak(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].@"break";

        try self.writeInstIndex(stream, inst_data.block_inst);
        try stream.writeAll(", ");
        try self.writeInstRef(stream, inst_data.operand);
        try stream.writeAll(")");
    }

    fn writeUnreachable(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        const inst_data = self.code.instructions.items(.data)[inst].@"unreachable";
        const safety_str = if (inst_data.safety) "safe" else "unsafe";
        try stream.print("{s}) ", .{safety_str});
        try self.writeSrc(stream, inst_data.src());
    }

    fn writeFnTypeCommon(
        self: *Writer,
        stream: anytype,
        param_types: []const Inst.Ref,
        ret_ty: Inst.Ref,
        var_args: bool,
        cc: Inst.Ref,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        try stream.writeAll("[");
        for (param_types) |param_type, i| {
            if (i != 0) try stream.writeAll(", ");
            try self.writeInstRef(stream, param_type);
        }
        try stream.writeAll("], ");
        try self.writeInstRef(stream, ret_ty);
        try self.writeOptionalInstRef(stream, ", cc=", cc);
        try self.writeFlag(stream, ", var_args", var_args);
        try stream.writeAll(")");
    }

    fn writeSmallStr(
        self: *Writer,
        stream: anytype,
        inst: Inst.Index,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const str = self.code.instructions.items(.data)[inst].small_str.get();
        try stream.print("\"{}\")", .{std.zig.fmtEscapes(str)});
    }

    fn writeInstRef(self: *Writer, stream: anytype, inst: Inst.Ref) !void {
        var i: usize = inst;

        if (i < const_inst_list.len) {
            return stream.print("@{d}", .{i});
        }
        i -= const_inst_list.len;

        if (i < self.param_count) {
            return stream.print("${d}", .{i});
        }
        i -= self.param_count;

        return self.writeInstIndex(stream, @intCast(Inst.Index, i));
    }

    fn writeInstIndex(self: *Writer, stream: anytype, inst: Inst.Index) !void {
        return stream.print("%{d}", .{inst});
    }

    fn writeOptionalInstRef(
        self: *Writer,
        stream: anytype,
        prefix: []const u8,
        inst: Inst.Index,
    ) !void {
        if (inst == 0) return;
        try stream.writeAll(prefix);
        try self.writeInstRef(stream, inst);
    }

    fn writeFlag(
        self: *Writer,
        stream: anytype,
        name: []const u8,
        flag: bool,
    ) !void {
        if (!flag) return;
        try stream.writeAll(name);
    }

    fn writeSrc(self: *Writer, stream: anytype, src: LazySrcLoc) !void {
        const tree = self.scope.tree();
        const src_loc = src.toSrcLoc(self.scope);
        const abs_byte_off = try src_loc.byteOffset();
        const delta_line = std.zig.findLineColumn(tree.source, abs_byte_off);
        try stream.print("{s}:{d}:{d}", .{
            @tagName(src), delta_line.line + 1, delta_line.column + 1,
        });
    }

    fn writeBody(self: *Writer, stream: anytype, body: []const Inst.Index) !void {
        for (body) |inst| {
            try stream.writeByteNTimes(' ', self.indent);
            try stream.print("%{d} ", .{inst});
            try self.writeInstToStream(stream, inst);
            try stream.writeByte('\n');
        }
    }
};
