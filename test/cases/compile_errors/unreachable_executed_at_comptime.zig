fn foo(comptime x: i32) i32 {
    comptime {
        if (x >= 0) return -x;
        unreachable;
    }
}
export fn entry() void {
    _ = comptime foo(-42);
}

// error
// backend=stage2
// target=native
//
// :4:9: error: reached unreachable code
// :8:21: note: called from here
