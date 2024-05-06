//! Represents export trie used in MachO executables and dynamic libraries.
//! The purpose of an export trie is to encode as compactly as possible all
//! export symbols for the loader `dyld`.
//! The export trie encodes offset and other information using ULEB128
//! encoding, and is part of the __LINKEDIT segment.
//!
//! Description from loader.h:
//!
//! The symbols exported by a dylib are encoded in a trie. This is a compact
//! representation that factors out common prefixes. It also reduces LINKEDIT pages
//! in RAM because it encodes all information (name, address, flags) in one small,
//! contiguous range. The export area is a stream of nodes. The first node sequentially
//! is the start node for the trie.
//!
//! Nodes for a symbol start with a uleb128 that is the length of the exported symbol
//! information for the string so far. If there is no exported symbol, the node starts
//! with a zero byte. If there is exported info, it follows the length.
//!
//! First is a uleb128 containing flags. Normally, it is followed by a uleb128 encoded
//! offset which is location of the content named by the symbol from the mach_header
//! for the image. If the flags is EXPORT_SYMBOL_FLAGS_REEXPORT, then following the flags
//! is a uleb128 encoded library ordinal, then a zero terminated UTF8 string. If the string
//! is zero length, then the symbol is re-export from the specified dylib with the same name.
//! If the flags is EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER, then following the flags is two
//! uleb128s: the stub offset and the resolver offset. The stub is used by non-lazy pointers.
//! The resolver is used by lazy pointers and must be called to get the actual address to use.
//!
//! After the optional exported symbol information is a byte of how many edges (0-255) that
//! this node has leaving it, followed by each edge. Each edge is a zero terminated UTF8 of
//! the addition chars in the symbol, followed by a uleb128 offset for the node that edge points to.
const Trie = @This();

const std = @import("std");
const mem = std.mem;
const leb = std.leb;
const log = std.log.scoped(.macho);
const macho = std.macho;
const testing = std.testing;
const assert = std.debug.assert;
const Allocator = mem.Allocator;

