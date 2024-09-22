fn foo() !struct { u8, u8 } {
    return error.Failure;
}

pub export fn entry() void {
    const bar, const baz = foo();
    _ = bar;
    _ = baz;
}

// error
// backend=stage2
// target=native
//
// :6:31: error: type '@typeInfo(@typeInfo(@TypeOf(tmp.foo)).@"fn".return_type.?).error_union.error_set!tmp.foo__struct_1306' cannot be destructured
// :6:26: note: result destructured here
// :6:31: note: consider using 'try', 'catch', or 'if'
