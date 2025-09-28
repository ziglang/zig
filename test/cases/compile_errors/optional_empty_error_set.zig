export fn example() void {
    comptime foo() catch |err| switch (err) {};
}
var x: ?error{} = null;
fn foo() !void {
    return x.?;
}
// error
//
// :6:13: error: unable to unwrap null
// :2:17: note: called at comptime here
