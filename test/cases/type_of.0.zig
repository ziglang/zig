pub fn main() void {
    var x: usize = 0;
    _ = &x;
    const z = @TypeOf(x, @as(u128, 5));
    assert(z == u128);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
