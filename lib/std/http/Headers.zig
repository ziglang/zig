const std = @import("../std.zig");

const Allocator = std.mem.Allocator;

const testing = std.testing;
const ascii = std.ascii;
const assert = std.debug.assert;

pub const HeaderList = std.ArrayListUnmanaged(Field);
pub const HeaderIndexList = std.ArrayListUnmanaged(usize);
pub const HeaderIndex = std.HashMapUnmanaged([]const u8, HeaderIndexList, CaseInsensitiveStringContext, std.hash_map.default_max_load_percentage);

pub const CaseInsensitiveStringContext = struct {
    pub fn hash(self: @This(), s: []const u8) u64 {
        _ = self;
        var buf: [64]u8 = undefined;
        var i: u8 = 0;

        var h = std.hash.Wyhash.init(0);
        while (i < s.len) : (i += 64) {
            const left = @min(64, s.len - i);
            const ret = ascii.lowerString(buf[0..], s[i..][0..left]);
            h.update(ret);
        }

        return h.final();
    }

    pub fn eql(self: @This(), a: []const u8, b: []const u8) bool {
        _ = self;
        return ascii.eqlIgnoreCase(a, b);
    }
};

pub const Field = struct {
    name: []const u8,
    value: []const u8,

    fn lessThan(ctx: void, a: Field, b: Field) bool {
        _ = ctx;
        if (a.name.ptr == b.name.ptr) return false;

        return ascii.lessThanIgnoreCase(a.name, b.name);
    }
};

