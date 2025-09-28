export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// error
//
// :3:11: error: expected type '@TypeOf(.{})', found 'struct { comptime comptime_int = 1, comptime comptime_int = 2, comptime comptime_int = 3 }'
