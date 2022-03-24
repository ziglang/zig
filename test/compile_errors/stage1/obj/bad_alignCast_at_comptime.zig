comptime {
    const ptr = @intToPtr(*align(1) i32, 0x1);
    const aligned = @alignCast(4, ptr);
    _ = aligned;
}

// bad @alignCast at comptime
//
// tmp.zig:3:35: error: pointer address 0x1 is not aligned to 4 bytes
