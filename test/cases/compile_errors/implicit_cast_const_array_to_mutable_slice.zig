export fn entry() void {
    const buffer: [1]u8 = [_]u8{8};
    const sliceA: []u8 = &buffer;
    _ = sliceA;
}
export fn entry1() void {
    const str: *const [0:0]u8 = "";
    const slice: [:0]u8 = str;
    _ = slice;
}
export fn entry2() void {
    const str: *const [0:0]u8 = "";
    const many: [*]u8 = str;
    _ = many;
}
export fn entry3() void {
    const lang: []const u8 = "lang";
    const targets: [1][]const u8 = [_][]u8{lang};
    _ = targets;
}

// error
// backend=stage2
// target=native
//
// :3:26: error: expected type '[]u8', found '*const [1]u8'
// :3:26: note: cast discards const qualifier
// :8:27: error: expected type '[:0]u8', found '*const [0:0]u8'
// :8:27: note: cast discards const qualifier
// :13:25: error: expected type '[*]u8', found '*const [0:0]u8'
// :13:25: note: cast discards const qualifier
// :18:44: error: expected type '[]u8', found '[]const u8'
// :18:44: note: cast discards const qualifier
