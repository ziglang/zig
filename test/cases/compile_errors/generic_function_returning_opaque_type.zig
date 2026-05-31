fn generic(comptime T: type) T {
    return undefined;
}
const MyOpaque = opaque {};
export fn foo() void {
    _ = generic(MyOpaque);
}
export fn bar() void {
    _ = generic(anyopaque);
}

// error
//
// :1:30: error: opaque return type 'tmp.MyOpaque' not allowed
// :4:18: note: opaque declared here
// :1:30: error: opaque return type 'anyopaque' not allowed
