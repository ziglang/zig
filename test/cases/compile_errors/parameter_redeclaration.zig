fn f(a: i32, a: i32) void {}
export fn entry() void {
    f(1, 2);
}

// error
//
// :1:14: error: redeclaration of function parameter 'a'
// :1:6: note: previous declaration here
