fn f(a: i32) void {
    const a = 0;
}
export fn entry() void {
    f(1);
}

// error
// backend=stage2
// target=native
//
// :2:11: error: local constant 'a' shadows function parameter from outer scope
// :1:6: note: previous declaration here
