pub fn main() void {
    const ignore =
        \\ cool thx
        \\
    ;
    _ = ignore;
    add('ぁ', '\x03');
}

fn add(a: u32, b: u32) void {
    assert(a + b == 12356);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
