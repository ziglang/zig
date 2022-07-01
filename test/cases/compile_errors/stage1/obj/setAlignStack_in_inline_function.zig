export fn entry() void {
    foo();
}
fn foo() callconv(.Inline) void {
    @setAlignStack(16);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:5: error: @setAlignStack in inline function
