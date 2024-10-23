extern fn foo(comptime x: i32, y: i32) i32;
fn f() i32 {
    return foo(1, 2);
}
pub extern fn entry1(b: u32, comptime a: [2]u8, c: i32) void;
pub extern fn entry2(b: u32, noalias a: anytype, i43) void;
comptime {
    _ = &f;
}
comptime {
    _ = &entry1;
}
comptime {
    _ = &entry2;
}

// error
// backend=stage2
// target=native
//
// :1:15: error: comptime parameters not allowed in function with calling convention 'C'
// :5:30: error: comptime parameters not allowed in function with calling convention 'C'
// :6:30: error: generic parameters not allowed in function with calling convention 'C'
