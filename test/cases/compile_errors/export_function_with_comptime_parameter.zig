export fn foo(comptime x: anytype, y: i32) i32 {
    return x + y;
}

// error
// target=x86_64-linux
//
// :1:15: error: comptime parameters not allowed in function with calling convention 'x86_64_sysv'
