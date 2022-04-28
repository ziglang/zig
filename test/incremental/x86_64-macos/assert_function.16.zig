const hello = "hello".*;
pub fn main() void {
    assert(hello[1] == 'e');
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
