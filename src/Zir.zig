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
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const Module = @import("Module.zig");
const LazySrcLoc = Module.LazySrcLoc;

instructions: std.MultiArrayList(Inst).Slice,
/// In order to store references to strings in fewer bytes, we copy all
/// string bytes into here. String bytes can be null. It is up to whomever
/// is referencing the data here whether they want to store both index and length,
/// thus allowing null bytes, or store only index, and use null-termination. The
/// `string_bytes` array is agnostic to either usage.
/// Indexes 0 and 1 are reserved for special cases.
string_bytes: []u8,
/// The meaning of this data is determined by `Inst.Tag` value.
/// The first few indexes are reserved. See `ExtraIndex` for the values.
extra: []u32,

/// The data stored at byte offset 0 when ZIR is stored in a file.
pub const Header = extern struct {
    instructions_len: u32,
    string_bytes_len: u32,
    extra_len: u32,

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

/// Returns the requested data, as well as the new index which is at the start of the
/// trailers for the object.
pub fn extraData(code: Zir, comptime T: type, index: usize) struct { data: T, end: usize } {
    const fields = @typeInfo(T).Struct.fields;
    var i: usize = index;
    var result: T = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.field_type) {
            u32 => code.extra[i],
            Inst.Ref => @intToEnum(Inst.Ref, code.extra[i]),
            i32 => @bitCast(i32, code.extra[i]),
            Inst.Call.Flags => @bitCast(Inst.Call.Flags, code.extra[i]),
            Inst.BuiltinCall.Flags => @bitCast(Inst.BuiltinCall.Flags, code.extra[i]),
            Inst.SwitchBlock.Bits => @bitCast(Inst.SwitchBlock.Bits, code.extra[i]),
            Inst.FuncFancy.Bits => @bitCast(Inst.FuncFancy.Bits, code.extra[i]),
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return .{
        .data = result,
        .end = i,
    };
}

/// Given an index into `string_bytes` returns the null-terminated string found there.
pub fn nullTerminatedString(code: Zir, index: usize) [:0]const u8 {
    var end: usize = index;
    while (code.string_bytes[end] != 0) {
        end += 1;
    }
    return code.string_bytes[index..end :0];
}

pub fn refSlice(code: Zir, start: usize, len: usize) []Inst.Ref {
    const raw_slice = code.extra[start..][0..len];
    // TODO we should be able to directly `@ptrCast` the slice to the other slice type.
    return @ptrCast([*]Inst.Ref, raw_slice.ptr)[0..len];
}

pub fn hasCompileErrors(code: Zir) bool {
    return code.extra[@enumToInt(ExtraIndex.compile_errors)] != 0;
}

pub fn deinit(code: *Zir, gpa: Allocator) void {
    code.instructions.deinit(gpa);
    gpa.free(code.string_bytes);
    gpa.free(code.extra);
    code.* = undefined;
}

/// ZIR is structured so that the outermost "main" struct of any file
/// is always at index 0.
pub const main_struct_inst: Inst.Index = 0;

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
        /// Uses the `pl_node` union field. Payload is `Bin`.
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
        /// Given an indexable type, returns the type of the element at given index.
        /// Uses the `bin` union field. lhs is the indexable type, rhs is the index.
        elem_type_index,
        /// Given a pointer to an indexable object, returns the len property. This is
        /// used by for loops. This instruction also emits a for-loop specific compile
        /// error if the indexable object is not indexable.
        /// Uses the `un_node` field. The AST node is the for loop node.
        indexable_ptr_len,
        /// Create a `anyframe->T` type.
        /// Uses the `un_node` field.
        anyframe_type,
        /// Type coercion. No source location attached.
        /// Uses the `bin` field.
        as,
        /// Type coercion to the function's return type.
        /// Uses the `pl_node` field. Payload is `As`. AST node could be many things.
        as_node,
        /// Bitwise AND. `&`
        bit_and,
        /// Reinterpret the memory representation of a value as a different type.
        /// Uses the pl_node field with payload `Bin`.
        bitcast,
        /// Bitwise NOT. `~`
        /// Uses `un_tok`.
        bit_not,
        /// Bitwise OR. `|`
        bit_or,
        /// A labeled block of code, which can return a value.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block,
        /// A list of instructions which are analyzed in the parent context, without
        /// generating a runtime block. Must terminate with an "inline" variant of
        /// a noreturn instruction.
        /// Uses the `pl_node` union field. Payload is `Block`.
        block_inline,
        /// Implements `suspend {...}`.
        /// Uses the `pl_node` union field. Payload is `Block`.
        suspend_block,
        /// Boolean NOT. See also `bit_not`.
        /// Uses the `un_tok` field.
        bool_not,
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
        /// Return a value from a block. This instruction is used as the terminator
        /// of a `block_inline`. It allows using the return value from `Sema.analyzeBody`.
        /// This instruction may also be used when it is known that there is only one
        /// break instruction in a block, and the target block is the parent.
        /// Uses the `break` union field.
        break_inline,
        /// Function call.
        /// Uses the `pl_node` union field with payload `Call`.
        /// AST node is the function call.
        call,
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
        /// Coerces a result location pointer to a new element type. It is evaluated "backwards"-
        /// as type coercion from the new element type to the old element type.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        /// LHS is destination element type, RHS is result pointer.
        coerce_result_ptr,
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
        ///// Same as `try` except the operand is coerced to a comptime value, and
        ///// only the taken branch is analyzed. The block must terminate with an "inline"
        ///// variant of a noreturn instruction.
        //try_inline,
        /// Same as `try` except the operand is a pointer and the result is a pointer.
        try_ptr,
        ///// Same as `try_inline` except the operand is a pointer and the result is a pointer.
        //try_ptr_inline,
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
        /// Marks the beginning of a semantic scope for debug info variables.
        dbg_block_begin,
        /// Marks the end of a semantic scope for debug info variables.
        dbg_block_end,
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
        /// Uses the `pl_node` union field. AST node is the condition of a for loop. Payload is `Bin`.
        elem_ptr,
        /// Same as `elem_ptr_node` except the index is stored immediately rather than
        /// as a reference to another ZIR instruction.
        /// Uses the `pl_node` union field. AST node is an element inside array initialization
        /// syntax. Payload is `ElemPtrImm`.
        elem_ptr_imm,
        /// Given an array, slice, or pointer, returns the element at the provided index.
        /// Uses the `pl_node` union field. AST node is a[b] syntax. Payload is `Bin`.
        elem_val_node,
        /// Same as `elem_val_node` but used only for for loop.
        /// Uses the `pl_node` union field. AST node is the condition of a for loop. Payload is `Bin`.
        elem_val,
        /// Emits a compile error if the operand is not `void`.
        /// Uses the `un_node` field.
        ensure_result_used,
        /// Emits a compile error if an error is ignored.
        /// Uses the `un_node` field.
        ensure_result_non_error,
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
        /// Given a pointer to a struct or object that contains virtual fields, returns the
        /// named field.  If there is no named field, searches in the type for a decl that
        /// matches the field name.  The decl is resolved and we ensure that it's a function
        /// which can accept the object as the first parameter, with one pointer fixup.  If
        /// all of that works, this instruction produces a special "bound function" value
        /// which contains both the function and the saved first parameter value.
        /// Bound functions may only be used as the function parameter to a `call` or
        /// `builtin_call` instruction.  Any other use is invalid zir and may crash the compiler.
        field_call_bind,
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
        /// Merge two error sets into one, `E1 || E2`.
        /// Uses the `pl_node` field with payload `Bin`.
        merge_error_sets,
        /// Given a reference to a function and a parameter index, returns the
        /// type of the parameter. The only usage of this instruction is for the
        /// result location of parameters of function calls. In the case of a function's
        /// parameter type being `anytype`, it is the type coercion's job to detect this
        /// scenario and skip the coercion, so that semantic analysis of this instruction
        /// is not in a position where it must create an invalid type.
        /// Uses the `param_type` union field.
        param_type,
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
        ret_tok,
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
        /// Create a pointer type that does not have a sentinel, alignment, address space, or bit range specified.
        /// Uses the `ptr_type_simple` union field.
        ptr_type_simple,
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
        /// Write a value to a pointer. For loading, see `load`.
        /// Source location is assumed to be same as previous instruction.
        /// Uses the `bin` union field.
        store,
        /// Same as `store` except provides a source location.
        /// Uses the `pl_node` union field. Payload is `Bin`.
        store_node,
        /// This instruction is not really supposed to be emitted from AstGen; nevertheless it
        /// is sometimes emitted due to deficiencies in AstGen. When Sema sees this instruction,
        /// it must clean up after AstGen's mess by looking at various context clues and
        /// then treating it as one of the following:
        ///  * no-op
        ///  * store_to_inferred_ptr
        ///  * store
        /// Uses the `bin` union field with LHS as the pointer to store to.
        store_to_block_ptr,
        /// Same as `store` but the type of the value being stored will be used to infer
        /// the pointer type.
        /// Uses the `bin` union field - Astgen.zig depends on the ability to change
        /// the tag of an instruction from `store_to_block_ptr` to `store_to_inferred_ptr`
        /// without changing the data.
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
        /// Given an integer type, returns the integer type for the RHS of a shift operation.
        /// Uses the `un_node` field.
        log2_int_type,
        /// Asserts control-flow will not reach this instruction (`unreachable`).
        /// Uses the `unreachable` union field.
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
        /// A switch expression. Uses the `pl_node` union field.
        /// AST node is the switch, payload is `SwitchBlock`.
        switch_block,
        /// Produces the value that will be switched on. For example, for
        /// integers, it returns the integer with no modifications. For tagged unions, it
        /// returns the active enum tag.
        /// Uses the `un_node` union field.
        switch_cond,
        /// Same as `switch_cond`, except the input operand is a pointer to
        /// what will be switched on.
        /// Uses the `un_node` union field.
        switch_cond_ref,
        /// Produces the capture value for a switch prong.
        /// Uses the `switch_capture` field.
        /// If the `prong_index` field is max int, it means this is the capture
        /// for the else/`_` prong.
        switch_capture,
        /// Produces the capture value for a switch prong.
        /// Result is a pointer to the value.
        /// Uses the `switch_capture` field.
        /// If the `prong_index` field is max int, it means this is the capture
        /// for the else/`_` prong.
        switch_capture_ref,
        /// Produces the capture value for a switch prong.
        /// The prong is one of the multi cases.
        /// Uses the `switch_capture` field.
        switch_capture_multi,
        /// Produces the capture value for a switch prong.
        /// The prong is one of the multi cases.
        /// Result is a pointer to the value.
        /// Uses the `switch_capture` field.
        switch_capture_multi_ref,
        /// Given a
        ///   *A returns *A
        ///   *E!A returns *A
        ///   *?A returns *A
        /// Uses the `un_node` field.
        array_base_ptr,
        /// Given a
        ///   *S returns *S
        ///   *E!S returns *S
        ///   *?S returns *S
        /// Uses the `un_node` field.
        field_base_ptr,
        /// Checks that the type supports array init syntax.
        /// Uses the `un_node` field.
        validate_array_init_ty,
        /// Checks that the type supports struct init syntax.
        /// Uses the `un_node` field.
        validate_struct_init_ty,
        /// Given a set of `field_ptr` instructions, assumes they are all part of a struct
        /// initialization expression, and emits compile errors for duplicate fields
        /// as well as missing fields, if applicable.
        /// This instruction asserts that there is at least one field_ptr instruction,
        /// because it must use one of them to find out the struct type.
        /// Uses the `pl_node` field. Payload is `Block`.
        validate_struct_init,
        /// Same as `validate_struct_init` but additionally communicates that the
        /// resulting struct initialization value is within a comptime scope.
        validate_struct_init_comptime,
        /// Given a set of `elem_ptr_imm` instructions, assumes they are all part of an
        /// array initialization expression, and emits a compile error if the number of
        /// elements does not match the array type.
        /// This instruction asserts that there is at least one `elem_ptr_imm` instruction,
        /// because it must use one of them to find out the array type.
        /// Uses the `pl_node` field. Payload is `Block`.
        validate_array_init,
        /// Same as `validate_array_init` but additionally communicates that the
        /// resulting array initialization value is within a comptime scope.
        validate_array_init_comptime,
        /// Check that operand type supports the dereference operand (.*).
        /// Uses the `un_node` field.
        validate_deref,
        /// A struct literal with a specified type, with no fields.
        /// Uses the `un_node` field.
        struct_init_empty,
        /// Given a struct or union, and a field name as a string index,
        /// returns the field type. Uses the `pl_node` field. Payload is `FieldType`.
        field_type,
        /// Given a struct or union, and a field name as a Ref,
        /// returns the field type. Uses the `pl_node` field. Payload is `FieldTypeRef`.
        field_type_ref,
        /// Finalizes a typed struct or union initialization, performs validation, and returns the
        /// struct or union value.
        /// Uses the `pl_node` field. Payload is `StructInit`.
        struct_init,
        /// Struct initialization syntax, make the result a pointer.
        /// Uses the `pl_node` field. Payload is `StructInit`.
        struct_init_ref,
        /// Struct initialization without a type.
        /// Uses the `pl_node` field. Payload is `StructInitAnon`.
        struct_init_anon,
        /// Anonymous struct initialization syntax, make the result a pointer.
        /// Uses the `pl_node` field. Payload is `StructInitAnon`.
        struct_init_anon_ref,
        /// Array initialization syntax.
        /// Uses the `pl_node` field. Payload is `MultiOp`.
        array_init,
        /// Anonymous array initialization syntax.
        /// Uses the `pl_node` field. Payload is `MultiOp`.
        array_init_anon,
        /// Array initialization syntax, make the result a pointer.
        /// Uses the `pl_node` field. Payload is `MultiOp`.
        array_init_ref,
        /// Anonymous array initialization syntax, make the result a pointer.
        /// Uses the `pl_node` field. Payload is `MultiOp`.
        array_init_anon_ref,
        /// Implements the `@unionInit` builtin.
        /// Uses the `pl_node` field. Payload is `UnionInit`.
        union_init,
        /// Implements the `@typeInfo` builtin. Uses `un_node`.
        type_info,
        /// Implements the `@sizeOf` builtin. Uses `un_node`.
        size_of,
        /// Implements the `@bitSizeOf` builtin. Uses `un_node`.
        bit_size_of,

        /// Implement builtin `@ptrToInt`. Uses `un_node`.
        /// Convert a pointer to a `usize` integer.
        ptr_to_int,
        /// Emit an error message and fail compilation.
        /// Uses the `un_node` field.
        compile_error,
        /// Changes the maximum number of backwards branches that compile-time
        /// code execution can use before giving up and making a compile error.
        /// Uses the `un_node` union field.
        set_eval_branch_quota,
        /// Converts an enum value into an integer. Resulting type will be the tag type
        /// of the enum. Uses `un_node`.
        enum_to_int,
        /// Implement builtin `@alignOf`. Uses `un_node`.
        align_of,
        /// Implement builtin `@boolToInt`. Uses `un_node`.
        bool_to_int,
        /// Implement builtin `@embedFile`. Uses `un_node`.
        embed_file,
        /// Implement builtin `@errorName`. Uses `un_node`.
        error_name,
        /// Implement builtin `@panic`. Uses `un_node`.
        panic,
        /// Same as `panic` but forces comptime.
        panic_comptime,
        /// Implement builtin `@setCold`. Uses `un_node`.
        set_cold,
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
        /// Implement builtin `@fabs`. Uses `un_node`.
        fabs,
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
        /// Implement builtin `@Type`. Uses `un_node`.
        reify,
        /// Implement builtin `@typeName`. Uses `un_node`.
        type_name,
        /// Implement builtin `@Frame`. Uses `un_node`.
        frame_type,
        /// Implement builtin `@frameSize`. Uses `un_node`.
        frame_size,

        /// Implements the `@floatToInt` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        float_to_int,
        /// Implements the `@intToFloat` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        int_to_float,
        /// Implements the `@intToPtr` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        int_to_ptr,
        /// Converts an integer into an enum value.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        int_to_enum,
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
        ptr_cast,
        /// Implements the `@truncate` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest type, `rhs` is operand.
        truncate,
        /// Implements the `@alignCast` builtin.
        /// Uses `pl_node` with payload `Bin`. `lhs` is dest alignment, `rhs` is operand.
        align_cast,

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
        /// Implements the `@cmpxchgStrong` builtin.
        /// Uses the `pl_node` union field with payload `Cmpxchg`.
        cmpxchg_strong,
        /// Implements the `@cmpxchgWeak` builtin.
        /// Uses the `pl_node` union field with payload `Cmpxchg`.
        cmpxchg_weak,
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
        /// Implements the `@fieldParentPtr` builtin.
        /// Uses the `pl_node` union field with payload `FieldParentPtr`.
        field_parent_ptr,
        /// Implements the `@memcpy` builtin.
        /// Uses the `pl_node` union field with payload `Memcpy`.
        memcpy,
        /// Implements the `@memset` builtin.
        /// Uses the `pl_node` union field with payload `Memset`.
        memset,
        /// Implements the `@minimum` builtin.
        /// Uses the `pl_node` union field with payload `Bin`
        minimum,
        /// Implements the `@maximum` builtin.
        /// Uses the `pl_node` union field with payload `Bin`
        maximum,
        /// Implements the `@asyncCall` builtin.
        /// Uses the `pl_node` union field with payload `AsyncCall`.
        builtin_async_call,
        /// Implements the `@cImport` builtin.
        /// Uses the `pl_node` union field with payload `Block`.
        c_import,

        /// Allocates stack local memory.
        /// Uses the `un_node` union field. The operand is the type of the allocated object.
        /// The node source location points to a var decl node.
        alloc,
        /// Same as `alloc` except mutable.
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
        /// Turns a pointer coming from an `alloc`, `alloc_inferred`, `alloc_inferred_comptime` or
        /// `Extended.alloc` into a constant version of the same pointer.
        /// Uses the `un_node` union field.
        make_ptr_const,

        /// Implements `resume` syntax. Uses `un_node` field.
        @"resume",
        @"await",

        /// When a type or function refers to a comptime value from an outer
        /// scope, that forms a closure over comptime value.  The outer scope
        /// will record a capture of that value, which encodes its current state
        /// and marks it to persist.  Uses `un_tok` field.  Operand is the
        /// instruction value to capture.
        closure_capture,
        /// The inner scope of a closure uses closure_get to retrieve the value
        /// stored by the outer scope.  Uses `inst_node` field.  Operand is the
        /// closure_capture instruction ref.
        closure_get,

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
                .elem_type_index,
                .indexable_ptr_len,
                .anyframe_type,
                .as,
                .as_node,
                .bit_and,
                .bitcast,
                .bit_or,
                .block,
                .block_inline,
                .suspend_block,
                .loop,
                .bool_br_and,
                .bool_br_or,
                .bool_not,
                .call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .coerce_result_ptr,
                .error_set_decl,
                .error_set_decl_anon,
                .error_set_decl_func,
                .dbg_stmt,
                .dbg_var_ptr,
                .dbg_var_val,
                .dbg_block_begin,
                .dbg_block_end,
                .decl_ref,
                .decl_val,
                .load,
                .div,
                .elem_ptr,
                .elem_val,
                .elem_ptr_node,
                .elem_ptr_imm,
                .elem_val_node,
                .ensure_result_used,
                .ensure_result_non_error,
                .@"export",
                .export_value,
                .field_ptr,
                .field_val,
                .field_call_bind,
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
                .mod_rem,
                .mul,
                .mulwrap,
                .mul_sat,
                .param_type,
                .ref,
                .shl,
                .shl_sat,
                .shr,
                .store,
                .store_node,
                .store_to_block_ptr,
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
                .merge_error_sets,
                .error_union_type,
                .bit_not,
                .error_value,
                .slice_start,
                .slice_end,
                .slice_sentinel,
                .import,
                .typeof_log2_int_type,
                .log2_int_type,
                .resolve_inferred_alloc,
                .set_eval_branch_quota,
                .switch_capture,
                .switch_capture_ref,
                .switch_capture_multi,
                .switch_capture_multi_ref,
                .switch_block,
                .switch_cond,
                .switch_cond_ref,
                .array_base_ptr,
                .field_base_ptr,
                .validate_array_init_ty,
                .validate_struct_init_ty,
                .validate_struct_init,
                .validate_struct_init_comptime,
                .validate_array_init,
                .validate_array_init_comptime,
                .validate_deref,
                .struct_init_empty,
                .struct_init,
                .struct_init_ref,
                .struct_init_anon,
                .struct_init_anon_ref,
                .array_init,
                .array_init_anon,
                .array_init_ref,
                .array_init_anon_ref,
                .union_init,
                .field_type,
                .field_type_ref,
                .int_to_enum,
                .enum_to_int,
                .type_info,
                .size_of,
                .bit_size_of,
                .ptr_to_int,
                .align_of,
                .bool_to_int,
                .embed_file,
                .error_name,
                .set_cold,
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
                .fabs,
                .floor,
                .ceil,
                .trunc,
                .round,
                .tag_name,
                .reify,
                .type_name,
                .frame_type,
                .frame_size,
                .float_to_int,
                .int_to_float,
                .int_to_ptr,
                .float_cast,
                .int_cast,
                .ptr_cast,
                .truncate,
                .align_cast,
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
                .cmpxchg_strong,
                .cmpxchg_weak,
                .splat,
                .reduce,
                .shuffle,
                .atomic_load,
                .atomic_rmw,
                .atomic_store,
                .mul_add,
                .builtin_call,
                .field_parent_ptr,
                .maximum,
                .memcpy,
                .memset,
                .minimum,
                .builtin_async_call,
                .c_import,
                .@"resume",
                .@"await",
                .ret_err_value_code,
                .extended,
                .closure_get,
                .closure_capture,
                .ret_ptr,
                .ret_type,
                .@"try",
                .try_ptr,
                //.try_inline,
                //.try_ptr_inline,
                => false,

                .@"break",
                .break_inline,
                .condbr,
                .condbr_inline,
                .compile_error,
                .ret_node,
                .ret_load,
                .ret_tok,
                .ret_err_value,
                .@"unreachable",
                .repeat,
                .repeat_inline,
                .panic,
                .panic_comptime,
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
                .dbg_block_begin,
                .dbg_block_end,
                .ensure_result_used,
                .ensure_result_non_error,
                .ensure_err_payload_void,
                .set_eval_branch_quota,
                .atomic_store,
                .store,
                .store_node,
                .store_to_block_ptr,
                .store_to_inferred_ptr,
                .resolve_inferred_alloc,
                .validate_array_init_ty,
                .validate_struct_init_ty,
                .validate_struct_init,
                .validate_struct_init_comptime,
                .validate_array_init,
                .validate_array_init_comptime,
                .validate_deref,
                .@"export",
                .export_value,
                .set_cold,
                .set_runtime_safety,
                .memcpy,
                .memset,
                => true,

                .param,
                .param_comptime,
                .param_anytype,
                .param_anytype_comptime,
                .add,
                .addwrap,
                .add_sat,
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
                .elem_type_index,
                .indexable_ptr_len,
                .anyframe_type,
                .as,
                .as_node,
                .bit_and,
                .bitcast,
                .bit_or,
                .block,
                .block_inline,
                .suspend_block,
                .loop,
                .bool_br_and,
                .bool_br_or,
                .bool_not,
                .call,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .coerce_result_ptr,
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
                .elem_ptr_imm,
                .elem_val_node,
                .field_ptr,
                .field_val,
                .field_call_bind,
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
                .mod_rem,
                .mul,
                .mulwrap,
                .mul_sat,
                .param_type,
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
                .err_union_payload_safe,
                .err_union_payload_unsafe,
                .err_union_payload_safe_ptr,
                .err_union_payload_unsafe_ptr,
                .err_union_code,
                .err_union_code_ptr,
                .ptr_type,
                .ptr_type_simple,
                .enum_literal,
                .merge_error_sets,
                .error_union_type,
                .bit_not,
                .error_value,
                .slice_start,
                .slice_end,
                .slice_sentinel,
                .import,
                .typeof_log2_int_type,
                .log2_int_type,
                .switch_capture,
                .switch_capture_ref,
                .switch_capture_multi,
                .switch_capture_multi_ref,
                .switch_block,
                .switch_cond,
                .switch_cond_ref,
                .array_base_ptr,
                .field_base_ptr,
                .struct_init_empty,
                .struct_init,
                .struct_init_ref,
                .struct_init_anon,
                .struct_init_anon_ref,
                .array_init,
                .array_init_anon,
                .array_init_ref,
                .array_init_anon_ref,
                .union_init,
                .field_type,
                .field_type_ref,
                .int_to_enum,
                .enum_to_int,
                .type_info,
                .size_of,
                .bit_size_of,
                .ptr_to_int,
                .align_of,
                .bool_to_int,
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
                .fabs,
                .floor,
                .ceil,
                .trunc,
                .round,
                .tag_name,
                .reify,
                .type_name,
                .frame_type,
                .frame_size,
                .float_to_int,
                .int_to_float,
                .int_to_ptr,
                .float_cast,
                .int_cast,
                .ptr_cast,
                .truncate,
                .align_cast,
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
                .cmpxchg_strong,
                .cmpxchg_weak,
                .splat,
                .reduce,
                .shuffle,
                .atomic_load,
                .atomic_rmw,
                .mul_add,
                .builtin_call,
                .field_parent_ptr,
                .maximum,
                .minimum,
                .builtin_async_call,
                .c_import,
                .@"resume",
                .@"await",
                .ret_err_value_code,
                .closure_get,
                .closure_capture,
                .@"break",
                .break_inline,
                .condbr,
                .condbr_inline,
                .compile_error,
                .ret_node,
                .ret_load,
                .ret_tok,
                .ret_err_value,
                .ret_ptr,
                .ret_type,
                .@"unreachable",
                .repeat,
                .repeat_inline,
                .panic,
                .panic_comptime,
                .@"try",
                .try_ptr,
                //.try_inline,
                //.try_ptr_inline,
                => false,

                .extended => switch (data.extended.opcode) {
                    .breakpoint, .fence => true,
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
                .sub = .pl_node,
                .subwrap = .pl_node,
                .sub_sat = .pl_node,
                .mul = .pl_node,
                .mulwrap = .pl_node,
                .mul_sat = .pl_node,

                .param_type = .param_type,
                .param = .pl_tok,
                .param_comptime = .pl_tok,
                .param_anytype = .str_tok,
                .param_anytype_comptime = .str_tok,
                .array_cat = .pl_node,
                .array_mul = .pl_node,
                .array_type = .pl_node,
                .array_type_sentinel = .pl_node,
                .vector_type = .pl_node,
                .elem_type_index = .bin,
                .indexable_ptr_len = .un_node,
                .anyframe_type = .un_node,
                .as = .bin,
                .as_node = .pl_node,
                .bit_and = .pl_node,
                .bitcast = .pl_node,
                .bit_not = .un_node,
                .bit_or = .pl_node,
                .block = .pl_node,
                .block_inline = .pl_node,
                .suspend_block = .pl_node,
                .bool_not = .un_node,
                .bool_br_and = .bool_br,
                .bool_br_or = .bool_br,
                .@"break" = .@"break",
                .break_inline = .@"break",
                .call = .pl_node,
                .cmp_lt = .pl_node,
                .cmp_lte = .pl_node,
                .cmp_eq = .pl_node,
                .cmp_gte = .pl_node,
                .cmp_gt = .pl_node,
                .cmp_neq = .pl_node,
                .coerce_result_ptr = .pl_node,
                .condbr = .pl_node,
                .condbr_inline = .pl_node,
                .@"try" = .pl_node,
                .try_ptr = .pl_node,
                //.try_inline = .pl_node,
                //.try_ptr_inline = .pl_node,
                .error_set_decl = .pl_node,
                .error_set_decl_anon = .pl_node,
                .error_set_decl_func = .pl_node,
                .dbg_stmt = .dbg_stmt,
                .dbg_var_ptr = .str_op,
                .dbg_var_val = .str_op,
                .dbg_block_begin = .tok,
                .dbg_block_end = .tok,
                .decl_ref = .str_tok,
                .decl_val = .str_tok,
                .load = .un_node,
                .div = .pl_node,
                .elem_ptr = .pl_node,
                .elem_ptr_node = .pl_node,
                .elem_ptr_imm = .pl_node,
                .elem_val = .pl_node,
                .elem_val_node = .pl_node,
                .ensure_result_used = .un_node,
                .ensure_result_non_error = .un_node,
                .error_union_type = .pl_node,
                .error_value = .str_tok,
                .@"export" = .pl_node,
                .export_value = .pl_node,
                .field_ptr = .pl_node,
                .field_val = .pl_node,
                .field_ptr_named = .pl_node,
                .field_val_named = .pl_node,
                .field_call_bind = .pl_node,
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
                .loop = .pl_node,
                .repeat = .node,
                .repeat_inline = .node,
                .merge_error_sets = .pl_node,
                .mod_rem = .pl_node,
                .ref = .un_tok,
                .ret_node = .un_node,
                .ret_load = .un_node,
                .ret_tok = .un_tok,
                .ret_err_value = .str_tok,
                .ret_err_value_code = .str_tok,
                .ret_ptr = .node,
                .ret_type = .node,
                .ptr_type_simple = .ptr_type_simple,
                .ptr_type = .ptr_type,
                .slice_start = .pl_node,
                .slice_end = .pl_node,
                .slice_sentinel = .pl_node,
                .store = .bin,
                .store_node = .pl_node,
                .store_to_block_ptr = .bin,
                .store_to_inferred_ptr = .bin,
                .str = .str,
                .negate = .un_node,
                .negate_wrap = .un_node,
                .typeof = .un_node,
                .typeof_log2_int_type = .un_node,
                .log2_int_type = .un_node,
                .@"unreachable" = .@"unreachable",
                .xor = .pl_node,
                .optional_type = .un_node,
                .optional_payload_safe = .un_node,
                .optional_payload_unsafe = .un_node,
                .optional_payload_safe_ptr = .un_node,
                .optional_payload_unsafe_ptr = .un_node,
                .err_union_payload_safe = .un_node,
                .err_union_payload_unsafe = .un_node,
                .err_union_payload_safe_ptr = .un_node,
                .err_union_payload_unsafe_ptr = .un_node,
                .err_union_code = .un_node,
                .err_union_code_ptr = .un_node,
                .ensure_err_payload_void = .un_tok,
                .enum_literal = .str_tok,
                .switch_block = .pl_node,
                .switch_cond = .un_node,
                .switch_cond_ref = .un_node,
                .switch_capture = .switch_capture,
                .switch_capture_ref = .switch_capture,
                .switch_capture_multi = .switch_capture,
                .switch_capture_multi_ref = .switch_capture,
                .array_base_ptr = .un_node,
                .field_base_ptr = .un_node,
                .validate_array_init_ty = .un_node,
                .validate_struct_init_ty = .un_node,
                .validate_struct_init = .pl_node,
                .validate_struct_init_comptime = .pl_node,
                .validate_array_init = .pl_node,
                .validate_array_init_comptime = .pl_node,
                .validate_deref = .un_node,
                .struct_init_empty = .un_node,
                .field_type = .pl_node,
                .field_type_ref = .pl_node,
                .struct_init = .pl_node,
                .struct_init_ref = .pl_node,
                .struct_init_anon = .pl_node,
                .struct_init_anon_ref = .pl_node,
                .array_init = .pl_node,
                .array_init_anon = .pl_node,
                .array_init_ref = .pl_node,
                .array_init_anon_ref = .pl_node,
                .union_init = .pl_node,
                .type_info = .un_node,
                .size_of = .un_node,
                .bit_size_of = .un_node,

                .ptr_to_int = .un_node,
                .compile_error = .un_node,
                .set_eval_branch_quota = .un_node,
                .enum_to_int = .un_node,
                .align_of = .un_node,
                .bool_to_int = .un_node,
                .embed_file = .un_node,
                .error_name = .un_node,
                .panic = .un_node,
                .panic_comptime = .un_node,
                .set_cold = .un_node,
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
                .fabs = .un_node,
                .floor = .un_node,
                .ceil = .un_node,
                .trunc = .un_node,
                .round = .un_node,
                .tag_name = .un_node,
                .reify = .un_node,
                .type_name = .un_node,
                .frame_type = .un_node,
                .frame_size = .un_node,

                .float_to_int = .pl_node,
                .int_to_float = .pl_node,
                .int_to_ptr = .pl_node,
                .int_to_enum = .pl_node,
                .float_cast = .pl_node,
                .int_cast = .pl_node,
                .ptr_cast = .pl_node,
                .truncate = .pl_node,
                .align_cast = .pl_node,
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
                .cmpxchg_strong = .pl_node,
                .cmpxchg_weak = .pl_node,
                .splat = .pl_node,
                .reduce = .pl_node,
                .shuffle = .pl_node,
                .atomic_load = .pl_node,
                .atomic_rmw = .pl_node,
                .atomic_store = .pl_node,
                .mul_add = .pl_node,
                .builtin_call = .pl_node,
                .field_parent_ptr = .pl_node,
                .maximum = .pl_node,
                .memcpy = .pl_node,
                .memset = .pl_node,
                .minimum = .pl_node,
                .builtin_async_call = .pl_node,
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

                .closure_capture = .un_tok,
                .closure_get = .inst_node,

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
        /// Log compile time variables and emit an error message.
        /// `operand` is payload index to `NodeMultiOp`.
        /// `small` is `operands_len`.
        /// The AST node is the compile log builtin call.
        compile_log,
        /// The builtin `@TypeOf` which returns the type after Peer Type Resolution
        /// of one or more params.
        /// `operand` is payload index to `NodeMultiOp`.
        /// `small` is `operands_len`.
        /// The AST node is the builtin call.
        typeof_peer,
        /// Implements the `@addWithOverflow` builtin.
        /// `operand` is payload index to `OverflowArithmetic`.
        /// `small` is unused.
        add_with_overflow,
        /// Implements the `@subWithOverflow` builtin.
        /// `operand` is payload index to `OverflowArithmetic`.
        /// `small` is unused.
        sub_with_overflow,
        /// Implements the `@mulWithOverflow` builtin.
        /// `operand` is payload index to `OverflowArithmetic`.
        /// `small` is unused.
        mul_with_overflow,
        /// Implements the `@shlWithOverflow` builtin.
        /// `operand` is payload index to `OverflowArithmetic`.
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
        /// Given a pointer to a struct or object that contains virtual fields, returns the
        /// named field.  If there is no named field, searches in the type for a decl that
        /// matches the field name.  The decl is resolved and we ensure that it's a function
        /// which can accept the object as the first parameter, with one pointer fixup.  If
        /// all of that works, this instruction produces a special "bound function" value
        /// which contains both the function and the saved first parameter value.
        /// Bound functions may only be used as the function parameter to a `call` or
        /// `builtin_call` instruction.  Any other use is invalid zir and may crash the compiler.
        /// Uses `pl_node` field. The AST node is the `@field` builtin. Payload is FieldNamedNode.
        field_call_bind_named,
        /// Implements the `@fence` builtin.
        /// `operand` is payload index to `UnNode`.
        fence,
        /// Implement builtin `@setFloatMode`.
        /// `operand` is payload index to `UnNode`.
        set_float_mode,
        /// Implement builtin `@setAlignStack`.
        /// `operand` is payload index to `UnNode`.
        set_align_stack,
        /// Implements the `@errSetCast` builtin.
        /// `operand` is payload index to `BinNode`. `lhs` is dest type, `rhs` is operand.
        err_set_cast,
        /// `operand` is payload index to `UnNode`.
        await_nosuspend,
        /// `operand` is `src_node: i32`.
        breakpoint,
        /// Implements the `@select` builtin.
        /// operand` is payload index to `Select`.
        select,
        /// Implement builtin `@errToInt`.
        /// `operand` is payload index to `UnNode`.
        error_to_int,
        /// Implement builtin `@intToError`.
        /// `operand` is payload index to `UnNode`.
        int_to_error,

        pub const InstData = struct {
            opcode: Extended,
            small: u16,
            operand: u32,
        };
    };

    /// The position of a ZIR instruction within the `Zir` instructions array.
    pub const Index = u32;

    /// A reference to a TypedValue or ZIR instruction.
    ///
    /// If the Ref has a tag in this enum, it refers to a TypedValue which may be
    /// retrieved with Ref.toTypedValue().
    ///
    /// If the value of a Ref does not have a tag, it refers to a ZIR instruction.
    ///
    /// The first values after the the last tag refer to ZIR instructions which may
    /// be derived by subtracting `typed_value_map.len`.
    ///
    /// When adding a tag to this enum, consider adding a corresponding entry to
    /// `primitives` in astgen.
    ///
    /// The tag type is specified so that it is safe to bitcast between `[]u32`
    /// and `[]Ref`.
    pub const Ref = enum(u32) {
        /// This Ref does not correspond to any ZIR instruction or constant
        /// value and may instead be used as a sentinel to indicate null.
        none,

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
        call_options_type,
        prefetch_options_type,
        export_options_type,
        extern_options_type,
        type_info_type,
        manyptr_u8_type,
        manyptr_const_u8_type,
        fn_noreturn_no_args_type,
        fn_void_no_args_type,
        fn_naked_noreturn_no_args_type,
        fn_ccc_void_no_args_type,
        single_const_pointer_to_comptime_int_type,
        const_slice_u8_type,
        anyerror_void_error_union_type,
        generic_poison_type,

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
        /// `.{}` (untyped)
        empty_struct,
        /// `0` (usize)
        zero_usize,
        /// `1` (usize)
        one_usize,
        /// `std.builtin.CallingConvention.C`
        calling_convention_c,
        /// `std.builtin.CallingConvention.Inline`
        calling_convention_inline,
        /// Used for generic parameters where the type and value
        /// is not known until generic function instantiation.
        generic_poison,

        _,

        pub const typed_value_map = std.enums.directEnumArray(Ref, TypedValue, 0, .{
            .none = undefined,

            .u1_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.u1_type),
            },
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
            .u29_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.u29_type),
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
            .f80_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.f80_type),
            },
            .f128_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.f128_type),
            },
            .anyopaque_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.anyopaque_type),
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
            .anyframe_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.anyframe_type),
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
            .anyerror_void_error_union_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.anyerror_void_error_union_type),
            },
            .generic_poison_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.generic_poison_type),
            },
            .enum_literal_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.enum_literal_type),
            },
            .manyptr_u8_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.manyptr_u8_type),
            },
            .manyptr_const_u8_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.manyptr_const_u8_type),
            },
            .atomic_order_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.atomic_order_type),
            },
            .atomic_rmw_op_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.atomic_rmw_op_type),
            },
            .calling_convention_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.calling_convention_type),
            },
            .address_space_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.address_space_type),
            },
            .float_mode_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.float_mode_type),
            },
            .reduce_op_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.reduce_op_type),
            },
            .call_options_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.call_options_type),
            },
            .prefetch_options_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.prefetch_options_type),
            },
            .export_options_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.export_options_type),
            },
            .extern_options_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.extern_options_type),
            },
            .type_info_type = .{
                .ty = Type.initTag(.type),
                .val = Value.initTag(.type_info_type),
            },

            .undef = .{
                .ty = Type.initTag(.@"undefined"),
                .val = Value.initTag(.undef),
            },
            .zero = .{
                .ty = Type.initTag(.comptime_int),
                .val = Value.initTag(.zero),
            },
            .zero_usize = .{
                .ty = Type.initTag(.usize),
                .val = Value.initTag(.zero),
            },
            .one = .{
                .ty = Type.initTag(.comptime_int),
                .val = Value.initTag(.one),
            },
            .one_usize = .{
                .ty = Type.initTag(.usize),
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
            .empty_struct = .{
                .ty = Type.initTag(.empty_struct_literal),
                .val = Value.initTag(.empty_struct_value),
            },
            .calling_convention_c = .{
                .ty = Type.initTag(.calling_convention),
                .val = .{ .ptr_otherwise = &calling_convention_c_payload.base },
            },
            .calling_convention_inline = .{
                .ty = Type.initTag(.calling_convention),
                .val = .{ .ptr_otherwise = &calling_convention_inline_payload.base },
            },
            .generic_poison = .{
                .ty = Type.initTag(.generic_poison),
                .val = Value.initTag(.generic_poison),
            },
        });
    };

    /// We would like this to be const but `Value` wants a mutable pointer for
    /// its payload field. Nothing should mutate this though.
    var calling_convention_c_payload: Value.Payload.U32 = .{
        .base = .{ .tag = .enum_field_index },
        .data = @enumToInt(std.builtin.CallingConvention.C),
    };

    /// We would like this to be const but `Value` wants a mutable pointer for
    /// its payload field. Nothing should mutate this though.
    var calling_convention_inline_payload: Value.Payload.U32 = .{
        .base = .{ .tag = .enum_field_index },
        .data = @enumToInt(std.builtin.CallingConvention.Inline),
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
            start: u32,
            /// Number of bytes in the string.
            len: u32,

            pub fn get(self: @This(), code: Zir) []const u8 {
                return code.string_bytes[self.start..][0..self.len];
            }
        },
        str_tok: struct {
            /// Offset into `string_bytes`. Null-terminated.
            start: u32,
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
        ptr_type_simple: struct {
            is_allowzero: bool,
            is_mutable: bool,
            is_volatile: bool,
            size: std.builtin.Type.Pointer.Size,
            elem_type: Ref,
        },
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
            force_comptime: bool,

            pub fn src(self: @This()) LazySrcLoc {
                return LazySrcLoc.nodeOffset(self.src_node);
            }
        },
        @"break": struct {
            block_inst: Index,
            operand: Ref,
        },
        switch_capture: struct {
            switch_inst: Index,
            prong_index: u32,
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
            str: u32,
            operand: Ref,

            pub fn getStr(self: @This(), zir: Zir) [:0]const u8 {
                return zir.nullTerminatedString(self.str);
            }
        },

        // Make sure we don't accidentally add a field to make this union
        // bigger than expected. Note that in Debug builds, Zig is allowed
        // to insert a secret field for safety checks.
        comptime {
            if (builtin.mode != .Debug) {
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
            ptr_type_simple,
            ptr_type,
            int_type,
            bool_br,
            param_type,
            @"unreachable",
            @"break",
            switch_capture,
            dbg_stmt,
            inst_node,
            str_op,
        };
    };

    /// Trailing:
    /// 0. Output for every outputs_len
    /// 1. Input for every inputs_len
    /// 2. clobber: u32 // index into string_bytes (null terminated) for every clobbers_len.
    pub const Asm = struct {
        src_node: i32,
        // null-terminated string index
        asm_source: u32,
        /// 1 bit for each outputs_len: whether it uses `-> T` or not.
        ///   0b0 - operand is a pointer to where to store the output.
        ///   0b1 - operand is a type; asm expression has the output as the result.
        /// 0b0X is the first output, 0bX0 is the second, etc.
        output_type_bits: u32,

        pub const Output = struct {
            /// index into string_bytes (null terminated)
            name: u32,
            /// index into string_bytes (null terminated)
            constraint: u32,
            /// How to interpret this is determined by `output_type_bits`.
            operand: Ref,
        };

        pub const Input = struct {
            /// index into string_bytes (null terminated)
            name: u32,
            /// index into string_bytes (null terminated)
            constraint: u32,
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
    pub const Func = struct {
        /// If this is 0 it means a void return type.
        /// If this is 1 it means return_type is a simple Ref
        ret_body_len: u32,
        /// Points to the block that contains the param instructions for this function.
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
    /// 0. lib_name: u32, // null terminated string index, if has_lib_name is set
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
    pub const FuncFancy = struct {
        /// Points to the block that contains the param instructions for this function.
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
            _: u16 = undefined,
        };
    };

    /// Trailing:
    /// 0. lib_name: u32, // null terminated string index, if has_lib_name is set
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
            is_threadlocal: bool,
            _: u11 = undefined,
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

    /// Stored inside extra, with trailing arguments according to `args_len`.
    /// Each argument is a `Ref`.
    pub const Call = struct {
        // Note: Flags *must* come first so that unusedResultExpr
        // can find it when it goes to modify them.
        flags: Flags,
        callee: Ref,

        pub const Flags = packed struct {
            /// std.builtin.CallOptions.Modifier in packed form
            pub const PackedModifier = u3;
            pub const PackedArgsLen = u28;

            packed_modifier: PackedModifier,
            ensure_result_used: bool = false,
            args_len: PackedArgsLen,

            comptime {
                if (@sizeOf(Flags) != 4 or @bitSizeOf(Flags) != 32)
                    @compileError("Layout of Call.Flags needs to be updated!");
                if (@bitSizeOf(std.builtin.CallOptions.Modifier) != @bitSizeOf(PackedModifier))
                    @compileError("Call.Flags.PackedModifier needs to be updated!");
            }
        };
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
        options: Ref,
        callee: Ref,
        args: Ref,

        pub const Flags = packed struct {
            is_nosuspend: bool,
            is_comptime: bool,
            ensure_result_used: bool,
            _: u29 = undefined,

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

    /// 0. multi_cases_len: u32 // If has_multi_cases is set.
    /// 1. else_body { // If has_else or has_under is set.
    ///        body_len: u32,
    ///        body member Index for every body_len
    ///     }
    /// 2. scalar_cases: { // for every scalar_cases_len
    ///        item: Ref,
    ///        body_len: u32,
    ///        body member Index for every body_len
    ///     }
    /// 3. multi_cases: { // for every multi_cases_len
    ///        items_len: u32,
    ///        ranges_len: u32,
    ///        body_len: u32,
    ///        item: Ref // for every items_len
    ///        ranges: { // for every ranges_len
    ///            item_first: Ref,
    ///            item_last: Ref,
    ///        }
    ///        body member Index for every body_len
    ///    }
    pub const SwitchBlock = struct {
        /// This is always a `switch_cond` or `switch_cond_ref` instruction.
        /// If it is a `switch_cond_ref` instruction, bits.is_ref is always true.
        /// If it is a `switch_cond` instruction, bits.is_ref is always false.
        /// Both `switch_cond` and `switch_cond_ref` return a value, not a pointer,
        /// that is useful for the case items, but cannot be used for capture values.
        /// For the capture values, Sema is expected to find the operand of this operand
        /// and use that.
        operand: Ref,
        bits: Bits,

        pub const Bits = packed struct {
            /// If true, one or more prongs have multiple items.
            has_multi_cases: bool,
            /// If true, there is an else prong. This is mutually exclusive with `has_under`.
            has_else: bool,
            /// If true, there is an underscore prong. This is mutually exclusive with `has_else`.
            has_under: bool,
            /// If true, the `operand` is a pointer to the value being switched on.
            /// TODO this flag is redundant with the tag of operand and can be removed.
            is_ref: bool,
            scalar_cases_len: ScalarCasesLen,

            pub const ScalarCasesLen = u28;

            pub fn specialProng(bits: Bits) SpecialProng {
                const has_else: u2 = @boolToInt(bits.has_else);
                const has_under: u2 = @boolToInt(bits.has_under);
                return switch ((has_else << 1) | has_under) {
                    0b00 => .none,
                    0b01 => .under,
                    0b10 => .@"else",
                    0b11 => unreachable,
                };
            }
        };

        pub const ScalarProng = struct {
            item: Ref,
            body: []const Index,
        };

        /// TODO performance optimization: instead of having this helper method
        /// change the definition of switch_capture instruction to store extra_index
        /// instead of prong_index. This way, Sema won't be doing O(N^2) iterations
        /// over the switch prongs.
        pub fn getScalarProng(
            self: SwitchBlock,
            zir: Zir,
            extra_end: usize,
            prong_index: usize,
        ) ScalarProng {
            var extra_index: usize = extra_end;

            if (self.bits.has_multi_cases) {
                extra_index += 1;
            }

            if (self.bits.specialProng() != .none) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                extra_index += body.len;
            }

            var scalar_i: usize = 0;
            while (true) : (scalar_i += 1) {
                const item = @intToEnum(Ref, zir.extra[extra_index]);
                extra_index += 1;
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                extra_index += body.len;

                if (scalar_i < prong_index) continue;

                return .{
                    .item = item,
                    .body = body,
                };
            }
        }

        pub const MultiProng = struct {
            items: []const Ref,
            body: []const Index,
        };

        pub fn getMultiProng(
            self: SwitchBlock,
            zir: Zir,
            extra_end: usize,
            prong_index: usize,
        ) MultiProng {
            // +1 for self.bits.has_multi_cases == true
            var extra_index: usize = extra_end + 1;

            if (self.bits.specialProng() != .none) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                extra_index += body.len;
            }

            var scalar_i: usize = 0;
            while (scalar_i < self.bits.scalar_cases_len) : (scalar_i += 1) {
                extra_index += 1;
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                extra_index += body_len;
            }
            var multi_i: u32 = 0;
            while (true) : (multi_i += 1) {
                const items_len = zir.extra[extra_index];
                extra_index += 2;
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const items = zir.refSlice(extra_index, items_len);
                extra_index += items_len;
                const body = zir.extra[extra_index..][0..body_len];
                extra_index += body_len;

                if (multi_i < prong_index) continue;
                return .{
                    .items = items,
                    .body = body,
                };
            }
        }
    };

    pub const Field = struct {
        lhs: Ref,
        /// Offset into `string_bytes`.
        field_name_start: u32,
    };

    pub const FieldNamed = struct {
        lhs: Ref,
        field_name: Ref,
    };

    pub const FieldNamedNode = struct {
        node: i32,
        lhs: Ref,
        field_name: Ref,
    };

    pub const As = struct {
        dest_type: Ref,
        operand: Ref,
    };

    /// Trailing:
    /// 0. src_node: i32, // if has_src_node
    /// 1. fields_len: u32, // if has_fields_len
    /// 2. decls_len: u32, // if has_decls_len
    /// 3. decl_bits: u32 // for every 8 decls
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding decl is pub
    ///      0b00X0: whether corresponding decl is exported
    ///      0b0X00: whether corresponding decl has an align expression
    ///      0bX000: whether corresponding decl has a linksection or an address space expression
    /// 4. decl: { // for every decls_len
    ///        src_hash: [4]u32, // hash of source bytes
    ///        line: u32, // line number of decl, relative to parent
    ///        name: u32, // null terminated string index
    ///        - 0 means comptime or usingnamespace decl.
    ///          - if name == 0 `is_exported` determines which one: 0=comptime,1=usingnamespace
    ///        - 1 means test decl with no name.
    ///        - 2 means that the test is a decltest, doc_comment gives the name of the identifier
    ///        - if there is a 0 byte at the position `name` indexes, it indicates
    ///          this is a test decl, and the name starts at `name+1`.
    ///        value: Index,
    ///        doc_comment: u32, 0 if no doc comment, if this is a decltest, doc_comment references the decl name in the string table
    ///        align: Ref, // if corresponding bit is set
    ///        link_section_or_address_space: { // if corresponding bit is set.
    ///            link_section: Ref,
    ///            address_space: Ref,
    ///        }
    ///    }
    /// 5. flags: u32 // for every 8 fields
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding field has an align expression
    ///      0b00X0: whether corresponding field has a default expression
    ///      0b0X00: whether corresponding field is comptime
    ///      0bX000: whether corresponding field has a type expression
    /// 6. fields: { // for every fields_len
    ///        field_name: u32,
    ///        doc_comment: u32, // 0 if no doc comment
    ///        field_type: Ref, // if corresponding bit is not set. none means anytype.
    ///        field_type_body_len: u32, // if corresponding bit is set
    ///        align_body_len: u32, // if corresponding bit is set
    ///        init_body_len: u32, // if corresponding bit is set
    ///    }
    /// 7. bodies: { // for every fields_len
    ///        field_type_body_inst: Inst, // for each field_type_body_len
    ///        align_body_inst: Inst, // for each align_body_len
    ///        init_body_inst: Inst, // for each init_body_len
    ///    }
    pub const StructDecl = struct {
        pub const Small = packed struct {
            has_src_node: bool,
            has_fields_len: bool,
            has_decls_len: bool,
            known_non_opv: bool,
            known_comptime_only: bool,
            name_strategy: NameStrategy,
            layout: std.builtin.Type.ContainerLayout,
            _: u7 = undefined,
        };
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

    /// Trailing:
    /// 0. src_node: i32, // if has_src_node
    /// 1. tag_type: Ref, // if has_tag_type
    /// 2. body_len: u32, // if has_body_len
    /// 3. fields_len: u32, // if has_fields_len
    /// 4. decls_len: u32, // if has_decls_len
    /// 5. decl_bits: u32 // for every 8 decls
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding decl is pub
    ///      0b00X0: whether corresponding decl is exported
    ///      0b0X00: whether corresponding decl has an align expression
    ///      0bX000: whether corresponding decl has a linksection or an address space expression
    /// 6. decl: { // for every decls_len
    ///        src_hash: [4]u32, // hash of source bytes
    ///        line: u32, // line number of decl, relative to parent
    ///        name: u32, // null terminated string index
    ///        - 0 means comptime or usingnamespace decl.
    ///          - if name == 0 `is_exported` determines which one: 0=comptime,1=usingnamespace
    ///        - 1 means test decl with no name.
    ///        - if there is a 0 byte at the position `name` indexes, it indicates
    ///          this is a test decl, and the name starts at `name+1`.
    ///        value: Index,
    ///        doc_comment: u32, // 0 if no doc_comment
    ///        align: Ref, // if corresponding bit is set
    ///        link_section_or_address_space: { // if corresponding bit is set.
    ///            link_section: Ref,
    ///            address_space: Ref,
    ///        }
    ///    }
    /// 7. inst: Index // for every body_len
    /// 8. has_bits: u32 // for every 32 fields
    ///    - the bit is whether corresponding field has an value expression
    /// 9. fields: { // for every fields_len
    ///        field_name: u32,
    ///        doc_comment: u32, // 0 if no doc_comment
    ///        value: Ref, // if corresponding bit is set
    ///    }
    pub const EnumDecl = struct {
        pub const Small = packed struct {
            has_src_node: bool,
            has_tag_type: bool,
            has_body_len: bool,
            has_fields_len: bool,
            has_decls_len: bool,
            name_strategy: NameStrategy,
            nonexhaustive: bool,
            _: u8 = undefined,
        };
    };

    /// Trailing:
    /// 0. src_node: i32, // if has_src_node
    /// 1. tag_type: Ref, // if has_tag_type
    /// 2. body_len: u32, // if has_body_len
    /// 3. fields_len: u32, // if has_fields_len
    /// 4. decls_len: u32, // if has_decls_len
    /// 5. decl_bits: u32 // for every 8 decls
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding decl is pub
    ///      0b00X0: whether corresponding decl is exported
    ///      0b0X00: whether corresponding decl has an align expression
    ///      0bX000: whether corresponding decl has a linksection or an address space expression
    /// 6. decl: { // for every decls_len
    ///        src_hash: [4]u32, // hash of source bytes
    ///        line: u32, // line number of decl, relative to parent
    ///        name: u32, // null terminated string index
    ///        - 0 means comptime or usingnamespace decl.
    ///          - if name == 0 `is_exported` determines which one: 0=comptime,1=usingnamespace
    ///        - 1 means test decl with no name.
    ///        - if there is a 0 byte at the position `name` indexes, it indicates
    ///          this is a test decl, and the name starts at `name+1`.
    ///        value: Index,
    ///        doc_comment: u32, // 0 if no doc comment
    ///        align: Ref, // if corresponding bit is set
    ///        link_section_or_address_space: { // if corresponding bit is set.
    ///            link_section: Ref,
    ///            address_space: Ref,
    ///        }
    ///    }
    /// 7. inst: Index // for every body_len
    /// 8. has_bits: u32 // for every 8 fields
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding field has a type expression
    ///      0b00X0: whether corresponding field has a align expression
    ///      0b0X00: whether corresponding field has a tag value expression
    ///      0bX000: unused
    /// 9. fields: { // for every fields_len
    ///        field_name: u32, // null terminated string index
    ///        doc_comment: u32, // 0 if no doc comment
    ///        field_type: Ref, // if corresponding bit is set
    ///        - if none, means `anytype`.
    ///        align: Ref, // if corresponding bit is set
    ///        tag_value: Ref, // if corresponding bit is set
    ///    }
    pub const UnionDecl = struct {
        pub const Small = packed struct {
            has_src_node: bool,
            has_tag_type: bool,
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
            _: u6 = undefined,
        };
    };

    /// Trailing:
    /// 0. src_node: i32, // if has_src_node
    /// 1. decls_len: u32, // if has_decls_len
    /// 2. decl_bits: u32 // for every 8 decls
    ///    - sets of 4 bits:
    ///      0b000X: whether corresponding decl is pub
    ///      0b00X0: whether corresponding decl is exported
    ///      0b0X00: whether corresponding decl has an align expression
    ///      0bX000: whether corresponding decl has a linksection or an address space expression
    /// 3. decl: { // for every decls_len
    ///        src_hash: [4]u32, // hash of source bytes
    ///        line: u32, // line number of decl, relative to parent
    ///        name: u32, // null terminated string index
    ///        - 0 means comptime or usingnamespace decl.
    ///          - if name == 0 `is_exported` determines which one: 0=comptime,1=usingnamespace
    ///        - 1 means test decl with no name.
    ///        - if there is a 0 byte at the position `name` indexes, it indicates
    ///          this is a test decl, and the name starts at `name+1`.
    ///        value: Index,
    ///        doc_comment: u32, // 0 if no doc comment,
    ///        align: Ref, // if corresponding bit is set
    ///        link_section_or_address_space: { // if corresponding bit is set.
    ///            link_section: Ref,
    ///            address_space: Ref,
    ///        }
    ///    }
    pub const OpaqueDecl = struct {
        pub const Small = packed struct {
            has_src_node: bool,
            has_decls_len: bool,
            name_strategy: NameStrategy,
            _: u12 = undefined,
        };
    };

    /// Trailing:
    /// { // for every fields_len
    ///      field_name: u32 // null terminated string index
    ///     doc_comment: u32 // null terminated string index
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
            return @bitCast(f128, int_bits);
        }
    };

    /// Trailing is an item per field.
    pub const StructInit = struct {
        fields_len: u32,

        pub const Item = struct {
            /// The `field_type` ZIR instruction for this field init.
            field_type: Index,
            /// The field init expression to be used as the field value.
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
            field_name: u32,
            /// The field init expression to be used as the field value.
            init: Ref,
        };
    };

    pub const FieldType = struct {
        container_type: Ref,
        /// Offset into `string_bytes`, null terminated.
        name_start: u32,
    };

    pub const FieldTypeRef = struct {
        container_type: Ref,
        field_name: Ref,
    };

    pub const OverflowArithmetic = struct {
        node: i32,
        lhs: Ref,
        rhs: Ref,
        ptr: Ref,
    };

    pub const Cmpxchg = struct {
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
        parent_type: Ref,
        field_name: Ref,
        field_ptr: Ref,
    };

    pub const Memcpy = struct {
        dest: Ref,
        source: Ref,
        byte_count: Ref,
    };

    pub const Memset = struct {
        dest: Ref,
        byte: Ref,
        byte_count: Ref,
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
        frame_buffer: Ref,
        result_ptr: Ref,
        fn_ptr: Ref,
        args: Ref,
    };

    /// Trailing: inst: Index // for every body_len
    pub const Param = struct {
        /// Null-terminated string index.
        name: u32,
        /// 0 if no doc comment
        doc_comment: u32,
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
        decl_name: u32,
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
            msg: u32,
            node: Ast.Node.Index,
            /// If node is 0 then this will be populated.
            token: Ast.TokenIndex,
            /// Can be used in combination with `token`.
            byte_offset: u32,
            /// 0 or a payload index of a `Block`, each is a payload
            /// index of another `Item`.
            notes: u32,
        };
    };

    /// Trailing: for each `imports_len` there is an Item
    pub const Imports = struct {
        imports_len: Inst.Index,

        pub const Item = struct {
            /// null terminated string index
            name: u32,
            /// points to the import name
            token: Ast.TokenIndex,
        };
    };

    pub const LineColumn = struct {
        line: u32,
        column: u32,
    };
};

