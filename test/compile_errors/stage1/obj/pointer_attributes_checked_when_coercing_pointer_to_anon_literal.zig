comptime {
    const c: [][]const u8 = &.{"hello", "world" };
    _ = c;
}
comptime {
    const c: *[2][]const u8 = &.{"hello", "world" };
    _ = c;
}
const S = struct {a: u8 = 1, b: u32 = 2};
comptime {
    const c: *S = &.{};
    _ = c;
}

// pointer attributes checked when coercing pointer to anon literal
//
// tmp.zig:2:31: error: cannot cast pointer to array literal to slice type '[][]const u8'
// tmp.zig:2:31: note: cast discards const qualifier
// tmp.zig:6:33: error: cannot cast pointer to array literal to '*[2][]const u8'
// tmp.zig:6:33: note: cast discards const qualifier
// tmp.zig:11:21: error: expected type '*S', found '*const struct:11:21'
// tmp.zig:11:21: note: cast discards const qualifier
