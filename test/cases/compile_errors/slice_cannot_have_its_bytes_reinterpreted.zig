export fn foo() void {
    const bytes align(@alignOf([]const u8)) = @as([16]u8, @splat(0xfa));
    _ = @as(*const []const u8, @ptrCast(&bytes)).*;
}

// error
//
// :3:49: error: comptime dereference requires '[]const u8' to have a well-defined layout
