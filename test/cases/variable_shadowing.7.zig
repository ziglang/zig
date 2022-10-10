pub fn main() void {
    var i = 0;
    if (true) |i| {}
}

// error
//
// :3:16: error: capture 'i' shadows local variable from outer scope
// :2:9: note: previous declaration here
