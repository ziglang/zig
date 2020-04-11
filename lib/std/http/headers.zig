// HTTP Header data structure/type
// Based on lua-http's http.header module
//
// Design criteria:
//   - the same header field is allowed more than once
//       - must be able to fetch separate occurrences (important for some headers e.g. Set-Cookie)
//       - optionally available as comma separated list
//   - http2 adds flag to headers that they should never be indexed
//   - header order should be recoverable
//
// Headers are implemented as an array of entries.
// An index of field name => array indices is kept.

const std = @import("../std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

fn never_index_default(name: []const u8) bool {
    if (mem.eql(u8, "authorization", name)) return true;
    if (mem.eql(u8, "proxy-authorization", name)) return true;
    if (mem.eql(u8, "cookie", name)) return true;
    if (mem.eql(u8, "set-cookie", name)) return true;
    return false;
}

const HeaderEntry = struct {
    allocator: *Allocator,
    name: []const u8,
    value: []u8,
    never_index: bool,

    const Self = @This();

    fn init(allocator: *Allocator, name: []const u8, value: []const u8, never_index: ?bool) !Self {
        return Self{
            .allocator = allocator,
            .name = name, // takes reference
            .value = try mem.dupe(allocator, u8, value),
            .never_index = never_index orelse never_index_default(name),
        };
    }

    fn deinit(self: Self) void {
        self.allocator.free(self.value);
    }

    pub fn modify(self: *Self, value: []const u8, never_index: ?bool) !void {
        const old_len = self.value.len;
        if (value.len > old_len) {
            self.value = try self.allocator.realloc(self.value, value.len);
        } else if (value.len < old_len) {
            self.value = self.allocator.shrink(self.value, value.len);
        }
        mem.copy(u8, self.value, value);
        self.never_index = never_index orelse never_index_default(self.name);
    }

    fn compare(a: HeaderEntry, b: HeaderEntry) bool {
        if (a.name.ptr != b.name.ptr and a.name.len != b.name.len) {
            // Things beginning with a colon *must* be before others
            const a_is_colon = a.name[0] == ':';
            const b_is_colon = b.name[0] == ':';
            if (a_is_colon and !b_is_colon) {
                return true;
            } else if (!a_is_colon and b_is_colon) {
                return false;
            }

            // Sort lexicographically on header name
            return mem.order(u8, a.name, b.name) == .lt;
        }

        // Sort lexicographically on header value
        if (!mem.eql(u8, a.value, b.value)) {
            return mem.order(u8, a.value, b.value) == .lt;
        }

        // Doesn't matter here; need to pick something for sort consistency
        return a.never_index;
    }
};

test "HeaderEntry" {
    var e = try HeaderEntry.init(testing.allocator, "foo", "bar", null);
    defer e.deinit();
    testing.expectEqualSlices(u8, "foo", e.name);
    testing.expectEqualSlices(u8, "bar", e.value);
    testing.expectEqual(false, e.never_index);

    try e.modify("longer value", null);
    testing.expectEqualSlices(u8, "longer value", e.value);

    // shorter value
    try e.modify("x", null);
    testing.expectEqualSlices(u8, "x", e.value);
}

const HeaderList = std.ArrayList(HeaderEntry);
const HeaderIndexList = std.ArrayList(usize);
const HeaderIndex = std.StringHashMap(HeaderIndexList);

pub const Headers = struct {
    // the owned header field name is stored in the index as part of the key
    allocator: *Allocator,
    data: HeaderList,
    index: HeaderIndex,

    const Self = @This();

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .allocator = allocator,
            .data = HeaderList.init(allocator),
            .index = HeaderIndex.init(allocator),
        };
    }

    pub fn deinit(self: Self) void {
        {
            var it = self.index.iterator();
            while (it.next()) |kv| {
                var dex = &kv.value;
                dex.deinit();
                self.allocator.free(kv.key);
            }
            self.index.deinit();
        }
        {
            for (self.data.span()) |entry| {
                entry.deinit();
            }
            self.data.deinit();
        }
    }

    pub fn clone(self: Self, allocator: *Allocator) !Self {
        var other = Headers.init(allocator);
        errdefer other.deinit();
        try other.data.ensureCapacity(self.data.items.len);
        try other.index.initCapacity(self.index.entries.len);
        for (self.data.span()) |entry| {
            try other.append(entry.name, entry.value, entry.never_index);
        }
        return other;
    }

    pub fn toSlice(self: Self) []const HeaderEntry {
        return self.data.span();
    }

    pub fn append(self: *Self, name: []const u8, value: []const u8, never_index: ?bool) !void {
        const n = self.data.items.len + 1;
        try self.data.ensureCapacity(n);
        var entry: HeaderEntry = undefined;
        if (self.index.get(name)) |kv| {
            entry = try HeaderEntry.init(self.allocator, kv.key, value, never_index);
            errdefer entry.deinit();
            var dex = &kv.value;
            try dex.append(n - 1);
        } else {
            const name_dup = try mem.dupe(self.allocator, u8, name);
            errdefer self.allocator.free(name_dup);
            entry = try HeaderEntry.init(self.allocator, name_dup, value, never_index);
            errdefer entry.deinit();
            var dex = HeaderIndexList.init(self.allocator);
            try dex.append(n - 1);
            errdefer dex.deinit();
            _ = try self.index.put(name_dup, dex);
        }
        self.data.appendAssumeCapacity(entry);
    }

    /// If the header already exists, replace the current value, otherwise append it to the list of headers.
    /// If the header has multiple entries then returns an error.
    pub fn upsert(self: *Self, name: []const u8, value: []const u8, never_index: ?bool) !void {
        if (self.index.get(name)) |kv| {
            const dex = kv.value;
            if (dex.len != 1)
                return error.CannotUpsertMultiValuedField;
            var e = &self.data.at(dex.at(0));
            try e.modify(value, never_index);
        } else {
            try self.append(name, value, never_index);
        }
    }

    /// Returns boolean indicating if the field is present.
    pub fn contains(self: Self, name: []const u8) bool {
        return self.index.contains(name);
    }

    /// Returns boolean indicating if something was deleted.
    pub fn delete(self: *Self, name: []const u8) bool {
        if (self.index.remove(name)) |kv| {
            var dex = &kv.value;
            // iterate backwards
            var i = dex.items.len;
            while (i > 0) {
                i -= 1;
                const data_index = dex.items[i];
                const removed = self.data.orderedRemove(data_index);
                assert(mem.eql(u8, removed.name, name));
                removed.deinit();
            }
            dex.deinit();
            self.allocator.free(kv.key);
            self.rebuild_index();
            return true;
        } else {
            return false;
        }
    }

    /// Removes the element at the specified index.
    /// Moves items down to fill the empty space.
    pub fn orderedRemove(self: *Self, i: usize) void {
        const removed = self.data.orderedRemove(i);
        const kv = self.index.get(removed.name).?;
        var dex = &kv.value;
        if (dex.items.len == 1) {
            // was last item; delete the index
            _ = self.index.remove(kv.key);
            dex.deinit();
            removed.deinit();
            self.allocator.free(kv.key);
        } else {
            dex.shrink(dex.items.len - 1);
            removed.deinit();
        }
        // if it was the last item; no need to rebuild index
        if (i != self.data.items.len) {
            self.rebuild_index();
        }
    }

    /// Removes the element at the specified index.
    /// The empty slot is filled from the end of the list.
    pub fn swapRemove(self: *Self, i: usize) void {
        const removed = self.data.swapRemove(i);
        const kv = self.index.get(removed.name).?;
        var dex = &kv.value;
        if (dex.items.len == 1) {
            // was last item; delete the index
            _ = self.index.remove(kv.key);
            dex.deinit();
            removed.deinit();
            self.allocator.free(kv.key);
        } else {
            dex.shrink(dex.items.len - 1);
            removed.deinit();
        }
        // if it was the last item; no need to rebuild index
        if (i != self.data.items.len) {
            self.rebuild_index();
        }
    }

    /// Access the header at the specified index.
    pub fn at(self: Self, i: usize) HeaderEntry {
        return self.data.items[i];
    }

    /// Returns a list of indices containing headers with the given name.
    /// The returned list should not be modified by the caller.
    pub fn getIndices(self: Self, name: []const u8) ?HeaderIndexList {
        if (self.index.get(name)) |kv| {
            return kv.value;
        } else {
            return null;
        }
    }

    /// Returns a slice containing each header with the given name.
    pub fn get(self: Self, allocator: *Allocator, name: []const u8) !?[]const HeaderEntry {
        const dex = self.getIndices(name) orelse return null;

        const buf = try allocator.alloc(HeaderEntry, dex.items.len);
        var n: usize = 0;
        for (dex.span()) |idx| {
            buf[n] = self.data.items[idx];
            n += 1;
        }
        return buf;
    }

    /// Returns all headers with the given name as a comma separated string.
    ///
    /// Useful for HTTP headers that follow RFC-7230 section 3.2.2:
    ///   A recipient MAY combine multiple header fields with the same field
    ///   name into one "field-name: field-value" pair, without changing the
    ///   semantics of the message, by appending each subsequent field value to
    ///   the combined field value in order, separated by a comma.  The order
    ///   in which header fields with the same field name are received is
    ///   therefore significant to the interpretation of the combined field
    ///   value
    pub fn getCommaSeparated(self: Self, allocator: *Allocator, name: []const u8) !?[]u8 {
        const dex = self.getIndices(name) orelse return null;

        // adapted from mem.join
        const total_len = blk: {
            var sum: usize = dex.items.len - 1; // space for separator(s)
            for (dex.span()) |idx|
                sum += self.data.items[idx].value.len;
            break :blk sum;
        };

        const buf = try allocator.alloc(u8, total_len);
        errdefer allocator.free(buf);

        const first_value = self.data.items[dex.items[0]].value;
        mem.copy(u8, buf, first_value);
        var buf_index: usize = first_value.len;
        for (dex.items[1..]) |idx| {
            const value = self.data.items[idx].value;
            buf[buf_index] = ',';
            buf_index += 1;
            mem.copy(u8, buf[buf_index..], value);
            buf_index += value.len;
        }

        // No need for shrink since buf is exactly the correct size.
        return buf;
    }

    fn rebuild_index(self: *Self) void {
        { // clear out the indexes
            var it = self.index.iterator();
            while (it.next()) |kv| {
                var dex = &kv.value;
                dex.items.len = 0; // keeps capacity available
            }
        }
        { // fill up indexes again; we know capacity is fine from before
            for (self.data.span()) |entry, i| {
                var dex = &self.index.get(entry.name).?.value;
                dex.appendAssumeCapacity(i);
            }
        }
    }

    pub fn sort(self: *Self) void {
        std.sort.sort(HeaderEntry, self.data.items, HeaderEntry.compare);
        self.rebuild_index();
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) !void {
        for (self.toSlice()) |entry| {
            try out_stream.writeAll(entry.name);
            try out_stream.writeAll(": ");
            try out_stream.writeAll(entry.value);
            try out_stream.writeAll("\n");
        }
    }
};

