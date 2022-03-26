fn foo(args: ...) void {}
export fn entry() void {
    foo();
}

// non-extern function with var args
//
// tmp.zig:1:14: error: expected type expression, found '...'
