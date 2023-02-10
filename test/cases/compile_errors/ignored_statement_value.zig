export fn foo() void {
    1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: value of type 'comptime_int' ignored
// :2:5: note: all non-void values must be used
// :2:5: note: this error can be suppressed by assigning the value to '_'
