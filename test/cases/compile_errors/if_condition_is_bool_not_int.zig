export fn f() void {
    if (0) {}
}

// error
// backend=stage2
// target=native
//
// :2:9: error: expected type 'bool', found 'comptime_int'
