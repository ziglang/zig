export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// error
//
// :3:11: error: expected type '@TypeOf(.{})', found 'struct { comptime <T> = 1, comptime <T> = 2, comptime <T> = 3 }'
// :3:11: note: <T> = comptime_int
