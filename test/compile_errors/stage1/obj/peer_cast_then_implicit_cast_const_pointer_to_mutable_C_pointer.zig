export fn func() void {
    var strValue: [*c]u8 = undefined;
    strValue = strValue orelse "";
}

// peer cast then implicit cast const pointer to mutable C pointer
//
// tmp.zig:3:32: error: expected type '[*c]u8', found '*const [0:0]u8'
// tmp.zig:3:32: note: cast discards const qualifier
