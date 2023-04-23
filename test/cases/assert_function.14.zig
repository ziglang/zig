pub fn main() void {
    add(aa, bb);
}

const aa = 'ぁ';
const bb = '\x03';

fn add(a: u32, b: u32) void {
    assert(a + b == 12356);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
