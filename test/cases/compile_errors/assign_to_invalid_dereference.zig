export fn entry() void {
    'a'.* = 1;
}

// error
// backend=stage2
// target=native
//
// :2:8: error: cannot dereference non-pointer type 'comptime_int'
