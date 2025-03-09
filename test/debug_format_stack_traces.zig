const std = @import("std");
const os = std.os;
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.DebugFormatStackTraceContext) void {
    cases.addCase(.{
        .name = "hoyten",
        .source =
        \\ const std = @import("std");
        \\
        \\ noinline fn foo(x: u32) u32 {
        \\     return x * x;
        \\ }
        \\
        \\ noinline fn bar() u32 {
        \\     return foo(std.math.maxInt(u32));
        \\ }
        \\
        \\ pub fn main() !void {
        \\     std.debug.print("{}", .{bar()});
        \\ }
        ,
        .symbols = .{
            .exclude_os = &.{ .macos, .windows },
            // release modes won't check for overflow, so no error occurs
            .exclude_optimize_mode = &.{ .ReleaseFast, .ReleaseSmall },
            .expect_panic = true,
            .expect =
            \\thread [thread_id] panic: integer overflow
            \\???:?:?: [address] in source.foo (???)
            \\???:?:?: [address] in source.bar (???)
            \\???:?:?: [address] in source.main (???)
            \\
            ,
        },
        .dwarf32 = .{
            // release modes won't check for overflow, so no error occurs
            .exclude_optimize_mode = &.{ .ReleaseFast, .ReleaseSmall },
            .expect_panic = true,
            .expect =
            \\thread [thread_id] panic: integer overflow
            \\source.zig:4:15: [address] in foo (test)
            \\     return x * x;
            \\              ^
            \\source.zig:8:16: [address] in bar (test)
            \\     return foo(std.math.maxInt(u32));
            \\               ^
            \\source.zig:12:33: [address] in main (test)
            \\     std.debug.print("{}", .{bar()});
            \\                                ^
            \\
            ,
        },
    });
}
