export fn foo() void {
    while (bar()) |x| {_ = x;}
}
fn bar() bool { return true; }

// while expected optional, got bool
//
// tmp.zig:2:15: error: expected optional type, found 'bool'
