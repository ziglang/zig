const std = @import("std");

const Diagnostics = @import("../Diagnostics.zig");
const LangOpts = @import("../LangOpts.zig");
const Compilation = @import("../Compilation.zig");

const Diagnostic = @This();

fmt: []const u8,
kind: Diagnostics.Message.Kind,
opt: ?Diagnostics.Option = null,
extension: bool = false,
show_in_system_headers: bool = false,

pub const elif_without_if: Diagnostic = .{
    .fmt = "#elif without #if",
    .kind = .@"error",
};

pub const elif_after_else: Diagnostic = .{
    .fmt = "#elif after #else",
    .kind = .@"error",
};

pub const elifdef_without_if: Diagnostic = .{
    .fmt = "#elifdef without #if",
    .kind = .@"error",
};

pub const elifdef_after_else: Diagnostic = .{
    .fmt = "#elifdef after #else",
    .kind = .@"error",
};

pub const elifndef_without_if: Diagnostic = .{
    .fmt = "#elifndef without #if",
    .kind = .@"error",
};

pub const elifndef_after_else: Diagnostic = .{
    .fmt = "#elifndef after #else",
    .kind = .@"error",
};

pub const else_without_if: Diagnostic = .{
    .fmt = "#else without #if",
    .kind = .@"error",
};

pub const else_after_else: Diagnostic = .{
    .fmt = "#else after #else",
    .kind = .@"error",
};

pub const endif_without_if: Diagnostic = .{
    .fmt = "#endif without #if",
    .kind = .@"error",
};

pub const unknown_pragma: Diagnostic = .{
    .fmt = "unknown pragma ignored",
    .opt = .@"unknown-pragmas",
    .kind = .off,
};

pub const line_simple_digit: Diagnostic = .{
    .fmt = "#line directive requires a simple digit sequence",
    .kind = .@"error",
};

pub const line_invalid_filename: Diagnostic = .{
    .fmt = "invalid filename for #line directive",
    .kind = .@"error",
};

pub const unterminated_conditional_directive: Diagnostic = .{
    .fmt = "unterminated conditional directive",
    .kind = .@"error",
};

pub const invalid_preprocessing_directive: Diagnostic = .{
    .fmt = "invalid preprocessing directive",
    .kind = .@"error",
};

pub const error_directive: Diagnostic = .{
    .fmt = "{s}",
    .kind = .@"error",
};

pub const warning_directive: Diagnostic = .{
    .fmt = "{s}",
    .opt = .@"#warnings",
    .kind = .warning,
    .show_in_system_headers = true,
};

pub const macro_name_missing: Diagnostic = .{
    .fmt = "macro name missing",
    .kind = .@"error",
};

pub const extra_tokens_directive_end: Diagnostic = .{
    .fmt = "extra tokens at end of macro directive",
    .kind = .@"error",
};

pub const expected_value_in_expr: Diagnostic = .{
    .fmt = "expected value in expression",
    .kind = .@"error",
};

pub const defined_as_macro_name: Diagnostic = .{
    .fmt = "'defined' cannot be used as a macro name",
    .kind = .@"error",
};

pub const macro_name_must_be_identifier: Diagnostic = .{
    .fmt = "macro name must be an identifier",
    .kind = .@"error",
};

pub const whitespace_after_macro_name: Diagnostic = .{
    .fmt = "ISO C99 requires whitespace after the macro name",
    .opt = .@"c99-extensions",
    .kind = .warning,
    .extension = true,
};

pub const hash_hash_at_start: Diagnostic = .{
    .fmt = "'##' cannot appear at the start of a macro expansion",
    .kind = .@"error",
};

pub const hash_hash_at_end: Diagnostic = .{
    .fmt = "'##' cannot appear at the end of a macro expansion",
    .kind = .@"error",
};

pub const pasting_formed_invalid: Diagnostic = .{
    .fmt = "pasting formed '{s}', an invalid preprocessing token",
    .kind = .@"error",
};

pub const missing_paren_param_list: Diagnostic = .{
    .fmt = "missing ')' in macro parameter list",
    .kind = .@"error",
};

pub const unterminated_macro_param_list: Diagnostic = .{
    .fmt = "unterminated macro param list",
    .kind = .@"error",
};

pub const invalid_token_param_list: Diagnostic = .{
    .fmt = "invalid token in macro parameter list",
    .kind = .@"error",
};

