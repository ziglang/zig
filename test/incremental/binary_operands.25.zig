pub fn main() void {
    var b: bool = true;
    b = b and true;
    if (!b) unreachable;
    return;
}

// run
//
