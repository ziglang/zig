const std = @import("std");
const assert = std.debug.assert;

test "@alignTo" {
    comptime testAlignTo();
    testAlignTo();

    assert(testAlignToCallSite(5, 8) == 8);
    assert(testAlignToCallSite(17, 8) == 24);
    assert(testAlignToCallSite(~usize(0), 8) == 0);
    assert(testAlignToCallSite(321, 255) == 510);
}

fn testAlignTo() void {
    assert(@alignTo(5, 8) == 8);
    assert(@alignTo(17, 8) == 24);
    assert(@alignTo(~usize(0), 8) == 0);
    assert(@alignTo(321, 255) == 510);
}

fn testAlignToCallSite(from: usize, to: usize) usize {
    return @alignTo(from, to);
}
