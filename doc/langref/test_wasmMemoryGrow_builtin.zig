const std = @import("std");
const native_arch = @import("builtin").target.cpu.arch;
const expect = std.testing.expect;

test "@wasmMemoryGrow" {
    if (native_arch != .wasm32) return error.SkipZigTest;

    const prev = @wasmMemorySize(0);
    try expect(prev == @wasmMemoryGrow(0, 1));
    try expect(prev + 1 == @wasmMemorySize(0));
}

// test
