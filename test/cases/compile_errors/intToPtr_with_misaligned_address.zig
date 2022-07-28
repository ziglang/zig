pub export fn entry() void {
    var y = @intToPtr([*]align(4) u8, 5);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:39: error: pointer type '[*]align(4) u8' requires aligned address
