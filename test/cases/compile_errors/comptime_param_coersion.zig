pub export fn entry() void {
    comptime var x: fn (comptime i32, comptime i32) void = undefined;
    x = bar;
}
pub export fn entry1() void {
    comptime var x: fn (i32, i32) void = undefined;
    x = foo;
}

fn foo(comptime _: i32, comptime _: i32) void {}
fn bar(comptime _: i32, _: i32) void {}

// error
// backend=stage2
// target=native
//
// :3:9: error: expected type 'fn (comptime i32, comptime i32) void', found 'fn (comptime i32, i32) void'
// :3:9: note: non-comptime parameter 1 cannot cast into a comptime parameter
// :7:9: error: expected type 'fn (i32, i32) void', found 'fn (comptime i32, comptime i32) void'
// :7:9: note: generic function cannot cast into a non-generic function
