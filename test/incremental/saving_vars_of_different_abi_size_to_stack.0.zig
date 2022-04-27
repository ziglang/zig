pub fn main() void {
    assert(callMe(2) == 24);
}

fn callMe(a: u8) u8 {
    var b: u8 = a + 10;
    const c = 2 * b;
    return c;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
