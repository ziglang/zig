noinline fn foo() callconv(.@"inline") void {}

comptime {
    _ = foo;
}

// error
//
// :1:29: error: 'noinline' function cannot have calling convention 'inline'
