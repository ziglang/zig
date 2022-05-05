pub fn main() void {
    var b: bool = false;
    b = b and true;
    if (b) unreachable;
    return;
}

// run
//
