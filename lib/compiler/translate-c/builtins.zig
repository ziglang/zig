const std = @import("std");

const ast = @import("ast.zig");

/// All builtins need to have a source so that macros can reference them
/// but for some it is possible to directly call an equivalent Zig builtin
/// which is preferrable.
pub const Builtin = struct {
    /// The name of the builtin in `c_builtins.zig`.
    name: []const u8,
    tag: ?ast.Node.Tag = null,
};

pub const map = std.StaticStringMap(Builtin).initComptime([_]struct { []const u8, Builtin }{
    .{ "__builtin_abs", .{ .name = "abs" } },
    .{ "__builtin_assume", .{ .name = "assume" } },
    .{ "__builtin_bswap16", .{ .name = "bswap16", .tag = .byte_swap } },
    .{ "__builtin_bswap32", .{ .name = "bswap32", .tag = .byte_swap } },
    .{ "__builtin_bswap64", .{ .name = "bswap64", .tag = .byte_swap } },
    .{ "__builtin_ceilf", .{ .name = "ceilf", .tag = .ceil } },
    .{ "__builtin_ceil", .{ .name = "ceil", .tag = .ceil } },
    .{ "__builtin_clz", .{ .name = "clz" } },
    .{ "__builtin_constant_p", .{ .name = "constant_p" } },
    .{ "__builtin_cosf", .{ .name = "cosf", .tag = .cos } },
    .{ "__builtin_cos", .{ .name = "cos", .tag = .cos } },
    .{ "__builtin_ctz", .{ .name = "ctz" } },
    .{ "__builtin_exp2f", .{ .name = "exp2f", .tag = .exp2 } },
    .{ "__builtin_exp2", .{ .name = "exp2", .tag = .exp2 } },
    .{ "__builtin_expf", .{ .name = "expf", .tag = .exp } },
    .{ "__builtin_exp", .{ .name = "exp", .tag = .exp } },
    .{ "__builtin_expect", .{ .name = "expect" } },
    .{ "__builtin_fabsf", .{ .name = "fabsf", .tag = .abs } },
    .{ "__builtin_fabs", .{ .name = "fabs", .tag = .abs } },
    .{ "__builtin_floorf", .{ .name = "floorf", .tag = .floor } },
    .{ "__builtin_floor", .{ .name = "floor", .tag = .floor } },
    .{ "__builtin_huge_valf", .{ .name = "huge_valf" } },
    .{ "__builtin_inff", .{ .name = "inff" } },
    .{ "__builtin_isinf_sign", .{ .name = "isinf_sign" } },
    .{ "__builtin_isinf", .{ .name = "isinf" } },
    .{ "__builtin_isnan", .{ .name = "isnan" } },
    .{ "__builtin_labs", .{ .name = "labs" } },
    .{ "__builtin_llabs", .{ .name = "llabs" } },
    .{ "__builtin_log10f", .{ .name = "log10f", .tag = .log10 } },
    .{ "__builtin_log10", .{ .name = "log10", .tag = .log10 } },
    .{ "__builtin_log2f", .{ .name = "log2f", .tag = .log2 } },
    .{ "__builtin_log2", .{ .name = "log2", .tag = .log2 } },
    .{ "__builtin_logf", .{ .name = "logf", .tag = .log } },
    .{ "__builtin_log", .{ .name = "log", .tag = .log } },
    .{ "__builtin___memcpy_chk", .{ .name = "memcpy_chk" } },
    .{ "__builtin_memcpy", .{ .name = "memcpy" } },
    .{ "__builtin___memset_chk", .{ .name = "memset_chk" } },
    .{ "__builtin_memset", .{ .name = "memset" } },
    .{ "__builtin_mul_overflow", .{ .name = "mul_overflow" } },
    .{ "__builtin_nanf", .{ .name = "nanf" } },
    .{ "__builtin_object_size", .{ .name = "object_size" } },
    .{ "__builtin_popcount", .{ .name = "popcount" } },
    .{ "__builtin_roundf", .{ .name = "roundf", .tag = .round } },
    .{ "__builtin_round", .{ .name = "round", .tag = .round } },
    .{ "__builtin_signbitf", .{ .name = "signbitf" } },
    .{ "__builtin_signbit", .{ .name = "signbit" } },
    .{ "__builtin_sinf", .{ .name = "sinf", .tag = .sin } },
    .{ "__builtin_sin", .{ .name = "sin", .tag = .sin } },
    .{ "__builtin_sqrtf", .{ .name = "sqrtf", .tag = .sqrt } },
    .{ "__builtin_sqrt", .{ .name = "sqrt", .tag = .sqrt } },
    .{ "__builtin_strcmp", .{ .name = "strcmp" } },
    .{ "__builtin_strlen", .{ .name = "strlen" } },
    .{ "__builtin_truncf", .{ .name = "truncf", .tag = .trunc } },
    .{ "__builtin_trunc", .{ .name = "trunc", .tag = .trunc } },
    .{ "__builtin_unreachable", .{ .name = "unreachable", .tag = .@"unreachable" } },
    .{ "__has_builtin", .{ .name = "has_builtin" } },

    // __builtin_alloca_with_align is not currently implemented.
    // It is used in a run and a translate test to ensure that non-implemented
    // builtins are correctly demoted. If you implement __builtin_alloca_with_align,
    // please update the tests to use a different non-implemented builtin.
});
