const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = false,
        .is_var_args = false,
        .return_type = null,
        .args = &.{},
    },
});
comptime { _ = Foo; }

// @Type(.Fn) with return_type = null
//
// tmp.zig:1:20: error: Type.Fn.return_type must be non-null for @Type
