const Foo = @Type(.{
    .Struct = undefined,
});
comptime {
    _ = Foo;
}

// error
// backend=stage2
// target=native
//
// :1:20: error: use of undefined value here causes undefined behavior
