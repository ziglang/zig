export fn b() void {
    const x: anyerror!u8 = 256;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// 2:28: error: expected type 'anyerror!u8', found 'comptime_int'
// 2:28: note: type 'u8' cannot represent value '256'
