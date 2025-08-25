pub fn main() void {
    assert(foo() == 43);
}

fn foo() u32 {
    return bar() + baz(42);
}

fn bar() u32 {
    return 1;
}

fn baz(x: u32) u32 {
    return x;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
