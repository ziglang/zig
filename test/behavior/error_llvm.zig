const std = @import("std");
const expect = std.testing.expect;
const mem = std.mem;

fn gimmeItBroke() anyerror {
    return error.ItBroke;
}

test "@errorName" {
    try expect(mem.eql(u8, @errorName(error.AnError), "AnError"));
    try expect(mem.eql(u8, @errorName(error.ALongerErrorName), "ALongerErrorName"));
    try expect(mem.eql(u8, @errorName(gimmeItBroke()), "ItBroke"));
}

test "@errorName sentinel length matches slice length" {
    const name = testBuiltinErrorName(error.FooBar);
    const length: usize = 6;
    try expect(length == std.mem.indexOfSentinel(u8, 0, name.ptr));
    try expect(length == name.len);
}

pub fn testBuiltinErrorName(err: anyerror) [:0]const u8 {
    return @errorName(err);
}
