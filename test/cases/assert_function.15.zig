pub fn main() void {
    assert("hello"[0] == 'h');
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
