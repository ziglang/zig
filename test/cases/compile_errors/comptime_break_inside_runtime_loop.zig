export fn entry() void {
    while (true) {
        comptime break;
    }
}

// error
// backend=stage2
// target=native
//
// :3:18: error: cannot comptime break out of runtime loop
