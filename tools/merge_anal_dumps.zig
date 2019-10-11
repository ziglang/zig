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

const Dump = struct {
    zig_id: ?[]const u8 = null,
    zig_version: ?[]const u8 = null,
    root_name: ?[]const u8 = null,
    targets: std.ArrayList([]const u8),
    files_list: std.ArrayList([]const u8),
    files_map: std.StringHashMap(usize),

    fn init(allocator: *mem.Allocator) Dump {
        return Dump{
            .targets = std.ArrayList([]const u8).init(allocator),
            .files_list = std.ArrayList([]const u8).init(allocator),
            .files_map = std.StringHashMap(usize).init(allocator),
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

        const target = params.get("target").?.value.String;
        try self.targets.append(target);

        // Merge files
        const other_files = root.Object.get("files").?.value.Array.toSliceConst();
        var other_file_to_mine = std.AutoHashMap(usize, usize).init(self.a());
        for (other_files) |other_file, i| {
            const gop = try self.files_map.getOrPut(other_file.String);
            if (gop.found_existing) {
                try other_file_to_mine.putNoClobber(i, gop.kv.value);
            } else {
                gop.kv.value = self.files_list.len;
                try self.files_list.append(other_file.String);
            }
        }

        const other_ast_nodes = root.Object.get("astNodes").?.value.Array.toSliceConst();
        var other_ast_node_to_mine = std.AutoHashMap(usize, usize).init(self.a());
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

        try jw.objectField("files");
        try jw.beginArray();
        for (self.files_list.toSliceConst()) |file| {
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