test "Headers.iterator" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("cookie", "somevalue", null);

    var count: i32 = 0;
    for (h.toSlice()) |e| {
        if (count == 0) {
            testing.expectEqualSlices(u8, "foo", e.name);
            testing.expectEqualSlices(u8, "bar", e.value);
            testing.expectEqual(false, e.never_index);
        } else if (count == 1) {
            testing.expectEqualSlices(u8, "cookie", e.name);
            testing.expectEqualSlices(u8, "somevalue", e.value);
            testing.expectEqual(true, e.never_index);
        }
        count += 1;
    }
    testing.expectEqual(@as(i32, 2), count);
}

test "Headers.contains" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("cookie", "somevalue", null);

    testing.expectEqual(true, h.contains("foo"));
    testing.expectEqual(false, h.contains("flooble"));
}

test "Headers.delete" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("baz", "qux", null);
    try h.append("cookie", "somevalue", null);

    testing.expectEqual(false, h.delete("not-present"));
    testing.expectEqual(@as(usize, 3), h.toSlice().len);

    testing.expectEqual(true, h.delete("foo"));
    testing.expectEqual(@as(usize, 2), h.toSlice().len);
    {
        const e = h.at(0);
        testing.expectEqualSlices(u8, "baz", e.name);
        testing.expectEqualSlices(u8, "qux", e.value);
        testing.expectEqual(false, e.never_index);
    }
    {
        const e = h.at(1);
        testing.expectEqualSlices(u8, "cookie", e.name);
        testing.expectEqualSlices(u8, "somevalue", e.value);
        testing.expectEqual(true, e.never_index);
    }

    testing.expectEqual(false, h.delete("foo"));
}

