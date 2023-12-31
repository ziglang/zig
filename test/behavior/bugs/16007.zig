const std = @import("std");

test "unexpected load elision (with structs)" {
    const Foo = struct { x: i32 };

    var a = Foo{ .x = 1 };
    var b = Foo{ .x = 1 };

    var condition = false;
    std.mem.doNotOptimizeAway({
        condition = true;
    });

    const c = if (condition) a else b;
    // The second variable is superfluous with the current
    // state of codegen optimizations, but in future
    // "if (smthg) a else a" may be optimized simply into "a".

    a.x = 2;
    b.x = 3;

    try std.testing.expectEqual(c.x, 1);
}

test "unexpected load elision (with optionals)" {
    var a: ?i32 = 1;
    var b: ?i32 = 1;

    var condition = false;
    std.mem.doNotOptimizeAway({
        condition = true;
    });

    const c = if (condition) a else b;

    a = 2;
    b = 3;

    try std.testing.expectEqual(c, 1);
}
