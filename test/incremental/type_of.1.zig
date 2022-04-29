pub fn main() void {
    const z = @TypeOf(true);
    assert(z == bool);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
