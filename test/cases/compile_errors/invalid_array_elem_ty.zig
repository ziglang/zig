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
// :4:1: error: expected type, found fn() type
