pub fn main() void {
    var i: u32 = 10;
    var j: u32 = 11;
    assert(i | 1 == 11);
    assert(j | 1 == 11);
    var m1: u32 = 0b1111;
    var m2: u32 = 0b0000;
    assert(m1 | 0b1010 == 0b1111);
    assert(m2 | 0b1010 == 0b1010);
    _ = .{ &i, &j, &m1, &m2 };
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
