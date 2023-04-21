pub fn main() void {
    assert(foo(true) != @as(i32, 30));
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn foo(ok: bool) i32 {
    const x = if (ok) @as(i32, 20) else @as(i32, 10);
    return x;
}

// run
//
