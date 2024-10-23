const globl = g: {
    @branchHint(.none);
    break :g {};
};

comptime {
    @branchHint(.none);
}

test {
    @branchHint(.none);
}

export fn foo() void {
    {
        @branchHint(.none);
    }
}

export fn bar() void {
    _ = (b: {
        @branchHint(.none);
        break :b true;
    }) or true;
}

export fn qux() void {
    (b: {
        @branchHint(.none);
        break :b @as(?void, {});
    }) orelse unreachable;
}

// error
//
// :2:5: error: '@branchHint' outside function scope
// :7:5: error: '@branchHint' outside function scope
// :11:5: error: '@branchHint' must appear as the first statement in a function or conditional branch
// :16:9: error: '@branchHint' must appear as the first statement in a function or conditional branch
// :22:9: error: '@branchHint' must appear as the first statement in a function or conditional branch
// :29:9: error: '@branchHint' must appear as the first statement in a function or conditional branch
