pub fn main() void {
    var a: u32 = 1024;
    assert(a >> 1 == 512);

    a >>= 1;
    assert(a >> 2 == 128);
    assert(a >> 3 == 64);
    assert(a >> 4 == 32);
    assert(a >> 5 == 16);
    assert(a >> 6 == 8);
    assert(a >> 7 == 4);
    assert(a >> 8 == 2);
    assert(a >> 9 == 1);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
