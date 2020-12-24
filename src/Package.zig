const Package = @This();

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Allocator = mem.Allocator;

const Compilation = @import("Compilation.zig");

pub const Table = std.StringHashMapUnmanaged(*Package);

root_src_directory: Compilation.Directory,
/// Relative to `root_src_directory`. May contain path separators.
root_src_path: []const u8,
table: Table = .{},
parent: ?*Package = null,

/// Allocate a Package. No references to the slices passed are kept.
pub fn create(
    gpa: *Allocator,
    /// Null indicates the current working directory
    root_src_dir_path: ?[]const u8,
    /// Relative to root_src_dir_path
    root_src_path: []const u8,
) !*Package {
    const ptr = try gpa.create(Package);
    errdefer gpa.destroy(ptr);

    const owned_dir_path = if (root_src_dir_path) |p| try gpa.dupe(u8, p) else null;
    errdefer if (owned_dir_path) |p| gpa.free(p);

    const owned_src_path = try gpa.dupe(u8, root_src_path);
    errdefer gpa.free(owned_src_path);

    ptr.* = .{
        .root_src_directory = .{
            .path = owned_dir_path,
            .handle = if (owned_dir_path) |p| try fs.cwd().openDir(p, .{}) else fs.cwd(),
        },
        .root_src_path = owned_src_path,
    };

    return ptr;
}

/// Free all memory associated with this package and recursively call destroy
/// on all packages in its table
pub fn destroy(pkg: *Package, gpa: *Allocator) void {
    gpa.free(pkg.root_src_path);

    // If root_src_directory.path is null then the handle is the cwd()
    // which shouldn't be closed.
    if (pkg.root_src_directory.path) |p| {
        gpa.free(p);
        pkg.root_src_directory.handle.close();
    }

    {
        var it = pkg.table.iterator();
        while (it.next()) |kv| {
            kv.value.destroy(gpa);
            gpa.free(kv.key);
        }
    }

    pkg.table.deinit(gpa);
    gpa.destroy(pkg);
}

pub fn add(pkg: *Package, gpa: *Allocator, name: []const u8, package: *Package) !void {
    try pkg.table.ensureCapacity(gpa, pkg.table.count() + 1);
    const name_dupe = try mem.dupe(gpa, u8, name);
    pkg.table.putAssumeCapacityNoClobber(name_dupe, package);
}
