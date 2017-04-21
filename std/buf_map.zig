const HashMap = @import("hash_map.zig").HashMap;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

/// BufMap copies keys and values before they go into the map, and
/// frees them when they get removed.
pub const BufMap = struct {
    hash_map: BufMapHashMap,

    const BufMapHashMap = HashMap([]const u8, []const u8, mem.hash_slice_u8, mem.eql_slice_u8);

    pub fn init(allocator: &Allocator) -> BufMap {
        var self = BufMap {
            .hash_map = BufMapHashMap.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: &BufMap) {
        var it = self.hash_map.iterator();
        while (true) {
            const entry = it.next() ?? break; 
            self.free(entry.key);
            self.free(entry.value);
        }

        self.hash_map.deinit();
    }

    pub fn set(self: &BufMap, key: []const u8, value: []const u8) -> %void {
        if (const entry ?= self.hash_map.get(key)) {
            const value_copy = %return self.copy(value);
            %defer self.free(value_copy);
            %return self.hash_map.put(key, value_copy);
            self.free(entry.value);
        } else {
            const key_copy = %return self.copy(key);
            %defer self.free(key_copy);
            const value_copy = %return self.copy(value);
            %defer self.free(value_copy);
            %return self.hash_map.put(key_copy, value_copy);
        }
    }

    pub fn delete(self: &BufMap, key: []const u8) {
        const entry = self.hash_map.remove(key) ?? return;
        self.free(entry.key);
        self.free(entry.value);
    }

    pub fn count(self: &const BufMap) -> usize {
        return self.hash_map.size;
    }

    pub fn iterator(self: &const BufMap) -> BufMapHashMap.Iterator {
        return self.hash_map.iterator();
    }

    fn free(self: &BufMap, value: []const u8) {
        // remove the const
        const mut_value = @ptrCast(&u8, value.ptr)[0...value.len];
        self.hash_map.allocator.free(mut_value);
    }

    fn copy(self: &BufMap, value: []const u8) -> %[]const u8 {
        const result = %return self.hash_map.allocator.alloc(u8, value.len);
        mem.copy(u8, result, value);
        return result;
    }
};
