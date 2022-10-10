pub fn main() void {
    var i = 0;
    for ("n") |_, i| {
    }
}

// error
//
// :3:19: error: loop index capture 'i' shadows local variable from outer scope
// :2:9: note: previous declaration here
