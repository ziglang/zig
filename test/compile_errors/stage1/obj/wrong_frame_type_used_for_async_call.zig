export fn entry() void {
    var frame: @Frame(foo) = undefined;
    frame = async bar();
}
fn foo() void {
    suspend {}
}
fn bar() void {
    suspend {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:13: error: expected type '*@Frame(bar)', found '*@Frame(foo)'
