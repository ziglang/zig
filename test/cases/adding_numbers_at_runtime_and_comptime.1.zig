pub fn main() void {
    if (x - 7 != 0) unreachable;
}

fn add(a: u32, b: u32) u32 {
    return a + b;
}

const x = add(3, 4);

// run
//
