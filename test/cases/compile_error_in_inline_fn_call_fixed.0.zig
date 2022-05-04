pub fn main() void {
    var x: usize = 3;
    const y = add(10, 2, x);
    if (y - 6 != 0) unreachable;
}

inline fn add(a: usize, b: usize, c: usize) usize {
    if (a == 10) @compileError("bad");
    return a + b + c;
}

// error
// output_mode=Exe
//
// :8:18: error: bad
// :3:18: note: called from here
