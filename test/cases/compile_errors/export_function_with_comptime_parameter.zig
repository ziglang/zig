export fn foo(comptime x: anytype, y: i32) i32 {
    return x + y;
}

// error
// backend=stage2
// target=native
//
// :1:15: error: comptime parameters not allowed in function with calling convention 'C'
