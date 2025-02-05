export fn foo(num: anytype) i32 {
    _ = num;
    return 0;
}

// error
// target=x86_64-linux
//
// :1:15: error: generic parameters not allowed in function with calling convention 'x86_64_sysv'
