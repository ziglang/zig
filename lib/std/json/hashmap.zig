const std = @import("std");
const Allocator = std.mem.Allocator;

const ParseOptions = @import("static.zig").ParseOptions;
const innerParse = @import("static.zig").innerParse;
const innerParseFromValue = @import("static.zig").innerParseFromValue;
const Value = @import("dynamic.zig").Value;
const StringifyOptions = @import("stringify.zig").StringifyOptions;
const stringify = @import("stringify.zig").stringify;
const encodeJsonString = @import("stringify.zig").encodeJsonString;

/// A thin wrapper around `std.StringArrayHashMapUnmanaged` that implements
/// `jsonParse`, `jsonParseFromValue`, and `jsonStringify`.
/// This is useful when your JSON schema has an object with arbitrary data keys
/// instead of comptime-known struct field names.
pub fn ArrayHashMap(comptime T: type) type {
    return struct {
        map: std.StringArrayHashMapUnmanaged(T) = .{},

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.map.deinit(allocator);
        }

        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            var map = std.StringArrayHashMapUnmanaged(T){};
            errdefer map.deinit(allocator);

            if (.object_begin != try source.next()) return error.UnexpectedToken;
            while (true) {
                const token = try source.nextAlloc(allocator, .alloc_if_needed);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        const gop = try map.getOrPut(allocator, k);
                        if (token == .allocated_string) {
                            // Free the key before recursing in case we're using an allocator
                            // that optimizes freeing the last allocated object.
                            allocator.free(k);
                        }
                        if (gop.found_existing) {
                            switch (options.duplicate_field_behavior) {
                                .use_first => {
                                    // Parse and ignore the redundant value.
                                    // We don't want to skip the value, because we want type checking.
                                    _ = try innerParse(T, allocator, source, options);
                                    continue;
                                },
                                .@"error" => return error.DuplicateField,
                                .use_last => {},
                            }
                        }
                        gop.value_ptr.* = try innerParse(T, allocator, source, options);
                    },
                    .object_end => break,
                    else => unreachable,
                }
            }
            return .{ .map = map };
        }

        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            if (source != .object) return error.UnexpectedToken;

            var map = std.StringArrayHashMapUnmanaged(T){};
            errdefer map.deinit(allocator);

            var it = source.object.iterator();
            while (it.next()) |kv| {
                try map.put(allocator, kv.key_ptr.*, try innerParseFromValue(T, allocator, kv.value_ptr.*, options));
            }
            return .{ .map = map };
        }

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            var it = self.map.iterator();
            while (it.next()) |kv| {
                try jws.write(kv.key_ptr.*);
                try jws.write(kv.value_ptr.*);
            }
            try jws.endObject();
        }
    };
}

test {
    _ = @import("hashmap_test.zig");
}
