const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const Source = @import("Source.zig");
const Compilation = @import("Compilation.zig");
const Attribute = @import("Attribute.zig");
const BuiltinFunction = @import("builtins/BuiltinFunction.zig");
const Header = @import("builtins/Properties.zig").Header;
const Tree = @import("Tree.zig");
const util = @import("util.zig");
const is_windows = @import("builtin").os.tag == .windows;

const Diagnostics = @This();

const PointerSignMessage = " converts between pointers to integer types with different sign";

pub const Message = struct {
    tag: Tag,
    kind: Kind = undefined,
    loc: Source.Location = .{},
    extra: Extra = .{ .none = {} },

    pub const Extra = union {
        str: []const u8,
        tok_id: struct {
            expected: Tree.Token.Id,
            actual: Tree.Token.Id,
        },
        tok_id_expected: Tree.Token.Id,
        arguments: struct {
            expected: u32,
            actual: u32,
        },
        codepoints: struct {
            actual: u21,
            resembles: u21,
        },
        attr_arg_count: struct {
            attribute: Attribute.Tag,
            expected: u32,
        },
        attr_arg_type: struct {
            expected: Attribute.ArgumentType,
            actual: Attribute.ArgumentType,
        },
        attr_enum: struct {
            tag: Attribute.Tag,
        },
        ignored_record_attr: struct {
            tag: Attribute.Tag,
            specifier: enum { @"struct", @"union", @"enum" },
        },
        builtin_with_header: struct {
            builtin: BuiltinFunction.Tag,
            header: Header,
        },
        invalid_escape: struct {
            offset: u32,
            char: u8,
        },
        actual_codepoint: u21,
        ascii: u7,
        unsigned: u64,
        pow_2_as_string: u8,
        signed: i64,
        none: void,
    };
};

pub const Tag = std.meta.DeclEnum(messages);

// u4 to avoid any possible packed struct issues
pub const Kind = enum(u4) { @"fatal error", @"error", note, warning, off, default };

pub const Options = packed struct {
    // do not directly use these, instead add `const NAME = true;`
    all: Kind = .default,
    extra: Kind = .default,
    pedantic: Kind = .default,

    @"unsupported-pragma": Kind = .default,
    @"c99-extensions": Kind = .default,
    @"implicit-int": Kind = .default,
    @"duplicate-decl-specifier": Kind = .default,
    @"missing-declaration": Kind = .default,
    @"extern-initializer": Kind = .default,
    @"implicit-function-declaration": Kind = .default,
    @"unused-value": Kind = .default,
    @"unreachable-code": Kind = .default,
    @"unknown-warning-option": Kind = .default,
    @"gnu-empty-struct": Kind = .default,
    @"gnu-alignof-expression": Kind = .default,
    @"macro-redefined": Kind = .default,
    @"generic-qual-type": Kind = .default,
    multichar: Kind = .default,
    @"pointer-integer-compare": Kind = .default,
    @"compare-distinct-pointer-types": Kind = .default,
    @"literal-conversion": Kind = .default,
    @"cast-qualifiers": Kind = .default,
    @"array-bounds": Kind = .default,
    @"int-conversion": Kind = .default,
    @"pointer-type-mismatch": Kind = .default,
    @"c2x-extensions": Kind = .default,
    @"incompatible-pointer-types": Kind = .default,
    @"excess-initializers": Kind = .default,
    @"division-by-zero": Kind = .default,
    @"initializer-overrides": Kind = .default,
    @"incompatible-pointer-types-discards-qualifiers": Kind = .default,
    @"unknown-attributes": Kind = .default,
    @"ignored-attributes": Kind = .default,
    @"builtin-macro-redefined": Kind = .default,
    @"gnu-label-as-value": Kind = .default,
    @"malformed-warning-check": Kind = .default,
    @"#pragma-messages": Kind = .default,
    @"newline-eof": Kind = .default,
    @"empty-translation-unit": Kind = .default,
    @"implicitly-unsigned-literal": Kind = .default,
    @"c99-compat": Kind = .default,
    @"unicode-zero-width": Kind = .default,
    @"unicode-homoglyph": Kind = .default,
    unicode: Kind = .default,
    @"return-type": Kind = .default,
    @"dollar-in-identifier-extension": Kind = .default,
    @"unknown-pragmas": Kind = .default,
    @"predefined-identifier-outside-function": Kind = .default,
    @"many-braces-around-scalar-init": Kind = .default,
    uninitialized: Kind = .default,
    @"gnu-statement-expression": Kind = .default,
    @"gnu-imaginary-constant": Kind = .default,
    @"gnu-complex-integer": Kind = .default,
    @"ignored-qualifiers": Kind = .default,
    @"integer-overflow": Kind = .default,
    @"extra-semi": Kind = .default,
    @"gnu-binary-literal": Kind = .default,
    @"variadic-macros": Kind = .default,
    varargs: Kind = .default,
    @"#warnings": Kind = .default,
    @"deprecated-declarations": Kind = .default,
    @"backslash-newline-escape": Kind = .default,
    @"pointer-to-int-cast": Kind = .default,
    @"gnu-case-range": Kind = .default,
    @"c++-compat": Kind = .default,
    vla: Kind = .default,
    @"float-overflow-conversion": Kind = .default,
    @"float-zero-conversion": Kind = .default,
    @"float-conversion": Kind = .default,
    @"gnu-folding-constant": Kind = .default,
    undef: Kind = .default,
    @"ignored-pragmas": Kind = .default,
    @"gnu-include-next": Kind = .default,
    @"include-next-outside-header": Kind = .default,
    @"include-next-absolute-path": Kind = .default,
    @"enum-too-large": Kind = .default,
    @"fixed-enum-extension": Kind = .default,
    @"designated-init": Kind = .default,
    @"attribute-warning": Kind = .default,
    @"invalid-noreturn": Kind = .default,
    @"zero-length-array": Kind = .default,
    @"old-style-flexible-struct": Kind = .default,
    @"gnu-zero-variadic-macro-arguments": Kind = .default,
    @"main-return-type": Kind = .default,
    @"expansion-to-defined": Kind = .default,
    @"bit-int-extension": Kind = .default,
    @"keyword-macro": Kind = .default,
    @"pointer-arith": Kind = .default,
    @"sizeof-array-argument": Kind = .default,
    @"pre-c2x-compat": Kind = .default,
    @"pointer-bool-conversion": Kind = .default,
    @"string-conversion": Kind = .default,
    @"gnu-auto-type": Kind = .default,
    @"gnu-union-cast": Kind = .default,
    @"pointer-sign": Kind = .default,
    @"fuse-ld-path": Kind = .default,
    @"language-extension-token": Kind = .default,
    @"complex-component-init": Kind = .default,
    @"microsoft-include": Kind = .default,
    @"microsoft-end-of-file": Kind = .default,
    @"invalid-source-encoding": Kind = .default,
    @"four-char-constants": Kind = .default,
    @"unknown-escape-sequence": Kind = .default,
};

