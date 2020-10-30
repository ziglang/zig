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
const testing = std.testing;
const assert = std.debug.assert;
const Allocator = mem.Allocator;

pub const Symbol = struct {
    name: []const u8,
    vmaddr_offset: u64,
    export_flags: u64,
};

const Edge = struct {
    from: *Node,
    to: *Node,
    label: []const u8,

    fn deinit(self: *Edge, alloc: *Allocator) void {
        self.to.deinit(alloc);
        alloc.destroy(self.to);
        self.from = undefined;
        self.to = undefined;
    }
};

const Node = struct {
    /// Export flags associated with this exported symbol (if any).
    export_flags: ?u64 = null,
    /// VM address offset wrt to the section this symbol is defined against (if any).
    vmaddr_offset: ?u64 = null,
    /// Offset of this node in the trie output byte stream.
    trie_offset: ?usize = null,
    /// List of all edges originating from this node.
    edges: std.ArrayListUnmanaged(Edge) = .{},

    fn deinit(self: *Node, alloc: *Allocator) void {
        for (self.edges.items) |*edge| {
            edge.deinit(alloc);
        }
        self.edges.deinit(alloc);
    }

    const PutResult = struct {
        /// Node reached at this stage of `put` op.
        node: *Node,
        /// Count of newly inserted nodes at this stage of `put` op.
        node_count: usize,
    };

    /// Inserts a new node starting from `self`.
    fn put(self: *Node, alloc: *Allocator, label: []const u8, node_count: usize) !PutResult {
        var curr_node_count = node_count;
        // Check for match with edges from this node.
        for (self.edges.items) |*edge| {
            const match = mem.indexOfDiff(u8, edge.label, label) orelse return PutResult{
                .node = edge.to,
                .node_count = curr_node_count,
            };
            if (match == 0) continue;
            if (match == edge.label.len) return edge.to.put(alloc, label[match..], curr_node_count);

            // Found a match, need to splice up nodes.
            // From: A -> B
            // To: A -> C -> B
            const mid = try alloc.create(Node);
            mid.* = .{};
            const to_label = edge.label;
            const to_node = edge.to;
            edge.to = mid;
            edge.label = label[0..match];
            curr_node_count += 1;

            try mid.edges.append(alloc, .{
                .from = mid,
                .to = to_node,
                .label = to_label[match..],
            });

            if (match == label.len) {
                return PutResult{ .node = to_node, .node_count = curr_node_count };
            } else {
                return mid.put(alloc, label[match..], curr_node_count);
            }
        }

        // Add a new node.
        const node = try alloc.create(Node);
        node.* = .{};
        curr_node_count += 1;

        try self.edges.append(alloc, .{
            .from = self,
            .to = node,
            .label = label,
        });

        return PutResult{ .node = node, .node_count = curr_node_count };
    }

    /// This method should only be called *after* updateOffset has been called!
    /// In case this is not upheld, this method will panic.
    fn writeULEB128Mem(self: Node, buffer: *std.ArrayListUnmanaged(u8)) !void {
        assert(self.trie_offset != null); // You need to call updateOffset first.
        if (self.vmaddr_offset) |offset| {
            // Terminal node info: encode export flags and vmaddr offset of this symbol.
            var info_buf_len: usize = 0;
            var info_buf: [@sizeOf(u64) * 2]u8 = undefined;
            var info_stream = std.io.fixedBufferStream(&info_buf);
            try leb.writeULEB128(info_stream.writer(), self.export_flags.?);
            try leb.writeULEB128(info_stream.writer(), offset);

            // Encode the size of the terminal node info.
            var size_buf: [@sizeOf(u64)]u8 = undefined;
            var size_stream = std.io.fixedBufferStream(&size_buf);
            try leb.writeULEB128(size_stream.writer(), info_stream.pos);

            // Now, write them to the output buffer.
            buffer.appendSliceAssumeCapacity(size_buf[0..size_stream.pos]);
            buffer.appendSliceAssumeCapacity(info_buf[0..info_stream.pos]);
        } else {
            // Non-terminal node is delimited by 0 byte.
            buffer.appendAssumeCapacity(0);
        }
        // Write number of edges (max legal number of edges is 256).
        buffer.appendAssumeCapacity(@intCast(u8, self.edges.items.len));

        for (self.edges.items) |edge| {
            // Write edges labels.
            buffer.appendSliceAssumeCapacity(edge.label);
            buffer.appendAssumeCapacity(0);

            var buf: [@sizeOf(u64)]u8 = undefined;
            var buf_stream = std.io.fixedBufferStream(&buf);
            try leb.writeULEB128(buf_stream.writer(), edge.to.trie_offset.?);
            buffer.appendSliceAssumeCapacity(buf[0..buf_stream.pos]);
        }
    }

    const UpdateResult = struct {
        /// Current size of this node in bytes.
        node_size: usize,
        /// True if the trie offset of this node in the output byte stream
        /// would need updating; false otherwise.
        updated: bool,
    };

    /// Updates offset of this node in the output byte stream.
    fn updateOffset(self: *Node, offset: usize) UpdateResult {
        var node_size: usize = 0;
        if (self.vmaddr_offset) |vmaddr| {
            node_size += sizeULEB128Mem(self.export_flags.?);
            node_size += sizeULEB128Mem(vmaddr);
            node_size += sizeULEB128Mem(node_size);
        } else {
            node_size += 1; // 0x0 for non-terminal nodes
        }
        node_size += 1; // 1 byte for edge count

        for (self.edges.items) |edge| {
            const next_node_offset = edge.to.trie_offset orelse 0;
            node_size += edge.label.len + 1 + sizeULEB128Mem(next_node_offset);
        }

        const trie_offset = self.trie_offset orelse 0;
        const updated = offset != trie_offset;
        self.trie_offset = offset;

        return .{ .node_size = node_size, .updated = updated };
    }

    /// Calculates number of bytes in ULEB128 encoding of value.
    fn sizeULEB128Mem(value: u64) usize {
        var res: usize = 0;
        var v = value;
        while (true) {
            v = v >> 7;
            res += 1;
            if (v == 0) break;
        }
        return res;
    }
};

