fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

pub fn main() void {
    assert(add(1, 2) == 3);
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
