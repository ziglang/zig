var foo = u8;
export fn entry() foo {
    return 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: variable of type 'type' must be constant
