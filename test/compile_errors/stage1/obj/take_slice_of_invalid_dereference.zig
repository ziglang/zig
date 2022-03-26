export fn entry() void {
    const x = 'a'.*[0..];
    _ = x;
}

// take slice of invalid dereference
//
// tmp.zig:2:18: error: attempt to dereference non-pointer type 'comptime_int'
