const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = false,
        .is_var_args = true,
        .return_type = u0,
        .params = &.{},
    },
});
comptime { _ = Foo; }

// error
// backend=stage2
// target=native
//
// :1:13: error: varargs functions must have C calling convention
