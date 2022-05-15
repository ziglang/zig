export fn entry() void {
    const x = 'a'.*[0..];
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:18: error: attempt to dereference non-pointer type 'comptime_int'
