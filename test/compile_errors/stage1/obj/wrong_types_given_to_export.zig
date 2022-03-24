fn entry() callconv(.C) void { }
comptime {
    @export(entry, .{.name = "entry", .linkage = @as(u32, 1234) });
}

// wrong types given to @export
//
// tmp.zig:3:59: error: expected type 'std.builtin.GlobalLinkage', found 'comptime_int'
