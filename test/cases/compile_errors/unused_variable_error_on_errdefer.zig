fn foo() !void {
    errdefer |a| unreachable;
    return error.A;
}
export fn entry() void {
    foo() catch unreachable;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: unused capture
