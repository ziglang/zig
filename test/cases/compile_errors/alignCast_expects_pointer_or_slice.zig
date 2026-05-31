export fn entry() void {
    const x: *align(8) u32 = @alignCast(@as(u32, 3));
    _ = x;
}

// error
//
// :2:41: error: expected pointer type, found 'u32'
