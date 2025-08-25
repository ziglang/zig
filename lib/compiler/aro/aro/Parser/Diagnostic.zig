const std = @import("std");

const Diagnostics = @import("../Diagnostics.zig");
const LangOpts = @import("../LangOpts.zig");
const Compilation = @import("../Compilation.zig");

const Diagnostic = @This();

fmt: []const u8,
kind: Diagnostics.Message.Kind,
opt: ?Diagnostics.Option = null,
extension: bool = false,

// TODO look into removing these
suppress_version: ?LangOpts.Standard = null,
suppress_unless_version: ?LangOpts.Standard = null,

const pointer_sign_message = " converts between pointers to integer types with different sign";

// Maybe someday this will no longer be needed.
pub const todo: Diagnostic = .{
    .fmt = "TODO: {s}",
    .kind = .@"error",
};

pub const closing_paren: Diagnostic = .{
    .fmt = "expected closing ')'",
    .kind = .@"error",
};

pub const to_match_paren: Diagnostic = .{
    .fmt = "to match this '('",
    .kind = .note,
};

pub const to_match_brace: Diagnostic = .{
    .fmt = "to match this '{'",
    .kind = .note,
};

pub const to_match_bracket: Diagnostic = .{
    .fmt = "to match this '['",
    .kind = .note,
};

pub const float_literal_in_pp_expr: Diagnostic = .{
    .fmt = "floating point literal in preprocessor expression",
    .kind = .@"error",
};

pub const expected_invalid: Diagnostic = .{
    .fmt = "expected '{tok_id}', found invalid bytes",
    .kind = .@"error",
};

pub const expected_eof: Diagnostic = .{
    .fmt = "expected '{tok_id}' before end of file",
    .kind = .@"error",
};

pub const expected_token: Diagnostic = .{
    .fmt = "expected '{tok_id}', found '{tok_id}'",
    .kind = .@"error",
};

pub const expected_expr: Diagnostic = .{
    .fmt = "expected expression",
    .kind = .@"error",
};

pub const unexpected_type_name: Diagnostic = .{
    .fmt = "unexpected type name '{s}': expected expression",
    .kind = .@"error",
};

pub const expected_integer_constant_expr: Diagnostic = .{
    .fmt = "expression is not an integer constant expression",
    .kind = .@"error",
};

pub const missing_type_specifier: Diagnostic = .{
    .fmt = "type specifier missing, defaults to 'int'",
    .opt = .@"implicit-int",
    .kind = .warning,
};

pub const missing_type_specifier_c23: Diagnostic = .{
    .fmt = "a type specifier is required for all declarations",
    .kind = .@"error",
};

pub const param_not_declared: Diagnostic = .{
    .fmt = "parameter '{s}' was not declared, defaults to 'int'",
    .opt = .@"implicit-int",
    .kind = .warning,
    .extension = true,
};

pub const multiple_storage_class: Diagnostic = .{
    .fmt = "cannot combine with previous '{s}' declaration specifier",
    .kind = .@"error",
};

pub const static_assert_failure: Diagnostic = .{
    .fmt = "static assertion failed",
    .kind = .@"error",
};

pub const static_assert_failure_message: Diagnostic = .{
    .fmt = "static assertion failed {s}",
    .kind = .@"error",
};

pub const expected_type: Diagnostic = .{
    .fmt = "expected a type",
    .kind = .@"error",
};

pub const cannot_combine_spec: Diagnostic = .{
    .fmt = "cannot combine with previous '{s}' specifier",
    .kind = .@"error",
};

pub const cannot_combine_spec_qt: Diagnostic = .{
    .fmt = "cannot combine with previous {qt} specifier",
    .kind = .@"error",
};

pub const cannot_combine_with_typeof: Diagnostic = .{
    .fmt = "'{s} typeof' is invalid",
    .kind = .@"error",
};

pub const duplicate_decl_spec: Diagnostic = .{
    .fmt = "duplicate '{s}' declaration specifier",
    .opt = .@"duplicate-decl-specifier",
    .kind = .warning,
};

pub const restrict_non_pointer: Diagnostic = .{
    .fmt = "restrict requires a pointer or reference ({qt} is invalid)",
    .kind = .@"error",
};

pub const expected_external_decl: Diagnostic = .{
    .fmt = "expected external declaration",
    .kind = .@"error",
};

pub const expected_ident_or_l_paren: Diagnostic = .{
    .fmt = "expected identifier or '('",
    .kind = .@"error",
};

pub const missing_declaration: Diagnostic = .{
    .fmt = "declaration does not declare anything",
    .opt = .@"missing-declaration",
    .kind = .warning,
    .extension = true,
};

pub const func_not_in_root: Diagnostic = .{
    .fmt = "function definition is not allowed here",
    .kind = .@"error",
};

pub const illegal_initializer: Diagnostic = .{
    .fmt = "illegal initializer (only variables can be initialized)",
    .kind = .@"error",
};

pub const extern_initializer: Diagnostic = .{
    .fmt = "extern variable has initializer",
    .opt = .@"extern-initializer",
    .kind = .warning,
};

pub const param_before_var_args: Diagnostic = .{
    .fmt = "ISO C requires a named parameter before '...'",
    .kind = .@"error",
    .suppress_version = .c23,
};

pub const void_only_param: Diagnostic = .{
    .fmt = "'void' must be the only parameter if specified",
    .kind = .@"error",
};

pub const void_param_qualified: Diagnostic = .{
    .fmt = "'void' parameter cannot be qualified",
    .kind = .@"error",
};

pub const void_must_be_first_param: Diagnostic = .{
    .fmt = "'void' must be the first parameter if specified",
    .kind = .@"error",
};

pub const invalid_storage_on_param: Diagnostic = .{
    .fmt = "invalid storage class on function parameter",
    .kind = .@"error",
};

pub const threadlocal_non_var: Diagnostic = .{
    .fmt = "_Thread_local only allowed on variables",
    .kind = .@"error",
};

pub const func_spec_non_func: Diagnostic = .{
    .fmt = "'{s}' can only appear on functions",
    .kind = .@"error",
};

pub const illegal_storage_on_func: Diagnostic = .{
    .fmt = "illegal storage class on function",
    .kind = .@"error",
};

pub const illegal_storage_on_global: Diagnostic = .{
    .fmt = "illegal storage class on global variable",
    .kind = .@"error",
};

pub const expected_stmt: Diagnostic = .{
    .fmt = "expected statement",
    .kind = .@"error",
};

pub const func_cannot_return_func: Diagnostic = .{
    .fmt = "function cannot return a function",
    .kind = .@"error",
};

pub const func_cannot_return_array: Diagnostic = .{
    .fmt = "function cannot return an array",
    .kind = .@"error",
};

pub const undeclared_identifier: Diagnostic = .{
    .fmt = "use of undeclared identifier '{s}'",
    .kind = .@"error",
};

pub const not_callable: Diagnostic = .{
    .fmt = "cannot call non function type {qt}",
    .kind = .@"error",
};

pub const unsupported_str_cat: Diagnostic = .{
    .fmt = "unsupported string literal concatenation",
    .kind = .@"error",
};

pub const static_func_not_global: Diagnostic = .{
    .fmt = "static functions must be global",
    .kind = .@"error",
};

pub const implicit_func_decl: Diagnostic = .{
    .fmt = "call to undeclared function '{s}'; ISO C99 and later do not support implicit function declarations",
    .opt = .@"implicit-function-declaration",
    .kind = .@"error",
};

pub const unknown_builtin: Diagnostic = .{
    .fmt = "use of unknown builtin '{s}'",
    .opt = .@"implicit-function-declaration",
    .kind = .@"error",
};

pub const implicit_builtin: Diagnostic = .{
    .fmt = "implicitly declaring library function '{s}'",
    .kind = .@"error",
    .opt = .@"implicit-function-declaration",
};

pub const implicit_builtin_header_note: Diagnostic = .{
    .fmt = "include the header <{s}.h> or explicitly provide a declaration for '{s}'",
    .kind = .note,
    .opt = .@"implicit-function-declaration",
};

pub const expected_param_decl: Diagnostic = .{
    .fmt = "expected parameter declaration",
    .kind = .@"error",
};

pub const invalid_old_style_params: Diagnostic = .{
    .fmt = "identifier parameter lists are only allowed in function definitions",
    .kind = .@"error",
};

pub const expected_fn_body: Diagnostic = .{
    .fmt = "expected function body after function declaration",
    .kind = .@"error",
};

pub const invalid_void_param: Diagnostic = .{
    .fmt = "parameter cannot have void type",
    .kind = .@"error",
};

pub const continue_not_in_loop: Diagnostic = .{
    .fmt = "'continue' statement not in a loop",
    .kind = .@"error",
};

pub const break_not_in_loop_or_switch: Diagnostic = .{
    .fmt = "'break' statement not in a loop or a switch",
    .kind = .@"error",
};

