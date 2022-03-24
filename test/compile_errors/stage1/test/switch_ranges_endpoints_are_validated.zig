pub export fn entry() void {
    var x: i32 = 0;
    switch (x) {
        6...1 => {},
        -1...-5 => {},
        else => unreachable,
    }
}

// switch ranges endpoints are validated
//
// tmp.zig:4:9: error: range start value is greater than the end value
// tmp.zig:5:9: error: range start value is greater than the end value
