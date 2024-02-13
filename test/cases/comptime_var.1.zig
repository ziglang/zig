pub fn main() void {
    var a: u32 = 0;
    _ = &a;
    comptime var b: u32 = 0;
    switch (a) {
        0 => {},
        else => b = 3,
    }
}

// error
//
// :6:19: error: store to comptime variable depends on runtime condition
// :4:13: note: runtime condition here
