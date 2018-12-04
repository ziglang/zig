const std = @import("std");
const assert = std.debug.assert;

const fixuint = @import("fixuint.zig").fixuint;

fn test__fixuint(comptime fp_t: type, comptime fixuint_t: type, a: fp_t, expected: fixuint_t) void {
    const x = fixuint(fp_t, fixuint_t, a);
    assert(x == expected);
}

test "fixuint.u1" {
    test__fixuint(f32, u1, -1.0, 0);
    test__fixuint(f32, u1, 0.0, 0);
    test__fixuint(f32, u1, 1.0, 1);
    test__fixuint(f32, u1, 2.0, 1);
}

