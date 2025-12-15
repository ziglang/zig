const std = @import("std");

/// Header which must be included for a builtin to be available
pub const Header = enum {
    none,
    /// stdio.h
    stdio,
    /// stdlib.h
    stdlib,
    /// setjmpex.h
    setjmpex,
    /// stdarg.h
    stdarg,
    /// string.h
    string,
    /// ctype.h
    ctype,
    /// wchar.h
    wchar,
    /// setjmp.h
    setjmp,
    /// malloc.h
    malloc,
    /// strings.h
    strings,
    /// unistd.h
    unistd,
    /// pthread.h
    pthread,
    /// math.h
    math,
    /// complex.h
    complex,
    /// Blocks.h
    blocks,
    /// intrin.h
    intrin,
    /// immintrin.h
    immintrin,
    /// xmmintrin.h
    xmmintrin,
    /// emmintrin.h
    emmintrin,
    /// mmintrin.h
    mmintrin,
    /// arm_acle.h
    arm_acle,
};

/// Languages in which a builtin is available
pub const Language = enum {
    all_languages,
    all_ms_languages,
    all_gnu_languages,
    gnu_lang,
    c23_lang,
};

pub const Attributes = packed struct {
    /// Function does not return
    noreturn: bool = false,

    /// Function has no side effects
    pure: bool = false,

    /// Function has no side effects and does not read memory
    @"const": bool = false,

    /// Signature is meaningless; use custom typecheck
    custom_typecheck: bool = false,

    /// A declaration of this builtin should be recognized even if the type doesn't match the specified signature.
    allow_type_mismatch: bool = false,

    /// this is a libc/libm function with a '__builtin_' prefix added.
    lib_function_with_builtin_prefix: bool = false,

    /// this is a libc/libm function without a '__builtin_' prefix.  This builtin is disableable by '-fno-builtin-foo'
    lib_function_without_prefix: bool = false,

    /// Function returns twice (e.g. setjmp)
    returns_twice: bool = false,

    /// Nature of the format string passed to this function
    format_kind: enum(u3) {
        /// Does not take a format string
        none,
        /// this is a printf-like function whose Nth argument is the format string
        printf,
        /// function is like vprintf in that it accepts its arguments as a va_list rather than through an ellipsis
        vprintf,
        /// this is a scanf-like function whose Nth argument is the format string
        scanf,
        /// the function is like vscanf in that it accepts its arguments as a va_list rather than through an ellipsis
        vscanf,
    } = .none,

    /// Position of format string argument. Only meaningful if format_kind is not .none
    format_string_position: u5 = 0,

    /// if false, arguments are not evaluated
    eval_args: bool = true,

    /// no side effects and does not read memory, but only when -fno-math-errno and FP exceptions are ignored
    const_without_errno_and_fp_exceptions: bool = false,

    /// no side effects and does not read memory, but only when FP exceptions are ignored
    const_without_fp_exceptions: bool = false,

    /// this function can be constant evaluated by the frontend
    const_evaluable: bool = false,
};

pub fn isVarArgs(param_str: [*:0]const u8) bool {
    const slice = std.mem.sliceTo(param_str, 0);
    return slice[slice.len - 1] == '.';
}
