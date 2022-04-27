pub fn main() void {
    var x: u32 = undefined;
    set(&x);
    assert(x == 123);
}

fn set(x: *u32) void {
    x.* = 123;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
