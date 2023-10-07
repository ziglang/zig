pub fn main() void {
    _ = @as(*u8, @ptrFromInt(0));
}

// error
// output_mode=Exe
//
// :2:18: error: pointer type '*u8' does not allow address zero
