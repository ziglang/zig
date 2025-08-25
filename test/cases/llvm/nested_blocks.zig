fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn foo(ok: bool) i32 {
    var val: i32 = blk: {
        const val2: i32 = another: {
            if (!ok) break :blk 10;
            break :another 10;
        };
        break :blk val2 + 10;
    };
    return (&val).*;
}

pub fn main() void {
    assert(foo(false) == 10);
    assert(foo(true) == 20);
}

// run
// backend=stage2,llvm
// target=x86_64-linux,x86_64-macos
//
