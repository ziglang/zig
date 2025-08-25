fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn main() void {
    var a: i32 = -5;
    _ = &a;
    const x = add(a, 7);
    var y = add(2, 0);
    y -= x;
    assert(y == 0);
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
