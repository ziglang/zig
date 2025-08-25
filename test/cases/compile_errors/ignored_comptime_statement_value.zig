export fn foo() void {
    comptime {
        1;
    }
}

// error
// backend=stage2
// target=native
//
// :3:9: error: value of type 'comptime_int' ignored
// :3:9: note: all non-void values must be used
// :3:9: note: to discard the value, assign it to '_'
