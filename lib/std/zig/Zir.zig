//! Zig Intermediate Representation. Astgen.zig converts AST nodes to these
//! untyped IR instructions. Next, Sema.zig processes these into AIR.
//! The minimum amount of information needed to represent a list of ZIR instructions.
//! Once this structure is completed, it can be used to generate AIR, followed by
//! machine code, without any memory access into the AST tree token list, node list,
//! or source bytes. Exceptions include:
//!  * Compile errors, which may need to reach into these data structures to
//!    create a useful report.
//!  * In the future, possibly inline assembly, which needs to get parsed and
//!    handled by the codegen backend, and errors reported there. However for now,
//!    inline assembly is not an exception.

const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Ast = std.zig.Ast;

const Zir = @This();
const LazySrcLoc = std.zig.LazySrcLoc;

instructions: std.MultiArrayList(Inst).Slice,
/// In order to store references to strings in fewer bytes, we copy all
/// string bytes into here. String bytes can be null. It is up to whomever
/// is referencing the data here whether they want to store both index and length,
/// thus allowing null bytes, or store only index, and use null-termination. The
/// `string_bytes` array is agnostic to either usage.
/// Index 0 is reserved for special cases.
string_bytes: []u8,
/// The meaning of this data is determined by `Inst.Tag` value.
/// The first few indexes are reserved. See `ExtraIndex` for the values.
extra: []u32,

/// The data stored at byte offset 0 when ZIR is stored in a file.
pub const Header = extern struct {
    instructions_len: u32,
    string_bytes_len: u32,
    extra_len: u32,
    /// We could leave this as padding, however it triggers a Valgrind warning because
    /// we read and write undefined bytes to the file system. This is harmless, but
    /// it's essentially free to have a zero field here and makes the warning go away,
    /// making it more likely that following Valgrind warnings will be taken seriously.
    unused: u32 = 0,
    stat_inode: std.fs.File.INode,
    stat_size: u64,
    stat_mtime: i128,
};

pub const ExtraIndex = enum(u32) {
    /// If this is 0, no compile errors. Otherwise there is a `CompileErrors`
    /// payload at this index.
    compile_errors,
    /// If this is 0, this file contains no imports. Otherwise there is a `Imports`
    /// payload at this index.
    imports,

    _,
};

