fn f(a : i32, a : i32) void {
}
export fn entry() void { f(1, 2); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:15: error: redeclaration of function parameter 'a'
// tmp.zig:1:6: note: previous declaration here
