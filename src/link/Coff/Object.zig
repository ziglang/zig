const Object = @This();

const std = @import("std");
const mem = std.mem;

const Allocator = mem.Allocator;

name: []const u8,

pub fn deinit(self: *Object, gpa: Allocator) void {
    gpa.free(self.name);
}