pub const Node = struct {
    base: *Trie,

    /// Terminal info associated with this node.
    /// If this node is not a terminal node, info is null.
    terminal_info: ?struct {
        /// Export flags associated with this exported symbol.
        export_flags: u64,
        /// VM address offset wrt to the section this symbol is defined against.
        vmaddr_offset: u64,
    } = null,

    /// Offset of this node in the trie output byte stream.
    trie_offset: ?u64 = null,

    /// List of all edges originating from this node.
    edges: std.ArrayListUnmanaged(Edge) = .{},

    node_dirty: bool = true,

    /// Edge connecting to nodes in the trie.
    pub const Edge = struct {
        from: *Node,
        to: *Node,
        label: []u8,

        fn deinit(self: *Edge, allocator: Allocator) void {
            self.to.deinit(allocator);
            allocator.destroy(self.to);
            allocator.free(self.label);
            self.from = undefined;
            self.to = undefined;
            self.label = undefined;
        }
    };

    fn deinit(self: *Node, allocator: Allocator) void {
        for (self.edges.items) |*edge| {
            edge.deinit(allocator);
        }
        self.edges.deinit(allocator);
    }

    /// Inserts a new node starting from `self`.
    fn put(self: *Node, allocator: Allocator, label: []const u8) !*Node {
        // Check for match with edges from this node.
        for (self.edges.items) |*edge| {
            const match = mem.indexOfDiff(u8, edge.label, label) orelse return edge.to;
            if (match == 0) continue;
            if (match == edge.label.len) return edge.to.put(allocator, label[match..]);

            // Found a match, need to splice up nodes.
            // From: A -> B
            // To: A -> C -> B
            const mid = try allocator.create(Node);
            mid.* = .{ .base = self.base };
            const to_label = try allocator.dupe(u8, edge.label[match..]);
            allocator.free(edge.label);
            const to_node = edge.to;
            edge.to = mid;
            edge.label = try allocator.dupe(u8, label[0..match]);
            self.base.node_count += 1;

            try mid.edges.append(allocator, .{
                .from = mid,
                .to = to_node,
                .label = to_label,
            });

            return if (match == label.len) mid else mid.put(allocator, label[match..]);
        }

        // Add a new node.
        const node = try allocator.create(Node);
        node.* = .{ .base = self.base };
        self.base.node_count += 1;

        try self.edges.append(allocator, .{
            .from = self,
            .to = node,
            .label = try allocator.dupe(u8, label),
        });

        return node;
    }

    /// Recursively parses the node from the input byte stream.
    fn read(self: *Node, allocator: Allocator, reader: anytype) Trie.ReadError!usize {
        self.node_dirty = true;
        const trie_offset = try reader.context.getPos();
        self.trie_offset = trie_offset;

        var nread: usize = 0;

        const node_size = try leb.readULEB128(u64, reader);
        if (node_size > 0) {
            const export_flags = try leb.readULEB128(u64, reader);
            // TODO Parse special flags.
            assert(export_flags & macho.EXPORT_SYMBOL_FLAGS_REEXPORT == 0 and
                export_flags & macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER == 0);

            const vmaddr_offset = try leb.readULEB128(u64, reader);

            self.terminal_info = .{
                .export_flags = export_flags,
                .vmaddr_offset = vmaddr_offset,
            };
        }

        const nedges = try reader.readByte();
        self.base.node_count += nedges;

        nread += (try reader.context.getPos()) - trie_offset;

        var i: usize = 0;
        while (i < nedges) : (i += 1) {
            const edge_start_pos = try reader.context.getPos();

            const label = blk: {
                var label_buf = std.ArrayList(u8).init(allocator);
                while (true) {
                    const next = try reader.readByte();
                    if (next == @as(u8, 0))
                        break;
                    try label_buf.append(next);
                }
                break :blk try label_buf.toOwnedSlice();
            };

            const seek_to = try leb.readULEB128(u64, reader);
            const return_pos = try reader.context.getPos();

            nread += return_pos - edge_start_pos;
            try reader.context.seekTo(seek_to);

            const node = try allocator.create(Node);
            node.* = .{ .base = self.base };

            nread += try node.read(allocator, reader);
            try self.edges.append(allocator, .{
                .from = self,
                .to = node,
                .label = label,
            });
            try reader.context.seekTo(return_pos);
        }

        return nread;
    }

    /// Writes this node to a byte stream.
    /// The children of this node *are* not written to the byte stream
    /// recursively. To write all nodes to a byte stream in sequence,
    /// iterate over `Trie.ordered_nodes` and call this method on each node.
    /// This is one of the requirements of the MachO.
    /// Panics if `finalize` was not called before calling this method.
    fn write(self: Node, writer: anytype) !void {
        assert(!self.node_dirty);
        if (self.terminal_info) |info| {
            // Terminal node info: encode export flags and vmaddr offset of this symbol.
            var info_buf: [@sizeOf(u64) * 2]u8 = undefined;
            var info_stream = std.io.fixedBufferStream(&info_buf);
            // TODO Implement for special flags.
            assert(info.export_flags & macho.EXPORT_SYMBOL_FLAGS_REEXPORT == 0 and
                info.export_flags & macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER == 0);
            try leb.writeULEB128(info_stream.writer(), info.export_flags);
            try leb.writeULEB128(info_stream.writer(), info.vmaddr_offset);

            // Encode the size of the terminal node info.
            var size_buf: [@sizeOf(u64)]u8 = undefined;
            var size_stream = std.io.fixedBufferStream(&size_buf);
            try leb.writeULEB128(size_stream.writer(), info_stream.pos);

            // Now, write them to the output stream.
            try writer.writeAll(size_buf[0..size_stream.pos]);
            try writer.writeAll(info_buf[0..info_stream.pos]);
        } else {
            // Non-terminal node is delimited by 0 byte.
            try writer.writeByte(0);
        }
        // Write number of edges (max legal number of edges is 256).
        try writer.writeByte(@as(u8, @intCast(self.edges.items.len)));

        for (self.edges.items) |edge| {
            // Write edge label and offset to next node in trie.
            try writer.writeAll(edge.label);
            try writer.writeByte(0);
            try leb.writeULEB128(writer, edge.to.trie_offset.?);
        }
    }

    const FinalizeResult = struct {
        /// Current size of this node in bytes.
        node_size: u64,

        /// True if the trie offset of this node in the output byte stream
        /// would need updating; false otherwise.
        updated: bool,
    };

    /// Updates offset of this node in the output byte stream.
    fn finalize(self: *Node, offset_in_trie: u64) !FinalizeResult {
        var stream = std.io.countingWriter(std.io.null_writer);
        const writer = stream.writer();

        var node_size: u64 = 0;
        if (self.terminal_info) |info| {
            try leb.writeULEB128(writer, info.export_flags);
            try leb.writeULEB128(writer, info.vmaddr_offset);
            try leb.writeULEB128(writer, stream.bytes_written);
        } else {
            node_size += 1; // 0x0 for non-terminal nodes
        }
        node_size += 1; // 1 byte for edge count

        for (self.edges.items) |edge| {
            const next_node_offset = edge.to.trie_offset orelse 0;
            node_size += edge.label.len + 1;
            try leb.writeULEB128(writer, next_node_offset);
        }

        const trie_offset = self.trie_offset orelse 0;
        const updated = offset_in_trie != trie_offset;
        self.trie_offset = offset_in_trie;
        self.node_dirty = false;
        node_size += stream.bytes_written;

        return FinalizeResult{ .node_size = node_size, .updated = updated };
    }
};

