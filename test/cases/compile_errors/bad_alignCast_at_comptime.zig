comptime {
    const ptr: *align(1) i32 = @ptrFromInt(0x1);
    const aligned: *align(4) i32 = @alignCast(ptr);
    _ = aligned;
}

// error
// backend=stage2
// target=native
//
// :3:47: error: pointer address 0x1 is not aligned to 4 bytes
