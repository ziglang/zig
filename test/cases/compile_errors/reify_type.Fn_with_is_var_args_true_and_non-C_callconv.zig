const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .is_generic = false,
        .is_var_args = true,
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
// :1:13: error: variadic function does not support '.Unspecified' calling convention
// :1:13: note: supported calling conventions: '.C'
