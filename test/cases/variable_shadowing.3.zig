pub fn main() void {
    var i = 0;
    for ("n", 0..) |_, i| {}
}

// error
//
// :3:24: error: capture 'i' shadows local variable from outer scope
// :2:9: note: previous declaration here
