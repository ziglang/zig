const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    comptime var st = .{
        .foo = &1,
        .bar = &2,
    };

    inline for (@typeInfo(@TypeOf(st)).Struct.fields) |field| {
        _ = field;
    }
}
