threadlocal const x: i32 = 1234;
export fn entry() i32 {
    return x;
}

// error
// backend=stage2
// target=native
//
// :1:1: error: threadlocal variable cannot be constant
