export fn entry() void {
    _ = for(foo()) |_| {};
    var good = {};
    _ = for(foo()) |_| {}
    var bad = {};
    _ = good;
    _ = bad;
}
fn foo() void {}

// error
// backend=stage2
// target=native
//
// :4:26: error: expected ';' after statement
