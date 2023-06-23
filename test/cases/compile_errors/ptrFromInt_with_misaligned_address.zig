pub export fn entry() void {
    var y = @ptrFromInt([*]align(4) u8, 5);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :2:41: error: pointer type '[*]align(4) u8' requires aligned address
