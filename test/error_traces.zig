pub fn addCases(cases: *@import("tests.zig").ErrorTracesContext) void {
    cases.addCase(.{
        .name = "return",
        .source =
        \\pub fn main() !void {
        \\    return error.TheSkyIsFalling;
        \\}
        ,
        .expect_error = "TheSkyIsFalling",
        .expect_trace =
        \\source.zig:2:5: [address] in main
        \\    return error.TheSkyIsFalling;
        \\    ^
        ,
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
        .expect_error = "TheSkyIsFalling",
        .expect_trace =
        \\source.zig:2:5: [address] in foo
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:6:5: [address] in main
        \\    try foo();
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "UnrelatedError",
        .expect_trace =
        \\source.zig:13:5: [address] in main
        \\    return error.UnrelatedError;
        \\    ^
        ,
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
        .expect_error = "UnrelatedError",
        .expect_trace =
        \\source.zig:10:5: [address] in main
        \\    return error.UnrelatedError;
        \\    ^
        ,
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
        .expect_error = "TheSkyIsFalling",
        .expect_trace =
        \\source.zig:2:5: [address] in foo
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:10:5: [address] in main
        \\    try foo();
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "BadTime",
        .expect_trace =
        \\source.zig:12:5: [address] in main
        \\    return error.BadTime;
        \\    ^
        ,
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
        .expect_error = "AndMyCarIsOutOfGas",
        .expect_trace =
        \\source.zig:2:5: [address] in foo
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:6:5: [address] in main
        \\    return foo() catch error.AndMyCarIsOutOfGas;
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "SomethingUnrelatedWentWrong",
        .expect_trace =
        \\source.zig:11:5: [address] in main
        \\    return error.SomethingUnrelatedWentWrong;
        \\    ^
        ,
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
        .expect_error = "StillUnresolved",
        .expect_trace =
        \\source.zig:1:18: [address] in foo
        \\fn foo() !void { return error.TheSkyIsFalling; }
        \\                 ^
        \\source.zig:2:18: [address] in bar
        \\fn bar() !void { return error.InternalError; }
        \\                 ^
        \\source.zig:23:5: [address] in main
        \\    return error.StillUnresolved;
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "TestExpectedError",
        .expect_trace =
        \\source.zig:9:18: [address] in foo
        \\fn foo() !void { return error.Foo; }
        \\                 ^
        \\source.zig:5:5: [address] in expectError
        \\    return error.TestExpectedError;
        \\    ^
        \\source.zig:17:5: [address] in main
        \\    try expectError(error.Bar, foo());
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "AndMyCarIsOutOfGas",
        .expect_trace =
        \\source.zig:2:5: [address] in foo
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:6:5: [address] in bar
        \\    return error.AndMyCarIsOutOfGas;
        \\    ^
        \\source.zig:11:9: [address] in main
        \\        try bar();
        \\        ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "AndMyCarIsOutOfGas",
        .expect_trace =
        \\source.zig:2:5: [address] in foo
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:6:5: [address] in bar
        \\    return error.AndMyCarIsOutOfGas;
        \\    ^
        \\source.zig:11:9: [address] in main
        \\        try bar();
        \\        ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "TheSkyIsFalling",
        .expect_trace =
        \\source.zig:10:5: [address] in make_error
        \\    return error.TheSkyIsFalling;
        \\    ^
        \\source.zig:6:5: [address] in bar
        \\    return make_error();
        \\    ^
        \\source.zig:2:5: [address] in foo
        \\    try bar();
        \\    ^
        \\source.zig:14:5: [address] in main
        \\    try foo();
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
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
        .expect_error = "TheSkyIsFalling",
        .expect_trace =
        \\source.zig:3:5: [address] in main
        \\    return error.TheSkyIsFalling;
        \\    ^
        ,
        .disable_trace_optimized = &.{
            .{ .x86_64, .linux },
            .{ .x86, .linux },
            .{ .aarch64, .linux },
            .{ .x86_64, .windows },
            .{ .x86, .windows },
            .{ .x86_64, .macos },
            .{ .aarch64, .macos },
        },
    });
}
