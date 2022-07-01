pub fn main() void {
    var x: u32 = 1;
    assert(x << 1 == 2);

    x <<= 1;
    assert(x << 2 == 8);
    assert(x << 3 == 16);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
