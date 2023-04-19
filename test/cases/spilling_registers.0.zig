pub fn main() void {
    assert(add(3, 4) == 791);
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
        const k = i + j; // 210
        const l = k + c; // 217
        const m = l + d; // 227
        const n = m + e; // 241
        const o = n + f; // 265
        const p = o + g; // 303
        const q = p + h; // 365
        const r = q + i; // 465
        const s = r + j; // 575
        const t = s + k; // 785
        break :blk t;
    };
    const y = x + a; // 788
    const z = y + a; // 791
    return z;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// target=x86_64-linux,x86_64-macos
//
