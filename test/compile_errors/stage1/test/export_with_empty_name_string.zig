pub export fn entry() void { }
comptime {
    @export(entry, .{ .name = "" });
}

// @export with empty name string
//
// tmp.zig:3:5: error: exported symbol name cannot be empty
