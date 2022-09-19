export fn entry() u32 {
    var bytes: [4]u8 = [_]u8{0x01, 0x02, 0x03, 0x04};
    const ptr = @ptrCast(*u32, &bytes[0]);
    return ptr.*;
}

// error
// backend=stage2
// target=native
//
// :3:17: error: cast increases pointer alignment
// :3:32: note: '*u8' has alignment '1'
// :3:26: note: '*u32' has alignment '4'
