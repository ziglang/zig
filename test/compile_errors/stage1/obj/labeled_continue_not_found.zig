export fn entry() void {
    var i: usize = 0;
    blah: while (i < 10) : (i += 1) {
        while (true) {
            continue :outer;
        }
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:23: error: label not found: 'outer'
