pub fn main() void {
    _ = @ptrFromInt(*u32, 2);
}

// error
//
// :2:25: error: pointer type '*u32' requires aligned address
