extern "c" fn write(c_int, usize, usize) usize;

pub fn main() void {
    var i: u32 = 0;
    inline while (i < 4) : (i += 1) print();
    assert(i == 4);
}

fn print() void {
    _ = write(1, @intFromPtr("hello\n"), 6);
}

pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

// error
//
// :5:21: error: unable to resolve comptime value
// :5:21: note: condition in comptime branch must be comptime-known
