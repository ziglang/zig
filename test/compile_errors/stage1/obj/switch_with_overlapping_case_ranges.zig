export fn entry() void {
    var q: u8 = 0;
    switch (q) {
        1...2 => {},
        0...255 => {},
    }
}

// switch with overlapping case ranges
//
// tmp.zig:5:9: error: duplicate switch value
