pub fn main() void {
    add(3, 4);
}

fn add(a: u32, b: u32) void {
    const c = a + b; // 7
    const d = a + c; // 10
    const e = d + b; // 14
    const f = d + e; // 24
    const g = e + f; // 38
    const h = f + g; // 62
    const i = g + h; // 100
    assert(i == 100);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
