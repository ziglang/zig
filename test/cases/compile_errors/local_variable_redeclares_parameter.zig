fn f(a : i32) void {
    const a = 0;
}
export fn entry() void { f(1); }

// error
// backend=stage2
// target=native
//
// :2:11: error: redeclaration of function parameter 'a'
// :1:6: note: previous declaration here
