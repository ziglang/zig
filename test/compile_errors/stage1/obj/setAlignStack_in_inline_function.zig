export fn entry() void {
    foo();
}
fn foo() callconv(.Inline) void {
    @setAlignStack(16);
}

// @setAlignStack in inline function
//
// tmp.zig:5:5: error: @setAlignStack in inline function
