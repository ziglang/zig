export fn foo() void {
    defer {
        1;
    }
}

// error
// backend=stage2
// target=native
//
// :3:9: error: value of type 'comptime_int' ignored
// :3:9: note: all non-void values must be used
// :3:9: note: this error can be suppressed by assigning the value to '_'
