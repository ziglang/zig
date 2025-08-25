export fn entry() void {
    var a: u32 = 0;
    while (true) switch (a) {
        0 => 2,
        1 => a = 0,
        else => break,
    };
}

// error
// backend=stage2
// target=native
//
// :3:18: error: incompatible types: 'comptime_int' and 'void'
// :4:14: note: type 'comptime_int' here
// :5:16: note: type 'void' here
