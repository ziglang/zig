export fn foo(num: anytype) i32 {
    _ = num;
    return 0;
}

// export generic function
//
// tmp.zig:1:15: error: parameter of type 'anytype' not allowed in function with calling convention 'C'
