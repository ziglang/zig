const builtin = @import("builtin");
const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.StackTracesContext) void {
    const source_return =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    return error.TheSkyIsFalling;
        \\}
    ;
    const source_try_return =
        \\const std = @import("std");
        \\
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    try foo();
        \\}
    ;
    const source_try_try_return_return =
        \\const std = @import("std");
        \\
        \\fn foo() !void {
        \\    try bar();
        \\}
        \\
        \\fn bar() !void {
        \\    return make_error();
        \\}
        \\
        \\fn make_error() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    try foo();
        \\}
    ;
    // zig fmt: off
    switch (builtin.os) {
        .freebsd => {
            cases.addCase(
                "return",
                source_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in std.start.main (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try return",
                source_try_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in foo (test)
                    \\source.zig:8:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in std.start.main (test)
                    \\source.zig:8:5: [address] in std.start.main (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try try return return",
                source_try_try_return_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in make_error (test)
                    \\source.zig:8:5: [address] in bar (test)
                    \\source.zig:4:5: [address] in foo (test)
                    \\source.zig:16:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in std.start.main (test)
                    \\source.zig:8:5: [address] in std.start.main (test)
                    \\source.zig:4:5: [address] in std.start.main (test)
                    \\source.zig:16:5: [address] in std.start.main (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
        },
        .linux => {
            cases.addCase(
                "return",
                source_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in std.start.posixCallMainAndExit (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try return",
                source_try_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in foo (test)
                    \\source.zig:8:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in std.start.posixCallMainAndExit (test)
                    \\source.zig:8:5: [address] in std.start.posixCallMainAndExit (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try try return return",
                source_try_try_return_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in make_error (test)
                    \\source.zig:8:5: [address] in bar (test)
                    \\source.zig:4:5: [address] in foo (test)
                    \\source.zig:16:5: [address] in main (test)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in std.start.posixCallMainAndExit (test)
                    \\source.zig:8:5: [address] in std.start.posixCallMainAndExit (test)
                    \\source.zig:4:5: [address] in std.start.posixCallMainAndExit (test)
                    \\source.zig:16:5: [address] in std.start.posixCallMainAndExit (test)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
        },
        .macosx => {
            cases.addCase(
                "return",
                source_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in _main.0 (test.o)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in _main (test.o)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try return",
                source_try_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in _foo (test.o)
                    \\source.zig:8:5: [address] in _main.0 (test.o)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in _main (test.o)
                    \\source.zig:8:5: [address] in _main (test.o)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try try return return",
                source_try_try_return_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in _make_error (test.o)
                    \\source.zig:8:5: [address] in _bar (test.o)
                    \\source.zig:4:5: [address] in _foo (test.o)
                    \\source.zig:16:5: [address] in _main.0 (test.o)
                    \\
                ,
                // release-safe
                    \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in _main (test.o)
                    \\source.zig:8:5: [address] in _main (test.o)
                    \\source.zig:4:5: [address] in _main (test.o)
                    \\source.zig:16:5: [address] in _main (test.o)
                    \\
                ,
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
        },
        .windows => {
            cases.addCase(
                "return",
                source_return,
                [_][]const u8{
                // debug
                    \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in main (test.obj)
                    \\
                ,
                // release-safe
                // --disabled-- results in segmenetation fault
                "",
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try return",
                source_try_return,
                [_][]const u8{
                // debug
                \\error: TheSkyIsFalling
                    \\source.zig:4:5: [address] in foo (test.obj)
                    \\source.zig:8:5: [address] in main (test.obj)
                    \\
                ,
                // release-safe
                // --disabled-- results in segmenetation fault
                "",
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
            cases.addCase(
                "try try return return",
                source_try_try_return_return,
                [_][]const u8{
                // debug
                \\error: TheSkyIsFalling
                    \\source.zig:12:5: [address] in make_error (test.obj)
                    \\source.zig:8:5: [address] in bar (test.obj)
                    \\source.zig:4:5: [address] in foo (test.obj)
                    \\source.zig:16:5: [address] in main (test.obj)
                    \\
                ,
                // release-safe
                // --disabled-- results in segmenetation fault
                "",
                // release-fast
                    \\error: TheSkyIsFalling
                    \\
                ,
                // release-small
                    \\error: TheSkyIsFalling
                    \\
                },
            );
        },
        else => {},
    }
    // zig fmt: off
}
