const Foo = @Type(.{
    .Fn = .{
        .calling_convention = .Unspecified,
        .alignment = 0,
        .is_generic = true,
        .is_var_args = false,
        .return_type = u0,
        .args = &.{},
    },
});
comptime { _ = Foo; }

// @Type(.Fn) with is_generic = true
//
// tmp.zig:1:20: error: Type.Fn.is_generic must be false for @Type
