export fn entry() void {
    var items = [_]u8{ 1, 2, 3 };
    for (&items) |*i| {
        i.?.* = 1;
    }
}

// error
//
// :4:10: error: expected optional type, found '*u8'
