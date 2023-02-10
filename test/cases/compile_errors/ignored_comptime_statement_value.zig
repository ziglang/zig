export fn foo() void {
    comptime {1;}
}

// error
// backend=stage2
// target=native
//
// :2:15: error: value of type 'comptime_int' ignored
// :2:15: note: all non-void values must be used
// :2:15: note: this error can be suppressed by assigning the value to '_'
