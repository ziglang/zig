pub fn foo() !void {
    try return bar();
}
pub fn bar() !void {}

// error
// backend=stage2
// target=native
//
// :2:5: error: unreachable code
// :2:9: note: control flow is diverted here
