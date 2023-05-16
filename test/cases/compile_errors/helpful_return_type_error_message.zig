export fn foo() u32 {
    return error.Ohno;
}
fn bar() !u32 {
    return error.Ohno;
}
export fn baz() void {
    try bar();
}
export fn qux() u32 {
    return bar();
}
export fn quux() u32 {
    var buf: u32 = 0;
    buf = bar();
}

// error
// backend=stage2
// target=native
//
// :2:18: error: expected type 'u32', found 'error{Ohno}'
// :1:17: note: function cannot return an error
// :8:5: error: expected type 'void', found '@typeInfo(@typeInfo(@TypeOf(tmp.bar)).Fn.return_type.?).ErrorUnion.error_set'
// :7:17: note: function cannot return an error
// :11:15: error: expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(tmp.bar)).Fn.return_type.?).ErrorUnion.error_set!u32'
// :11:15: note: cannot convert error union to payload type
// :11:15: note: consider using 'try', 'catch', or 'if'
// :10:17: note: function cannot return an error
// :15:14: error: expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(tmp.bar)).Fn.return_type.?).ErrorUnion.error_set!u32'
// :15:14: note: cannot convert error union to payload type
// :15:14: note: consider using 'try', 'catch', or 'if'
