pub const Table = std.StringHashMap(*Package);

/// This should be used for file operations.
root_src_dir: std.fs.Dir,
/// This is for metadata purposes, for example putting into debug information.
root_src_dir_path: []u8,
/// Relative to `root_src_dir` and `root_src_dir_path`.
root_src_path: []u8,
table: Table,

/// No references to `root_src_dir` and `root_src_path` are kept.
pub fn create(
    allocator: *mem.Allocator,
    base_dir: std.fs.Dir,
    /// Relative to `base_dir`.
    root_src_dir: []const u8,
    /// Relative to `root_src_dir`.
    root_src_path: []const u8,
) !*Package {
    const ptr = try allocator.create(Package);
    errdefer allocator.destroy(ptr);
    const root_src_path_dupe = try mem.dupe(allocator, u8, root_src_path);
    errdefer allocator.free(root_src_path_dupe);
    const root_src_dir_path = try mem.dupe(allocator, u8, root_src_dir);
    errdefer allocator.free(root_src_dir_path);
    ptr.* = .{
        .root_src_dir = try base_dir.openDir(root_src_dir, .{}),
        .root_src_dir_path = root_src_dir_path,
        .root_src_path = root_src_path_dupe,
        .table = Table.init(allocator),
    };
    return ptr;
}

pub fn destroy(self: *Package) void {
    const allocator = self.table.allocator;
    self.root_src_dir.close();
    allocator.free(self.root_src_path);
    allocator.free(self.root_src_dir_path);
    {
        var it = self.table.iterator();
        while (it.next()) |kv| {
            allocator.free(kv.key);
        }
    }
    self.table.deinit();
    allocator.destroy(self);
}

pub fn add(self: *Package, name: []const u8, package: *Package) !void {
    try self.table.ensureCapacity(self.table.items().len + 1);
    const name_dupe = try mem.dupe(self.table.allocator, u8, name);
    self.table.putAssumeCapacityNoClobber(name_dupe, package);
}

const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Package = @This();
