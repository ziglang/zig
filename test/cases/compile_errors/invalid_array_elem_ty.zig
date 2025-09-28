pub fn S() type {
    return struct {};
}
pub export fn entry() void {
    _ = [0]S;
}

// error
//
// :5:12: error: expected type 'type', found 'fn () type'
