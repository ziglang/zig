fn foo(x: u2) void {
    switch (x) {
        0 => {},
        1 => {},
        2 => {},
        3 => {},
        else => {},
    }
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// switch expression - unreachable else prong (u2)
//
// tmp.zig:7:9: error: unreachable else prong, all cases already handled