pub const expected_comma_param_list: Diagnostic = .{
    .fmt = "expected comma in macro parameter list",
    .kind = .@"error",
};

pub const hash_not_followed_param: Diagnostic = .{
    .fmt = "'#' is not followed by a macro parameter",
    .kind = .@"error",
};

pub const expected_filename: Diagnostic = .{
    .fmt = "expected \"FILENAME\" or <FILENAME>",
    .kind = .@"error",
};

pub const empty_filename: Diagnostic = .{
    .fmt = "empty filename",
    .kind = .@"error",
};

pub const header_str_closing: Diagnostic = .{
    .fmt = "expected closing '>'",
    .kind = .@"error",
};

pub const header_str_match: Diagnostic = .{
    .fmt = "to match this '<'",
    .kind = .note,
};

pub const string_literal_in_pp_expr: Diagnostic = .{
    .fmt = "string literal in preprocessor expression",
    .kind = .@"error",
};

pub const empty_char_literal_warning: Diagnostic = .{
    .fmt = "empty character constant",
    .kind = .warning,
    .opt = .@"invalid-pp-token",
    .extension = true,
};

pub const unterminated_char_literal_warning: Diagnostic = .{
    .fmt = "missing terminating ' character",
    .kind = .warning,
    .opt = .@"invalid-pp-token",
    .extension = true,
};

pub const unterminated_string_literal_warning: Diagnostic = .{
    .fmt = "missing terminating '\"' character",
    .kind = .warning,
    .opt = .@"invalid-pp-token",
    .extension = true,
};

pub const unterminated_comment: Diagnostic = .{
    .fmt = "unterminated comment",
    .kind = .@"error",
};

pub const malformed_embed_param: Diagnostic = .{
    .fmt = "unexpected token in embed parameter",
    .kind = .@"error",
};

pub const malformed_embed_limit: Diagnostic = .{
    .fmt = "the limit parameter expects one non-negative integer as a parameter",
    .kind = .@"error",
};

pub const duplicate_embed_param: Diagnostic = .{
    .fmt = "duplicate embed parameter '{s}'",
    .kind = .warning,
    .opt = .@"duplicate-embed-param",
};

pub const unsupported_embed_param: Diagnostic = .{
    .fmt = "unsupported embed parameter '{s}' embed parameter",
    .kind = .warning,
    .opt = .@"unsupported-embed-param",
};

pub const va_opt_lparen: Diagnostic = .{
    .fmt = "missing '(' following __VA_OPT__",
    .kind = .@"error",
};

pub const va_opt_rparen: Diagnostic = .{
    .fmt = "unterminated __VA_OPT__ argument list",
    .kind = .@"error",
};

pub const keyword_macro: Diagnostic = .{
    .fmt = "keyword is hidden by macro definition",
    .kind = .off,
    .opt = .@"keyword-macro",
    .extension = true,
};

pub const undefined_macro: Diagnostic = .{
    .fmt = "'{s}' is not defined, evaluates to 0",
    .kind = .off,
    .opt = .undef,
};

pub const fn_macro_undefined: Diagnostic = .{
    .fmt = "function-like macro '{s}' is not defined",
    .kind = .@"error",
};

// pub const preprocessing_directive_only: Diagnostic = .{
//     .fmt = "'{s}' must be used within a preprocessing directive",
//     .extra = .tok_id_expected,
//     .kind = .@"error",
// };

pub const missing_lparen_after_builtin: Diagnostic = .{
    .fmt = "Missing '(' after built-in macro '{s}'",
    .kind = .@"error",
};

pub const too_many_includes: Diagnostic = .{
    .fmt = "#include nested too deeply",
    .kind = .@"error",
};

pub const include_next: Diagnostic = .{
    .fmt = "#include_next is a language extension",
    .kind = .off,
    .opt = .@"gnu-include-next",
    .extension = true,
};

pub const include_next_outside_header: Diagnostic = .{
    .fmt = "#include_next in primary source file; will search from start of include path",
    .kind = .warning,
    .opt = .@"include-next-outside-header",
};

pub const comma_deletion_va_args: Diagnostic = .{
    .fmt = "token pasting of ',' and __VA_ARGS__ is a GNU extension",
    .kind = .off,
    .opt = .@"gnu-zero-variadic-macro-arguments",
    .extension = true,
};

pub const expansion_to_defined_obj: Diagnostic = .{
    .fmt = "macro expansion producing 'defined' has undefined behavior",
    .kind = .off,
    .opt = .@"expansion-to-defined",
};

