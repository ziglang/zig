export fn entry() void {
    'a'.* = 1;
}

// error
//
// :2:8: error: cannot dereference non-pointer type 'comptime_int'