/// The root node of the trie.
root: ?*Node = null,

/// If you want to access nodes ordered in DFS fashion,
/// you should call `finalize` first since the nodes
/// in this container are not guaranteed to not be stale
/// if more insertions took place after the last `finalize`
/// call.
ordered_nodes: std.ArrayListUnmanaged(*Node) = .{},

/// The size of the trie in bytes.
/// This value may be outdated if there were additional
/// insertions performed after `finalize` was called.
/// Call `finalize` before accessing this value to ensure
/// it is up-to-date.
size: u64 = 0,

/// Number of nodes currently in the trie.
node_count: usize = 0,

trie_dirty: bool = true,

/// Export symbol that is to be placed in the trie.
pub const ExportSymbol = struct {
    /// Name of the symbol.
    name: []const u8,

    /// Offset of this symbol's virtual memory address from the beginning
    /// of the __TEXT segment.
    vmaddr_offset: u64,

    /// Export flags of this exported symbol.
    export_flags: u64,
};

/// Insert a symbol into the trie, updating the prefixes in the process.
/// This operation may change the layout of the trie by splicing edges in
/// certain circumstances.
pub fn put(self: *Trie, allocator: Allocator, symbol: ExportSymbol) !void {
    const node = try self.root.?.put(allocator, symbol.name);
    node.terminal_info = .{
        .vmaddr_offset = symbol.vmaddr_offset,
        .export_flags = symbol.export_flags,
    };
    self.trie_dirty = true;
}

/// Finalizes this trie for writing to a byte stream.
/// This step performs multiple passes through the trie ensuring
/// there are no gaps after every `Node` is ULEB128 encoded.
/// Call this method before trying to `write` the trie to a byte stream.
pub fn finalize(self: *Trie, allocator: Allocator) !void {
    if (!self.trie_dirty) return;

    self.ordered_nodes.shrinkRetainingCapacity(0);
    try self.ordered_nodes.ensureTotalCapacity(allocator, self.node_count);

    var fifo = std.fifo.LinearFifo(*Node, .Dynamic).init(allocator);
    defer fifo.deinit();

    try fifo.writeItem(self.root.?);

    while (fifo.readItem()) |next| {
        for (next.edges.items) |*edge| {
            try fifo.writeItem(edge.to);
        }
        self.ordered_nodes.appendAssumeCapacity(next);
    }

    var more: bool = true;
    while (more) {
        self.size = 0;
        more = false;
        for (self.ordered_nodes.items) |node| {
            const res = try node.finalize(self.size);
            self.size += res.node_size;
            if (res.updated) more = true;
        }
    }

    self.trie_dirty = false;
}

