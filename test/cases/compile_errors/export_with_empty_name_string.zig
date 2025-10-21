pub export fn entry() void {}
comptime {
    @export(&entry, .{ .name = "" });
}

// error
//
// :3:25: error: exported symbol name cannot be empty