pub const SpecialProng = enum { none, @"else", under };

pub const DeclIterator = struct {
    extra_index: usize,
    bit_bag_index: usize,
    cur_bit_bag: u32,
    decl_i: u32,
    decls_len: u32,
    zir: Zir,

    pub const Item = struct {
        name: [:0]const u8,
        sub_index: u32,
    };

    pub fn next(it: *DeclIterator) ?Item {
        if (it.decl_i >= it.decls_len) return null;

        if (it.decl_i % 8 == 0) {
            it.cur_bit_bag = it.zir.extra[it.bit_bag_index];
            it.bit_bag_index += 1;
        }
        it.decl_i += 1;

        const flags = @truncate(u4, it.cur_bit_bag);
        it.cur_bit_bag >>= 4;

        const sub_index = @intCast(u32, it.extra_index);
        it.extra_index += 5; // src_hash(4) + line(1)
        const name = it.zir.nullTerminatedString(it.zir.extra[it.extra_index]);
        it.extra_index += 3; // name(1) + value(1) + doc_comment(1)
        it.extra_index += @truncate(u1, flags >> 2);
        it.extra_index += @truncate(u1, flags >> 3);

        return Item{
            .sub_index = sub_index,
            .name = name,
        };
    }
};

pub fn declIterator(zir: Zir, decl_inst: u32) DeclIterator {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);
    switch (tags[decl_inst]) {
        // Functions are allowed and yield no iterations.
        // There is one case matching this in the extended instruction set below.
        .func, .func_inferred, .func_fancy => return declIteratorInner(zir, 0, 0),

        .extended => {
            const extended = datas[decl_inst].extended;
            switch (extended.opcode) {
                .struct_decl => {
                    const small = @bitCast(Inst.StructDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;
                    extra_index += @boolToInt(small.has_src_node);
                    extra_index += @boolToInt(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    return declIteratorInner(zir, extra_index, decls_len);
                },
                .enum_decl => {
                    const small = @bitCast(Inst.EnumDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;
                    extra_index += @boolToInt(small.has_src_node);
                    extra_index += @boolToInt(small.has_tag_type);
                    extra_index += @boolToInt(small.has_body_len);
                    extra_index += @boolToInt(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    return declIteratorInner(zir, extra_index, decls_len);
                },
                .union_decl => {
                    const small = @bitCast(Inst.UnionDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;
                    extra_index += @boolToInt(small.has_src_node);
                    extra_index += @boolToInt(small.has_tag_type);
                    extra_index += @boolToInt(small.has_body_len);
                    extra_index += @boolToInt(small.has_fields_len);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    return declIteratorInner(zir, extra_index, decls_len);
                },
                .opaque_decl => {
                    const small = @bitCast(Inst.OpaqueDecl.Small, extended.small);
                    var extra_index: usize = extended.operand;
                    extra_index += @boolToInt(small.has_src_node);
                    const decls_len = if (small.has_decls_len) decls_len: {
                        const decls_len = zir.extra[extra_index];
                        extra_index += 1;
                        break :decls_len decls_len;
                    } else 0;

                    return declIteratorInner(zir, extra_index, decls_len);
                },
                else => unreachable,
            }
        },
        else => unreachable,
    }
}

pub fn declIteratorInner(zir: Zir, extra_index: usize, decls_len: u32) DeclIterator {
    const bit_bags_count = std.math.divCeil(usize, decls_len, 8) catch unreachable;
    return .{
        .zir = zir,
        .extra_index = extra_index + bit_bags_count,
        .bit_bag_index = extra_index,
        .cur_bit_bag = undefined,
        .decl_i = 0,
        .decls_len = decls_len,
    };
}

/// The iterator would have to allocate memory anyway to iterate. So here we populate
/// an ArrayList as the result.
pub fn findDecls(zir: Zir, list: *std.ArrayList(Inst.Index), decl_sub_index: u32) !void {
    const block_inst = zir.extra[decl_sub_index + 6];
    list.clearRetainingCapacity();

    return zir.findDeclsInner(list, block_inst);
}

fn findDeclsInner(
    zir: Zir,
    list: *std.ArrayList(Inst.Index),
    inst: Inst.Index,
) Allocator.Error!void {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);

    switch (tags[inst]) {
        // Functions instructions are interesting and have a body.
        .func,
        .func_inferred,
        => {
            try list.append(inst);

            const inst_data = datas[inst].pl_node;
            const extra = zir.extraData(Inst.Func, inst_data.payload_index);
            var extra_index: usize = extra.end;
            switch (extra.data.ret_body_len) {
                0 => {},
                1 => extra_index += 1,
                else => {
                    const body = zir.extra[extra_index..][0..extra.data.ret_body_len];
                    extra_index += body.len;
                    try zir.findDeclsBody(list, body);
                },
            }
            const body = zir.extra[extra_index..][0..extra.data.body_len];
            return zir.findDeclsBody(list, body);
        },
        .func_fancy => {
            try list.append(inst);

            const inst_data = datas[inst].pl_node;
            const extra = zir.extraData(Inst.FuncFancy, inst_data.payload_index);
            var extra_index: usize = extra.end;
            extra_index += @boolToInt(extra.data.bits.has_lib_name);

            if (extra.data.bits.has_align_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_align_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_addrspace_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_addrspace_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_section_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_section_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_cc_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_cc_ref) {
                extra_index += 1;
            }

            if (extra.data.bits.has_ret_ty_body) {
                const body_len = zir.extra[extra_index];
                extra_index += 1;
                const body = zir.extra[extra_index..][0..body_len];
                try zir.findDeclsBody(list, body);
                extra_index += body.len;
            } else if (extra.data.bits.has_ret_ty_ref) {
                extra_index += 1;
            }

            extra_index += @boolToInt(extra.data.bits.has_any_noalias);

            const body = zir.extra[extra_index..][0..extra.data.body_len];
            return zir.findDeclsBody(list, body);
        },
        .extended => {
            const extended = datas[inst].extended;
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

        .block, .block_inline => {
            const inst_data = datas[inst].pl_node;
            const extra = zir.extraData(Inst.Block, inst_data.payload_index);
            const body = zir.extra[extra.end..][0..extra.data.body_len];
            return zir.findDeclsBody(list, body);
        },
        .condbr, .condbr_inline => {
            const inst_data = datas[inst].pl_node;
            const extra = zir.extraData(Inst.CondBr, inst_data.payload_index);
            const then_body = zir.extra[extra.end..][0..extra.data.then_body_len];
            const else_body = zir.extra[extra.end + then_body.len ..][0..extra.data.else_body_len];
            try zir.findDeclsBody(list, then_body);
            try zir.findDeclsBody(list, else_body);
        },
        .@"try", .try_ptr => {
            const inst_data = datas[inst].pl_node;
            const extra = zir.extraData(Inst.Try, inst_data.payload_index);
            const body = zir.extra[extra.end..][0..extra.data.body_len];
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
    const inst_data = zir.instructions.items(.data)[inst].pl_node;
    const extra = zir.extraData(Inst.SwitchBlock, inst_data.payload_index);

    var extra_index: usize = extra.end;

    const multi_cases_len = if (extra.data.bits.has_multi_cases) blk: {
        const multi_cases_len = zir.extra[extra_index];
        extra_index += 1;
        break :blk multi_cases_len;
    } else 0;

    const special_prong = extra.data.bits.specialProng();
    if (special_prong != .none) {
        const body_len = zir.extra[extra_index];
        extra_index += 1;
        const body = zir.extra[extra_index..][0..body_len];
        extra_index += body.len;

        try zir.findDeclsBody(list, body);
    }

    {
        const scalar_cases_len = extra.data.bits.scalar_cases_len;
        var scalar_i: usize = 0;
        while (scalar_i < scalar_cases_len) : (scalar_i += 1) {
            extra_index += 1;
            const body_len = zir.extra[extra_index];
            extra_index += 1;
            const body = zir.extra[extra_index..][0..body_len];
            extra_index += body_len;

            try zir.findDeclsBody(list, body);
        }
    }
    {
        var multi_i: usize = 0;
        while (multi_i < multi_cases_len) : (multi_i += 1) {
            const items_len = zir.extra[extra_index];
            extra_index += 1;
            const ranges_len = zir.extra[extra_index];
            extra_index += 1;
            const body_len = zir.extra[extra_index];
            extra_index += 1;
            const items = zir.refSlice(extra_index, items_len);
            extra_index += items_len;
            _ = items;

            var range_i: usize = 0;
            while (range_i < ranges_len) : (range_i += 1) {
                extra_index += 1;
                extra_index += 1;
            }

            const body = zir.extra[extra_index..][0..body_len];
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

pub fn getFnInfo(zir: Zir, fn_inst: Inst.Index) FnInfo {
    const tags = zir.instructions.items(.tag);
    const datas = zir.instructions.items(.data);
    const info: struct {
        param_block: Inst.Index,
        body: []const Inst.Index,
        ret_ty_ref: Inst.Ref,
        ret_ty_body: []const Inst.Index,
    } = switch (tags[fn_inst]) {
        .func, .func_inferred => blk: {
            const inst_data = datas[fn_inst].pl_node;
            const extra = zir.extraData(Inst.Func, inst_data.payload_index);

            var extra_index: usize = extra.end;
            var ret_ty_ref: Inst.Ref = .none;
            var ret_ty_body: []const Inst.Index = &.{};

            switch (extra.data.ret_body_len) {
                0 => {
                    ret_ty_ref = .void_type;
                },
                1 => {
                    ret_ty_ref = @intToEnum(Inst.Ref, zir.extra[extra_index]);
                    extra_index += 1;
                },
                else => {
                    ret_ty_body = zir.extra[extra_index..][0..extra.data.ret_body_len];
                    extra_index += ret_ty_body.len;
                },
            }

            const body = zir.extra[extra_index..][0..extra.data.body_len];
            extra_index += body.len;

            break :blk .{
                .param_block = extra.data.param_block,
                .ret_ty_ref = ret_ty_ref,
                .ret_ty_body = ret_ty_body,
                .body = body,
            };
        },
        .func_fancy => blk: {
            const inst_data = datas[fn_inst].pl_node;
            const extra = zir.extraData(Inst.FuncFancy, inst_data.payload_index);

            var extra_index: usize = extra.end;
            var ret_ty_ref: Inst.Ref = .void_type;
            var ret_ty_body: []const Inst.Index = &.{};

            extra_index += @boolToInt(extra.data.bits.has_lib_name);
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
                ret_ty_body = zir.extra[extra_index..][0..body_len];
                extra_index += ret_ty_body.len;
            } else if (extra.data.bits.has_ret_ty_ref) {
                ret_ty_ref = @intToEnum(Inst.Ref, zir.extra[extra_index]);
                extra_index += 1;
            }

            extra_index += @boolToInt(extra.data.bits.has_any_noalias);

            const body = zir.extra[extra_index..][0..extra.data.body_len];
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
    assert(tags[info.param_block] == .block or tags[info.param_block] == .block_inline);
    const param_block = zir.extraData(Inst.Block, datas[info.param_block].pl_node.payload_index);
    const param_body = zir.extra[param_block.end..][0..param_block.data.body_len];
    var total_params_len: u32 = 0;
    for (param_body) |inst| {
        switch (tags[inst]) {
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

const ref_start_index: u32 = Inst.Ref.typed_value_map.len;

pub fn indexToRef(inst: Inst.Index) Inst.Ref {
    return @intToEnum(Inst.Ref, ref_start_index + inst);
}

pub fn refToIndex(inst: Inst.Ref) ?Inst.Index {
    const ref_int = @enumToInt(inst);
    if (ref_int >= ref_start_index) {
        return ref_int - ref_start_index;
    } else {
        return null;
    }
}
