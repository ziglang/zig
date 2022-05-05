pub fn main() void {
    const i: ?u64 = null;
    const result = i orelse 5;
    assert(result == 5);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
