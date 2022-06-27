pub export fn entry() void { }
comptime {
    @export(entry, .{ .name = "" });
}

// error
// backend=stage2
// target=native
//
// :3:21: error: exported symbol name cannot be empty