test "Headers.orderedRemove" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("baz", "qux", null);
    try h.append("cookie", "somevalue", null);

    h.orderedRemove(0);
    testing.expectEqual(@as(usize, 2), h.toSlice().len);
    {
        const e = h.at(0);
        testing.expectEqualSlices(u8, "baz", e.name);
        testing.expectEqualSlices(u8, "qux", e.value);
        testing.expectEqual(false, e.never_index);
    }
    {
        const e = h.at(1);
        testing.expectEqualSlices(u8, "cookie", e.name);
        testing.expectEqualSlices(u8, "somevalue", e.value);
        testing.expectEqual(true, e.never_index);
    }
}

test "Headers.swapRemove" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("baz", "qux", null);
    try h.append("cookie", "somevalue", null);

    h.swapRemove(0);
    testing.expectEqual(@as(usize, 2), h.toSlice().len);
    {
        const e = h.at(0);
        testing.expectEqualSlices(u8, "cookie", e.name);
        testing.expectEqualSlices(u8, "somevalue", e.value);
        testing.expectEqual(true, e.never_index);
    }
    {
        const e = h.at(1);
        testing.expectEqualSlices(u8, "baz", e.name);
        testing.expectEqualSlices(u8, "qux", e.value);
        testing.expectEqual(false, e.never_index);
    }
}

