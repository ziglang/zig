const std = @import("std");
const mem = std.mem;
const Compilation = @import("Compilation.zig");

const StringToIdMap = std.StringHashMapUnmanaged(StringId);

pub const StringId = enum(u32) {
    empty,
    _,
};

pub const TypeMapper = struct {
    const LookupSpeed = enum {
        fast,
        slow,
    };

    data: union(LookupSpeed) {
        fast: []const []const u8,
        slow: *const StringToIdMap,
    },

    pub fn lookup(self: TypeMapper, string_id: StringInterner.StringId) []const u8 {
        if (string_id == .empty) return "";
        switch (self.data) {
            .fast => |arr| return arr[@intFromEnum(string_id)],
            .slow => |map| {
                var it = map.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* == string_id) return entry.key_ptr.*;
                }
                unreachable;
            },
        }
    }

    pub fn deinit(self: TypeMapper, allocator: mem.Allocator) void {
        switch (self.data) {
            .slow => {},
            .fast => |arr| allocator.free(arr),
        }
    }
};

const StringInterner = @This();

string_table: StringToIdMap = .{},
next_id: StringId = @enumFromInt(@intFromEnum(StringId.empty) + 1),

pub fn deinit(self: *StringInterner, allocator: mem.Allocator) void {
    self.string_table.deinit(allocator);
}

pub fn intern(comp: *Compilation, str: []const u8) !StringId {
    return comp.string_interner.internExtra(comp.gpa, str);
}

pub fn internExtra(self: *StringInterner, allocator: mem.Allocator, str: []const u8) !StringId {
    if (str.len == 0) return .empty;

    const gop = try self.string_table.getOrPut(allocator, str);
    if (gop.found_existing) return gop.value_ptr.*;

    defer self.next_id = @enumFromInt(@intFromEnum(self.next_id) + 1);
    gop.value_ptr.* = self.next_id;
    return self.next_id;
}

/// deinit for the returned TypeMapper is a no-op and does not need to be called
pub fn getSlowTypeMapper(self: *const StringInterner) TypeMapper {
    return TypeMapper{ .data = .{ .slow = &self.string_table } };
}

/// Caller must call `deinit` on the returned TypeMapper
pub fn getFastTypeMapper(self: *const StringInterner, allocator: mem.Allocator) !TypeMapper {
    var strings = try allocator.alloc([]const u8, @intFromEnum(self.next_id));
    var it = self.string_table.iterator();
    strings[0] = "";
    while (it.next()) |entry| {
        strings[@intFromEnum(entry.value_ptr.*)] = entry.key_ptr.*;
    }
    return TypeMapper{ .data = .{ .fast = strings } };
}
