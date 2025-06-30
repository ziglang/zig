export fn example() void {
    comptime foo() catch |err| switch (err) {};
}
var x: ?error{} = null;
fn foo() !void {
    return x.?;
}
// error
// backend=stage2
// target=native
//
// :6:13: error: unable to unwrap null
// :2:17: note: called at comptime here
