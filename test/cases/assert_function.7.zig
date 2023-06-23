extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    var i: u32 = 0;
    while (i < 4) : (i += 1) print();
    assert(i == 4);
}

fn print() void {
    _ = write(1, @intFromPtr("hello\n"), 6);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// run
//
// hello
// hello
// hello
// hello
//
