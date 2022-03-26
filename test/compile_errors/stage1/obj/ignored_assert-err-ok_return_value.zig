export fn foo() void {
    bar() catch unreachable;
}
fn bar() anyerror!i32 { return 0; }

// ignored assert-err-ok return value
//
// tmp.zig:2:11: error: expression value is ignored
