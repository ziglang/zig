fn foo(args: ...) void {}
export fn entry() void {
    foo();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:14: error: expected type expression, found '...'
