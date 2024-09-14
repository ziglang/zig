var end: usize = 1;
comptime {
    _ = @as(*[0:1]u8, undefined)[1..];
}
comptime {
    _ = @as([*]u8, undefined)[0..1];
}
comptime {
    _ = @as([*]u8, undefined)[0..end];
}
comptime {
    _ = @as([]u8, undefined)[0..end];
}
comptime {
    _ = @as(*[0]u8, undefined)[0..end :0];
}
comptime {
    _ = @as([]u8, &.{})[0..1];
}

// error
//
// :3:33: error: non-zero length slice of undefined pointer
// :6:30: error: non-zero length slice of undefined pointer
// :9:30: error: slice of undefined pointer with runtime length causes undefined behaviour
// :12:29: error: slice of undefined pointer with runtime length causes undefined behaviour
// :15:31: error: sentinel not allowed for slice of undefined pointer
// :18:28: error: slice end index out of bounds: end 1, length 0
