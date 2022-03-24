export fn foo() void {
    while (true) {
        defer {
            continue;
        }
    }
}

// cannot continue out of defer expression
//
// tmp.zig:4:13: error: cannot continue out of defer expression
