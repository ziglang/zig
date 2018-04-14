const std = @import("index.zig");
const HashMap = std.HashMap;
const mem = std.mem;
const Allocator = mem.Allocator;
const string = std.string;

pub const BufSet = struct {
    hash_map: BufSetHashMap,

    const BufSetHashMap = HashMap([]const u8, void, string.hashStr, string.strEql);

    pub fn init(a: &Allocator) BufSet {
        var self = BufSet {
            .hash_map = BufSetHashMap.init(a),
        };
        return self;
    }

    pub fn deinit(self: &BufSet) void {
        var it = self.hash_map.iterator();
        while (true) {
            const entry = it.next() ?? break; 
            self.free(entry.key);
        }

        self.hash_map.deinit();
    }

    pub fn put(self: &BufSet, key: []const u8) !void {
        if (self.hash_map.get(key) == null) {
            const key_copy = try self.copy(key);
            errdefer self.free(key_copy);
            _ = try self.hash_map.put(key_copy, {});
        }
    }

    pub fn delete(self: &BufSet, key: []const u8) void {
        const entry = self.hash_map.remove(key) ?? return;
        self.free(entry.key);
    }

    pub fn count(self: &const BufSet) usize {
        return self.hash_map.size;
    }

    pub fn iterator(self: &const BufSet) BufSetHashMap.Iterator {
        return self.hash_map.iterator();
    }

    pub fn allocator(self: &const BufSet) &Allocator {
        return self.hash_map.allocator;
    }

    fn free(self: &BufSet, value: []const u8) void {
        self.hash_map.allocator.free(value);
    }

    fn copy(self: &BufSet, value: []const u8) ![]const u8 {
        const result = try self.hash_map.allocator.alloc(u8, value.len);
        mem.copy(u8, result, value);
        return result;
    }
};

