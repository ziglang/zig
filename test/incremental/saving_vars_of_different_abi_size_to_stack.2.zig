pub fn main() void {
    assert(callMe(2) == 24);
}

fn callMe(a: u32) u32 {
    var b: u32 = a + 10;
    const c = 2 * b;
    return c;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
