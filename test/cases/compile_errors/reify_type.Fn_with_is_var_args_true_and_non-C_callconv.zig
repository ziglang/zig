const Foo = @Type(.{
    .@"fn" = .{
        .calling_convention = .auto,
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
// target=x86_64-linux
//
// :1:13: error: variadic function does not support 'auto' calling convention
// :1:13: note: supported calling conventions: 'x86_64_sysv', 'x86_64_win'
