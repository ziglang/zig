fn foo(args: ...) void {}
export fn entry() void {
    foo();
}

// error
//
// :1:14: error: expected type expression, found '...'
