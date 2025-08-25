extern "c" fn definitelyNotInLibC(a: i32, b: i32) i32 {
    return a + b;
}

// error
// backend=stage2
// target=native
//
// :1:1: error: extern functions have no body
