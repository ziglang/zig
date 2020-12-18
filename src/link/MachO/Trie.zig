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
const log = std.log.scoped(.link);
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
    trie_offset: ?usize = null,

    /// List of all edges originating from this node.
    edges: std.ArrayListUnmanaged(Edge) = .{},

    node_dirty: bool = true,

    /// Edge connecting to nodes in the trie.
    pub const Edge = struct {
        from: *Node,
        to: *Node,
        label: []u8,

        fn deinit(self: *Edge, allocator: *Allocator) void {
            self.to.deinit(allocator);
            allocator.destroy(self.to);
            allocator.free(self.label);
            self.from = undefined;
            self.to = undefined;
            self.label = undefined;
        }
    };

    fn deinit(self: *Node, allocator: *Allocator) void {
        for (self.edges.items) |*edge| {
            edge.deinit(allocator);
        }
        self.edges.deinit(allocator);
    }

    /// Inserts a new node starting from `self`.
    fn put(self: *Node, allocator: *Allocator, label: []const u8) !*Node {
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
            var to_label = try allocator.dupe(u8, edge.label[match..]);
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

            return if (match == label.len) to_node else mid.put(allocator, label[match..]);
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
    fn read(self: *Node, allocator: *Allocator, reader: anytype) Trie.ReadError!usize {
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
                break :blk label_buf.toOwnedSlice();
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
            var info_buf_len: usize = 0;
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
        try writer.writeByte(@intCast(u8, self.edges.items.len));

        for (self.edges.items) |edge| {
            // Write edge label and offset to next node in trie.
            try writer.writeAll(edge.label);
            try writer.writeByte(0);
            try leb.writeULEB128(writer, edge.to.trie_offset.?);
        }
    }

    const FinalizeResult = struct {
        /// Current size of this node in bytes.
        node_size: usize,

        /// True if the trie offset of this node in the output byte stream
        /// would need updating; false otherwise.
        updated: bool,
    };

    /// Updates offset of this node in the output byte stream.
    fn finalize(self: *Node, offset_in_trie: usize) !FinalizeResult {
        var stream = std.io.countingWriter(std.io.null_writer);
        var writer = stream.writer();

        var node_size: usize = 0;
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

allocator: *Allocator,

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
size: usize = 0,

/// Number of nodes currently in the trie.
node_count: usize = 0,

trie_dirty: bool = true,

pub fn init(allocator: *Allocator) Trie {
    return .{ .allocator = allocator };
}

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
pub fn put(self: *Trie, symbol: ExportSymbol) !void {
    try self.createRoot();
    const node = try self.root.?.put(self.allocator, symbol.name);
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
pub fn finalize(self: *Trie) !void {
    if (!self.trie_dirty) return;

    self.ordered_nodes.shrinkRetainingCapacity(0);
    try self.ordered_nodes.ensureCapacity(self.allocator, self.node_count);

    comptime const Fifo = std.fifo.LinearFifo(*Node, .{ .Static = std.math.maxInt(u8) });
    var fifo = Fifo.init();
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
pub fn read(self: *Trie, reader: anytype) ReadError!usize {
    try self.createRoot();
    return self.root.?.read(self.allocator, reader);
}

/// Write the trie to a byte stream.
/// Panics if the trie was not finalized using `finalize` before calling this method.
pub fn write(self: Trie, writer: anytype) !usize {
    assert(!self.trie_dirty);
    var counting_writer = std.io.countingWriter(writer);
    for (self.ordered_nodes.items) |node| {
        try node.write(counting_writer.writer());
    }
    return counting_writer.bytes_written;
}

pub fn deinit(self: *Trie) void {
    if (self.root) |root| {
        root.deinit(self.allocator);
        self.allocator.destroy(root);
    }
    self.ordered_nodes.deinit(self.allocator);
}

fn createRoot(self: *Trie) !void {
    if (self.root == null) {
        const root = try self.allocator.create(Node);
        root.* = .{ .base = self };
        self.root = root;
        self.node_count += 1;
    }
}

test "Trie node count" {
    var gpa = testing.allocator;
    var trie = Trie.init(gpa);
    defer trie.deinit();

    testing.expectEqual(trie.node_count, 0);
    testing.expect(trie.root == null);

    try trie.put(.{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 2);

    // Inserting the same node shouldn't update the trie.
    try trie.put(.{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 2);

    try trie.put(.{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);

    // Inserting the same node shouldn't update the trie.
    try trie.put(.{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);
    try trie.put(.{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);
}

test "Trie basic" {
    var gpa = testing.allocator;
    var trie = Trie.init(gpa);
    defer trie.deinit();

    // root --- _st ---> node
    try trie.put(.{
        .name = "_st",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expect(trie.root.?.edges.items.len == 1);
    testing.expect(mem.eql(u8, trie.root.?.edges.items[0].label, "_st"));

    {
        // root --- _st ---> node --- art ---> node
        try trie.put(.{
            .name = "_start",
            .vmaddr_offset = 0,
            .export_flags = 0,
        });
        testing.expect(trie.root.?.edges.items.len == 1);

        const nextEdge = &trie.root.?.edges.items[0];
        testing.expect(mem.eql(u8, nextEdge.label, "_st"));
        testing.expect(nextEdge.to.edges.items.len == 1);
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "art"));
    }
    {
        // root --- _ ---> node --- st ---> node --- art ---> node
        //                  |
        //                  |   --- main ---> node
        try trie.put(.{
            .name = "_main",
            .vmaddr_offset = 0,
            .export_flags = 0,
        });
        testing.expect(trie.root.?.edges.items.len == 1);

        const nextEdge = &trie.root.?.edges.items[0];
        testing.expect(mem.eql(u8, nextEdge.label, "_"));
        testing.expect(nextEdge.to.edges.items.len == 2);
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "st"));
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[1].label, "main"));

        const nextNextEdge = &nextEdge.to.edges.items[0];
        testing.expect(mem.eql(u8, nextNextEdge.to.edges.items[0].label, "art"));
    }
}

test "write Trie to a byte stream" {
    var gpa = testing.allocator;
    var trie = Trie.init(gpa);
    defer trie.deinit();

    try trie.put(.{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    try trie.put(.{
        .name = "_main",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });

    try trie.finalize();
    try trie.finalize(); // Finalizing mulitple times is a nop subsequently unless we add new nodes.

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

    var buffer = try gpa.alloc(u8, trie.size);
    defer gpa.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    {
        const nwritten = try trie.write(stream.writer());
        testing.expect(nwritten == trie.size);
        testing.expect(mem.eql(u8, buffer, &exp_buffer));
    }
    {
        // Writing finalized trie again should yield the same result.
        try stream.seekTo(0);
        const nwritten = try trie.write(stream.writer());
        testing.expect(nwritten == trie.size);
        testing.expect(mem.eql(u8, buffer, &exp_buffer));
    }
}

test "parse Trie from byte stream" {
    var gpa = testing.allocator;

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
    var trie = Trie.init(gpa);
    defer trie.deinit();
    const nread = try trie.read(in_stream.reader());

    testing.expect(nread == in_buffer.len);

    try trie.finalize();

    var out_buffer = try gpa.alloc(u8, trie.size);
    defer gpa.free(out_buffer);
    var out_stream = std.io.fixedBufferStream(out_buffer);
    const nwritten = try trie.write(out_stream.writer());

    testing.expect(nwritten == trie.size);
    testing.expect(mem.eql(u8, &in_buffer, out_buffer));
}
