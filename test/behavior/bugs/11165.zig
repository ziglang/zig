const builtin = @import("builtin");

test "bytes" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        a: u32,
        c: [5]u8,
    };

    const U = union {
        s: S,
    };

    const s_1 = S{
        .a = undefined,
        .c = "12345".*, // this caused problems
    };

    var u_2 = U{ .s = s_1 };
    _ = u_2;
}

test "aggregate" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = struct {
        a: u32,
        c: [5]u8,
    };

    const U = union {
        s: S,
    };

    const c = [5:0]u8{ 1, 2, 3, 4, 5 };
    const s_1 = S{
        .a = undefined,
        .c = c, // this caused problems
    };

    var u_2 = U{ .s = s_1 };
    _ = u_2;
}