pub const unreachable_code: Diagnostic = .{
    .fmt = "unreachable code",
    .opt = .@"unreachable-code",
    .kind = .warning,
};

pub const duplicate_label: Diagnostic = .{
    .fmt = "duplicate label '{s}'",
    .kind = .@"error",
};

pub const previous_label: Diagnostic = .{
    .fmt = "previous definition of label '{s}' was here",
    .kind = .note,
};

pub const undeclared_label: Diagnostic = .{
    .fmt = "use of undeclared label '{s}'",
    .kind = .@"error",
};

pub const case_not_in_switch: Diagnostic = .{
    .fmt = "'{s}' statement not in a switch statement",
    .kind = .@"error",
};

pub const duplicate_switch_case: Diagnostic = .{
    .fmt = "duplicate case value '{value}'",
    .kind = .@"error",
};

pub const multiple_default: Diagnostic = .{
    .fmt = "multiple default cases in the same switch",
    .kind = .@"error",
};

pub const previous_case: Diagnostic = .{
    .fmt = "previous case defined here",
    .kind = .note,
};

pub const expected_arguments: Diagnostic = .{
    .fmt = "expected {d} argument(s) got {d}",
    .kind = .@"error",
};

pub const expected_arguments_old: Diagnostic = .{
    .fmt = expected_arguments.fmt,
    .kind = .warning,
};

pub const callee_with_static_array: Diagnostic = .{
    .fmt = "callee declares array parameter as static here",
    .kind = .note,
};

pub const array_argument_too_small: Diagnostic = .{
    .fmt = "array argument is too small; contains {d} elements, callee requires at least {d}",
    .kind = .warning,
    .opt = .@"array-bounds",
};

pub const non_null_argument: Diagnostic = .{
    .fmt = "null passed to a callee that requires a non-null argument",
    .kind = .warning,
    .opt = .nonnull,
};

pub const expected_at_least_arguments: Diagnostic = .{
    .fmt = "expected at least {d} argument(s) got {d}",
    .kind = .warning,
};

pub const invalid_static_star: Diagnostic = .{
    .fmt = "'static' may not be used with an unspecified variable length array size",
    .kind = .@"error",
};

pub const static_non_param: Diagnostic = .{
    .fmt = "'static' used outside of function parameters",
    .kind = .@"error",
};

pub const array_qualifiers: Diagnostic = .{
    .fmt = "type qualifier in non parameter array type",
    .kind = .@"error",
};

pub const star_non_param: Diagnostic = .{
    .fmt = "star modifier used outside of function parameters",
    .kind = .@"error",
};

pub const variable_len_array_file_scope: Diagnostic = .{
    .fmt = "variable length arrays not allowed at file scope",
    .kind = .@"error",
};

pub const useless_static: Diagnostic = .{
    .fmt = "'static' useless without a constant size",
    .kind = .warning,
};

pub const negative_array_size: Diagnostic = .{
    .fmt = "array size must be 0 or greater",
    .kind = .@"error",
};

pub const array_incomplete_elem: Diagnostic = .{
    .fmt = "array has incomplete element type {qt}",
    .kind = .@"error",
};

pub const array_func_elem: Diagnostic = .{
    .fmt = "arrays cannot have functions as their element type",
    .kind = .@"error",
};

pub const static_non_outermost_array: Diagnostic = .{
    .fmt = "'static' used in non-outermost array type",
    .kind = .@"error",
};

pub const qualifier_non_outermost_array: Diagnostic = .{
    .fmt = "type qualifier used in non-outermost array type",
    .kind = .@"error",
};

pub const array_overflow: Diagnostic = .{
    .fmt = "the pointer incremented by {value} refers past the last possible element in {d}-bit address space containing {d}-bit ({d}-byte) elements (max possible {d} elements)",
    .opt = .@"array-bounds",
    .kind = .warning,
};

pub const overflow: Diagnostic = .{
    .fmt = "overflow in expression; result is '{value}'",
    .kind = .warning,
    .opt = .@"integer-overflow",
};

pub const int_literal_too_big: Diagnostic = .{
    .fmt = "integer literal is too large to be represented in any integer type",
    .kind = .@"error",
};

pub const indirection_ptr: Diagnostic = .{
    .fmt = "indirection requires pointer operand",
    .kind = .@"error",
};

pub const addr_of_rvalue: Diagnostic = .{
    .fmt = "cannot take the address of an rvalue",
    .kind = .@"error",
};

pub const addr_of_bitfield: Diagnostic = .{
    .fmt = "address of bit-field requested",
    .kind = .@"error",
};

pub const not_assignable: Diagnostic = .{
    .fmt = "expression is not assignable",
    .kind = .@"error",
};

pub const ident_or_l_brace: Diagnostic = .{
    .fmt = "expected identifier or '{'",
    .kind = .@"error",
};

pub const empty_enum: Diagnostic = .{
    .fmt = "empty enum is invalid",
    .kind = .@"error",
};

pub const redefinition: Diagnostic = .{
    .fmt = "redefinition of '{s}'",
    .kind = .@"error",
};

pub const previous_definition: Diagnostic = .{
    .fmt = "previous definition is here",
    .kind = .note,
};

pub const previous_declaration: Diagnostic = .{
    .fmt = "previous declaration is here",
    .kind = .note,
};

pub const out_of_scope_use: Diagnostic = .{
    .fmt = "use of out-of-scope declaration of '{s}'",
    .kind = .warning,
    .opt = .@"out-of-scope-function",
};

pub const expected_identifier: Diagnostic = .{
    .fmt = "expected identifier",
    .kind = .@"error",
};

pub const expected_str_literal: Diagnostic = .{
    .fmt = "expected string literal for diagnostic message in static_assert",
    .kind = .@"error",
};

pub const expected_str_literal_in: Diagnostic = .{
    .fmt = "expected string literal in '{s}'",
    .kind = .@"error",
};

pub const parameter_missing: Diagnostic = .{
    .fmt = "parameter named '{s}' is missing",
    .kind = .@"error",
};

pub const empty_record: Diagnostic = .{
    .fmt = "empty {s} is a GNU extension",
    .opt = .@"gnu-empty-struct",
    .kind = .off,
    .extension = true,
};

pub const empty_record_size: Diagnostic = .{
    .fmt = "empty {s} has size 0 in C, size 1 in C++",
    .opt = .@"c++-compat",
    .kind = .off,
};

pub const wrong_tag: Diagnostic = .{
    .fmt = "use of '{s}' with tag type that does not match previous definition",
    .kind = .@"error",
};

pub const expected_parens_around_typename: Diagnostic = .{
    .fmt = "expected parentheses around type name",
    .kind = .@"error",
};

pub const alignof_expr: Diagnostic = .{
    .fmt = "'_Alignof' applied to an expression is a GNU extension",
    .opt = .@"gnu-alignof-expression",
    .kind = .warning,
    .extension = true,
};

pub const invalid_alignof: Diagnostic = .{
    .fmt = "invalid application of 'alignof' to an incomplete type {qt}",
    .kind = .@"error",
};

pub const invalid_sizeof: Diagnostic = .{
    .fmt = "invalid application of 'sizeof' to an incomplete type {qt}",
    .kind = .@"error",
};

pub const generic_qual_type: Diagnostic = .{
    .fmt = "generic association with qualifiers cannot be matched with",
    .opt = .@"generic-qual-type",
    .kind = .warning,
};

pub const generic_array_type: Diagnostic = .{
    .fmt = "generic association array type cannot be matched with",
    .opt = .@"generic-qual-type",
    .kind = .warning,
};

pub const generic_func_type: Diagnostic = .{
    .fmt = "generic association function type cannot be matched with",
    .opt = .@"generic-qual-type",
    .kind = .warning,
};

pub const generic_duplicate: Diagnostic = .{
    .fmt = "type {qt} in generic association compatible with previously specified type",
    .kind = .@"error",
};

pub const generic_duplicate_here: Diagnostic = .{
    .fmt = "compatible type {qt} specified here",
    .kind = .note,
};

pub const generic_duplicate_default: Diagnostic = .{
    .fmt = "duplicate default generic association",
    .kind = .@"error",
};

pub const generic_no_match: Diagnostic = .{
    .fmt = "controlling expression type {qt} not compatible with any generic association type",
    .kind = .@"error",
};

pub const must_use_struct: Diagnostic = .{
    .fmt = "must use 'struct' tag to refer to type '{s}'",
    .kind = .@"error",
};

pub const must_use_union: Diagnostic = .{
    .fmt = "must use 'union' tag to refer to type '{s}'",
    .kind = .@"error",
};

pub const must_use_enum: Diagnostic = .{
    .fmt = "must use 'enum' tag to refer to type '{s}'",
    .kind = .@"error",
};

pub const redefinition_different_sym: Diagnostic = .{
    .fmt = "redefinition of '{s}' as different kind of symbol",
    .kind = .@"error",
};

