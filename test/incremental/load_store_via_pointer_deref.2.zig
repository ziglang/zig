pub fn main() void {
    var x: u8 = undefined;
    set(&x);
    assert(x == 123);
}

fn set(x: *u8) void {
    x.* = 123;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
