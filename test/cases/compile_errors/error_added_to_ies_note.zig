fn foo() !void {
    return error.Bar;
}
fn bar() !void {
    try foo();
}
pub export fn entry() void {
    bar() catch |e| switch (e) {
        // error.Bar => {},
    };
}

// error
// backend=stage2
// target=native
//
// :8:21: error: switch must handle all possibilities
// :8:21: note: unhandled error value: 'error.Bar'
// :5:5: note: error added to inferred error set here
