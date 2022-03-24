fn f(a : i32) void {
    const a = 0;
}
export fn entry() void { f(1); }

// local variable redeclares parameter
//
// tmp.zig:2:11: error: redeclaration of function parameter 'a'
// tmp.zig:1:6: note: previous declaration here
