export fn foo() void {
    1;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: value of type 'comptime_int' ignored
// :2:5: note: all non-void values must be used
// :2:5: note: to discard the value, assign it to '_'
