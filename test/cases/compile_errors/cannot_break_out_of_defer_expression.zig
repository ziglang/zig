export fn foo() void {
    while (true) {
        defer {
            break;
        }
    }
}

// error
// backend=stage2
// target=native
//
// :4:13: error: cannot break out of defer expression
// :3:9: note: defer expression here
