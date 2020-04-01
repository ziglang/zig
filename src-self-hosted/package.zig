const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const ArrayListSentineled = std.ArrayListSentineled;

pub const Package = struct {
    root_src_dir: ArrayListSentineled(u8, 0),
    root_src_path: ArrayListSentineled(u8, 0),

    /// relative to root_src_dir
    table: Table,

    pub const Table = std.StringHashMap(*Package);

    /// makes internal copies of root_src_dir and root_src_path
    /// allocator should be an arena allocator because Package never frees anything
    pub fn create(allocator: *mem.Allocator, root_src_dir: []const u8, root_src_path: []const u8) !*Package {
        const ptr = try allocator.create(Package);
        ptr.* = Package{
            .root_src_dir = try ArrayListSentineled(u8, 0).init(allocator, root_src_dir),
            .root_src_path = try ArrayListSentineled(u8, 0).init(allocator, root_src_path),
            .table = Table.init(allocator),
        };
        return ptr;
    }

    pub fn add(self: *Package, name: []const u8, package: *Package) !void {
        const entry = try self.table.put(try mem.dupe(self.table.allocator, u8, name), package);
        assert(entry == null);
    }
};
