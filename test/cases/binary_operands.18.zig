pub fn main() void {
    var b: bool = false;
    b = b or false;
    if (b) unreachable;
    return;
}

// run
//
