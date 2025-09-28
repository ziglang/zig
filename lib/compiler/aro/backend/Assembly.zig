const std = @import("std");
const Allocator = std.mem.Allocator;

data: []const u8,
text: []const u8,

const Assembly = @This();

pub fn deinit(self: *const Assembly, gpa: Allocator) void {
    gpa.free(self.data);
    gpa.free(self.text);
}

pub fn writeToFile(self: Assembly, file: std.fs.File) !void {
    var vec: [2]std.posix.iovec_const = .{
        .{ .base = self.data.ptr, .len = self.data.len },
        .{ .base = self.text.ptr, .len = self.text.len },
    };
    return file.writevAll(&vec);
}