const ReadError = error{
    OutOfMemory,
    EndOfStream,
    Overflow,
};

/// Parse the trie from a byte stream.
pub fn read(self: *Trie, allocator: Allocator, reader: anytype) ReadError!usize {
    return self.root.?.read(allocator, reader);
}

/// Write the trie to a byte stream.
/// Panics if the trie was not finalized using `finalize` before calling this method.
pub fn write(self: Trie, writer: anytype) !void {
    assert(!self.trie_dirty);
    for (self.ordered_nodes.items) |node| {
        try node.write(writer);
    }
}

pub fn init(self: *Trie, allocator: Allocator) !void {
    assert(self.root == null);
    const root = try allocator.create(Node);
    root.* = .{ .base = self };
    self.root = root;
    self.node_count += 1;
}

pub fn deinit(self: *Trie, allocator: Allocator) void {
    if (self.root) |root| {
        root.deinit(allocator);
        allocator.destroy(root);
    }
    self.ordered_nodes.deinit(allocator);
}

test "Trie node count" {
    const gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);

    try testing.expectEqual(@as(usize, 1), trie.node_count);
    try testing.expect(trie.root != null);

    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try testing.expectEqual(@as(usize, 2), trie.node_count);

    // Inserting the same node shouldn't update the trie.
    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try testing.expectEqual(@as(usize, 2), trie.node_count);

    try trie.put(gpa, .{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    try testing.expectEqual(@as(usize, 4), trie.node_count);

    // Inserting the same node shouldn't update the trie.
    try trie.put(gpa, .{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    try testing.expectEqual(@as(usize, 4), trie.node_count);
    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try testing.expectEqual(@as(usize, 4), trie.node_count);
}

test "Trie basic" {
    const gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);

    // root --- _st ---> node
    try trie.put(gpa, .{
        .name = "_st",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try testing.expect(trie.root.?.edges.items.len == 1);
    try testing.expect(mem.eql(u8, trie.root.?.edges.items[0].label, "_st"));

    {
        // root --- _st ---> node --- art ---> node
        try trie.put(gpa, .{
            .name = "_start",
            .vmaddr_offset = 0,
            .export_flags = 0,
        });
        try testing.expect(trie.root.?.edges.items.len == 1);

        const nextEdge = &trie.root.?.edges.items[0];
        try testing.expect(mem.eql(u8, nextEdge.label, "_st"));
        try testing.expect(nextEdge.to.edges.items.len == 1);
        try testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "art"));
    }
    {
        // root --- _ ---> node --- st ---> node --- art ---> node
        //                  |
        //                  |   --- main ---> node
        try trie.put(gpa, .{
            .name = "_main",
            .vmaddr_offset = 0,
            .export_flags = 0,
        });
        try testing.expect(trie.root.?.edges.items.len == 1);

        const nextEdge = &trie.root.?.edges.items[0];
        try testing.expect(mem.eql(u8, nextEdge.label, "_"));
        try testing.expect(nextEdge.to.edges.items.len == 2);
        try testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "st"));
        try testing.expect(mem.eql(u8, nextEdge.to.edges.items[1].label, "main"));

        const nextNextEdge = &nextEdge.to.edges.items[0];
        try testing.expect(mem.eql(u8, nextNextEdge.to.edges.items[0].label, "art"));
    }
}

fn expectEqualHexStrings(expected: []const u8, given: []const u8) !void {
    assert(expected.len > 0);
    if (mem.eql(u8, expected, given)) return;
    const expected_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(expected)});
    defer testing.allocator.free(expected_fmt);
    const given_fmt = try std.fmt.allocPrint(testing.allocator, "{x}", .{std.fmt.fmtSliceHexLower(given)});
    defer testing.allocator.free(given_fmt);
    const idx = mem.indexOfDiff(u8, expected_fmt, given_fmt).?;
    const padding = try testing.allocator.alloc(u8, idx + 5);
    defer testing.allocator.free(padding);
    @memset(padding, ' ');
    std.debug.print("\nEXP: {s}\nGIV: {s}\n{s}^ -- first differing byte\n", .{ expected_fmt, given_fmt, padding });
    return error.TestFailed;
}

