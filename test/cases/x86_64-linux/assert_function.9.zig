pub fn main() void {
    assert(add(3, 4) == 20);
}

fn add(a: u32, b: u32) u32 {
    const x: u32 = blk: {
        const c = a + b; // 7
        const d = a + c; // 10
        const e = d + b; // 14
        break :blk e;
    };
    const y = x + a; // 17
    const z = y + a; // 20
    return z;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
