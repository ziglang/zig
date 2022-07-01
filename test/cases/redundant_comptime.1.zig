pub fn main() void {
    comptime {
        var a: u32 = comptime 0;
    }
}

// error
//
// :3:22: error: redundant comptime keyword in already comptime scope
