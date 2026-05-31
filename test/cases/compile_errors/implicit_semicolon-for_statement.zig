export fn entry() void {
    for(foo()) |_| {}
    var good = {};
    for(foo()) |_| ({})
    var bad = {};
    _ = good;
    _ = bad;
}
fn foo() void {}

// error
//
// :4:24: error: expected ';' or 'else' after statement
