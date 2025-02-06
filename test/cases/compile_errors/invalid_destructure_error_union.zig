pub export fn entry() void {
    const foo: anyerror!u32 = error.Failure;
    const bar, const baz = foo;
    _ = bar;
    _ = baz;
}

// error
// backend=stage2
// target=native
//
// :3:28: error: type 'anyerror!u32' cannot be destructured
// :3:26: note: result destructured here