pub const redefinition_incompatible: Diagnostic = .{
    .fmt = "redefinition of '{s}' with a different type",
    .kind = .@"error",
};

pub const redefinition_of_parameter: Diagnostic = .{
    .fmt = "redefinition of parameter '{s}'",
    .kind = .@"error",
};

pub const invalid_bin_types: Diagnostic = .{
    .fmt = "invalid operands to binary expression ({qt} and {qt})",
    .kind = .@"error",
};

pub const incompatible_vec_types: Diagnostic = .{
    .fmt = "cannot convert between vector type {qt} and vector type {qt} as implicit conversion would cause truncation",
    .kind = .@"error",
};

pub const comparison_ptr_int: Diagnostic = .{
    .fmt = "comparison between pointer and integer ({qt} and {qt})",
    .kind = .warning,
    .opt = .@"pointer-integer-compare",
    .extension = true,
};

pub const comparison_distinct_ptr: Diagnostic = .{
    .fmt = "comparison of distinct pointer types ({qt} and {qt})",
    .kind = .warning,
    .opt = .@"compare-distinct-pointer-types",
    .extension = true,
};

pub const incompatible_pointers: Diagnostic = .{
    .fmt = "incompatible pointer types ({qt} and {qt})",
    .kind = .@"error",
};

pub const invalid_argument_un: Diagnostic = .{
    .fmt = "invalid argument type {qt} to unary expression",
    .kind = .@"error",
};

pub const incompatible_assign: Diagnostic = .{
    .fmt = "assignment to {qt} from incompatible type {qt}",
    .kind = .@"error",
};

pub const implicit_ptr_to_int: Diagnostic = .{
    .fmt = "implicit pointer to integer conversion from {qt} to {qt}",
    .kind = .warning,
    .opt = .@"int-conversion",
};

pub const invalid_cast_to_float: Diagnostic = .{
    .fmt = "pointer cannot be cast to type {qt}",
    .kind = .@"error",
};

pub const invalid_cast_to_pointer: Diagnostic = .{
    .fmt = "operand of type {qt} cannot be cast to a pointer type",
    .kind = .@"error",
};

pub const invalid_cast_type: Diagnostic = .{
    .fmt = "cannot cast to non arithmetic or pointer type {qt}",
    .kind = .@"error",
};

pub const cast_to_same_type: Diagnostic = .{
    .fmt = "C99 forbids casting nonscalar type {qt} to the same type",
    .kind = .off,
    .extension = true,
};

pub const invalid_cast_operand_type: Diagnostic = .{
    .fmt = "operand of type {qt} where arithmetic or pointer type is required",
    .kind = .@"error",
};

pub const qual_cast: Diagnostic = .{
    .fmt = "cast to type {qt} will not preserve qualifiers",
    .opt = .@"cast-qualifiers",
    .kind = .warning,
};

pub const invalid_vec_conversion: Diagnostic = .{
    .fmt = "invalid conversion between vector type {qt} and {qt} of different size",
    .kind = .@"error",
};

pub const invalid_vec_conversion_scalar: Diagnostic = .{
    .fmt = "invalid conversion between vector type {qt} and scalar type {qt}",
    .kind = .@"error",
};

pub const invalid_vec_conversion_int: Diagnostic = .{
    .fmt = "invalid conversion between vector type {qt} and integer type {qt} of different size",
    .kind = .@"error",
};

pub const invalid_index: Diagnostic = .{
    .fmt = "array subscript is not an integer",
    .kind = .@"error",
};

pub const invalid_subscript: Diagnostic = .{
    .fmt = "subscripted value is not an array, pointer or vector",
    .kind = .@"error",
};

pub const array_after: Diagnostic = .{
    .fmt = "array index {value} is past the end of the array",
    .opt = .@"array-bounds",
    .kind = .warning,
};

pub const array_before: Diagnostic = .{
    .fmt = "array index {value} is before the beginning of the array",
    .opt = .@"array-bounds",
    .kind = .warning,
};

pub const statement_int: Diagnostic = .{
    .fmt = "statement requires expression with integer type ({qt} invalid)",
    .kind = .@"error",
};

pub const statement_scalar: Diagnostic = .{
    .fmt = "statement requires expression with scalar type ({qt} invalid)",
    .kind = .@"error",
};

pub const func_should_return: Diagnostic = .{
    .fmt = "non-void function '{s}' should return a value",
    .opt = .@"return-type",
    .kind = .@"error",
};

pub const incompatible_return: Diagnostic = .{
    .fmt = "returning {qt} from a function with incompatible result type {qt}",
    .kind = .@"error",
};

pub const incompatible_return_sign: Diagnostic = .{
    .fmt = incompatible_return.fmt ++ pointer_sign_message,
    .kind = .warning,
    .opt = .@"pointer-sign",
};

pub const implicit_int_to_ptr: Diagnostic = .{
    .fmt = "implicit integer to pointer conversion from {qt} to {qt}",
    .opt = .@"int-conversion",
    .kind = .warning,
};

pub const func_does_not_return: Diagnostic = .{
    .fmt = "non-void function '{s}' does not return a value",
    .opt = .@"return-type",
    .kind = .warning,
};

pub const void_func_returns_value: Diagnostic = .{
    .fmt = "void function '{s}' should not return a value",
    .opt = .@"return-type",
    .kind = .@"error",
};

pub const incompatible_arg: Diagnostic = .{
    .fmt = "passing {qt} to parameter of incompatible type {qt}",
    .kind = .@"error",
};

pub const incompatible_ptr_arg: Diagnostic = .{
    .fmt = "passing {qt} to parameter of incompatible type {qt}",
    .kind = .warning,
    .opt = .@"incompatible-pointer-types",
};

pub const incompatible_ptr_arg_sign: Diagnostic = .{
    .fmt = incompatible_ptr_arg.fmt ++ pointer_sign_message,
    .kind = .warning,
    .opt = .@"pointer-sign",
};

pub const parameter_here: Diagnostic = .{
    .fmt = "passing argument to parameter here",
    .kind = .note,
};

pub const atomic_array: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to array type {qt}",
    .kind = .@"error",
};

pub const atomic_func: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to function type {qt}",
    .kind = .@"error",
};

pub const atomic_incomplete: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to incomplete type {qt}",
    .kind = .@"error",
};

pub const atomic_atomic: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to atomic type {qt}",
    .kind = .@"error",
};

pub const atomic_complex: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to complex type {qt}",
    .kind = .@"error",
};

pub const atomic_qualified: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to qualified type {qt}",
    .kind = .@"error",
};

pub const atomic_auto: Diagnostic = .{
    .fmt = "_Atomic cannot be applied to type 'auto' in C23",
    .kind = .@"error",
};

// pub const atomic_access: Diagnostic = .{
//     .fmt = "accessing a member of an atomic structure or union is undefined behavior",
//     .opt = .@"atomic-access",
//     .kind = .@"error",
// };

pub const addr_of_register: Diagnostic = .{
    .fmt = "address of register variable requested",
    .kind = .@"error",
};

pub const variable_incomplete_ty: Diagnostic = .{
    .fmt = "variable has incomplete type {qt}",
    .kind = .@"error",
};

pub const parameter_incomplete_ty: Diagnostic = .{
    .fmt = "parameter has incomplete type {qt}",
    .kind = .@"error",
};

pub const tentative_array: Diagnostic = .{
    .fmt = "tentative array definition assumed to have one element",
    .kind = .warning,
};

pub const deref_incomplete_ty_ptr: Diagnostic = .{
    .fmt = "dereferencing pointer to incomplete type {qt}",
    .kind = .@"error",
};

pub const alignas_on_func: Diagnostic = .{
    .fmt = "'_Alignas' attribute only applies to variables and fields",
    .kind = .@"error",
};

pub const alignas_on_param: Diagnostic = .{
    .fmt = "'_Alignas' attribute cannot be applied to a function parameter",
    .kind = .@"error",
};

pub const minimum_alignment: Diagnostic = .{
    .fmt = "requested alignment is less than minimum alignment of {d}",
    .kind = .@"error",
};

pub const maximum_alignment: Diagnostic = .{
    .fmt = "requested alignment of {value} is too large",
    .kind = .@"error",
};

pub const negative_alignment: Diagnostic = .{
    .fmt = "requested negative alignment of {value} is invalid",
    .kind = .@"error",
};

pub const align_ignored: Diagnostic = .{
    .fmt = "'_Alignas' attribute is ignored here",
    .kind = .warning,
};

// pub const zero_align_ignored: Diagnostic = .{
//     .fmt = "requested alignment of zero is ignored",
//     .kind = .warning,
// };

pub const non_pow2_align: Diagnostic = .{
    .fmt = "requested alignment is not a power of 2",
    .kind = .@"error",
};

pub const pointer_mismatch: Diagnostic = .{
    .fmt = "pointer type mismatch ({qt} and {qt})",
    .opt = .@"pointer-type-mismatch",
    .kind = .warning,
    .extension = true,
};

