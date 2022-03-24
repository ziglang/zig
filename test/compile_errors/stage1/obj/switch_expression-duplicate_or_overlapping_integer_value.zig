fn foo(x: u8) u8 {
    return switch (x) {
        0 ... 100 => @as(u8, 0),
        101 ... 200 => 1,
        201, 203 ... 207 => 2,
        206 ... 255 => 3,
    };
}
export fn entry() usize { return @sizeOf(@TypeOf(foo)); }

// switch expression - duplicate or overlapping integer value
//
// tmp.zig:6:9: error: duplicate switch value
// tmp.zig:5:14: note: previous value here
