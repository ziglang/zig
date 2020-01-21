const std = @import("std");
const json = std.json;
const debug = std.debug;
const io = std.io;
const mem = std.mem;
const zig = std.zig;

const protocol = @import("protocol.zig");
const types = @import("types.zig");
const json_rpc = @import("json_rpc.zig");
const serial = @import("json_serialize.zig");
const data = @import("data.zig");

pub const TextDocument = struct {
    uri: types.DocumentUri,
    text: types.String,

    pub fn findPosition(self: *const TextDocument, position: types.Position) ?usize {
        var it = mem.separate(self.text, "\n");

        var line: i64 = 0;
        while (line < position.line) {
            _ = it.next() orelse return null;
            line += 1;
        }

        var index = @intCast(i64, it.index.?) + position.character;

        if (index < 0 or index >= @intCast(i64, self.text.len)) {
            return null;
        }

        return @intCast(usize, index);
    }
};

pub const Server = struct {
    const Self = @This();

    const MethodError = json_rpc.Dispatcher(Server).MethodError;

    alloc: *mem.Allocator,
    documents: std.StringHashMap(TextDocument),

    pub fn init(allocator: *mem.Allocator) Self {
        return Self{
            .alloc = allocator,
            .documents = std.StringHashMap(TextDocument).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.documents.deinit();
    }

    pub fn onInitialize(self: *Self, req: json_rpc.Request) !void {
        const result =
            \\{
            \\    "capabilities": {
            \\        "textDocumentSync": {"change" :1},
            \\        "completionProvider": {"triggerCharacters": ["@"]}
            \\    }
            \\}
        ;

        var parser = json.Parser.init(self.alloc, false);
        defer parser.deinit();

        var tree = try parser.parse(result[0..]);
        defer tree.deinit();

        var response = json_rpc.Response{
            .result = .{ .Defined = tree.root },
            .id = req.id.Defined, // TODO check
        };
        msgWrite.writeResponse(response) catch return MethodError.InternalError;
    }

    pub fn onInitialized(self: *Self, req: json_rpc.Request) MethodError!void {}

    pub fn onTextDocumentDidChange(self: *Self, req: json_rpc.Request) !void {
        const params = serial.deserialize(types.DidChangeTextDocumentParams, req.params, self.alloc) catch return MethodError.InvalidParams;

        (try self.documents.getOrPut(params.textDocument.uri)).kv.value = TextDocument{
            .uri = params.textDocument.uri,
            .text = params.contentChanges[0].text,
        };

        const tree = zig.parse(self.alloc, params.contentChanges[0].text) catch return MethodError.InternalError;
        defer tree.deinit();

        var diagnostics = try self.alloc.alloc(types.Diagnostic, tree.errors.len);
        defer self.alloc.free(diagnostics);

        var msgAlloc = std.heap.ArenaAllocator.init(self.alloc);
        defer msgAlloc.deinit();

        var it = tree.errors.iterator(0);
        var i: usize = 0;
        while (it.next()) |err| : (i += 1) {
            const token = tree.tokens.at(err.loc());
            const location = tree.tokenLocation(0, err.loc());

            var text_buf = try std.Buffer.initSize(&msgAlloc.allocator, 0);
            var out_stream = &std.io.BufferOutStream.init(&text_buf).stream;
            try err.render(&tree.tokens, out_stream);

            diagnostics[i] = types.Diagnostic{
                .range = types.Range{
                    .start = types.Position{
                        .line = @intCast(i64, location.line),
                        .character = @intCast(i64, location.column),
                    },
                    .end = types.Position{
                        .line = @intCast(i64, location.line),
                        .character = @intCast(i64, location.column + (token.end - token.start)),
                    },
                },
                .severity = .{ .Defined = types.DiagnosticSeverity.Error },
                .message = text_buf.toSlice(),
            };
        }

        const outParam = types.PublishDiagnosticsParams{
            .uri = params.textDocument.uri,
            .diagnostics = diagnostics,
        };

        var request = json_rpc.Request{
            .method = "textDocument/publishDiagnostics",
            .params = try serial.serialize2(outParam, self.alloc),
        };
        try msgWrite.writeRequest(request);
    }

    pub fn onTextDocumentCompletion(self: *Self, req: json_rpc.Request) !void {
        const params = serial.deserialize(types.CompletionParams, req.params, self.alloc) catch return MethodError.InvalidParams;

        const document = (self.documents.getValue(params.textDocument.uri) orelse return MethodError.InvalidParams);

        const posToCheck = types.Position{
            .line = params.position.line,
            .character = params.position.character - 1,
        };

        if (posToCheck.character >= 0) {
            const pos = document.findPosition(posToCheck) orelse return MethodError.InvalidParams;
            const char = document.text[pos];
            if (char == '@') {
                var items: [data.builtins.len]types.CompletionItem = undefined;

                for (data.builtins) |builtin, i| {
                    items[i] = types.CompletionItem{
                        .label = builtin,
                        .kind = .{ .Defined = types.CompletionItemKind.Function },
                        .textEdit = .{
                            .Defined = types.TextEdit{
                                .range = types.Range{
                                    .start = params.position,
                                    .end = params.position,
                                },
                                .newText = builtin[1..],
                            },
                        },
                        .filterText = .{ .Defined = builtin[1..] },
                    };
                }

                var response = json_rpc.Response{
                    .id = req.id.Defined, // TODO check
                    .result = .{ .Defined = try serial.serialize2(items[0..], self.alloc) },
                };
                try msgWrite.writeResponse(response);
                return;
            }
        }

        var response = json_rpc.Response{
            .id = req.id.Defined, // TODO check
            .result = .{ .Defined = json.Value.Null },
        };
        try msgWrite.writeResponse(response);
    }
};

var heap = std.heap.direct_allocator;
var out: *io.OutStream(std.fs.File.WriteError) = undefined;
var msgWrite: protocol.MessageWriter(std.fs.File.WriteError) = undefined;

pub fn main() !void {
    var in = io.getStdIn().inStream();
    var stdoutStream = io.getStdOut().outStream();
    out = &stdoutStream.stream;

    var msgReader = protocol.MessageReader(std.fs.File.ReadError).init(&in.stream, heap);
    defer msgReader.deinit();

    msgWrite = protocol.MessageWriter(std.fs.File.WriteError).init(out, heap);

    var server = Server.init(heap);

    var dispatcher = json_rpc.Dispatcher(Server).init(&server, heap);
    defer dispatcher.deinit();

    try dispatcher.register("initialize", Server.onInitialize);
    try dispatcher.register("initialized", Server.onInitialized);
    try dispatcher.register("textDocument/didChange", Server.onTextDocumentDidChange);
    try dispatcher.register("textDocument/completion", Server.onTextDocumentCompletion);

    while (true) {
        const request = try msgReader.readMessage();

        dispatcher.dispatch(request) catch |err| {
            debug.warn("{}", .{err});
        };
    }
}
