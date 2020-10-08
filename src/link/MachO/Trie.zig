/// Represents export trie used in MachO executables and dynamic libraries.
/// The purpose of an export trie is to encode as compactly as possible all
/// export symbols for the loader `dyld`.
/// The export trie encodes offset and other information using ULEB128
/// encoding, and is part of the __LINKEDIT segment.
///
/// Description from loader.h:
///
/// The symbols exported by a dylib are encoded in a trie. This is a compact
/// representation that factors out common prefixes. It also reduces LINKEDIT pages
/// in RAM because it encodes all information (name, address, flags) in one small,
/// contiguous range. The export area is a stream of nodes. The first node sequentially
/// is the start node for the trie.
///
/// Nodes for a symbol start with a uleb128 that is the length of the exported symbol
/// information for the string so far. If there is no exported symbol, the node starts
/// with a zero byte. If there is exported info, it follows the length.
///
/// First is a uleb128 containing flags. Normally, it is followed by a uleb128 encoded
/// offset which is location of the content named by the symbol from the mach_header
/// for the image. If the flags is EXPORT_SYMBOL_FLAGS_REEXPORT, then following the flags
/// is a uleb128 encoded library ordinal, then a zero terminated UTF8 string. If the string
/// is zero length, then the symbol is re-export from the specified dylib with the same name.
/// If the flags is EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER, then following the flags is two
/// uleb128s: the stub offset and the resolver offset. The stub is used by non-lazy pointers.
/// The resolver is used by lazy pointers and must be called to get the actual address to use.
///
/// After the optional exported symbol information is a byte of how many edges (0-255) that
/// this node has leaving it, followed by each edge. Each edge is a zero terminated UTF8 of
/// the addition chars in the symbol, followed by a uleb128 offset for the node that edge points to.
const Trie = @This();

const std = @import("std");
const mem = std.mem;
const leb = std.debug.leb;
const log = std.log.scoped(.link);
const testing = std.testing;
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
    export_flags: ?u64 = null,
    vmaddr_offset: ?u64 = null,
    trie_offset: usize = 0,
    edges: std.ArrayListUnmanaged(Edge) = .{},

    fn deinit(self: *Node, alloc: *Allocator) void {
        for (self.edges.items) |*edge| {
            edge.deinit(alloc);
        }
        self.edges.deinit(alloc);
    }

    fn put(self: *Node, alloc: *Allocator, label: []const u8) !*Node {
        // Check for match with edges from this node.
        for (self.edges.items) |*edge| {
            const match = mem.indexOfDiff(u8, edge.label, label) orelse return edge.to;
            if (match == 0) continue;
            if (match == edge.label.len) return edge.to.put(alloc, label[match..]);

            // Found a match, need to splice up nodes.
            // From: A -> B
            // To: A -> C -> B
            const mid = try alloc.create(Node);
            mid.* = .{};
            const to_label = edge.label;
            const to_node = edge.to;
            edge.to = mid;
            edge.label = label[0..match];

            try mid.edges.append(alloc, .{
                .from = mid,
                .to = to_node,
                .label = to_label[match..],
            });

            if (match == label.len) {
                return to_node;
            } else {
                return mid.put(alloc, label[match..]);
            }
        }

        // Add a new edge.
        const node = try alloc.create(Node);
        node.* = .{};

        try self.edges.append(alloc, .{
            .from = self,
            .to = node,
            .label = label,
        });

        return node;
    }

    fn writeULEB128Mem(self: Node, alloc: *Allocator, buffer: *std.ArrayListUnmanaged(u8)) !void {
        if (self.vmaddr_offset) |offset| {
            // Terminal node info: encode export flags and vmaddr offset of this symbol.
            var info_buf_len: usize = 0;
            var info_buf: [@sizeOf(u64) * 2]u8 = undefined;
            info_buf_len += try leb.writeULEB128Mem(info_buf[0..], self.export_flags.?);
            info_buf_len += try leb.writeULEB128Mem(info_buf[info_buf_len..], offset);

            // Encode the size of the terminal node info.
            var size_buf: [@sizeOf(u64)]u8 = undefined;
            const size_buf_len = try leb.writeULEB128Mem(size_buf[0..], info_buf_len);

            // Now, write them to the output buffer.
            try buffer.ensureCapacity(alloc, buffer.items.len + info_buf_len + size_buf_len);
            buffer.appendSliceAssumeCapacity(size_buf[0..size_buf_len]);
            buffer.appendSliceAssumeCapacity(info_buf[0..info_buf_len]);
        } else {
            // Non-terminal node is delimited by 0 byte.
            try buffer.append(alloc, 0);
        }
        // Write number of edges (max legal number of edges is 256).
        try buffer.append(alloc, @intCast(u8, self.edges.items.len));

        for (self.edges.items) |edge| {
            // Write edges labels.
            try buffer.ensureCapacity(alloc, buffer.items.len + edge.label.len + 1); // +1 to account for null-byte
            buffer.appendSliceAssumeCapacity(edge.label);
            buffer.appendAssumeCapacity(0);

            var buf: [@sizeOf(u64)]u8 = undefined;
            const buf_len = try leb.writeULEB128Mem(buf[0..], edge.to.trie_offset);
            try buffer.appendSlice(alloc, buf[0..buf_len]);
        }
    }

    const UpdateResult = struct {
        node_size: usize,
        updated: bool,
    };

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
            node_size += edge.label.len + 1 + sizeULEB128Mem(edge.to.trie_offset);
        }

        const updated = offset != self.trie_offset;
        self.trie_offset = offset;

        return .{ .node_size = node_size, .updated = updated };
    }

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

root: Node,

/// Insert a symbol into the trie, updating the prefixes in the process.
/// This operation may change the layout of the trie by splicing edges in
/// certain circumstances.
pub fn put(self: *Trie, alloc: *Allocator, symbol: Symbol) !void {
    const node = try self.root.put(alloc, symbol.name);
    node.vmaddr_offset = symbol.vmaddr_offset;
    node.export_flags = symbol.export_flags;
}

/// Write the trie to a buffer ULEB128 encoded.
pub fn writeULEB128Mem(self: *Trie, alloc: *Allocator, buffer: *std.ArrayListUnmanaged(u8)) !void {
    var ordered_nodes: std.ArrayListUnmanaged(*Node) = .{};
    defer ordered_nodes.deinit(alloc);

    try walkInOrder(&self.root, alloc, &ordered_nodes);

    var more: bool = true;
    while (more) {
        var offset: usize = 0;
        more = false;
        for (ordered_nodes.items) |node| {
            const res = node.updateOffset(offset);
            offset += res.node_size;
            if (res.updated) more = true;
        }
    }

    for (ordered_nodes.items) |node| {
        try node.writeULEB128Mem(alloc, buffer);
    }
}

fn walkInOrder(node: *Node, alloc: *Allocator, list: *std.ArrayListUnmanaged(*Node)) error{OutOfMemory}!void {
    try list.append(alloc, node);
    for (node.edges.items) |*edge| {
        try walkInOrder(edge.to, alloc, list);
    }
}

pub fn deinit(self: *Trie, alloc: *Allocator) void {
    self.root.deinit(alloc);
}

test "Trie basic" {
    var gpa = testing.allocator;
    var trie: Trie = .{
        .root = .{},
    };
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
    var trie: Trie = .{
        .root = .{},
    };
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
