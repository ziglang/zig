fn foo(args: ...) void {}
export fn entry() void {
    foo();
}

// error
// backend=stage2
// target=native
//
// :1:14: error: expected type expression, found '...'
