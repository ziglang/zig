const Foo = @Type(.{
    .Struct = undefined,
});
comptime { _ = Foo; }

// @Type() union payload is undefined
//
// tmp.zig:1:20: error: use of undefined value here causes undefined behavior
