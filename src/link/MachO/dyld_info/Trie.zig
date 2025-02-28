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

/// The root node of the trie.
root: ?Node.Index = null,
buffer: std.ArrayListUnmanaged(u8) = .empty,
nodes: std.MultiArrayList(Node) = .{},
edges: std.ArrayListUnmanaged(Edge) = .empty,

/// Insert a symbol into the trie, updating the prefixes in the process.
/// This operation may change the layout of the trie by splicing edges in
/// certain circumstances.
fn put(self: *Trie, allocator: Allocator, symbol: ExportSymbol) !void {
    // const tracy = trace(@src());
    // defer tracy.end();

    const node_index = try self.putNode(self.root.?, allocator, symbol.name);
    const slice = self.nodes.slice();
    slice.items(.is_terminal)[node_index] = true;
    slice.items(.vmaddr_offset)[node_index] = symbol.vmaddr_offset;
    slice.items(.export_flags)[node_index] = symbol.export_flags;
}

/// Inserts a new node starting at `node_index`.
fn putNode(self: *Trie, node_index: Node.Index, allocator: Allocator, label: []const u8) !Node.Index {
    // Check for match with edges from this node.
    for (self.nodes.items(.edges)[node_index].items) |edge_index| {
        const edge = &self.edges.items[edge_index];
        const match = mem.indexOfDiff(u8, edge.label, label) orelse return edge.node;
        if (match == 0) continue;
        if (match == edge.label.len) return self.putNode(edge.node, allocator, label[match..]);

        // Found a match, need to splice up nodes.
        // From: A -> B
        // To: A -> C -> B
        const mid_index = try self.addNode(allocator);
        const to_label = edge.label[match..];
        const to_node = edge.node;
        edge.node = mid_index;
        edge.label = label[0..match];

        const new_edge_index = try self.addEdge(allocator);
        const new_edge = &self.edges.items[new_edge_index];
        new_edge.node = to_node;
        new_edge.label = to_label;
        try self.nodes.items(.edges)[mid_index].append(allocator, new_edge_index);

        return if (match == label.len) mid_index else self.putNode(mid_index, allocator, label[match..]);
    }

    // Add a new node.
    const new_node_index = try self.addNode(allocator);
    const new_edge_index = try self.addEdge(allocator);
    const new_edge = &self.edges.items[new_edge_index];
    new_edge.node = new_node_index;
    new_edge.label = label;
    try self.nodes.items(.edges)[node_index].append(allocator, new_edge_index);

    return new_node_index;
}

pub fn updateSize(self: *Trie, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    try self.init(gpa);
    try self.nodes.ensureUnusedCapacity(gpa, macho_file.resolver.values.items.len * 2);
    try self.edges.ensureUnusedCapacity(gpa, macho_file.resolver.values.items.len * 2);

    const seg = macho_file.getTextSegment();
    for (macho_file.resolver.values.items) |ref| {
        if (ref.getFile(macho_file) == null) continue;
        const sym = ref.getSymbol(macho_file).?;
        if (!sym.flags.@"export") continue;
        if (sym.getAtom(macho_file)) |atom| if (!atom.isAlive()) continue;
        var flags: u64 = if (sym.flags.abs)
            macho.EXPORT_SYMBOL_FLAGS_KIND_ABSOLUTE
        else if (sym.flags.tlv)
            macho.EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL
        else
            macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR;
        if (sym.flags.weak) {
            flags |= macho.EXPORT_SYMBOL_FLAGS_WEAK_DEFINITION;
            macho_file.weak_defines.store(true, .seq_cst);
            macho_file.binds_to_weak.store(true, .seq_cst);
        }
        try self.put(gpa, .{
            .name = sym.getName(macho_file),
            .vmaddr_offset = sym.getAddress(.{ .stubs = false }, macho_file) - seg.vmaddr,
            .export_flags = flags,
        });
    }

    try self.finalize(gpa);

    macho_file.dyld_info_cmd.export_size = mem.alignForward(u32, @intCast(self.buffer.items.len), @alignOf(u64));
}

/// Finalizes this trie for writing to a byte stream.
/// This step performs multiple passes through the trie ensuring
/// there are no gaps after every `Node` is ULEB128 encoded.
/// Call this method before trying to `write` the trie to a byte stream.
fn finalize(self: *Trie, allocator: Allocator) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var ordered_nodes = std.ArrayList(Node.Index).init(allocator);
    defer ordered_nodes.deinit();
    try ordered_nodes.ensureTotalCapacityPrecise(self.nodes.items(.is_terminal).len);

    var fifo = std.fifo.LinearFifo(Node.Index, .Dynamic).init(allocator);
    defer fifo.deinit();

    try fifo.writeItem(self.root.?);

    while (fifo.readItem()) |next_index| {
        const edges = &self.nodes.items(.edges)[next_index];
        for (edges.items) |edge_index| {
            const edge = self.edges.items[edge_index];
            try fifo.writeItem(edge.node);
        }
        ordered_nodes.appendAssumeCapacity(next_index);
    }

    var more: bool = true;
    var size: u32 = 0;
    while (more) {
        size = 0;
        more = false;
        for (ordered_nodes.items) |node_index| {
            const res = try self.finalizeNode(node_index, size);
            size += res.node_size;
            if (res.updated) more = true;
        }
    }

    try self.buffer.ensureTotalCapacityPrecise(allocator, size);
    for (ordered_nodes.items) |node_index| {
        try self.writeNode(node_index, self.buffer.writer(allocator));
    }
}

