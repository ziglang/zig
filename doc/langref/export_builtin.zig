comptime {
    @export(&internalName, .{ .name = "foo", .linkage = .strong });
}

fn internalName() callconv(.c) void {}

// obj
