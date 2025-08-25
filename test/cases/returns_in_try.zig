pub fn main() !void {
    try a();
    try b();
}

pub fn a() !void {
    defer try b();
}
pub fn b() !void {
    defer return a();
}

// error
//
// :7:11: error: 'try' not allowed inside defer expression
// :7:5: note: defer expression here
// :10:11: error: cannot return from defer expression
// :10:5: note: defer expression here
