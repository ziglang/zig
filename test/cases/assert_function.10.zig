pub fn main() void {
    assert(add(3, 4) == 116);
}

fn add(a: u32, b: u32) u32 {
    const x: u32 = blk: {
        const c = a + b; // 7
        const d = a + c; // 10
        const e = d + b; // 14
        const f = d + e; // 24
        const g = e + f; // 38
        const h = f + g; // 62
        const i = g + h; // 100
        const j = i + d; // 110
        break :blk j;
    };
    const y = x + a; // 113
    const z = y + a; // 116
    return z;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
