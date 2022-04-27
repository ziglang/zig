pub fn main() void {
    var x: u8 = undefined;
    const maybe_x = byPtr(&x);
    assert(maybe_x != null);
    maybe_x.?.* = 255;
    assert(x == 255);
}

fn byPtr(x: *u8) ?*u8 {
    return x;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
