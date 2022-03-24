fn foo(x: bool) void {
    switch (x) {
        true => {},
        false => {},
        else => {},
    }
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// switch expression - unreachable else prong (bool)
//
// tmp.zig:5:9: error: unreachable else prong, all cases already handled
