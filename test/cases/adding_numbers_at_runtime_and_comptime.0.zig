pub fn main() void {
    add(3, 4);
}

fn add(a: u32, b: u32) void {
    if (a + b != 7) unreachable;
}

// run
//
