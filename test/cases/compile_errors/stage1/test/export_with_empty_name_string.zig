pub export fn entry() void { }
comptime {
    @export(entry, .{ .name = "" });
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:5: error: exported symbol name cannot be empty
