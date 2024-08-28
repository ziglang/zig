const Foo = @Type(.{
    .@"fn" = .{
        .calling_convention = .Unspecified,
        .is_generic = true,
        .is_var_args = false,
        .return_type = u0,
        .params = &.{},
    },
});
comptime {
    _ = Foo;
}

// error
// backend=stage2
// target=native
//
// :1:13: error: Type.Fn.is_generic must be false for @Type
