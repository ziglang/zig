fn foo(x: u8) void {
    switch (x) {
        0 => {},
    }
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// switch expression - non exhaustive integer prongs
//
// tmp.zig:2:5: error: switch must handle all possibilities
