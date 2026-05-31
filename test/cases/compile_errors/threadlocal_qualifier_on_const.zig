threadlocal const x: i32 = 1234;
export fn entry() i32 {
    return x;
}

// error
//
// :1:1: error: threadlocal variable cannot be constant
