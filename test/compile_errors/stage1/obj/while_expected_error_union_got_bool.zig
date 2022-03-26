export fn foo() void {
    while (bar()) |x| {_ = x;} else |err| {_ = err;}
}
fn bar() bool { return true; }

// while expected error union, got bool
//
// tmp.zig:2:15: error: expected error union type, found 'bool'
