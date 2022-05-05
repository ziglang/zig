export fn f() void {
    if (0) {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: expected type 'bool', found 'comptime_int'
