export fn foo() void {
    @setFloatMode(@import("std").builtin.FloatMode.Optimized);
    @setFloatMode(@import("std").builtin.FloatMode.Optimized);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: float mode set twice for same scope
// tmp.zig:2:5: note: first set here
