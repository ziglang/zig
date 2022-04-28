pub fn main() void {
    add(3, 4);
}

fn add(a: u32, b: u32) void {
    const c = a + b; // 7
    const d = a + c; // 10
    const e = d + b; // 14
    assert(e == 14);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
