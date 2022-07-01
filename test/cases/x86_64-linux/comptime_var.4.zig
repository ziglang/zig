pub fn main() void {
    comptime var i: u64 = 0;
    while (i < 5) : (i += 1) {}
}

// error
//
// :3:24: error: cannot store to comptime variable in non-inline loop
// :3:5: note: non-inline loop here
