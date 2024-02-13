pub fn main() void {
    var i: i32 = 2147483647;
    _ = &i;
    const result = i *% 2;
    if (result != -2) unreachable;
    return;
}

// run
//
