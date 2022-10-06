comptime {
    var ptr: [*]u8 = undefined;
    _ = ptr[0..];
}

// error
// backend=stage2
// target=native
//
// :3:12: error: slice of pointer must include end value
