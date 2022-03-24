const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = false,
        .is_var_args = true,
        .return_type = u0,
        .args = &.{},
    },
});
comptime { _ = Foo; }

// @Type(.Fn) with is_var_args = true and non-C callconv
//
// tmp.zig:1:20: error: varargs functions must have C calling convention
