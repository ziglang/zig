export fn foo() void {
    if (0) {}
}

export fn bar() void {
    comptime if (0) {};
}

// error
//
// :2:9: error: expected type 'bool', found 'comptime_int'
// :6:18: error: expected type 'bool', found 'comptime_int'
