export fn entry() void {
    var q: u8 = 0;
    switch (q) {
        1...2 => {},
        0...255 => {},
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:9: error: duplicate switch value
