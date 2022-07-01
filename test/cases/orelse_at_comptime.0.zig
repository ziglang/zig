pub fn main() void {
    const i: ?u64 = 0;
    const result = i orelse 5;
    assert(result == 0);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
