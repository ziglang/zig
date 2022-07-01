pub fn main() void {
    var b: bool = true;
    b = b and false;
    if (b) unreachable;
    return;
}

// run
//
