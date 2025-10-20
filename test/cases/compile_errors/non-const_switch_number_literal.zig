export fn foo() void {
    const x = switch (bar()) {
        1, 2 => 1,
        3, 4 => 2,
        else => 3,
    };
    _ = x;
}
fn bar() i32 {
    return 2;
}

// error
//
// :2:15: error: value with comptime-only type 'comptime_int' depends on runtime control flow
// :2:26: note: runtime control flow here
