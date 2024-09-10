export fn a() void {
    _ = @as(f32, 1.0) +| @as(f32, 1.0);
}

// error
// backend=stage2
// target=native
//
// :2:23: error: invalid operands to binary expression: 'float' and 'float'
