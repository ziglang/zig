export fn entry() void {
    const x = 1 << &@as(u8, 10);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:20: error: expected type 'comptime_int', found '*const u8'
