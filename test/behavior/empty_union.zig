const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

test "switch on empty enum" {
    const E = enum {};
    var e: E = undefined;
    _ = &e;
    switch (e) {}
}

test "switch on empty enum with a specified tag type" {
    const E = enum(u8) {};
    var e: E = undefined;
    _ = &e;
    switch (e) {}
}

test "switch on empty auto numbered tagged union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const U = union(enum(u8)) {};
    var u: U = undefined;
    _ = &u;
    switch (u) {}
}

test "switch on empty tagged union" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const E = enum {};
    const U = union(E) {};
    var u: U = undefined;
    _ = &u;
    switch (u) {}
}

test "empty union" {
    const U = union {};
    try expect(@sizeOf(U) == 0);
    try expect(@alignOf(U) == 1);
}

test "empty extern union" {
    const U = extern union {};
    try expect(@sizeOf(U) == 0);
    try expect(@alignOf(U) == 1);
}

test "empty union passed as argument" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const U = union(enum) {
        fn f(u: @This()) void {
            switch (u) {}
        }
    };
    U.f(@as(U, undefined));
}

test "empty enum passed as argument" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const E = enum {
        fn f(e: @This()) void {
            switch (e) {}
        }
    };
    E.f(@as(E, undefined));
}
