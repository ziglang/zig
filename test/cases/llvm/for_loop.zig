fn assert(ok: bool) void {
    if (!ok) unreachable;
}

pub fn main() void {
    var x: u32 = 0;
    for ("hello") |_| {
        x += 1;
    }
    assert("hello".len == x);
}

// run
// backend=llvm
// target=x86_64-linux,x86_64-macos
//
