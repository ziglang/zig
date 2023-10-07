fn foo(x: u8) u8 {
    return switch (x) {
        0...100 => @as(u8, 0),
        101...200 => 1,
        201, 203...207 => 2,
        206...255 => 3,
    };
}
export fn entry() usize {
    return @sizeOf(@TypeOf(&foo));
}

// error
// backend=stage2
// target=native
//
// :6:12: error: duplicate switch value
// :5:17: note: previous value here
