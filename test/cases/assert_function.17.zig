pub fn main() void {
    var i: u64 = 0xFFEEDDCCBBAA9988;
    assert(i == 0xFFEEDDCCBBAA9988);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
