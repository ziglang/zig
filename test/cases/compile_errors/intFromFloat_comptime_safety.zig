comptime {
    _ = @as(i8, @intFromFloat(@as(f32, -129.1)));
}
comptime {
    _ = @as(u8, @intFromFloat(@as(f32, -1.1)));
}
comptime {
    _ = @as(u8, @intFromFloat(@as(f32, 256.1)));
}

// error
// backend=stage2
// target=native
//
// :2:31: error: float value '-129.10000610351562' cannot be stored in integer type 'i8'
// :5:31: error: float value '-1.100000023841858' cannot be stored in integer type 'u8'
// :8:31: error: float value '256.1000061035156' cannot be stored in integer type 'u8'
