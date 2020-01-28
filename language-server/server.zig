const std = @import("std");
const json = std.json;
const debug = std.debug;
const io = std.io;
const mem = std.mem;
const zig = std.zig;

const protocol = @import("protocol.zig");
const types = @import("types.zig");
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

    const MethodError = protocol.Dispatcher(Server).MethodError;

    alloc: *mem.Allocator,
    outStream: *io.OutStream(std.fs.File.WriteError),
    documents: std.StringHashMap(TextDocument),

    pub fn init(allocator: *mem.Allocator, outStream: *io.OutStream(std.fs.File.WriteError)) Self {
        return Self{
            .alloc = allocator,
            .outStream = outStream,
            .documents = std.StringHashMap(TextDocument).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.documents.deinit();
    }

    fn send(self: *Self, requestOrResponse: var) !void {
        debug.assert(requestOrResponse.validate());

        var mem_buffer: [1024 * 128]u8 = undefined;
        var sliceStream = io.SliceOutStream.init(mem_buffer[0..]);
        var jsonStream = json.WriteStream(@TypeOf(sliceStream.stream), 1024).init(&sliceStream.stream);

        try serial.serialize(requestOrResponse, &jsonStream);
        try protocol.writeMessage(self.outStream, sliceStream.getWritten());
    }

    pub fn onInitialize(self: *Self, params: types.InitializeParams, reqId: types.RequestId) !void {
        const result =
            \\{
            \\    "capabilities": {
            \\        "textDocumentSync": {"openClose": true, "change": 1},
            \\        "completionProvider": {"triggerCharacters": ["@"]}
            \\    }
            \\}
        ;

        var parser = json.Parser.init(self.alloc, false);
        defer parser.deinit();

        var tree = try parser.parse(result[0..]);
        defer tree.deinit();

        try self.send(types.Response{
            .result = .{ .Defined = tree.root },
            .id = reqId,
        });
    }

    pub fn onInitialized(self: *Self, params: types.InitializedParams) MethodError!void {}

    pub fn onTextDocumentDidOpen(self: *Self, params: types.DidOpenTextDocumentParams) !void {
        const document = TextDocument{
            .uri = try mem.dupe(self.alloc, u8, params.textDocument.uri),
            .text = try mem.dupe(self.alloc, u8, params.textDocument.text),
        };

        const alreadyThere = try self.documents.put(document.uri, document);
        if (alreadyThere != null) {
            return MethodError.InvalidParams;
        }

        try self.publishDiagnostics(document);
    }

    pub fn onTextDocumentDidChange(self: *Self, params: types.DidChangeTextDocumentParams) !void {
        var entry = self.documents.get(params.textDocument.uri) orelse return MethodError.InvalidParams;
        self.alloc.free(entry.*.value.text);
        entry.*.value.text = try mem.dupe(self.alloc, u8, params.contentChanges[0].text);

        try self.publishDiagnostics(entry.*.value);
    }

    pub fn onTextDocumentDidClose(self: *Self, params: types.DidCloseTextDocumentParams) !void {
        var maybeEntry = self.documents.remove(params.textDocument.uri);
        if (maybeEntry) |entry| {
            self.alloc.free(entry.value.uri);
            self.alloc.free(entry.value.text);
        } else {
            return MethodError.InvalidParams;
        }
    }

    fn publishDiagnostics(self: *Self, document: TextDocument) !void {
        const tree = try zig.parse(self.alloc, document.text);
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
            .uri = document.uri,
            .diagnostics = diagnostics,
        };

        var resultTree = try serial.serialize2(outParam, self.alloc);
        defer resultTree.deinit();

        try self.send(types.Request{
            .method = "textDocument/publishDiagnostics",
            .params = resultTree.root,
        });
    }

    pub fn onTextDocumentCompletion(self: *Self, params: types.CompletionParams, reqId: types.RequestId) !void {
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

                var tree = try serial.serialize2(items[0..], self.alloc);
                defer tree.deinit();

                try self.send(types.Response{
                    .id = reqId,
                    .result = .{ .Defined = tree.root },
                });
                return;
            }
        }

        try self.send(types.Response{
            .id = reqId,
            .result = .{ .Defined = json.Value.Null },
        });
    }
};

pub fn main() !void {
    var failingAlloc = std.debug.FailingAllocator.init(std.heap.page_allocator, 10000000000);
    const heap = &failingAlloc.allocator;
    // const heap = std.heap.page_allocator;

    var in = io.getStdIn().inStream();
    var out = io.getStdOut().outStream();

    var server = Server.init(heap, &out.stream);
    defer server.deinit();

    var dispatcher = protocol.Dispatcher(Server).init(&server, heap);
    defer dispatcher.deinit();

    try dispatcher.registerRequest("initialize", types.InitializeParams, Server.onInitialize);
    try dispatcher.registerNotification("initialized", types.InitializedParams, Server.onInitialized);
    try dispatcher.registerNotification("textDocument/didOpen", types.DidOpenTextDocumentParams, Server.onTextDocumentDidOpen);
    try dispatcher.registerNotification("textDocument/didChange", types.DidChangeTextDocumentParams, Server.onTextDocumentDidChange);
    try dispatcher.registerNotification("textDocument/didClose", types.DidCloseTextDocumentParams, Server.onTextDocumentDidClose);
    try dispatcher.registerRequest("textDocument/completion", types.CompletionParams, Server.onTextDocumentCompletion);

    while (true) {
        debug.warn("mem: {}\n", .{failingAlloc.allocated_bytes - failingAlloc.freed_bytes});
        const message = try protocol.readMessageAlloc(&in.stream, heap);
        defer heap.free(message);

        var parser = json.Parser.init(heap, false);
        defer parser.deinit();

        var tree = try parser.parse(message);
        defer tree.deinit();

        var request = try serial.deserialize(types.Request, tree.root, heap);
        defer request.deinit();

        if (!request.result.validate()) {
            return error.InvalidMessage;
        }

        dispatcher.dispatch(request.result) catch |err| {
            debug.warn("{}\n", .{err});
        };
    }
}
