var buf: [10]u8 align(16) = undefined;
export fn entry() void {
    @call(.{ .stack = &buf }, foo, .{});
}
fn foo() void {}

// error
// backend=stage1
// target=wasm32-wasi-none
//
// tmp.zig:3:5: error: target arch 'wasm32' does not support calling with a new stack
