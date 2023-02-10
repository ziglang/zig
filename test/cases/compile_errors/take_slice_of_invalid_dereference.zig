export fn entry() void {
    const x = 'a'.*[0..];
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:18: error: cannot dereference non-pointer type 'comptime_int'
