extern var foo;
pub export fn entry() void {
    foo;
}

// extern variable has no type
//
// tmp.zig:1:8: error: unable to infer variable type
