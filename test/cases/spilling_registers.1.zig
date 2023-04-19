pub fn main() void {
    assert(addMul(3, 4) == 357747496);
}

fn addMul(a: u32, b: u32) u32 {
    const x: u32 = blk: {
        const c = a + b; // 7
        const d = a + c; // 10
        const e = d + b; // 14
        const f = d + e; // 24
        const g = e + f; // 38
        const h = f + g; // 62
        const i = g + h; // 100
        const j = i + d; // 110
        const k = i + j; // 210
        const l = k + c; // 217
        const m = l * d; // 2170
        const n = m + e; // 2184
        const o = n * f; // 52416
        const p = o + g; // 52454
        const q = p * h; // 3252148
        const r = q + i; // 3252248
        const s = r * j; // 357747280
        const t = s + k; // 357747490
        break :blk t;
    };
    const y = x + a; // 357747493
    const z = y + a; // 357747496
    return z;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
