export fn entry() void {
    testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
}
fn testImplicitlyDecreaseFnAlign(ptr: fn () align(8) i32, answer: i32) void {
    if (ptr() != answer) unreachable;
}
fn alignedSmall() align(4) i32 { return 1234; }

// passing an under-aligned function pointer
//
// tmp.zig:2:35: error: expected type 'fn() align(8) i32', found 'fn() align(4) i32'
