const std = @import("std");
const expect = std.testing.expect;

test "@expect if-statement" {
    const x: u32 = 10;
    _ = &x;
    if (@expect(x == 20)) {}
}

test "@expect runtime if-statement" {
    var x: u32 = 10;
    var y: u32 = 20;
    _ = &x;
    _ = &y;
    if (@expect(x != y)) {}
}

test "@expect bool input/output" {
    const b: bool = true;
    try expect(@TypeOf(@expect(b)) == bool);
}

test "@expect bool is transitive" {
    const a: bool = true;
    const b = @expect(a);

    const c = @intFromBool(~b);
    std.mem.doNotOptimizeAway(c);

    try expect(c == true);
}
