const Foo = @Type(.{
    .@"struct" = undefined,
});
comptime {
    _ = Foo;
}

// error
//
// :1:20: error: use of undefined value here causes illegal behavior
