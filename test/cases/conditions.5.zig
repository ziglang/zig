pub fn main() void {
    assert(foo(false) == @as(i32, 20));
    assert(foo(true) == @as(i32, 30));
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn foo(ok: bool) i32 {
    const val: i32 = blk: {
        var x: i32 = 1;
        _ = &x;
        if (!ok) break :blk x + @as(i32, 9);
        break :blk x + @as(i32, 19);
    };
    return val + 10;
}

// run
//
