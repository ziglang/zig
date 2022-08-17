const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "switch on empty enum" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const E = enum {};
    var e: E = undefined;
    switch (e) {}
}

test "switch on empty enum with a specified tag type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const E = enum(u8) {};
    var e: E = undefined;
    switch (e) {}
}

test "switch on empty auto numbered tagged union" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const U = union(enum(u8)) {};
    var u: U = undefined;
    switch (u) {}
}

test "switch on empty tagged union" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO

    const E = enum {};
    const U = union(E) {};
    var u: U = undefined;
    switch (u) {}
}

test "empty union" {
    const U = union {};
    try expect(@sizeOf(U) == 0);
    try expect(@alignOf(U) == 0);
}

test "empty extern union" {
    const U = extern union {};
    try expect(@sizeOf(U) == 0);
    try expect(@alignOf(U) == 1);
}
