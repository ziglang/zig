pub fn main() void {
    var i = 0;
    if (true) |_| {} else |i| {}
}

// error
//
// :3:28: error: redeclaration of local variable 'i'
// :2:9: note: previous declaration here
