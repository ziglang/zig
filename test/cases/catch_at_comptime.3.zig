pub fn main() void {
    const a: anyerror!u32 = error.B;
    _ = &(a catch |err| assert(err == error.B));
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
