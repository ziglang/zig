const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const self_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(self_path);

    var self_exe = try std.fs.openSelfExe(.{});
    defer self_exe.close();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const self_exe_path = try std.os.getFdPath(self_exe.handle, &buf);

    try std.testing.expectEqualStrings(self_exe_path, self_path);
}
