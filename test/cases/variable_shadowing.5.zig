pub fn main() void {
    var i = 0;
    while ("n") |i| {}
}

// error
//
// :3:18: error: capture 'i' shadows local variable from outer scope
// :2:9: note: previous declaration here
