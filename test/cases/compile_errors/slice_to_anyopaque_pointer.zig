export fn entry() void {
    const slice: []const u8 = "foo";
    const x = @as(*const anyopaque, slice);
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :3:37: error: expected type '*const anyopaque', found '[]const u8'
// :3:37: note: cannot implicitly cast slice '[]const u8' to anyopaque pointer '*const anyopaque'
// :3:37: note: consider using '.ptr'
