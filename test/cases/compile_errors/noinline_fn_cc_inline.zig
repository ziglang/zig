noinline fn foo() callconv(.@"inline") void {}

comptime {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :1:29: error: 'noinline' function cannot have calling convention 'inline'
