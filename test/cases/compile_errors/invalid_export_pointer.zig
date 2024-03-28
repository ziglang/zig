comptime {
    const x: u32 = 123;
    @export(x, .{ .name = "a", .linkage = @as(u32, 1234) });
}

comptime {
    const x: [5]u8 = .{ 1, 2, 3, 4, 5 };
    const slice: []const u8 = &x;
    @export(slice, .{ .name = "b", .linkage = @as(u32, 1234) });
}

comptime {
    var x: u32 = 123;
    @export(&x, .{ .name = "c", .linkage = @as(u32, 1234) });
}

comptime {
    const ptr: *const u32 = @ptrFromInt(0x1000);
    @export(ptr, .{ .name = "d", .linkage = @as(u32, 1234) });
}

// error
// backend=stage2
// target=native
//
// :3:13: error: expected pointer, found 'u32'
// :3:13: note: take the address of a value to export it
// :9:13: error: expected pointer, found '[]const u8'
// :9:13: note: use 'ptr' field to convert slice to many pointer
// :14:13: error: export pointer contains reference to comptime var
// :14:13: note: comptime var pointers are not available at runtime
// :19:13: error: export target is not comptime-known
// :19:13: note: export must  to global declaration or comptime-known value
