extern var foo;
pub export fn entry() void {
    foo;
}

// error
//
// :1:8: error: unable to infer variable type
