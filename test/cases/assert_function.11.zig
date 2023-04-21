pub fn main() void {
    assert(add(3, 4) == 1221);
    assert(mul(3, 4) == 21609);
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
        const l = j + k; // 320
        const m = l + c; // 327
        const n = m + d; // 337
        const o = n + e; // 351
        const p = o + f; // 375
        const q = p + g; // 413
        const r = q + h; // 475
        const s = r + i; // 575
        const t = s + j; // 685
        const u = t + k; // 895
        const v = u + l; // 1215
        break :blk v;
    };
    const y = x + a; // 1218
    const z = y + a; // 1221
    return z;
}

fn mul(a: u32, b: u32) u32 {
    const x: u32 = blk: {
        const c = a * a * a * a; // 81
        const d = a * a * a * b; // 108
        const e = a * a * b * a; // 108
        const f = a * a * b * b; // 144
        const g = a * b * a * a; // 108
        const h = a * b * a * b; // 144
        const i = a * b * b * a; // 144
        const j = a * b * b * b; // 192
        const k = b * a * a * a; // 108
        const l = b * a * a * b; // 144
        const m = b * a * b * a; // 144
        const n = b * a * b * b; // 192
        const o = b * b * a * a; // 144
        const p = b * b * a * b; // 192
        const q = b * b * b * a; // 192
        const r = b * b * b * b; // 256
        const s = c + d + e + f + g + h + i + j + k + l + m + n + o + p + q + r; // 2401
        break :blk s;
    };
    const y = x * a; // 7203
    const z = y * a; // 21609
    return z;
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
