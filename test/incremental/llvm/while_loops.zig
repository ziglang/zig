fn assert(ok: bool) void {
    if (!ok) unreachable;
}

pub fn main() void {
    var sum: u32 = 0;
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        sum += i;
    }
    assert(sum == 10);
    assert(i == 5);
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
