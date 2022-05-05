pub fn main() void {
    mul(3, 4);
}

fn mul(a: u32, b: u32) void {
    if (a * b != 12) unreachable;
}

// run
// target=x86_64-linux,x86_64-macos
//
