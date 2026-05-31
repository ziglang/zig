fn foo() !void {
    errdefer |a| unreachable;
    return error.A;
}
export fn entry() void {
    foo() catch unreachable;
}

// error
//
// :2:15: error: unused capture
