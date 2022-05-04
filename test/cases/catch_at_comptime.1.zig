pub fn main() void {
    const i: anyerror!u64 = error.B;
    const caught = i catch 5;
    assert(caught == 5);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
