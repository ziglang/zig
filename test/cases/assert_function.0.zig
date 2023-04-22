pub fn main() void {
    add(3, 4);
}

fn add(a: u32, b: u32) void {
    assert(a + b == 7);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
// target=x86_64-macos,x86_64-linux
// link_libc=true
