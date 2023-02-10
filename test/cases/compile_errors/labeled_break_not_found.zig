export fn entry() void {
    blah: while (true) {
        while (true) {
            break :outer;
        }
    }
}

// error
// backend=stage2
// target=native
//
// :4:20: error: label not found: 'outer'
