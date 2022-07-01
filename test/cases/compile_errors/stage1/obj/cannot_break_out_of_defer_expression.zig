export fn foo() void {
    while (true) {
        defer {
            break;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:13: error: cannot break out of defer expression
