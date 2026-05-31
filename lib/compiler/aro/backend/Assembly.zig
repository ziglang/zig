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
    var file_writer = file.writer(&.{});

    var buffers = [_][]const u8{ self.data, self.text };
    try file_writer.interface.writeSplatAll(&buffers, 1);
}
