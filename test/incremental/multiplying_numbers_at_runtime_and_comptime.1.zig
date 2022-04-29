pub fn main() void {
    if (x - 12 != 0) unreachable;
}

fn mul(a: u32, b: u32) u32 {
    return a * b;
}

const x = mul(3, 4);

// run
//
