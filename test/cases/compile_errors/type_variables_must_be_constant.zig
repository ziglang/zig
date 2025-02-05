var foo = u8;
export fn entry() foo {
    return 1;
}

// error
// backend=stage2
// target=native
//
// :1:11: error: variable of type 'type' must be const or comptime
// :1:11: note: types are not available at runtime
