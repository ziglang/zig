pub fn main() void {
    var x: usize = 5;
    const y = mul(2, 3, x);
    if (y - 30 != 0) unreachable;
}

inline fn mul(a: usize, b: usize, c: usize) usize {
    return a * b * c;
}

// run
//
