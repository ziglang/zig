export fn entry() void {
    blah: while (true) {
        while (true) {
            break :outer;
        }
    }
}

// error
//
// :4:20: error: label not found: 'outer'
