export fn entry() void {
    foo() catch unreachable;
}
fn foo() !void {
    try foo();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:5: error: cannot resolve inferred error set '@typeInfo(@typeInfo(@TypeOf(foo)).Fn.return_type.?).ErrorUnion.error_set': function 'foo' not fully analyzed yet
