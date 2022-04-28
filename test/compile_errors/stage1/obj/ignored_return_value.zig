export fn foo() void {
    bar();
}
fn bar() i32 { return 0; }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:8: error: expression value is ignored
