var foo = u8;
export fn entry() foo {
    return 1;
}

// type variables must be constant
//
// tmp.zig:1:1: error: variable of type 'type' must be constant
