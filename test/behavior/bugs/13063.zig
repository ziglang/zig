const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var pos = [2]f32{ 0.0, 0.0 };
test "store to global array" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(pos[1] == 0.0);
    pos = [2]f32{ 0.0, 1.0 };
    try expect(pos[1] == 1.0);
}

var vpos = @Vector(2, f32){ 0.0, 0.0 };
test "store to global vector" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try expect(vpos[1] == 0.0);
    vpos = @Vector(2, f32){ 0.0, 1.0 };
    try expect(vpos[1] == 1.0);
}
