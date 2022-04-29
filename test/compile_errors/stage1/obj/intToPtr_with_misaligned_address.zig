pub fn main() void {
    var y = @intToPtr([*]align(4) u8, 5);
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:13: error: pointer type '[*]align(4) u8' requires aligned address
