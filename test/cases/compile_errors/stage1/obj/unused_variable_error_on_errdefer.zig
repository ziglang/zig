fn foo() !void {
    errdefer |a| unreachable;
    return error.A;
}
export fn entry() void {
    foo() catch unreachable;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: unused variable: 'a'
