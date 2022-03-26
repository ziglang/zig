export fn entry() void {
    blah: while (true) {
        while (true) {
            break :outer;
        }
    }
}

// labeled break not found
//
// tmp.zig:4:20: error: label not found: 'outer'
