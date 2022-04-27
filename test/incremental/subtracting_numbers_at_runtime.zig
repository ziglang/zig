pub fn main() void {
    sub(7, 4);
}

fn sub(a: u32, b: u32) void {
    if (a - b != 3) unreachable;
}

// run
//
