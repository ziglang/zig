fn assert(ok: bool) void {
    if (!ok) unreachable;
}
fn rem(lhs: i32, rhs: i32, expected: i32) bool {
    return @rem(lhs, rhs) == expected;
}
pub fn main() void {
    assert(rem(-5, 3, -2));
    assert(rem(5, 3, 2));
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
