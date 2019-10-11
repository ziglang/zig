const builtin = @import("builtin");
const std = @import("std");
const json = std.json;
const mem = std.mem;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    var parser: json.Parser = undefined;
    var dump = Dump.init(allocator);
    for (args[1..]) |arg| {
        parser = json.Parser.init(allocator, false);
        const json_text = try std.io.readFileAlloc(allocator, arg);
        const tree = try parser.parse(json_text);
        try dump.mergeJson(tree.root);
    }

    const stdout = try std.io.getStdOut();
    try dump.render(&stdout.outStream().stream);
}

/// AST source node
const Node = struct {
    file: usize,
    line: usize,
    col: usize,
    fields: []usize,

    fn hash(n: Node) u32 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, n.file);
        std.hash.autoHash(&hasher, n.line);
        std.hash.autoHash(&hasher, n.col);
        return @truncate(u32, hasher.final());
    }

    fn eql(a: Node, b: Node) bool {
        return a.file == b.file and
            a.line == b.line and
            a.col == b.col;
    }
};

const Dump = struct {
    zig_id: ?[]const u8 = null,
    zig_version: ?[]const u8 = null,
    root_name: ?[]const u8 = null,
    targets: std.ArrayList([]const u8),

    const FileMap = std.StringHashMap(usize);
    file_list: std.ArrayList([]const u8),
    file_map: FileMap,

    const NodeMap = std.HashMap(Node, usize, Node.hash, Node.eql);
    node_list: std.ArrayList(Node),
    node_map: NodeMap,

    fn init(allocator: *mem.Allocator) Dump {
        return Dump{
            .targets = std.ArrayList([]const u8).init(allocator),
            .file_list = std.ArrayList([]const u8).init(allocator),
            .file_map = FileMap.init(allocator),
            .node_list = std.ArrayList(Node).init(allocator),
            .node_map = NodeMap.init(allocator),
        };
    }

    fn mergeJson(self: *Dump, root: json.Value) !void {
        const params = &root.Object.get("params").?.value.Object;
        const zig_id = params.get("zigId").?.value.String;
        const zig_version = params.get("zigVersion").?.value.String;
        const root_name = params.get("rootName").?.value.String;
        try mergeSameStrings(&self.zig_id, zig_id);
        try mergeSameStrings(&self.zig_version, zig_version);
        try mergeSameStrings(&self.root_name, root_name);

        for (params.get("builds").?.value.Array.toSliceConst()) |json_build| {
            const target = json_build.Object.get("target").?.value.String;
            try self.targets.append(target);
        }

        // Merge files. If the string matches, it's the same file.
        const other_files = root.Object.get("files").?.value.Array.toSliceConst();
        var other_file_to_mine = std.AutoHashMap(usize, usize).init(self.a());
        for (other_files) |other_file, i| {
            const gop = try self.file_map.getOrPut(other_file.String);
            if (!gop.found_existing) {
                gop.kv.value = self.file_list.len;
                try self.file_list.append(other_file.String);
            }
            try other_file_to_mine.putNoClobber(i, gop.kv.value);
        }

        // Merge AST nodes. If the file id, line, and column all match, it's the same AST node.
        const other_ast_nodes = root.Object.get("astNodes").?.value.Array.toSliceConst();
        var other_ast_node_to_mine = std.AutoHashMap(usize, usize).init(self.a());
        for (other_ast_nodes) |other_ast_node_json, i| {
            const other_file_id = jsonObjInt(other_ast_node_json, "file");
            const other_node = Node{
                .line = jsonObjInt(other_ast_node_json, "line"),
                .col = jsonObjInt(other_ast_node_json, "col"),
                .file = other_file_to_mine.getValue(other_file_id).?,
                .fields = ([*]usize)(undefined)[0..0],
            };
            const gop = try self.node_map.getOrPut(other_node);
            if (!gop.found_existing) {
                gop.kv.value = self.node_list.len;
                try self.node_list.append(other_node);
            }
            try other_ast_node_to_mine.putNoClobber(i, gop.kv.value);
        }
        // convert fields lists
        for (other_ast_nodes) |other_ast_node_json, i| {
            const my_node_index = other_ast_node_to_mine.get(i).?.value;
            const my_node = &self.node_list.toSlice()[my_node_index];
            if (other_ast_node_json.Object.get("fields")) |fields_json_kv| {
                const other_fields = fields_json_kv.value.Array.toSliceConst();
                my_node.fields = try self.a().alloc(usize, other_fields.len);
                for (other_fields) |other_field_index, field_i| {
                    const other_index = @intCast(usize, other_field_index.Integer);
                    my_node.fields[field_i] = other_ast_node_to_mine.get(other_index).?.value;
                }
            }
        }

        // Merge errors. If the AST Node matches, it's the same error value.
    }

    fn render(self: *Dump, stream: var) !void {
        var jw = json.WriteStream(@typeOf(stream).Child, 10).init(stream);
        try jw.beginObject();

        try jw.objectField("typeKinds");
        try jw.beginArray();
        inline for (@typeInfo(builtin.TypeId).Enum.fields) |field| {
            try jw.arrayElem();
            try jw.emitString(field.name);
        }
        try jw.endArray();

        try jw.objectField("params");
        try jw.beginObject();

        try jw.objectField("zigId");
        try jw.emitString(self.zig_id.?);

        try jw.objectField("zigVersion");
        try jw.emitString(self.zig_version.?);

        try jw.objectField("rootName");
        try jw.emitString(self.root_name.?);

        try jw.objectField("builds");
        try jw.beginArray();
        for (self.targets.toSliceConst()) |target| {
            try jw.arrayElem();
            try jw.beginObject();
            try jw.objectField("target");
            try jw.emitString(target);
            try jw.endObject();
        }
        try jw.endArray();

        try jw.endObject();

        try jw.objectField("astNodes");
        try jw.beginArray();
        for (self.node_list.toSliceConst()) |node| {
            try jw.arrayElem();
            try jw.beginObject();

            try jw.objectField("file");
            try jw.emitNumber(node.file);

            try jw.objectField("line");
            try jw.emitNumber(node.line);

            try jw.objectField("col");
            try jw.emitNumber(node.col);

            if (node.fields.len != 0) {
                try jw.objectField("fields");
                try jw.beginArray();

                for (node.fields) |field_node_index| {
                    try jw.arrayElem();
                    try jw.emitNumber(field_node_index);
                }
                try jw.endArray();
            }

            try jw.endObject();
        }
        try jw.endArray();

        try jw.objectField("files");
        try jw.beginArray();
        for (self.file_list.toSliceConst()) |file| {
            try jw.arrayElem();
            try jw.emitString(file);
        }
        try jw.endArray();

        try jw.endObject();
    }

    fn a(self: Dump) *mem.Allocator {
        return self.targets.allocator;
    }

    fn mergeSameStrings(opt_dest: *?[]const u8, src: []const u8) !void {
        if (opt_dest.*) |dest| {
            if (!mem.eql(u8, dest, src))
                return error.MismatchedDumps;
        } else {
            opt_dest.* = src;
        }
    }
};

fn jsonObjInt(json_val: json.Value, field: []const u8) usize {
    const uncasted = json_val.Object.get(field).?.value.Integer;
    return @intCast(usize, uncasted);
}
