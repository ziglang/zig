extern var foo;
pub export fn entry() void {
    foo;
}

// error
// backend=stage2
// target=native
//
// :1:8: error: unable to infer variable type
