pub fn main() void {
    _ = @as(*u32, @ptrFromInt(2));
}

// error
//
// :2:19: error: pointer type '*u32' requires aligned address