test "write Trie to a byte stream" {
    var gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);

    try trie.put(gpa, .{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });

    try trie.finalize(gpa);
    try trie.finalize(gpa); // Finalizing mulitple times is a nop subsequently unless we add new nodes.

    const exp_buffer = [_]u8{
        0x0, 0x1, // node root
        0x5f, 0x0, 0x5, // edge '_'
        0x0, 0x2, // non-terminal node
        0x5f, 0x6d, 0x68, 0x5f, 0x65, 0x78, 0x65, 0x63, 0x75, 0x74, // edge '_mh_execute_header'
        0x65, 0x5f, 0x68, 0x65, 0x61, 0x64, 0x65, 0x72, 0x0, 0x21, // edge '_mh_execute_header'
        0x6d, 0x61, 0x69, 0x6e, 0x0, 0x25, // edge 'main'
        0x2, 0x0, 0x0, 0x0, // terminal node
        0x3, 0x0, 0x80, 0x20, 0x0, // terminal node
    };

    const buffer = try gpa.alloc(u8, trie.size);
    defer gpa.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    {
        _ = try trie.write(stream.writer());
        try expectEqualHexStrings(&exp_buffer, buffer);
    }
    {
        // Writing finalized trie again should yield the same result.
        try stream.seekTo(0);
        _ = try trie.write(stream.writer());
        try expectEqualHexStrings(&exp_buffer, buffer);
    }
}

test "parse Trie from byte stream" {
    const gpa = testing.allocator;

    const in_buffer = [_]u8{
        0x0, 0x1, // node root
        0x5f, 0x0, 0x5, // edge '_'
        0x0, 0x2, // non-terminal node
        0x5f, 0x6d, 0x68, 0x5f, 0x65, 0x78, 0x65, 0x63, 0x75, 0x74, // edge '_mh_execute_header'
        0x65, 0x5f, 0x68, 0x65, 0x61, 0x64, 0x65, 0x72, 0x0, 0x21, // edge '_mh_execute_header'
        0x6d, 0x61, 0x69, 0x6e, 0x0, 0x25, // edge 'main'
        0x2, 0x0, 0x0, 0x0, // terminal node
        0x3, 0x0, 0x80, 0x20, 0x0, // terminal node
    };

    var in_stream = std.io.fixedBufferStream(&in_buffer);
    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);
    const nread = try trie.read(gpa, in_stream.reader());

    try testing.expect(nread == in_buffer.len);

    try trie.finalize(gpa);

    const out_buffer = try gpa.alloc(u8, trie.size);
    defer gpa.free(out_buffer);
    var out_stream = std.io.fixedBufferStream(out_buffer);
    _ = try trie.write(out_stream.writer());
    try expectEqualHexStrings(&in_buffer, out_buffer);
}

test "ordering bug" {
    const gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);

    try trie.put(gpa, .{
        .name = "_asStr",
        .vmaddr_offset = 0x558,
        .export_flags = 0,
    });
    try trie.put(gpa, .{
        .name = "_a",
        .vmaddr_offset = 0x8008,
        .export_flags = 0,
    });

    try trie.finalize(gpa);

    const exp_buffer = [_]u8{
        0x00, 0x01, 0x5F, 0x61, 0x00, 0x06, 0x04, 0x00,
        0x88, 0x80, 0x02, 0x01, 0x73, 0x53, 0x74, 0x72,
        0x00, 0x12, 0x03, 0x00, 0xD8, 0x0A, 0x00,
    };

    const buffer = try gpa.alloc(u8, trie.size);
    defer gpa.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    // Writing finalized trie again should yield the same result.
    _ = try trie.write(stream.writer());
    try expectEqualHexStrings(&exp_buffer, buffer);
}
