const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.DebugFormatStackTraceContext) void {
    cases.addCase(.{
        .name = "hoyten",
        .source =
        \\ const std = @import("std");
        \\
        \\ noinline fn foo() void {
        \\     std.debug.dumpCurrentStackTrace(@returnAddress());
        \\ }
        \\
        \\ noinline fn bar() void {
        \\     return foo();
        \\ }
        \\
        \\ pub fn main() !void {
        \\     std.mem.doNotOptimizeAway(bar());
        \\ }
        ,
        .symbols = .{
            .expect =
            \\???:?:?: [address] in source.bar (???)
            \\???:?:?: [address] in source.main (???)
            \\
            ,
        },
        .dwarf32 = .{
            .expect =
            \\source.zig:8:16: [address] in bar (test)
            \\     return foo();
            \\               ^
            \\source.zig:12:35: [address] in main (test)
            \\     std.mem.doNotOptimizeAway(bar());
            \\                                  ^
            \\
            ,
        },
    });
}
