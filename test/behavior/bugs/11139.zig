const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "store array of array of structs at comptime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try expect(storeArrayOfArrayOfStructs() == 15);
    comptime try expect(storeArrayOfArrayOfStructs() == 15);
}

fn storeArrayOfArrayOfStructs() u8 {
    const S = struct {
        x: u8,
    };

    var cases = [_][1]S{
        [_]S{
            S{ .x = 15 },
        },
    };
    return cases[0][0].x;
}
