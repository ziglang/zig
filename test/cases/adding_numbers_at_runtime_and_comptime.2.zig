pub fn main() void {
    var x: usize = 3;
    _ = &x;
    const y = add(1, 2, x);
    if (y - 6 != 0) unreachable;
}

inline fn add(a: usize, b: usize, c: usize) usize {
    return a + b + c;
}

// run
//
