export fn foo() void {
    defer bar();
}
fn bar() anyerror!i32 { return 0; }

// ignored deferred function call
//
// tmp.zig:2:14: error: error is ignored. consider using `try`, `catch`, or `if`
