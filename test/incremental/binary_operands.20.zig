pub fn main() void {
    var b: bool = false;
    b = b or true;
    if (!b) unreachable;
    return;
}

// run
//
