const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Buffer = std.Buffer;

pub const Package = struct {
    root_src_dir: Buffer,
    root_src_path: Buffer,

    /// relative to root_src_dir
    table: Table,

    pub const Table = std.HashMap([]const u8, *Package, mem.hash_slice_u8, mem.eql_slice_u8);

    /// makes internal copies of root_src_dir and root_src_path
    /// allocator should be an arena allocator because Package never frees anything
    pub fn create(allocator: *mem.Allocator, root_src_dir: []const u8, root_src_path: []const u8) !*Package {
        return allocator.create(Package{
            .root_src_dir = try Buffer.init(allocator, root_src_dir),
            .root_src_path = try Buffer.init(allocator, root_src_path),
            .table = Table.init(allocator),
        });
    }

    pub fn add(self: *Package, name: []const u8, package: *Package) !void {
        const entry = try self.table.put(try mem.dupe(self.table.allocator, u8, name), package);
        assert(entry == null);
    }
};
