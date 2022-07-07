export fn entry() void {
    foo();
}
fn foo() callconv(.Inline) void {
    @setAlignStack(16);
}

export fn entry1() void {
    comptime bar();
}
fn bar() void {
    @setAlignStack(16);
}


// error
// backend=stage2
// target=native
//
// :5:5: error: @setAlignStack in inline function
// :2:8: note: called from here
// :12:5: error: @setAlignStack in inline call
// :9:17: note: called from here
