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
            .exclude_os = .{
                .windows, // segfault
            },
            .expect = 
            \\error: TheSkyIsFalling
            \\source.zig:2:5: [address] in [function]
            \\    return error.TheSkyIsFalling;
            \\    ^
            \\
            ,
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
            .exclude_os = .{
                .windows, // segfault
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
            .exclude_os = .{
                .windows, // segfault
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
        .exclude_os = .{
            .windows,
        },
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
}
