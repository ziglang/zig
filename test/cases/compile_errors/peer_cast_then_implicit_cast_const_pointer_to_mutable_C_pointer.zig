export fn func() void {
    var strValue: [*c]u8 = undefined;
    strValue = strValue orelse "";
}

// error
// backend=stage2
// target=native
//
// :3:32: error: expected type '[*c]u8', found '*const [0:0]u8'
// :3:32: note: cast discards const qualifier
