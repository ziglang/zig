pub fn S() type {
    return struct {};
}
pub export fn entry() void {
    _ = [0]S;
}

// error
// backend=stage2,llvm
//
// :4:1: error: expected type, found fn() type
