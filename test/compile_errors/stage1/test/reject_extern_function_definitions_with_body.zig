extern "c" fn definitelyNotInLibC(a: i32, b: i32) i32 {
    return a + b;
}

// reject extern function definitions with body
//
// tmp.zig:1:1: error: extern functions have no body
