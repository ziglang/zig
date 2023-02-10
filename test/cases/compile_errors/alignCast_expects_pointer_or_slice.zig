export fn entry() void {
    @alignCast(4, @as(u32, 3));
}

// error
// backend=stage2
// target=native
//
// :2:19: error: expected pointer type, found 'u32'
