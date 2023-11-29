pub fn S() type {
    return struct {};
}
pub export fn entry() void {
    _ = [0]S;
}

// error
// target=native
// backend=stage2
//
// :5:12: error: expected type 'type', found 'fn () type'
