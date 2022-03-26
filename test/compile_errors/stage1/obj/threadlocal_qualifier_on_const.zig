threadlocal const x: i32 = 1234;
export fn entry() i32 {
    return x;
}

// threadlocal qualifier on const
//
// tmp.zig:1:1: error: threadlocal variable cannot be constant
