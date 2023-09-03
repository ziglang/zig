comptime {
    _ = @mulAdd(@Vector(1, u32), .{0}, .{0}, .{0});
}

// error
// backend=stage2
// target=native
//
// :2:9: error: expected vector of floats or float type, found '@Vector(1, u32)'
