export fn foo() void {
    bar();
}
fn bar() i32 { return 0; }

// ignored return value
//
// tmp.zig:2:8: error: expression value is ignored
