export fn f() void {
    _ = @as(u32, @splat(5));
}

// error
//
// :2:18: error: expected array or vector type, found 'u32'
