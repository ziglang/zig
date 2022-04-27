pub fn main() void {
    const i: anyerror!u64 = 0;
    const caught = i catch 5;
    assert(caught == 0);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
