const std = @import("std");
const expect = std.testing.expect;

var pos = [2]f32{ 0.0, 0.0 };
test "store to global array" {
    try expect(pos[1] == 0.0);
    pos = [2]f32{ 0.0, 1.0 };
    try expect(pos[1] == 1.0);
}

var vpos = @Vector(2, f32){ 0.0, 0.0 };
test "store to global vector" {
    try expect(vpos[1] == 0.0);
    vpos = @Vector(2, f32){ 0.0, 1.0 };
    try expect(vpos[1] == 1.0);
}
