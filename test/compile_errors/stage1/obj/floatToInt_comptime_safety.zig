comptime {
    _ = @floatToInt(i8, @as(f32, -129.1));
}
comptime {
    _ = @floatToInt(u8, @as(f32, -1.1));
}
comptime {
    _ = @floatToInt(u8, @as(f32, 256.1));
}

// @floatToInt comptime safety
//
// tmp.zig:2:9: error: integer value '-129' cannot be stored in type 'i8'
// tmp.zig:5:9: error: integer value '-1' cannot be stored in type 'u8'
// tmp.zig:8:9: error: integer value '256' cannot be stored in type 'u8'
