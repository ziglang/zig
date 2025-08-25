fn A(comptime T: type) type {
    return struct { a: T };
}
fn B(comptime T: type) type {
    return struct { b: T };
}
fn foo() A(u32) {
    return B(u32){ .b = 1 };
}
export fn entry() void {
    _ = foo();
}

// error
// backend=stage2
// target=native
//
// :8:18: error: expected type 'tmp.A(u32)', found 'tmp.B(u32)'
// :5:12: note: struct declared here
// :2:12: note: struct declared here
// :7:11: note: function return type declared here
