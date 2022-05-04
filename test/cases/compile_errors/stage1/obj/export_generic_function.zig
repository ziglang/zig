export fn foo(num: anytype) i32 {
    _ = num;
    return 0;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:15: error: parameter of type 'anytype' not allowed in function with calling convention 'C'
