pub fn main() void {
    var b: bool = false;
    b = b and false;
    if (b) unreachable;
    return;
}

// run
//
