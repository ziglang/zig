pub fn main() void {
    _ = @ptrFromInt(*u8, 0);
}

// error
// output_mode=Exe
//
// :2:24: error: pointer type '*u8' does not allow address zero
