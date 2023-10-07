export fn f() void {
    _ = @as(u32, @splat(5));
}

// error
// backend=stage2
// target=native
//
// :2:18: error: expected vector type, found 'u32'
