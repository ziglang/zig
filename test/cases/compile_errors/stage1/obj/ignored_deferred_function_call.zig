export fn foo() void {
    defer bar();
}
fn bar() anyerror!i32 { return 0; }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:14: error: error is ignored. consider using `try`, `catch`, or `if`
