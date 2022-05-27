const std = @import("std");
const testing = std.testing;
pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!general_purpose_allocator.deinit());
    const gpa = general_purpose_allocator.allocator();
    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit(); // no-op unless WASI or Windows
    _ = it.next() orelse unreachable; // skip binary name
    const zig_compiler = it.next() orelse unreachable;
    std.debug.print("zig_compiler: {s}\n", .{zig_compiler});
    var child_process = std.ChildProcess.init(
        &[_][]const u8{ zig_compiler, "fmt", "--stdin" },
        gpa,
    );
    child_process.stdin_behavior = .Pipe;
    child_process.stdout_behavior = .Pipe;
    try child_process.spawn();
    const input_program =
        \\ const std = @import("std");
        \\ pub fn main() void {
        \\ std.debug.print("Hello World", .{});
        \\ }
    ;
    try child_process.stdin.?.writer().writeAll(input_program);
    child_process.stdin.?.close();
    child_process.stdin = null;

    const out_bytes = try child_process.stdout.?.reader().readAllAlloc(gpa, std.math.maxInt(usize));
    defer gpa.free(out_bytes);

    switch (try child_process.wait()) {
        .Exited => |code| if (code == 0) {
            const expected_program =
                \\const std = @import("std");
                \\pub fn main() void {
                \\    std.debug.print("Hello World", .{});
                \\}
                \\
            ;
            try testing.expectEqualStrings(expected_program, out_bytes);
        },
        else => unreachable,
    }
}
