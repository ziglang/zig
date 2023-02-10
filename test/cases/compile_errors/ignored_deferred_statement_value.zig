export fn foo() void {
    defer {1;}
}

// error
// backend=stage2
// target=native
//
// :2:12: error: value of type 'comptime_int' ignored
// :2:12: note: all non-void values must be used
// :2:12: note: this error can be suppressed by assigning the value to '_'
