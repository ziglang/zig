export fn entry() void {
    var i: usize = 0;
    blah: while (i < 10) : (i += 1) {
        while (true) {
            continue :outer;
        }
    }
}

// error
//
// :5:23: error: label not found: 'outer'