const FinalizeNodeResult = struct {
    /// Current size of this node in bytes.
    node_size: u32,

    /// True if the trie offset of this node in the output byte stream
    /// would need updating; false otherwise.
    updated: bool,
};

/// Updates offset of this node in the output byte stream.
fn finalizeNode(self: *Trie, node_index: Node.Index, offset_in_trie: u32) !FinalizeNodeResult {
    var stream = std.io.countingWriter(std.io.null_writer);
    const writer = stream.writer();
    const slice = self.nodes.slice();

    var node_size: u32 = 0;
    if (slice.items(.is_terminal)[node_index]) {
        const export_flags = slice.items(.export_flags)[node_index];
        const vmaddr_offset = slice.items(.vmaddr_offset)[node_index];
        try leb.writeULEB128(writer, export_flags);
        try leb.writeULEB128(writer, vmaddr_offset);
        try leb.writeULEB128(writer, stream.bytes_written);
    } else {
        node_size += 1; // 0x0 for non-terminal nodes
    }
    node_size += 1; // 1 byte for edge count

    for (slice.items(.edges)[node_index].items) |edge_index| {
        const edge = &self.edges.items[edge_index];
        const next_node_offset = slice.items(.trie_offset)[edge.node];
        node_size += @intCast(edge.label.len + 1);
        try leb.writeULEB128(writer, next_node_offset);
    }

    const trie_offset = slice.items(.trie_offset)[node_index];
    const updated = offset_in_trie != trie_offset;
    slice.items(.trie_offset)[node_index] = offset_in_trie;
    node_size += @intCast(stream.bytes_written);

    return .{ .node_size = node_size, .updated = updated };
}

fn init(self: *Trie, allocator: Allocator) !void {
    assert(self.root == null);
    self.root = try self.addNode(allocator);
}

pub fn deinit(self: *Trie, allocator: Allocator) void {
    for (self.nodes.items(.edges)) |*edges| {
        edges.deinit(allocator);
    }
    self.nodes.deinit(allocator);
    self.edges.deinit(allocator);
    self.buffer.deinit(allocator);
}

pub fn write(self: Trie, writer: anytype) !void {
    if (self.buffer.items.len == 0) return;
    try writer.writeAll(self.buffer.items);
}

/// Writes this node to a byte stream.
/// The children of this node *are* not written to the byte stream
/// recursively. To write all nodes to a byte stream in sequence,
/// iterate over `Trie.ordered_nodes` and call this method on each node.
/// This is one of the requirements of the MachO.
/// Panics if `finalize` was not called before calling this method.
fn writeNode(self: *Trie, node_index: Node.Index, writer: anytype) !void {
    const slice = self.nodes.slice();
    const edges = slice.items(.edges)[node_index];
    const is_terminal = slice.items(.is_terminal)[node_index];
    const export_flags = slice.items(.export_flags)[node_index];
    const vmaddr_offset = slice.items(.vmaddr_offset)[node_index];

    if (is_terminal) {
        // Terminal node info: encode export flags and vmaddr offset of this symbol.
        var info_buf: [@sizeOf(u64) * 2]u8 = undefined;
        var info_stream = std.io.fixedBufferStream(&info_buf);
        // TODO Implement for special flags.
        assert(export_flags & macho.EXPORT_SYMBOL_FLAGS_REEXPORT == 0 and
            export_flags & macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER == 0);
        try leb.writeULEB128(info_stream.writer(), export_flags);
        try leb.writeULEB128(info_stream.writer(), vmaddr_offset);

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
    try writer.writeByte(@as(u8, @intCast(edges.items.len)));

    for (edges.items) |edge_index| {
        const edge = self.edges.items[edge_index];
        // Write edge label and offset to next node in trie.
        try writer.writeAll(edge.label);
        try writer.writeByte(0);
        try leb.writeULEB128(writer, slice.items(.trie_offset)[edge.node]);
    }
}

fn addNode(self: *Trie, allocator: Allocator) !Node.Index {
    const index: Node.Index = @intCast(try self.nodes.addOne(allocator));
    self.nodes.set(index, .{});
    return index;
}

fn addEdge(self: *Trie, allocator: Allocator) !Edge.Index {
    const index: Edge.Index = @intCast(self.edges.items.len);
    const edge = try self.edges.addOne(allocator);
    edge.* = .{};
    return index;
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

const Node = struct {
    is_terminal: bool = false,

    /// Export flags associated with this exported symbol.
    export_flags: u64 = 0,

    /// VM address offset wrt to the section this symbol is defined against.
    vmaddr_offset: u64 = 0,

    /// Offset of this node in the trie output byte stream.
    trie_offset: u32 = 0,

    /// List of all edges originating from this node.
    edges: std.ArrayListUnmanaged(Edge.Index) = .empty,

    const Index = u32;
};

/// Edge connecting nodes in the trie.
const Edge = struct {
    /// Target node in the trie.
    node: Node.Index = 0,

    /// Matching prefix.
    label: []const u8 = "",

    const Index = u32;
};

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
    const gpa = testing.allocator;
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
    try expectEqualHexStrings(&exp_buffer, trie.buffer.items);
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
    try expectEqualHexStrings(&exp_buffer, trie.buffer.items);
}

const assert = std.debug.assert;
const leb = std.leb;
const log = std.log.scoped(.macho);
const macho = std.macho;
const mem = std.mem;
const std = @import("std");
const testing = std.testing;
const trace = @import("../../../tracy.zig").trace;

const Allocator = mem.Allocator;
const MachO = @import("../../MachO.zig");
const Trie = @This();
