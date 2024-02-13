fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn foo(ok: bool) i32 {
    const val: i32 = blk: {
        var x: i32 = 1;
        _ = &x;
        if (!ok) break :blk x + 9;
        break :blk x + 19;
    };
    return val + 10;
}

pub fn main() void {
    assert(foo(false) == 20);
    assert(foo(true) == 30);
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
