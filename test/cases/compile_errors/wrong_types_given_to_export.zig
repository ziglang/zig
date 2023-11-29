fn entry() callconv(.C) void {}
comptime {
    @export(entry, .{ .name = "entry", .linkage = @as(u32, 1234) });
}

// error
// backend=stage2
// target=native
//
// :3:41: error: expected type 'builtin.GlobalLinkage', found 'u32'
// :?:?: note: enum declared here
