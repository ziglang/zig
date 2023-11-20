pub fn main() void {
    var i: i7 = -64;
    _ = &i;
    if (i -% 1 != 63) unreachable;
    return;
}

// run
//
