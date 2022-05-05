pub fn main() void {
    var x: u32 = undefined;
    const maybe_x = byPtr(&x);
    assert(maybe_x != null);
    maybe_x.?.* = 123;
    assert(x == 123);
}

fn byPtr(x: *u32) ?*u32 {
    return x;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
// target=x86_64-linux,x86_64-macos
//
