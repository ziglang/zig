export fn foo(comptime x: i32, y: i32) i32{
    return x + y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:15: error: comptime parameter not allowed in function with calling convention 'C'
