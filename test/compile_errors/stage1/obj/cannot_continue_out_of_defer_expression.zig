export fn foo() void {
    while (true) {
        defer {
            continue;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:13: error: cannot continue out of defer expression
