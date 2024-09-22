pub export fn entry() void {
    const Foo = struct { u8, u8 };
    const foo: anyerror!Foo = error.Failure;
    const bar, const baz = foo;
    _ = bar;
    _ = baz;
}

// error
// backend=stage2
// target=native
//
// :4:28: error: type 'anyerror!tmp.entry.Foo' cannot be destructured
// :4:26: note: result destructured here
// :4:28: note: consider using 'try', 'catch', or 'if'
