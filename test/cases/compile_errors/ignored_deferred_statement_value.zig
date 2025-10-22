export fn foo() void {
    defer {
        1;
    }
}

// error
//
// :3:9: error: value of type 'comptime_int' ignored
// :3:9: note: all non-void values must be used
// :3:9: note: to discard the value, assign it to '_'
