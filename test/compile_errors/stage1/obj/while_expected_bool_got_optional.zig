export fn foo() void {
    while (bar()) {}
}
fn bar() ?i32 { return 1; }

// while expected bool, got optional
//
// tmp.zig:2:15: error: expected type 'bool', found '?i32'
