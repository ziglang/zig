export fn entry() void {
    const x = 'a'.*[0..];
    _ = x;
}

// error
//
// :2:18: error: cannot dereference non-pointer type 'comptime_int'
