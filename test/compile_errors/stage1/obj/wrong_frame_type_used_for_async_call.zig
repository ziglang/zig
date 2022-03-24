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

// wrong frame type used for async call
//
// tmp.zig:3:13: error: expected type '*@Frame(bar)', found '*@Frame(foo)'
