export fn a() void {
    const x: ?u8 = 256;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// 2:20: error: expected type '?u8', found 'comptime_int'
// 2:20: note: type 'u8' cannot represent value '256'
