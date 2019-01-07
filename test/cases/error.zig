const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const mem = std.mem;
const builtin = @import("builtin");

test "error union peer type resolution" {
    testErrorUnionPeerTypeResolution(1);
    comptime testErrorUnionPeerTypeResolution(1);
}

fn testErrorUnionPeerTypeResolution(x: i32) void {
    const y = switch (x) {
        1 => bar_1(),
        2 => baz_1(),
        else => quux_1(),
    };
}

fn bar_1() anyerror {
    return error.A;
}

fn baz_1() !i32 {
    return error.B;
}

fn quux_1() !i32 {
    return error.C;
}

test "error: Zero sized error set returned with value payload crash" {
    _ = foo3(0);
    _ = comptime foo3(0);
}

const Error = error{};
fn foo3(b: usize) Error!usize {
    return b;
}

test "error: Infer error set from literals" {
    _ = nullLiteral("n") catch |err| handleErrors(err);
    _ = floatLiteral("n") catch |err| handleErrors(err);
    _ = intLiteral("n") catch |err| handleErrors(err);
    _ = comptime nullLiteral("n") catch |err| handleErrors(err);
    _ = comptime floatLiteral("n") catch |err| handleErrors(err);
    _ = comptime intLiteral("n") catch |err| handleErrors(err);
}

fn handleErrors(err: var) noreturn {
    switch (err) {
        error.T => {},
    }

    unreachable;
}

fn nullLiteral(str: []const u8) !?i64 {
    if (str[0] == 'n') return null;

    return error.T;
}

fn floatLiteral(str: []const u8) !?f64 {
    if (str[0] == 'n') return 1.0;

    return error.T;
}

fn intLiteral(str: []const u8) !?i64 {
    if (str[0] == 'n') return 1;

    return error.T;
}
