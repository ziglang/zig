pub fn main() void {
    var x: usize = 1;
    var y: bool = getFalse();
    _ = y;

    assert(x == 1);
}

fn getFalse() bool {
    return false;
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

// run
//
