pub fn main() void {
    var i: i4 = 3;
    _ = &i;
    if (i *% 3 != -7) unreachable;
    return;
}

// run
//
