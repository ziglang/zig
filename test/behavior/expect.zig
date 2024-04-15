const std = @import("std");
const expect = std.testing.expect;

test "@expect if-statement" {
    const x: u32 = 10;
    _ = &x;
    if (@expect(x == 20, true)) {}
}

test "@expect runtime if-statement" {
    var x: u32 = 10;
    var y: u32 = 20;
    _ = &x;
    _ = &y;
    if (@expect(x != y, false)) {}
}

test "@expect bool input/output" {
    const b: bool = true;
    try expect(@TypeOf(@expect(b, false)) == bool);
}

test "@expect bool is transitive" {
    const a: bool = true;
    const b = @expect(a, false);

    const c = @intFromBool(!b);
    std.mem.doNotOptimizeAway(c);

    try expect(c == 0);
    try expect(@expect(c != 0, false) == false);
}

test "@expect at comptime" {
    const a: bool = true;
    comptime try expect(@expect(a, true) == true);
}
