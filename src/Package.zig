pub const Table = std.StringHashMapUnmanaged(*Package);

root_src_directory: Compilation.Directory,
/// Relative to `root_src_directory`. May contain path separators.
root_src_path: []const u8,
table: Table = .{},
parent: ?*Package = null,

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Package = @This();
const Compilation = @import("Compilation.zig");

/// No references to `root_src_dir` and `root_src_path` are kept.
pub fn create(
    gpa: *Allocator,
    base_directory: Compilation.Directory,
    /// Relative to `base_directory`.
    root_src_dir: []const u8,
    /// Relative to `root_src_dir`.
    root_src_path: []const u8,
) !*Package {
    const ptr = try gpa.create(Package);
    errdefer gpa.destroy(ptr);

    const root_src_dir_path = try base_directory.join(gpa, &[_][]const u8{root_src_dir});
    errdefer gpa.free(root_src_dir_path);

    const root_src_path_dupe = try mem.dupe(gpa, u8, root_src_path);
    errdefer gpa.free(root_src_path_dupe);

    ptr.* = .{
        .root_src_directory = .{
            .path = root_src_dir_path,
            .handle = try base_directory.handle.openDir(root_src_dir, .{}),
        },
        .root_src_path = root_src_path_dupe,
    };
    return ptr;
}

pub fn destroy(pkg: *Package, gpa: *Allocator) void {
    pkg.root_src_directory.handle.close();
    gpa.free(pkg.root_src_path);
    if (pkg.root_src_directory.path) |p| gpa.free(p);
    {
        var it = pkg.table.iterator();
        while (it.next()) |kv| {
            gpa.free(kv.key);
        }
    }
    pkg.table.deinit(gpa);
    gpa.destroy(pkg);
}

pub fn add(pkg: *Package, gpa: *Allocator, name: []const u8, package: *Package) !void {
    try pkg.table.ensureCapacity(gpa, pkg.table.items().len + 1);
    const name_dupe = try mem.dupe(gpa, u8, name);
    pkg.table.putAssumeCapacityNoClobber(name_dupe, package);
}
