export fn entry() void {
    testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
}
fn testImplicitlyDecreaseFnAlign(ptr: *const fn () align(8) i32, answer: i32) void {
    if (ptr() != answer) unreachable;
}
fn alignedSmall() align(4) i32 { return 1234; }

// error
// backend=stage2
// target=x86_64-linux
//
// :2:35: error: expected type '*const fn() align(8) i32', found '*const fn() align(4) i32'
// :2:35: note: pointer alignment '4' cannot cast into pointer alignment '8'
