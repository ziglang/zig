const std = @import("std");
const expect = std.testing.expect;

const Bar = packed struct {
    const Baz = enum {
        fizz,
        buzz,
    };
};

test {
    var foo = Bar.Baz.fizz;
    try expect(foo == .fizz);
}