pub const Headers = struct {
    allocator: Allocator,
    list: HeaderList = .{},
    index: HeaderIndex = .{},

    /// When this is false, names and values will not be duplicated.
    /// Use with caution.
    owned: bool = true,

    pub fn init(allocator: Allocator) Headers {
        return .{ .allocator = allocator };
    }

    pub fn deinit(headers: *Headers) void {
        headers.deallocateIndexListsAndFields();
        headers.index.deinit(headers.allocator);
        headers.list.deinit(headers.allocator);

        headers.* = undefined;
    }

    /// Appends a header to the list. Both name and value are copied.
    pub fn append(headers: *Headers, name: []const u8, value: []const u8) !void {
        const n = headers.list.items.len;

        const value_duped = if (headers.owned) try headers.allocator.dupe(u8, value) else value;
        errdefer if (headers.owned) headers.allocator.free(value_duped);

        var entry = Field{ .name = undefined, .value = value_duped };

        if (headers.index.getEntry(name)) |kv| {
            entry.name = kv.key_ptr.*;
            try kv.value_ptr.append(headers.allocator, n);
        } else {
            const name_duped = if (headers.owned) try headers.allocator.dupe(u8, name) else name;
            errdefer if (headers.owned) headers.allocator.free(name_duped);

            entry.name = name_duped;

            var new_index = try HeaderIndexList.initCapacity(headers.allocator, 1);
            errdefer new_index.deinit(headers.allocator);

            new_index.appendAssumeCapacity(n);
            try headers.index.put(headers.allocator, name_duped, new_index);
        }

        try headers.list.append(headers.allocator, entry);
    }

    pub fn contains(headers: Headers, name: []const u8) bool {
        return headers.index.contains(name);
    }

    pub fn delete(headers: *Headers, name: []const u8) bool {
        if (headers.index.fetchRemove(name)) |kv| {
            var index = kv.value;

            // iterate backwards
            var i = index.items.len;
            while (i > 0) {
                i -= 1;
                const data_index = index.items[i];
                const removed = headers.list.orderedRemove(data_index);

                assert(ascii.eqlIgnoreCase(removed.name, name)); // ensure the index hasn't been corrupted
                if (headers.owned) headers.allocator.free(removed.value);
            }

            if (headers.owned) headers.allocator.free(kv.key);
            index.deinit(headers.allocator);
            headers.rebuildIndex();

            return true;
        } else {
            return false;
        }
    }

    /// Returns the index of the first occurrence of a header with the given name.
    pub fn firstIndexOf(headers: Headers, name: []const u8) ?usize {
        const index = headers.index.get(name) orelse return null;

        return index.items[0];
    }

    /// Returns a list of indices containing headers with the given name.
    pub fn getIndices(headers: Headers, name: []const u8) ?[]const usize {
        const index = headers.index.get(name) orelse return null;

        return index.items;
    }

    /// Returns the entry of the first occurrence of a header with the given name.
    pub fn getFirstEntry(headers: Headers, name: []const u8) ?Field {
        const first_index = headers.firstIndexOf(name) orelse return null;

        return headers.list.items[first_index];
    }

    /// Returns a slice containing each header with the given name.
    /// The caller owns the returned slice, but NOT the values in the slice.
    pub fn getEntries(headers: Headers, allocator: Allocator, name: []const u8) !?[]const Field {
        const indices = headers.getIndices(name) orelse return null;

        const buf = try allocator.alloc(Field, indices.len);
        for (indices, 0..) |idx, n| {
            buf[n] = headers.list.items[idx];
        }

        return buf;
    }

    /// Returns the value in the entry of the first occurrence of a header with the given name.
    pub fn getFirstValue(headers: Headers, name: []const u8) ?[]const u8 {
        const first_index = headers.firstIndexOf(name) orelse return null;

        return headers.list.items[first_index].value;
    }

    /// Returns a slice containing the value of each header with the given name.
    /// The caller owns the returned slice, but NOT the values in the slice.
    pub fn getValues(headers: Headers, allocator: Allocator, name: []const u8) !?[]const []const u8 {
        const indices = headers.getIndices(name) orelse return null;

        const buf = try allocator.alloc([]const u8, indices.len);
        for (indices, 0..) |idx, n| {
            buf[n] = headers.list.items[idx].value;
        }

        return buf;
    }

    fn rebuildIndex(headers: *Headers) void {
        // clear out the indexes
        var it = headers.index.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.shrinkRetainingCapacity(0);
        }

        // fill up indexes again; we know capacity is fine from before
        for (headers.list.items, 0..) |entry, i| {
            headers.index.getEntry(entry.name).?.value_ptr.appendAssumeCapacity(i);
        }
    }

    /// Sorts the headers in lexicographical order.
    pub fn sort(headers: *Headers) void {
        std.mem.sort(Field, headers.list.items, {}, Field.lessThan);
        headers.rebuildIndex();
    }

    /// Writes the headers to the given stream.
    pub fn format(
        headers: Headers,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        for (headers.list.items) |entry| {
            if (entry.value.len == 0) continue;

            try out_stream.writeAll(entry.name);
            try out_stream.writeAll(": ");
            try out_stream.writeAll(entry.value);
            try out_stream.writeAll("\r\n");
        }
    }

    /// Writes all of the headers with the given name to the given stream, separated by commas.
    ///
    /// This is useful for headers like `Set-Cookie` which can have multiple values. RFC 9110, Section 5.2
    pub fn formatCommaSeparated(
        headers: Headers,
        name: []const u8,
        out_stream: anytype,
    ) !void {
        const indices = headers.getIndices(name) orelse return;

        try out_stream.writeAll(name);
        try out_stream.writeAll(": ");

        for (indices, 0..) |idx, n| {
            if (n != 0) try out_stream.writeAll(", ");
            try out_stream.writeAll(headers.list.items[idx].value);
        }

        try out_stream.writeAll("\r\n");
    }

    /// Frees all `HeaderIndexList`s within `index`
    /// Frees names and values of all fields if they are owned.
    fn deallocateIndexListsAndFields(headers: *Headers) void {
        var it = headers.index.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(headers.allocator);

            if (headers.owned) headers.allocator.free(entry.key_ptr.*);
        }

        if (headers.owned) {
            for (headers.list.items) |entry| {
                headers.allocator.free(entry.value);
            }
        }
    }

    /// Clears and frees the underlying data structures.
    /// Frees names and values if they are owned.
    pub fn clearAndFree(headers: *Headers) void {
        headers.deallocateIndexListsAndFields();
        headers.index.clearAndFree(headers.allocator);
        headers.list.clearAndFree(headers.allocator);
    }

    /// Clears the underlying data structures while retaining their capacities.
    /// Frees names and values if they are owned.
    pub fn clearRetainingCapacity(headers: *Headers) void {
        headers.deallocateIndexListsAndFields();
        headers.index.clearRetainingCapacity();
        headers.list.clearRetainingCapacity();
    }
};

