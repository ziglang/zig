pub fn main() void {
    assert(add(1, 2, 3, 4, 5, 6) == 21);
}

fn add(a: u32, b: u32, c: u32, d: u32, e: u32, f: u32) u32 {
    return a + b + c + d + e + f;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