/// Count of nodes in the trie.
/// The count is updated at every `put` call.
/// The trie always consists of at least a root node, hence
/// the count always starts at 1.
node_count: usize = 1,
/// The root node of the trie.
root: Node = .{},

/// Insert a symbol into the trie, updating the prefixes in the process.
/// This operation may change the layout of the trie by splicing edges in
/// certain circumstances.
pub fn put(self: *Trie, alloc: *Allocator, symbol: Symbol) !void {
    const res = try self.root.put(alloc, symbol.name, 0);
    self.node_count += res.node_count;
    res.node.vmaddr_offset = symbol.vmaddr_offset;
    res.node.export_flags = symbol.export_flags;
}

/// Write the trie to a buffer ULEB128 encoded.
pub fn writeULEB128Mem(self: *Trie, alloc: *Allocator, buffer: *std.ArrayListUnmanaged(u8)) !void {
    var ordered_nodes: std.ArrayListUnmanaged(*Node) = .{};
    defer ordered_nodes.deinit(alloc);

    try ordered_nodes.ensureCapacity(alloc, self.node_count);
    walkInOrder(&self.root, &ordered_nodes);

    var offset: usize = 0;
    var more: bool = true;
    while (more) {
        offset = 0;
        more = false;
        for (ordered_nodes.items) |node| {
            const res = node.updateOffset(offset);
            offset += res.node_size;
            if (res.updated) more = true;
        }
    }

    try buffer.ensureCapacity(alloc, buffer.items.len + offset);
    for (ordered_nodes.items) |node| {
        try node.writeULEB128Mem(buffer);
    }
}

/// Walks the trie in DFS order gathering all nodes into a linear stream of nodes.
fn walkInOrder(node: *Node, list: *std.ArrayListUnmanaged(*Node)) void {
    list.appendAssumeCapacity(node);
    for (node.edges.items) |*edge| {
        walkInOrder(edge.to, list);
    }
}

pub fn deinit(self: *Trie, alloc: *Allocator) void {
    self.root.deinit(alloc);
}

test "Trie node count" {
    var gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);

    testing.expectEqual(trie.node_count, 1);

    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 2);

    // Inserting the same node shouldn't update the trie.
    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 2);

    try trie.put(gpa, .{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);

    // Inserting the same node shouldn't update the trie.
    try trie.put(gpa, .{
        .name = "__mh_execute_header",
        .vmaddr_offset = 0x1000,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);
    try trie.put(gpa, .{
        .name = "_main",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expectEqual(trie.node_count, 4);
}

test "Trie basic" {
    var gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);

    // root
    testing.expect(trie.root.edges.items.len == 0);

    // root --- _st ---> node
    try trie.put(gpa, .{
        .name = "_st",
        .vmaddr_offset = 0,
        .export_flags = 0,
    });
    testing.expect(trie.root.edges.items.len == 1);
    testing.expect(mem.eql(u8, trie.root.edges.items[0].label, "_st"));

    {
        // root --- _st ---> node --- art ---> node
        try trie.put(gpa, .{
            .name = "_start",
            .vmaddr_offset = 0,
            .export_flags = 0,
        });
        testing.expect(trie.root.edges.items.len == 1);

        const nextEdge = &trie.root.edges.items[0];
        testing.expect(mem.eql(u8, nextEdge.label, "_st"));
        testing.expect(nextEdge.to.edges.items.len == 1);
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "art"));
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
        testing.expect(trie.root.edges.items.len == 1);

        const nextEdge = &trie.root.edges.items[0];
        testing.expect(mem.eql(u8, nextEdge.label, "_"));
        testing.expect(nextEdge.to.edges.items.len == 2);
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[0].label, "st"));
        testing.expect(mem.eql(u8, nextEdge.to.edges.items[1].label, "main"));

        const nextNextEdge = &nextEdge.to.edges.items[0];
        testing.expect(mem.eql(u8, nextNextEdge.to.edges.items[0].label, "art"));
    }
}

test "Trie.writeULEB128Mem" {
    var gpa = testing.allocator;
    var trie: Trie = .{};
    defer trie.deinit(gpa);

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

    var buffer: std.ArrayListUnmanaged(u8) = .{};
    defer buffer.deinit(gpa);

    try trie.writeULEB128Mem(gpa, &buffer);

    const exp_buffer = [_]u8{
        0x0,
        0x1,
        0x5f,
        0x0,
        0x5,
        0x0,
        0x2,
        0x5f,
        0x6d,
        0x68,
        0x5f,
        0x65,
        0x78,
        0x65,
        0x63,
        0x75,
        0x74,
        0x65,
        0x5f,
        0x68,
        0x65,
        0x61,
        0x64,
        0x65,
        0x72,
        0x0,
        0x21,
        0x6d,
        0x61,
        0x69,
        0x6e,
        0x0,
        0x25,
        0x2,
        0x0,
        0x0,
        0x0,
        0x3,
        0x0,
        0x80,
        0x20,
        0x0,
    };

    testing.expect(buffer.items.len == exp_buffer.len);
    testing.expect(mem.eql(u8, buffer.items, exp_buffer[0..]));
}
