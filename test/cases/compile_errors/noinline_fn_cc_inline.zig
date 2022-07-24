const cc = .Inline;
noinline fn foo() callconv(cc) void {}

comptime {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:28: error: 'noinline' function cannot have callconv 'Inline'
