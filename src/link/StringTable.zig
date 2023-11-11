buffer: std.ArrayListUnmanaged(u8) = .{},
table: std.HashMapUnmanaged(u32, void, StringIndexContext, std.hash_map.default_max_load_percentage) = .{},

pub fn deinit(self: *Self, gpa: Allocator) void {
    self.buffer.deinit(gpa);
    self.table.deinit(gpa);
}

pub fn insert(self: *Self, gpa: Allocator, string: []const u8) !u32 {
    const gop = try self.table.getOrPutContextAdapted(gpa, @as([]const u8, string), StringIndexAdapter{
        .bytes = &self.buffer,
    }, StringIndexContext{
        .bytes = &self.buffer,
    });
    if (gop.found_existing) return gop.key_ptr.*;

    try self.buffer.ensureUnusedCapacity(gpa, string.len + 1);
    const new_off = @as(u32, @intCast(self.buffer.items.len));

    self.buffer.appendSliceAssumeCapacity(string);
    self.buffer.appendAssumeCapacity(0);

    gop.key_ptr.* = new_off;

    return new_off;
}

pub fn getOffset(self: *Self, string: []const u8) ?u32 {
    return self.table.getKeyAdapted(string, StringIndexAdapter{
        .bytes = &self.buffer,
    });
}

pub fn get(self: Self, off: u32) ?[:0]const u8 {
    if (off >= self.buffer.items.len) return null;
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.buffer.items.ptr + off)), 0);
}

pub fn getAssumeExists(self: Self, off: u32) [:0]const u8 {
    return self.get(off) orelse unreachable;
}

const std = @import("std");
const mem = std.mem;

const Allocator = mem.Allocator;
const Self = @This();
const StringIndexAdapter = std.hash_map.StringIndexAdapter;
const StringIndexContext = std.hash_map.StringIndexContext;
