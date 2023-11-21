pub fn main() void {
    var i: u4 = 0;
    _ = &i;
    if (i -% 1 != 15) unreachable;
}

// run
//
