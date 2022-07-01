pub fn main() void {
    assert(add(3, 4) == 7);
    assert(add(20, 10) == 30);
}

fn add(a: u32, b: u32) u32 {
    return a + b;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