test "Headers.append" {
    var h = Headers{ .allocator = std.testing.allocator };
    defer h.deinit();

    try h.append("foo", "bar");
    try h.append("hello", "world");

    try testing.expect(h.contains("Foo"));
    try testing.expect(!h.contains("Bar"));
}

test "Headers.delete" {
    var h = Headers{ .allocator = std.testing.allocator };
    defer h.deinit();

    try h.append("foo", "bar");
    try h.append("hello", "world");

    try testing.expect(h.contains("Foo"));

    _ = h.delete("Foo");

    try testing.expect(!h.contains("foo"));
}

test "Headers consistency" {
    var h = Headers{ .allocator = std.testing.allocator };
    defer h.deinit();

    try h.append("foo", "bar");
    try h.append("hello", "world");
    _ = h.delete("Foo");

    try h.append("foo", "bar");
    try h.append("bar", "world");
    try h.append("foo", "baz");
    try h.append("baz", "hello");

    try testing.expectEqual(@as(?usize, 0), h.firstIndexOf("hello"));
    try testing.expectEqual(@as(?usize, 1), h.firstIndexOf("foo"));
    try testing.expectEqual(@as(?usize, 2), h.firstIndexOf("bar"));
    try testing.expectEqual(@as(?usize, 4), h.firstIndexOf("baz"));
    try testing.expectEqual(@as(?usize, null), h.firstIndexOf("pog"));

    try testing.expectEqualSlices(usize, &[_]usize{0}, h.getIndices("hello").?);
    try testing.expectEqualSlices(usize, &[_]usize{ 1, 3 }, h.getIndices("foo").?);
    try testing.expectEqualSlices(usize, &[_]usize{2}, h.getIndices("bar").?);
    try testing.expectEqualSlices(usize, &[_]usize{4}, h.getIndices("baz").?);
    try testing.expectEqual(@as(?[]const usize, null), h.getIndices("pog"));

    try testing.expectEqualStrings("world", h.getFirstEntry("hello").?.value);
    try testing.expectEqualStrings("bar", h.getFirstEntry("foo").?.value);
    try testing.expectEqualStrings("world", h.getFirstEntry("bar").?.value);
    try testing.expectEqualStrings("hello", h.getFirstEntry("baz").?.value);

    const hello_entries = (try h.getEntries(testing.allocator, "hello")).?;
    defer testing.allocator.free(hello_entries);
    try testing.expectEqualDeep(@as([]const Field, &[_]Field{
        .{ .name = "hello", .value = "world" },
    }), hello_entries);

    const foo_entries = (try h.getEntries(testing.allocator, "foo")).?;
    defer testing.allocator.free(foo_entries);
    try testing.expectEqualDeep(@as([]const Field, &[_]Field{
        .{ .name = "foo", .value = "bar" },
        .{ .name = "foo", .value = "baz" },
    }), foo_entries);

    const bar_entries = (try h.getEntries(testing.allocator, "bar")).?;
    defer testing.allocator.free(bar_entries);
    try testing.expectEqualDeep(@as([]const Field, &[_]Field{
        .{ .name = "bar", .value = "world" },
    }), bar_entries);

    const baz_entries = (try h.getEntries(testing.allocator, "baz")).?;
    defer testing.allocator.free(baz_entries);
    try testing.expectEqualDeep(@as([]const Field, &[_]Field{
        .{ .name = "baz", .value = "hello" },
    }), baz_entries);

    const pog_entries = (try h.getEntries(testing.allocator, "pog"));
    try testing.expectEqual(@as(?[]const Field, null), pog_entries);

    try testing.expectEqualStrings("world", h.getFirstValue("hello").?);
    try testing.expectEqualStrings("bar", h.getFirstValue("foo").?);
    try testing.expectEqualStrings("world", h.getFirstValue("bar").?);
    try testing.expectEqualStrings("hello", h.getFirstValue("baz").?);
    try testing.expectEqual(@as(?[]const u8, null), h.getFirstValue("pog"));

    const hello_values = (try h.getValues(testing.allocator, "hello")).?;
    defer testing.allocator.free(hello_values);
    try testing.expectEqualDeep(@as([]const []const u8, &[_][]const u8{"world"}), hello_values);

    const foo_values = (try h.getValues(testing.allocator, "foo")).?;
    defer testing.allocator.free(foo_values);
    try testing.expectEqualDeep(@as([]const []const u8, &[_][]const u8{ "bar", "baz" }), foo_values);

    const bar_values = (try h.getValues(testing.allocator, "bar")).?;
    defer testing.allocator.free(bar_values);
    try testing.expectEqualDeep(@as([]const []const u8, &[_][]const u8{"world"}), bar_values);

    const baz_values = (try h.getValues(testing.allocator, "baz")).?;
    defer testing.allocator.free(baz_values);
    try testing.expectEqualDeep(@as([]const []const u8, &[_][]const u8{"hello"}), baz_values);

    const pog_values = (try h.getValues(testing.allocator, "pog"));
    try testing.expectEqual(@as(?[]const []const u8, null), pog_values);

    h.sort();

    try testing.expectEqualSlices(usize, &[_]usize{0}, h.getIndices("bar").?);
    try testing.expectEqualSlices(usize, &[_]usize{1}, h.getIndices("baz").?);
    try testing.expectEqualSlices(usize, &[_]usize{ 2, 3 }, h.getIndices("foo").?);
    try testing.expectEqualSlices(usize, &[_]usize{4}, h.getIndices("hello").?);

    const formatted_values = try std.fmt.allocPrint(testing.allocator, "{}", .{h});
    defer testing.allocator.free(formatted_values);

    try testing.expectEqualStrings("bar: world\r\nbaz: hello\r\nfoo: bar\r\nfoo: baz\r\nhello: world\r\n", formatted_values);

    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try h.formatCommaSeparated("foo", writer);
    try testing.expectEqualStrings("foo: bar, baz\r\n", fbs.getWritten());
}

