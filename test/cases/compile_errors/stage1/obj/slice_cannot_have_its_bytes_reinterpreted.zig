export fn foo() void {
    const bytes = [1]u8{ 0xfa } ** 16;
    var value = @ptrCast(*const []const u8, &bytes).*;
    _ = value;
}

// error
// backend=stage1
// target=native
//
// :3:52: error: slice '[]const u8' cannot have its bytes reinterpreted
