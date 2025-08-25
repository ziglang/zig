fn SimpleList(comptime L: usize) type {
    var T = u8;
    return struct {
        array: [L]T,
    };
}

// error
// backend=stage2
// target=native
//
// :4:19: error: mutable 'T' not accessible from here
// :2:9: note: declared mutable here
// :3:12: note: crosses namespace boundary here
