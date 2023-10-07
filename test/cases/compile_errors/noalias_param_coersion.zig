pub export fn entry() void {
    comptime var x: fn (noalias *i32, noalias *i32) void = undefined;
    x = bar;
}
pub export fn entry1() void {
    comptime var x: fn (*i32, *i32) void = undefined;
    x = foo;
}

fn foo(noalias _: *i32, noalias _: *i32) void {}
fn bar(noalias _: *i32, _: *i32) void {}

// error
// backend=stage2
// target=native
//
// :3:9: error: expected type 'fn (noalias *i32, noalias *i32) void', found 'fn (noalias *i32, *i32) void'
// :3:9: note: regular parameter 1 cannot cast into a noalias parameter
// :7:9: error: expected type 'fn (*i32, *i32) void', found 'fn (noalias *i32, noalias *i32) void'
// :7:9: note: noalias parameter 0 cannot cast into a regular parameter
