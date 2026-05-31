pub export fn entry() void {
    var y: [*]align(4) u8 = @ptrFromInt(5);
    _ = &y;
}

// error
//
// :2:41: error: pointer type '[*]align(4) u8' requires aligned address
