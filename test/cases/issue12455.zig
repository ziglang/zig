test "issue12455" {
    var a: u32 = 0;
    while (true) switch (a) {
        0 => 2,
        1 => a = 0,
        else => break,
    };
}

// error
// is_test=1
//
// :3:18: error: incompatible types: 'comptime_int' and 'void'
