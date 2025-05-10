const Foo = @Type(.{
    .@"fn" = .{
        .calling_convention = .auto,
        .is_generic = false,
        .is_var_args = false,
        .return_type = null,
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
// :1:13: error: Type.Fn.return_type must be non-null for @Type
