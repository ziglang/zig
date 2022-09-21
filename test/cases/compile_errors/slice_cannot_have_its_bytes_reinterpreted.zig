export fn foo() void {
    const bytes align(@alignOf([]const u8)) = [1]u8{0xfa} ** 16;
    var value = @ptrCast(*const []const u8, &bytes).*;
    _ = value;
}

// error
// backend=stage2
// target=native
//
// :3:52: error: comptime dereference requires '[]const u8' to have a well-defined layout, but it does not.
