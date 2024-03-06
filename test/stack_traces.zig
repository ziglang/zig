const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.StackTracesContext) void {
    cases.addCase(.{
        .name = "return",
        .source =
        \\pub fn main() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in main (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "try return",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    try foo();
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in foo (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in main (test)
            \\    try foo();
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
            },
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in [function]
            \\    try foo();
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
    });
    cases.addCase(.{
        .name = "non-error return pops error trace",
        .source =
        \\fn bar() !void {
        \\    return error.UhOh;
        \\}
        \\
        \\fn foo() !void {
        \\    bar() catch {
        \\        return; // non-error result: success
        \\    };
        \\}
        \\
        \\pub fn main() !void {
        \\    try foo();
        \\    return error.UnrelatedError;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: UnrelatedError
            \\source.zig:13:5: [address] in main (test)
            \\    return error.UnrelatedError;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: UnrelatedError
            \\source.zig:13:5: [address] in [function]
            \\    return error.UnrelatedError;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: UnrelatedError
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: UnrelatedError
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "continue in while loop",
        .source =
        \\fn foo() !void {
        \\    return error.UhOh;
        \\}
        \\
        \\pub fn main() !void {
        \\    var i: usize = 0;
        \\    while (i < 3) : (i += 1) {
        \\        foo() catch continue;
        \\    }
        \\    return error.UnrelatedError;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: UnrelatedError
            \\source.zig:10:5: [address] in main (test)
            \\    return error.UnrelatedError;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: UnrelatedError
            \\source.zig:10:5: [address] in [function]
            \\    return error.UnrelatedError;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: UnrelatedError
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: UnrelatedError
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "try return + handled catch/if-else",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    foo() catch {}; // should not affect error trace
        \\    if (foo()) |_| {} else |_| {
        \\        // should also not affect error trace
        \\    }
        \\    try foo();
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in foo (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:10:5: [address] in main (test)
            \\    try foo();
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:10:5: [address] in [function]
            \\    try foo();
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "break from inline loop pops error return trace",
        .source =
        \\fn foo() !void { return error.FooBar; }
        \\
        \\pub fn main() !void {
        \\    comptime var i: usize = 0;
        \\    b: inline while (i < 5) : (i += 1) {
        \\        foo() catch {
        \\            break :b; // non-error break, success
        \\        };
        \\    }
        \\    // foo() was successfully handled, should not appear in trace
        \\
        \\    return error.BadTime;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: BadTime
            \\source.zig:12:5: [address] in main (test)
            \\    return error.BadTime;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: BadTime
            \\source.zig:12:5: [address] in [function]
            \\    return error.BadTime;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: BadTime
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: BadTime
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "catch and re-throw error",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    return foo() catch error.AndMyCarIsOutOfGas;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in foo (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in main (test)
            \\    return foo() catch error.AndMyCarIsOutOfGas;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in [function]
            \\    return foo() catch error.AndMyCarIsOutOfGas;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "errors stored in var do not contribute to error trace",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\pub fn main() !void {
        \\    // Once an error is stored in a variable, it is popped from the trace
        \\    var x = foo();
        \\    x = {};
        \\
        \\    // As a result, this error trace will still be clean
        \\    return error.SomethingUnrelatedWentWrong;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: SomethingUnrelatedWentWrong
            \\source.zig:11:5: [address] in main (test)
            \\    return error.SomethingUnrelatedWentWrong;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: SomethingUnrelatedWentWrong
            \\source.zig:11:5: [address] in [function]
            \\    return error.SomethingUnrelatedWentWrong;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: SomethingUnrelatedWentWrong
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: SomethingUnrelatedWentWrong
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "error stored in const has trace preserved for duration of block",
        .source =
        \\fn foo() !void { return error.TheSkyIsFalling; }
        \\fn bar() !void { return error.InternalError; }
        \\fn baz() !void { return error.UnexpectedReality; }
        \\
        \\pub fn main() !void {
        \\    const x = foo();
        \\    const y = b: {
        \\        if (true)
        \\            break :b bar();
        \\
        \\        break :b {};
        \\    };
        \\    x catch {};
        \\    y catch {};
        \\    // foo()/bar() error traces not popped until end of block
        \\
        \\    {
        \\        const z = baz();
        \\        z catch {};
        \\        // baz() error trace still alive here
        \\    }
        \\    // baz() error trace popped, foo(), bar() still alive
        \\    return error.StillUnresolved;
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: StillUnresolved
            \\source.zig:1:18: [address] in foo (test)
            \\fn foo() !void { return error.TheSkyIsFalling; }
            \\                 ^
            \\source.zig:2:18: [address] in bar (test)
            \\fn bar() !void { return error.InternalError; }
            \\                 ^
            \\source.zig:23:5: [address] in main (test)
            \\    return error.StillUnresolved;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: StillUnresolved
            \\source.zig:1:18: [address] in [function]
            \\fn foo() !void { return error.TheSkyIsFalling; }
            \\                 ^
            \\source.zig:2:18: [address] in [function]
            \\fn bar() !void { return error.InternalError; }
            \\                 ^
            \\source.zig:23:5: [address] in [function]
            \\    return error.StillUnresolved;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: StillUnresolved
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: StillUnresolved
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "error passed to function has its trace preserved for duration of the call",
        .source =
        \\pub fn expectError(expected_error: anyerror, actual_error: anyerror!void) !void {
        \\    actual_error catch |err| {
        \\        if (err == expected_error) return {};
        \\    };
        \\    return error.TestExpectedError;
        \\}
        \\
        \\fn alwaysErrors() !void { return error.ThisErrorShouldNotAppearInAnyTrace; }
        \\fn foo() !void { return error.Foo; }
        \\
        \\pub fn main() !void {
        \\    try expectError(error.ThisErrorShouldNotAppearInAnyTrace, alwaysErrors());
        \\    try expectError(error.ThisErrorShouldNotAppearInAnyTrace, alwaysErrors());
        \\    try expectError(error.Foo, foo());
        \\
        \\    // Only the error trace for this failing check should appear:
        \\    try expectError(error.Bar, foo());
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: TestExpectedError
            \\source.zig:9:18: [address] in foo (test)
            \\fn foo() !void { return error.Foo; }
            \\                 ^
            \\source.zig:5:5: [address] in expectError (test)
            \\    return error.TestExpectedError;
            \\    ^
            \\source.zig:17:5: [address] in main (test)
            \\    try expectError(error.Bar, foo());
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
            },
            .expect =
            \\error: TestExpectedError
            \\source.zig:9:18: [address] in [function]
            \\fn foo() !void { return error.Foo; }
            \\                 ^
            \\source.zig:5:5: [address] in [function]
            \\    return error.TestExpectedError;
            \\    ^
            \\source.zig:17:5: [address] in [function]
            \\    try expectError(error.Bar, foo());
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TestExpectedError
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TestExpectedError
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "try return from within catch",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\fn bar() !void {
        \\    return error.AndMyCarIsOutOfGas;
        \\}
        \\
        \\pub fn main() !void {
        \\    foo() catch { // error trace should include foo()
        \\        try bar();
        \\    };
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in foo (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in bar (test)
            \\    return error.AndMyCarIsOutOfGas;
            \\    ^
            \\source.zig:11:9: [address] in main (test)
            \\        try bar();
            \\        ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
            },
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in [function]
            \\    return error.AndMyCarIsOutOfGas;
            \\    ^
            \\source.zig:11:9: [address] in [function]
            \\        try bar();
            \\        ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "try return from within if-else",
        .source =
        \\fn foo() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\fn bar() !void {
        \\    return error.AndMyCarIsOutOfGas;
        \\}
        \\
        \\pub fn main() !void {
        \\    if (foo()) |_| {} else |_| { // error trace should include foo()
        \\        try bar();
        \\    }
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in foo (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in bar (test)
            \\    return error.AndMyCarIsOutOfGas;
            \\    ^
            \\source.zig:11:9: [address] in main (test)
            \\        try bar();
            \\        ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
            },
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in [function]
            \\    return error.AndMyCarIsOutOfGas;
            \\    ^
            \\source.zig:11:9: [address] in [function]
            \\        try bar();
            \\        ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: AndMyCarIsOutOfGas
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "try try return return",
        .source =
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
        ,
        .Debug = .{
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:10:5: [address] in make_error (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in bar (test)
            \\    return make_error();
            \\    ^
            \\source.zig:2:5: [address] in foo (test)
            \\    try bar();
            \\    ^
            \\source.zig:14:5: [address] in main (test)
            \\    try foo();
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
            },
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:10:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\source.zig:6:5: [address] in [function]
            \\    return make_error();
            \\    ^
            \\source.zig:2:5: [address] in [function]
            \\    try bar();
            \\    ^
            \\source.zig:14:5: [address] in [function]
            \\    try foo();
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
    });

    cases.addCase(.{
        .name = "dumpCurrentStackTrace",
        .source =
        \\const std = @import("std");
        \\
        \\fn bar() void {
        \\    std.debug.dumpCurrentStackTrace(@returnAddress());
        \\}
        \\fn foo() void {
        \\    bar();
        \\}
        \\pub fn main() u8 {
        \\    foo();
        \\    return 1;
        \\}
        ,
        .Debug = .{
            .exclude_os = &.{
                .openbsd, // integer overflow
                .windows, // TODO intermittent failures
            },
            .expect =
            \\source.zig:7:8: [address] in foo (test)
            \\    bar();
            \\       ^
            \\source.zig:10:8: [address] in main (test)
            \\    foo();
            \\       ^
            \\
            ,
        },
    });
    cases.addCase(.{
        .name = "error union switch with call operand",
        .source =
        \\pub fn main() !void {
        \\    try foo();
        \\    return error.TheSkyIsFalling;
        \\}
        \\
        \\noinline fn failure() error{ Fatal, NonFatal }!void {
        \\    return error.NonFatal;
        \\}
        \\
        \\fn foo() error{Fatal}!void {
        \\    return failure() catch |err| switch (err) {
        \\        error.Fatal => return error.Fatal,
        \\        error.NonFatal => return,
        \\    };
        \\}
        ,
        .Debug = .{
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:3:5: [address] in main (test)
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\
            ,
        },
        .ReleaseSafe = .{
            .exclude_os = &.{
                .windows, // TODO
                .linux, // defeated by aggressive inlining
            },
            .expect =
            \\error: TheSkyIsFalling
            \\source.zig:3:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\
            ,
            .error_tracing = true,
        },
        .ReleaseFast = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
        .ReleaseSmall = .{
            .expect =
            \\error: TheSkyIsFalling
            \\
            ,
        },
    });
}
