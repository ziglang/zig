export fn f() void {
    if (0) {}
}

// if condition is bool, not int
//
// tmp.zig:2:9: error: expected type 'bool', found 'comptime_int'
