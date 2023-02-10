pub fn main() void {
    var i: u32 = 10;
    var i: u32 = 10;
}

// error
// backend=stage2
// target=x86_64-linux,x86_64-macos
//
// :3:9: error: redeclaration of local variable 'i'
// :2:9: note: previous declaration here
