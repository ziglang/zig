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

// helpful return type error message
//
// tmp.zig:2:17: error: expected type 'u32', found 'error{Ohno}'
// tmp.zig:1:17: note: function cannot return an error
// tmp.zig:8:5: error: expected type 'void', found '@typeInfo(@typeInfo(@TypeOf(bar)).Fn.return_type.?).ErrorUnion.error_set'
// tmp.zig:7:17: note: function cannot return an error
// tmp.zig:11:15: error: cannot convert error union to payload type. consider using `try`, `catch`, or `if`. expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(bar)).Fn.return_type.?).ErrorUnion.error_set!u32'
// tmp.zig:10:17: note: function cannot return an error
// tmp.zig:15:14: error: cannot convert error union to payload type. consider using `try`, `catch`, or `if`. expected type 'u32', found '@typeInfo(@typeInfo(@TypeOf(bar)).Fn.return_type.?).ErrorUnion.error_set!u32'
// tmp.zig:14:5: note: cannot store an error in type 'u32'