pub const static_assert_not_constant: Diagnostic = .{
    .fmt = "static assertion expression is not an integral constant expression",
    .kind = .@"error",
};

pub const static_assert_missing_message: Diagnostic = .{
    .fmt = "'_Static_assert' with no message is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .warning,
    .suppress_version = .c23,
    .extension = true,
};

pub const pre_c23_compat: Diagnostic = .{
    .fmt = "{s} is incompatible with C standards before C23",
    .kind = .off,
    .suppress_unless_version = .c23,
    .opt = .@"pre-c23-compat",
};

pub const unbound_vla: Diagnostic = .{
    .fmt = "variable length array must be bound in function definition",
    .kind = .@"error",
};

pub const array_too_large: Diagnostic = .{
    .fmt = "array is too large",
    .kind = .@"error",
};

pub const record_too_large: Diagnostic = .{
    .fmt = "type {qt} is too large",
    .kind = .@"error",
};

pub const incompatible_ptr_init: Diagnostic = .{
    .fmt = "incompatible pointer types initializing {qt} from incompatible type {qt}",
    .opt = .@"incompatible-pointer-types",
    .kind = .warning,
};

pub const incompatible_ptr_init_sign: Diagnostic = .{
    .fmt = incompatible_ptr_init.fmt ++ pointer_sign_message,
    .opt = .@"pointer-sign",
    .kind = .warning,
};

pub const incompatible_ptr_assign: Diagnostic = .{
    .fmt = "incompatible pointer types assigning to {qt} from incompatible type {qt}",
    .opt = .@"incompatible-pointer-types",
    .kind = .warning,
};

pub const incompatible_ptr_assign_sign: Diagnostic = .{
    .fmt = incompatible_ptr_assign.fmt ++ pointer_sign_message,
    .opt = .@"pointer-sign",
    .kind = .warning,
};

pub const vla_init: Diagnostic = .{
    .fmt = "variable-sized object may not be initialized",
    .kind = .@"error",
};

pub const func_init: Diagnostic = .{
    .fmt = "illegal initializer type",
    .kind = .@"error",
};

pub const incompatible_init: Diagnostic = .{
    .fmt = "initializing {qt} from incompatible type {qt}",
    .kind = .@"error",
};

pub const excess_scalar_init: Diagnostic = .{
    .fmt = "excess elements in scalar initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const excess_str_init: Diagnostic = .{
    .fmt = "excess elements in string initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const excess_struct_init: Diagnostic = .{
    .fmt = "excess elements in struct initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const excess_union_init: Diagnostic = .{
    .fmt = "excess elements in union initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const excess_array_init: Diagnostic = .{
    .fmt = "excess elements in array initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const excess_vector_init: Diagnostic = .{
    .fmt = "excess elements in vector initializer",
    .kind = .warning,
    .opt = .@"excess-initializers",
};

pub const str_init_too_long: Diagnostic = .{
    .fmt = "initializer-string for char array is too long",
    .opt = .@"excess-initializers",
    .kind = .warning,
    .extension = true,
};

pub const arr_init_too_long: Diagnostic = .{
    .fmt = "cannot initialize type {qt} with array of type {qt}",
    .kind = .@"error",
};

pub const empty_initializer: Diagnostic = .{
    .fmt = "use of an empty initializer is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .off,
    .suppress_version = .c23,
    .extension = true,
};

pub const division_by_zero: Diagnostic = .{
    .fmt = "{s} by zero is undefined",
    .kind = .warning,
    .opt = .@"division-by-zero",
};

pub const division_by_zero_macro: Diagnostic = .{
    .fmt = "{s} by zero in preprocessor expression",
    .kind = .@"error",
};

pub const builtin_choose_cond: Diagnostic = .{
    .fmt = "'__builtin_choose_expr' requires a constant expression",
    .kind = .@"error",
};

pub const convertvector_arg: Diagnostic = .{
    .fmt = "{s} argument to __builtin_convertvector must be a vector type",
    .kind = .@"error",
};

pub const convertvector_size: Diagnostic = .{
    .fmt = "first two arguments to __builtin_convertvector must have the same number of elements",
    .kind = .@"error",
};

pub const shufflevector_arg: Diagnostic = .{
    .fmt = "{s} argument to __builtin_shufflevector must be a vector type",
    .kind = .@"error",
};

pub const shufflevector_same_type: Diagnostic = .{
    .fmt = "first two arguments to '__builtin_shufflevector' must have the same type",
    .kind = .@"error",
};

pub const shufflevector_negative_index: Diagnostic = .{
    .fmt = "index for __builtin_shufflevector must be positive or -1",
    .kind = .@"error",
};

pub const shufflevector_index_too_big: Diagnostic = .{
    .fmt = "index for __builtin_shufflevector must be less than the total number of vector elements",
    .kind = .@"error",
};

pub const alignas_unavailable: Diagnostic = .{
    .fmt = "'_Alignas' attribute requires integer constant expression",
    .kind = .@"error",
};

pub const case_val_unavailable: Diagnostic = .{
    .fmt = "case value must be an integer constant expression",
    .kind = .@"error",
};

pub const enum_val_unavailable: Diagnostic = .{
    .fmt = "enum value must be an integer constant expression",
    .kind = .@"error",
};

pub const incompatible_array_init: Diagnostic = .{
    .fmt = "cannot initialize array of type {qt} with array of type {qt}",
    .kind = .@"error",
};

pub const array_init_str: Diagnostic = .{
    .fmt = "array initializer must be an initializer list or wide string literal",
    .kind = .@"error",
};

pub const initializer_overrides: Diagnostic = .{
    .fmt = "initializer overrides previous initialization",
    .opt = .@"initializer-overrides",
    .kind = .warning,
};

pub const previous_initializer: Diagnostic = .{
    .fmt = "previous initialization",
    .kind = .note,
};

pub const invalid_array_designator: Diagnostic = .{
    .fmt = "array designator used for non-array type {qt}",
    .kind = .@"error",
};

pub const negative_array_designator: Diagnostic = .{
    .fmt = "array designator value {value} is negative",
    .kind = .@"error",
};

pub const oob_array_designator: Diagnostic = .{
    .fmt = "array designator index {value} exceeds array bounds",
    .kind = .@"error",
};

pub const invalid_field_designator: Diagnostic = .{
    .fmt = "field designator used for non-record type {qt}",
    .kind = .@"error",
};

pub const no_such_field_designator: Diagnostic = .{
    .fmt = "record type has no field named '{s}'",
    .kind = .@"error",
};

pub const empty_aggregate_init_braces: Diagnostic = .{
    .fmt = "initializer for aggregate with no elements requires explicit braces",
    .kind = .@"error",
};

pub const ptr_init_discards_quals: Diagnostic = .{
    .fmt = "initializing {qt} from incompatible type {qt} discards qualifiers",
    .kind = .warning,
    .opt = .@"incompatible-pointer-types-discards-qualifiers",
};

pub const ptr_assign_discards_quals: Diagnostic = .{
    .fmt = "assigning to {qt} from incompatible type {qt} discards qualifiers",
    .kind = .warning,
    .opt = .@"incompatible-pointer-types-discards-qualifiers",
};

pub const ptr_ret_discards_quals: Diagnostic = .{
    .fmt = "returning {qt} from a function with incompatible result type {qt} discards qualifiers",
    .kind = .warning,
    .opt = .@"incompatible-pointer-types-discards-qualifiers",
};

pub const ptr_arg_discards_quals: Diagnostic = .{
    .fmt = "passing {qt} to parameter of incompatible type {qt} discards qualifiers",
    .kind = .warning,
    .opt = .@"incompatible-pointer-types-discards-qualifiers",
};

pub const unknown_attribute: Diagnostic = .{
    .fmt = "unknown attribute '{s}' ignored",
    .kind = .warning,
    .opt = .@"unknown-attributes",
};

