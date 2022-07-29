export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// error
// backend=stage2
// target=native
//
// :3:11: error: index '0' out of bounds of tuple '@TypeOf(.{})'
