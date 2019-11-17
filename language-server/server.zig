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

pub const Server = struct {
    const Self = @This();

    const MethodError = json_rpc.Dispatcher(Server).MethodError;

    pub fn onInitialize(self: *Self, req: json_rpc.Request) MethodError!void {
        const outJson =
            \\{
            \\    "jsonrpc": "2.0",
            \\    "result": {
            \\        "capabilities": {
            \\            "textDocumentSync": {"change" :1}
            \\        }
            \\    },
            \\    "id": 0
            \\}
        ;
        msgWrite.writeString(outJson[0..]) catch return MethodError.InternalError;
    }

    pub fn onInitialized(self: *Self, req: json_rpc.Request) MethodError!void {

    }

    pub fn onTextDocumentDidChange(self: *Self, req: json_rpc.Request) MethodError!void {
        var params = serial.deserialize(types.DidChangeTextDocumentParams, req.params, heap) catch return MethodError.InvalidParams;
        
        const tmpFilePath = "/home/mwa/code/tmp";

        const fileContents = mem.concat(heap, u8, [_][]const u8{params.contentChanges[0].text, 
            \\test "__lsp" {
            \\    _ = @import("std").meta.refAllDecls(@This());
            \\}
        }) catch return MethodError.InternalError;

        io.writeFile("/home/mwa/code/tmp", fileContents) catch return MethodError.InternalError;

        const result = std.ChildProcess.exec(heap, [_][]const u8{
            "/home/mwa/code/zig/build/bin/zig",
            "test",
            "/home/mwa/code/tmp",
            "--test-filter",
            "__lsp"
        }, null, null, 10 * 1024 * 1024) catch return MethodError.InternalError;

        warn("STDOUT:\n{}\n\nSTDERR:\n{}\n\n", result.stdout, result.stderr);

        switch (result.term) {
            .Exited => |exit_code| {
                if (exit_code != 0) {
                    const lineEnd = mem.indexOf(u8, result.stderr, "\n") orelse return MethodError.InternalError;
                    const line = result.stderr[0..lineEnd];
                    var it = mem.separate(line, ":");
                    _ = it.next();
                    const lineNumber = std.fmt.parseInt(i64, it.next() orelse return MethodError.InternalError, 10) catch return MethodError.InternalError;
                    const charNumber = std.fmt.parseInt(i64, it.next() orelse return MethodError.InternalError, 10) catch return MethodError.InternalError;
                    const message = line[it.index.? ..];

                    const diagnostic = [1]types.Diagnostic{types.Diagnostic{
                        .range = types.Range{
                            .start = types.Position{
                                .line = lineNumber - 1,
                                .character = charNumber - 1
                            },
                            .end = types.Position{
                                .line = lineNumber - 1,
                                .character = charNumber - 1
                            }
                        },
                        .severity = serial.MaybeDefined(i64){ .Defined = types.DiagnosticSeverity.Error },
                        .message = message,
                    }};

                    const outParam = types.PublishDiagnosticsParams{
                        .uri = params.textDocument.uri,
                        .diagnostics = diagnostic[0..]
                    };

                    var request = json_rpc.Request{
                        .jsonrpc = "2.0",
                        .method = "textDocument/publishDiagnostics",
                        .params = serial.serialize2(outParam, heap) catch return MethodError.InternalError,
                        .id = serial.MaybeDefined(json.Value).NotDefined
                    };
                    request.params.dump();
                    msgWrite.writeRequest(request) catch return MethodError.InternalError;
                }
            },
            else => {
                // Crashed
                return MethodError.InternalError;
            },
        }
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

    var server = Server{};

    var dispatcher = json_rpc.Dispatcher(Server).init(server, heap);
    defer dispatcher.deinit();

    try dispatcher.register("initialize", Server.onInitialize);
    try dispatcher.register("initialized", Server.onInitialized);
    try dispatcher.register("textDocument/didChange", Server.onTextDocumentDidChange);

    while(true){
        const request = try msgReader.readMessage();

        dispatcher.dispatch(request) catch |err| {
            debug.warn("{}", err);
        };
    }
}
