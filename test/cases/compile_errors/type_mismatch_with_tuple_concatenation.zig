export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// error
// backend=stage2
// target=native
//
// :3:11: error: no field named '0' in struct '@TypeOf(.{})'
