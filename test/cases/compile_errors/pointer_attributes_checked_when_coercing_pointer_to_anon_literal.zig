comptime {
    const c: [][]const u8 = &.{ "hello", "world" };
    _ = c;
}
comptime {
    const c: *[2][]const u8 = &.{ "hello", "world" };
    _ = c;
}
const S = struct { a: u8 = 1, b: u32 = 2 };
comptime {
    const c: *S = &.{ .a = 2 };
    _ = c;
}

// error
// backend=stage2
// target=native
//
// :2:29: error: expected type '[][]const u8', found '*const [2][]const u8'
// :2:29: note: cast discards const qualifier
// :6:31: error: expected type '*[2][]const u8', found '*const [2][]const u8'
// :6:31: note: cast discards const qualifier
// :11:19: error: expected type '*tmp.S', found '*const tmp.S'
// :11:19: note: cast discards const qualifier
