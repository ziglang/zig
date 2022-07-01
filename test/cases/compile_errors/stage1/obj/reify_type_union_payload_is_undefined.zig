const Foo = @Type(.{
    .Struct = undefined,
});
comptime { _ = Foo; }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:20: error: use of undefined value here causes undefined behavior
