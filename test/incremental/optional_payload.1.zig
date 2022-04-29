pub fn main() void {
    var x: u32 = undefined;
    const maybe_x = byPtr(&x);
    assert(maybe_x == null);
}

fn byPtr(x: *u32) ?*u32 {
    _ = x;
    return null;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