pub const expansion_to_defined_func: Diagnostic = .{
    .fmt = expansion_to_defined_obj.fmt,
    .kind = .off,
    .opt = .@"expansion-to-defined",
    .extension = true,
};

pub const invalid_pp_stringify_escape: Diagnostic = .{
    .fmt = "invalid string literal, ignoring final '\\'",
    .kind = .warning,
};

pub const gnu_va_macro: Diagnostic = .{
    .fmt = "named variadic macros are a GNU extension",
    .opt = .@"variadic-macros",
    .kind = .off,
    .extension = true,
};

pub const pragma_operator_string_literal: Diagnostic = .{
    .fmt = "_Pragma requires exactly one string literal token",
    .kind = .@"error",
};

pub const invalid_preproc_expr_start: Diagnostic = .{
    .fmt = "invalid token at start of a preprocessor expression",
    .kind = .@"error",
};

pub const newline_eof: Diagnostic = .{
    .fmt = "no newline at end of file",
    .opt = .@"newline-eof",
    .kind = .off,
    .extension = true,
};

pub const malformed_warning_check: Diagnostic = .{
    .fmt = "{s} expected option name (e.g. \"-Wundef\")",
    .opt = .@"malformed-warning-check",
    .kind = .warning,
    .extension = true,
};

pub const feature_check_requires_identifier: Diagnostic = .{
    .fmt = "builtin feature check macro requires a parenthesized identifier",
    .kind = .@"error",
};

pub const builtin_macro_redefined: Diagnostic = .{
    .fmt = "redefining builtin macro",
    .opt = .@"builtin-macro-redefined",
    .kind = .warning,
    .extension = true,
};

pub const macro_redefined: Diagnostic = .{
    .fmt = "'{s}' macro redefined",
    .opt = .@"macro-redefined",
    .kind = .warning,
    .extension = true,
};

pub const previous_definition: Diagnostic = .{
    .fmt = "previous definition is here",
    .kind = .note,
};

pub const unterminated_macro_arg_list: Diagnostic = .{
    .fmt = "unterminated function macro argument list",
    .kind = .@"error",
};

pub const to_match_paren: Diagnostic = .{
    .fmt = "to match this '('",
    .kind = .note,
};

pub const closing_paren: Diagnostic = .{
    .fmt = "expected closing ')'",
    .kind = .@"error",
};

pub const poisoned_identifier: Diagnostic = .{
    .fmt = "attempt to use a poisoned identifier",
    .kind = .@"error",
};

pub const expected_arguments: Diagnostic = .{
    .fmt = "expected {d} argument(s) got {d}",
    .kind = .@"error",
};

pub const expected_at_least_arguments: Diagnostic = .{
    .fmt = "expected at least {d} argument(s) got {d}",
    .kind = .warning,
};

pub const invalid_preproc_operator: Diagnostic = .{
    .fmt = "token is not a valid binary operator in a preprocessor subexpression",
    .kind = .@"error",
};

pub const expected_str_literal_in: Diagnostic = .{
    .fmt = "expected string literal in '{s}'",
    .kind = .@"error",
};

pub const builtin_missing_r_paren: Diagnostic = .{
    .fmt = "missing ')', after {s}",
    .kind = .@"error",
};

pub const cannot_convert_to_identifier: Diagnostic = .{
    .fmt = "cannot convert {s} to an identifier",
    .kind = .@"error",
};

pub const expected_identifier: Diagnostic = .{
    .fmt = "expected identifier argument",
    .kind = .@"error",
};

pub const incomplete_ucn: Diagnostic = .{
    .fmt = "incomplete universal character name; treating as '\\' followed by identifier",
    .kind = .warning,
    .opt = .unicode,
};

pub const invalid_source_epoch: Diagnostic = .{
    .fmt = "environment variable SOURCE_DATE_EPOCH must expand to a non-negative integer less than or equal to 253402300799",
    .kind = .@"error",
};

pub const date_time: Diagnostic = .{
    .fmt = "expansion of date or time macro is not reproducible",
    .kind = .off,
    .opt = .@"date-time",
    .show_in_system_headers = true,
};

pub const no_argument_variadic_macro: Diagnostic = .{
    .fmt = "passing no argument for the '...' parameter of a variadic macro is incompatible with C standards before C23",
    .opt = .@"variadic-macro-arguments-omitted",
    .kind = .off,
    .extension = true,
};
