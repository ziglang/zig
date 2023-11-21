pub fn main() void {
    var i: u3 = 3;
    _ = &i;
    if (i *% 3 != 1) unreachable;
    return;
}

// run
//
