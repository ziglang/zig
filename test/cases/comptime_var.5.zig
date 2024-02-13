pub fn main() void {
    var a: u32 = 0;
    _ = &a;
    if (a == 0) {
        comptime var b: u32 = 0;
        b = 1;
    }
}
comptime {
    var x: i32 = 1;
    x += 1;
    if (x != 2) unreachable;
}

// run
//
