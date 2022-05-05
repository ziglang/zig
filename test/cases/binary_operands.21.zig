pub fn main() void {
    var b: bool = true;
    b = b or true;
    if (!b) unreachable;
    return;
}

// run
//
