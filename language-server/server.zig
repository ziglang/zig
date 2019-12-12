const std = @import("std");
const json = std.json;
const debug = std.debug;
const io = std.io;
const mem = std.mem;
const warn = debug.warn;

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
        while(line < position.line){
            _ = it.next() orelse return null;
            line += 1;
        }

        var index = @intCast(i64, it.index.?) + position.character;

        if(index < 0 or index >= @intCast(i64, self.text.len)){
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
        return Self {
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

        var response = json_rpc.Response {
            .result = .{ .Defined = tree.root },
            .id = req.id.Defined // TODO check
        };
        msgWrite.writeResponse(response) catch return MethodError.InternalError;
    }

    pub fn onInitialized(self: *Self, req: json_rpc.Request) MethodError!void {

    }

    pub fn onTextDocumentDidChange(self: *Self, req: json_rpc.Request) !void {
        const params = serial.deserialize(types.DidChangeTextDocumentParams, req.params, self.alloc) catch return MethodError.InvalidParams;
        
        (try self.documents.getOrPut(params.textDocument.uri)).kv.value = TextDocument {
            .uri = params.textDocument.uri,
            .text = params.contentChanges[0].text,
        };

        const tmpFilePath = "/home/mwa/code/tmp";

        const fileContents = try mem.concat(self.alloc, u8, [_][]const u8{params.contentChanges[0].text, 
            \\test "__lsp" {
            \\    _ = @import("std").meta.refAllDecls(@This());
            \\}
        });

        try io.writeFile("/home/mwa/code/tmp", fileContents);

        const result = try std.ChildProcess.exec(self.alloc, [_][]const u8{
            "/home/mwa/code/zig/build/bin/zig",
            "test",
            "/home/mwa/code/tmp",
            "--test-filter",
            "__lsp",
            "-fno-emit-bin"
        }, null, null, 10 * 1024 * 1024);

        warn("STDOUT:\n{}\n\nSTDERR:\n{}\n\n", result.stdout, result.stderr);

        switch (result.term) {
            .Exited => |exit_code| {
                if (exit_code != 0) {
                    const lineEnd = mem.indexOf(u8, result.stderr, "\n") orelse return MethodError.InternalError;
                    const line = result.stderr[0..lineEnd];
                    var it = mem.separate(line, ":");
                    _ = it.next();
                    const lineNumber = try std.fmt.parseInt(i64, it.next() orelse return MethodError.InternalError, 10);
                    const charNumber = try std.fmt.parseInt(i64, it.next() orelse return MethodError.InternalError, 10);
                    const message = line[it.index.? ..];

                    const diagnostic = [1]types.Diagnostic {
                        types.Diagnostic {
                            .range = types.Range {
                                .start = types.Position {
                                    .line = lineNumber - 1,
                                    .character = charNumber - 1
                                },
                                .end = types.Position {
                                    .line = lineNumber - 1,
                                    .character = charNumber - 1
                                }
                            },
                            .severity = .{ .Defined = types.DiagnosticSeverity.Error },
                            .message = message,
                        }
                    };

                    const outParam = types.PublishDiagnosticsParams {
                        .uri = params.textDocument.uri,
                        .diagnostics = diagnostic[0..]
                    };

                    var request = json_rpc.Request {
                        .method = "textDocument/publishDiagnostics",
                        .params = try serial.serialize2(outParam, self.alloc)
                    };
                    try msgWrite.writeRequest(request);
                }
            },
            else => {
                // Crashed
                return MethodError.InternalError;
            },
        }
    }

    pub fn onTextDocumentCompletion(self: *Self, req: json_rpc.Request) !void {
        const params = serial.deserialize(types.CompletionParams, req.params, self.alloc) catch return MethodError.InvalidParams;

        const document = (self.documents.getValue(params.textDocument.uri) orelse return MethodError.InvalidParams);

        const posToCheck = types.Position {
            .line = params.position.line,
            .character = params.position.character - 1,
        };

        if(posToCheck.character >= 0){
            const pos = document.findPosition(posToCheck) orelse return MethodError.InvalidParams;
            const char = document.text[pos];
            if(char == '@'){
                var items: [data.builtins.len]types.CompletionItem = undefined;

                for(data.builtins) |builtin, i| {
                    items[i] = types.CompletionItem {
                        .label = builtin,
                        .kind = .{ .Defined = types.CompletionItemKind.Function },
                        .textEdit = .{ .Defined = types.TextEdit {
                            .range = types.Range {
                                .start = params.position,
                                .end = params.position,
                            },
                            .newText = builtin[1..],
                        }},
                        .filterText = .{ .Defined =  builtin[1..] },
                    };
                }

                var response = json_rpc.Response {
                    .id = req.id.Defined, // TODO check
                    .result = .{ .Defined = try serial.serialize2(items[0..], self.alloc) },
                };
                try msgWrite.writeResponse(response);
                return;
            }
        }

        var response = json_rpc.Response {
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

    while(true){
        const request = try msgReader.readMessage();

        dispatcher.dispatch(request) catch |err| {
            debug.warn("{}", err);
        };
    }
}
