const std = @import("std");
const expect = std.testing.expect;
const builtin = @import("builtin");

test "memory size and grow" {
    var prev = @wasmMemorySize(0);
    _ = &prev;
    try expect(prev == @wasmMemoryGrow(0, 1));
    try expect(prev + 1 == @wasmMemorySize(0));
}
