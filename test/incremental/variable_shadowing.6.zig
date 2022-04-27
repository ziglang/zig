pub fn main() void {
    var i = 0;
    while ("n") |bruh| {
        _ = bruh;
    } else |i| {

    }
}

// error
//
// :5:13: error: redeclaration of local variable 'i'
// :2:9: note: previous declaration here
