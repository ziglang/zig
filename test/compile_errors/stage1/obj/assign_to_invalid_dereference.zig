export fn entry() void {
    'a'.* = 1;
}

// assign to invalid dereference
//
// tmp.zig:2:8: error: attempt to dereference non-pointer type 'comptime_int'
