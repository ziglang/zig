export fn entry() void {
    blah: while (true) {
        while (true) {
            break :outer;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:20: error: label not found: 'outer'