test "Headers.clearRetainingCapacity and clearAndFree" {
    var h = Headers.init(std.testing.allocator);
    defer h.deinit();

    h.clearRetainingCapacity();

    try h.append("foo", "bar");
    try h.append("bar", "world");
    try h.append("foo", "baz");
    try h.append("baz", "hello");
    try testing.expectEqual(@as(usize, 4), h.list.items.len);
    try testing.expectEqual(@as(usize, 3), h.index.count());
    const list_capacity = h.list.capacity;
    const index_capacity = h.index.capacity();

    h.clearRetainingCapacity();
    try testing.expectEqual(@as(usize, 0), h.list.items.len);
    try testing.expectEqual(@as(usize, 0), h.index.count());
    try testing.expectEqual(list_capacity, h.list.capacity);
    try testing.expectEqual(index_capacity, h.index.capacity());

    try h.append("foo", "bar");
    try h.append("bar", "world");
    try h.append("foo", "baz");
    try h.append("baz", "hello");
    try testing.expectEqual(@as(usize, 4), h.list.items.len);
    try testing.expectEqual(@as(usize, 3), h.index.count());
    // Capacity should still be the same since we shouldn't have needed to grow
    // when adding back the same fields
    try testing.expectEqual(list_capacity, h.list.capacity);
    try testing.expectEqual(index_capacity, h.index.capacity());

    h.clearAndFree();
    try testing.expectEqual(@as(usize, 0), h.list.items.len);
    try testing.expectEqual(@as(usize, 0), h.index.count());
    try testing.expectEqual(@as(usize, 0), h.list.capacity);
    try testing.expectEqual(@as(usize, 0), h.index.capacity());
}
