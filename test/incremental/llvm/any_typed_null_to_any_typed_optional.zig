pub fn main() void {
    var a: ?*anyopaque = undefined;
    a = @as(?usize, null);
}

// error
// output_mode=Exe
// backend=stage2,llvm
// target=x86_64-linux
//
// :3:21: error: expected *anyopaque, found ?usize
