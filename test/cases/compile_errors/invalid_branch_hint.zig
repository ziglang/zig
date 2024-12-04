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

export fn baz() void {
    if (true) {
        @branchHint(.none);
        @branchHint(.none);
    }
}

// error
//
// :2:5: error: '@branchHint' outside function scope
// :7:5: error: '@branchHint' outside function scope
// :11:5: error: '@branchHint' must appear before non-hint statements in a function or conditional branch
// :16:9: error: '@branchHint' must appear before non-hint statements in a function or conditional branch
// :22:9: error: '@branchHint' must appear before non-hint statements in a function or conditional branch
// :29:9: error: '@branchHint' must appear before non-hint statements in a function or conditional branch
// :37:9: error: duplicate '@branchHint' call; only one is allowed per function or conditional branch
