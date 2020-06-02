const std = @import("std");
const expect = std.testing.expect;

test "memory size and grow" {
    var prev = @wasmMemorySize();
    expect(prev == @wasmMemoryGrow(1));
    expect(prev + 1 == @wasmMemorySize());
}
