pub fn main() void {
    const a: anyerror!u32 = error.Bar;
    a catch |err| assert(err == error.Bar);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
