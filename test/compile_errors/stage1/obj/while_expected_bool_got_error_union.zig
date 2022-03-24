export fn foo() void {
    while (bar()) {}
}
fn bar() anyerror!i32 { return 1; }

// while expected bool, got error union
//
// tmp.zig:2:15: error: expected type 'bool', found 'anyerror!i32'
