export fn foo() void {
    while (true) {
        defer {
            break;
        }
    }
}

// cannot break out of defer expression
//
// tmp.zig:4:13: error: cannot break out of defer expression