const messages = struct {
    pub const todo = struct { // Maybe someday this will no longer be needed.
        const msg = "TODO: {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const error_directive = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const warning_directive = struct {
        const msg = "{s}";
        const opt = "#warnings";
        const extra = .str;
        const kind = .warning;
    };
    pub const elif_without_if = struct {
        const msg = "#elif without #if";
        const kind = .@"error";
    };
    pub const elif_after_else = struct {
        const msg = "#elif after #else";
        const kind = .@"error";
    };
    pub const elifdef_without_if = struct {
        const msg = "#elifdef without #if";
        const kind = .@"error";
    };
    pub const elifdef_after_else = struct {
        const msg = "#elifdef after #else";
        const kind = .@"error";
    };
    pub const elifndef_without_if = struct {
        const msg = "#elifndef without #if";
        const kind = .@"error";
    };
    pub const elifndef_after_else = struct {
        const msg = "#elifndef after #else";
        const kind = .@"error";
    };
    pub const else_without_if = struct {
        const msg = "#else without #if";
        const kind = .@"error";
    };
    pub const else_after_else = struct {
        const msg = "#else after #else";
        const kind = .@"error";
    };
    pub const endif_without_if = struct {
        const msg = "#endif without #if";
        const kind = .@"error";
    };
    pub const unknown_pragma = struct {
        const msg = "unknown pragma ignored";
        const opt = "unknown-pragmas";
        const kind = .off;
        const all = true;
    };
    pub const line_simple_digit = struct {
        const msg = "#line directive requires a simple digit sequence";
        const kind = .@"error";
    };
    pub const line_invalid_filename = struct {
        const msg = "invalid filename for #line directive";
        const kind = .@"error";
    };
    pub const unterminated_conditional_directive = struct {
        const msg = "unterminated conditional directive";
        const kind = .@"error";
    };
    pub const invalid_preprocessing_directive = struct {
        const msg = "invalid preprocessing directive";
        const kind = .@"error";
    };
    pub const macro_name_missing = struct {
        const msg = "macro name missing";
        const kind = .@"error";
    };
    pub const extra_tokens_directive_end = struct {
        const msg = "extra tokens at end of macro directive";
        const kind = .@"error";
    };
    pub const expected_value_in_expr = struct {
        const msg = "expected value in expression";
        const kind = .@"error";
    };
    pub const closing_paren = struct {
        const msg = "expected closing ')'";
        const kind = .@"error";
    };
    pub const to_match_paren = struct {
        const msg = "to match this '('";
        const kind = .note;
    };
    pub const to_match_brace = struct {
        const msg = "to match this '{'";
        const kind = .note;
    };
    pub const to_match_bracket = struct {
        const msg = "to match this '['";
        const kind = .note;
    };
    pub const header_str_closing = struct {
        const msg = "expected closing '>'";
        const kind = .@"error";
    };
    pub const header_str_match = struct {
        const msg = "to match this '<'";
        const kind = .note;
    };
    pub const string_literal_in_pp_expr = struct {
        const msg = "string literal in preprocessor expression";
        const kind = .@"error";
    };
    pub const float_literal_in_pp_expr = struct {
        const msg = "floating point literal in preprocessor expression";
        const kind = .@"error";
    };
    pub const defined_as_macro_name = struct {
        const msg = "'defined' cannot be used as a macro name";
        const kind = .@"error";
    };
    pub const macro_name_must_be_identifier = struct {
        const msg = "macro name must be an identifier";
        const kind = .@"error";
    };
    pub const whitespace_after_macro_name = struct {
        const msg = "ISO C99 requires whitespace after the macro name";
        const opt = "c99-extensions";
        const kind = .warning;
    };
    pub const hash_hash_at_start = struct {
        const msg = "'##' cannot appear at the start of a macro expansion";
        const kind = .@"error";
    };
    pub const hash_hash_at_end = struct {
        const msg = "'##' cannot appear at the end of a macro expansion";
        const kind = .@"error";
    };
    pub const pasting_formed_invalid = struct {
        const msg = "pasting formed '{s}', an invalid preprocessing token";
        const extra = .str;
        const kind = .@"error";
    };
    pub const missing_paren_param_list = struct {
        const msg = "missing ')' in macro parameter list";
        const kind = .@"error";
    };
    pub const unterminated_macro_param_list = struct {
        const msg = "unterminated macro param list";
        const kind = .@"error";
    };
    pub const invalid_token_param_list = struct {
        const msg = "invalid token in macro parameter list";
        const kind = .@"error";
    };
    pub const expected_comma_param_list = struct {
        const msg = "expected comma in macro parameter list";
        const kind = .@"error";
    };
    pub const hash_not_followed_param = struct {
        const msg = "'#' is not followed by a macro parameter";
        const kind = .@"error";
    };
    pub const expected_filename = struct {
        const msg = "expected \"FILENAME\" or <FILENAME>";
        const kind = .@"error";
    };
    pub const empty_filename = struct {
        const msg = "empty filename";
        const kind = .@"error";
    };
    pub const expected_invalid = struct {
        const msg = "expected '{s}', found invalid bytes";
        const extra = .tok_id_expected;
        const kind = .@"error";
    };
    pub const expected_eof = struct {
        const msg = "expected '{s}' before end of file";
        const extra = .tok_id_expected;
        const kind = .@"error";
    };
    pub const expected_token = struct {
        const msg = "expected '{s}', found '{s}'";
        const extra = .tok_id;
        const kind = .@"error";
    };
    pub const expected_expr = struct {
        const msg = "expected expression";
        const kind = .@"error";
    };
    pub const expected_integer_constant_expr = struct {
        const msg = "expression is not an integer constant expression";
        const kind = .@"error";
    };
    pub const missing_type_specifier = struct {
        const msg = "type specifier missing, defaults to 'int'";
        const opt = "implicit-int";
        const kind = .warning;
        const all = true;
    };
    pub const missing_type_specifier_c2x = struct {
        const msg = "a type specifier is required for all declarations";
        const kind = .@"error";
    };
    pub const multiple_storage_class = struct {
        const msg = "cannot combine with previous '{s}' declaration specifier";
        const extra = .str;
        const kind = .@"error";
    };
    pub const static_assert_failure = struct {
        const msg = "static assertion failed";
        const kind = .@"error";
    };
    pub const static_assert_failure_message = struct {
        const msg = "static assertion failed {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const expected_type = struct {
        const msg = "expected a type";
        const kind = .@"error";
    };
    pub const cannot_combine_spec = struct {
        const msg = "cannot combine with previous '{s}' specifier";
        const extra = .str;
        const kind = .@"error";
    };
    pub const duplicate_decl_spec = struct {
        const msg = "duplicate '{s}' declaration specifier";
        const extra = .str;
        const opt = "duplicate-decl-specifier";
        const kind = .warning;
        const all = true;
    };
    pub const restrict_non_pointer = struct {
        const msg = "restrict requires a pointer or reference ('{s}' is invalid)";
        const extra = .str;
        const kind = .@"error";
    };
    pub const expected_external_decl = struct {
        const msg = "expected external declaration";
        const kind = .@"error";
    };
    pub const expected_ident_or_l_paren = struct {
        const msg = "expected identifier or '('";
        const kind = .@"error";
    };
    pub const missing_declaration = struct {
        const msg = "declaration does not declare anything";
        const opt = "missing-declaration";
        const kind = .warning;
    };
    pub const func_not_in_root = struct {
        const msg = "function definition is not allowed here";
        const kind = .@"error";
    };
    pub const illegal_initializer = struct {
        const msg = "illegal initializer (only variables can be initialized)";
        const kind = .@"error";
    };
    pub const extern_initializer = struct {
        const msg = "extern variable has initializer";
        const opt = "extern-initializer";
        const kind = .warning;
    };
    pub const spec_from_typedef = struct {
        const msg = "'{s}' came from typedef";
        const extra = .str;
        const kind = .note;
    };
    pub const param_before_var_args = struct {
        const msg = "ISO C requires a named parameter before '...'";
        const kind = .@"error";
    };
    pub const void_only_param = struct {
        const msg = "'void' must be the only parameter if specified";
        const kind = .@"error";
    };
    pub const void_param_qualified = struct {
        const msg = "'void' parameter cannot be qualified";
        const kind = .@"error";
    };
    pub const void_must_be_first_param = struct {
        const msg = "'void' must be the first parameter if specified";
        const kind = .@"error";
    };
    pub const invalid_storage_on_param = struct {
        const msg = "invalid storage class on function parameter";
        const kind = .@"error";
    };
    pub const threadlocal_non_var = struct {
        const msg = "_Thread_local only allowed on variables";
        const kind = .@"error";
    };
    pub const func_spec_non_func = struct {
        const msg = "'{s}' can only appear on functions";
        const extra = .str;
        const kind = .@"error";
    };
    pub const illegal_storage_on_func = struct {
        const msg = "illegal storage class on function";
        const kind = .@"error";
    };
    pub const illegal_storage_on_global = struct {
        const msg = "illegal storage class on global variable";
        const kind = .@"error";
    };
    pub const expected_stmt = struct {
        const msg = "expected statement";
        const kind = .@"error";
    };
    pub const func_cannot_return_func = struct {
        const msg = "function cannot return a function";
        const kind = .@"error";
    };
    pub const func_cannot_return_array = struct {
        const msg = "function cannot return an array";
        const kind = .@"error";
    };
    pub const undeclared_identifier = struct {
        const msg = "use of undeclared identifier '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const not_callable = struct {
        const msg = "cannot call non function type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const unsupported_str_cat = struct {
        const msg = "unsupported string literal concatenation";
        const kind = .@"error";
    };
    pub const static_func_not_global = struct {
        const msg = "static functions must be global";
        const kind = .@"error";
    };
    pub const implicit_func_decl = struct {
        const msg = "implicit declaration of function '{s}' is invalid in C99";
        const extra = .str;
        const opt = "implicit-function-declaration";
        const kind = .warning;
        const all = true;
    };
    pub const unknown_builtin = struct {
        const msg = "use of unknown builtin '{s}'";
        const extra = .str;
        const opt = "implicit-function-declaration";
        const kind = .@"error";
        const all = true;
    };
    pub const implicit_builtin = struct {
        const msg = "implicitly declaring library function '{s}'";
        const extra = .str;
        const opt = "implicit-function-declaration";
        const kind = .@"error";
        const all = true;
    };
    pub const implicit_builtin_header_note = struct {
        const msg = "include the header <{s}.h> or explicitly provide a declaration for '{s}'";
        const extra = .builtin_with_header;
        const opt = "implicit-function-declaration";
        const kind = .note;
        const all = true;
    };
    pub const expected_param_decl = struct {
        const msg = "expected parameter declaration";
        const kind = .@"error";
    };
    pub const invalid_old_style_params = struct {
        const msg = "identifier parameter lists are only allowed in function definitions";
        const kind = .@"error";
    };
    pub const expected_fn_body = struct {
        const msg = "expected function body after function declaration";
        const kind = .@"error";
    };
    pub const invalid_void_param = struct {
        const msg = "parameter cannot have void type";
        const kind = .@"error";
    };
    pub const unused_value = struct {
        const msg = "expression result unused";
        const opt = "unused-value";
        const kind = .warning;
        const all = true;
    };
    pub const continue_not_in_loop = struct {
        const msg = "'continue' statement not in a loop";
        const kind = .@"error";
    };
    pub const break_not_in_loop_or_switch = struct {
        const msg = "'break' statement not in a loop or a switch";
        const kind = .@"error";
    };
    pub const unreachable_code = struct {
        const msg = "unreachable code";
        const opt = "unreachable-code";
        const kind = .warning;
        const all = true;
    };
    pub const duplicate_label = struct {
        const msg = "duplicate label '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const previous_label = struct {
        const msg = "previous definition of label '{s}' was here";
        const extra = .str;
        const kind = .note;
    };
    pub const undeclared_label = struct {
        const msg = "use of undeclared label '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const case_not_in_switch = struct {
        const msg = "'{s}' statement not in a switch statement";
        const extra = .str;
        const kind = .@"error";
    };
    pub const duplicate_switch_case_signed = struct {
        const msg = "duplicate case value '{d}'";
        const extra = .signed;
        const kind = .@"error";
    };
    pub const duplicate_switch_case_unsigned = struct {
        const msg = "duplicate case value '{d}'";
        const extra = .unsigned;
        const kind = .@"error";
    };
    pub const multiple_default = struct {
        const msg = "multiple default cases in the same switch";
        const kind = .@"error";
    };
    pub const previous_case = struct {
        const msg = "previous case defined here";
        const kind = .note;
    };
    pub const expected_arguments = struct {
        const msg = "expected {d} argument(s) got {d}";
        const extra = .arguments;
        const kind = .@"error";
    };
    pub const expected_arguments_old = struct {
        const msg = expected_arguments.msg;
        const extra = .arguments;
        const kind = .warning;
    };
    pub const expected_at_least_arguments = struct {
        const msg = "expected at least {d} argument(s) got {d}";
        const extra = .arguments;
        const kind = .warning;
    };
    pub const invalid_static_star = struct {
        const msg = "'static' may not be used with an unspecified variable length array size";
        const kind = .@"error";
    };
    pub const static_non_param = struct {
        const msg = "'static' used outside of function parameters";
        const kind = .@"error";
    };
    pub const array_qualifiers = struct {
        const msg = "type qualifier in non parameter array type";
        const kind = .@"error";
    };
    pub const star_non_param = struct {
        const msg = "star modifier used outside of function parameters";
        const kind = .@"error";
    };
    pub const variable_len_array_file_scope = struct {
        const msg = "variable length arrays not allowed at file scope";
        const kind = .@"error";
    };
    pub const useless_static = struct {
        const msg = "'static' useless without a constant size";
        const kind = .warning;
        const w_extra = true;
    };
    pub const negative_array_size = struct {
        const msg = "array size must be 0 or greater";
        const kind = .@"error";
    };
    pub const array_incomplete_elem = struct {
        const msg = "array has incomplete element type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const array_func_elem = struct {
        const msg = "arrays cannot have functions as their element type";
        const kind = .@"error";
    };
    pub const static_non_outermost_array = struct {
        const msg = "'static' used in non-outermost array type";
        const kind = .@"error";
    };
    pub const qualifier_non_outermost_array = struct {
        const msg = "type qualifier used in non-outermost array type";
        const kind = .@"error";
    };
    pub const unterminated_macro_arg_list = struct {
        const msg = "unterminated function macro argument list";
        const kind = .@"error";
    };
    pub const unknown_warning = struct {
        const msg = "unknown warning '{s}'";
        const extra = .str;
        const opt = "unknown-warning-option";
        const kind = .warning;
    };
    pub const overflow_signed = struct {
        const msg = "overflow in expression; result is '{d}'";
        const extra = .signed;
        const opt = "integer-overflow";
        const kind = .warning;
    };
    pub const overflow_unsigned = struct {
        const msg = overflow_signed.msg;
        const extra = .unsigned;
        const opt = "integer-overflow";
        const kind = .warning;
    };
    pub const int_literal_too_big = struct {
        const msg = "integer literal is too large to be represented in any integer type";
        const kind = .@"error";
    };
    pub const indirection_ptr = struct {
        const msg = "indirection requires pointer operand";
        const kind = .@"error";
    };
    pub const addr_of_rvalue = struct {
        const msg = "cannot take the address of an rvalue";
        const kind = .@"error";
    };
    pub const addr_of_bitfield = struct {
        const msg = "address of bit-field requested";
        const kind = .@"error";
    };
    pub const not_assignable = struct {
        const msg = "expression is not assignable";
        const kind = .@"error";
    };
    pub const ident_or_l_brace = struct {
        const msg = "expected identifier or '{'";
        const kind = .@"error";
    };
    pub const empty_enum = struct {
        const msg = "empty enum is invalid";
        const kind = .@"error";
    };
    pub const redefinition = struct {
        const msg = "redefinition of '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const previous_definition = struct {
        const msg = "previous definition is here";
        const kind = .note;
    };
    pub const expected_identifier = struct {
        const msg = "expected identifier";
        const kind = .@"error";
    };
    pub const expected_str_literal = struct {
        const msg = "expected string literal for diagnostic message in static_assert";
        const kind = .@"error";
    };
    pub const expected_str_literal_in = struct {
        const msg = "expected string literal in '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const parameter_missing = struct {
        const msg = "parameter named '{s}' is missing";
        const extra = .str;
        const kind = .@"error";
    };
    pub const empty_record = struct {
        const msg = "empty {s} is a GNU extension";
        const extra = .str;
        const opt = "gnu-empty-struct";
        const kind = .off;
        const pedantic = true;
    };
    pub const empty_record_size = struct {
        const msg = "empty {s} has size 0 in C, size 1 in C++";
        const extra = .str;
        const opt = "c++-compat";
        const kind = .off;
    };
    pub const wrong_tag = struct {
        const msg = "use of '{s}' with tag type that does not match previous definition";
        const extra = .str;
        const kind = .@"error";
    };
    pub const expected_parens_around_typename = struct {
        const msg = "expected parentheses around type name";
        const kind = .@"error";
    };
    pub const alignof_expr = struct {
        const msg = "'_Alignof' applied to an expression is a GNU extension";
        const opt = "gnu-alignof-expression";
        const kind = .warning;
        const suppress_gnu = true;
    };
    pub const invalid_alignof = struct {
        const msg = "invalid application of 'alignof' to an incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_sizeof = struct {
        const msg = "invalid application of 'sizeof' to an incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const macro_redefined = struct {
        const msg = "'{s}' macro redefined";
        const extra = .str;
        const opt = "macro-redefined";
        const kind = .warning;
    };
    pub const generic_qual_type = struct {
        const msg = "generic association with qualifiers cannot be matched with";
        const opt = "generic-qual-type";
        const kind = .warning;
    };
    pub const generic_array_type = struct {
        const msg = "generic association array type cannot be matched with";
        const opt = "generic-qual-type";
        const kind = .warning;
    };
    pub const generic_func_type = struct {
        const msg = "generic association function type cannot be matched with";
        const opt = "generic-qual-type";
        const kind = .warning;
    };
    pub const generic_duplicate = struct {
        const msg = "type '{s}' in generic association compatible with previously specified type";
        const extra = .str;
        const kind = .@"error";
    };
    pub const generic_duplicate_here = struct {
        const msg = "compatible type '{s}' specified here";
        const extra = .str;
        const kind = .note;
    };
    pub const generic_duplicate_default = struct {
        const msg = "duplicate default generic association";
        const kind = .@"error";
    };
    pub const generic_no_match = struct {
        const msg = "controlling expression type '{s}' not compatible with any generic association type";
        const extra = .str;
        const kind = .@"error";
    };
    pub const escape_sequence_overflow = struct {
        const msg = "escape sequence out of range";
        const kind = .@"error";
    };
    pub const invalid_universal_character = struct {
        const msg = "invalid universal character";
        const kind = .@"error";
    };
    pub const incomplete_universal_character = struct {
        const msg = "incomplete universal character name";
        const kind = .@"error";
    };
    pub const multichar_literal_warning = struct {
        const msg = "multi-character character constant";
        const opt = "multichar";
        const kind = .warning;
        const all = true;
    };
    pub const invalid_multichar_literal = struct {
        const msg = "{s} character literals may not contain multiple characters";
        const kind = .@"error";
        const extra = .str;
    };
    pub const wide_multichar_literal = struct {
        const msg = "extraneous characters in character constant ignored";
        const kind = .warning;
    };
    pub const char_lit_too_wide = struct {
        const msg = "character constant too long for its type";
        const kind = .warning;
        const all = true;
    };
    pub const char_too_large = struct {
        const msg = "character too large for enclosing character literal type";
        const kind = .@"error";
    };
    pub const must_use_struct = struct {
        const msg = "must use 'struct' tag to refer to type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const must_use_union = struct {
        const msg = "must use 'union' tag to refer to type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const must_use_enum = struct {
        const msg = "must use 'enum' tag to refer to type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const redefinition_different_sym = struct {
        const msg = "redefinition of '{s}' as different kind of symbol";
        const extra = .str;
        const kind = .@"error";
    };
    pub const redefinition_incompatible = struct {
        const msg = "redefinition of '{s}' with a different type";
        const extra = .str;
        const kind = .@"error";
    };
    pub const redefinition_of_parameter = struct {
        const msg = "redefinition of parameter '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_bin_types = struct {
        const msg = "invalid operands to binary expression ({s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const comparison_ptr_int = struct {
        const msg = "comparison between pointer and integer ({s})";
        const extra = .str;
        const opt = "pointer-integer-compare";
        const kind = .warning;
    };
    pub const comparison_distinct_ptr = struct {
        const msg = "comparison of distinct pointer types ({s})";
        const extra = .str;
        const opt = "compare-distinct-pointer-types";
        const kind = .warning;
    };
    pub const incompatible_pointers = struct {
        const msg = "incompatible pointer types ({s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_argument_un = struct {
        const msg = "invalid argument type '{s}' to unary expression";
        const extra = .str;
        const kind = .@"error";
    };
    pub const incompatible_assign = struct {
        const msg = "assignment to {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const implicit_ptr_to_int = struct {
        const msg = "implicit pointer to integer conversion from {s}";
        const extra = .str;
        const opt = "int-conversion";
        const kind = .warning;
    };
    pub const invalid_cast_to_float = struct {
        const msg = "pointer cannot be cast to type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_cast_to_pointer = struct {
        const msg = "operand of type '{s}' cannot be cast to a pointer type";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_cast_type = struct {
        const msg = "cannot cast to non arithmetic or pointer type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const qual_cast = struct {
        const msg = "cast to type '{s}' will not preserve qualifiers";
        const extra = .str;
        const opt = "cast-qualifiers";
        const kind = .warning;
    };
    pub const invalid_index = struct {
        const msg = "array subscript is not an integer";
        const kind = .@"error";
    };
    pub const invalid_subscript = struct {
        const msg = "subscripted value is not an array or pointer";
        const kind = .@"error";
    };
    pub const array_after = struct {
        const msg = "array index {d} is past the end of the array";
        const extra = .unsigned;
        const opt = "array-bounds";
        const kind = .warning;
    };
    pub const array_before = struct {
        const msg = "array index {d} is before the beginning of the array";
        const extra = .signed;
        const opt = "array-bounds";
        const kind = .warning;
    };
    pub const statement_int = struct {
        const msg = "statement requires expression with integer type ('{s}' invalid)";
        const extra = .str;
        const kind = .@"error";
    };
    pub const statement_scalar = struct {
        const msg = "statement requires expression with scalar type ('{s}' invalid)";
        const extra = .str;
        const kind = .@"error";
    };
    pub const func_should_return = struct {
        const msg = "non-void function '{s}' should return a value";
        const extra = .str;
        const opt = "return-type";
        const kind = .@"error";
        const all = true;
    };
    pub const incompatible_return = struct {
        const msg = "returning {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const incompatible_return_sign = struct {
        const msg = "returning {s}" ++ PointerSignMessage;
        const extra = .str;
        const kind = .warning;
        const opt = "pointer-sign";
    };
    pub const implicit_int_to_ptr = struct {
        const msg = "implicit integer to pointer conversion from {s}";
        const extra = .str;
        const opt = "int-conversion";
        const kind = .warning;
    };
    pub const func_does_not_return = struct {
        const msg = "non-void function '{s}' does not return a value";
        const extra = .str;
        const opt = "return-type";
        const kind = .warning;
        const all = true;
    };
    pub const void_func_returns_value = struct {
        const msg = "void function '{s}' should not return a value";
        const extra = .str;
        const opt = "return-type";
        const kind = .@"error";
        const all = true;
    };
    pub const incompatible_arg = struct {
        const msg = "passing {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const incompatible_ptr_arg = struct {
        const msg = "passing {s}";
        const extra = .str;
        const kind = .warning;
        const opt = "incompatible-pointer-types";
    };
    pub const incompatible_ptr_arg_sign = struct {
        const msg = "passing {s}" ++ PointerSignMessage;
        const extra = .str;
        const kind = .warning;
        const opt = "pointer-sign";
    };
    pub const parameter_here = struct {
        const msg = "passing argument to parameter here";
        const kind = .note;
    };
    pub const atomic_array = struct {
        const msg = "atomic cannot be applied to array type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const atomic_func = struct {
        const msg = "atomic cannot be applied to function type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const atomic_incomplete = struct {
        const msg = "atomic cannot be applied to incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const addr_of_register = struct {
        const msg = "address of register variable requested";
        const kind = .@"error";
    };
    pub const variable_incomplete_ty = struct {
        const msg = "variable has incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const parameter_incomplete_ty = struct {
        const msg = "parameter has incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const tentative_array = struct {
        const msg = "tentative array definition assumed to have one element";
        const kind = .warning;
    };
    pub const deref_incomplete_ty_ptr = struct {
        const msg = "dereferencing pointer to incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const alignas_on_func = struct {
        const msg = "'_Alignas' attribute only applies to variables and fields";
        const kind = .@"error";
    };
    pub const alignas_on_param = struct {
        const msg = "'_Alignas' attribute cannot be applied to a function parameter";
        const kind = .@"error";
    };
    pub const minimum_alignment = struct {
        const msg = "requested alignment is less than minimum alignment of {d}";
        const extra = .unsigned;
        const kind = .@"error";
    };
    pub const maximum_alignment = struct {
        const msg = "requested alignment of {d} is too large";
        const extra = .unsigned;
        const kind = .@"error";
    };
    pub const negative_alignment = struct {
        const msg = "requested negative alignment of {d} is invalid";
        const extra = .signed;
        const kind = .@"error";
    };
    pub const align_ignored = struct {
        const msg = "'_Alignas' attribute is ignored here";
        const kind = .warning;
    };
    pub const zero_align_ignored = struct {
        const msg = "requested alignment of zero is ignored";
        const kind = .warning;
    };
    pub const non_pow2_align = struct {
        const msg = "requested alignment is not a power of 2";
        const kind = .@"error";
    };
    pub const pointer_mismatch = struct {
        const msg = "pointer type mismatch ({s})";
        const extra = .str;
        const opt = "pointer-type-mismatch";
        const kind = .warning;
    };
    pub const static_assert_not_constant = struct {
        const msg = "static_assert expression is not an integral constant expression";
        const kind = .@"error";
    };
    pub const static_assert_missing_message = struct {
        const msg = "static_assert with no message is a C2X extension";
        const opt = "c2x-extensions";
        const kind = .warning;
        const suppress_version = .c2x;
    };
    pub const pre_c2x_compat = struct {
        const msg = "{s} is incompatible with C standards before C2x";
        const extra = .str;
        const kind = .off;
        const suppress_unless_version = .c2x;
        const opt = "pre-c2x-compat";
    };
    pub const unbound_vla = struct {
        const msg = "variable length array must be bound in function definition";
        const kind = .@"error";
    };
    pub const array_too_large = struct {
        const msg = "array is too large";
        const kind = .@"error";
    };
    pub const incompatible_ptr_init = struct {
        const msg = "incompatible pointer types initializing {s}";
        const extra = .str;
        const opt = "incompatible-pointer-types";
        const kind = .warning;
    };
    pub const incompatible_ptr_init_sign = struct {
        const msg = "incompatible pointer types initializing {s}" ++ PointerSignMessage;
        const extra = .str;
        const opt = "pointer-sign";
        const kind = .warning;
    };
    pub const incompatible_ptr_assign = struct {
        const msg = "incompatible pointer types assigning to {s}";
        const extra = .str;
        const opt = "incompatible-pointer-types";
        const kind = .warning;
    };
    pub const incompatible_ptr_assign_sign = struct {
        const msg = "incompatible pointer types assigning to {s} " ++ PointerSignMessage;
        const extra = .str;
        const opt = "pointer-sign";
        const kind = .warning;
    };
    pub const vla_init = struct {
        const msg = "variable-sized object may not be initialized";
        const kind = .@"error";
    };
    pub const func_init = struct {
        const msg = "illegal initializer type";
        const kind = .@"error";
    };
    pub const incompatible_init = struct {
        const msg = "initializing {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const empty_scalar_init = struct {
        const msg = "scalar initializer cannot be empty";
        const kind = .@"error";
    };
    pub const excess_scalar_init = struct {
        const msg = "excess elements in scalar initializer";
        const opt = "excess-initializers";
        const kind = .warning;
    };
    pub const excess_str_init = struct {
        const msg = "excess elements in string initializer";
        const opt = "excess-initializers";
        const kind = .warning;
    };
    pub const excess_struct_init = struct {
        const msg = "excess elements in struct initializer";
        const opt = "excess-initializers";
        const kind = .warning;
    };
    pub const excess_array_init = struct {
        const msg = "excess elements in array initializer";
        const opt = "excess-initializers";
        const kind = .warning;
    };
    pub const str_init_too_long = struct {
        const msg = "initializer-string for char array is too long";
        const opt = "excess-initializers";
        const kind = .warning;
    };
    pub const arr_init_too_long = struct {
        const msg = "cannot initialize type ({s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_typeof = struct {
        const msg = "'{s} typeof' is invalid";
        const extra = .str;
        const kind = .@"error";
    };
    pub const division_by_zero = struct {
        const msg = "{s} by zero is undefined";
        const extra = .str;
        const opt = "division-by-zero";
        const kind = .warning;
    };
    pub const division_by_zero_macro = struct {
        const msg = "{s} by zero in preprocessor expression";
        const extra = .str;
        const kind = .@"error";
    };
    pub const builtin_choose_cond = struct {
        const msg = "'__builtin_choose_expr' requires a constant expression";
        const kind = .@"error";
    };
    pub const alignas_unavailable = struct {
        const msg = "'_Alignas' attribute requires integer constant expression";
        const kind = .@"error";
    };
    pub const case_val_unavailable = struct {
        const msg = "case value must be an integer constant expression";
        const kind = .@"error";
    };
    pub const enum_val_unavailable = struct {
        const msg = "enum value must be an integer constant expression";
        const kind = .@"error";
    };
    pub const incompatible_array_init = struct {
        const msg = "cannot initialize array of type {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const array_init_str = struct {
        const msg = "array initializer must be an initializer list or wide string literal";
        const kind = .@"error";
    };
    pub const initializer_overrides = struct {
        const msg = "initializer overrides previous initialization";
        const opt = "initializer-overrides";
        const kind = .warning;
        const w_extra = true;
    };
    pub const previous_initializer = struct {
        const msg = "previous initialization";
        const kind = .note;
    };
    pub const invalid_array_designator = struct {
        const msg = "array designator used for non-array type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const negative_array_designator = struct {
        const msg = "array designator value {d} is negative";
        const extra = .signed;
        const kind = .@"error";
    };
    pub const oob_array_designator = struct {
        const msg = "array designator index {d} exceeds array bounds";
        const extra = .unsigned;
        const kind = .@"error";
    };
    pub const invalid_field_designator = struct {
        const msg = "field designator used for non-record type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const no_such_field_designator = struct {
        const msg = "record type has no field named '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const empty_aggregate_init_braces = struct {
        const msg = "initializer for aggregate with no elements requires explicit braces";
        const kind = .@"error";
    };
    pub const ptr_init_discards_quals = struct {
        const msg = "initializing {s} discards qualifiers";
        const extra = .str;
        const opt = "incompatible-pointer-types-discards-qualifiers";
        const kind = .warning;
    };
    pub const ptr_assign_discards_quals = struct {
        const msg = "assigning to {s} discards qualifiers";
        const extra = .str;
        const opt = "incompatible-pointer-types-discards-qualifiers";
        const kind = .warning;
    };
    pub const ptr_ret_discards_quals = struct {
        const msg = "returning {s} discards qualifiers";
        const extra = .str;
        const opt = "incompatible-pointer-types-discards-qualifiers";
        const kind = .warning;
    };
    pub const ptr_arg_discards_quals = struct {
        const msg = "passing {s} discards qualifiers";
        const extra = .str;
        const opt = "incompatible-pointer-types-discards-qualifiers";
        const kind = .warning;
    };
    pub const unknown_attribute = struct {
        const msg = "unknown attribute '{s}' ignored";
        const extra = .str;
        const opt = "unknown-attributes";
        const kind = .warning;
    };
    pub const ignored_attribute = struct {
        const msg = "{s}";
        const extra = .str;
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const invalid_fallthrough = struct {
        const msg = "fallthrough annotation does not directly precede switch label";
        const kind = .@"error";
    };
    pub const cannot_apply_attribute_to_statement = struct {
        const msg = "'{s}' attribute cannot be applied to a statement";
        const extra = .str;
        const kind = .@"error";
    };
    pub const builtin_macro_redefined = struct {
        const msg = "redefining builtin macro";
        const opt = "builtin-macro-redefined";
        const kind = .warning;
    };
    pub const feature_check_requires_identifier = struct {
        const msg = "builtin feature check macro requires a parenthesized identifier";
        const kind = .@"error";
    };
    pub const missing_tok_builtin = struct {
        const msg = "missing '{s}', after builtin feature-check macro";
        const extra = .tok_id_expected;
        const kind = .@"error";
    };
    pub const gnu_label_as_value = struct {
        const msg = "use of GNU address-of-label extension";
        const opt = "gnu-label-as-value";
        const kind = .off;
        const pedantic = true;
    };
    pub const expected_record_ty = struct {
        const msg = "member reference base type '{s}' is not a structure or union";
        const extra = .str;
        const kind = .@"error";
    };
    pub const member_expr_not_ptr = struct {
        const msg = "member reference type '{s}' is not a pointer; did you mean to use '.'?";
        const extra = .str;
        const kind = .@"error";
    };
    pub const member_expr_ptr = struct {
        const msg = "member reference type '{s}' is a pointer; did you mean to use '->'?";
        const extra = .str;
        const kind = .@"error";
    };
    pub const no_such_member = struct {
        const msg = "no member named {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const malformed_warning_check = struct {
        const msg = "{s} expected option name (e.g. \"-Wundef\")";
        const extra = .str;
        const opt = "malformed-warning-check";
        const kind = .warning;
        const all = true;
    };
    pub const invalid_computed_goto = struct {
        const msg = "computed goto in function with no address-of-label expressions";
        const kind = .@"error";
    };
    pub const pragma_warning_message = struct {
        const msg = "{s}";
        const extra = .str;
        const opt = "#pragma-messages";
        const kind = .warning;
    };
    pub const pragma_error_message = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const pragma_message = struct {
        const msg = "#pragma message: {s}";
        const extra = .str;
        const kind = .note;
    };
    pub const pragma_requires_string_literal = struct {
        const msg = "pragma {s} requires string literal";
        const extra = .str;
        const kind = .@"error";
    };
    pub const poisoned_identifier = struct {
        const msg = "attempt to use a poisoned identifier";
        const kind = .@"error";
    };
    pub const pragma_poison_identifier = struct {
        const msg = "can only poison identifier tokens";
        const kind = .@"error";
    };
    pub const pragma_poison_macro = struct {
        const msg = "poisoning existing macro";
        const kind = .warning;
    };
    pub const newline_eof = struct {
        const msg = "no newline at end of file";
        const opt = "newline-eof";
        const kind = .off;
        const pedantic = true;
    };
    pub const empty_translation_unit = struct {
        const msg = "ISO C requires a translation unit to contain at least one declaration";
        const opt = "empty-translation-unit";
        const kind = .off;
        const pedantic = true;
    };
    pub const omitting_parameter_name = struct {
        const msg = "omitting the parameter name in a function definition is a C2x extension";
        const opt = "c2x-extensions";
        const kind = .warning;
        const suppress_version = .c2x;
    };
    pub const non_int_bitfield = struct {
        const msg = "bit-field has non-integer type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const negative_bitwidth = struct {
        const msg = "bit-field has negative width ({d})";
        const extra = .signed;
        const kind = .@"error";
    };
    pub const zero_width_named_field = struct {
        const msg = "named bit-field has zero width";
        const kind = .@"error";
    };
    pub const bitfield_too_big = struct {
        const msg = "width of bit-field exceeds width of its type";
        const kind = .@"error";
    };
    pub const invalid_utf8 = struct {
        const msg = "source file is not valid UTF-8";
        const kind = .@"error";
    };
    pub const implicitly_unsigned_literal = struct {
        const msg = "integer literal is too large to be represented in a signed integer type, interpreting as unsigned";
        const opt = "implicitly-unsigned-literal";
        const kind = .warning;
    };
    pub const invalid_preproc_operator = struct {
        const msg = "token is not a valid binary operator in a preprocessor subexpression";
        const kind = .@"error";
    };
    pub const invalid_preproc_expr_start = struct {
        const msg = "invalid token at start of a preprocessor expression";
        const kind = .@"error";
    };
    pub const c99_compat = struct {
        const msg = "using this character in an identifier is incompatible with C99";
        const opt = "c99-compat";
        const kind = .off;
    };
    pub const unexpected_character = struct {
        const msg = "unexpected character <U+{X:0>4}>";
        const extra = .actual_codepoint;
        const kind = .@"error";
    };
    pub const invalid_identifier_start_char = struct {
        const msg = "character <U+{X:0>4}> not allowed at the start of an identifier";
        const extra = .actual_codepoint;
        const kind = .@"error";
    };
    pub const unicode_zero_width = struct {
        const msg = "identifier contains Unicode character <U+{X:0>4}> that is invisible in some environments";
        const opt = "unicode-homoglyph";
        const extra = .actual_codepoint;
        const kind = .warning;
    };
    pub const unicode_homoglyph = struct {
        const msg = "treating Unicode character <U+{X:0>4}> as identifier character rather than as '{u}' symbol";
        const extra = .codepoints;
        const opt = "unicode-homoglyph";
        const kind = .warning;
    };
    pub const meaningless_asm_qual = struct {
        const msg = "meaningless '{s}' on assembly outside function";
        const extra = .str;
        const kind = .@"error";
    };
    pub const duplicate_asm_qual = struct {
        const msg = "duplicate asm qualifier '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_asm_str = struct {
        const msg = "cannot use {s} string literal in assembly";
        const extra = .str;
        const kind = .@"error";
    };
    pub const dollar_in_identifier_extension = struct {
        const msg = "'$' in identifier";
        const opt = "dollar-in-identifier-extension";
        const kind = .off;
        const suppress_language_option = "dollars_in_identifiers";
        const pedantic = true;
    };
    pub const dollars_in_identifiers = struct {
        const msg = "illegal character '$' in identifier";
        const kind = .@"error";
    };
    pub const expanded_from_here = struct {
        const msg = "expanded from here";
        const kind = .note;
    };
    pub const skipping_macro_backtrace = struct {
        const msg = "(skipping {d} expansions in backtrace; use -fmacro-backtrace-limit=0 to see all)";
        const extra = .unsigned;
        const kind = .note;
    };
    pub const pragma_operator_string_literal = struct {
        const msg = "_Pragma requires exactly one string literal token";
        const kind = .@"error";
    };
    pub const unknown_gcc_pragma = struct {
        const msg = "pragma GCC expected 'error', 'warning', 'diagnostic', 'poison'";
        const opt = "unknown-pragmas";
        const kind = .off;
        const all = true;
    };
    pub const unknown_gcc_pragma_directive = struct {
        const msg = "pragma GCC diagnostic expected 'error', 'warning', 'ignored', 'fatal', 'push', or 'pop'";
        const opt = "unknown-pragmas";
        const kind = .warning;
        const all = true;
    };
    pub const predefined_top_level = struct {
        const msg = "predefined identifier is only valid inside function";
        const opt = "predefined-identifier-outside-function";
        const kind = .warning;
    };
    pub const incompatible_va_arg = struct {
        const msg = "first argument to va_arg, is of type '{s}' and not 'va_list'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const too_many_scalar_init_braces = struct {
        const msg = "too many braces around scalar initializer";
        const opt = "many-braces-around-scalar-init";
        const kind = .warning;
    };
    pub const uninitialized_in_own_init = struct {
        const msg = "variable '{s}' is uninitialized when used within its own initialization";
        const extra = .str;
        const opt = "uninitialized";
        const kind = .off;
        const all = true;
    };
    pub const gnu_statement_expression = struct {
        const msg = "use of GNU statement expression extension";
        const opt = "gnu-statement-expression";
        const kind = .off;
        const suppress_gnu = true;
        const pedantic = true;
    };
    pub const stmt_expr_not_allowed_file_scope = struct {
        const msg = "statement expression not allowed at file scope";
        const kind = .@"error";
    };
    pub const gnu_imaginary_constant = struct {
        const msg = "imaginary constants are a GNU extension";
        const opt = "gnu-imaginary-constant";
        const kind = .off;
        const suppress_gnu = true;
        const pedantic = true;
    };
    pub const plain_complex = struct {
        const msg = "plain '_Complex' requires a type specifier; assuming '_Complex double'";
        const kind = .warning;
    };
    pub const complex_int = struct {
        const msg = "complex integer types are a GNU extension";
        const opt = "gnu-complex-integer";
        const suppress_gnu = true;
        const kind = .off;
    };
    pub const qual_on_ret_type = struct {
        const msg = "'{s}' type qualifier on return type has no effect";
        const opt = "ignored-qualifiers";
        const extra = .str;
        const kind = .off;
        const all = true;
    };
    pub const cli_invalid_standard = struct {
        const msg = "invalid standard '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_invalid_target = struct {
        const msg = "invalid target '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_invalid_emulate = struct {
        const msg = "invalid compiler '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_unknown_arg = struct {
        const msg = "unknown argument '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_error = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_unused_link_object = struct {
        const msg = "{s}: linker input file unused because linking not done";
        const extra = .str;
        const kind = .warning;
    };
    pub const cli_unknown_linker = struct {
        const msg = "unrecognized linker '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const extra_semi = struct {
        const msg = "extra ';' outside of a function";
        const opt = "extra-semi";
        const kind = .off;
        const pedantic = true;
    };
    pub const func_field = struct {
        const msg = "field declared as a function";
        const kind = .@"error";
    };
    pub const vla_field = struct {
        const msg = "variable length array fields extension is not supported";
        const kind = .@"error";
    };
    pub const field_incomplete_ty = struct {
        const msg = "field has incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const flexible_in_union = struct {
        const msg = "flexible array member in union is not allowed";
        const kind = .@"error";
        const suppress_msvc = true;
    };
    pub const flexible_non_final = struct {
        const msg = "flexible array member is not at the end of struct";
        const kind = .@"error";
    };
    pub const flexible_in_empty = struct {
        const msg = "flexible array member in otherwise empty struct";
        const kind = .@"error";
        const suppress_msvc = true;
    };
    pub const duplicate_member = struct {
        const msg = "duplicate member '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const binary_integer_literal = struct {
        const msg = "binary integer literals are a GNU extension";
        const kind = .off;
        const opt = "gnu-binary-literal";
        const pedantic = true;
    };
    pub const gnu_va_macro = struct {
        const msg = "named variadic macros are a GNU extension";
        const opt = "variadic-macros";
        const kind = .off;
        const pedantic = true;
    };
    pub const builtin_must_be_called = struct {
        const msg = "builtin function must be directly called";
        const kind = .@"error";
    };
    pub const va_start_not_in_func = struct {
        const msg = "'va_start' cannot be used outside a function";
        const kind = .@"error";
    };
    pub const va_start_fixed_args = struct {
        const msg = "'va_start' used in a function with fixed args";
        const kind = .@"error";
    };
    pub const va_start_not_last_param = struct {
        const msg = "second argument to 'va_start' is not the last named parameter";
        const opt = "varargs";
        const kind = .warning;
    };
    pub const attribute_not_enough_args = struct {
        const msg = "'{s}' attribute takes at least {d} argument(s)";
        const kind = .@"error";
        const extra = .attr_arg_count;
    };
    pub const attribute_too_many_args = struct {
        const msg = "'{s}' attribute takes at most {d} argument(s)";
        const kind = .@"error";
        const extra = .attr_arg_count;
    };
    pub const attribute_arg_invalid = struct {
        const msg = "Attribute argument is invalid, expected {s} but got {s}";
        const kind = .@"error";
        const extra = .attr_arg_type;
    };
    pub const unknown_attr_enum = struct {
        const msg = "Unknown `{s}` argument. Possible values are: {s}";
        const kind = .@"error";
        const extra = .attr_enum;
    };
    pub const attribute_requires_identifier = struct {
        const msg = "'{s}' attribute requires an identifier";
        const kind = .@"error";
        const extra = .str;
    };
    pub const declspec_not_enabled = struct {
        const msg = "'__declspec' attributes are not enabled; use '-fdeclspec' or '-fms-extensions' to enable support for __declspec attributes";
        const kind = .@"error";
    };
    pub const declspec_attr_not_supported = struct {
        const msg = "__declspec attribute '{s}' is not supported";
        const extra = .str;
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const deprecated_declarations = struct {
        const msg = "{s}";
        const extra = .str;
        const opt = "deprecated-declarations";
        const kind = .warning;
    };
    pub const deprecated_note = struct {
        const msg = "'{s}' has been explicitly marked deprecated here";
        const extra = .str;
        const opt = "deprecated-declarations";
        const kind = .note;
    };
    pub const unavailable = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const unavailable_note = struct {
        const msg = "'{s}' has been explicitly marked unavailable here";
        const extra = .str;
        const kind = .note;
    };
    pub const warning_attribute = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .warning;
        const opt = "attribute-warning";
    };
    pub const error_attribute = struct {
        const msg = "{s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const ignored_record_attr = struct {
        const msg = "attribute '{s}' is ignored, place it after \"{s}\" to apply attribute to type declaration";
        const extra = .ignored_record_attr;
        const kind = .warning;
        const opt = "ignored-attributes";
    };
    pub const backslash_newline_escape = struct {
        const msg = "backslash and newline separated by space";
        const kind = .warning;
        const opt = "backslash-newline-escape";
    };
    pub const array_size_non_int = struct {
        const msg = "size of array has non-integer type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cast_to_smaller_int = struct {
        const msg = "cast to smaller integer type {s}";
        const extra = .str;
        const kind = .warning;
        const opt = "pointer-to-int-cast";
    };
    pub const gnu_switch_range = struct {
        const msg = "use of GNU case range extension";
        const opt = "gnu-case-range";
        const kind = .off;
        const pedantic = true;
    };
    pub const empty_case_range = struct {
        const msg = "empty case range specified";
        const kind = .warning;
    };
    pub const non_standard_escape_char = struct {
        const msg = "use of non-standard escape character '\\{s}'";
        const kind = .off;
        const opt = "pedantic";
        const extra = .invalid_escape;
    };
    pub const invalid_pp_stringify_escape = struct {
        const msg = "invalid string literal, ignoring final '\\'";
        const kind = .warning;
    };
    pub const vla = struct {
        const msg = "variable length array used";
        const kind = .off;
        const opt = "vla";
    };
    pub const float_overflow_conversion = struct {
        const msg = "implicit conversion of non-finite value from {s} is undefined";
        const extra = .str;
        const kind = .off;
        const opt = "float-overflow-conversion";
    };
    pub const float_out_of_range = struct {
        const msg = "implicit conversion of out of range value from {s} is undefined";
        const extra = .str;
        const kind = .warning;
        const opt = "literal-conversion";
    };
    pub const float_zero_conversion = struct {
        const msg = "implicit conversion from {s}";
        const extra = .str;
        const kind = .off;
        const opt = "float-zero-conversion";
    };
    pub const float_value_changed = struct {
        const msg = "implicit conversion from {s}";
        const extra = .str;
        const kind = .warning;
        const opt = "float-conversion";
    };
    pub const float_to_int = struct {
        const msg = "implicit conversion turns floating-point number into integer: {s}";
        const extra = .str;
        const kind = .off;
        const opt = "literal-conversion";
    };
    pub const const_decl_folded = struct {
        const msg = "expression is not an integer constant expression; folding it to a constant is a GNU extension";
        const kind = .off;
        const opt = "gnu-folding-constant";
        const pedantic = true;
    };
    pub const const_decl_folded_vla = struct {
        const msg = "variable length array folded to constant array as an extension";
        const kind = .off;
        const opt = "gnu-folding-constant";
        const pedantic = true;
    };
    pub const redefinition_of_typedef = struct {
        const msg = "typedef redefinition with different types ({s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const undefined_macro = struct {
        const msg = "'{s}' is not defined, evaluates to 0";
        const extra = .str;
        const kind = .off;
        const opt = "undef";
    };
    pub const fn_macro_undefined = struct {
        const msg = "function-like macro '{s}' is not defined";
        const extra = .str;
        const kind = .@"error";
    };
    pub const preprocessing_directive_only = struct {
        const msg = "'{s}' must be used within a preprocessing directive";
        const extra = .tok_id_expected;
        const kind = .@"error";
    };
    pub const missing_lparen_after_builtin = struct {
        const msg = "Missing '(' after built-in macro '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const offsetof_ty = struct {
        const msg = "offsetof requires struct or union type, '{s}' invalid";
        const extra = .str;
        const kind = .@"error";
    };
    pub const offsetof_incomplete = struct {
        const msg = "offsetof of incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const offsetof_array = struct {
        const msg = "offsetof requires array type, '{s}' invalid";
        const extra = .str;
        const kind = .@"error";
    };
    pub const pragma_pack_lparen = struct {
        const msg = "missing '(' after '#pragma pack' - ignoring";
        const kind = .warning;
        const opt = "ignored-pragmas";
    };
    pub const pragma_pack_rparen = struct {
        const msg = "missing ')' after '#pragma pack' - ignoring";
        const kind = .warning;
        const opt = "ignored-pragmas";
    };
    pub const pragma_pack_unknown_action = struct {
        const msg = "unknown action for '#pragma pack' - ignoring";
        const opt = "ignored-pragmas";
        const kind = .warning;
    };
    pub const pragma_pack_show = struct {
        const msg = "value of #pragma pack(show) == {d}";
        const extra = .unsigned;
        const kind = .warning;
    };
    pub const pragma_pack_int = struct {
        const msg = "expected #pragma pack parameter to be '1', '2', '4', '8', or '16'";
        const opt = "ignored-pragmas";
        const kind = .warning;
    };
    pub const pragma_pack_int_ident = struct {
        const msg = "expected integer or identifier in '#pragma pack' - ignored";
        const opt = "ignored-pragmas";
        const kind = .warning;
    };
    pub const pragma_pack_undefined_pop = struct {
        const msg = "specifying both a name and alignment to 'pop' is undefined";
        const kind = .warning;
    };
    pub const pragma_pack_empty_stack = struct {
        const msg = "#pragma pack(pop, ...) failed: stack empty";
        const opt = "ignored-pragmas";
        const kind = .warning;
    };
    pub const cond_expr_type = struct {
        const msg = "used type '{s}' where arithmetic or pointer type is required";
        const extra = .str;
        const kind = .@"error";
    };
    pub const too_many_includes = struct {
        const msg = "#include nested too deeply";
        const kind = .@"error";
    };
    pub const enumerator_too_small = struct {
        const msg = "ISO C restricts enumerator values to range of 'int' ({d} is too small)";
        const extra = .signed;
        const kind = .off;
        const opt = "pedantic";
    };
    pub const enumerator_too_large = struct {
        const msg = "ISO C restricts enumerator values to range of 'int' ({d} is too large)";
        const extra = .unsigned;
        const kind = .off;
        const opt = "pedantic";
    };
    pub const include_next = struct {
        const msg = "#include_next is a language extension";
        const kind = .off;
        const pedantic = true;
        const opt = "gnu-include-next";
    };
    pub const include_next_outside_header = struct {
        const msg = "#include_next in primary source file; will search from start of include path";
        const kind = .warning;
        const opt = "include-next-outside-header";
    };
    pub const enumerator_overflow = struct {
        const msg = "overflow in enumeration value";
        const kind = .warning;
    };
    pub const enum_not_representable = struct {
        const msg = "incremented enumerator value {s} is not representable in the largest integer type";
        const kind = .warning;
        const opt = "enum-too-large";
        const extra = .pow_2_as_string;
    };
    pub const enum_too_large = struct {
        const msg = "enumeration values exceed range of largest integer";
        const kind = .warning;
        const opt = "enum-too-large";
    };
    pub const enum_fixed = struct {
        const msg = "enumeration types with a fixed underlying type are a Clang extension";
        const kind = .off;
        const pedantic = true;
        const opt = "fixed-enum-extension";
    };
    pub const enum_prev_nonfixed = struct {
        const msg = "enumeration previously declared with nonfixed underlying type";
        const kind = .@"error";
    };
    pub const enum_prev_fixed = struct {
        const msg = "enumeration previously declared with fixed underlying type";
        const kind = .@"error";
    };
    pub const enum_different_explicit_ty = struct {
        // str will be like 'new' (was 'old'
        const msg = "enumeration redeclared with different underlying type {s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const enum_not_representable_fixed = struct {
        const msg = "enumerator value is not representable in the underlying type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const transparent_union_wrong_type = struct {
        const msg = "'transparent_union' attribute only applies to unions";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const transparent_union_one_field = struct {
        const msg = "transparent union definition must contain at least one field; transparent_union attribute ignored";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const transparent_union_size = struct {
        const msg = "size of field {s} bits) does not match the size of the first field in transparent union; transparent_union attribute ignored";
        const extra = .str;
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const transparent_union_size_note = struct {
        const msg = "size of first field is {d}";
        const extra = .unsigned;
        const kind = .note;
    };
    pub const designated_init_invalid = struct {
        const msg = "'designated_init' attribute is only valid on 'struct' type'";
        const kind = .@"error";
    };
    pub const designated_init_needed = struct {
        const msg = "positional initialization of field in 'struct' declared with 'designated_init' attribute";
        const opt = "designated-init";
        const kind = .warning;
    };
    pub const ignore_common = struct {
        const msg = "ignoring attribute 'common' because it conflicts with attribute 'nocommon'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const ignore_nocommon = struct {
        const msg = "ignoring attribute 'nocommon' because it conflicts with attribute 'common'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const non_string_ignored = struct {
        const msg = "'nonstring' attribute ignored on objects of type '{s}'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const local_variable_attribute = struct {
        const msg = "'{s}' attribute only applies to local variables";
        const extra = .str;
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const ignore_cold = struct {
        const msg = "ignoring attribute 'cold' because it conflicts with attribute 'hot'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const ignore_hot = struct {
        const msg = "ignoring attribute 'hot' because it conflicts with attribute 'cold'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const ignore_noinline = struct {
        const msg = "ignoring attribute 'noinline' because it conflicts with attribute 'always_inline'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const ignore_always_inline = struct {
        const msg = "ignoring attribute 'always_inline' because it conflicts with attribute 'noinline'";
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const invalid_noreturn = struct {
        const msg = "function '{s}' declared 'noreturn' should not return";
        const extra = .str;
        const kind = .warning;
        const opt = "invalid-noreturn";
    };
    pub const nodiscard_unused = struct {
        const msg = "ignoring return value of '{s}', declared with 'nodiscard' attribute";
        const extra = .str;
        const kind = .warning;
        const op = "unused-result";
    };
    pub const warn_unused_result = struct {
        const msg = "ignoring return value of '{s}', declared with 'warn_unused_result' attribute";
        const extra = .str;
        const kind = .warning;
        const op = "unused-result";
    };
    pub const invalid_vec_elem_ty = struct {
        const msg = "invalid vector element type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const vec_size_not_multiple = struct {
        const msg = "vector size not an integral multiple of component size";
        const kind = .@"error";
    };
    pub const invalid_imag = struct {
        const msg = "invalid type '{s}' to __imag operator";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_real = struct {
        const msg = "invalid type '{s}' to __real operator";
        const extra = .str;
        const kind = .@"error";
    };
    pub const zero_length_array = struct {
        const msg = "zero size arrays are an extension";
        const kind = .off;
        const pedantic = true;
        const opt = "zero-length-array";
    };
    pub const old_style_flexible_struct = struct {
        const msg = "array index {d} is past the end of the array";
        const extra = .unsigned;
        const kind = .off;
        const pedantic = true;
        const opt = "old-style-flexible-struct";
    };
    pub const comma_deletion_va_args = struct {
        const msg = "token pasting of ',' and __VA_ARGS__ is a GNU extension";
        const kind = .off;
        const pedantic = true;
        const opt = "gnu-zero-variadic-macro-arguments";
        const suppress_gcc = true;
    };
    pub const main_return_type = struct {
        const msg = "return type of 'main' is not 'int'";
        const kind = .warning;
        const opt = "main-return-type";
    };
    pub const expansion_to_defined = struct {
        const msg = "macro expansion producing 'defined' has undefined behavior";
        const kind = .off;
        const pedantic = true;
        const opt = "expansion-to-defined";
    };
    pub const invalid_int_suffix = struct {
        const msg = "invalid suffix '{s}' on integer constant";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_float_suffix = struct {
        const msg = "invalid suffix '{s}' on floating constant";
        const extra = .str;
        const kind = .@"error";
    };
    pub const invalid_octal_digit = struct {
        const msg = "invalid digit '{c}' in octal constant";
        const extra = .ascii;
        const kind = .@"error";
    };
    pub const invalid_binary_digit = struct {
        const msg = "invalid digit '{c}' in binary constant";
        const extra = .ascii;
        const kind = .@"error";
    };
    pub const exponent_has_no_digits = struct {
        const msg = "exponent has no digits";
        const kind = .@"error";
    };
    pub const hex_floating_constant_requires_exponent = struct {
        const msg = "hexadecimal floating constant requires an exponent";
        const kind = .@"error";
    };
    pub const sizeof_returns_zero = struct {
        const msg = "sizeof returns 0";
        const kind = .warning;
        const suppress_gcc = true;
        const suppress_clang = true;
    };
    pub const declspec_not_allowed_after_declarator = struct {
        const msg = "'declspec' attribute not allowed after declarator";
        const kind = .@"error";
    };
    pub const declarator_name_tok = struct {
        const msg = "this declarator";
        const kind = .note;
    };
    pub const type_not_supported_on_target = struct {
        const msg = "{s} is not supported on this target";
        const extra = .str;
        const kind = .@"error";
    };
    pub const bit_int = struct {
        const msg = "'_BitInt' in C17 and earlier is a Clang extension'";
        const kind = .off;
        const pedantic = true;
        const opt = "bit-int-extension";
        const suppress_version = .c2x;
    };
    pub const unsigned_bit_int_too_small = struct {
        const msg = "{s} must have a bit size of at least 1";
        const extra = .str;
        const kind = .@"error";
    };
    pub const signed_bit_int_too_small = struct {
        const msg = "{s} must have a bit size of at least 2";
        const extra = .str;
        const kind = .@"error";
    };
    pub const bit_int_too_big = struct {
        const msg = "{s} of bit sizes greater than " ++ std.fmt.comptimePrint("{d}", .{Compilation.bit_int_max_bits}) ++ " not supported";
        const extra = .str;
        const kind = .@"error";
    };
    pub const keyword_macro = struct {
        const msg = "keyword is hidden by macro definition";
        const kind = .off;
        const pedantic = true;
        const opt = "keyword-macro";
    };
    pub const ptr_arithmetic_incomplete = struct {
        const msg = "arithmetic on a pointer to an incomplete type '{s}'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const callconv_not_supported = struct {
        const msg = "'{s}' calling convention is not supported for this target";
        const extra = .str;
        const opt = "ignored-attributes";
        const kind = .warning;
    };
    pub const pointer_arith_void = struct {
        const msg = "invalid application of '{s}' to a void type";
        const extra = .str;
        const kind = .off;
        const pedantic = true;
        const opt = "pointer-arith";
    };
    pub const sizeof_array_arg = struct {
        const msg = "sizeof on array function parameter will return size of {s}";
        const extra = .str;
        const kind = .warning;
        const opt = "sizeof-array-argument";
    };
    pub const array_address_to_bool = struct {
        const msg = "address of array '{s}' will always evaluate to 'true'";
        const extra = .str;
        const kind = .warning;
        const opt = "pointer-bool-conversion";
    };
    pub const string_literal_to_bool = struct {
        const msg = "implicit conversion turns string literal into bool: {s}";
        const extra = .str;
        const kind = .off;
        const opt = "string-conversion";
    };
    pub const constant_expression_conversion_not_allowed = struct {
        const msg = "this conversion is not allowed in a constant expression";
        const kind = .note;
    };
    pub const invalid_object_cast = struct {
        const msg = "cannot cast an object of type {s}";
        const extra = .str;
        const kind = .@"error";
    };
    pub const cli_invalid_fp_eval_method = struct {
        const msg = "unsupported argument '{s}' to option '-ffp-eval-method='; expected 'source', 'double', or 'extended'";
        const extra = .str;
        const kind = .@"error";
    };
    pub const suggest_pointer_for_invalid_fp16 = struct {
        const msg = "{s} cannot have __fp16 type; did you forget * ?";
        const extra = .str;
        const kind = .@"error";
    };
    pub const bitint_suffix = struct {
        const msg = "'_BitInt' suffix for literals is a C2x extension";
        const opt = "c2x-extensions";
        const kind = .warning;
        const suppress_version = .c2x;
    };
    pub const auto_type_extension = struct {
        const msg = "'__auto_type' is a GNU extension";
        const opt = "gnu-auto-type";
        const kind = .off;
        const pedantic = true;
    };
    pub const auto_type_not_allowed = struct {
        const msg = "'__auto_type' not allowed in {s}";
        const kind = .@"error";
        const extra = .str;
    };
    pub const auto_type_requires_initializer = struct {
        const msg = "declaration of variable '{s}' with deduced type requires an initializer";
        const kind = .@"error";
        const extra = .str;
    };
    pub const auto_type_requires_single_declarator = struct {
        const msg = "'__auto_type' may only be used with a single declarator";
        const kind = .@"error";
    };
    pub const auto_type_requires_plain_declarator = struct {
        const msg = "'__auto_type' requires a plain identifier as declarator";
        const kind = .@"error";
    };
    pub const invalid_cast_to_auto_type = struct {
        const msg = "invalid cast to '__auto_type'";
        const kind = .@"error";
    };
    pub const auto_type_from_bitfield = struct {
        const msg = "cannot use bit-field as '__auto_type' initializer";
        const kind = .@"error";
    };
    pub const array_of_auto_type = struct {
        const msg = "'{s}' declared as array of '__auto_type'";
        const kind = .@"error";
        const extra = .str;
    };
    pub const auto_type_with_init_list = struct {
        const msg = "cannot use '__auto_type' with initializer list";
        const kind = .@"error";
    };
    pub const missing_semicolon = struct {
        const msg = "expected ';' at end of declaration list";
        const kind = .warning;
    };
    pub const tentative_definition_incomplete = struct {
        const msg = "tentative definition has type '{s}' that is never completed";
        const kind = .@"error";
        const extra = .str;
    };
    pub const forward_declaration_here = struct {
        const msg = "forward declaration of '{s}'";
        const kind = .note;
        const extra = .str;
    };
    pub const gnu_union_cast = struct {
        const msg = "cast to union type is a GNU extension";
        const opt = "gnu-union-cast";
        const kind = .off;
        const pedantic = true;
    };
    pub const invalid_union_cast = struct {
        const msg = "cast to union type from type '{s}' not present in union";
        const kind = .@"error";
        const extra = .str;
    };
    pub const cast_to_incomplete_type = struct {
        const msg = "cast to incomplete type '{s}'";
        const kind = .@"error";
        const extra = .str;
    };
    pub const invalid_source_epoch = struct {
        const msg = "environment variable SOURCE_DATE_EPOCH must expand to a non-negative integer less than or equal to 253402300799";
        const kind = .@"error";
    };
    pub const fuse_ld_path = struct {
        const msg = "'-fuse-ld=' taking a path is deprecated; use '--ld-path=' instead";
        const kind = .off;
        const opt = "fuse-ld-path";
    };
    pub const invalid_rtlib = struct {
        const msg = "invalid runtime library name '{s}'";
        const kind = .@"error";
        const extra = .str;
    };
    pub const unsupported_rtlib_gcc = struct {
        const msg = "unsupported runtime library 'libgcc' for platform '{s}'";
        const kind = .@"error";
        const extra = .str;
    };
    pub const invalid_unwindlib = struct {
        const msg = "invalid unwind library name '{s}'";
        const kind = .@"error";
        const extra = .str;
    };
    pub const incompatible_unwindlib = struct {
        const msg = "--rtlib=libgcc requires --unwindlib=libgcc";
        const kind = .@"error";
    };
    pub const gnu_asm_disabled = struct {
        const msg = "GNU-style inline assembly is disabled";
        const kind = .@"error";
    };
    pub const extension_token_used = struct {
        const msg = "extension used";
        const kind = .off;
        const pedantic = true;
        const opt = "language-extension-token";
    };
    pub const complex_component_init = struct {
        const msg = "complex initialization specifying real and imaginary components is an extension";
        const opt = "complex-component-init";
        const kind = .off;
        const pedantic = true;
    };
    pub const complex_prefix_postfix_op = struct {
        const msg = "ISO C does not support '++'/'--' on complex type '{s}'";
        const opt = "pedantic";
        const extra = .str;
        const kind = .off;
    };
    pub const not_floating_type = struct {
        const msg = "argument type '{s}' is not a real floating point type";
        const extra = .str;
        const kind = .@"error";
    };
    pub const argument_types_differ = struct {
        const msg = "arguments are of different types ({s})";
        const extra = .str;
        const kind = .@"error";
    };
    pub const ms_search_rule = struct {
        const msg = "#include resolved using non-portable Microsoft search rules as: {s}";
        const extra = .str;
        const opt = "microsoft-include";
        const kind = .warning;
    };
    pub const ctrl_z_eof = struct {
        const msg = "treating Ctrl-Z as end-of-file is a Microsoft extension";
        const opt = "microsoft-end-of-file";
        const kind = .off;
        const pedantic = true;
    };
    pub const illegal_char_encoding_warning = struct {
        const msg = "illegal character encoding in character literal";
        const opt = "invalid-source-encoding";
        const kind = .warning;
    };
    pub const illegal_char_encoding_error = struct {
        const msg = "illegal character encoding in character literal";
        const kind = .@"error";
    };
    pub const ucn_basic_char_error = struct {
        const msg = "character '{c}' cannot be specified by a universal character name";
        const kind = .@"error";
        const extra = .ascii;
    };
    pub const ucn_basic_char_warning = struct {
        const msg = "specifying character '{c}' with a universal character name is incompatible with C standards before C2x";
        const kind = .off;
        const extra = .ascii;
        const suppress_unless_version = .c2x;
        const opt = "pre-c2x-compat";
    };
    pub const ucn_control_char_error = struct {
        const msg = "universal character name refers to a control character";
        const kind = .@"error";
    };
    pub const ucn_control_char_warning = struct {
        const msg = "universal character name referring to a control character is incompatible with C standards before C2x";
        const kind = .off;
        const suppress_unless_version = .c2x;
        const opt = "pre-c2x-compat";
    };
    pub const c89_ucn_in_literal = struct {
        const msg = "universal character names are only valid in C99 or later";
        const suppress_version = .c99;
        const kind = .warning;
        const opt = "unicode";
    };
    pub const four_char_char_literal = struct {
        const msg = "multi-character character constant";
        const opt = "four-char-constants";
        const kind = .off;
    };
    pub const multi_char_char_literal = struct {
        const msg = "multi-character character constant";
        const kind = .off;
    };
    pub const missing_hex_escape = struct {
        const msg = "\\{c} used with no following hex digits";
        const kind = .@"error";
        const extra = .ascii;
    };
    pub const unknown_escape_sequence = struct {
        const msg = "unknown escape sequence '\\{s}'";
        const kind = .warning;
        const opt = "unknown-escape-sequence";
        const extra = .invalid_escape;
    };
};

list: std.ArrayListUnmanaged(Message) = .{},
arena: std.heap.ArenaAllocator,
color: bool = true,
fatal_errors: bool = false,
options: Options = .{},
errors: u32 = 0,
macro_backtrace_limit: u32 = 6,

pub fn warningExists(name: []const u8) bool {
    inline for (std.meta.fields(Options)) |f| {
        if (mem.eql(u8, f.name, name)) return true;
    }
    return false;
}

pub fn set(diag: *Diagnostics, name: []const u8, to: Kind) !void {
    inline for (std.meta.fields(Options)) |f| {
        if (mem.eql(u8, f.name, name)) {
            @field(diag.options, f.name) = to;
            return;
        }
    }
    try diag.add(.{
        .tag = .unknown_warning,
        .extra = .{ .str = name },
    }, &.{});
}

pub fn init(gpa: Allocator) Diagnostics {
    return .{
        .arena = std.heap.ArenaAllocator.init(gpa),
    };
}

pub fn deinit(diag: *Diagnostics) void {
    diag.list.deinit(diag.arena.allocator());
    diag.arena.deinit();
}

pub fn add(diag: *Diagnostics, msg: Message, expansion_locs: []const Source.Location) Compilation.Error!void {
    const kind = diag.tagKind(msg.tag);
    if (kind == .off) return;
    var copy = msg;
    copy.kind = kind;

    if (expansion_locs.len != 0) copy.loc = expansion_locs[expansion_locs.len - 1];
    try diag.list.append(diag.arena.allocator(), copy);
    if (expansion_locs.len != 0) {
        // Add macro backtrace notes in reverse order omitting from the middle if needed.
        var i = expansion_locs.len - 1;
        const half = diag.macro_backtrace_limit / 2;
        const limit = if (i < diag.macro_backtrace_limit) 0 else i - half;
        try diag.list.ensureUnusedCapacity(
            diag.arena.allocator(),
            if (limit == 0) expansion_locs.len else diag.macro_backtrace_limit + 1,
        );
        while (i > limit) {
            i -= 1;
            diag.list.appendAssumeCapacity(.{
                .tag = .expanded_from_here,
                .kind = .note,
                .loc = expansion_locs[i],
            });
        }
        if (limit != 0) {
            diag.list.appendAssumeCapacity(.{
                .tag = .skipping_macro_backtrace,
                .kind = .note,
                .extra = .{ .unsigned = expansion_locs.len - diag.macro_backtrace_limit },
            });
            i = half - 1;
            while (i > 0) {
                i -= 1;
                diag.list.appendAssumeCapacity(.{
                    .tag = .expanded_from_here,
                    .kind = .note,
                    .loc = expansion_locs[i],
                });
            }
        }

        diag.list.appendAssumeCapacity(.{
            .tag = .expanded_from_here,
            .kind = .note,
            .loc = msg.loc,
        });
    }
    if (kind == .@"fatal error" or (kind == .@"error" and diag.fatal_errors))
        return error.FatalError;
}

pub fn fatal(
    diag: *Diagnostics,
    path: []const u8,
    line: []const u8,
    line_no: u32,
    col: u32,
    comptime fmt: []const u8,
    args: anytype,
) Compilation.Error {
    var m = MsgWriter.init(diag.color);
    defer m.deinit();

    m.location(path, line_no, col);
    m.start(.@"fatal error");
    m.print(fmt, args);
    m.end(line, col, false);

    diag.errors += 1;
    return error.FatalError;
}

pub fn fatalNoSrc(diag: *Diagnostics, comptime fmt: []const u8, args: anytype) error{FatalError} {
    if (!diag.color) {
        std.debug.print("fatal error: " ++ fmt ++ "\n", args);
    } else {
        const std_err = std.io.getStdErr().writer();
        util.setColor(.red, std_err);
        std_err.writeAll("fatal error: ") catch {};
        util.setColor(.white, std_err);
        std_err.print(fmt ++ "\n", args) catch {};
        util.setColor(.reset, std_err);
    }
    diag.errors += 1;
    return error.FatalError;
}

pub fn render(comp: *Compilation) void {
    if (comp.diag.list.items.len == 0) return;
    var m = defaultMsgWriter(comp);
    defer m.deinit();
    renderMessages(comp, &m);
}
pub fn defaultMsgWriter(comp: *const Compilation) MsgWriter {
    return MsgWriter.init(comp.diag.color);
}

pub fn renderMessages(comp: *Compilation, m: anytype) void {
    var errors: u32 = 0;
    var warnings: u32 = 0;
    for (comp.diag.list.items) |msg| {
        switch (msg.kind) {
            .@"fatal error", .@"error" => errors += 1,
            .warning => warnings += 1,
            .note => {},
            .off => continue, // happens if an error is added before it is disabled
            .default => unreachable,
        }
        renderMessage(comp, m, msg);
    }
    const w_s: []const u8 = if (warnings == 1) "" else "s";
    const e_s: []const u8 = if (errors == 1) "" else "s";
    if (errors != 0 and warnings != 0) {
        m.print("{d} warning{s} and {d} error{s} generated.\n", .{ warnings, w_s, errors, e_s });
    } else if (warnings != 0) {
        m.print("{d} warning{s} generated.\n", .{ warnings, w_s });
    } else if (errors != 0) {
        m.print("{d} error{s} generated.\n", .{ errors, e_s });
    }

    comp.diag.list.items.len = 0;
    comp.diag.errors += errors;
}

pub fn renderMessage(comp: *Compilation, m: anytype, msg: Message) void {
    var line: ?[]const u8 = null;
    var end_with_splice = false;
    const width = if (msg.loc.id != .unused) blk: {
        var loc = msg.loc;
        switch (msg.tag) {
            .escape_sequence_overflow,
            .invalid_universal_character,
            // use msg.extra.unsigned for index into string literal
            => loc.byte_offset += @truncate(msg.extra.unsigned),
            .non_standard_escape_char,
            .unknown_escape_sequence,
            => loc.byte_offset += msg.extra.invalid_escape.offset,
            else => {},
        }
        const source = comp.getSource(loc.id);
        var line_col = source.lineCol(loc);
        line = line_col.line;
        end_with_splice = line_col.end_with_splice;
        if (msg.tag == .backslash_newline_escape) {
            line = line_col.line[0 .. line_col.col - 1];
            line_col.col += 1;
            line_col.width += 1;
        }
        m.location(source.path, line_col.line_no, line_col.col);
        break :blk line_col.width;
    } else 0;

    m.start(msg.kind);
    @setEvalBranchQuota(1500);
    switch (msg.tag) {
        inline else => |tag| {
            const info = @field(messages, @tagName(tag));
            if (@hasDecl(info, "extra")) {
                switch (info.extra) {
                    .str => m.print(info.msg, .{msg.extra.str}),
                    .tok_id => m.print(info.msg, .{
                        msg.extra.tok_id.expected.symbol(),
                        msg.extra.tok_id.actual.symbol(),
                    }),
                    .tok_id_expected => m.print(info.msg, .{msg.extra.tok_id_expected.symbol()}),
                    .arguments => m.print(info.msg, .{ msg.extra.arguments.expected, msg.extra.arguments.actual }),
                    .codepoints => m.print(info.msg, .{
                        msg.extra.codepoints.actual,
                        msg.extra.codepoints.resembles,
                    }),
                    .attr_arg_count => m.print(info.msg, .{
                        @tagName(msg.extra.attr_arg_count.attribute),
                        msg.extra.attr_arg_count.expected,
                    }),
                    .attr_arg_type => m.print(info.msg, .{
                        msg.extra.attr_arg_type.expected.toString(),
                        msg.extra.attr_arg_type.actual.toString(),
                    }),
                    .actual_codepoint => m.print(info.msg, .{msg.extra.actual_codepoint}),
                    .ascii => m.print(info.msg, .{msg.extra.ascii}),
                    .unsigned => m.print(info.msg, .{msg.extra.unsigned}),
                    .pow_2_as_string => m.print(info.msg, .{switch (msg.extra.pow_2_as_string) {
                        63 => "9223372036854775808",
                        64 => "18446744073709551616",
                        127 => "170141183460469231731687303715884105728",
                        128 => "340282366920938463463374607431768211456",
                        else => unreachable,
                    }}),
                    .signed => m.print(info.msg, .{msg.extra.signed}),
                    .attr_enum => m.print(info.msg, .{
                        @tagName(msg.extra.attr_enum.tag),
                        Attribute.Formatting.choices(msg.extra.attr_enum.tag),
                    }),
                    .ignored_record_attr => m.print(info.msg, .{
                        @tagName(msg.extra.ignored_record_attr.tag),
                        @tagName(msg.extra.ignored_record_attr.specifier),
                    }),
                    .builtin_with_header => m.print(info.msg, .{
                        @tagName(msg.extra.builtin_with_header.header),
                        BuiltinFunction.nameFromTag(msg.extra.builtin_with_header.builtin).span(),
                    }),
                    .invalid_escape => {
                        if (std.ascii.isPrint(msg.extra.invalid_escape.char)) {
                            const str: [1]u8 = .{msg.extra.invalid_escape.char};
                            m.print(info.msg, .{&str});
                        } else {
                            var buf: [3]u8 = undefined;
                            _ = std.fmt.bufPrint(&buf, "x{x}", .{std.fmt.fmtSliceHexLower(&.{msg.extra.invalid_escape.char})}) catch unreachable;
                            m.print(info.msg, .{&buf});
                        }
                    },
                    else => @compileError("invalid extra kind " ++ @tagName(info.extra)),
                }
            } else {
                m.write(info.msg);
            }

            if (@hasDecl(info, "opt")) {
                if (msg.kind == .@"error" and info.kind != .@"error") {
                    m.print(" [-Werror,-W{s}]", .{info.opt});
                } else if (msg.kind != .note) {
                    m.print(" [-W{s}]", .{info.opt});
                }
            }
        },
    }

    m.end(line, width, end_with_splice);
}

fn tagKind(diag: *Diagnostics, tag: Tag) Kind {
    // XXX: horrible hack, do not do this
    const comp = @fieldParentPtr(Compilation, "diag", diag);

    var kind: Kind = undefined;
    switch (tag) {
        inline else => |tag_val| {
            const info = @field(messages, @tagName(tag_val));
            kind = info.kind;

            // stage1 doesn't like when I combine these ifs
            if (@hasDecl(info, "all")) {
                if (diag.options.all != .default) kind = diag.options.all;
            }
            if (@hasDecl(info, "w_extra")) {
                if (diag.options.extra != .default) kind = diag.options.extra;
            }
            if (@hasDecl(info, "pedantic")) {
                if (diag.options.pedantic != .default) kind = diag.options.pedantic;
            }
            if (@hasDecl(info, "opt")) {
                if (@field(diag.options, info.opt) != .default) kind = @field(diag.options, info.opt);
            }
            if (@hasDecl(info, "suppress_version")) if (comp.langopts.standard.atLeast(info.suppress_version)) return .off;
            if (@hasDecl(info, "suppress_unless_version")) if (!comp.langopts.standard.atLeast(info.suppress_unless_version)) return .off;
            if (@hasDecl(info, "suppress_gnu")) if (comp.langopts.standard.isExplicitGNU()) return .off;
            if (@hasDecl(info, "suppress_language_option")) if (!@field(comp.langopts, info.suppress_language_option)) return .off;
            if (@hasDecl(info, "suppress_gcc")) if (comp.langopts.emulate == .gcc) return .off;
            if (@hasDecl(info, "suppress_clang")) if (comp.langopts.emulate == .clang) return .off;
            if (@hasDecl(info, "suppress_msvc")) if (comp.langopts.emulate == .msvc) return .off;
            if (kind == .@"error" and diag.fatal_errors) kind = .@"fatal error";
            return kind;
        },
    }
}

const MsgWriter = struct {
    w: std.io.BufferedWriter(4096, std.fs.File.Writer),
    color: bool,

    fn init(color: bool) MsgWriter {
        std.debug.getStderrMutex().lock();
        return .{
            .w = std.io.bufferedWriter(std.io.getStdErr().writer()),
            .color = color,
        };
    }

    pub fn deinit(m: *MsgWriter) void {
        m.w.flush() catch {};
        std.debug.getStderrMutex().unlock();
    }

    pub fn print(m: *MsgWriter, comptime fmt: []const u8, args: anytype) void {
        m.w.writer().print(fmt, args) catch {};
    }

    fn write(m: *MsgWriter, msg: []const u8) void {
        m.w.writer().writeAll(msg) catch {};
    }

    fn setColor(m: *MsgWriter, color: util.Color) void {
        util.setColor(color, m.w.writer());
    }

    fn location(m: *MsgWriter, path: []const u8, line: u32, col: u32) void {
        const prefix = if (std.fs.path.dirname(path) == null and path[0] != '<') "." ++ std.fs.path.sep_str else "";
        if (!m.color) {
            m.print("{s}{s}:{d}:{d}: ", .{ prefix, path, line, col });
        } else {
            m.setColor(.white);
            m.print("{s}{s}:{d}:{d}: ", .{ prefix, path, line, col });
        }
    }

    fn start(m: *MsgWriter, kind: Kind) void {
        if (!m.color) {
            m.print("{s}: ", .{@tagName(kind)});
        } else {
            switch (kind) {
                .@"fatal error", .@"error" => m.setColor(.red),
                .note => m.setColor(.cyan),
                .warning => m.setColor(.purple),
                .off, .default => unreachable,
            }
            m.write(switch (kind) {
                .@"fatal error" => "fatal error: ",
                .@"error" => "error: ",
                .note => "note: ",
                .warning => "warning: ",
                .off, .default => unreachable,
            });
            m.setColor(.white);
        }
    }

    fn end(m: *MsgWriter, maybe_line: ?[]const u8, col: u32, end_with_splice: bool) void {
        const line = maybe_line orelse {
            m.write("\n");
            m.setColor(.reset);
            return;
        };
        const trailer = if (end_with_splice) "\\ " else "";
        if (!m.color) {
            m.print("\n{s}{s}\n", .{ line, trailer });
            m.print("{s: >[1]}^\n", .{ "", col });
        } else {
            m.setColor(.reset);
            m.print("\n{s}{s}\n{s: >[3]}", .{ line, trailer, "", col });
            m.setColor(.green);
            m.write("^\n");
            m.setColor(.reset);
        }
    }
};