test "Headers.at" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("cookie", "somevalue", null);

    {
        const e = h.at(0);
        testing.expectEqualSlices(u8, "foo", e.name);
        testing.expectEqualSlices(u8, "bar", e.value);
        testing.expectEqual(false, e.never_index);
    }
    {
        const e = h.at(1);
        testing.expectEqualSlices(u8, "cookie", e.name);
        testing.expectEqualSlices(u8, "somevalue", e.value);
        testing.expectEqual(true, e.never_index);
    }
}

test "Headers.getIndices" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("set-cookie", "x=1", null);
    try h.append("set-cookie", "y=2", null);

    testing.expect(null == h.getIndices("not-present"));
    testing.expectEqualSlices(usize, &[_]usize{0}, h.getIndices("foo").?.span());
    testing.expectEqualSlices(usize, &[_]usize{ 1, 2 }, h.getIndices("set-cookie").?.span());
}

test "Headers.get" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("set-cookie", "x=1", null);
    try h.append("set-cookie", "y=2", null);

    {
        const v = try h.get(testing.allocator, "not-present");
        testing.expect(null == v);
    }
    {
        const v = (try h.get(testing.allocator, "foo")).?;
        defer testing.allocator.free(v);
        const e = v[0];
        testing.expectEqualSlices(u8, "foo", e.name);
        testing.expectEqualSlices(u8, "bar", e.value);
        testing.expectEqual(false, e.never_index);
    }
    {
        const v = (try h.get(testing.allocator, "set-cookie")).?;
        defer testing.allocator.free(v);
        {
            const e = v[0];
            testing.expectEqualSlices(u8, "set-cookie", e.name);
            testing.expectEqualSlices(u8, "x=1", e.value);
            testing.expectEqual(true, e.never_index);
        }
        {
            const e = v[1];
            testing.expectEqualSlices(u8, "set-cookie", e.name);
            testing.expectEqualSlices(u8, "y=2", e.value);
            testing.expectEqual(true, e.never_index);
        }
    }
}

test "Headers.getCommaSeparated" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("set-cookie", "x=1", null);
    try h.append("set-cookie", "y=2", null);

    {
        const v = try h.getCommaSeparated(testing.allocator, "not-present");
        testing.expect(null == v);
    }
    {
        const v = (try h.getCommaSeparated(testing.allocator, "foo")).?;
        defer testing.allocator.free(v);
        testing.expectEqualSlices(u8, "bar", v);
    }
    {
        const v = (try h.getCommaSeparated(testing.allocator, "set-cookie")).?;
        defer testing.allocator.free(v);
        testing.expectEqualSlices(u8, "x=1,y=2", v);
    }
}

test "Headers.sort" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("cookie", "somevalue", null);

    h.sort();
    {
        const e = h.at(0);
        testing.expectEqualSlices(u8, "cookie", e.name);
        testing.expectEqualSlices(u8, "somevalue", e.value);
        testing.expectEqual(true, e.never_index);
    }
    {
        const e = h.at(1);
        testing.expectEqualSlices(u8, "foo", e.name);
        testing.expectEqualSlices(u8, "bar", e.value);
        testing.expectEqual(false, e.never_index);
    }
}

test "Headers.format" {
    var h = Headers.init(testing.allocator);
    defer h.deinit();
    try h.append("foo", "bar", null);
    try h.append("cookie", "somevalue", null);

    var buf: [100]u8 = undefined;
    testing.expectEqualSlices(u8,
        \\foo: bar
        \\cookie: somevalue
        \\
    , try std.fmt.bufPrint(buf[0..], "{}", .{h}));
}
