fn foo() !void {
    errdefer |a| unreachable;
    return error.A;
}
export fn entry() void {
    foo() catch unreachable;
}

// unused variable error on errdefer
//
// tmp.zig:2:15: error: unused variable: 'a'
