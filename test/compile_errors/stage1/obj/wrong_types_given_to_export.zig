fn entry() callconv(.C) void { }
comptime {
    @export(entry, .{.name = "entry", .linkage = @as(u32, 1234) });
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:59: error: expected type 'std.builtin.GlobalLinkage', found 'comptime_int'
