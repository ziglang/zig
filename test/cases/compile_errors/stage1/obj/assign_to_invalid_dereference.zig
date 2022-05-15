export fn entry() void {
    'a'.* = 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:8: error: attempt to dereference non-pointer type 'comptime_int'
