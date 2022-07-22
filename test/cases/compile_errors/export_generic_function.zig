export fn foo(num: anytype) i32 {
    _ = num;
    return 0;
}

// error
// backend=stage2
// target=native
//
// :1:15: error: generic parameters not allowed in function with calling convention 'C'
