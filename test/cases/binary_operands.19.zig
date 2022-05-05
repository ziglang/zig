pub fn main() void {
    var b: bool = true;
    b = b or false;
    if (!b) unreachable;
    return;
}

// run
//
