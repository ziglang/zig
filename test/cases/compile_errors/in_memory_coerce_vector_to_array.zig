export fn entry() void {
    _ = foo() catch {};
}
fn foo() anyerror![4]u32 {
    return bar();
}
fn bar() anyerror!@Vector(4, u32) {
    return .{ 1, 2, 3, 4 };
}
// error
//
// :5:15: error: expected type 'anyerror![4]u32', found 'anyerror!@Vector(4, u32)'
// :5:15: note: error union payload '@Vector(4, u32)' cannot cast into error union payload '[4]u32'
// :4:18: note: function return type declared here