fn ExtraData(comptime T: type) type {
    return struct { data: T, end: usize };
}

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(code: Zir, comptime T: type, index: usize) ExtraData(T) {
    const fields = @typeInfo(T).Struct.fields;
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => code.extra[i],

            Inst.Ref,
            Inst.Index,
            Inst.Declaration.Name,
            NullTerminatedString,
            => @enumFromInt(code.extra[i]),

            i32,
            Inst.Call.Flags,
            Inst.BuiltinCall.Flags,
            Inst.SwitchBlock.Bits,
            Inst.SwitchBlockErrUnion.Bits,
            Inst.FuncFancy.Bits,
            Inst.Declaration.Flags,
            => @bitCast(code.extra[i]),

            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

pub const NullTerminatedString = enum(u32) {
    empty = 0,
    _,
};

/// Given an index into `string_bytes` returns the null-terminated string found there.
pub fn nullTerminatedString(code: Zir, index: NullTerminatedString) [:0]const u8 {
    const slice = code.string_bytes[@intFromEnum(index)..];
    return slice[0..std.mem.indexOfScalar(u8, slice, 0).? :0];
}

pub fn refSlice(code: Zir, start: usize, len: usize) []Inst.Ref {
    return @ptrCast(code.extra[start..][0..len]);
}

pub fn bodySlice(zir: Zir, start: usize, len: usize) []Inst.Index {
    return @ptrCast(zir.extra[start..][0..len]);
}

pub fn hasCompileErrors(code: Zir) bool {
    return code.extra[@intFromEnum(ExtraIndex.compile_errors)] != 0;
}

pub fn deinit(code: *Zir, gpa: Allocator) void {
    code.instructions.deinit(gpa);
    gpa.free(code.string_bytes);
    gpa.free(code.extra);
    code.* = undefined;
}

/// These are untyped instructions generated from an Abstract Syntax Tree.
/// The data here is immutable because it is possible to have multiple
/// analyses on the same ZIR happening at the same time.
pub const Inst = struct {
    tag: Tag,
    data: Data,

    /// These names are used directly as the instruction names in the text format.
    /// See `data_field_map` for a list of which `Data` fields are used by each `Tag`.
    pub const Tag = enum(u8) {
        /// Arithmetic addition, asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        add,
        /// Twos complement wrapping integer addition.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        addwrap,
        /// Saturating addition.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        add_sat,
        /// The same as `add` except no safety check.
        add_unsafe,
        /// Arithmetic subtraction. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        sub,
        /// Twos complement wrapping integer subtraction.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        subwrap,
        /// Saturating subtraction.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        sub_sat,
        /// Arithmetic multiplication. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mul,
        /// Twos complement wrapping integer multiplication.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mulwrap,
        /// Saturating multiplication.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mul_sat,
        /// Implements the `@divExact` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        div_exact,
        /// Implements the `@divFloor` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        div_floor,
        /// Implements the `@divTrunc` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        div_trunc,
        /// Implements the `@mod` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        mod,
        /// Implements the `@rem` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        rem,
        /// Ambiguously remainder division or modulus. If the computation would possibly have
        /// a different value depending on whether the operation is remainder division or modulus,
        /// a compile error is emitted. Otherwise the computation is performed.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        mod_rem,
        /// Integer shift-left. Zeroes are shifted in from the right hand side.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        shl,
        /// Implements the `@shlExact` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        shl_exact,
        /// Saturating shift-left.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        shl_sat,
        /// Integer shift-right. Arithmetic or logical depending on the signedness of
        /// the integer type.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        shr,
        /// Implements the `@shrExact` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        shr_exact,

        /// Declares a parameter of the current function. Used for:
        /// * debug info
        /// * checking shadowing against declarations in the current namespace
        /// * parameter type expressions referencing other parameters
        /// These occur in the block outside a function body (the same block as
        /// contains the func instruction).
        /// Uses the `pl_tok` field. Token is the parameter name, payload is a `Param`.
        param,
        /// Same as `param` except the parameter is marked comptime.
        param_comptime,
        /// Same as `param` except the parameter is marked anytype.
        /// Uses the `str_tok` field. Token is the parameter name. String is the parameter name.
        param_anytype,
        /// Same as `param` except the parameter is marked both comptime and anytype.
        /// Uses the `str_tok` field. Token is the parameter name. String is the parameter name.
        param_anytype_comptime,
        /// Array concatenation. `a ++ b`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        array_cat,
        /// Array multiplication `a ** b`
        /// Uses the `pl_node` union field. Payload is `ArrayMul`.
        array_mul,
        /// `[N]T` syntax. No source location provided.
        /// Uses the `pl_node` union field. Payload is `Bin`. lhs is length, rhs is element type.
        array_type,
        /// `[N:S]T` syntax. Source location is the array type expression node.
        /// Uses the `pl_node` union field. Payload is `ArrayTypeSentinel`.
        array_type_sentinel,
        /// `@Vector` builtin.
        /// Uses the `pl_node` union field with `Bin` payload.
        /// lhs is length, rhs is element type.
        vector_type,
        /// Given a pointer type, returns its element type. Reaches through any optional or error
        /// union types wrapping the pointer. Asserts that the underlying type is a pointer type.
        /// Returns generic poison if the element type is `anyopaque`.
        /// Uses the `un_node` field.
        elem_type,
        /// Given an indexable pointer (slice, many-ptr, single-ptr-to-array), returns its
        /// element type. Emits a compile error if the type is not an indexable pointer.
        /// Uses the `un_node` field.
        indexable_ptr_elem_type,
        /// Given a vector type, returns its element type.
        /// Uses the `un_node` field.
        vector_elem_type,
        /// Given a pointer to an indexable object, returns the len property. This is
        /// used by for loops. This instruction also emits a for-loop specific compile
        /// error if the indexable object is not indexable.
        /// Uses the `un_node` field. The AST node is the for loop node.
        indexable_ptr_len,
        /// Create a `anyframe->T` type.
        /// Uses the `un_node` field.
        anyframe_type,
        /// Type coercion to the function's return type.
        /// Uses the `pl_node` field. Payload is `As`. AST node could be many things.
        as_node,
        /// Same as `as_node` but ignores runtime to comptime int error.
        as_shift_operand,
        /// Bitwise AND. `&`
        bit_and,
        /// Reinterpret the memory representation of a value as a different type.
        /// Uses the pl_node field with payload `Bin`.
        bitcast,
        /// Bitwise NOT. `~`
        /// Uses `un_node`.
        bit_not,
        /// Bitwise OR. `|`
        bit_or,
        /// A labeled block of code, which can return a value.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block,
        /// Like `block`, but forces full evaluation of its contents at compile-time.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block_comptime,
        /// A list of instructions which are analyzed in the parent context, without
        /// generating a runtime block. Must terminate with an "inline" variant of
        /// a noreturn instruction.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block_inline,
        /// This instruction may only ever appear in the list of declarations for a
        /// namespace type, e.g. within a `struct_decl` instruction. It represents a
        /// single source declaration (`const`/`var`/`fn`), containing the name,
        /// attributes, type, and value of the declaration.
        /// Uses the `pl_node` union field. Payload is `Declaration`.
        declaration,
        /// Implements `suspend {...}`.
        /// Uses the `pl_node` union field. Payload is `Block`.
        suspend_block,
        /// Boolean NOT. See also `bit_not`.
        /// Uses the `un_node` field.
        bool_not,
        /// Short-circuiting boolean `and`. `lhs` is a boolean `Ref` and the other operand
        /// is a block, which is evaluated if `lhs` is `true`.
        /// Uses the `pl_node` union field. Payload is `BoolBr`.
        bool_br_and,
        /// Short-circuiting boolean `or`. `lhs` is a boolean `Ref` and the other operand
        /// is a block, which is evaluated if `lhs` is `false`.
        /// Uses the `pl_node` union field. Payload is `BoolBr`.
        bool_br_or,
        /// Return a value from a block.
        /// Uses the `break` union field.
        /// Uses the source information from previous instruction.
        @"break",
        /// Return a value from a block. This instruction is used as the terminator
        /// of a `block_inline`. It allows using the return value from `Sema.analyzeBody`.
        /// This instruction may also be used when it is known that there is only one
        /// break instruction in a block, and the target block is the parent.
        /// Uses the `break` union field.
        break_inline,
        /// Checks that comptime control flow does not happen inside a runtime block.
        /// Uses the `un_node` union field.
        check_comptime_control_flow,
        /// Function call.
        /// Uses the `pl_node` union field with payload `Call`.
        /// AST node is the function call.
        call,
        /// Function call using `a.b()` syntax.
        /// Uses the named field as the callee. If there is no such field, searches in the type for
        /// a decl matching the field name. The decl is resolved and we ensure that it's a function
        /// which can accept the object as the first parameter, with one pointer fixup. This
        /// function is then used as the callee, with the object as an implicit first parameter.
        /// Uses the `pl_node` union field with payload `FieldCall`.
        /// AST node is the function call.
        field_call,
        /// Implements the `@call` builtin.
        /// Uses the `pl_node` union field with payload `BuiltinCall`.
        /// AST node is the builtin call.
        builtin_call,
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
        /// Conditional branch. Splits control flow based on a boolean condition value.
        /// Uses the `pl_node` union field. AST node is an if, while, for, etc.
        /// Payload is `CondBr`.
        condbr,
        /// Same as `condbr`, except the condition is coerced to a comptime value, and
        /// only the taken branch is analyzed. The then block and else block must
        /// terminate with an "inline" variant of a noreturn instruction.
        condbr_inline,
        /// Given an operand which is an error union, splits control flow. In
        /// case of error, control flow goes into the block that is part of this
        /// instruction, which is guaranteed to end with a return instruction
        /// and never breaks out of the block.
        /// In the case of non-error, control flow proceeds to the next instruction
        /// after the `try`, with the result of this instruction being the unwrapped
        /// payload value, as if `err_union_payload_unsafe` was executed on the operand.
        /// Uses the `pl_node` union field. Payload is `Try`.
        @"try",
        /// Same as `try` except the operand is a pointer and the result is a pointer.
        try_ptr,
        /// An error set type definition. Contains a list of field names.
        /// Uses the `pl_node` union field. Payload is `ErrorSetDecl`.
        error_set_decl,
        error_set_decl_anon,
        error_set_decl_func,
        /// Declares the beginning of a statement. Used for debug info.
        /// Uses the `dbg_stmt` union field. The line and column are offset
        /// from the parent declaration.
        dbg_stmt,
        /// Marks a variable declaration. Used for debug info.
        /// Uses the `str_op` union field. The string is the local variable name,
        /// and the operand is the pointer to the variable's location. The local
        /// may be a const or a var.
        dbg_var_ptr,
        /// Same as `dbg_var_ptr` but the local is always a const and the operand
        /// is the local's value.
        dbg_var_val,
        /// Uses a name to identify a Decl and takes a pointer to it.
        /// Uses the `str_tok` union field.
        decl_ref,
        /// Uses a name to identify a Decl and uses it as a value.
        /// Uses the `str_tok` union field.
        decl_val,
        /// Load the value from a pointer. Assumes `x.*` syntax.
        /// Uses `un_node` field. AST node is the `x.*` syntax.
        load,
        /// Arithmetic division. Asserts no integer overflow.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        div,
        /// Given a pointer to an array, slice, or pointer, returns a pointer to the element at
        /// the provided index.
        /// Uses the `pl_node` union field. AST node is a[b] syntax. Payload is `Bin`.
        elem_ptr_node,
        /// Same as `elem_ptr_node` but used only for for loop.
        /// Uses the `pl_node` union field. AST node is the condition of a for loop.
        /// Payload is `Bin`.
        /// No OOB safety check is emitted.
        elem_ptr,
        /// Given an array, slice, or pointer, returns the element at the provided index.
        /// Uses the `pl_node` union field. AST node is a[b] syntax. Payload is `Bin`.
        elem_val_node,
        /// Same as `elem_val_node` but used only for for loop.
        /// Uses the `pl_node` union field. AST node is the condition of a for loop.
        /// Payload is `Bin`.
        /// No OOB safety check is emitted.
        elem_val,
        /// Same as `elem_val` but takes the index as an immediate value.
        /// No OOB safety check is emitted. A prior instruction must validate this operation.
        /// Uses the `elem_val_imm` union field.
        elem_val_imm,
        /// Emits a compile error if the operand is not `void`.
        /// Uses the `un_node` field.
        ensure_result_used,
        /// Emits a compile error if an error is ignored.
        /// Uses the `un_node` field.
        ensure_result_non_error,
        /// Emits a compile error error union payload is not void.
        ensure_err_union_payload_void,
        /// Create a `E!T` type.
        /// Uses the `pl_node` field with `Bin` payload.
        error_union_type,
        /// `error.Foo` syntax. Uses the `str_tok` field of the Data union.
        error_value,
        /// Implements the `@export` builtin function, based on either an identifier to a Decl,
        /// or field access of a Decl. The thing being exported is the Decl.
        /// Uses the `pl_node` union field. Payload is `Export`.
        @"export",
        /// Implements the `@export` builtin function, based on a comptime-known value.
        /// The thing being exported is the comptime-known value which is the operand.
        /// Uses the `pl_node` union field. Payload is `ExportValue`.
        export_value,
        /// Given a pointer to a struct or object that contains virtual fields, returns a pointer
        /// to the named field. The field name is stored in string_bytes. Used by a.b syntax.
        /// Uses `pl_node` field. The AST node is the a.b syntax. Payload is Field.
        field_ptr,
        /// Given a struct or object that contains virtual fields, returns the named field.
        /// The field name is stored in string_bytes. Used by a.b syntax.
        /// This instruction also accepts a pointer.
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
        /// Returns a function type, or a function instance, depending on whether
        /// the body_len is 0. Calling convention is auto.
        /// Uses the `pl_node` union field. `payload_index` points to a `Func`.
        func,
        /// Same as `func` but has an inferred error set.
        func_inferred,
        /// Represents a function declaration or function prototype, depending on
        /// whether body_len is 0.
        /// Uses the `pl_node` union field. `payload_index` points to a `FuncFancy`.
        func_fancy,
        /// Implements the `@import` builtin.
        /// Uses the `str_tok` field.
        import,
        /// Integer literal that fits in a u64. Uses the `int` union field.
        int,
        /// Arbitrary sized integer literal. Uses the `str` union field.
        int_big,
        /// A float literal that fits in a f64. Uses the float union value.
        float,
        /// A float literal that fits in a f128. Uses the `pl_node` union value.
        /// Payload is `Float128`.
        float128,
        /// Make an integer type out of signedness and bit count.
        /// Payload is `int_type`
        int_type,
        /// Return a boolean false if an optional is null. `x != null`
        /// Uses the `un_node` field.
        is_non_null,
        /// Return a boolean false if an optional is null. `x.* != null`
        /// Uses the `un_node` field.
        is_non_null_ptr,
        /// Return a boolean false if value is an error
        /// Uses the `un_node` field.
        is_non_err,
        /// Return a boolean false if dereferenced pointer is an error
        /// Uses the `un_node` field.
        is_non_err_ptr,
        /// Same as `is_non_er` but doesn't validate that the type can be an error.
        /// Uses the `un_node` field.
        ret_is_non_err,
        /// A labeled block of code that loops forever. At the end of the body will have either
        /// a `repeat` instruction or a `repeat_inline` instruction.
        /// Uses the `pl_node` field. The AST node is either a for loop or while loop.
        /// This ZIR instruction is needed because AIR does not (yet?) match ZIR, and Sema
        /// needs to emit more than 1 AIR block for this instruction.
        /// The payload is `Block`.
        loop,
        /// Sends runtime control flow back to the beginning of the current block.
        /// Uses the `node` field.
        repeat,
        /// Sends comptime control flow back to the beginning of the current block.
        /// Uses the `node` field.
        repeat_inline,
        /// Asserts that all the lengths provided match. Used to build a for loop.
        /// Return value is the length as a usize.
        /// Uses the `pl_node` field with payload `MultiOp`.
        /// There is exactly one item corresponding to each AST node inside the for
        /// loop condition. Any item may be `none`, indicating an unbounded range.
        /// Illegal behaviors:
        ///  * If all lengths are unbounded ranges (always a compile error).
        ///  * If any two lengths do not match each other.
        for_len,
        /// Merge two error sets into one, `E1 || E2`.
        /// Uses the `pl_node` field with payload `Bin`.
        merge_error_sets,
        /// Turns an R-Value into a const L-Value. In other words, it takes a value,
        /// stores it in a memory location, and returns a const pointer to it. If the value
        /// is `comptime`, the memory location is global static constant data. Otherwise,
        /// the memory location is in the stack frame, local to the scope containing the
        /// instruction.
        /// Uses the `un_tok` union field.
        ref,
        /// Sends control flow back to the function's callee.
        /// Includes an operand as the return value.
        /// Includes an AST node source location.
        /// Uses the `un_node` union field.
        ret_node,
        /// Sends control flow back to the function's callee.
        /// The operand is a `ret_ptr` instruction, where the return value can be found.
        /// Includes an AST node source location.
        /// Uses the `un_node` union field.
        ret_load,
        /// Sends control flow back to the function's callee.
        /// Includes an operand as the return value.
        /// Includes a token source location.
        /// Uses the `un_tok` union field.
        ret_implicit,
        /// Sends control flow back to the function's callee.
        /// The return operand is `error.foo` where `foo` is given by the string.
        /// If the current function has an inferred error set, the error given by the
        /// name is added to it.
        /// Uses the `str_tok` union field.
        ret_err_value,
        /// A string name is provided which is an anonymous error set value.
        /// If the current function has an inferred error set, the error given by the
        /// name is added to it.
        /// Results in the error code. Note that control flow is not diverted with
        /// this instruction; a following 'ret' instruction will do the diversion.
        /// Uses the `str_tok` union field.
        ret_err_value_code,
        /// Obtains a pointer to the return value.
        /// Uses the `node` union field.
        ret_ptr,
        /// Obtains the return type of the in-scope function.
        /// Uses the `node` union field.
        ret_type,
        /// Create a pointer type which can have a sentinel, alignment, address space, and/or bit range.
        /// Uses the `ptr_type` union field.
        ptr_type,
        /// Slice operation `lhs[rhs..]`. No sentinel and no end offset.
        /// Returns a pointer to the subslice.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceStart`.
        slice_start,
        /// Slice operation `array_ptr[start..end]`. No sentinel.
        /// Returns a pointer to the subslice.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceEnd`.
        slice_end,
        /// Slice operation `array_ptr[start..end:sentinel]`.
        /// Returns a pointer to the subslice.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceSentinel`.
        slice_sentinel,
        /// Slice operation `array_ptr[start..][0..len]`. Optional sentinel.
        /// Returns a pointer to the subslice.
        /// Uses the `pl_node` field. AST node is the slice syntax. Payload is `SliceLength`.
        slice_length,
        /// Same as `store` except provides a source location.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        store_node,
        /// Same as `store_node` but the type of the value being stored will be
        /// used to infer the pointer type of an `alloc_inferred`.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        store_to_inferred_ptr,
        /// String Literal. Makes an anonymous Decl and then takes a pointer to it.
        /// Uses the `str` union field.
        str,
        /// Arithmetic negation. Asserts no integer overflow.
        /// Same as sub with a lhs of 0, split into a separate instruction to save memory.
        /// Uses `un_node`.
        negate,
        /// Twos complement wrapping integer negation.
        /// Same as subwrap with a lhs of 0, split into a separate instruction to save memory.
        /// Uses `un_node`.
        negate_wrap,
        /// Returns the type of a value.
        /// Uses the `un_node` field.
        typeof,
        /// Implements `@TypeOf` for one operand.
        /// Uses the `pl_node` field.
        typeof_builtin,
        /// Given a value, look at the type of it, which must be an integer type.
        /// Returns the integer type for the RHS of a shift operation.
        /// Uses the `un_node` field.
        typeof_log2_int_type,
        /// Asserts control-flow will not reach this instruction (`unreachable`).
        /// Uses the `@"unreachable"` union field.
        @"unreachable",
        /// Bitwise XOR. `^`
        /// Uses the `pl_node` union field. Payload is `Bin`.
        xor,
        /// Create an optional type '?T'
        /// Uses the `un_node` field.
        optional_type,
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
        /// E!T => T without safety.
        /// Given an error union value, returns the payload value. No safety checks.
        /// Uses the `un_node` field.
        err_union_payload_unsafe,
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
        /// An enum literal. Uses the `str_tok` union field.
        enum_literal,
        /// A switch expression. Uses the `pl_node` union field.
        /// AST node is the switch, payload is `SwitchBlock`.
        switch_block,
        /// A switch expression. Uses the `pl_node` union field.
        /// AST node is the switch, payload is `SwitchBlock`. Operand is a pointer.
        switch_block_ref,
        /// A switch on an error union `a catch |err| switch (err) {...}`.
        /// Uses the `pl_node` union field. AST node is the `catch`, payload is `SwitchBlockErrUnion`.
        switch_block_err_union,
        /// Check that operand type supports the dereference operand (.*).
        /// Uses the `un_node` field.
        validate_deref,
        /// Check that the operand's type is an array or tuple with the given number of elements.
        /// Uses the `pl_node` field. Payload is `ValidateDestructure`.
        validate_destructure,
        /// Given a struct or union, and a field name as a Ref,
        /// returns the field type. Uses the `pl_node` field. Payload is `FieldTypeRef`.
        field_type_ref,
        /// Given a pointer, initializes all error unions and optionals in the pointee to payloads,
        /// returning the base payload pointer. For instance, converts *E!?T into a valid *T
        /// (clobbering any existing error or null value).
        /// Uses the `un_node` field.
        opt_eu_base_ptr_init,
        /// Coerce a given value such that when a reference is taken, the resulting pointer will be
        /// coercible to the given type. For instance, given a value of type 'u32' and the pointer
        /// type '*u64', coerces the value to a 'u64'. Asserts that the type is a pointer type.
        /// Uses the `pl_node` field. Payload is `Bin`.
        /// LHS is the pointer type, RHS is the value.
        coerce_ptr_elem_ty,
        /// Given a type, validate that it is a pointer type suitable for return from the address-of
        /// operator. Emit a compile error if not.
        /// Uses the `un_tok` union field. Token is the `&` operator. Operand is the type.
        validate_ref_ty,

        // The following tags all relate to struct initialization expressions.

        /// A struct literal with a specified explicit type, with no fields.
        /// Uses the `un_node` field.
        struct_init_empty,
        /// An anonymous struct literal with a known result type, with no fields.
        /// Uses the `un_node` field.
        struct_init_empty_result,
        /// An anonymous struct literal with no fields, returned by reference, with a known result
        /// type for the pointer. Asserts that the type is a pointer.
        /// Uses the `un_node` field.
        struct_init_empty_ref_result,
        /// Struct initialization without a type. Creates a value of an anonymous struct type.
        /// Uses the `pl_node` field. Payload is `StructInitAnon`.
        struct_init_anon,
        /// Finalizes a typed struct or union initialization, performs validation, and returns the
        /// struct or union value. The given type must be validated prior to this instruction, using
        /// `validate_struct_init_ty` or `validate_struct_init_result_ty`. If the given type is
        /// generic poison, this is downgraded to an anonymous initialization.
        /// Uses the `pl_node` field. Payload is `StructInit`.
        struct_init,
        /// Struct initialization syntax, make the result a pointer. Equivalent to `struct_init`
        /// followed by `ref` - this ZIR tag exists as an optimization for a common pattern.
        /// Uses the `pl_node` field. Payload is `StructInit`.
        struct_init_ref,
        /// Checks that the type supports struct init syntax. Always returns void.
        /// Uses the `un_node` field.
        validate_struct_init_ty,
        /// Like `validate_struct_init_ty`, but additionally accepts types which structs coerce to.
        /// Used on the known result type of a struct init expression. Always returns void.
        /// Uses the `un_node` field.
        validate_struct_init_result_ty,
        /// Given a set of `struct_init_field_ptr` instructions, assumes they are all part of a
        /// struct initialization expression, and emits compile errors for duplicate fields as well
        /// as missing fields, if applicable.
        /// This instruction asserts that there is at least one struct_init_field_ptr instruction,
        /// because it must use one of them to find out the struct type.
        /// Uses the `pl_node` field. Payload is `Block`.
        validate_ptr_struct_init,
        /// Given a type being used for a struct initialization expression, returns the type of the
        /// field with the given name.
        /// Uses the `pl_node` field. Payload is `FieldType`.
        struct_init_field_type,
        /// Given a pointer being used as the result pointer of a struct initialization expression,
        /// return a pointer to the field of the given name.
        /// Uses the `pl_node` field. The AST node is the field initializer. Payload is Field.
        struct_init_field_ptr,

        // The following tags all relate to array initialization expressions.

        /// Array initialization without a type. Creates a value of a tuple type.
        /// Uses the `pl_node` field. Payload is `MultiOp`.
        array_init_anon,
        /// Array initialization syntax with a known type. The given type must be validated prior to
        /// this instruction, using some `validate_array_init_*_ty` instruction.
        /// Uses the `pl_node` field. Payload is `MultiOp`, where the first operand is the type.
        array_init,
        /// Array initialization syntax, make the result a pointer. Equivalent to `array_init`
        /// followed by `ref`- this ZIR tag exists as an optimization for a common pattern.
        /// Uses the `pl_node` field. Payload is `MultiOp`, where the first operand is the type.
        array_init_ref,
        /// Checks that the type supports array init syntax. Always returns void.
        /// Uses the `pl_node` field. Payload is `ArrayInit`.
        validate_array_init_ty,
        /// Like `validate_array_init_ty`, but additionally accepts types which arrays coerce to.
        /// Used on the known result type of an array init expression. Always returns void.
        /// Uses the `pl_node` field. Payload is `ArrayInit`.
        validate_array_init_result_ty,
        /// Given a pointer or slice type and an element count, return the expected type of an array
        /// initializer such that a pointer to the initializer has the given pointer type, checking
        /// that this type supports array init syntax and emitting a compile error if not. Preserves
        /// error union and optional wrappers on the array type, if any.
        /// Asserts that the given type is a pointer or slice type.
        /// Uses the `pl_node` field. Payload is `ArrayInitRefTy`.
        validate_array_init_ref_ty,
        /// Given a set of `array_init_elem_ptr` instructions, assumes they are all part of an array
        /// initialization expression, and emits a compile error if the number of elements does not
        /// match the array type.
        /// This instruction asserts that there is at least one `array_init_elem_ptr` instruction,
        /// because it must use one of them to find out the array type.
        /// Uses the `pl_node` field. Payload is `Block`.
        validate_ptr_array_init,
        /// Given a type being used for an array initialization expression, returns the type of the
        /// element at the given index.
        /// Uses the `bin` union field. lhs is the indexable type, rhs is the index.
        array_init_elem_type,
        /// Given a pointer being used as the result pointer of an array initialization expression,
        /// return a pointer to the element at the given index.
        /// Uses the `pl_node` union field. AST node is an element inside array initialization
        /// syntax. Payload is `ElemPtrImm`.
        array_init_elem_ptr,

        /// Implements the `@unionInit` builtin.
        /// Uses the `pl_node` field. Payload is `UnionInit`.
        union_init,
        /// Implements the `@typeInfo` builtin. Uses `un_node`.
        type_info,
        /// Implements the `@sizeOf` builtin. Uses `un_node`.
        size_of,
        /// Implements the `@bitSizeOf` builtin. Uses `un_node`.
        bit_size_of,

        /// Implement builtin `@intFromPtr`. Uses `un_node`.
        /// Convert a pointer to a `usize` integer.
        int_from_ptr,
        /// Emit an error message and fail compilation.
        /// Uses the `un_node` field.
        compile_error,
        /// Changes the maximum number of backwards branches that compile-time
        /// code execution can use before giving up and making a compile error.
        /// Uses the `un_node` union field.
        set_eval_branch_quota,
        /// Converts an enum value into an integer. Resulting type will be the tag type
        /// of the enum. Uses `un_node`.
        int_from_enum,
        /// Implement builtin `@alignOf`. Uses `un_node`.
        align_of,
        /// Implement builtin `@intFromBool`. Uses `un_node`.
        int_from_bool,
        /// Implement builtin `@embedFile`. Uses `un_node`.
        embed_file,
        /// Implement builtin `@errorName`. Uses `un_node`.
        error_name,
        /// Implement builtin `@panic`. Uses `un_node`.
        panic,
        /// Implements `@trap`.
        /// Uses the `node` field.
        trap,
        /// Implement builtin `@setRuntimeSafety`. Uses `un_node`.
        set_runtime_safety,
        /// Implement builtin `@sqrt`. Uses `un_node`.
        sqrt,
        /// Implement builtin `@sin`. Uses `un_node`.
        sin,
        /// Implement builtin `@cos`. Uses `un_node`.
        cos,
        /// Implement builtin `@tan`. Uses `un_node`.
        tan,
        /// Implement builtin `@exp`. Uses `un_node`.
        exp,
        /// Implement builtin `@exp2`. Uses `un_node`.
        exp2,
        /// Implement builtin `@log`. Uses `un_node`.
        log,
        /// Implement builtin `@log2`. Uses `un_node`.
        log2,
        /// Implement builtin `@log10`. Uses `un_node`.
        log10,
        /// Implement builtin `@abs`. Uses `un_node`.
        abs,
        /// Implement builtin `@floor`. Uses `un_node`.
        floor,
        /// Implement builtin `@ceil`. Uses `un_node`.
        ceil,
        /// Implement builtin `@trunc`. Uses `un_node`.
        trunc,
        /// Implement builtin `@round`. Uses `un_node`.
        round,
        /// Implement builtin `@tagName`. Uses `un_node`.
        tag_name,
        /// Implement builtin `@typeName`. Uses `un_node`.
        type_name,
        /// Implement builtin `@Frame`. Uses `un_node`.
        frame_type,
        /// Implement builtin `@frameSize`. Uses `un_node`.
        frame_size,

        /// Implements the `@intFromFloat` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        int_from_float,
        /// Implements the `@floatFromInt` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        float_from_int,
        /// Implements the `@ptrFromInt` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        ptr_from_int,
        /// Converts an integer into an enum value.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        enum_from_int,
        /// Convert a larger float type to any other float type, possibly causing
        /// a loss of precision.
        /// Uses the `pl_node` field. AST is the `@floatCast` syntax.
        /// Payload is `Bin` with lhs as the dest type, rhs the operand.
        float_cast,
        /// Implements the `@intCast` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        /// Convert an integer value to another integer type, asserting that the destination type
        /// can hold the same mathematical value.
        int_cast,
        /// Implements the `@ptrCast` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        /// Not every `@ptrCast` will correspond to this instruction - see also
        /// `ptr_cast_full` in `Extended`.
        ptr_cast,
        /// Implements the `@truncate` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        truncate,

        /// Implements the `@hasDecl` builtin.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        has_decl,
        /// Implements the `@hasField` builtin.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        has_field,

        /// Implements the `@clz` builtin. Uses the `un_node` union field.
        clz,
        /// Implements the `@ctz` builtin. Uses the `un_node` union field.
        ctz,
        /// Implements the `@popCount` builtin. Uses the `un_node` union field.
        pop_count,
        /// Implements the `@byteSwap` builtin. Uses the `un_node` union field.
        byte_swap,
        /// Implements the `@bitReverse` builtin. Uses the `un_node` union field.
        bit_reverse,

        /// Implements the `@bitOffsetOf` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        bit_offset_of,
        /// Implements the `@offsetOf` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        offset_of,
        /// Implements the `@splat` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        splat,
        /// Implements the `@reduce` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        reduce,
        /// Implements the `@shuffle` builtin.
        /// Uses the `pl_node` union field with payload `Shuffle`.
        shuffle,
        /// Implements the `@atomicLoad` builtin.
        /// Uses the `pl_node` union field with payload `AtomicLoad`.
        atomic_load,
        /// Implements the `@atomicRmw` builtin.
        /// Uses the `pl_node` union field with payload `AtomicRmw`.
        atomic_rmw,
        /// Implements the `@atomicStore` builtin.
        /// Uses the `pl_node` union field with payload `AtomicStore`.
        atomic_store,
        /// Implements the `@mulAdd` builtin.
        /// Uses the `pl_node` union field with payload `MulAdd`.
        /// The addend communicates the type of the builtin.
        /// The mulends need to be coerced to the same type.
        mul_add,
        /// Implements the `@memcpy` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        memcpy,
        /// Implements the `@memset` builtin.
        /// Uses the `pl_node` union field with payload `Bin`.
        memset,
        /// Implements the `@min` builtin for 2 args.
        /// Uses the `pl_node` union field with payload `Bin`
        min,
        /// Implements the `@max` builtin for 2 args.
        /// Uses the `pl_node` union field with payload `Bin`
        max,
        /// Implements the `@cImport` builtin.
        /// Uses the `pl_node` union field with payload `Block`.
        c_import,

        /// Allocates stack local memory.
        /// Uses the `un_node` union field. The operand is the type of the allocated object.
        /// The node source location points to a var decl node.
        /// A `make_ptr_const` instruction should be used once the value has
        /// been stored to the allocation. To ensure comptime value detection
        /// functions, there are some restrictions on how this pointer should be
        /// used prior to the `make_ptr_const` instruction: no pointer derived
        /// from this `alloc` may be returned from a block or stored to another
        /// address. In other words, it must be trivial to determine whether any
        /// given pointer derives from this one.
        alloc,
        /// Same as `alloc` except mutable. As such, `make_ptr_const` need not be used,
        /// and there are no restrictions on the usage of the pointer.
        alloc_mut,
        /// Allocates comptime-mutable memory.
        /// Uses the `un_node` union field. The operand is the type of the allocated object.
        /// The node source location points to a var decl node.
        alloc_comptime_mut,
        /// Same as `alloc` except the type is inferred.
        /// Uses the `node` union field.
        alloc_inferred,
        /// Same as `alloc_inferred` except mutable.
        alloc_inferred_mut,
        /// Allocates comptime const memory.
        /// Uses the `node` union field. The type of the allocated object is inferred.
        /// The node source location points to a var decl node.
        alloc_inferred_comptime,
        /// Same as `alloc_comptime_mut` except the type is inferred.
        alloc_inferred_comptime_mut,
        /// Each `store_to_inferred_ptr` puts the type of the stored value into a set,
        /// and then `resolve_inferred_alloc` triggers peer type resolution on the set.
        /// The operand is a `alloc_inferred` or `alloc_inferred_mut` instruction, which
        /// is the allocation that needs to have its type inferred.
        /// Uses the `un_node` field. The AST node is the var decl.
        resolve_inferred_alloc,
        /// Turns a pointer coming from an `alloc` or `Extended.alloc` into a constant
        /// version of the same pointer. For inferred allocations this is instead implicitly
        /// handled by the `resolve_inferred_alloc` instruction.
        /// Uses the `un_node` union field.
        make_ptr_const,

        /// Implements `resume` syntax. Uses `un_node` field.
        @"resume",
        @"await",

        /// A defer statement.
        /// Uses the `defer` union field.
        @"defer",
        /// An errdefer statement with a code.
        /// Uses the `err_defer_code` union field.
        defer_err_code,

        /// Requests that Sema update the saved error return trace index for the enclosing
        /// block, if the operand is .none or of an error/error-union type.
        /// Uses the `save_err_ret_index` field.
        save_err_ret_index,
        /// Specialized form of `Extended.restore_err_ret_index`.
        /// Unconditionally restores the error return index to its last saved state
        /// in the block referred to by `operand`. If `operand` is `none`, restores
        /// to the point of function entry.
        /// Uses the `un_node` field.
        restore_err_ret_index_unconditional,
        /// Specialized form of `Extended.restore_err_ret_index`.
        /// Restores the error return index to its state at the entry of
        /// the current function conditional on `operand` being a non-error.
        /// If `operand` is `none`, restores unconditionally.
        /// Uses the `un_node` field.
        restore_err_ret_index_fn_entry,

        /// The ZIR instruction tag is one of the `Extended` ones.
        /// Uses the `extended` union field.
        extended,

        /// Returns whether the instruction is one of the control flow "noreturn" types.
        /// Function calls do not count.
        pub fn isNoReturn(tag: Tag) bool {
            return switch (tag) {
                .param,
                .param_comptime,
                .param_anytype,
                .param_anytype_comptime,
                .add,
                .addwrap,
                .add_sat,
                .add_unsafe,
                .alloc,
                .alloc_mut,
                .alloc_comptime_mut,
                .alloc_inferred,
                .alloc_inferred_mut,
                .alloc_inferred_comptime,
                .alloc_inferred_comptime_mut,
                .make_ptr_const,
                .array_cat,
                .array_mul,
                .array_type,
                .array_type_sentinel,
                .vector_type,
                .elem_type,
                .indexable_ptr_elem_type,
                .vector_elem_type,
                .indexable_ptr_len,
                .anyframe_type,
                .as_node,
                .as_shift_operand,
                .bit_and,
                .bitcast,
                .bit_or,
                .block,
                .block_comptime,
                .block_inline,
                .declaration,
                .suspend_block,
                .loop,
                .bool_br_and,
                .bool_br_or,
                .bool_not,
                .call,
                .field_call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .error_set_decl,
                .error_set_decl_anon,
                .error_set_decl_func,
                .dbg_stmt,
                .dbg_var_ptr,
                .dbg_var_val,
                .decl_ref,
                .decl_val,
                .load,
                .div,
                .elem_ptr,
                .elem_val,
                .elem_ptr_node,
                .elem_val_node,
                .elem_val_imm,
                .ensure_result_used,
                .ensure_result_non_error,
                .ensure_err_union_payload_void,
                .@"export",
                .export_value,
                .field_ptr,
                .field_val,
                .field_ptr_named,
                .field_val_named,
                .func,
                .func_inferred,
                .func_fancy,
                .has_decl,
                .int,
                .int_big,
                .float,
                .float128,
                .int_type,
                .is_non_null,
                .is_non_null_ptr,
                .is_non_err,
                .is_non_err_ptr,
                .ret_is_non_err,
                .mod_rem,
                .mul,
                .mulwrap,
                .mul_sat,
                .ref,
                .shl,
                .shl_sat,
                .shr,
                .store_node,
                .store_to_inferred_ptr,
                .str,
                .sub,
                .subwrap,
                .sub_sat,
                .negate,
                .negate_wrap,
                .typeof,
                .typeof_builtin,
                .xor,
                .optional_type,
                .optional_payload_safe,
                .optional_payload_unsafe,
                .optional_payload_safe_ptr,
                .optional_payload_unsafe_ptr,
                .err_union_payload_unsafe,
                .err_union_payload_unsafe_ptr,
                .err_union_code,
                .err_union_code_ptr,
                .ptr_type,
                .enum_literal,
                .merge_error_sets,
                .error_union_type,
                .bit_not,
                .error_value,
                .slice_start,
                .slice_end,
                .slice_sentinel,
                .slice_length,
                .import,
                .typeof_log2_int_type,
                .resolve_inferred_alloc,
                .set_eval_branch_quota,
                .switch_block,
                .switch_block_ref,
                .switch_block_err_union,
                .validate_deref,
                .validate_destructure,
                .union_init,
                .field_type_ref,
                .enum_from_int,
                .int_from_enum,
                .type_info,
                .size_of,
                .bit_size_of,
                .int_from_ptr,
                .align_of,
                .int_from_bool,
                .embed_file,
                .error_name,
                .set_runtime_safety,
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
                .trunc,
                .round,
                .tag_name,
                .type_name,
                .frame_type,
                .frame_size,
                .int_from_float,
                .float_from_int,
                .ptr_from_int,
                .float_cast,
                .int_cast,
                .ptr_cast,
                .truncate,
                .has_field,
                .clz,
                .ctz,
                .pop_count,
                .byte_swap,
                .bit_reverse,
                .div_exact,
                .div_floor,
                .div_trunc,
                .mod,
                .rem,
                .shl_exact,
                .shr_exact,
                .bit_offset_of,
                .offset_of,
                .splat,
                .reduce,
                .shuffle,
                .atomic_load,
                .atomic_rmw,
                .atomic_store,
                .mul_add,
                .builtin_call,
                .max,
                .memcpy,
                .memset,
                .min,
                .c_import,
                .@"resume",
                .@"await",
                .ret_err_value_code,
                .extended,
                .ret_ptr,
                .ret_type,
                .@"try",
                .try_ptr,
                .@"defer",
                .defer_err_code,
                .save_err_ret_index,
                .for_len,
                .opt_eu_base_ptr_init,
                .coerce_ptr_elem_ty,
                .struct_init_empty,
                .struct_init_empty_result,
                .struct_init_empty_ref_result,
                .struct_init_anon,
                .struct_init,
                .struct_init_ref,
                .validate_struct_init_ty,
                .validate_struct_init_result_ty,
                .validate_ptr_struct_init,
                .struct_init_field_type,
                .struct_init_field_ptr,
                .array_init_anon,
                .array_init,
                .array_init_ref,
                .validate_array_init_ty,
                .validate_array_init_result_ty,
                .validate_array_init_ref_ty,
                .validate_ptr_array_init,
                .array_init_elem_type,
                .array_init_elem_ptr,
                .validate_ref_ty,
                .restore_err_ret_index_unconditional,
                .restore_err_ret_index_fn_entry,
                => false,

                .@"break",
                .break_inline,
                .condbr,
                .condbr_inline,
                .compile_error,
                .ret_node,
                .ret_load,
                .ret_implicit,
                .ret_err_value,
                .@"unreachable",
                .repeat,
                .repeat_inline,
                .panic,
                .trap,
                .check_comptime_control_flow,
                => true,
            };
        }

        pub fn isParam(tag: Tag) bool {
            return switch (tag) {
                .param,
                .param_comptime,
                .param_anytype,
                .param_anytype_comptime,
                => true,

                else => false,
            };
        }

        /// AstGen uses this to find out if `Ref.void_value` should be used in place
        /// of the result of a given instruction. This allows Sema to forego adding
        /// the instruction to the map after analysis.
        pub fn isAlwaysVoid(tag: Tag, data: Data) bool {
            return switch (tag) {
                .dbg_stmt,
                .dbg_var_ptr,
                .dbg_var_val,
                .ensure_result_used,
                .ensure_result_non_error,
                .ensure_err_union_payload_void,
                .set_eval_branch_quota,
                .atomic_store,
                .store_node,
                .store_to_inferred_ptr,
                .resolve_inferred_alloc,
                .validate_deref,
                .validate_destructure,
                .@"export",
                .export_value,
                .set_runtime_safety,
                .memcpy,
                .memset,
                .check_comptime_control_flow,
                .@"defer",
                .defer_err_code,
                .save_err_ret_index,
                .restore_err_ret_index_unconditional,
                .restore_err_ret_index_fn_entry,
                .validate_struct_init_ty,
                .validate_struct_init_result_ty,
                .validate_ptr_struct_init,
                .validate_array_init_ty,
                .validate_array_init_result_ty,
                .validate_ptr_array_init,
                .validate_ref_ty,
                => true,

                .param,
                .param_comptime,
                .param_anytype,
                .param_anytype_comptime,
                .add,
                .addwrap,
                .add_sat,
                .add_unsafe,
                .alloc,
                .alloc_mut,
                .alloc_comptime_mut,
                .alloc_inferred,
                .alloc_inferred_mut,
                .alloc_inferred_comptime,
                .alloc_inferred_comptime_mut,
                .make_ptr_const,
                .array_cat,
                .array_mul,
                .array_type,
                .array_type_sentinel,
                .vector_type,
                .elem_type,
                .indexable_ptr_elem_type,
                .vector_elem_type,
                .indexable_ptr_len,
                .anyframe_type,
                .as_node,
                .as_shift_operand,
                .bit_and,
                .bitcast,
                .bit_or,
                .block,
                .block_comptime,
                .block_inline,
                .declaration,
                .suspend_block,
                .loop,
                .bool_br_and,
                .bool_br_or,
                .bool_not,
                .call,
                .field_call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .error_set_decl,
                .error_set_decl_anon,
                .error_set_decl_func,
                .decl_ref,
                .decl_val,
                .load,
                .div,
                .elem_ptr,
                .elem_val,
                .elem_ptr_node,
                .elem_val_node,
                .elem_val_imm,
                .field_ptr,
                .field_val,
                .field_ptr_named,
                .field_val_named,
                .func,
                .func_inferred,
                .func_fancy,
                .has_decl,
                .int,
                .int_big,
                .float,
                .float128,
                .int_type,
                .is_non_null,
                .is_non_null_ptr,
                .is_non_err,
                .is_non_err_ptr,
                .ret_is_non_err,
                .mod_rem,
                .mul,
                .mulwrap,
                .mul_sat,
                .ref,
                .shl,
                .shl_sat,
                .shr,
                .str,
                .sub,
                .subwrap,
                .sub_sat,
                .negate,
                .negate_wrap,
                .typeof,
                .typeof_builtin,
                .xor,
                .optional_type,
                .optional_payload_safe,
                .optional_payload_unsafe,
                .optional_payload_safe_ptr,
                .optional_payload_unsafe_ptr,
                .err_union_payload_unsafe,
                .err_union_payload_unsafe_ptr,
                .err_union_code,
                .err_union_code_ptr,
                .ptr_type,
                .enum_literal,
                .merge_error_sets,
                .error_union_type,
                .bit_not,
                .error_value,
                .slice_start,
                .slice_end,
                .slice_sentinel,
                .slice_length,
                .import,
                .typeof_log2_int_type,
                .switch_block,
                .switch_block_ref,
                .switch_block_err_union,
                .union_init,
                .field_type_ref,
                .enum_from_int,
                .int_from_enum,
                .type_info,
                .size_of,
                .bit_size_of,
                .int_from_ptr,
                .align_of,
                .int_from_bool,
                .embed_file,
                .error_name,
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
                .trunc,
                .round,
                .tag_name,
                .type_name,
                .frame_type,
                .frame_size,
                .int_from_float,
                .float_from_int,
                .ptr_from_int,
                .float_cast,
                .int_cast,
                .ptr_cast,
                .truncate,
                .has_field,
                .clz,
                .ctz,
                .pop_count,
                .byte_swap,
                .bit_reverse,
                .div_exact,
                .div_floor,
                .div_trunc,
                .mod,
                .rem,
                .shl_exact,
                .shr_exact,
                .bit_offset_of,
                .offset_of,
                .splat,
                .reduce,
                .shuffle,
                .atomic_load,
                .atomic_rmw,
                .mul_add,
                .builtin_call,
                .max,
                .min,
                .c_import,
                .@"resume",
                .@"await",
                .ret_err_value_code,
                .@"break",
                .break_inline,
                .condbr,
                .condbr_inline,
                .compile_error,
                .ret_node,
                .ret_load,
                .ret_implicit,
                .ret_err_value,
                .ret_ptr,
                .ret_type,
                .@"unreachable",
                .repeat,
                .repeat_inline,
                .panic,
                .trap,
                .for_len,
                .@"try",
                .try_ptr,
                .opt_eu_base_ptr_init,
                .coerce_ptr_elem_ty,
                .struct_init_empty,
                .struct_init_empty_result,
                .struct_init_empty_ref_result,
                .struct_init_anon,
                .struct_init,
                .struct_init_ref,
                .struct_init_field_type,
                .struct_init_field_ptr,
                .array_init_anon,
                .array_init,
                .array_init_ref,
                .validate_array_init_ref_ty,
                .array_init_elem_type,
                .array_init_elem_ptr,
                => false,

                .extended => switch (data.extended.opcode) {
                    .fence, .set_cold, .breakpoint => true,
                    else => false,
                },
            };
        }

        /// Used by debug safety-checking code.
        pub const data_tags = list: {
            @setEvalBranchQuota(2000);
            break :list std.enums.directEnumArray(Tag, Data.FieldEnum, 0, .{
                .add = .pl_node,
                .addwrap = .pl_node,
                .add_sat = .pl_node,
                .add_unsafe = .pl_node,
                .sub = .pl_node,
                .subwrap = .pl_node,
                .sub_sat = .pl_node,
                .mul = .pl_node,
                .mulwrap = .pl_node,
                .mul_sat = .pl_node,

                .param = .pl_tok,
                .param_comptime = .pl_tok,
                .param_anytype = .str_tok,
                .param_anytype_comptime = .str_tok,
                .array_cat = .pl_node,
                .array_mul = .pl_node,
                .array_type = .pl_node,
                .array_type_sentinel = .pl_node,
                .vector_type = .pl_node,
                .elem_type = .un_node,
                .indexable_ptr_elem_type = .un_node,
                .vector_elem_type = .un_node,
                .indexable_ptr_len = .un_node,
                .anyframe_type = .un_node,
                .as_node = .pl_node,
                .as_shift_operand = .pl_node,
                .bit_and = .pl_node,
                .bitcast = .pl_node,
                .bit_not = .un_node,
                .bit_or = .pl_node,
                .block = .pl_node,
                .block_comptime = .pl_node,
                .block_inline = .pl_node,
                .declaration = .pl_node,
                .suspend_block = .pl_node,
                .bool_not = .un_node,
                .bool_br_and = .pl_node,
                .bool_br_or = .pl_node,
                .@"break" = .@"break",
                .break_inline = .@"break",
                .check_comptime_control_flow = .un_node,
                .for_len = .pl_node,
                .call = .pl_node,
                .field_call = .pl_node,
                .cmp_lt = .pl_node,
                .cmp_lte = .pl_node,
                .cmp_eq = .pl_node,
                .cmp_gte = .pl_node,
                .cmp_gt = .pl_node,
                .cmp_neq = .pl_node,
                .condbr = .pl_node,
                .condbr_inline = .pl_node,
                .@"try" = .pl_node,
                .try_ptr = .pl_node,
                .error_set_decl = .pl_node,
                .error_set_decl_anon = .pl_node,
                .error_set_decl_func = .pl_node,
                .dbg_stmt = .dbg_stmt,
                .dbg_var_ptr = .str_op,
                .dbg_var_val = .str_op,
                .decl_ref = .str_tok,
                .decl_val = .str_tok,
                .load = .un_node,
                .div = .pl_node,
                .elem_ptr = .pl_node,
                .elem_ptr_node = .pl_node,
                .elem_val = .pl_node,
                .elem_val_node = .pl_node,
                .elem_val_imm = .elem_val_imm,
                .ensure_result_used = .un_node,
                .ensure_result_non_error = .un_node,
                .ensure_err_union_payload_void = .un_node,
                .error_union_type = .pl_node,
                .error_value = .str_tok,
                .@"export" = .pl_node,
                .export_value = .pl_node,
                .field_ptr = .pl_node,
                .field_val = .pl_node,
                .field_ptr_named = .pl_node,
                .field_val_named = .pl_node,
                .func = .pl_node,
                .func_inferred = .pl_node,
                .func_fancy = .pl_node,
                .import = .str_tok,
                .int = .int,
                .int_big = .str,
                .float = .float,
                .float128 = .pl_node,
                .int_type = .int_type,
                .is_non_null = .un_node,
                .is_non_null_ptr = .un_node,
                .is_non_err = .un_node,
                .is_non_err_ptr = .un_node,
                .ret_is_non_err = .un_node,
                .loop = .pl_node,
                .repeat = .node,
                .repeat_inline = .node,
                .merge_error_sets = .pl_node,
                .mod_rem = .pl_node,
                .ref = .un_tok,
                .ret_node = .un_node,
                .ret_load = .un_node,
                .ret_implicit = .un_tok,
                .ret_err_value = .str_tok,
                .ret_err_value_code = .str_tok,
                .ret_ptr = .node,
                .ret_type = .node,
                .ptr_type = .ptr_type,
                .slice_start = .pl_node,
                .slice_end = .pl_node,
                .slice_sentinel = .pl_node,
                .slice_length = .pl_node,
                .store_node = .pl_node,
                .store_to_inferred_ptr = .pl_node,
                .str = .str,
                .negate = .un_node,
                .negate_wrap = .un_node,
                .typeof = .un_node,
                .typeof_log2_int_type = .un_node,
                .@"unreachable" = .@"unreachable",
                .xor = .pl_node,
                .optional_type = .un_node,
                .optional_payload_safe = .un_node,
                .optional_payload_unsafe = .un_node,
                .optional_payload_safe_ptr = .un_node,
                .optional_payload_unsafe_ptr = .un_node,
                .err_union_payload_unsafe = .un_node,
                .err_union_payload_unsafe_ptr = .un_node,
                .err_union_code = .un_node,
                .err_union_code_ptr = .un_node,
                .enum_literal = .str_tok,
                .switch_block = .pl_node,
                .switch_block_ref = .pl_node,
                .switch_block_err_union = .pl_node,
                .validate_deref = .un_node,
                .validate_destructure = .pl_node,
                .field_type_ref = .pl_node,
                .union_init = .pl_node,
                .type_info = .un_node,
                .size_of = .un_node,
                .bit_size_of = .un_node,
                .opt_eu_base_ptr_init = .un_node,
                .coerce_ptr_elem_ty = .pl_node,
                .validate_ref_ty = .un_tok,

                .int_from_ptr = .un_node,
                .compile_error = .un_node,
                .set_eval_branch_quota = .un_node,
                .int_from_enum = .un_node,
                .align_of = .un_node,
                .int_from_bool = .un_node,
                .embed_file = .un_node,
                .error_name = .un_node,
                .panic = .un_node,
                .trap = .node,
                .set_runtime_safety = .un_node,
                .sqrt = .un_node,
                .sin = .un_node,
                .cos = .un_node,
                .tan = .un_node,
                .exp = .un_node,
                .exp2 = .un_node,
                .log = .un_node,
                .log2 = .un_node,
                .log10 = .un_node,
                .abs = .un_node,
                .floor = .un_node,
                .ceil = .un_node,
                .trunc = .un_node,
                .round = .un_node,
                .tag_name = .un_node,
                .type_name = .un_node,
                .frame_type = .un_node,
                .frame_size = .un_node,

                .int_from_float = .pl_node,
                .float_from_int = .pl_node,
                .ptr_from_int = .pl_node,
                .enum_from_int = .pl_node,
                .float_cast = .pl_node,
                .int_cast = .pl_node,
                .ptr_cast = .pl_node,
                .truncate = .pl_node,
                .typeof_builtin = .pl_node,

                .has_decl = .pl_node,
                .has_field = .pl_node,

                .clz = .un_node,
                .ctz = .un_node,
                .pop_count = .un_node,
                .byte_swap = .un_node,
                .bit_reverse = .un_node,

                .div_exact = .pl_node,
                .div_floor = .pl_node,
                .div_trunc = .pl_node,
                .mod = .pl_node,
                .rem = .pl_node,

                .shl = .pl_node,
                .shl_exact = .pl_node,
                .shl_sat = .pl_node,
                .shr = .pl_node,
                .shr_exact = .pl_node,

                .bit_offset_of = .pl_node,
                .offset_of = .pl_node,
                .splat = .pl_node,
                .reduce = .pl_node,
                .shuffle = .pl_node,
                .atomic_load = .pl_node,
                .atomic_rmw = .pl_node,
                .atomic_store = .pl_node,
                .mul_add = .pl_node,
                .builtin_call = .pl_node,
                .max = .pl_node,
                .memcpy = .pl_node,
                .memset = .pl_node,
                .min = .pl_node,
                .c_import = .pl_node,

                .alloc = .un_node,
                .alloc_mut = .un_node,
                .alloc_comptime_mut = .un_node,
                .alloc_inferred = .node,
                .alloc_inferred_mut = .node,
                .alloc_inferred_comptime = .node,
                .alloc_inferred_comptime_mut = .node,
                .resolve_inferred_alloc = .un_node,
                .make_ptr_const = .un_node,

                .@"resume" = .un_node,
                .@"await" = .un_node,

                .@"defer" = .@"defer",
                .defer_err_code = .defer_err_code,

                .save_err_ret_index = .save_err_ret_index,
                .restore_err_ret_index_unconditional = .un_node,
                .restore_err_ret_index_fn_entry = .un_node,

                .struct_init_empty = .un_node,
                .struct_init_empty_result = .un_node,
                .struct_init_empty_ref_result = .un_node,
                .struct_init_anon = .pl_node,
                .struct_init = .pl_node,
                .struct_init_ref = .pl_node,
                .validate_struct_init_ty = .un_node,
                .validate_struct_init_result_ty = .un_node,
                .validate_ptr_struct_init = .pl_node,
                .struct_init_field_type = .pl_node,
                .struct_init_field_ptr = .pl_node,
                .array_init_anon = .pl_node,
                .array_init = .pl_node,
                .array_init_ref = .pl_node,
                .validate_array_init_ty = .pl_node,
                .validate_array_init_result_ty = .pl_node,
                .validate_array_init_ref_ty = .pl_node,
                .validate_ptr_array_init = .pl_node,
                .array_init_elem_type = .bin,
                .array_init_elem_ptr = .pl_node,

                .extended = .extended,
            });
        };

        // Uncomment to view how many tag slots are available.
        //comptime {
        //    @compileLog("ZIR tags left: ", 256 - @typeInfo(Tag).Enum.fields.len);
        //}
    };

    /// Rarer instructions are here; ones that do not fit in the 8-bit `Tag` enum.
    /// `noreturn` instructions may not go here; they must be part of the main `Tag` enum.
    pub const Extended = enum(u16) {
        /// Declares a global variable.
        /// `operand` is payload index to `ExtendedVar`.
        /// `small` is `ExtendedVar.Small`.
        variable,
        /// A struct type definition. Contains references to ZIR instructions for
        /// the field types, defaults, and alignments.
        /// `operand` is payload index to `StructDecl`.
        /// `small` is `StructDecl.Small`.
        struct_decl,
        /// An enum type definition. Contains references to ZIR instructions for
        /// the field value expressions and optional type tag expression.
        /// `operand` is payload index to `EnumDecl`.
        /// `small` is `EnumDecl.Small`.
        enum_decl,
        /// A union type definition. Contains references to ZIR instructions for
        /// the field types and optional type tag expression.
        /// `operand` is payload index to `UnionDecl`.
        /// `small` is `UnionDecl.Small`.
        union_decl,
        /// An opaque type definition. Contains references to decls and captures.
        /// `operand` is payload index to `OpaqueDecl`.
        /// `small` is `OpaqueDecl.Small`.
        opaque_decl,
        /// Implements the `@This` builtin.
        /// `operand` is `src_node: i32`.
        this,
        /// Implements the `@returnAddress` builtin.
        /// `operand` is `src_node: i32`.
        ret_addr,
        /// Implements the `@src` builtin.
        /// `operand` is payload index to `LineColumn`.
        builtin_src,
        /// Implements the `@errorReturnTrace` builtin.
        /// `operand` is `src_node: i32`.
        error_return_trace,
        /// Implements the `@frame` builtin.
        /// `operand` is `src_node: i32`.
        frame,
        /// Implements the `@frameAddress` builtin.
        /// `operand` is `src_node: i32`.
        frame_address,
        /// Same as `alloc` from `Tag` but may contain an alignment instruction.
        /// `operand` is payload index to `AllocExtended`.
        /// `small`:
        ///  * 0b000X - has type
        ///  * 0b00X0 - has alignment
        ///  * 0b0X00 - 1=const, 0=var
        ///  * 0bX000 - is comptime
        alloc,
        /// The `@extern` builtin.
        /// `operand` is payload index to `BinNode`.
        builtin_extern,
        /// Inline assembly.
        /// `small`:
        ///  * 0b00000000_000XXXXX - `outputs_len`.
        ///  * 0b000000XX_XXX00000 - `inputs_len`.
        ///  * 0b0XXXXX00_00000000 - `clobbers_len`.
        ///  * 0bX0000000_00000000 - is volatile
        /// `operand` is payload index to `Asm`.
        @"asm",
        /// Same as `asm` except the assembly template is not a string literal but a comptime
        /// expression.
        /// The `asm_source` field of the Asm is not a null-terminated string
        /// but instead a Ref.
        asm_expr,
        /// Log compile time variables and emit an error message.
        /// `operand` is payload index to `NodeMultiOp`.
        /// `small` is `operands_len`.
        /// The AST node is the compile log builtin call.
        compile_log,
        /// The builtin `@TypeOf` which returns the type after Peer Type Resolution
        /// of one or more params.
        /// `operand` is payload index to `TypeOfPeer`.
        /// `small` is `operands_len`.
        /// The AST node is the builtin call.
        typeof_peer,
        /// Implements the `@min` builtin for more than 2 args.
        /// `operand` is payload index to `NodeMultiOp`.
        /// `small` is `operands_len`.
        /// The AST node is the builtin call.
        min_multi,
        /// Implements the `@max` builtin for more than 2 args.
        /// `operand` is payload index to `NodeMultiOp`.
        /// `small` is `operands_len`.
        /// The AST node is the builtin call.
        max_multi,
        /// Implements the `@addWithOverflow` builtin.
        /// `operand` is payload index to `BinNode`.
        /// `small` is unused.
        add_with_overflow,
        /// Implements the `@subWithOverflow` builtin.
        /// `operand` is payload index to `BinNode`.
        /// `small` is unused.
        sub_with_overflow,
        /// Implements the `@mulWithOverflow` builtin.
        /// `operand` is payload index to `BinNode`.
        /// `small` is unused.
        mul_with_overflow,
        /// Implements the `@shlWithOverflow` builtin.
        /// `operand` is payload index to `BinNode`.
        /// `small` is unused.
        shl_with_overflow,
        /// `operand` is payload index to `UnNode`.
        c_undef,
        /// `operand` is payload index to `UnNode`.
        c_include,
        /// `operand` is payload index to `BinNode`.
        c_define,
        /// `operand` is payload index to `UnNode`.
        wasm_memory_size,
        /// `operand` is payload index to `BinNode`.
        wasm_memory_grow,
        /// The `@prefetch` builtin.
        /// `operand` is payload index to `BinNode`.
        prefetch,
        /// Implements the `@fence` builtin.
        /// `operand` is payload index to `UnNode`.
        fence,
        /// Implement builtin `@setFloatMode`.
        /// `operand` is payload index to `UnNode`.
        set_float_mode,
        /// Implement builtin `@setAlignStack`.
        /// `operand` is payload index to `UnNode`.
        set_align_stack,
        /// Implements `@setCold`.
        /// `operand` is payload index to `UnNode`.
        set_cold,
        /// Implements the `@errorCast` builtin.
        /// `operand` is payload index to `BinNode`. `lhs` is dest type, `rhs` is operand.
        error_cast,
        /// `operand` is payload index to `UnNode`.
        await_nosuspend,
        /// Implements `@breakpoint`.
        /// `operand` is `src_node: i32`.
        breakpoint,
        /// Implements the `@select` builtin.
        /// `operand` is payload index to `Select`.
        select,
        /// Implement builtin `@errToInt`.
        /// `operand` is payload index to `UnNode`.
        int_from_error,
        /// Implement builtin `@errorFromInt`.
        /// `operand` is payload index to `UnNode`.
        error_from_int,
        /// Implement builtin `@Type`.
        /// `operand` is payload index to `UnNode`.
        /// `small` contains `NameStrategy`.
        reify,
        /// Implements the `@asyncCall` builtin.
        /// `operand` is payload index to `AsyncCall`.
        builtin_async_call,
        /// Implements the `@cmpxchgStrong` and `@cmpxchgWeak` builtins.
        /// `small` 0=>weak 1=>strong
        /// `operand` is payload index to `Cmpxchg`.
        cmpxchg,
        /// Implement builtin `@cVaArg`.
        /// `operand` is payload index to `BinNode`.
        c_va_arg,
        /// Implement builtin `@cVaCopy`.
        /// `operand` is payload index to `UnNode`.
        c_va_copy,
        /// Implement builtin `@cVaEnd`.
        /// `operand` is payload index to `UnNode`.
        c_va_end,
        /// Implement builtin `@cVaStart`.
        /// `operand` is `src_node: i32`.
        c_va_start,
        /// Implements the following builtins:
        /// `@ptrCast`, `@alignCast`, `@addrSpaceCast`, `@constCast`, `@volatileCast`.
        /// Represents an arbitrary nesting of the above builtins. Such a nesting is treated as a
        /// single operation which can modify multiple components of a pointer type.
        /// `operand` is payload index to `BinNode`.
        /// `small` contains `FullPtrCastFlags`.
        /// AST node is the root of the nested casts.
        /// `lhs` is dest type, `rhs` is operand.
        ptr_cast_full,
        /// `operand` is payload index to `UnNode`.
        /// `small` contains `FullPtrCastFlags`.
        /// Guaranteed to only have flags where no explicit destination type is
        /// required (const_cast and volatile_cast).
        /// AST node is the root of the nested casts.
        ptr_cast_no_dest,
        /// Implements the `@workItemId` builtin.
        /// `operand` is payload index to `UnNode`.
        work_item_id,
        /// Implements the `@workGroupSize` builtin.
        /// `operand` is payload index to `UnNode`.
        work_group_size,
        /// Implements the `@workGroupId` builtin.
        /// `operand` is payload index to `UnNode`.
        work_group_id,
        /// Implements the `@inComptime` builtin.
        /// `operand` is `src_node: i32`.
        in_comptime,
        /// Restores the error return index to its last saved state in a given
        /// block. If the block is `.none`, restores to the state from the point
        /// of function entry. If the operand is not `.none`, the restore is
        /// conditional on the operand value not being an error.
        /// `operand` is payload index to `RestoreErrRetIndex`.
        /// `small` is undefined.
        restore_err_ret_index,
        /// Retrieves a value from the current type declaration scope's closure.
        /// `operand` is `src_node: i32`.
        /// `small` is closure index.
        closure_get,
        /// Used as a placeholder instruction which is just a dummy index for Sema to replace
        /// with a specific value. For instance, this is used for the capture of an `errdefer`.
        /// This should never appear in a body.
        value_placeholder,
        /// Implements the `@fieldParentPtr` builtin.
        /// `operand` is payload index to `FieldParentPtr`.
        /// `small` contains `FullPtrCastFlags`.
        /// Guaranteed to not have the `ptr_cast` flag.
        /// Uses the `pl_node` union field with payload `FieldParentPtr`.
        field_parent_ptr,

        pub const InstData = struct {
            opcode: Extended,
            small: u16,
            operand: u32,
        };
    };

    /// The position of a ZIR instruction within the `Zir` instructions array.
    pub const Index = enum(u32) {
        /// ZIR is structured so that the outermost "main" struct of any file
        /// is always at index 0.
        main_struct_inst = 0,
        ref_start_index = static_len,
        _,

        pub const static_len = 84;

        pub fn toRef(i: Index) Inst.Ref {
            return @enumFromInt(@intFromEnum(Index.ref_start_index) + @intFromEnum(i));
        }

        pub fn toOptional(i: Index) OptionalIndex {
            return @enumFromInt(@intFromEnum(i));
        }
    };

    pub const OptionalIndex = enum(u32) {
        /// ZIR is structured so that the outermost "main" struct of any file
        /// is always at index 0.
        main_struct_inst = 0,
        ref_start_index = Index.static_len,
        none = std.math.maxInt(u32),
        _,

        pub fn unwrap(oi: OptionalIndex) ?Index {
            return if (oi == .none) null else @enumFromInt(@intFromEnum(oi));
        }
    };

    /// A reference to ZIR instruction, or to an InternPool index, or neither.
    ///
    /// If the integer tag value is < InternPool.static_len, then it
    /// corresponds to an InternPool index. Otherwise, this refers to a ZIR
    /// instruction.
    ///
    /// The tag type is specified so that it is safe to bitcast between `[]u32`
    /// and `[]Ref`.
    pub const Ref = enum(u32) {
        u0_type,
        i0_type,
        u1_type,
        u8_type,
        i8_type,
        u16_type,
        i16_type,
        u29_type,
        u32_type,
        i32_type,
        u64_type,
        i64_type,
        u80_type,
        u128_type,
        i128_type,
        usize_type,
        isize_type,
        c_char_type,
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
        f80_type,
        f128_type,
        anyopaque_type,
        bool_type,
        void_type,
        type_type,
        anyerror_type,
        comptime_int_type,
        comptime_float_type,
        noreturn_type,
        anyframe_type,
        null_type,
        undefined_type,
        enum_literal_type,
        atomic_order_type,
        atomic_rmw_op_type,
        calling_convention_type,
        address_space_type,
        float_mode_type,
        reduce_op_type,
        call_modifier_type,
        prefetch_options_type,
        export_options_type,
        extern_options_type,
        type_info_type,
        manyptr_u8_type,
        manyptr_const_u8_type,
        manyptr_const_u8_sentinel_0_type,
        single_const_pointer_to_comptime_int_type,
        slice_const_u8_type,
        slice_const_u8_sentinel_0_type,
        optional_noreturn_type,
        anyerror_void_error_union_type,
        adhoc_inferred_error_set_type,
        generic_poison_type,
        empty_struct_type,
        undef,
        zero,
        zero_usize,
        zero_u8,
        one,
        one_usize,
        one_u8,
        four_u8,
        negative_one,
        calling_convention_c,
        calling_convention_inline,
        void_value,
        unreachable_value,
        null_value,
        bool_true,
        bool_false,
        empty_struct,
        generic_poison,

        /// This Ref does not correspond to any ZIR instruction or constant
        /// value and may instead be used as a sentinel to indicate null.
        none = std.math.maxInt(u32),

        _,

        pub fn toIndex(inst: Ref) ?Index {
            assert(inst != .none);
            const ref_int = @intFromEnum(inst);
            if (ref_int >= @intFromEnum(Index.ref_start_index)) {
                return @enumFromInt(ref_int - @intFromEnum(Index.ref_start_index));
            } else {
                return null;
            }
        }

        pub fn toIndexAllowNone(inst: Ref) ?Index {
            if (inst == .none) return null;
            return toIndex(inst);
        }
    };

    /// All instructions have an 8-byte payload, which is contained within
    /// this union. `Tag` determines which union field is active, as well as
    /// how to interpret the data within.
    pub const Data = union {
        /// Used for `Tag.extended`. The extended opcode determines the meaning
        /// of the `small` and `operand` fields.
        extended: Extended.InstData,
        /// Used for unary operators, with an AST node source location.
        un_node: struct {
            /// Offset from Decl AST node index.
            src_node: i32,
            /// The meaning of this operand depends on the corresponding `Tag`.
            operand: Ref,

            pub fn src(self: @This()) LazySrcLoc {
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        /// Used for unary operators, with a token source location.
        un_tok: struct {
            /// Offset from Decl AST token index.
            src_tok: Ast.TokenIndex,
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
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        pl_tok: struct {
            /// Offset from Decl AST token index.
            src_tok: Ast.TokenIndex,
            /// index into extra.
            /// `Tag` determines what lives there.
            payload_index: u32,

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .token_offset = self.src_tok };
            }
        },
        bin: Bin,
        /// For strings which may contain null bytes.
        str: struct {
            /// Offset into `string_bytes`.
            start: NullTerminatedString,
            /// Number of bytes in the string.
            len: u32,

            pub fn get(self: @This(), code: Zir) []const u8 {
                return code.string_bytes[@intFromEnum(self.start)..][0..self.len];
            }
        },
        str_tok: struct {
            /// Offset into `string_bytes`. Null-terminated.
            start: NullTerminatedString,
            /// Offset from Decl AST token index.
            src_tok: u32,

            pub fn get(self: @This(), code: Zir) [:0]const u8 {
                return code.nullTerminatedString(self.start);
            }

            pub fn src(self: @This()) LazySrcLoc {
                return .{ .token_offset = self.src_tok };
            }
        },
        /// Offset from Decl AST token index.
        tok: Ast.TokenIndex,
        /// Offset from Decl AST node index.
        node: i32,
        int: u64,
        float: f64,
        ptr_type: struct {
            flags: packed struct {
                is_allowzero: bool,
                is_mutable: bool,
                is_volatile: bool,
                has_sentinel: bool,
                has_align: bool,
                has_addrspace: bool,
                has_bit_range: bool,
                _: u1 = undefined,
            },
            size: std.builtin.Type.Pointer.Size,
            /// Index into extra. See `PtrType`.
            payload_index: u32,
        },
        int_type: struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,
            signedness: std.builtin.Signedness,
            bit_count: u16,

            pub fn src(self: @This()) LazySrcLoc {
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        @"unreachable": struct {
            /// Offset from Decl AST node index.
            /// `Tag` determines which kind of AST node this points to.
            src_node: i32,

            pub fn src(self: @This()) LazySrcLoc {
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        @"break": struct {
            operand: Ref,
            payload_index: u32,
        },
        dbg_stmt: LineColumn,
        /// Used for unary operators which reference an inst,
        /// with an AST node source location.
        inst_node: struct {
            /// Offset from Decl AST node index.
            src_node: i32,
            /// The meaning of this operand depends on the corresponding `Tag`.
            inst: Index,

            pub fn src(self: @This()) LazySrcLoc {
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        str_op: struct {
            /// Offset into `string_bytes`. Null-terminated.
            str: NullTerminatedString,
            operand: Ref,

            pub fn getStr(self: @This(), zir: Zir) [:0]const u8 {
                return zir.nullTerminatedString(self.str);
            }
        },
        @"defer": struct {
            index: u32,
            len: u32,
        },
        defer_err_code: struct {
            err_code: Ref,
            payload_index: u32,
        },
        save_err_ret_index: struct {
            operand: Ref, // If error type (or .none), save new trace index
        },
        elem_val_imm: struct {
            /// The indexable value being accessed.
            operand: Ref,
            /// The index being accessed.
            idx: u32,
        },

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (builtin.mode != .Debug and builtin.mode != .ReleaseSafe) {
                assert(@sizeOf(Data) == 8);
            }
        }

        /// TODO this has to be kept in sync with `Data` which we want to be an untagged
        /// union. There is some kind of language awkwardness here and it has to do with
        /// deserializing an untagged union (in this case `Data`) from a file, and trying
        /// to preserve the hidden safety field.
        pub const FieldEnum = enum {
            extended,
            un_node,
            un_tok,
            pl_node,
            pl_tok,
            bin,
            str,
            str_tok,
            tok,
            node,
            int,
            float,
            ptr_type,
            int_type,
            @"unreachable",
            @"break",
            dbg_stmt,
            inst_node,
            str_op,
            @"defer",
            defer_err_code,
            save_err_ret_index,
            elem_val_imm,
        };
    };

    pub const Break = struct {
        pub const no_src_node = std.math.maxInt(i32);

        operand_src_node: i32,
        block_inst: Index,
    };

    /// Trailing:
    /// 0. Output for every outputs_len
    /// 1. Input for every inputs_len
    /// 2. clobber: NullTerminatedString // index into string_bytes (null terminated) for every clobbers_len.
    pub const Asm = struct {
        src_node: i32,
        // null-terminated string index
        asm_source: NullTerminatedString,
        /// 1 bit for each outputs_len: whether it uses `-> T` or not.
        ///   0b0 - operand is a pointer to where to store the output.
        ///   0b1 - operand is a type; asm expression has the output as the result.
        /// 0b0X is the first output, 0bX0 is the second, etc.
        output_type_bits: u32,

        pub const Output = struct {
            /// index into string_bytes (null terminated)
            name: NullTerminatedString,
            /// index into string_bytes (null terminated)
            constraint: NullTerminatedString,
            /// How to interpret this is determined by `output_type_bits`.
            operand: Ref,
        };

        pub const Input = struct {
            /// index into string_bytes (null terminated)
            name: NullTerminatedString,
            /// index into string_bytes (null terminated)
            constraint: NullTerminatedString,
            operand: Ref,
        };
    };

    /// Trailing:
    /// if (ret_body_len == 1) {
    ///   0. return_type: Ref
    /// }
    /// if (ret_body_len > 1) {
    ///   1. return_type: Index // for each ret_body_len
    /// }
    /// 2. body: Index // for each body_len
    /// 3. src_locs: SrcLocs // if body_len != 0
    /// 4. proto_hash: std.zig.SrcHash // if body_len != 0; hash of function prototype
    pub const Func = struct {
        /// If this is 0 it means a void return type.
        /// If this is 1 it means return_type is a simple Ref
        ret_body_len: u32,
        /// Points to the block that contains the param instructions for this function.
        /// If this is a `declaration`, it refers to the declaration's value body.
        param_block: Index,
        body_len: u32,

        pub const SrcLocs = struct {
            /// Line index in the source file relative to the parent decl.
            lbrace_line: u32,
            /// Line index in the source file relative to the parent decl.
            rbrace_line: u32,
            /// lbrace_column is least significant bits u16
            /// rbrace_column is most significant bits u16
            columns: u32,
        };
    };

    /// Trailing:
    /// 0. lib_name: NullTerminatedString, // null terminated string index, if has_lib_name is set
    /// if (has_align_ref and !has_align_body) {
    ///   1. align: Ref,
    /// }
    /// if (has_align_body) {
    ///   2. align_body_len: u32
    ///   3. align_body: u32 // for each align_body_len
    /// }
    /// if (has_addrspace_ref and !has_addrspace_body) {
    ///   4. addrspace: Ref,
    /// }
    /// if (has_addrspace_body) {
    ///   5. addrspace_body_len: u32
    ///   6. addrspace_body: u32 // for each addrspace_body_len
    /// }
    /// if (has_section_ref and !has_section_body) {
    ///   7. section: Ref,
    /// }
    /// if (has_section_body) {
    ///   8. section_body_len: u32
    ///   9. section_body: u32 // for each section_body_len
    /// }
    /// if (has_cc_ref and !has_cc_body) {
    ///   10. cc: Ref,
    /// }
    /// if (has_cc_body) {
    ///   11. cc_body_len: u32
    ///   12. cc_body: u32 // for each cc_body_len
    /// }
    /// if (has_ret_ty_ref and !has_ret_ty_body) {
    ///   13. ret_ty: Ref,
    /// }
    /// if (has_ret_ty_body) {
    ///   14. ret_ty_body_len: u32
    ///   15. ret_ty_body: u32 // for each ret_ty_body_len
    /// }
    /// 16. noalias_bits: u32 // if has_any_noalias
    ///     - each bit starting with LSB corresponds to parameter indexes
    /// 17. body: Index // for each body_len
    /// 18. src_locs: Func.SrcLocs // if body_len != 0
    /// 19. proto_hash: std.zig.SrcHash // if body_len != 0; hash of function prototype
    pub const FuncFancy = struct {
        /// Points to the block that contains the param instructions for this function.
        /// If this is a `declaration`, it refers to the declaration's value body.
        param_block: Index,
        body_len: u32,
        bits: Bits,

        /// If both has_cc_ref and has_cc_body are false, it means auto calling convention.
        /// If both has_align_ref and has_align_body are false, it means default alignment.
        /// If both has_ret_ty_ref and has_ret_ty_body are false, it means void return type.
        /// If both has_section_ref and has_section_body are false, it means default section.
        /// If both has_addrspace_ref and has_addrspace_body are false, it means default addrspace.
        pub const Bits = packed struct {
            is_var_args: bool,
            is_inferred_error: bool,
            is_test: bool,
            is_extern: bool,
            is_noinline: bool,
            has_align_ref: bool,
            has_align_body: bool,
            has_addrspace_ref: bool,
            has_addrspace_body: bool,
            has_section_ref: bool,
            has_section_body: bool,
            has_cc_ref: bool,
            has_cc_body: bool,
            has_ret_ty_ref: bool,
            has_ret_ty_body: bool,
            has_lib_name: bool,
            has_any_noalias: bool,
            _: u15 = undefined,
        };
    };

    /// Trailing:
    /// 0. lib_name: NullTerminatedString, // null terminated string index, if has_lib_name is set
    /// 1. align: Ref, // if has_align is set
    /// 2. init: Ref // if has_init is set
    /// The source node is obtained from the containing `block_inline`.
    pub const ExtendedVar = struct {
        var_type: Ref,

        pub const Small = packed struct {
            has_lib_name: bool,
            has_align: bool,
            has_init: bool,
            is_extern: bool,
            is_const: bool,
            is_threadlocal: bool,
            _: u10 = undefined,
        };
    };

    /// This data is stored inside extra, with trailing operands according to `operands_len`.
    /// Each operand is a `Ref`.
    pub const MultiOp = struct {
        operands_len: u32,
    };

    /// Trailing: operand: Ref, // for each `operands_len` (stored in `small`).
    pub const NodeMultiOp = struct {
        src_node: i32,
    };

    /// This data is stored inside extra, with trailing operands according to `body_len`.
    /// Each operand is an `Index`.
    pub const Block = struct {
        body_len: u32,
    };

    /// Trailing:
    /// * inst: Index // for each `body_len`
    pub const BoolBr = struct {
        lhs: Ref,
        body_len: u32,
    };

    /// Trailing:
    /// 0. doc_comment: u32          // if `has_doc_comment`; null-terminated string index
    /// 1. align_body_len: u32       // if `has_align_linksection_addrspace`; 0 means no `align`
    /// 2. linksection_body_len: u32 // if `has_align_linksection_addrspace`; 0 means no `linksection`
    /// 3. addrspace_body_len: u32   // if `has_align_linksection_addrspace`; 0 means no `addrspace`
    /// 4. value_body_inst: Zir.Inst.Index
    ///    - for each `value_body_len`
    ///    - body to be exited via `break_inline` to this `declaration` instruction
    /// 5. align_body_inst: Zir.Inst.Index
    ///    - for each `align_body_len`
    ///    - body to be exited via `break_inline` to this `declaration` instruction
    /// 6. linksection_body_inst: Zir.Inst.Index
    ///    - for each `linksection_body_len`
    ///    - body to be exited via `break_inline` to this `declaration` instruction
    /// 7. addrspace_body_inst: Zir.Inst.Index
    ///    - for each `addrspace_body_len`
    ///    - body to be exited via `break_inline` to this `declaration` instruction
    pub const Declaration = struct {
        // These fields should be concatenated and reinterpreted as a `std.zig.SrcHash`.
        src_hash_0: u32,
        src_hash_1: u32,
        src_hash_2: u32,
        src_hash_3: u32,
        /// The name of this `Decl`. Also indicates whether it is a test, comptime block, etc.
        name: Name,
        /// This Decl's line number relative to that of its parent.
        /// TODO: column must be encoded similarly to respect non-formatted code!
        line_offset: u32,
        flags: Flags,

        pub const Flags = packed struct(u32) {
            value_body_len: u28,
            is_pub: bool,
            is_export: bool,
            has_doc_comment: bool,
            has_align_linksection_addrspace: bool,
        };

        pub const Name = enum(u32) {
            @"comptime" = std.math.maxInt(u32),
            @"usingnamespace" = std.math.maxInt(u32) - 1,
            unnamed_test = std.math.maxInt(u32) - 2,
            /// In this case, `has_doc_comment` will be true, and the doc
            /// comment body is the identifier name.
            decltest = std.math.maxInt(u32) - 3,
            /// Other values are `NullTerminatedString` values, i.e. index into
            /// `string_bytes`. If the byte referenced is 0, the decl is a named
            /// test, and the actual name begins at the following byte.
            _,

            pub fn isNamedTest(name: Name, zir: Zir) bool {
                return switch (name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => false,
                    _ => zir.string_bytes[@intFromEnum(name)] == 0,
                };
            }
            pub fn toString(name: Name, zir: Zir) ?NullTerminatedString {
                switch (name) {
                    .@"comptime", .@"usingnamespace", .unnamed_test, .decltest => return null,
                    _ => {},
                }
                const idx: u32 = @intFromEnum(name);
                if (zir.string_bytes[idx] == 0) {
                    // Named test
                    return @enumFromInt(idx + 1);
                }
                return @enumFromInt(idx);
            }
        };

        pub const Bodies = struct {
            value_body: []const Index,
            align_body: ?[]const Index,
            linksection_body: ?[]const Index,
            addrspace_body: ?[]const Index,
        };

        pub fn getBodies(declaration: Declaration, extra_end: u32, zir: Zir) Bodies {
            var extra_index: u32 = extra_end;
            extra_index += @intFromBool(declaration.flags.has_doc_comment);
            const value_body_len = declaration.flags.value_body_len;
            const align_body_len, const linksection_body_len, const addrspace_body_len = lens: {
                if (!declaration.flags.has_align_linksection_addrspace) {
                    break :lens .{ 0, 0, 0 };
                }
                const lens = zir.extra[extra_index..][0..3].*;
                extra_index += 3;
                break :lens lens;
            };
            return .{
                .value_body = b: {
                    defer extra_index += value_body_len;
                    break :b zir.bodySlice(extra_index, value_body_len);
                },
                .align_body = if (align_body_len == 0) null else b: {
                    defer extra_index += align_body_len;
                    break :b zir.bodySlice(extra_index, align_body_len);
                },
                .linksection_body = if (linksection_body_len == 0) null else b: {
                    defer extra_index += linksection_body_len;
                    break :b zir.bodySlice(extra_index, linksection_body_len);
                },
                .addrspace_body = if (addrspace_body_len == 0) null else b: {
                    defer extra_index += addrspace_body_len;
                    break :b zir.bodySlice(extra_index, addrspace_body_len);
                },
            };
        }
    };

    /// Stored inside extra, with trailing arguments according to `args_len`.
    /// Implicit 0. arg_0_start: u32, // always same as `args_len`
    /// 1. arg_end: u32, // for each `args_len`
    /// arg_N_start is the same as arg_N-1_end
    pub const Call = struct {
        // Note: Flags *must* come first so that unusedResultExpr
        // can find it when it goes to modify them.
        flags: Flags,
        callee: Ref,

        pub const Flags = packed struct {
            /// std.builtin.CallModifier in packed form
            pub const PackedModifier = u3;
            pub const PackedArgsLen = u27;

            packed_modifier: PackedModifier,
            ensure_result_used: bool = false,
            pop_error_return_trace: bool,
            args_len: PackedArgsLen,

            comptime {
                if (@sizeOf(Flags) != 4 or @bitSizeOf(Flags) != 32)
                    @compileError("Layout of Call.Flags needs to be updated!");
                if (@bitSizeOf(std.builtin.CallModifier) != @bitSizeOf(PackedModifier))
                    @compileError("Call.Flags.PackedModifier needs to be updated!");
            }
        };
    };

    /// Stored inside extra, with trailing arguments according to `args_len`.
    /// Implicit 0. arg_0_start: u32, // always same as `args_len`
    /// 1. arg_end: u32, // for each `args_len`
    /// arg_N_start is the same as arg_N-1_end
    pub const FieldCall = struct {
        // Note: Flags *must* come first so that unusedResultExpr
        // can find it when it goes to modify them.
        flags: Call.Flags,
        obj_ptr: Ref,
        /// Offset into `string_bytes`.
        field_name_start: NullTerminatedString,
    };

    pub const TypeOfPeer = struct {
        src_node: i32,
        body_len: u32,
        body_index: u32,
    };

    pub const BuiltinCall = struct {
        // Note: Flags *must* come first so that unusedResultExpr
        // can find it when it goes to modify them.
        flags: Flags,
        modifier: Ref,
        callee: Ref,
        args: Ref,

        pub const Flags = packed struct {
            is_nosuspend: bool,
            ensure_result_used: bool,
            _: u30 = undefined,

            comptime {
                if (@sizeOf(Flags) != 4 or @bitSizeOf(Flags) != 32)
                    @compileError("Layout of BuiltinCall.Flags needs to be updated!");
            }
        };
    };

    /// This data is stored inside extra, with two sets of trailing `Ref`:
    /// * 0. the then body, according to `then_body_len`.
    /// * 1. the else body, according to `else_body_len`.
    pub const CondBr = struct {
        condition: Ref,
        then_body_len: u32,
        else_body_len: u32,
    };

    /// This data is stored inside extra, trailed by:
    /// * 0. body: Index //  for each `body_len`.
    pub const Try = struct {
        /// The error union to unwrap.
        operand: Ref,
        body_len: u32,
    };

    /// Stored in extra. Depending on the flags in Data, there will be up to 5
    /// trailing Ref fields:
    /// 0. sentinel: Ref // if `has_sentinel` flag is set
    /// 1. align: Ref // if `has_align` flag is set
    /// 2. address_space: Ref // if `has_addrspace` flag is set
    /// 3. bit_start: Ref // if `has_bit_range` flag is set
    /// 4. host_size: Ref // if `has_bit_range` flag is set
    pub const PtrType = struct {
        elem_type: Ref,
        src_node: i32,
    };

    pub const ArrayTypeSentinel = struct {
        len: Ref,
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

    pub const SliceLength = struct {
        lhs: Ref,
        start: Ref,
        len: Ref,
        sentinel: Ref,
        start_src_node_offset: i32,
    };

    /// The meaning of these operands depends on the corresponding `Tag`.
    pub const Bin = struct {
        lhs: Ref,
        rhs: Ref,
    };

    pub const BinNode = struct {
        node: i32,
        lhs: Ref,
        rhs: Ref,
    };

    pub const UnNode = struct {
        node: i32,
        operand: Ref,
    };

    pub const ElemPtrImm = struct {
        ptr: Ref,
        index: u32,
    };

    pub const SwitchBlockErrUnion = struct {
        operand: Ref,
        bits: Bits,
        main_src_node_offset: i32,

        pub const Bits = packed struct(u32) {
            /// If true, one or more prongs have multiple items.
            has_multi_cases: bool,
            /// If true, there is an else prong. This is mutually exclusive with `has_under`.
            has_else: bool,
            any_uses_err_capture: bool,
            payload_is_ref: bool,
            scalar_cases_len: ScalarCasesLen,

            pub const ScalarCasesLen = u28;
        };

        pub const MultiProng = struct {
            items: []const Ref,
            body: []const Index,
        };
    };

    /// 0. multi_cases_len: u32 // If has_multi_cases is set.
    /// 1. tag_capture_inst: u32 // If any_has_tag_capture is set. Index of instruction prongs use to refer to the inline tag capture.
    /// 2. else_body { // If has_else or has_under is set.
    ///        info: ProngInfo,
    ///        body member Index for every info.body_len
    ///     }
    /// 3. scalar_cases: { // for every scalar_cases_len
    ///        item: Ref,
    ///        info: ProngInfo,
    ///        body member Index for every info.body_len
    ///     }
    /// 4. multi_cases: { // for every multi_cases_len
    ///        items_len: u32,
    ///        ranges_len: u32,
    ///        info: ProngInfo,
    ///        item: Ref // for every items_len
    ///        ranges: { // for every ranges_len
    ///            item_first: Ref,
    ///            item_last: Ref,
    ///        }
    ///        body member Index for every info.body_len
    ///    }
    ///
    /// When analyzing a case body, the switch instruction itself refers to the
    /// captured payload. Whether this is captured by reference or by value
    /// depends on whether the `byref` bit is set for the corresponding body.
    pub const SwitchBlock = struct {
        /// The operand passed to the `switch` expression. If this is a
        /// `switch_block`, this is the operand value; if `switch_block_ref` it
        /// is a pointer to the operand. `switch_block_ref` is always used if
        /// any prong has a byref capture.
        operand: Ref,
        bits: Bits,

        /// These are stored in trailing data in `extra` for each prong.
        pub const ProngInfo = packed struct(u32) {
            body_len: u28,
            capture: ProngInfo.Capture,
            is_inline: bool,
            has_tag_capture: bool,

            pub const Capture = enum(u2) {
                none,
                by_val,
                by_ref,
            };
        };

        pub const Bits = packed struct(u32) {
            /// If true, one or more prongs have multiple items.
            has_multi_cases: bool,
            /// If true, there is an else prong. This is mutually exclusive with `has_under`.
            has_else: bool,
            /// If true, there is an underscore prong. This is mutually exclusive with `has_else`.
            has_under: bool,
            /// If true, at least one prong has an inline tag capture.
            any_has_tag_capture: bool,
            scalar_cases_len: ScalarCasesLen,

            pub const ScalarCasesLen = u28;

            pub fn specialProng(bits: Bits) SpecialProng {
                const has_else: u2 = @intFromBool(bits.has_else);
                const has_under: u2 = @intFromBool(bits.has_under);
                return switch ((has_else << 1) | has_under) {
                    0b00 => .none,
                    0b01 => .under,
                    0b10 => .@"else",
                    0b11 => unreachable,
                };
            }
        };

        pub const MultiProng = struct {
            items: []const Ref,
            body: []const Index,
        };
    };

    pub const ArrayInitRefTy = struct {
        ptr_ty: Ref,
        elem_count: u32,
    };

    pub const Field = struct {
        lhs: Ref,
        /// Offset into `string_bytes`.
        field_name_start: NullTerminatedString,
    };

    pub const FieldNamed = struct {
        lhs: Ref,
        field_name: Ref,
    };

    pub const As = struct {
        dest_type: Ref,
        operand: Ref,
    };

    /// Trailing:
    /// 0. captures_len: u32 // if has_captures_len
    /// 1. fields_len: u32, // if has_fields_len
    /// 2. decls_len: u32, // if has_decls_len
    /// 3. capture: Capture // for every captures_len
    /// 4. backing_int_body_len: u32, // if has_backing_int
    /// 5. backing_int_ref: Ref, // if has_backing_int and backing_int_body_len is 0
    /// 6. backing_int_body_inst: Inst, // if has_backing_int and backing_int_body_len is > 0
    /// 7. decl: Index, // for every decls_len; points to a `declaration` instruction
    /// 8. flags: u32 // for every 8 fields
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding field has an align expression
    ///      0b00X0: whether corresponding field has a default expression
    ///      0b0X00: whether corresponding field is comptime
    ///      0bX000: whether corresponding field has a type expression
    /// 9. fields: { // for every fields_len
    ///        field_name: u32, // if !is_tuple
    ///        doc_comment: NullTerminatedString, // .empty if no doc comment
    ///        field_type: Ref, // if corresponding bit is not set. none means anytype.
    ///        field_type_body_len: u32, // if corresponding bit is set
    ///        align_body_len: u32, // if corresponding bit is set
    ///        init_body_len: u32, // if corresponding bit is set
    ///    }
    /// 10. bodies: { // for every fields_len
    ///        field_type_body_inst: Inst, // for each field_type_body_len
    ///        align_body_inst: Inst, // for each align_body_len
    ///        init_body_inst: Inst, // for each init_body_len
    ///    }
    pub const StructDecl = struct {
        // These fields should be concatenated and reinterpreted as a `std.zig.SrcHash`.
        // This hash contains the source of all fields, and any specified attributes (`extern`, backing type, etc).
        fields_hash_0: u32,
        fields_hash_1: u32,
        fields_hash_2: u32,
        fields_hash_3: u32,
        src_node: i32,

        pub fn src(self: StructDecl) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }

        pub const Small = packed struct {
            has_captures_len: bool,
            has_fields_len: bool,
            has_decls_len: bool,
            has_backing_int: bool,
            known_non_opv: bool,
            known_comptime_only: bool,
            is_tuple: bool,
            name_strategy: NameStrategy,
            layout: std.builtin.Type.ContainerLayout,
            any_default_inits: bool,
            any_comptime_fields: bool,
            any_aligned_fields: bool,
            _: u2 = undefined,
        };
    };

    /// Represents a single value being captured in a type declaration's closure.
    pub const Capture = packed struct(u32) {
        tag: enum(u3) {
            /// `data` is a `u16` index into the parent closure.
            nested,
            /// `data` is a `Zir.Inst.Index` to an instruction whose value is being captured.
            instruction,
            /// `data` is a `Zir.Inst.Index` to an instruction representing an alloc whose contents is being captured.
            instruction_load,
            /// `data` is a `NullTerminatedString` to a decl name.
            decl_val,
            /// `data` is a `NullTerminatedString` to a decl name.
            decl_ref,
        },
        data: u29,
        pub const Unwrapped = union(enum) {
            nested: u16,
            instruction: Zir.Inst.Index,
            instruction_load: Zir.Inst.Index,
            decl_val: NullTerminatedString,
            decl_ref: NullTerminatedString,
        };
        pub fn wrap(cap: Unwrapped) Capture {
            return switch (cap) {
                .nested => |idx| .{
                    .tag = .nested,
                    .data = idx,
                },
                .instruction => |inst| .{
                    .tag = .instruction,
                    .data = @intCast(@intFromEnum(inst)),
                },
                .instruction_load => |inst| .{
                    .tag = .instruction_load,
                    .data = @intCast(@intFromEnum(inst)),
                },
                .decl_val => |str| .{
                    .tag = .decl_val,
                    .data = @intCast(@intFromEnum(str)),
                },
                .decl_ref => |str| .{
                    .tag = .decl_ref,
                    .data = @intCast(@intFromEnum(str)),
                },
            };
        }
        pub fn unwrap(cap: Capture) Unwrapped {
            return switch (cap.tag) {
                .nested => .{ .nested = @intCast(cap.data) },
                .instruction => .{ .instruction = @enumFromInt(cap.data) },
                .instruction_load => .{ .instruction_load = @enumFromInt(cap.data) },
                .decl_val => .{ .decl_val = @enumFromInt(cap.data) },
                .decl_ref => .{ .decl_ref = @enumFromInt(cap.data) },
            };
        }
    };

    pub const NameStrategy = enum(u2) {
        /// Use the same name as the parent declaration name.
        /// e.g. `const Foo = struct {...};`.
        parent,
        /// Use the name of the currently executing comptime function call,
        /// with the current parameters. e.g. `ArrayList(i32)`.
        func,
        /// Create an anonymous name for this declaration.
        /// Like this: "ParentDeclName_struct_69"
        anon,
        /// Use the name specified in the next `dbg_var_{val,ptr}` instruction.
        dbg_var,
    };

    pub const FullPtrCastFlags = packed struct(u5) {
        ptr_cast: bool = false,
        align_cast: bool = false,
        addrspace_cast: bool = false,
        const_cast: bool = false,
        volatile_cast: bool = false,

        pub inline fn needResultTypeBuiltinName(flags: FullPtrCastFlags) []const u8 {
            if (flags.ptr_cast) return "@ptrCast";
            if (flags.align_cast) return "@alignCast";
            if (flags.addrspace_cast) return "@addrSpaceCast";
            unreachable;
        }
    };

    /// Trailing:
    /// 0. tag_type: Ref, // if has_tag_type
    /// 1. captures_len: u32, // if has_captures_len
    /// 2. body_len: u32, // if has_body_len
    /// 3. fields_len: u32, // if has_fields_len
    /// 4. decls_len: u32, // if has_decls_len
    /// 5. capture: Capture // for every captures_len
    /// 6. decl: Index, // for every decls_len; points to a `declaration` instruction
    /// 7. inst: Index // for every body_len
    /// 8. has_bits: u32 // for every 32 fields
    ///    - the bit is whether corresponding field has an value expression
    /// 9. fields: { // for every fields_len
    ///        field_name: u32,
    ///        doc_comment: u32, // .empty if no doc_comment
    ///        value: Ref, // if corresponding bit is set
    ///    }
    pub const EnumDecl = struct {
        // These fields should be concatenated and reinterpreted as a `std.zig.SrcHash`.
        // This hash contains the source of all fields, and the backing type if specified.
        fields_hash_0: u32,
        fields_hash_1: u32,
        fields_hash_2: u32,
        fields_hash_3: u32,
        src_node: i32,

        pub fn src(self: EnumDecl) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }

        pub const Small = packed struct {
            has_tag_type: bool,
            has_captures_len: bool,
            has_body_len: bool,
            has_fields_len: bool,
            has_decls_len: bool,
            name_strategy: NameStrategy,
            nonexhaustive: bool,
            _: u8 = undefined,
        };
    };

    /// Trailing:
    /// 0. tag_type: Ref, // if has_tag_type
    /// 1. captures_len: u32 // if has_captures_len
    /// 2. body_len: u32, // if has_body_len
    /// 3. fields_len: u32, // if has_fields_len
    /// 4. decls_len: u37, // if has_decls_len
    /// 5. capture: Capture // for every captures_len
    /// 6. decl: Index, // for every decls_len; points to a `declaration` instruction
    /// 7. inst: Index // for every body_len
    /// 8. has_bits: u32 // for every 8 fields
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding field has a type expression
    ///      0b00X0: whether corresponding field has a align expression
    ///      0b0X00: whether corresponding field has a tag value expression
    ///      0bX000: unused
    /// 9. fields: { // for every fields_len
    ///        field_name: NullTerminatedString, // null terminated string index
    ///        doc_comment: NullTerminatedString, // .empty if no doc comment
    ///        field_type: Ref, // if corresponding bit is set
    ///        - if none, means `anytype`.
    ///        align: Ref, // if corresponding bit is set
    ///        tag_value: Ref, // if corresponding bit is set
    ///    }
    pub const UnionDecl = struct {
        // These fields should be concatenated and reinterpreted as a `std.zig.SrcHash`.
        // This hash contains the source of all fields, and any specified attributes (`extern` etc).
        fields_hash_0: u32,
        fields_hash_1: u32,
        fields_hash_2: u32,
        fields_hash_3: u32,
        src_node: i32,

        pub fn src(self: UnionDecl) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }

        pub const Small = packed struct {
            has_tag_type: bool,
            has_captures_len: bool,
            has_body_len: bool,
            has_fields_len: bool,
            has_decls_len: bool,
            name_strategy: NameStrategy,
            layout: std.builtin.Type.ContainerLayout,
            /// has_tag_type | auto_enum_tag | result
            /// -------------------------------------
            ///    false     | false         |  union { }
            ///    false     | true          |  union(enum) { }
            ///    true      | true          |  union(enum(T)) { }
            ///    true      | false         |  union(T) { }
            auto_enum_tag: bool,
            any_aligned_fields: bool,
            _: u5 = undefined,
        };
    };

    /// Trailing:
    /// 0. captures_len: u32, // if has_captures_len
    /// 1. decls_len: u32, // if has_decls_len
    /// 2. capture: Capture, // for every captures_len
    /// 3. decl: Index, // for every decls_len; points to a `declaration` instruction
    pub const OpaqueDecl = struct {
        src_node: i32,

        pub fn src(self: OpaqueDecl) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }

        pub const Small = packed struct {
            has_captures_len: bool,
            has_decls_len: bool,
            name_strategy: NameStrategy,
            _: u12 = undefined,
        };
    };

    /// Trailing:
    /// { // for every fields_len
    ///      field_name: NullTerminatedString // null terminated string index
    ///     doc_comment: NullTerminatedString // null terminated string index
    /// }
    pub const ErrorSetDecl = struct {
        fields_len: u32,
    };

    /// A f128 value, broken up into 4 u32 parts.
    pub const Float128 = struct {
        piece0: u32,
        piece1: u32,
        piece2: u32,
        piece3: u32,

        pub fn get(self: Float128) f128 {
            const int_bits = @as(u128, self.piece0) |
                (@as(u128, self.piece1) << 32) |
                (@as(u128, self.piece2) << 64) |
                (@as(u128, self.piece3) << 96);
            return @as(f128, @bitCast(int_bits));
        }
    };

    /// Trailing is an item per field.
    pub const StructInit = struct {
        fields_len: u32,

        pub const Item = struct {
            /// The `struct_init_field_type` ZIR instruction for this field init.
            field_type: Index,
            /// The field init expression to be used as the field value. This value will be coerced
            /// to the field type if not already.
            init: Ref,
        };
    };

    /// Trailing is an Item per field.
    /// TODO make this instead array of inits followed by array of names because
    /// it will be simpler Sema code and better for CPU cache.
    pub const StructInitAnon = struct {
        fields_len: u32,

        pub const Item = struct {
            /// Null-terminated string table index.
            field_name: NullTerminatedString,
            /// The field init expression to be used as the field value.
            init: Ref,
        };
    };

    pub const FieldType = struct {
        container_type: Ref,
        /// Offset into `string_bytes`, null terminated.
        name_start: NullTerminatedString,
    };

    pub const FieldTypeRef = struct {
        container_type: Ref,
        field_name: Ref,
    };

    pub const Cmpxchg = struct {
        node: i32,
        ptr: Ref,
        expected_value: Ref,
        new_value: Ref,
        success_order: Ref,
        failure_order: Ref,
    };

    pub const AtomicRmw = struct {
        ptr: Ref,
        operation: Ref,
        operand: Ref,
        ordering: Ref,
    };

    pub const UnionInit = struct {
        union_type: Ref,
        field_name: Ref,
        init: Ref,
    };

    pub const AtomicStore = struct {
        ptr: Ref,
        operand: Ref,
        ordering: Ref,
    };

    pub const AtomicLoad = struct {
        elem_type: Ref,
        ptr: Ref,
        ordering: Ref,
    };

    pub const MulAdd = struct {
        mulend1: Ref,
        mulend2: Ref,
        addend: Ref,
    };

    pub const FieldParentPtr = struct {
        src_node: i32,
        parent_ptr_type: Ref,
        field_name: Ref,
        field_ptr: Ref,

        pub fn src(self: FieldParentPtr) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }
    };

    pub const Shuffle = struct {
        elem_type: Ref,
        a: Ref,
        b: Ref,
        mask: Ref,
    };

    pub const Select = struct {
        node: i32,
        elem_type: Ref,
        pred: Ref,
        a: Ref,
        b: Ref,
    };

    pub const AsyncCall = struct {
        node: i32,
        frame_buffer: Ref,
        result_ptr: Ref,
        fn_ptr: Ref,
        args: Ref,
    };

    /// Trailing: inst: Index // for every body_len
    pub const Param = struct {
        /// Null-terminated string index.
        name: NullTerminatedString,
        /// Null-terminated string index.
        doc_comment: NullTerminatedString,
        /// The body contains the type of the parameter.
        body_len: u32,
    };

    /// Trailing:
    /// 0. type_inst: Ref,  // if small 0b000X is set
    /// 1. align_inst: Ref, // if small 0b00X0 is set
    pub const AllocExtended = struct {
        src_node: i32,

        pub const Small = packed struct {
            has_type: bool,
            has_align: bool,
            is_const: bool,
            is_comptime: bool,
            _: u12 = undefined,
        };
    };

    pub const Export = struct {
        /// If present, this is referring to a Decl via field access, e.g. `a.b`.
        /// If omitted, this is referring to a Decl via identifier, e.g. `a`.
        namespace: Ref,
        /// Null-terminated string index.
        decl_name: NullTerminatedString,
        options: Ref,
    };

    pub const ExportValue = struct {
        /// The comptime value to export.
        operand: Ref,
        options: Ref,
    };

    /// Trailing: `CompileErrors.Item` for each `items_len`.
    pub const CompileErrors = struct {
        items_len: u32,

        /// Trailing: `note_payload_index: u32` for each `notes_len`.
        /// It's a payload index of another `Item`.
        pub const Item = struct {
            /// null terminated string index
            msg: NullTerminatedString,
            node: Ast.Node.Index,
            /// If node is 0 then this will be populated.
            token: Ast.TokenIndex,
            /// Can be used in combination with `token`.
            byte_offset: u32,
            /// 0 or a payload index of a `Block`, each is a payload
            /// index of another `Item`.
            notes: u32,

            pub fn notesLen(item: Item, zir: Zir) u32 {
                if (item.notes == 0) return 0;
                const block = zir.extraData(Block, item.notes);
                return block.data.body_len;
            }
        };
    };

    /// Trailing: for each `imports_len` there is an Item
    pub const Imports = struct {
        imports_len: u32,

        pub const Item = struct {
            /// null terminated string index
            name: NullTerminatedString,
            /// points to the import name
            token: Ast.TokenIndex,
        };
    };

    pub const LineColumn = struct {
        line: u32,
        column: u32,
    };

    pub const ArrayInit = struct {
        ty: Ref,
        init_count: u32,
    };

    pub const Src = struct {
        node: i32,
        line: u32,
        column: u32,
    };

    pub const DeferErrCode = struct {
        remapped_err_code: Index,
        index: u32,
        len: u32,
    };

    pub const ValidateDestructure = struct {
        /// The value being destructured.
        operand: Ref,
        /// The `destructure_assign` node.
        destructure_node: i32,
        /// The expected field count.
        expect_len: u32,
    };

    pub const ArrayMul = struct {
        /// The result type of the array multiplication operation, or `.none` if none was available.
        res_ty: Ref,
        /// The LHS of the array multiplication.
        lhs: Ref,
        /// The RHS of the array multiplication.
        rhs: Ref,
    };

    pub const RestoreErrRetIndex = struct {
        src_node: i32,
        /// If `.none`, restore the trace to its state upon function entry.
        block: Ref,
        /// If `.none`, restore unconditionally.
        operand: Ref,

        pub fn src(self: RestoreErrRetIndex) LazySrcLoc {
            return LazySrcLoc.nodeOffset(self.src_node);
        }
    };
};

pub const SpecialProng = enum { none, @"else", under };

pub const DeclIterator = struct {
    extra_index: u32,
    decls_remaining: u32,
    zir: Zir,

    pub fn next(it: *DeclIterator) ?Inst.Index {
        if (it.decls_remaining == 0) return null;
        const decl_inst: Zir.Inst.Index = @enumFromInt(it.zir.extra[it.extra_index]);
        it.extra_index += 1;
        it.decls_remaining -= 1;
        assert(it.zir.instructions.items(.tag)[@intFromEnum(decl_inst)] == .declaration);
        return decl_inst;
    }
};

pub fn declIterator(zir: Zir, decl_inst: Zir.Inst.Index) DeclIterator {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);
    switch (tags[@intFromEnum(decl_inst)]) {
        // Functions are allowed and yield no iterations.
        // There is one case matching this in the extended instruction set below.
        .func, .func_inferred, .func_fancy => return .{
            .extra_index = undefined,
            .decls_remaining = 0,
            .zir = zir,
        },

        .extended => {
            const extended = datas[@intFromEnum(decl_inst)].extended;
            switch (extended.opcode) {
                .struct_decl => {
                    const small: Inst.StructDecl.Small = @bitCast(extended.small);
                    var extra_index: u32 = @intCast(extended.operand + @typeInfo(Inst.StructDecl).Struct.fields.len);
                    const captures_len = if (small.has_captures_len) captures_len: {
                        const captures_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :captures_len captures_len;
                    } else 0;
                    extra_index += @intFromBool(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    extra_index += captures_len;

                    if (small.has_backing_int) {
                        const backing_int_body_len = zir.extra[extra_index];
                        extra_index += 1; // backing_int_body_len
                        if (backing_int_body_len == 0) {
                            extra_index += 1; // backing_int_ref
                        } else {
                            extra_index += backing_int_body_len; // backing_int_body_inst
                        }
                    }

                    return .{
                        .extra_index = extra_index,
                        .decls_remaining = decls_len,
                        .zir = zir,
                    };
                },
                .enum_decl => {
                    const small: Inst.EnumDecl.Small = @bitCast(extended.small);
                    var extra_index: u32 = @intCast(extended.operand + @typeInfo(Inst.EnumDecl).Struct.fields.len);
                    extra_index += @intFromBool(small.has_tag_type);
                    const captures_len = if (small.has_captures_len) captures_len: {
                        const captures_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :captures_len captures_len;
                    } else 0;
                    extra_index += @intFromBool(small.has_body_len);
                    extra_index += @intFromBool(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    extra_index += captures_len;

                    return .{
                        .extra_index = extra_index,
                        .decls_remaining = decls_len,
                        .zir = zir,
                    };
                },
                .union_decl => {
                    const small: Inst.UnionDecl.Small = @bitCast(extended.small);
                    var extra_index: u32 = @intCast(extended.operand + @typeInfo(Inst.UnionDecl).Struct.fields.len);
                    extra_index += @intFromBool(small.has_tag_type);
                    const captures_len = if (small.has_captures_len) captures_len: {
                        const captures_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :captures_len captures_len;
                    } else 0;
                    extra_index += @intFromBool(small.has_body_len);
                    extra_index += @intFromBool(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    extra_index += captures_len;

                    return .{
                        .extra_index = extra_index,
                        .decls_remaining = decls_len,
                        .zir = zir,
                    };
                },
                .opaque_decl => {
                    const small: Inst.OpaqueDecl.Small = @bitCast(extended.small);
                    var extra_index: u32 = @intCast(extended.operand + @typeInfo(Inst.OpaqueDecl).Struct.fields.len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;
                    const captures_len = if (small.has_captures_len) captures_len: {
                        const captures_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :captures_len captures_len;
                    } else 0;

                    extra_index += captures_len;

                    return .{
                        .extra_index = extra_index,
                        .decls_remaining = decls_len,
                        .zir = zir,
                    };
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

/// The iterator would have to allocate memory anyway to iterate. So here we populate
/// an ArrayList as the result.
pub fn findDecls(zir: Zir, list: *std.ArrayList(Inst.Index), decl_inst: Zir.Inst.Index) !void {
    list.clearRetainingCapacity();
    const declaration, const extra_end = zir.getDeclaration(decl_inst);
    const bodies = declaration.getBodies(extra_end, zir);

    try zir.findDeclsBody(list, bodies.value_body);
    if (bodies.align_body) |b| try zir.findDeclsBody(list, b);
    if (bodies.linksection_body) |b| try zir.findDeclsBody(list, b);
    if (bodies.addrspace_body) |b| try zir.findDeclsBody(list, b);
}

fn findDeclsInner(
    zir: Zir,
    list: *std.ArrayList(Inst.Index),
    inst: Inst.Index,
) Allocator.Error!void {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);

    switch (tags[@intFromEnum(inst)]) {
        // Functions instructions are interesting and have a body.
        .func,
        .func_inferred,
        => {
            try list.append(inst);

            const inst_data = datas[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.Func, inst_data.payload_index);
            var extra_index: usize = extra.end;
            switch (extra.data.ret_body_len) {
                0 => {},
                1 => extra_index += 1,
                else => {
                    const body = zir.bodySlice(extra_index, extra.data.ret_body_len);
                    extra_index += body.len;
                    try zir.findDeclsBody(list, body);
                },
            }
            const body = zir.bodySlice(extra_index, extra.data.body_len);
            return zir.findDeclsBody(list, body);
        },
        .func_fancy => {
            try list.append(inst);

            const inst_data = datas[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.FuncFancy, inst_data.payload_index);
            var extra_index: usize = extra.end;
            extra_index += @intFromBool(extra.data.bits.has_lib_name);

            if (extra.data.bits.has_align_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.bodySlice(extra_index, body_len);
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_align_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_addrspace_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.bodySlice(extra_index, body_len);
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_addrspace_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_section_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.bodySlice(extra_index, body_len);
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_section_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_cc_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.bodySlice(extra_index, body_len);
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_cc_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_ret_ty_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.bodySlice(extra_index, body_len);
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_ret_ty_ref) {
                extra_index += 1;
            }

            extra_index += @intFromBool(extra.data.bits.has_any_noalias);

            const body = zir.bodySlice(extra_index, extra.data.body_len);
            return zir.findDeclsBody(list, body);
        },
        .extended => {
            const extended = datas[@intFromEnum(inst)].extended;
            switch (extended.opcode) {

                // Decl instructions are interesting but have no body.
                // TODO yes they do have a body actually. recurse over them just like block instructions.
                .struct_decl,
                .union_decl,
                .enum_decl,
                .opaque_decl,
                => return list.append(inst),

                else => return,
            }
        },

        // Block instructions, recurse over the bodies.

        .block, .block_comptime, .block_inline => {
            const inst_data = datas[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.Block, inst_data.payload_index);
            const body = zir.bodySlice(extra.end, extra.data.body_len);
            return zir.findDeclsBody(list, body);
        },
        .condbr, .condbr_inline => {
            const inst_data = datas[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.CondBr, inst_data.payload_index);
            const then_body = zir.bodySlice(extra.end, extra.data.then_body_len);
            const else_body = zir.bodySlice(extra.end + then_body.len, extra.data.else_body_len);
            try zir.findDeclsBody(list, then_body);
            try zir.findDeclsBody(list, else_body);
        },
        .@"try", .try_ptr => {
            const inst_data = datas[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.Try, inst_data.payload_index);
            const body = zir.bodySlice(extra.end, extra.data.body_len);
            try zir.findDeclsBody(list, body);
        },
        .switch_block => return findDeclsSwitch(zir, list, inst),

        .suspend_block => @panic("TODO iterate suspend block"),

        else => return, // Regular instruction, not interesting.
    }
}

fn findDeclsSwitch(
    zir: Zir,
    list: *std.ArrayList(Inst.Index),
    inst: Inst.Index,
) Allocator.Error!void {
    const inst_data = zir.instructions.items(.data)[@intFromEnum(inst)].pl_node;
    const extra = zir.extraData(Inst.SwitchBlock, inst_data.payload_index);

    var extra_index: usize = extra.end;

    const multi_cases_len = if (extra.data.bits.has_multi_cases) blk: {
        const multi_cases_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk multi_cases_len;
    } else 0;

    const special_prong = extra.data.bits.specialProng();
    if (special_prong != .none) {
        const body_len: u31 = @truncate(zir.extra[extra_index]);
        extra_index += 1;
        const body = zir.bodySlice(extra_index, body_len);
        extra_index += body.len;

        try zir.findDeclsBody(list, body);
    }

    {
        const scalar_cases_len = extra.data.bits.scalar_cases_len;
        for (0..scalar_cases_len) |_| {
            extra_index += 1;
            const body_len: u31 = @truncate(zir.extra[extra_index]);
            extra_index += 1;
            const body = zir.bodySlice(extra_index, body_len);
            extra_index += body_len;

            try zir.findDeclsBody(list, body);
        }
    }
    {
        for (0..multi_cases_len) |_| {
            const items_len = zir.extra[extra_index];
            extra_index += 1;
            const ranges_len = zir.extra[extra_index];
            extra_index += 1;
            const body_len: u31 = @truncate(zir.extra[extra_index]);
            extra_index += 1;
            const items = zir.refSlice(extra_index, items_len);
            extra_index += items_len;
            _ = items;

            var range_i: usize = 0;
            while (range_i < ranges_len) : (range_i += 1) {
                extra_index += 1;
                extra_index += 1;
            }

            const body = zir.bodySlice(extra_index, body_len);
            extra_index += body_len;

            try zir.findDeclsBody(list, body);
        }
    }
}

fn findDeclsBody(
    zir: Zir,
    list: *std.ArrayList(Inst.Index),
    body: []const Inst.Index,
) Allocator.Error!void {
    for (body) |member| {
        try zir.findDeclsInner(list, member);
    }
}

pub const FnInfo = struct {
    param_body: []const Inst.Index,
    param_body_inst: Inst.Index,
    ret_ty_body: []const Inst.Index,
    body: []const Inst.Index,
    ret_ty_ref: Zir.Inst.Ref,
    total_params_len: u32,
};

pub fn getParamBody(zir: Zir, fn_inst: Inst.Index) []const Zir.Inst.Index {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);
    const inst_data = datas[@intFromEnum(fn_inst)].pl_node;

    const param_block_index = switch (tags[@intFromEnum(fn_inst)]) {
        .func, .func_inferred => blk: {
            const extra = zir.extraData(Inst.Func, inst_data.payload_index);
            break :blk extra.data.param_block;
        },
        .func_fancy => blk: {
            const extra = zir.extraData(Inst.FuncFancy, inst_data.payload_index);
            break :blk extra.data.param_block;
        },
        else => unreachable,
    };

    switch (tags[@intFromEnum(param_block_index)]) {
        .block, .block_comptime, .block_inline => {
            const param_block = zir.extraData(Inst.Block, datas[@intFromEnum(param_block_index)].pl_node.payload_index);
            return zir.bodySlice(param_block.end, param_block.data.body_len);
        },
        .declaration => {
            const decl, const extra_end = zir.getDeclaration(param_block_index);
            return decl.getBodies(extra_end, zir).value_body;
        },
        else => unreachable,
    }
}

pub fn getFnInfo(zir: Zir, fn_inst: Inst.Index) FnInfo {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);
    const info: struct {
        param_block: Inst.Index,
        body: []const Inst.Index,
        ret_ty_ref: Inst.Ref,
        ret_ty_body: []const Inst.Index,
    } = switch (tags[@intFromEnum(fn_inst)]) {
        .func, .func_inferred => blk: {
            const inst_data = datas[@intFromEnum(fn_inst)].pl_node;
            const extra = zir.extraData(Inst.Func, inst_data.payload_index);

            var extra_index: usize = extra.end;
            var ret_ty_ref: Inst.Ref = .none;
            var ret_ty_body: []const Inst.Index = &.{};

            switch (extra.data.ret_body_len) {
                0 => {
                    ret_ty_ref = .void_type;
                },
                1 => {
                    ret_ty_ref = @enumFromInt(zir.extra[extra_index]);
                    extra_index += 1;
                },
                else => {
                    ret_ty_body = zir.bodySlice(extra_index, extra.data.ret_body_len);
                    extra_index += ret_ty_body.len;
                },
            }

            const body = zir.bodySlice(extra_index, extra.data.body_len);
            extra_index += body.len;

            break :blk .{
                .param_block = extra.data.param_block,
                .ret_ty_ref = ret_ty_ref,
                .ret_ty_body = ret_ty_body,
                .body = body,
            };
        },
        .func_fancy => blk: {
            const inst_data = datas[@intFromEnum(fn_inst)].pl_node;
            const extra = zir.extraData(Inst.FuncFancy, inst_data.payload_index);

            var extra_index: usize = extra.end;
            var ret_ty_ref: Inst.Ref = .void_type;
            var ret_ty_body: []const Inst.Index = &.{};

            extra_index += @intFromBool(extra.data.bits.has_lib_name);
            if (extra.data.bits.has_align_body) {
                extra_index += zir.extra[extra_index] + 1;
            } else if (extra.data.bits.has_align_ref) {
                extra_index += 1;
            }
            if (extra.data.bits.has_addrspace_body) {
                extra_index += zir.extra[extra_index] + 1;
            } else if (extra.data.bits.has_addrspace_ref) {
                extra_index += 1;
            }
            if (extra.data.bits.has_section_body) {
                extra_index += zir.extra[extra_index] + 1;
            } else if (extra.data.bits.has_section_ref) {
                extra_index += 1;
            }
            if (extra.data.bits.has_cc_body) {
                extra_index += zir.extra[extra_index] + 1;
            } else if (extra.data.bits.has_cc_ref) {
                extra_index += 1;
            }
            if (extra.data.bits.has_ret_ty_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                ret_ty_body = zir.bodySlice(extra_index, body_len);
                extra_index += ret_ty_body.len;
            } else if (extra.data.bits.has_ret_ty_ref) {
                ret_ty_ref = @enumFromInt(zir.extra[extra_index]);
                extra_index += 1;
            }

            extra_index += @intFromBool(extra.data.bits.has_any_noalias);

            const body = zir.bodySlice(extra_index, extra.data.body_len);
            extra_index += body.len;
            break :blk .{
                .param_block = extra.data.param_block,
                .ret_ty_ref = ret_ty_ref,
                .ret_ty_body = ret_ty_body,
                .body = body,
            };
        },
        else => unreachable,
    };
    const param_body = switch (tags[@intFromEnum(info.param_block)]) {
        .block, .block_comptime, .block_inline => param_body: {
            const param_block = zir.extraData(Inst.Block, datas[@intFromEnum(info.param_block)].pl_node.payload_index);
            break :param_body zir.bodySlice(param_block.end, param_block.data.body_len);
        },
        .declaration => param_body: {
            const decl, const extra_end = zir.getDeclaration(info.param_block);
            break :param_body decl.getBodies(extra_end, zir).value_body;
        },
        else => unreachable,
    };
    var total_params_len: u32 = 0;
    for (param_body) |inst| {
        switch (tags[@intFromEnum(inst)]) {
            .param, .param_comptime, .param_anytype, .param_anytype_comptime => {
                total_params_len += 1;
            },
            else => continue,
        }
    }
    return .{
        .param_body = param_body,
        .param_body_inst = info.param_block,
        .ret_ty_body = info.ret_ty_body,
        .ret_ty_ref = info.ret_ty_ref,
        .body = info.body,
        .total_params_len = total_params_len,
    };
}

pub fn getDeclaration(zir: Zir, inst: Zir.Inst.Index) struct { Inst.Declaration, u32 } {
    assert(zir.instructions.items(.tag)[@intFromEnum(inst)] == .declaration);
    const pl_node = zir.instructions.items(.data)[@intFromEnum(inst)].pl_node;
    const extra = zir.extraData(Inst.Declaration, pl_node.payload_index);
    return .{
        extra.data,
        @intCast(extra.end),
    };
}

pub fn getAssociatedSrcHash(zir: Zir, inst: Zir.Inst.Index) ?std.zig.SrcHash {
    const tag = zir.instructions.items(.tag);
    const data = zir.instructions.items(.data);
    switch (tag[@intFromEnum(inst)]) {
        .declaration => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.Declaration, pl_node.payload_index);
            return @bitCast([4]u32{
                extra.data.src_hash_0,
                extra.data.src_hash_1,
                extra.data.src_hash_2,
                extra.data.src_hash_3,
            });
        },
        .func, .func_inferred => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.Func, pl_node.payload_index);
            if (extra.data.body_len == 0) {
                // Function type or extern fn - no associated hash
                return null;
            }
            const extra_index = extra.end +
                1 +
                extra.data.body_len +
                @typeInfo(Inst.Func.SrcLocs).Struct.fields.len;
            return @bitCast([4]u32{
                zir.extra[extra_index + 0],
                zir.extra[extra_index + 1],
                zir.extra[extra_index + 2],
                zir.extra[extra_index + 3],
            });
        },
        .func_fancy => {
            const pl_node = data[@intFromEnum(inst)].pl_node;
            const extra = zir.extraData(Inst.FuncFancy, pl_node.payload_index);
            if (extra.data.body_len == 0) {
                // Function type or extern fn - no associated hash
                return null;
            }
            const bits = extra.data.bits;
            var extra_index = extra.end;
            extra_index += @intFromBool(bits.has_lib_name);
            if (bits.has_align_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1 + body_len;
            } else extra_index += @intFromBool(bits.has_align_ref);
            if (bits.has_addrspace_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1 + body_len;
            } else extra_index += @intFromBool(bits.has_addrspace_ref);
            if (bits.has_section_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1 + body_len;
            } else extra_index += @intFromBool(bits.has_section_ref);
            if (bits.has_cc_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1 + body_len;
            } else extra_index += @intFromBool(bits.has_cc_ref);
            if (bits.has_ret_ty_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1 + body_len;
            } else extra_index += @intFromBool(bits.has_ret_ty_ref);
            extra_index += @intFromBool(bits.has_any_noalias);
            extra_index += extra.data.body_len;
            extra_index += @typeInfo(Zir.Inst.Func.SrcLocs).Struct.fields.len;
            return @bitCast([4]u32{
                zir.extra[extra_index + 0],
                zir.extra[extra_index + 1],
                zir.extra[extra_index + 2],
                zir.extra[extra_index + 3],
            });
        },
        .extended => {},
        else => return null,
    }
    const extended = data[@intFromEnum(inst)].extended;
    switch (extended.opcode) {
        .struct_decl => {
            const extra = zir.extraData(Inst.StructDecl, extended.operand).data;
            return @bitCast([4]u32{
                extra.fields_hash_0,
                extra.fields_hash_1,
                extra.fields_hash_2,
                extra.fields_hash_3,
            });
        },
        .union_decl => {
            const extra = zir.extraData(Inst.UnionDecl, extended.operand).data;
            return @bitCast([4]u32{
                extra.fields_hash_0,
                extra.fields_hash_1,
                extra.fields_hash_2,
                extra.fields_hash_3,
            });
        },
        .enum_decl => {
            const extra = zir.extraData(Inst.EnumDecl, extended.operand).data;
            return @bitCast([4]u32{
                extra.fields_hash_0,
                extra.fields_hash_1,
                extra.fields_hash_2,
                extra.fields_hash_3,
            });
        },
        else => return null,
    }
}
