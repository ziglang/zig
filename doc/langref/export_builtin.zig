comptime {
    @export(&internalName, .{ .name = "foo", .linkage = .strong });
}

fn internalName() callconv(.C) void {}

// obj
