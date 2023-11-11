pub fn main() void {
    var i: i4 = 7;
    _ = &i;
    if (i +% 1 != -8) unreachable;
    return;
}

// run
//
