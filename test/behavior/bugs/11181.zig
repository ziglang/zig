const builtin = @import("builtin");

test "const inferred array of slices" {
    const T = struct { v: bool };

    const decls = [_][]const T{
        &[_]T{
            .{ .v = false },
        },
    };
    _ = decls;
}

test "var inferred array of slices" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = struct { v: bool };

    var decls = [_][]const T{
        &[_]T{
            .{ .v = false },
        },
    };
    _ = &decls;
}
