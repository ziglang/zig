extern var foo;
pub export fn entry() void {
    foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:8: error: unable to infer variable type
