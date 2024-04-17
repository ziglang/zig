export fn foo() void {
    const bytes align(@alignOf([]const u8)) = [1]u8{0xfa} ** 16;
    _ = @as(*const []const u8, @ptrCast(&bytes)).*;
}

// error
// backend=stage2
// target=native
//
// :3:49: error: comptime dereference requires '[]const u8' to have a well-defined layout
