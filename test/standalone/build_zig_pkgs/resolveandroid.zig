const std = @import("std");

pub fn main() !u8 {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    const zig_exe = args[1];
    const child = try std.ChildProcess.init(&[_][]const u8 {
        zig_exe, "build",
        "--pkg-begin", "androidbuild", "androidbuild.zig", "--pkg-end",
    }, std.heap.page_allocator);
    defer child.deinit();
    switch (try child.spawnAndWait()) {
        .Exited => |e| return if (e == 0) 0 else 0xff,
        else => |e| {
            std.debug.print("Error: zig build process failed with {}\n", .{e});
            return error.ZigBuildFailed;
        },
    }
}
