export fn foo() void {
    @setRuntimeSafety(false);
    @setRuntimeSafety(false);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: runtime safety set twice for same scope
// tmp.zig:2:5: note: first set here
