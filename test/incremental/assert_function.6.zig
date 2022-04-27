pub fn main() void {
    const a: u32 = 2;
    const b: ?u32 = a;
    const c = b.?;
    if (c != 2) unreachable;
}

// run
//
