pub fn main() void {
    var x: i8 = undefined;
    const maybe_x = byPtr(&x);
    assert(maybe_x != null);
    maybe_x.?.* = -1;
    assert(x == -1);
}

fn byPtr(x: *i8) ?*i8 {
    return x;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