pub const ignored_attribute: Diagnostic = .{
    .fmt = "attribute '{s}' ignored on {s}",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const invalid_fallthrough: Diagnostic = .{
    .fmt = "fallthrough annotation does not directly precede switch label",
    .kind = .@"error",
};

pub const cannot_apply_attribute_to_statement: Diagnostic = .{
    .fmt = "'{s}' attribute cannot be applied to a statement",
    .kind = .@"error",
};

pub const gnu_label_as_value: Diagnostic = .{
    .fmt = "use of GNU address-of-label extension",
    .opt = .@"gnu-label-as-value",
    .kind = .off,
    .extension = true,
};

pub const expected_record_ty: Diagnostic = .{
    .fmt = "member reference base type {qt} is not a structure or union",
    .kind = .@"error",
};

pub const member_expr_not_ptr: Diagnostic = .{
    .fmt = "member reference type {qt} is not a pointer; did you mean to use '.'?",
    .kind = .@"error",
};

pub const member_expr_ptr: Diagnostic = .{
    .fmt = "member reference type {qt} is a pointer; did you mean to use '->'?",
    .kind = .@"error",
};

pub const member_expr_atomic: Diagnostic = .{
    .fmt = "accessing a member of atomic type {qt} is undefined behavior",
    .kind = .@"error",
};

pub const no_such_member: Diagnostic = .{
    .fmt = "no member named '{s}' in {qt}",
    .kind = .@"error",
};

pub const invalid_computed_goto: Diagnostic = .{
    .fmt = "computed goto in function with no address-of-label expressions",
    .kind = .@"error",
};

pub const empty_translation_unit: Diagnostic = .{
    .fmt = "ISO C requires a translation unit to contain at least one declaration",
    .opt = .@"empty-translation-unit",
    .kind = .off,
    .extension = true,
};

pub const omitting_parameter_name: Diagnostic = .{
    .fmt = "omitting the parameter name in a function definition is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .warning,
    .suppress_version = .c23,
    .extension = true,
};

pub const non_int_bitfield: Diagnostic = .{
    .fmt = "bit-field has non-integer type {qt}",
    .kind = .@"error",
};

pub const negative_bitwidth: Diagnostic = .{
    .fmt = "bit-field has negative width ({value})",
    .kind = .@"error",
};

pub const zero_width_named_field: Diagnostic = .{
    .fmt = "named bit-field has zero width",
    .kind = .@"error",
};

pub const bitfield_too_big: Diagnostic = .{
    .fmt = "width of bit-field exceeds width of its type",
    .kind = .@"error",
};

pub const invalid_utf8: Diagnostic = .{
    .fmt = "source file is not valid UTF-8",
    .kind = .@"error",
};

pub const implicitly_unsigned_literal: Diagnostic = .{
    .fmt = "integer literal is too large to be represented in a signed integer type, interpreting as unsigned",
    .opt = .@"implicitly-unsigned-literal",
    .kind = .warning,
    .extension = true,
};

pub const invalid_preproc_operator: Diagnostic = .{
    .fmt = "token is not a valid binary operator in a preprocessor subexpression",
    .kind = .@"error",
};

pub const c99_compat: Diagnostic = .{
    .fmt = "using this character in an identifier is incompatible with C99",
    .kind = .off,
    .opt = .@"c99-compat",
};

pub const unexpected_character: Diagnostic = .{
    .fmt = "unexpected character <U+{codepoint}>",
    .kind = .@"error",
};

pub const invalid_identifier_start_char: Diagnostic = .{
    .fmt = "character <U+{codepoint}> not allowed at the start of an identifier",
    .kind = .@"error",
};

pub const unicode_zero_width: Diagnostic = .{
    .fmt = "identifier contains Unicode character <U+{codepoint}> that is invisible in some environments",
    .kind = .warning,
    .opt = .@"unicode-homoglyph",
};

pub const unicode_homoglyph: Diagnostic = .{
    .fmt = "treating Unicode character <U+{codepoint}> as identifier character rather than as '{s}' symbol",
    .kind = .warning,
    .opt = .@"unicode-homoglyph",
};

pub const meaningless_asm_qual: Diagnostic = .{
    .fmt = "meaningless '{s}' on assembly outside function",
    .kind = .@"error",
};

pub const duplicate_asm_qual: Diagnostic = .{
    .fmt = "duplicate asm qualifier '{s}'",
    .kind = .@"error",
};

pub const invalid_asm_str: Diagnostic = .{
    .fmt = "cannot use {s} string literal in assembly",
    .kind = .@"error",
};

pub const dollar_in_identifier_extension: Diagnostic = .{
    .fmt = "'$' in identifier",
    .opt = .@"dollar-in-identifier-extension",
    .kind = .off,
    .extension = true,
};

pub const dollars_in_identifiers: Diagnostic = .{
    .fmt = "illegal character '$' in identifier",
    .kind = .@"error",
};

pub const predefined_top_level: Diagnostic = .{
    .fmt = "predefined identifier is only valid inside function",
    .opt = .@"predefined-identifier-outside-function",
    .kind = .warning,
};

pub const incompatible_va_arg: Diagnostic = .{
    .fmt = "first argument to va_arg, is of type {qt} and not 'va_list'",
    .kind = .@"error",
};

pub const too_many_scalar_init_braces: Diagnostic = .{
    .fmt = "too many braces around scalar initializer",
    .opt = .@"many-braces-around-scalar-init",
    .kind = .warning,
    .extension = true,
};

// pub const uninitialized_in_own_init: Diagnostic = .{
//     .fmt = "variable '{s}' is uninitialized when used within its own initialization",
//     .opt = .uninitialized,
//     .kind = .off,
// };

pub const gnu_statement_expression: Diagnostic = .{
    .fmt = "use of GNU statement expression extension",
    .opt = .@"gnu-statement-expression",
    .kind = .off,
    .extension = true,
};

pub const stmt_expr_not_allowed_file_scope: Diagnostic = .{
    .fmt = "statement expression not allowed at file scope",
    .kind = .@"error",
};

pub const gnu_imaginary_constant: Diagnostic = .{
    .fmt = "imaginary constants are a GNU extension",
    .opt = .@"gnu-imaginary-constant",
    .kind = .off,
    .extension = true,
};

pub const plain_complex: Diagnostic = .{
    .fmt = "plain '_Complex' requires a type specifier; assuming '_Complex double'",
    .kind = .warning,
    .extension = true,
};

pub const complex_int: Diagnostic = .{
    .fmt = "complex integer types are a GNU extension",
    .opt = .@"gnu-complex-integer",
    .kind = .off,
    .extension = true,
};

pub const qual_on_ret_type: Diagnostic = .{
    .fmt = "'{s}' type qualifier on return type has no effect",
    .opt = .@"ignored-qualifiers",
    .kind = .off,
};

pub const extra_semi: Diagnostic = .{
    .fmt = "extra ';' outside of a function",
    .opt = .@"extra-semi",
    .kind = .off,
};

pub const func_field: Diagnostic = .{
    .fmt = "field declared as a function",
    .kind = .@"error",
};

pub const expected_member_name: Diagnostic = .{
    .fmt = "expected member name after declarator",
    .kind = .@"error",
};

pub const vla_field: Diagnostic = .{
    .fmt = "variable length array fields extension is not supported",
    .kind = .@"error",
};

pub const field_incomplete_ty: Diagnostic = .{
    .fmt = "field has incomplete type {qt}",
    .kind = .@"error",
};

pub const flexible_in_union: Diagnostic = .{
    .fmt = "flexible array member in union is not allowed",
    .kind = .@"error",
};

pub const flexible_in_union_msvc: Diagnostic = .{
    .fmt = "flexible array member in union is a Microsoft extension",
    .kind = .off,
    .opt = .@"microsoft-flexible-array",
    .extension = true,
};

pub const flexible_non_final: Diagnostic = .{
    .fmt = "flexible array member is not at the end of struct",
    .kind = .@"error",
};

pub const flexible_in_empty: Diagnostic = .{
    .fmt = "flexible array member in otherwise empty struct",
    .kind = .@"error",
};

pub const flexible_in_empty_msvc: Diagnostic = .{
    .fmt = "flexible array member in otherwise empty struct is a Microsoft extension",
    .kind = .off,
    .opt = .@"microsoft-flexible-array",
    .extension = true,
};

pub const anonymous_struct: Diagnostic = .{
    .fmt = "anonymous structs are a Microsoft extension",
    .kind = .warning,
    .opt = .@"microsoft-anon-tag",
    .extension = true,
};

pub const duplicate_member: Diagnostic = .{
    .fmt = "duplicate member '{s}'",
    .kind = .@"error",
};

pub const binary_integer_literal: Diagnostic = .{
    .fmt = "binary integer literals are a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .off,
    .suppress_version = .c23,
    .extension = true,
};

pub const builtin_must_be_called: Diagnostic = .{
    .fmt = "builtin function must be directly called",
    .kind = .@"error",
};

pub const va_start_not_in_func: Diagnostic = .{
    .fmt = "'va_start' cannot be used outside a function",
    .kind = .@"error",
};

pub const va_start_fixed_args: Diagnostic = .{
    .fmt = "'va_start' used in a function with fixed args",
    .kind = .@"error",
};

pub const va_start_not_last_param: Diagnostic = .{
    .fmt = "second argument to 'va_start' is not the last named parameter",
    .opt = .varargs,
    .kind = .warning,
};

pub const attribute_not_enough_args: Diagnostic = .{
    .fmt = "'{s}' attribute takes at least {d} argument(s)",
    .kind = .@"error",
};

pub const attribute_too_many_args: Diagnostic = .{
    .fmt = "'{s}' attribute takes at most {d} argument(s)",
    .kind = .@"error",
};

pub const attribute_arg_invalid: Diagnostic = .{
    .fmt = "attribute argument is invalid, expected {s} but got {s}",
    .kind = .@"error",
};

pub const unknown_attr_enum: Diagnostic = .{
    .fmt = "unknown `{s}` argument. Possible values are: {s}",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const attribute_requires_identifier: Diagnostic = .{
    .fmt = "'{s}' attribute requires an identifier",
    .kind = .@"error",
};

pub const attribute_int_out_of_range: Diagnostic = .{
    .fmt = "attribute value '{value}' out of range",
    .kind = .@"error",
};

pub const declspec_not_enabled: Diagnostic = .{
    .fmt = "'__declspec' attributes are not enabled; use '-fdeclspec' or '-fms-extensions' to enable support for __declspec attributes",
    .kind = .@"error",
};

pub const declspec_attr_not_supported: Diagnostic = .{
    .fmt = "__declspec attribute '{s}' is not supported",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const deprecated_declarations: Diagnostic = .{
    .fmt = "'{s}' is deprecated{s}{s}",
    .opt = .@"deprecated-declarations",
    .kind = .warning,
};

pub const deprecated_note: Diagnostic = .{
    .fmt = "'{s}' has been explicitly marked deprecated here",
    .opt = .@"deprecated-declarations",
    .kind = .note,
};

pub const unavailable: Diagnostic = .{
    .fmt = "'{s}' is unavailable{s}{s}",
    .kind = .@"error",
};

pub const unavailable_note: Diagnostic = .{
    .fmt = "'{s}' has been explicitly marked unavailable here",
    .kind = .note,
};

pub const warning_attribute: Diagnostic = .{
    .fmt = "call to '{s}' declared with attribute warning: {s}",
    .kind = .warning,
    .opt = .@"attribute-warning",
};

pub const error_attribute: Diagnostic = .{
    .fmt = "call to '{s}' declared with attribute error: {s}",
    .kind = .@"error",
};

pub const ignored_record_attr: Diagnostic = .{
    .fmt = "attribute '{s}' is ignored, place it after \"{s}\" to apply attribute to type declaration",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const array_size_non_int: Diagnostic = .{
    .fmt = "size of array has non-integer type {qt}",
    .kind = .@"error",
};

pub const cast_to_smaller_int: Diagnostic = .{
    .fmt = "cast to smaller integer type {qt} from {qt}",
    .kind = .warning,
    .opt = .@"pointer-to-int-cast",
};

pub const gnu_switch_range: Diagnostic = .{
    .fmt = "use of GNU case range extension",
    .opt = .@"gnu-case-range",
    .kind = .off,
    .extension = true,
};

pub const empty_case_range: Diagnostic = .{
    .fmt = "empty case range specified",
    .kind = .warning,
};

pub const vla: Diagnostic = .{
    .fmt = "variable length array used",
    .kind = .off,
    .opt = .vla,
};

pub const int_value_changed: Diagnostic = .{
    .fmt = "implicit conversion from {qt} to {qt} changes {s}value from {value} to {value}",
    .kind = .warning,
    .opt = .@"constant-conversion",
};

pub const sign_conversion: Diagnostic = .{
    .fmt = "implicit conversion changes signedness: {qt} to {qt}",
    .kind = .off,
    .opt = .@"sign-conversion",
};

pub const float_overflow_conversion: Diagnostic = .{
    .fmt = "implicit conversion of non-finite value from {qt} to {qt} is undefined",
    .kind = .off,
    .opt = .@"float-overflow-conversion",
};

pub const float_out_of_range: Diagnostic = .{
    .fmt = "implicit conversion of out of range value from {qt} to {qt} is undefined",
    .kind = .warning,
    .opt = .@"literal-conversion",
};

pub const float_zero_conversion: Diagnostic = .{
    .fmt = "implicit conversion from {qt} to {qt} changes {s}value from {value} to {value}",
    .kind = .off,
    .opt = .@"float-zero-conversion",
};

pub const float_value_changed: Diagnostic = .{
    .fmt = "implicit conversion from {qt} to {qt} changes {s}value from {value} to {value}",
    .kind = .warning,
    .opt = .@"float-conversion",
};

pub const float_to_int: Diagnostic = .{
    .fmt = "implicit conversion turns floating-point number into integer: {qt} to {qt}",
    .kind = .off,
    .opt = .@"literal-conversion",
};

pub const const_decl_folded: Diagnostic = .{
    .fmt = "expression is not an integer constant expression; folding it to a constant is a GNU extension",
    .kind = .off,
    .opt = .@"gnu-folding-constant",
    .extension = true,
};

pub const const_decl_folded_vla: Diagnostic = .{
    .fmt = "variable length array folded to constant array as an extension",
    .kind = .off,
    .opt = .@"gnu-folding-constant",
    .extension = true,
};

pub const redefinition_of_typedef: Diagnostic = .{
    .fmt = "typedef redefinition with different types ({qt} vs {qt})",
    .kind = .@"error",
};

pub const offsetof_ty: Diagnostic = .{
    .fmt = "offsetof requires struct or union type, {qt} invalid",
    .kind = .@"error",
};

pub const offsetof_incomplete: Diagnostic = .{
    .fmt = "offsetof of incomplete type {qt}",
    .kind = .@"error",
};

pub const offsetof_array: Diagnostic = .{
    .fmt = "offsetof requires array type, {qt} invalid",
    .kind = .@"error",
};

pub const cond_expr_type: Diagnostic = .{
    .fmt = "used type {qt} where arithmetic or pointer type is required",
    .kind = .@"error",
};

pub const enumerator_too_small: Diagnostic = .{
    .fmt = "ISO C restricts enumerator values to range of 'int' ({value} is too small)",
    .kind = .off,
    .extension = true,
};

pub const enumerator_too_large: Diagnostic = .{
    .fmt = "ISO C restricts enumerator values to range of 'int' ({value} is too large)",
    .kind = .off,
    .extension = true,
};

pub const enumerator_overflow: Diagnostic = .{
    .fmt = "overflow in enumeration value",
    .kind = .warning,
};

pub const enum_not_representable: Diagnostic = .{
    .fmt = "incremented enumerator value {s} is not representable in the largest integer type",
    .kind = .warning,
    .opt = .@"enum-too-large",
    .extension = true,
};

pub const enum_too_large: Diagnostic = .{
    .fmt = "enumeration values exceed range of largest integer",
    .kind = .warning,
    .opt = .@"enum-too-large",
    .extension = true,
};

pub const enum_fixed: Diagnostic = .{
    .fmt = "enumeration types with a fixed underlying type are a Clang extension",
    .kind = .off,
    .opt = .@"fixed-enum-extension",
    .extension = true,
};

pub const enum_prev_nonfixed: Diagnostic = .{
    .fmt = "enumeration previously declared with nonfixed underlying type",
    .kind = .@"error",
};

pub const enum_prev_fixed: Diagnostic = .{
    .fmt = "enumeration previously declared with fixed underlying type",
    .kind = .@"error",
};

pub const enum_different_explicit_ty: Diagnostic = .{
    .fmt = "enumeration redeclared with different underlying type {qt} (was {qt})",
    .kind = .@"error",
};

pub const enum_not_representable_fixed: Diagnostic = .{
    .fmt = "enumerator value is not representable in the underlying type {qt}",
    .kind = .@"error",
};

pub const transparent_union_wrong_type: Diagnostic = .{
    .fmt = "'transparent_union' attribute only applies to unions",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const transparent_union_one_field: Diagnostic = .{
    .fmt = "transparent union definition must contain at least one field; transparent_union attribute ignored",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const transparent_union_size: Diagnostic = .{
    .fmt = "size of field '{s}' ({d} bits) does not match the size of the first field in transparent union; transparent_union attribute ignored",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const transparent_union_size_note: Diagnostic = .{
    .fmt = "size of first field is {d}",
    .kind = .note,
};

pub const designated_init_invalid: Diagnostic = .{
    .fmt = "'designated_init' attribute is only valid on 'struct' type'",
    .kind = .@"error",
};

pub const designated_init_needed: Diagnostic = .{
    .fmt = "positional initialization of field in 'struct' declared with 'designated_init' attribute",
    .opt = .@"designated-init",
    .kind = .warning,
};

pub const ignore_common: Diagnostic = .{
    .fmt = "ignoring attribute 'common' because it conflicts with attribute 'nocommon'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const ignore_nocommon: Diagnostic = .{
    .fmt = "ignoring attribute 'nocommon' because it conflicts with attribute 'common'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const non_string_ignored: Diagnostic = .{
    .fmt = "'nonstring' attribute ignored on objects of type {qt}",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const local_variable_attribute: Diagnostic = .{
    .fmt = "'{s}' attribute only applies to local variables",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const ignore_cold: Diagnostic = .{
    .fmt = "ignoring attribute 'cold' because it conflicts with attribute 'hot'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const ignore_hot: Diagnostic = .{
    .fmt = "ignoring attribute 'hot' because it conflicts with attribute 'cold'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const ignore_noinline: Diagnostic = .{
    .fmt = "ignoring attribute 'noinline' because it conflicts with attribute 'always_inline'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const ignore_always_inline: Diagnostic = .{
    .fmt = "ignoring attribute 'always_inline' because it conflicts with attribute 'noinline'",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const invalid_noreturn: Diagnostic = .{
    .fmt = "function '{s}' declared 'noreturn' should not return",
    .kind = .warning,
    .opt = .@"invalid-noreturn",
};

pub const nodiscard_unused: Diagnostic = .{
    .fmt = "ignoring return value of '{s}', declared with 'nodiscard' attribute",
    .kind = .warning,
    .opt = .@"unused-result",
};

pub const warn_unused_result: Diagnostic = .{
    .fmt = "ignoring return value of '{s}', declared with 'warn_unused_result' attribute",
    .kind = .warning,
    .opt = .@"unused-result",
};

pub const builtin_unused: Diagnostic = .{
    .fmt = "ignoring return value of function declared with {s} attribute",
    .kind = .warning,
    .opt = .@"unused-value",
};

pub const unused_value: Diagnostic = .{
    .fmt = "expression result unused",
    .kind = .warning,
    .opt = .@"unused-value",
};

pub const invalid_vec_elem_ty: Diagnostic = .{
    .fmt = "invalid vector element type {qt}",
    .kind = .@"error",
};

pub const bit_int_vec_too_small: Diagnostic = .{
    .fmt = "'_BitInt' vector element width must be at least as wide as 'CHAR_BIT'",
    .kind = .@"error",
};

pub const bit_int_vec_not_pow2: Diagnostic = .{
    .fmt = "'_BitInt' vector element width must be a power of 2",
    .kind = .@"error",
};

pub const vec_size_not_multiple: Diagnostic = .{
    .fmt = "vector size not an integral multiple of component size",
    .kind = .@"error",
};

pub const invalid_imag: Diagnostic = .{
    .fmt = "invalid type {qt} to __imag operator",
    .kind = .@"error",
};

pub const invalid_real: Diagnostic = .{
    .fmt = "invalid type {qt} to __real operator",
    .kind = .@"error",
};

pub const zero_length_array: Diagnostic = .{
    .fmt = "zero size arrays are an extension",
    .kind = .off,
    .opt = .@"zero-length-array",
    .extension = true,
};

pub const old_style_flexible_struct: Diagnostic = .{
    .fmt = "array index {value} is past the end of the array",
    .kind = .off,
    .opt = .@"old-style-flexible-struct",
};

pub const main_return_type: Diagnostic = .{
    .fmt = "return type of 'main' is not 'int'",
    .kind = .warning,
    .opt = .@"main-return-type",
    .extension = true,
};

pub const invalid_int_suffix: Diagnostic = .{
    .fmt = "invalid suffix '{s}' on integer constant",
    .kind = .@"error",
};

pub const invalid_float_suffix: Diagnostic = .{
    .fmt = "invalid suffix '{s}' on floating constant",
    .kind = .@"error",
};

pub const invalid_octal_digit: Diagnostic = .{
    .fmt = "invalid digit '{c}' in octal constant",
    .kind = .@"error",
};

pub const invalid_binary_digit: Diagnostic = .{
    .fmt = "invalid digit '{c}' in binary constant",
    .kind = .@"error",
};

pub const exponent_has_no_digits: Diagnostic = .{
    .fmt = "exponent has no digits",
    .kind = .@"error",
};

pub const hex_floating_constant_requires_exponent: Diagnostic = .{
    .fmt = "hexadecimal floating constant requires an exponent",
    .kind = .@"error",
};

pub const sizeof_returns_zero: Diagnostic = .{
    .fmt = "sizeof returns 0",
    .kind = .warning,
};

pub const declspec_not_allowed_after_declarator: Diagnostic = .{
    .fmt = "'declspec' attribute not allowed after declarator",
    .kind = .@"error",
};

pub const declarator_name_tok: Diagnostic = .{
    .fmt = "this declarator",
    .kind = .note,
};

pub const type_not_supported_on_target: Diagnostic = .{
    .fmt = "{s} is not supported on this target",
    .kind = .@"error",
};

pub const bit_int: Diagnostic = .{
    .fmt = "'_BitInt' in C17 and earlier is a Clang extension",
    .kind = .off,
    .opt = .@"bit-int-extension",
    .suppress_version = .c23,
    .extension = true,
};

pub const unsigned_bit_int_too_small: Diagnostic = .{
    .fmt = "{s}unsigned _BitInt must have a bit size of at least 1",
    .kind = .@"error",
};

pub const signed_bit_int_too_small: Diagnostic = .{
    .fmt = "{s}signed _BitInt must have a bit size of at least 2",
    .kind = .@"error",
};

pub const unsigned_bit_int_too_big: Diagnostic = .{
    .fmt = "{s}unsigned _BitInt of bit sizes greater than " ++ std.fmt.comptimePrint("{d}", .{Compilation.bit_int_max_bits}) ++ " not supported",
    .kind = .@"error",
};

pub const signed_bit_int_too_big: Diagnostic = .{
    .fmt = "{s}signed _BitInt of bit sizes greater than " ++ std.fmt.comptimePrint("{d}", .{Compilation.bit_int_max_bits}) ++ " not supported",
    .kind = .@"error",
};

pub const ptr_arithmetic_incomplete: Diagnostic = .{
    .fmt = "arithmetic on a pointer to an incomplete type {qt}",
    .kind = .@"error",
};

pub const callconv_not_supported: Diagnostic = .{
    .fmt = "'{s}' calling convention is not supported for this target",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const callconv_non_func: Diagnostic = .{
    .fmt = "'{s}' only applies to function types; type here is {qt}",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};

pub const pointer_arith_void: Diagnostic = .{
    .fmt = "invalid application of '{s}' to a void type",
    .kind = .off,
    .opt = .@"pointer-arith",
    .extension = true,
};

pub const sizeof_array_arg: Diagnostic = .{
    .fmt = "sizeof on array function parameter will return size of {qt} instead of {qt}",
    .kind = .warning,
    .opt = .@"sizeof-array-argument",
};

pub const array_address_to_bool: Diagnostic = .{
    .fmt = "address of array '{s}' will always evaluate to 'true'",
    .kind = .warning,
    .opt = .@"pointer-bool-conversion",
};

pub const string_literal_to_bool: Diagnostic = .{
    .fmt = "implicit conversion turns string literal into bool: {qt} to {qt}",
    .kind = .off,
    .opt = .@"string-conversion",
};

// pub const constant_expression_conversion_not_allowed: Diagnostic = .{
//     .fmt = "this conversion is not allowed in a constant expression",
//     .kind = .note,
// };

pub const invalid_object_cast: Diagnostic = .{
    .fmt = "cannot cast an object of type {qt} to {qt}",
    .kind = .@"error",
};

pub const suggest_pointer_for_invalid_fp16: Diagnostic = .{
    .fmt = "{s} cannot have __fp16 type; did you forget * ?",
    .kind = .@"error",
};

pub const bitint_suffix: Diagnostic = .{
    .fmt = "'_BitInt' suffix for literals is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .warning,
    .suppress_version = .c23,
    .extension = true,
};

pub const auto_type_extension: Diagnostic = .{
    .fmt = "'__auto_type' is a GNU extension",
    .opt = .@"gnu-auto-type",
    .kind = .off,
    .extension = true,
};

pub const gnu_pointer_arith: Diagnostic = .{
    .fmt = "arithmetic on pointers to void is a GNU extension",
    .opt = .@"gnu-pointer-arith",
    .kind = .off,
    .extension = true,
};

pub const auto_type_not_allowed: Diagnostic = .{
    .fmt = "'__auto_type' not allowed in {s}",
    .kind = .@"error",
};

pub const auto_type_requires_initializer: Diagnostic = .{
    .fmt = "declaration of variable '{s}' with deduced type requires an initializer",
    .kind = .@"error",
};

pub const auto_type_requires_single_declarator: Diagnostic = .{
    .fmt = "'__auto_type' may only be used with a single declarator",
    .kind = .@"error",
};

pub const auto_type_requires_plain_declarator: Diagnostic = .{
    .fmt = "'__auto_type' requires a plain identifier as declarator",
    .kind = .@"error",
};

pub const auto_type_from_bitfield: Diagnostic = .{
    .fmt = "cannot use bit-field as '__auto_type' initializer",
    .kind = .@"error",
};

pub const auto_type_array: Diagnostic = .{
    .fmt = "'{s}' declared as array of '__auto_type'",
    .kind = .@"error",
};

pub const auto_type_with_init_list: Diagnostic = .{
    .fmt = "cannot use '__auto_type' with initializer list",
    .kind = .@"error",
};

pub const missing_semicolon: Diagnostic = .{
    .fmt = "expected ';' at end of declaration list",
    .kind = .warning,
    .extension = true,
};

pub const tentative_definition_incomplete: Diagnostic = .{
    .fmt = "tentative definition has type {qt} that is never completed",
    .kind = .@"error",
};

pub const forward_declaration_here: Diagnostic = .{
    .fmt = "forward declaration of {qt}",
    .kind = .note,
};

pub const gnu_union_cast: Diagnostic = .{
    .fmt = "cast to union type is a GNU extension",
    .opt = .@"gnu-union-cast",
    .kind = .off,
    .extension = true,
};

pub const invalid_union_cast: Diagnostic = .{
    .fmt = "cast to union type from type {qt} not present in union",
    .kind = .@"error",
};

pub const cast_to_incomplete_type: Diagnostic = .{
    .fmt = "cast to incomplete type {qt}",
    .kind = .@"error",
};

pub const gnu_asm_disabled: Diagnostic = .{
    .fmt = "GNU-style inline assembly is disabled",
    .kind = .@"error",
};

pub const extension_token_used: Diagnostic = .{
    .fmt = "extension used",
    .kind = .off,
    .opt = .@"language-extension-token",
    .extension = true,
};

pub const complex_component_init: Diagnostic = .{
    .fmt = "complex initialization specifying real and imaginary components is an extension",
    .opt = .@"complex-component-init",
    .kind = .off,
    .extension = true,
};

pub const complex_prefix_postfix_op: Diagnostic = .{
    .fmt = "ISO C does not support '++'/'--' on complex type {qt}",
    .kind = .off,
    .extension = true,
};

pub const not_floating_type: Diagnostic = .{
    .fmt = "argument type {qt} is not a real floating point type",
    .kind = .@"error",
};

pub const argument_types_differ: Diagnostic = .{
    .fmt = "arguments are of different types ({qt} vs {qt})",
    .kind = .@"error",
};

pub const attribute_requires_string: Diagnostic = .{
    .fmt = "attribute '{s}' requires an ordinary string",
    .kind = .@"error",
};

pub const empty_char_literal_error: Diagnostic = .{
    .fmt = "empty character constant",
    .kind = .@"error",
};

pub const unterminated_char_literal_error: Diagnostic = .{
    .fmt = "missing terminating ' character",
    .kind = .@"error",
};

// pub const def_no_proto_deprecated: Diagnostic = .{
//     .fmt = "a function definition without a prototype is deprecated in all versions of C and is not supported in C23",
//     .kind = .warning,
//     .opt = .@"deprecated-non-prototype",
// };

pub const passing_args_to_kr: Diagnostic = .{
    .fmt = "passing arguments to a function without a prototype is deprecated in all versions of C and is not supported in C23",
    .kind = .warning,
    .opt = .@"deprecated-non-prototype",
};

pub const unknown_type_name: Diagnostic = .{
    .fmt = "unknown type name '{s}'",
    .kind = .@"error",
};

pub const label_compound_end: Diagnostic = .{
    .fmt = "label at end of compound statement is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .warning,
    .suppress_version = .c23,
    .extension = true,
};

pub const u8_char_lit: Diagnostic = .{
    .fmt = "UTF-8 character literal is a C23 extension",
    .opt = .@"c23-extensions",
    .kind = .warning,
    .suppress_version = .c23,
    .extension = true,
};

pub const invalid_compound_literal_storage_class: Diagnostic = .{
    .fmt = "compound literal cannot have {s} storage class",
    .kind = .@"error",
};

pub const identifier_not_normalized: Diagnostic = .{
    .fmt = "'{normalized}' is not in NFC",
    .kind = .warning,
    .opt = .normalized,
};

pub const c23_auto_single_declarator: Diagnostic = .{
    .fmt = "'auto' can only be used with a single declarator",
    .kind = .@"error",
};

pub const c23_auto_requires_initializer: Diagnostic = .{
    .fmt = "'auto' requires an initializer",
    .kind = .@"error",
};

pub const c23_auto_not_allowed: Diagnostic = .{
    .fmt = "'auto' not allowed in {s}",
    .kind = .@"error",
};

pub const c23_auto_with_init_list: Diagnostic = .{
    .fmt = "cannot use 'auto' with array",
    .kind = .@"error",
};

pub const c23_auto_array: Diagnostic = .{
    .fmt = "'{s}' declared as array of 'auto'",
    .kind = .@"error",
};

pub const negative_shift_count: Diagnostic = .{
    .fmt = "shift count is negative",
    .opt = .@"shift-count-negative",
    .kind = .warning,
};

pub const too_big_shift_count: Diagnostic = .{
    .fmt = "shift count >= width of type",
    .opt = .@"shift-count-overflow",
    .kind = .warning,
};

pub const complex_conj: Diagnostic = .{
    .fmt = "ISO C does not support '~' for complex conjugation of {qt}",
    .kind = .off,
    .extension = true,
};

pub const overflow_builtin_requires_int: Diagnostic = .{
    .fmt = "operand argument to overflow builtin must be an integer ({qt} invalid)",
    .kind = .@"error",
};

pub const overflow_result_requires_ptr: Diagnostic = .{
    .fmt = "result argument to overflow builtin must be a pointer to a non-const integer ({qt} invalid)",
    .kind = .@"error",
};

pub const attribute_todo: Diagnostic = .{
    .fmt = "TODO: implement '{s}' attribute for {s}",
    .kind = .warning,
    .opt = .@"attribute-todo",
};

pub const invalid_type_underlying_enum: Diagnostic = .{
    .fmt = "non-integral type {qt} is an invalid underlying type",
    .kind = .@"error",
};

pub const auto_type_self_initialized: Diagnostic = .{
    .fmt = "variable '{s}' declared with deduced type '__auto_type' cannot appear in its own initializer",
    .kind = .@"error",
};

// pub const non_constant_initializer: Diagnostic = .{
//     .fmt = "initializer element is not a compile-time constant",
//     .kind = .@"error",
// };

pub const constexpr_requires_const: Diagnostic = .{
    .fmt = "constexpr variable must be initialized by a constant expression",
    .kind = .@"error",
};

pub const subtract_pointers_zero_elem_size: Diagnostic = .{
    .fmt = "subtraction of pointers to type {qt} of zero size has undefined behavior",
    .kind = .warning,
    .opt = .@"pointer-arith",
};

pub const packed_member_address: Diagnostic = .{
    .fmt = "taking address of packed member '{s}' of class or structure '{s}' may result in an unaligned pointer value",
    .kind = .warning,
    .opt = .@"address-of-packed-member",
};

pub const attribute_param_out_of_bounds: Diagnostic = .{
    .fmt = "'{s}' attribute parameter {d} is out of bounds",
    .kind = .@"error",
};

pub const alloc_align_requires_ptr_return: Diagnostic = .{
    .fmt = "'alloc_align' attribute only applies to return values that are pointers",
    .opt = .@"ignored-attributes",
    .kind = .warning,
};

pub const alloc_align_required_int_param: Diagnostic = .{
    .fmt = "'alloc_align' attribute argument may only refer to a function parameter of integer type",
    .kind = .@"error",
};

pub const gnu_missing_eq_designator: Diagnostic = .{
    .fmt = "use of GNU 'missing =' extension in designator",
    .kind = .warning,
    .opt = .@"gnu-designator",
    .extension = true,
};

pub const empty_if_body: Diagnostic = .{
    .fmt = "if statement has empty body",
    .kind = .warning,
    .opt = .@"empty-body",
};

pub const empty_if_body_note: Diagnostic = .{
    .fmt = "put the semicolon on a separate line to silence this warning",
    .kind = .note,
    .opt = .@"empty-body",
};

pub const nullability_extension: Diagnostic = .{
    .fmt = "type nullability specifier '{s}' is a Clang extension",
    .kind = .off,
    .opt = .@"nullability-extension",
    .extension = true,
};

pub const duplicate_nullability: Diagnostic = .{
    .fmt = "duplicate nullability specifier '{s}'",
    .kind = .warning,
    .opt = .nullability,
};

pub const conflicting_nullability: Diagnostic = .{
    .fmt = "nullaibility specifier '{tok_id}' conflicts with existing specifier '{tok_id}'",
    .kind = .@"error",
};

pub const invalid_nullability: Diagnostic = .{
    .fmt = "nullability specifier cannot be applied to non-pointer type {qt}",
    .kind = .@"error",
};

pub const array_not_assignable: Diagnostic = .{
    .fmt = "array type {qt} is not assignable",
    .kind = .@"error",
};

pub const non_object_not_assignable: Diagnostic = .{
    .fmt = "non-object type {qt} is not assignable",
    .kind = .@"error",
};

pub const const_var_assignment: Diagnostic = .{
    .fmt = "cannot assign to variable '{s}' with const-qualified type {qt}",
    .kind = .@"error",
};

pub const declared_const_here: Diagnostic = .{
    .fmt = "variable '{s}' declared const here",
    .kind = .note,
};

pub const nonnull_not_applicable: Diagnostic = .{
    .fmt = "'nonnull' attribute only applies to functions, methods, and parameters",
    .kind = .warning,
    .opt = .@"ignored-attributes",
};
