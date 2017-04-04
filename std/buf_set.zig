const HashMap = @import("hash_map.zig").HashMap;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub const BufSet = struct {
    hash_map: BufSetHashMap,

    const BufSetHashMap = HashMap([]const u8, void, mem.hash_slice_u8, mem.eql_slice_u8);

    pub fn init(allocator: &Allocator) -> BufSet {
        var self = BufSet {
            .hash_map = undefined,
        };
        self.hash_map.init(allocator);
        return self;
    }

    pub fn deinit(self: &BufSet) {
        var it = self.hash_map.entryIterator();
        while (true) {
            const entry = it.next() ?? break; 
            self.free(entry.key);
        }

        self.hash_map.deinit();
    }

    pub fn put(self: &BufSet, key: []const u8) -> %void {
        if (self.hash_map.get(key) == null) {
            const key_copy = %return self.copy(key);
            %defer self.free(key_copy);
            %return self.hash_map.put(key_copy, {});
        }
    }

    pub fn delete(self: &BufSet, key: []const u8) {
        const entry = self.hash_map.remove(key) ?? return;
        self.free(entry.key);
    }

    pub fn count(self: &const BufSet) -> usize {
        return self.hash_map.size;
    }

    pub fn iterator(self: &const BufSet) -> BufSetHashMap.Iterator {
        return self.hash_map.entryIterator();
    }

    fn free(self: &BufSet, value: []const u8) {
        // remove the const
        const mut_value = @ptrcast(&u8, value.ptr)[0...value.len];
        self.hash_map.allocator.free(mut_value);
    }

    fn copy(self: &BufSet, value: []const u8) -> %[]const u8 {
        const result = %return self.hash_map.allocator.alloc(u8, value.len);
        mem.copy(u8, result, value);
        return result;
    }
};

