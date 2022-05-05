pub fn main() void {
    const a: anyerror!comptime_int = 42;
    const b: *const comptime_int = &(a catch unreachable);
    assert(b.* == 42);
}
fn assert(b: bool) void {
    if (!b) unreachable; // assertion failure
}

// run
//
